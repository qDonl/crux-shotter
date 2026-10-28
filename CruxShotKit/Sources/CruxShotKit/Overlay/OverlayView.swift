import AppKit

/// The 8 resize handles of the selection, in AppKit (y-up) coordinates.
enum SelectionHandle: CaseIterable {
    case topLeft, top, topRight, right, bottomRight, bottom, bottomLeft, left

    func point(in r: CGRect) -> CGPoint {
        switch self {
        case .topLeft: CGPoint(x: r.minX, y: r.maxY)
        case .top: CGPoint(x: r.midX, y: r.maxY)
        case .topRight: CGPoint(x: r.maxX, y: r.maxY)
        case .right: CGPoint(x: r.maxX, y: r.midY)
        case .bottomRight: CGPoint(x: r.maxX, y: r.minY)
        case .bottom: CGPoint(x: r.midX, y: r.minY)
        case .bottomLeft: CGPoint(x: r.minX, y: r.minY)
        case .left: CGPoint(x: r.minX, y: r.midY)
        }
    }

    /// Moves the edges this handle controls by `d`; dragging past the opposite edge flips.
    func resized(_ r: CGRect, by d: CGVector) -> CGRect {
        var minX = r.minX, maxX = r.maxX, minY = r.minY, maxY = r.maxY
        switch self {
        case .topLeft: minX += d.dx; maxY += d.dy
        case .top: maxY += d.dy
        case .topRight: maxX += d.dx; maxY += d.dy
        case .right: maxX += d.dx
        case .bottomRight: maxX += d.dx; minY += d.dy
        case .bottom: minY += d.dy
        case .bottomLeft: minX += d.dx; minY += d.dy
        case .left: minX += d.dx
        }
        return CGRect(x: min(minX, maxX), y: min(minY, maxY), width: abs(maxX - minX), height: abs(maxY - minY))
    }

    /// Handle (or edge, mapped to its side handle) under `p`, if any.
    static func hit(_ p: CGPoint, in r: CGRect, radius: CGFloat = 6) -> SelectionHandle? {
        if let h = allCases.first(where: { hypot($0.point(in: r).x - p.x, $0.point(in: r).y - p.y) <= radius }) {
            return h
        }
        let inX = p.x >= r.minX && p.x <= r.maxX, inY = p.y >= r.minY && p.y <= r.maxY
        if inX, abs(p.y - r.maxY) <= 4 { return .top }
        if inX, abs(p.y - r.minY) <= 4 { return .bottom }
        if inY, abs(p.x - r.minX) <= 4 { return .left }
        if inY, abs(p.x - r.maxX) <= 4 { return .right }
        return nil
    }
}

/// Draws the overlay for one display and forwards events (in global points) to the controller.
@MainActor
final class OverlayView: NSView {
    static let maskColor = NSColor.black.withAlphaComponent(0.4)
    static let accent = NSColor(srgbRed: 0, green: 122 / 255, blue: 1, alpha: 1)
    static let handleSide: CGFloat = 8

    let captured: CapturedFrame
    var display: DisplayInfo { captured.display }
    weak var controller: OverlayController?
    let magnifier = MagnifierView()
    /// Shift went down alone and nothing else happened since.
    private var shiftArmed = false

    init(captured: CapturedFrame, controller: OverlayController) {
        self.captured = captured
        self.controller = controller
        super.init(frame: .zero)
        magnifier.isHidden = true
        addSubview(magnifier)
        addTrackingArea(NSTrackingArea(rect: .zero, options: [.mouseMoved, .activeAlways, .inVisibleRect],
                                       owner: self, userInfo: nil))
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    override var acceptsFirstResponder: Bool { true }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    // MARK: Coordinates

    func local(_ g: CGPoint) -> CGPoint { CGPoint(x: g.x - display.frame.minX, y: g.y - display.frame.minY) }
    func local(_ g: CGRect) -> CGRect { g.offsetBy(dx: -display.frame.minX, dy: -display.frame.minY) }
    func global(_ l: CGPoint) -> CGPoint { CGPoint(x: l.x + display.frame.minX, y: l.y + display.frame.minY) }

    private func global(_ event: NSEvent) -> CGPoint {
        guard let window else { return event.locationInWindow }
        return window.convertPoint(toScreen: event.locationInWindow)
    }

    // MARK: Drawing

    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext, let controller else { return }
        let model = controller.model
        let selection = model.rect.map(local)
        let hover: CGRect? = (model.phase == .selecting && model.rect == nil)
            ? model.hoveredWindow.map { local($0.frame) } : nil

        // Mask outside the selection (or outside the hovered window while nothing is selected).
        let path = CGMutablePath()
        path.addRect(bounds)
        if let hole = selection ?? hover { path.addRect(hole) }
        ctx.addPath(path)
        ctx.setFillColor(Self.maskColor.cgColor)
        ctx.fillPath(using: .evenOdd)

        if let hover {
            ctx.setFillColor(Self.accent.withAlphaComponent(0.1).cgColor)
            ctx.fill(hover)
            ctx.setStrokeColor(Self.accent.cgColor)
            ctx.setLineWidth(2)
            ctx.stroke(hover.insetBy(dx: 1, dy: 1))
        }

        guard let selection, let globalRect = model.rect else { return }
        ctx.setStrokeColor(Self.accent.cgColor)
        ctx.setLineWidth(1)
        ctx.stroke(selection.insetBy(dx: -0.5, dy: -0.5))
        if model.phase == .adjusting, controller.isGeometryEditable {
            for h in SelectionHandle.allCases {
                let c = h.point(in: selection)
                let s = Self.handleSide
                let box = CGRect(x: c.x - s / 2, y: c.y - s / 2, width: s, height: s)
                ctx.setFillColor(.white)
                ctx.fill(box)
                ctx.stroke(box.insetBy(dx: 0.5, dy: 0.5))
            }
        }
        if let size = controller.pixelSize(of: globalRect) {
            drawSizeLabel("\(Int(size.width)) × \(Int(size.height))", selection: selection)
        }
    }

    private func drawSizeLabel(_ text: String, selection: CGRect) {
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .medium),
            .foregroundColor: NSColor.white,
        ]
        let textSize = (text as NSString).size(withAttributes: attrs)
        let box = CGSize(width: ceil(textSize.width) + 12, height: ceil(textSize.height) + 6)
        var origin = CGPoint(x: selection.minX, y: selection.maxY + 4)
        if origin.y + box.height > bounds.maxY { origin.y = selection.maxY - box.height - 4 }
        origin.x = min(max(origin.x, bounds.minX), bounds.maxX - box.width)
        let rect = CGRect(origin: origin, size: box)
        NSColor.black.withAlphaComponent(0.75).setFill()
        NSBezierPath(roundedRect: rect, xRadius: 4, yRadius: 4).fill()
        (text as NSString).draw(at: CGPoint(x: rect.minX + 6, y: rect.minY + 3), withAttributes: attrs)
    }

    // MARK: Hit testing

    override func hitTest(_ point: NSPoint) -> NSView? {
        guard !isHidden, let controller else { return super.hitTest(point) }
        let p = convert(point, from: superview)
        guard bounds.contains(p) else { return nil }
        if controller.overlayClaimsMouse(atLocal: p, in: self) { return self }
        return super.hitTest(point)
    }

    // MARK: Mouse

    override func mouseMoved(with event: NSEvent) { controller?.mouseMoved(to: global(event)) }

    override func mouseDown(with event: NSEvent) {
        shiftArmed = false
        controller?.mouseDown(at: global(event))
    }

    override func mouseDragged(with event: NSEvent) { controller?.mouseDragged(to: global(event)) }
    override func mouseUp(with event: NSEvent) { controller?.mouseUp(at: global(event)) }

    // MARK: Keyboard

    override func keyDown(with event: NSEvent) {
        shiftArmed = false
        if controller?.handleKey(event) != true { super.keyDown(with: event) }
    }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if event.modifierFlags.contains(.command), controller?.handleKey(event) == true {
            shiftArmed = false
            return true
        }
        return super.performKeyEquivalent(with: event)
    }

    /// Lone Shift tap (press + release with nothing in between) toggles the color format.
    override func flagsChanged(with event: NSEvent) {
        let mods = event.modifierFlags.intersection([.shift, .command, .option, .control])
        let isShiftKey = event.keyCode == 56 || event.keyCode == 60
        if mods == .shift, isShiftKey {
            shiftArmed = true
        } else if mods.isEmpty, isShiftKey, shiftArmed {
            shiftArmed = false
            controller?.shiftTapped()
        } else {
            shiftArmed = false
        }
        super.flagsChanged(with: event)
    }
}
