import AppKit

/// Pixel loupe shown next to the cursor while selecting: a 15×15 pixel patch at 8× with a
/// grid and a center box, and three info lines below (pixel position, color, selection size).
@MainActor
final class MagnifierView: NSView {
    static let radius = 7
    static let zoom: CGFloat = 8
    static let loupeSide = CGFloat(radius * 2 + 1) * zoom  // 120pt
    static let lineHeight: CGFloat = 15
    static let infoHeight: CGFloat = lineHeight * 3 + 8
    static let cursorOffset: CGFloat = 20
    static let size = CGSize(width: loupeSide, height: loupeSide + infoHeight)

    private var patch: CGImage?
    private var lines: [String] = []

    override var isFlipped: Bool { true }

    init() { super.init(frame: CGRect(origin: .zero, size: Self.size)) }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    /// Never intercepts the mouse.
    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    func update(patch: CGImage?, position: String, color: String, size: String) {
        self.patch = patch
        lines = [position, color, size]
        needsDisplay = true
    }

    /// Places the loupe below-right of `cursor` (superview coordinates, y-up), flipping to the
    /// other side horizontally/vertically when it would leave `area`.
    func place(near cursor: CGPoint, in area: CGRect) {
        let s = Self.size, o = Self.cursorOffset
        var x = cursor.x + o
        if x + s.width > area.maxX { x = cursor.x - o - s.width }
        var y = cursor.y - o - s.height
        if y < area.minY { y = cursor.y + o }
        setFrameOrigin(CGPoint(x: x, y: y))
    }

    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        let side = Self.loupeSide, z = Self.zoom
        let loupe = CGRect(x: 0, y: 0, width: side, height: side)

        NSColor(white: 0.08, alpha: 0.92).setFill()
        NSBezierPath(roundedRect: bounds, xRadius: 6, yRadius: 6).fill()

        ctx.saveGState()
        ctx.clip(to: loupe)
        ctx.setFillColor(CGColor(gray: 0.2, alpha: 1))
        ctx.fill(loupe)
        if let patch {
            ctx.interpolationQuality = .none
            // The view is flipped; flip back so the image is upright.
            ctx.translateBy(x: 0, y: side)
            ctx.scaleBy(x: 1, y: -1)
            ctx.draw(patch, in: loupe)
        }
        ctx.restoreGState()

        // Grid
        ctx.setStrokeColor(CGColor(gray: 1, alpha: 0.15))
        ctx.setLineWidth(0.5)
        var i: CGFloat = z
        while i < side {
            ctx.move(to: CGPoint(x: i, y: 0)); ctx.addLine(to: CGPoint(x: i, y: side))
            ctx.move(to: CGPoint(x: 0, y: i)); ctx.addLine(to: CGPoint(x: side, y: i))
            i += z
        }
        ctx.strokePath()

        // Center pixel box: dark outline with a white inner line, visible on any color.
        let center = CGRect(x: CGFloat(Self.radius) * z, y: CGFloat(Self.radius) * z, width: z, height: z)
        ctx.setStrokeColor(CGColor(gray: 0, alpha: 1))
        ctx.setLineWidth(2)
        ctx.stroke(center.insetBy(dx: -1, dy: -1))
        ctx.setStrokeColor(CGColor(gray: 1, alpha: 1))
        ctx.setLineWidth(1)
        ctx.stroke(center.insetBy(dx: 0.5, dy: 0.5))

        ctx.setStrokeColor(CGColor(gray: 1, alpha: 0.6))
        ctx.stroke(loupe.insetBy(dx: 0.5, dy: 0.5))

        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .regular),
            .foregroundColor: NSColor.white,
        ]
        for (n, line) in lines.enumerated() {
            (line as NSString).draw(at: CGPoint(x: 6, y: side + 4 + CGFloat(n) * Self.lineHeight), withAttributes: attrs)
        }
    }
}
