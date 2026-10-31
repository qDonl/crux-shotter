import CoreGraphics

/// One geometry for rendering, selection bounds, hit testing, and toolbar previews.
/// Hand-drawn curves are deterministic: redraw/export never randomizes their shape.
struct ArrowGeometry {
    struct Stroke {
        let path: CGPath
        let width: CGFloat
        var dash: [CGFloat] = []
    }
    private(set) var strokes: [Stroke] = []
    private(set) var fills: [CGPath] = []

    init(from a: CGPoint, to b: CGPoint, style: ArrowStyle, lineWidth: CGFloat, bend: CGFloat = -0.18) {
        let length = hypot(b.x - a.x, b.y - a.y)
        guard a.x.isFinite, a.y.isFinite, b.x.isFinite, b.y.isFinite,
              length.isFinite, length > 0, lineWidth.isFinite, lineWidth > 0 else { return }
        let u = CGVector(dx: (b.x - a.x) / length, dy: (b.y - a.y) / length)
        let n = CGVector(dx: -u.dy, dy: u.dx)
        let width = min(lineWidth, max(0.5, length * 0.25))
        let headLength = min(max(4 * width, 12), length * (style == .doubleEnded ? 0.28 : 0.4))
        let halfHead = headLength * 0.5
        func shifted(_ p: CGPoint, along: CGFloat = 0, across: CGFloat = 0) -> CGPoint {
            CGPoint(x: p.x + u.dx * along + n.dx * across, y: p.y + u.dy * along + n.dy * across)
        }
        func head(at tip: CGPoint, direction: CGVector, open: Bool) -> CGPath {
            let base = CGPoint(x: tip.x - direction.dx * headLength, y: tip.y - direction.dy * headLength)
            let left = CGPoint(x: base.x - direction.dy * halfHead, y: base.y + direction.dx * halfHead)
            let right = CGPoint(x: base.x + direction.dy * halfHead, y: base.y - direction.dx * halfHead)
            return Self.path(open ? [left, tip, right] : [tip, left, right], closed: !open)
        }
        let base = shifted(b, along: -headLength)
        switch style {
        case .tapered:
            let tail = min(max(0.35, width * 0.13), halfHead * 0.35)
            let neck = min(width * 0.65, halfHead * 0.7)
            fills.append(Self.path([
                shifted(a, across: tail), shifted(base, across: neck), shifted(base, across: halfHead), b,
                shifted(base, across: -halfHead), shifted(base, across: -neck), shifted(a, across: -tail),
            ], closed: true))
        case .fine:
            let fineWidth = max(0.5, width * 0.65)
            strokes.append(Stroke(path: Self.path([a, b]), width: fineWidth))
            strokes.append(Stroke(path: head(at: b, direction: u, open: true), width: fineWidth))
        case .handDrawn:
            let safeBend = Self.clampedBend(bend)
            let jitter = min(3, width * 0.5, length * 0.02)
            let c1 = shifted(a, along: length / 3, across: safeBend * length * 4 / 3 + jitter)
            let c2 = shifted(a, along: length * 2 / 3, across: safeBend * length * 4 / 3 - jitter)
            let path = CGMutablePath()
            path.move(to: a)
            path.addCurve(to: b, control1: c1, control2: c2)
            let tangentLength = hypot(b.x - c2.x, b.y - c2.y)
            let tangent = CGVector(dx: (b.x - c2.x) / tangentLength, dy: (b.y - c2.y) / tangentLength)
            let penWidth = max(0.5, width * 0.72)
            strokes.append(Stroke(path: path, width: penWidth))
            strokes.append(Stroke(path: head(at: b, direction: tangent, open: true), width: penWidth))
        case .classic, .doubleEnded, .dashed:
            let start = style == .doubleEnded ? shifted(a, along: headLength * 0.8) : a
            let end = shifted(b, along: -headLength * 0.8)
            let dash: [CGFloat] = style == .dashed ? [max(2, width * 2.1), max(1.5, width * 1.65)] : []
            strokes.append(Stroke(path: Self.path([start, end]), width: width, dash: dash))
            fills.append(head(at: b, direction: u, open: false))
            if style == .doubleEnded {
                fills.append(head(at: a, direction: CGVector(dx: -u.dx, dy: -u.dy), open: false))
            }
        }
    }

    var bounds: CGRect {
        let paths = fills + strokes.map { $0.path.copy(strokingWithWidth: $0.width, lineCap: .round, lineJoin: .round, miterLimit: 10) }
        return paths.reduce(CGRect.null) { $0.union($1.boundingBoxOfPath) }
    }

    func contains(_ point: CGPoint, tolerance: CGFloat) -> Bool {
        let tolerance = max(0, tolerance)
        if fills.contains(where: { path in
            path.contains(point) || (tolerance > 0 && path.copy(strokingWithWidth: tolerance * 2,
                lineCap: .round, lineJoin: .round, miterLimit: 10).contains(point))
        }) { return true }
        // A dashed arrow remains easy to select between dashes, without treating its whole box as a hit.
        return strokes.contains { stroke in
            stroke.path.copy(strokingWithWidth: stroke.width + tolerance * 2,
                             lineCap: .round, lineJoin: .round, miterLimit: 10).contains(point)
        }
    }

    func draw(in context: CGContext) {
        context.setLineCap(.round)
        context.setLineJoin(.round)
        for stroke in strokes {
            context.setLineWidth(stroke.width)
            context.setLineDash(phase: 0, lengths: stroke.dash)
            context.addPath(stroke.path)
            context.strokePath()
        }
        context.setLineDash(phase: 0, lengths: [])
        for path in fills { context.addPath(path); context.fillPath() }
    }

    /// Midpoint of the cubic, also the user-facing bend handle.
    static func bendHandle(from a: CGPoint, to b: CGPoint, bend: CGFloat) -> CGPoint {
        let amount = clampedBend(bend)
        return CGPoint(x: (a.x + b.x) / 2 - (b.y - a.y) * amount,
                       y: (a.y + b.y) / 2 + (b.x - a.x) * amount)
    }

    static func bend(from a: CGPoint, to b: CGPoint, through p: CGPoint) -> CGFloat {
        let dx = b.x - a.x, dy = b.y - a.y, squared = dx * dx + dy * dy
        guard squared.isFinite, squared > 0 else { return 0 }
        return clampedBend(((p.x - (a.x + b.x) / 2) * -dy + (p.y - (a.y + b.y) / 2) * dx) / squared)
    }

    private static func clampedBend(_ bend: CGFloat) -> CGFloat { bend.isFinite ? max(-0.75, min(0.75, bend)) : 0 }

    private static func path(_ points: [CGPoint], closed: Bool = false) -> CGPath {
        let path = CGMutablePath()
        path.addLines(between: points)
        if closed { path.closeSubpath() }
        return path
    }
}
