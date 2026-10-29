import Foundation

/// A color written as text (`#RGB[A]`, `#RRGGBB[AA]`, `rgb()/rgba()`, `hsl()/hsla()`), parsed only
/// when the whole string is a single color so ordinary text is never mistaken for one.
public struct ColorLiteral: Sendable, Equatable {
    public var rgb: RGBColor
    /// 0...1
    public var alpha: Double

    public init(rgb: RGBColor, alpha: Double) {
        self.rgb = rgb
        self.alpha = alpha
    }

    public var hexString: String {
        let base = ColorFormat.hex.string(for: rgb)
        guard alpha < 1 else { return base }
        let a = String(UInt8((alpha * 255).rounded()), radix: 16, uppercase: true)
        return base + (a.count == 1 ? "0" + a : a)
    }

    public var rgbString: String {
        guard alpha < 1 else { return ColorFormat.rgb.string(for: rgb) }
        let a = (alpha * 100).rounded() / 100
        let text = a == a.rounded() ? String(Int(a)) : String(format: "%g", a)
        return "rgba(\(rgb.r), \(rgb.g), \(rgb.b), \(text))"
    }

    public static func parse(_ text: String) -> ColorLiteral? {
        let s = text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !s.isEmpty, s.count <= 64 else { return nil }
        if s.hasPrefix("#") { return parseHex(s.dropFirst()) }
        guard let open = s.firstIndex(of: "("), s.hasSuffix(")") else { return nil }
        let name = s[..<open].trimmingCharacters(in: .whitespaces)
        let parts = s[s.index(after: open)..<s.index(before: s.endIndex)]
            .split(whereSeparator: { $0 == "," || $0 == " " || $0 == "/" }).map(String.init)
        switch name {
        case "rgb", "rgba": return parseRGB(parts)
        case "hsl", "hsla": return parseHSL(parts)
        default: return nil
        }
    }

    private static func parseHex(_ digits: Substring) -> ColorLiteral? {
        guard [3, 4, 6, 8].contains(digits.count), digits.allSatisfy(\.isHexDigit) else { return nil }
        let expanded = digits.count <= 4 ? String(digits.flatMap { [$0, $0] }) : String(digits)
        var bytes: [UInt8] = []
        var i = expanded.startIndex
        while i < expanded.endIndex {
            let j = expanded.index(i, offsetBy: 2)
            bytes.append(UInt8(expanded[i..<j], radix: 16)!)
            i = j
        }
        return ColorLiteral(rgb: RGBColor(r: bytes[0], g: bytes[1], b: bytes[2]),
                            alpha: bytes.count == 4 ? Double(bytes[3]) / 255 : 1)
    }

    private static func parseRGB(_ parts: [String]) -> ColorLiteral? {
        guard parts.count == 3 || parts.count == 4 else { return nil }
        var channels: [UInt8] = []
        for p in parts.prefix(3) {
            let value: Double
            if p.hasSuffix("%") {
                guard let pct = Double(p.dropLast()), (0...100).contains(pct) else { return nil }
                value = pct * 255 / 100
            } else {
                guard let v = Double(p), (0...255).contains(v) else { return nil }
                value = v
            }
            channels.append(UInt8(value.rounded()))
        }
        guard let alpha = parseAlpha(parts.count == 4 ? parts[3] : nil) else { return nil }
        return ColorLiteral(rgb: RGBColor(r: channels[0], g: channels[1], b: channels[2]), alpha: alpha)
    }

    private static func parseHSL(_ parts: [String]) -> ColorLiteral? {
        guard parts.count == 3 || parts.count == 4,
              let h = Double(parts[0].hasSuffix("deg") ? String(parts[0].dropLast(3)) : parts[0]),
              parts[1].hasSuffix("%"), parts[2].hasSuffix("%"),
              let s = Double(parts[1].dropLast()), let l = Double(parts[2].dropLast()),
              (0...100).contains(s), (0...100).contains(l),
              let alpha = parseAlpha(parts.count == 4 ? parts[3] : nil) else { return nil }
        let hue = (h.truncatingRemainder(dividingBy: 360) + 360).truncatingRemainder(dividingBy: 360) / 360
        let sat = s / 100, light = l / 100
        let q = light < 0.5 ? light * (1 + sat) : light + sat - light * sat
        let p = 2 * light - q
        func channel(_ t0: Double) -> UInt8 {
            var t = t0
            if t < 0 { t += 1 }
            if t > 1 { t -= 1 }
            let v: Double
            if t < 1.0 / 6 { v = p + (q - p) * 6 * t }
            else if t < 0.5 { v = q }
            else if t < 2.0 / 3 { v = p + (q - p) * (2.0 / 3 - t) * 6 }
            else { v = p }
            return UInt8((v * 255).rounded())
        }
        return ColorLiteral(rgb: RGBColor(r: channel(hue + 1.0 / 3), g: channel(hue), b: channel(hue - 1.0 / 3)),
                            alpha: alpha)
    }

    /// Nil part means opaque; nil result means malformed.
    private static func parseAlpha(_ part: String?) -> Double? {
        guard let part else { return 1 }
        if part.hasSuffix("%") {
            guard let pct = Double(part.dropLast()), (0...100).contains(pct) else { return nil }
            return pct / 100
        }
        guard let a = Double(part), (0...1).contains(a) else { return nil }
        return a
    }
}
