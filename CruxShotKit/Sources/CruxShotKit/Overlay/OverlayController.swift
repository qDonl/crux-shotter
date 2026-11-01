import AppKit
import OSLog

public enum OverlayMode: Sendable { case annotate, ocr }

public enum OverlayResult {
    case cancelled
    case copy(CGImage)
    case save(CGImage)
    /// The unannotated crop plus its annotations, so the pin can keep editing them.
    case pin(CGImage, annotations: [Annotation], globalFrame: CGRect)
    case ocr(CGImage)
    case copiedColor(String)
}

/// Owns the overlay windows (one per captured display), the shared `SelectionModel` and, once a
/// selection is committed, the annotation canvas and toolbar. Views only draw and forward events.
@MainActor
public final class OverlayController {
    private static let logger = Logger(subsystem: "com.cruxshot", category: "Overlay")

    private enum GeometryDrag {
        case resize(SelectionHandle, start: CGRect, from: CGPoint)
        case move(start: CGRect, from: CGPoint)
    }

    private let snapshot: CaptureSnapshot
    private let pixels: SnapshotPixels
    private let mode: OverlayMode
    private let preferences: Preferences
    private(set) var model: SelectionModel
    private var windows: [OverlayWindow] = []
    private var completion: ((OverlayResult) -> Void)?
    private var screenObserver: NSObjectProtocol?
    private var cursor: CGPoint = .zero
    private var isFinished = false

    private(set) var document: AnnotationDocument?
    private var canvas: CanvasView?
    private var canvasHost: OverlayView?
    private var toolbar: ToolbarView?
    private var cropGlobalRect: CGRect { document?.captureFrame ?? .null }
    private var editingDisplayID: CGDirectDisplayID?
    private var geometryDrag: GeometryDrag?

    public init(snapshot: CaptureSnapshot, mode: OverlayMode, preferences: Preferences) {
        self.snapshot = snapshot
        pixels = SnapshotPixels(snapshot: snapshot)
        self.mode = mode
        self.preferences = preferences
        let bounds = snapshot.frames.map(\.display.frame).reduce(CGRect.null) { $0.union($1) }
        model = SelectionModel(bounds: bounds)
    }

    // MARK: Lifecycle

    public func present(completion: @escaping (OverlayResult) -> Void) {
        guard windows.isEmpty, !isFinished else { return }
        self.completion = completion
        guard !snapshot.frames.isEmpty else {
            CaptureSignpost.end()
            finish(.cancelled)
            return
        }
        windows = snapshot.frames.map { OverlayWindow(frame: $0, controller: self) }
        screenObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.cancel() }
        }
        ActivationHelper.activateForKeyboard()
        cursor = NSEvent.mouseLocation
        for (i, w) in windows.enumerated() {
            w.orderFrontRegardless()
            if i == 0 { CaptureSignpost.end() }
        }
        let key = windows.first { $0.frame.contains(cursor) } ?? windows[0]
        key.makeKeyAndOrderFront(nil)
        key.makeFirstResponder(key.overlayView)
        model.hover(at: cursor, windows: snapshot.windows)
        NSCursor.crosshair.set()
        refresh()
    }

    public func cancel() { finish(.cancelled) }

    private func finish(_ result: OverlayResult) {
        guard !isFinished else { return }
        isFinished = true
        if let screenObserver { NotificationCenter.default.removeObserver(screenObserver) }
        screenObserver = nil
        // `isReleasedWhenClosed = false` (OverlayWindow.init), so close() only tears the window down;
        // ARC releases it when `windows` is emptied.
        for w in windows {
            w.orderOut(nil)
            w.close()
        }
        windows.removeAll()
        canvas = nil
        canvasHost = nil
        toolbar = nil
        document = nil
        pixels.releaseSamplers()
        NSCursor.arrow.set()
        let done = completion
        completion = nil
        done?(result)
    }

    // MARK: Queries used by the views

    /// Crop adjustments preserve the same document, annotations, and undo history.
    var isGeometryEditable: Bool { model.phase == .adjusting && document != nil }

    private var editingBounds: CGRect {
        snapshot.frames.first { $0.display.displayID == editingDisplayID }?.display.frame ?? model.bounds
    }

    /// Empty-space dragging moves the crop; clicking a mark or its handles belongs to the canvas.
    func isSelectionBackground(at global: CGPoint) -> Bool {
        guard let rect = model.rect, rect.contains(global), canvas?.tool == nil,
              !(canvas?.isEditingText ?? false) else { return false }
        guard let document, let frame = document.captureFrame else { return true }
        let point = Geometry.imagePoint(fromGlobal: global, imageOriginGlobal: frame)
        if let selected = canvas?.selectedID.flatMap({ id in document.annotations.first { $0.id == id } }),
           AnnotationResizer.handle(at: point, for: selected) != nil { return false }
        if canvas?.isSelectedAnnotation(at: point) == true { return false }
        return AnnotationHitTester.hit(point, in: document.annotations) == nil
    }

    /// Pixel size of a global rect on the display containing its center.
    func pixelSize(of rect: CGRect) -> CGSize? { pixels.pixelSize(of: rect) }

    /// true → the OverlayView takes the mouse event; false → normal hit testing (canvas/toolbar).
    func overlayClaimsMouse(atLocal p: CGPoint, in view: OverlayView) -> Bool {
        guard model.phase == .adjusting else { return true }
        if let tb = toolbar, tb.superview === view,
           tb.frame.contains(p) || tb.toolRack.frame.contains(p) ||
           (!tb.propertyBar.isHidden && tb.propertyBar.frame.contains(p)) { return false }
        let g = view.global(p)
        if isGeometryEditable, let r = model.rect {
            if geometryHandle(at: g, in: r) != nil { return true }
            if isSelectionBackground(at: g) { return true }
        }
        return false
    }

    // MARK: Mouse

    func mouseMoved(to g: CGPoint) {
        cursor = g
        if model.phase == .selecting {
            model.hover(at: g, windows: snapshot.windows)
            NSCursor.crosshair.set()
            refresh()
        } else {
            updateAdjustingCursor(at: g)
            refresh()
        }
    }

    func mouseDown(at g: CGPoint, clickCount: Int) {
        cursor = g
        switch model.phase {
        case .selecting:
            model.mouseDown(at: g)
            refresh()
        case .adjusting:
            canvas?.beginClickSequence(clickCount: clickCount)
            // Double-click inside the selection with no drawing tool copies. (When annotations
            // exist the canvas gets the clicks and reports this through `onDoubleClick`.)
            if clickCount == 2, isSelectionBackground(at: g), canvas?.canDoubleClickCopy ?? true,
               let rect = model.rect, geometryHandle(at: g, in: rect) == nil {
                geometryDrag = nil
                perform(.copy)
                return
            }
            guard isGeometryEditable, let rect = model.rect else { return }
            canvas?.commitTextEditing()
            if let h = geometryHandle(at: g, in: rect) {
                geometryDrag = .resize(h, start: rect, from: g)
            } else if isSelectionBackground(at: g) {
                geometryDrag = .move(start: rect, from: g)
                if !windows.isEmpty { NSCursor.closedHand.set() }
            } else {
                return
            }
            // Keep marks visible in global coordinates while previewing the crop. Only output
            // controls are hidden until the single undoable crop change commits on mouse-up.
            toolbar?.removeFromSuperview()
            toolbar?.toolRack.removeFromSuperview()
            toolbar?.propertyBar.removeFromSuperview()
            if let host = canvasHost { host.window?.makeFirstResponder(host) }
        }
    }

    func mouseDragged(to g: CGPoint) {
        cursor = g
        switch model.phase {
        case .selecting:
            model.mouseDragged(to: g)
        case .adjusting:
            guard let geometryDrag else { return }
            switch geometryDrag {
            case let .resize(h, start, from):
                model.setRect(h.resized(start, by: CGVector(dx: g.x - from.x, dy: g.y - from.y)).intersection(editingBounds))
            case let .move(start, from):
                let b = editingBounds
                var r = start
                r.origin.x = min(max(start.minX + g.x - from.x, b.minX), max(b.minX, b.maxX - r.width))
                r.origin.y = min(max(start.minY + g.y - from.y, b.minY), max(b.minY, b.maxY - r.height))
                model.setRect(r)
            }
            previewGeometry()
        }
        refresh()
    }

    func mouseUp(at g: CGPoint) {
        cursor = g
        switch model.phase {
        case .selecting:
            model.mouseUp(at: g)
            if model.phase == .adjusting { enterAdjusting() } else { refresh() }
        case .adjusting:
            guard let drag = geometryDrag else { return }
            if case .move(_, let from) = drag, hypot(g.x - from.x, g.y - from.y) < SelectionModel.dragThreshold {
                canvas?.select(nil)
            }
            mouseDragged(to: g)
            geometryDrag = nil
            rebuildCanvas()
            updateAdjustingCursor(at: g)
        }
    }

    private func updateAdjustingCursor(at g: CGPoint) {
        guard !windows.isEmpty, let rect = model.rect else { return }
        if let tb = toolbar, let host = canvasHost, host.display.frame.contains(g),
           tb.frame.contains(host.local(g)) || tb.toolRack.frame.contains(host.local(g)) ||
           (!tb.propertyBar.isHidden && tb.propertyBar.frame.contains(host.local(g))) {
            NSCursor.arrow.set()
        } else if isGeometryEditable, let handle = geometryHandle(at: g, in: rect) {
            switch handle {
            case .left, .right: NSCursor.resizeLeftRight.set()
            case .top, .bottom: NSCursor.resizeUpDown.set()
            default: NSCursor.crosshair.set()
            }
        } else if rect.contains(g) {
            if let document, let frame = document.captureFrame {
                let point = Geometry.imagePoint(fromGlobal: g, imageOriginGlobal: frame)
                if let id = canvas?.selectedID,
                   let selected = document.annotations.first(where: { $0.id == id }),
                   AnnotationResizer.handle(at: point, for: selected) != nil {
                    NSCursor.crosshair.set()
                } else if canvas?.isSelectedAnnotation(at: point) == true ||
                            AnnotationHitTester.hit(point, in: document.annotations) != nil {
                    NSCursor.pointingHand.set()
                } else {
                    (canvas?.tool == nil ? NSCursor.openHand : NSCursor.crosshair).set()
                }
            } else {
                NSCursor.crosshair.set()
            }
        } else {
            NSCursor.arrow.set()
        }
    }

    // MARK: Keyboard

    func handleKey(_ event: NSEvent) -> Bool {
        if model.phase == .adjusting, canvas?.handleLineWidthKey(event) == true { return true }
        guard let action = OverlayKeyMap.action(
            keyCode: event.keyCode, characters: event.charactersIgnoringModifiers,
            modifiers: event.modifierFlags, phase: model.phase,
            isEditingText: canvas?.isEditingText ?? false)
        else { return false }
        if geometryDrag != nil, action != .cancel { return true }
        perform(action)
        return true
    }

    func shiftTapped() {
        guard model.phase == .selecting else { return }
        perform(.toggleColorFormat)
    }

    private func perform(_ action: OverlayAction) {
        switch action {
        case .cancel:
            if geometryDrag != nil {
                geometryDrag = nil
                syncSelectionFromDocument()
                restoreControls()
                canvasHost?.window?.makeFirstResponder(canvas)
                updateToolbar()
                updateAdjustingCursor(at: cursor)
                refresh()
                return
            }
            if canvas?.tool != nil { setTool(nil) } else { cancel() }
        case .copy, .save, .pin, .ocr:
            export(action)
        case .undo, .redo:
            guard let document else { return }
            canvas?.commitTextEditing()
            if action == .undo { document.undo() } else { document.redo() }
            documentChanged()
        case .selectTool(let tool):
            setTool(tool)
        case let .nudge(dx, dy):
            guard isGeometryEditable else { return }
            model.nudge(dx: dx, dy: dy, pixelScale: selectionScale, within: editingBounds)
            rebuildCanvas()
        case let .resize(dw, dh):
            guard isGeometryEditable else { return }
            model.resize(dw: dw, dh: dh, pixelScale: selectionScale, within: editingBounds)
            rebuildCanvas()
        case .copyColor:
            guard let color = pixels.colorString(at: cursor, format: preferences.colorFormat) else { return }
            ClipboardWriter.write(text: color)
            finish(.copiedColor(color))
        case .toggleColorFormat:
            preferences.colorFormat = preferences.colorFormat.toggled
            refresh()
        }
    }

    private func export(_ action: OverlayAction) {
        guard model.phase == .adjusting, geometryDrag == nil, let document else { return }
        canvas?.commitTextEditing()
        let image = AnnotationRenderer.render(document)
        switch action {
        case .copy: finish(.copy(image))
        case .save: finish(.save(image))
        case .pin: finish(.pin(document.image, annotations: document.annotations, globalFrame: cropGlobalRect))
        case .ocr: finish(.ocr(image))
        default: break
        }
    }

    // MARK: Adjusting phase

    private func enterAdjusting() {
        guard mode == .annotate else {
            if let rect = model.rect, let crop = pixels.crop(rect) { finish(.ocr(crop.image)) } else { cancel() }
            return
        }
        rebuildCanvas()
    }

    /// Re-crops only from the frozen snapshot, retaining marks and the document's full history.
    private func rebuildCanvas() {
        guard let rect = model.rect, let crop = pixels.crop(rect, displayID: editingDisplayID) else {
            Self.logger.error("selection crop failed")
            // Keep the last valid selection rather than exporting stale pixels for a new rectangle.
            syncSelectionFromDocument()
            restoreControls()
            updateToolbar()
            refresh()
            return
        }
        editingDisplayID = crop.frame.display.displayID
        let doc: AnnotationDocument
        if let existing = document {
            existing.reframe(image: crop.image, scale: crop.frame.display.scale, frame: crop.globalRect)
            doc = existing
        } else {
            doc = AnnotationDocument(image: crop.image, scale: crop.frame.display.scale, captureFrame: crop.globalRect)
            document = doc
        }
        model.setRect(crop.globalRect)
        // The editing state is usable independently of presentation (also exercised by component tests).
        guard let host = windows.first(where: { $0.overlayView.display.displayID == crop.frame.display.displayID })?.overlayView else {
            refresh()
            return
        }
        let cv = canvas ?? CanvasView(document: doc)
        cv.clipsToBounds = true
        cv.style = currentStyle
        cv.mosaicMode = preferences.mosaicMode
        cv.onChange = { [weak self] in self?.documentChanged() }
        cv.onDoubleClick = { [weak self] in self?.perform(.copy) }
        cv.onHover = { [weak self] point in
            guard let self, let frame = self.document?.captureFrame else { return }
            let global = CGPoint(x: frame.minX + point.x, y: frame.maxY - point.y)
            self.mouseMoved(to: global)
        }
        cv.onLineWidthStep = { [weak self, weak cv] delta, point in
            guard let self, let cv else { return }
            let current = cv.selectedAnnotationStyle?.lineWidth ?? cv.style.lineWidth
            let next = current.stepped(by: delta)
            self.preferences.lastLineWidth = next
            cv.applyLineWidth(next)
            cv.showLineWidth(next, near: point)
            self.updateToolbar()
        }
        if cv.superview !== host {
            cv.removeFromSuperview()
            host.addSubview(cv, positioned: .below, relativeTo: host.magnifier)
        }
        let tb = toolbar ?? ToolbarView()
        tb.onCommand = { [weak self] in self?.handleToolbar($0) }
        canvas = cv
        canvasHost = host
        toolbar = tb
        syncSelectionFromDocument()
        restoreControls()
        host.window?.makeKey()
        host.window?.makeFirstResponder(cv)
        updateToolbar()
        refresh()
    }

    private func restoreControls() {
        guard let host = canvasHost, let toolbar else { return }
        if toolbar.superview !== host { host.addSubview(toolbar) }
        if toolbar.toolRack.superview !== host { host.addSubview(toolbar.toolRack) }
        if toolbar.propertyBar.superview !== host { host.addSubview(toolbar.propertyBar) }
    }

    private func syncSelectionFromDocument() {
        guard let document, let rect = document.captureFrame else { return }
        model.setRect(rect)
        guard let canvas, let host = canvasHost else { return }
        canvas.frame = host.local(rect)
        canvas.bounds = CGRect(origin: .zero, size: document.pointSize)
        canvas.needsDisplay = true
    }

    private func previewGeometry() {
        guard let rect = model.rect, let document, let previous = document.captureFrame,
              let canvas, let host = canvasHost else { return }
        canvas.frame = host.local(rect)
        canvas.bounds = CGRect(x: rect.minX - previous.minX, y: previous.maxY - rect.maxY,
                               width: rect.width, height: rect.height)
        canvas.needsDisplay = true
    }

    private var currentStyle: AnnotationStyle {
        AnnotationStyle(color: preferences.lastColor, lineWidth: preferences.lastLineWidth, arrowStyle: preferences.lastArrowStyle)
    }

    private func setTool(_ tool: CanvasTool?) {
        guard let canvas else { return }
        canvas.tool = tool
        updateToolbar()
        refresh()
    }

    private func handleToolbar(_ command: ToolbarCommand) {
        switch command {
        case .action(let action):
            perform(action)
        case .select:
            setTool(nil)
        case .toggleTool(let tool):
            setTool(canvas?.tool == tool ? nil : tool)
        case .color(let color):
            preferences.lastColor = color
            canvas?.applyColor(color)
            updateToolbar()
        case .lineWidth(let width):
            preferences.lastLineWidth = width
            canvas?.applyLineWidth(width)
            updateToolbar()
        case .arrowStyle(let style):
            preferences.lastArrowStyle = style
            canvas?.applyArrowStyle(style)
            updateToolbar()
        case .mosaicMode(let mode):
            preferences.mosaicMode = mode
            canvas?.mosaicMode = mode
            updateToolbar()
        case .done, .discard:
            break
        }
    }

    private func documentChanged() {
        if geometryDrag == nil { syncSelectionFromDocument() }
        updateToolbar()
        refresh()
    }

    private func updateToolbar() {
        guard let tb = toolbar, let document else { return }
        let selectedStyle = canvas?.selectedAnnotationStyle
        tb.update(tool: canvas?.tool, color: selectedStyle?.color ?? preferences.lastColor,
                  lineWidth: selectedStyle?.lineWidth ?? preferences.lastLineWidth,
                  mosaicMode: preferences.mosaicMode, canUndo: document.canUndo, canRedo: document.canRedo,
                  arrowStyle: preferences.lastArrowStyle, selectedArrowStyle: canvas?.selectedArrowStyle,
                  hasSelection: canvas?.selectedID != nil)
        layoutToolbar()
    }

    /// Drawing tools stay beside the crop; output actions stay below or above it.
    private func layoutToolbar() {
        guard let tb = toolbar, let host = canvasHost, let cv = canvas else { return }
        let visible = host.window?.screen.map { host.local($0.visibleFrame) } ?? host.bounds
        let layout = ToolbarLayout(selection: cv.frame, available: visible.intersection(host.bounds),
                                   toolSize: tb.toolRack.fittingSize, actionSize: tb.fittingSize,
                                   propertySize: tb.propertyBar.fittingSize)
        tb.frame = layout.actions
        tb.toolRack.frame = layout.tools
        tb.propertyBar.frame = layout.properties
    }

    /// With a drawing tool active, only the handles and the band outside the border resize, so
    /// strokes started just inside the edge still draw.
    private func geometryHandle(at g: CGPoint, in rect: CGRect) -> SelectionHandle? {
        SelectionHandle.hit(g, in: rect, innerEdges: canvas?.tool == nil)
    }

    private var selectionScale: CGFloat {
        model.rect.flatMap(pixels.bestFrame(for:))?.display.scale ?? 1
    }

    // MARK: Redraw

    private func refresh() {
        for w in windows {
            w.overlayView.needsDisplay = true
            updateMagnifier(in: w.overlayView)
        }
    }

    private func updateMagnifier(in view: OverlayView) {
        let show = model.phase == .selecting && view.display.frame.contains(cursor)
        view.magnifier.isHidden = !show
        guard show else { return }
        let p = pixels.pixel(of: cursor, on: view.display)
        let sampler = pixels.sampler(for: view.captured)
        let color = sampler.color(atPixel: p.x, p.y).map(preferences.colorFormat.string(for:)) ?? "—"
        let sizeRect = model.rect ?? model.hoveredWindow?.frame
        let size = sizeRect.flatMap(pixelSize(of:)).map { "\(Int($0.width)) × \(Int($0.height))" } ?? ""
        view.magnifier.update(patch: sampler.patch(centerX: p.x, centerY: p.y, radius: MagnifierView.radius),
                              position: "(\(p.x), \(p.y))", color: color, size: size)
        view.magnifier.place(near: view.local(cursor), in: view.bounds)
    }
}
