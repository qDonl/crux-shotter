import CoreGraphics

public enum ResizeHandle: CaseIterable, Sendable {
    case topLeft, top, topRight, right, bottomRight, bottom, bottomLeft, left, arrowStart, arrowEnd
}

/// Pure resize geometry (image points, top-left origin). Only rect, mosaic and arrow are resizable.
public enum AnnotationResizer {
    public static let minimumSize: CGFloat = 2

    public static func handles(for a: Annotation) -> [(ResizeHandle, CGPoint)] {
        switch a.kind {
        case .rect(let r), .mosaic(let r, _):
            return [
                (.topLeft, CGPoint(x: r.minX, y: r.minY)), (.top, CGPoint(x: r.midX, y: r.minY)),
                (.topRight, CGPoint(x: r.maxX, y: r.minY)), (.right, CGPoint(x: r.maxX, y: r.midY)),
                (.bottomRight, CGPoint(x: r.maxX, y: r.maxY)), (.bottom, CGPoint(x: r.midX, y: r.maxY)),
                (.bottomLeft, CGPoint(x: r.minX, y: r.maxY)), (.left, CGPoint(x: r.minX, y: r.midY)),
            ]
        case .arrow(let f, let t):
            return [(.arrowStart, f), (.arrowEnd, t)]
        default:
            return []
        }
    }

    public static func handle(at point: CGPoint, for a: Annotation, tolerance: CGFloat = 6) -> ResizeHandle? {
        handles(for: a)
            .filter { abs($0.1.x - point.x) <= tolerance && abs($0.1.y - point.y) <= tolerance }
            .min { hypot($0.1.x - point.x, $0.1.y - point.y) < hypot($1.1.x - point.x, $1.1.y - point.y) }?.0
    }

    public static func resized(_ a: Annotation, handle: ResizeHandle, to p: CGPoint) -> Annotation {
        var copy = a
        switch a.kind {
        case .rect(let r): copy.kind = .rect(resize(r, handle, p))
        case .mosaic(let r, let m): copy.kind = .mosaic(resize(r, handle, p), m)
        case .arrow(let f, let t):
            if handle == .arrowStart { copy.kind = .arrow(from: p, to: t) }
            else if handle == .arrowEnd { copy.kind = .arrow(from: f, to: p) }
        default: break
        }
        return copy
    }

    private static func resize(_ r: CGRect, _ h: ResizeHandle, _ p: CGPoint) -> CGRect {
        var l = r.minX, rt = r.maxX, t = r.minY, b = r.maxY
        switch h {
        case .topLeft: l = p.x; t = p.y
        case .top: t = p.y
        case .topRight: rt = p.x; t = p.y
        case .right: rt = p.x
        case .bottomRight: rt = p.x; b = p.y
        case .bottom: b = p.y
        case .bottomLeft: l = p.x; b = p.y
        case .left: l = p.x
        default: break
        }
        return CGRect(x: min(l, rt), y: min(t, b),
                      width: max(abs(rt - l), minimumSize), height: max(abs(b - t), minimumSize))
    }
}
