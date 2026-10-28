public struct RGBColor: Sendable, Equatable {
    public var r: UInt8
    public var g: UInt8
    public var b: UInt8

    public init(r: UInt8, g: UInt8, b: UInt8) {
        self.r = r
        self.g = g
        self.b = b
    }
}

public enum ColorFormat: String, Sendable, CaseIterable {
    case hex, rgb

    public func string(for color: RGBColor) -> String {
        switch self {
        case .hex:
            func h(_ v: UInt8) -> String {
                let s = String(v, radix: 16, uppercase: true)
                return s.count == 1 ? "0" + s : s
            }
            return "#" + h(color.r) + h(color.g) + h(color.b)
        case .rgb:
            return "rgb(\(color.r), \(color.g), \(color.b))"
        }
    }

    public var toggled: ColorFormat { self == .hex ? .rgb : .hex }
}
