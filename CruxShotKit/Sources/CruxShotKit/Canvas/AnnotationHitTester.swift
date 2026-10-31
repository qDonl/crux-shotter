import CoreGraphics

public enum AnnotationHitTester {
    /// Topmost (last) annotation under `point`, or nil.
    public static func hit(_ point: CGPoint, in annotations: [Annotation], tolerance: CGFloat = 6) -> Annotation.ID? {
        annotations.last { hits($0, point, tolerance: tolerance) }?.id
    }

    /// Cycle through stacked marks at the last clicked point, front to back.
    public static func cycle(_ point: CGPoint, in annotations: [Annotation],
                             current: Annotation.ID?, backwards: Bool = false,
                             tolerance: CGFloat = 6) -> Annotation.ID? {
        let matches = annotations.reversed().filter { hits($0, point, tolerance: tolerance) }.map(\.id)
        guard !matches.isEmpty else { return nil }
        guard let current, let index = matches.firstIndex(of: current) else { return matches[0] }
        let next = backwards ? (index + matches.count - 1) % matches.count : (index + 1) % matches.count
        return matches[next]
    }

    static func hits(_ a: Annotation, _ p: CGPoint, tolerance: CGFloat) -> Bool {
        let reach = tolerance + a.style.lineWidth.rawValue / 2
        switch a.kind {
        case .rect(let r):
            let outer = r.insetBy(dx: -reach, dy: -reach)
            let inner = r.insetBy(dx: reach, dy: reach)
            guard outer.contains(p) else { return false }
            return inner.width <= 0 || inner.height <= 0 || !inner.contains(p)
        case .mosaic(let r, _):
            return r.contains(p)
        case .arrow(let from, let to):
            return ArrowGeometry(from: from, to: to, style: a.style.arrowStyle,
                                 lineWidth: a.style.lineWidth.rawValue, bend: a.arrowBend).contains(p, tolerance: tolerance)
        case .pen(let pts):
            if pts.count == 1 { return hypot(p.x - pts[0].x, p.y - pts[0].y) <= reach }
            return zip(pts, pts.dropFirst()).contains { distance(from: p, toSegment: $0, $1) <= reach }
        case .text, .counter:
            return a.bounds.contains(p)
        }
    }

    static func distance(from p: CGPoint, toSegment a: CGPoint, _ b: CGPoint) -> CGFloat {
        let dx = b.x - a.x, dy = b.y - a.y
        let lenSq = dx * dx + dy * dy
        guard lenSq > 0 else { return hypot(p.x - a.x, p.y - a.y) }
        let t = max(0, min(1, ((p.x - a.x) * dx + (p.y - a.y) * dy) / lenSq))
        return hypot(p.x - (a.x + t * dx), p.y - (a.y + t * dy))
    }
}
