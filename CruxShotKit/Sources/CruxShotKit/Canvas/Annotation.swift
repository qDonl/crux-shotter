import Foundation
import CoreGraphics
import AppKit

public enum PaletteColor: String, CaseIterable, Sendable {
    case red, orange, yellow, green, blue, black

    public var cgColor: CGColor {
        let hex: UInt32
        switch self {
        case .red: hex = 0xFF3B30
        case .orange: hex = 0xFF9500
        case .yellow: hex = 0xFFCC00
        case .green: hex = 0x34C759
        case .blue: hex = 0x007AFF
        case .black: hex = 0x1C1C1E
        }
        let space = CGColorSpace(name: CGColorSpace.sRGB)!
        return CGColor(colorSpace: space, components: [
            CGFloat((hex >> 16) & 0xFF) / 255,
            CGFloat((hex >> 8) & 0xFF) / 255,
            CGFloat(hex & 0xFF) / 255,
            1,
        ])!
    }
}

public enum LineWidth: CGFloat, CaseIterable, Sendable {
    case one = 1, thin = 2, three = 3, medium = 4, five = 5, six = 6
    case seven = 7, thick = 8, nine = 9, ten = 10, eleven = 11, twelve = 12

    public func stepped(by delta: Int) -> LineWidth {
        LineWidth(rawValue: CGFloat(min(12, max(1, Int(rawValue) + delta)))) ?? self
    }
}

public struct AnnotationStyle: Sendable, Equatable {
    public var color: PaletteColor
    public var lineWidth: LineWidth
    public var fontSize: CGFloat
    public var arrowStyle: ArrowStyle
    public var counterStyle: CounterStyle

    public init(color: PaletteColor = .red, lineWidth: LineWidth = .medium, fontSize: CGFloat = 18,
                arrowStyle: ArrowStyle = .classic, counterStyle: CounterStyle = .preciseRing) {
        self.color = color
        self.lineWidth = lineWidth
        self.fontSize = fontSize
        self.arrowStyle = arrowStyle
        self.counterStyle = counterStyle
    }
}

public enum MosaicMode: String, Sendable {
    case pixelate, blur
}

public enum AnnotationKind: Sendable, Equatable {
    case rect(CGRect)
    case arrow(from: CGPoint, to: CGPoint)
    case pen([CGPoint])
    case text(origin: CGPoint, string: String)
    case counter(center: CGPoint, number: Int)
    case mosaic(CGRect, MosaicMode)
}

public struct Annotation: Identifiable, Sendable, Equatable {
    public let id: UUID
    public var kind: AnnotationKind
    public var style: AnnotationStyle
    /// Signed curvature relative to arrow length; only used by hand-drawn arrows.
    public var arrowBend: CGFloat

    public init(id: UUID = UUID(), kind: AnnotationKind, style: AnnotationStyle = AnnotationStyle(), arrowBend: CGFloat = -0.18) {
        self.id = id
        self.kind = kind
        self.style = style
        self.arrowBend = arrowBend
    }

    /// Text annotation font; shared by the renderer, `bounds` and the in-place editor.
    static func textFont(size: CGFloat) -> NSFont { .systemFont(ofSize: size, weight: .semibold) }

    /// Size of a text annotation exactly as `AnnotationRenderer` lays it out: no wrapping, only
    /// explicit newlines break lines.
    static func textSize(_ string: String, fontSize: CGFloat) -> CGSize {
        let font = textFont(size: fontSize)
        let lineHeight = ceil(font.ascender - font.descender + font.leading)
        guard !string.isEmpty else { return CGSize(width: 0, height: lineHeight) }
        let r = NSAttributedString(string: string, attributes: [.font: font]).boundingRect(
            with: CGSize(width: textLayoutExtent, height: textLayoutExtent), options: [.usesLineFragmentOrigin])
        return CGSize(width: ceil(r.width), height: max(ceil(r.height), lineHeight))
    }

    /// Layout width/height large enough that text never wraps (renderer and editor).
    static let textLayoutExtent: CGFloat = 10_000

    public func translated(by v: CGVector) -> Annotation {
        func p(_ pt: CGPoint) -> CGPoint { CGPoint(x: pt.x + v.dx, y: pt.y + v.dy) }
        var copy = self
        switch kind {
        case .rect(let r): copy.kind = .rect(r.offsetBy(dx: v.dx, dy: v.dy))
        case .arrow(let a, let b): copy.kind = .arrow(from: p(a), to: p(b))
        case .pen(let pts): copy.kind = .pen(pts.map(p))
        case .text(let o, let s): copy.kind = .text(origin: p(o), string: s)
        case .counter(let c, let n): copy.kind = .counter(center: p(c), number: n)
        case .mosaic(let r, let m): copy.kind = .mosaic(r.offsetBy(dx: v.dx, dy: v.dy), m)
        }
        return copy
    }

    /// Bounds in image coordinates (points, top-left origin). Arrows include their visible heads and strokes.
    public var bounds: CGRect {
        switch kind {
        case .rect(let r), .mosaic(let r, _):
            return r
        case .arrow(let a, let b):
            let bounds = ArrowGeometry(from: a, to: b, style: style.arrowStyle,
                                       lineWidth: style.lineWidth.rawValue, bend: arrowBend).bounds
            return bounds.isNull ? CGRect(origin: a, size: .zero) : bounds
        case .pen(let pts):
            return Self.box(of: pts)
        case .text(let o, let s):
            let size = Self.textSize(s, fontSize: style.fontSize)
            return CGRect(x: o.x, y: o.y, width: max(size.width, 1), height: size.height)
        case .counter(let c, let n):
            return CounterGeometry(center: c, number: n, style: style.counterStyle).bounds
        }
    }

    var counterNumber: Int? {
        if case .counter(_, let n) = kind { return n }
        return nil
    }

    private static func box(of pts: [CGPoint]) -> CGRect {
        guard let first = pts.first else { return .zero }
        var minX = first.x, maxX = first.x, minY = first.y, maxY = first.y
        for p in pts.dropFirst() {
            minX = min(minX, p.x); maxX = max(maxX, p.x)
            minY = min(minY, p.y); maxY = max(maxY, p.y)
        }
        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }
}
