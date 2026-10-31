import AppKit
import Combine

/// Interactive annotation layer. Draws only annotations (the screenshot is drawn by the container).
/// Frame size should equal `document.pointSize`; the view is flipped so its space matches image points.
@MainActor
public final class CanvasView: NSView, NSTextViewDelegate {
    public static let minimumShapeSize: CGFloat = 2

    public let document: AnnotationDocument
    /// nil = selection mode.
    public var tool: CanvasTool? {
        didSet { if tool != oldValue { commitTextEditing(); if tool != nil { select(nil) } } }
    }
    public var style = AnnotationStyle()
    public var mosaicMode: MosaicMode = .pixelate
    public var onChange: (() -> Void)?
    /// Double-click in selection mode (`tool == nil`) that misses every annotation and did not
    /// end a text edit. The overlay uses it for "double-click to copy".
    public var onDoubleClick: (() -> Void)?
    var onHover: ((CGPoint) -> Void)?
    public var isEditingText: Bool { textView != nil }
    var canDoubleClickCopy: Bool { !isEditingText && !clickSequenceEndedEditing }
    public var selectedAnnotationStyle: AnnotationStyle? {
        guard let id = validSelectedID else { return nil }
        return document.annotations.first { $0.id == id }?.style
    }
    public var selectedArrowStyle: ArrowStyle? {
        guard let id = validSelectedID, let a = document.annotations.first(where: { $0.id == id }),
              case .arrow = a.kind else { return nil }
        return a.style.arrowStyle
    }

    private(set) var selectedID: Annotation.ID?
    private var draft: Annotation?
    private var dragStart: CGPoint = .zero
    private var dragOffset: CGVector = .zero
    private var isMovingSelection = false
    private var resizeHandle: ResizeHandle?
    private var resizeDraft: Annotation?
    private var textView: NSTextView?
    private var textOrigin: CGPoint = .zero
    private var preferredTextOrigin: CGPoint = .zero
    private var lastSelectionPoint: CGPoint?
    private var cancellable: AnyCancellable?
    /// The first click of the current click sequence committed an in-place text edit.
    private var clickSequenceEndedEditing = false

    public override var isFlipped: Bool { true }
    public override var acceptsFirstResponder: Bool { true }

    public init(document: AnnotationDocument) {
        self.document = document
        super.init(frame: CGRect(origin: .zero, size: document.pointSize))
        cancellable = document.objectWillChange.sink { [weak self] _ in
            MainActor.assumeIsolated { self?.needsDisplay = true }
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    // MARK: Public API

    /// Sets the drawing style; selected annotations keep their arrow variant, changed via `applyArrowStyle`.
    public func applyStyle(_ newStyle: AnnotationStyle) {
        style = newStyle
        if let id = validSelectedID {
            document.update(id: id) {
                let arrowStyle = $0.style.arrowStyle
                $0.style = newStyle
                $0.style.arrowStyle = arrowStyle
            }
            changed()
        }
    }

    public func applyColor(_ color: PaletteColor) {
        style.color = color
        if let id = validSelectedID, selectedAnnotationStyle?.color != color {
            document.update(id: id) { $0.style.color = color }
            changed()
        }
    }

    public func applyLineWidth(_ width: LineWidth) {
        style.lineWidth = width
        if let id = validSelectedID, selectedAnnotationStyle?.lineWidth != width {
            document.update(id: id) { $0.style.lineWidth = width }
            changed()
        }
    }

    /// Arrow variants are changed explicitly so changing color/width never resets a selected arrow.
    public func applyArrowStyle(_ arrowStyle: ArrowStyle) {
        style.arrowStyle = arrowStyle
        if let id = validSelectedID, selectedArrowStyle != nil,
           document.annotations.first(where: { $0.id == id })?.style.arrowStyle != arrowStyle {
            document.update(id: id) { $0.style.arrowStyle = arrowStyle }
            changed()
        }
    }

    /// The overlay also receives empty-space clicks while the selection can be moved.
    func beginClickSequence(clickCount: Int) {
        if clickCount <= 1 { clickSequenceEndedEditing = isEditingText }
    }

    /// Commits the in-place text editor, if any. Empty or whitespace-only text adds nothing.
    public func commitTextEditing() { commitText(refocus: true) }

    private func commitText(refocus: Bool) {
        guard let tv = textView else { return }
        textView = nil
        tv.unmarkText()
        let string = tv.string
        let editStyle = style
        tv.delegate = nil
        tv.removeFromSuperview()
        if refocus { window?.makeFirstResponder(self) }
        guard !string.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        document.add(Annotation(kind: .text(origin: textOrigin, string: string), style: editStyle))
        changed()
    }

    // MARK: Drawing

    public override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        var items = document.annotations
        if let id = validSelectedID, let i = items.firstIndex(where: { $0.id == id }) {
            if isMovingSelection { items[i] = items[i].translated(by: dragOffset) }
            if let resizeDraft { items[i] = resizeDraft }
        }
        if let draft { items.append(draft) }
        AnnotationRenderer.draw(items, source: document.image, scale: document.scale, in: ctx)

        if let id = validSelectedID, let sel = items.first(where: { $0.id == id }) {
            ctx.saveGState()
            ctx.setStrokeColor(PaletteColor.blue.cgColor)
            ctx.setLineWidth(1)
            ctx.setLineDash(phase: 0, lengths: [4, 3])
            ctx.stroke(sel.bounds.insetBy(dx: -3, dy: -3))
            for (handle, c) in AnnotationResizer.handles(for: sel) {
                // Edge resize remains available through hit testing; corners carry the visual cue.
                if [.top, .right, .bottom, .left].contains(handle) { continue }
                let box = CGRect(x: c.x - 3, y: c.y - 3, width: 6, height: 6)
                ctx.setFillColor(CGColor(gray: 1, alpha: 1))
                ctx.fill(box)
                ctx.setLineDash(phase: 0, lengths: [])
                ctx.stroke(box)
            }
            ctx.restoreGState()
        }
    }

    public override func updateTrackingAreas() {
        super.updateTrackingAreas()
        for area in trackingAreas { removeTrackingArea(area) }
        addTrackingArea(NSTrackingArea(rect: .zero, options: [.mouseMoved, .activeAlways, .inVisibleRect],
                                       owner: self, userInfo: nil))
    }

    public override func mouseMoved(with event: NSEvent) {
        onHover?(convert(event.locationInWindow, from: nil))
    }

    // MARK: Mouse

    public override func mouseDown(with event: NSEvent) {
        let wasEditingText = isEditingText
        beginClickSequence(clickCount: event.clickCount)
        window?.makeFirstResponder(self)
        commitTextEditing()
        let p = convert(event.locationInWindow, from: nil)
        dragStart = p
        dragOffset = .zero
        guard let tool else {
            if let id = validSelectedID, let sel = document.annotations.first(where: { $0.id == id }),
               let h = AnnotationResizer.handle(at: p, for: sel) {
                resizeHandle = h
                resizeDraft = sel
                return
            }
            let hit = AnnotationHitTester.hit(p, in: document.annotations)
            if hit == nil, event.clickCount == 2, !wasEditingText, !clickSequenceEndedEditing, let onDoubleClick {
                onDoubleClick()
                return
            }
            lastSelectionPoint = hit == nil ? nil : p
            select(hit)
            isMovingSelection = false
            return
        }
        switch tool {
        case .rect, .arrow, .mosaic: draft = makeDraft(tool, to: p)
        case .pen: draft = Annotation(kind: .pen([p]), style: style)
        case .text: beginTextEditing(at: p)
        case .counter:
            document.add(Annotation(kind: .counter(center: p, number: document.nextCounterNumber), style: style))
            changed()
        }
    }

    public override func mouseDragged(with event: NSEvent) {
        let p = convert(event.locationInWindow, from: nil)
        if let tool, let d = draft {
            if tool == .pen, case .pen(var pts) = d.kind {
                pts.append(p)
                draft?.kind = .pen(pts)
            } else {
                draft = makeDraft(tool, to: p, id: d.id)
            }
            needsDisplay = true
        } else if let h = resizeHandle, let base = resizeDraft {
            resizeDraft = AnnotationResizer.resized(base, handle: h, to: p)
            needsDisplay = true
        } else if tool == nil, validSelectedID != nil {
            isMovingSelection = true
            dragOffset = CGVector(dx: p.x - dragStart.x, dy: p.y - dragStart.y)
            needsDisplay = true
        }
    }

    public override func mouseUp(with event: NSEvent) {
        if let d = draft {
            draft = nil
            if isValid(d) { document.add(d); changed() }
            needsDisplay = true
        } else if let draftResize = resizeDraft {
            resizeHandle = nil
            resizeDraft = nil
            if let id = validSelectedID, document.annotations.first(where: { $0.id == id }) != draftResize {
                document.update(id: id) { $0 = draftResize }
                changed()
            }
            needsDisplay = true
        } else if isMovingSelection, let id = validSelectedID {
            isMovingSelection = false
            if dragOffset != .zero {
                document.translate(id: id, by: dragOffset)
                changed()
            }
            dragOffset = .zero
            needsDisplay = true
        }
    }

    // MARK: Keyboard

    public override func keyDown(with event: NSEvent) {
        switch event.keyCode {
        case 51, 117:
            if let id = validSelectedID {
                selectedID = nil
                document.remove(id: id)
                changed()
            }
        case 53 where selectedID != nil:
            select(nil)
        case 48 where tool == nil && selectedID != nil:
            if let point = lastSelectionPoint {
                select(AnnotationHitTester.cycle(point, in: document.annotations, current: validSelectedID,
                                                 backwards: event.modifierFlags.contains(.shift)))
            }
        default:
            super.keyDown(with: event)
        }
    }

    // MARK: Text editing

    private func beginTextEditing(at p: CGPoint) {
        textOrigin = p
        preferredTextOrigin = p
        let font = Annotation.textFont(size: style.fontSize)
        let height = ceil(font.ascender - font.descender + font.leading)
        let tv = NSTextView(frame: CGRect(x: p.x, y: p.y, width: max(40, bounds.maxX - p.x), height: height))
        tv.drawsBackground = false
        tv.backgroundColor = .clear
        tv.isRichText = false
        tv.font = font
        tv.textColor = NSColor(cgColor: style.color.cgColor)
        tv.insertionPointColor = NSColor(cgColor: style.color.cgColor)
        tv.textContainerInset = .zero
        tv.textContainer?.lineFragmentPadding = 0
        // No soft wrapping: like AnnotationRenderer, only explicit newlines break lines, so what
        // is typed matches what is exported (text past the image edge is clipped in both).
        let extent = Annotation.textLayoutExtent
        tv.isVerticallyResizable = true
        tv.isHorizontallyResizable = true
        tv.maxSize = CGSize(width: extent, height: extent)
        tv.textContainer?.widthTracksTextView = false
        tv.textContainer?.containerSize = CGSize(width: extent, height: extent)
        tv.autoresizingMask = []
        tv.delegate = self
        addSubview(tv)
        textView = tv
        window?.makeFirstResponder(tv)
    }

    public func textView(_ textView: NSTextView, doCommandBy selector: Selector) -> Bool {
        guard selector == #selector(NSResponder.cancelOperation(_:)) else { return false }
        commitTextEditing()
        return true
    }

    public func textDidEndEditing(_ notification: Notification) {
        commitText(refocus: false)
    }

    public func textDidChange(_ notification: Notification) {
        guard let tv = textView, let lm = tv.layoutManager, let tc = tv.textContainer else { return }
        lm.ensureLayout(for: tc)
        let used = lm.usedRect(for: tc)
        let size = CGSize(width: max(40, ceil(used.width)), height: max(Annotation.textSize("", fontSize: style.fontSize).height, ceil(used.height)))
        let origin = Self.fittedTextOrigin(preferred: preferredTextOrigin, size: size, in: bounds)
        textOrigin = origin
        tv.setFrameOrigin(origin)
        tv.setFrameSize(size)
    }

    /// Keep the edit view and exported text aligned, including near the right and bottom edges.
    static func fittedTextOrigin(preferred: CGPoint, size: CGSize, in bounds: CGRect) -> CGPoint {
        CGPoint(x: min(max(preferred.x, bounds.minX), max(bounds.minX, bounds.maxX - size.width)),
                y: min(max(preferred.y, bounds.minY), max(bounds.minY, bounds.maxY - size.height)))
    }

    // MARK: Helpers

    /// `selectedID`, or nil (clearing it) if that annotation no longer exists, e.g. after undo.
    private var validSelectedID: Annotation.ID? {
        guard let id = selectedID else { return nil }
        if document.annotations.contains(where: { $0.id == id }) { return id }
        selectedID = nil
        return nil
    }

    func select(_ id: Annotation.ID?) {
        if id == nil { lastSelectionPoint = nil }
        guard selectedID != id else { return }
        selectedID = id
        needsDisplay = true
        onChange?()
    }

    private func changed() {
        needsDisplay = true
        onChange?()
    }

    private func makeDraft(_ tool: CanvasTool, to p: CGPoint, id: UUID = UUID()) -> Annotation? {
        let rect = CGRect(x: min(dragStart.x, p.x), y: min(dragStart.y, p.y),
                          width: abs(p.x - dragStart.x), height: abs(p.y - dragStart.y))
        switch tool {
        case .rect: return Annotation(id: id, kind: .rect(rect), style: style)
        case .mosaic: return Annotation(id: id, kind: .mosaic(rect, mosaicMode), style: style)
        case .arrow: return Annotation(id: id, kind: .arrow(from: dragStart, to: p), style: style)
        default: return nil
        }
    }

    private func isValid(_ a: Annotation) -> Bool {
        let m = Self.minimumShapeSize
        switch a.kind {
        case .rect(let r), .mosaic(let r, _): return r.width >= m && r.height >= m
        case .arrow(let f, let t): return hypot(t.x - f.x, t.y - f.y) >= m
        case .pen(let pts): return pts.count >= 2
        default: return true
        }
    }
}
