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

    private var document: AnnotationDocument?
    private var canvas: CanvasView?
    private var canvasHost: OverlayView?
    private var toolbar: ToolbarView?
    private var cropGlobalRect: CGRect = .null
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

    /// Selection move/resize is allowed only before anything is annotated (annotations live in
    /// crop coordinates, so changing the crop under them is not supported in v1).
    var isGeometryEditable: Bool {
        model.phase == .adjusting && (document?.annotations.isEmpty ?? true) && !(canvas?.isEditingText ?? false)
    }

    /// Pixel size of a global rect on the display containing its center.
    func pixelSize(of rect: CGRect) -> CGSize? { pixels.pixelSize(of: rect) }

    /// true → the OverlayView takes the mouse event; false → normal hit testing (canvas/toolbar).
    func overlayClaimsMouse(atLocal p: CGPoint, in view: OverlayView) -> Bool {
        guard model.phase == .adjusting else { return true }
        if let tb = toolbar, tb.superview === view,
           tb.frame.contains(p) || tb.toolRack.frame.contains(p) { return false }
        let g = view.global(p)
        if isGeometryEditable, let r = model.rect {
            if geometryHandle(at: g, in: r) != nil { return true }
            if r.contains(g), canvas?.tool == nil { return true }
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
        }
    }

    func mouseDown(at g: CGPoint, clickCount: Int) {
        cursor = g
        switch model.phase {
        case .selecting:
            model.mouseDown(at: g)
            refresh()
        case .adjusting:
            // Double-click inside the selection with no drawing tool copies. (When annotations
            // exist the canvas gets the clicks and reports this through `onDoubleClick`.)
            if clickCount == 2, canvas?.tool == nil, let rect = model.rect, rect.contains(g) {
                geometryDrag = nil
                perform(.copy)
                return
            }
            guard isGeometryEditable, let rect = model.rect else { return }
            if let h = geometryHandle(at: g, in: rect) {
                geometryDrag = .resize(h, start: rect, from: g)
            } else if rect.contains(g), canvas?.tool == nil {
                geometryDrag = .move(start: rect, from: g)
                NSCursor.closedHand.set()
            } else {
                return
            }
            // Hidden while the geometry changes; rebuilt for the new crop on mouse up.
            canvas?.removeFromSuperview()
            toolbar?.removeFromSuperview()
            toolbar?.toolRack.removeFromSuperview()
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
                model.setRect(h.resized(start, by: CGVector(dx: g.x - from.x, dy: g.y - from.y)))
            case let .move(start, from):
                let b = model.bounds
                var r = start
                r.origin.x = min(max(start.minX + g.x - from.x, b.minX), max(b.minX, b.maxX - r.width))
                r.origin.y = min(max(start.minY + g.y - from.y, b.minY), max(b.minY, b.maxY - r.height))
                model.setRect(r)
            }
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
            guard geometryDrag != nil else { return }
            geometryDrag = nil
            rebuildCanvas()
            updateAdjustingCursor(at: g)
        }
    }

    private func updateAdjustingCursor(at g: CGPoint) {
        guard let rect = model.rect else { return }
        if let tb = toolbar, let host = canvasHost, host.display.frame.contains(g),
           tb.frame.contains(host.local(g)) || tb.toolRack.frame.contains(host.local(g)) {
            NSCursor.arrow.set()
        } else if isGeometryEditable, geometryHandle(at: g, in: rect) != nil {
            NSCursor.crosshair.set()
        } else if rect.contains(g) {
            (canvas?.tool == nil && isGeometryEditable ? NSCursor.openHand : NSCursor.crosshair).set()
        } else {
            NSCursor.arrow.set()
        }
    }

    // MARK: Keyboard

    func handleKey(_ event: NSEvent) -> Bool {
        guard let action = OverlayKeyMap.action(
            keyCode: event.keyCode, characters: event.charactersIgnoringModifiers,
            modifiers: event.modifierFlags, phase: model.phase,
            isEditingText: canvas?.isEditingText ?? false)
        else { return false }
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
            model.nudge(dx: dx, dy: dy, pixelScale: selectionScale)
            rebuildCanvas()
        case let .resize(dw, dh):
            guard isGeometryEditable else { return }
            model.resize(dw: dw, dh: dh, pixelScale: selectionScale)
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
        guard model.phase == .adjusting, let document else { return }
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

    /// (Re)creates the document + canvas for the current selection and places the toolbar.
    private func rebuildCanvas() {
        let tool = canvas?.tool
        canvas?.removeFromSuperview()
        toolbar?.removeFromSuperview()
        toolbar?.toolRack.removeFromSuperview()
        guard let rect = model.rect, let crop = pixels.crop(rect),
              let host = windows.first(where: { $0.overlayView.display.displayID == crop.frame.display.displayID })?.overlayView
        else {
            Self.logger.error("selection crop failed")
            // Drop the stale canvas so nothing can export the previous selection.
            document = nil
            canvas = nil
            canvasHost = nil
            toolbar = nil
            cropGlobalRect = .null
            refresh()
            return
        }
        let doc = AnnotationDocument(image: crop.image, scale: crop.frame.display.scale)
        let cv = CanvasView(document: doc)
        cv.style = currentStyle
        cv.mosaicMode = preferences.mosaicMode
        cv.tool = tool
        cv.onChange = { [weak self] in self?.documentChanged() }
        cv.onDoubleClick = { [weak self] in self?.perform(.copy) }
        cv.setFrameOrigin(host.local(crop.globalRect).origin)
        host.addSubview(cv, positioned: .below, relativeTo: host.magnifier)

        let tb = toolbar ?? ToolbarView()
        tb.onCommand = { [weak self] in self?.handleToolbar($0) }
        host.addSubview(tb)
        host.addSubview(tb.toolRack)

        document = doc
        canvas = cv
        canvasHost = host
        toolbar = tb
        cropGlobalRect = crop.globalRect
        host.window?.makeKey()
        host.window?.makeFirstResponder(cv)
        updateToolbar()
        refresh()
    }

    private var currentStyle: AnnotationStyle {
        AnnotationStyle(color: preferences.lastColor, lineWidth: preferences.lastLineWidth)
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
            canvas?.applyStyle(currentStyle)
            updateToolbar()
        case .lineWidth(let width):
            preferences.lastLineWidth = width
            canvas?.applyStyle(currentStyle)
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
        updateToolbar()
        refresh()
    }

    private func updateToolbar() {
        guard let tb = toolbar, let document else { return }
        tb.update(tool: canvas?.tool, color: preferences.lastColor, lineWidth: preferences.lastLineWidth,
                  mosaicMode: preferences.mosaicMode, canUndo: document.canUndo, canRedo: document.canRedo)
        layoutToolbar()
    }

    /// Drawing tools stay beside the crop; output actions stay below or above it.
    private func layoutToolbar() {
        guard let tb = toolbar, let host = canvasHost, let cv = canvas else { return }
        let visible = host.window?.screen.map { host.local($0.visibleFrame) } ?? host.bounds
        let layout = ToolbarLayout(selection: cv.frame, available: visible.intersection(host.bounds),
                                   toolSize: tb.toolRack.fittingSize, actionSize: tb.fittingSize)
        tb.frame = layout.actions
        tb.toolRack.frame = layout.tools
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
