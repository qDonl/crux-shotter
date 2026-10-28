import AppKit
import CoreText

public enum TextCardRenderer {
    public static let maxLines = 80
    public static let maxLineLength = 300
    static let padding: CGFloat = 16
    static let cornerRadius: CGFloat = 10

    public static func render(_ text: String, dark: Bool, scale: CGFloat) -> CGImage {
        let normalized = text.replacingOccurrences(of: "\r\n", with: "\n").replacingOccurrences(of: "\r", with: "\n")
        var lines = normalized.split(separator: "\n", omittingEmptySubsequences: false).map { raw -> String in
            let s = raw.replacingOccurrences(of: "\t", with: "    ")
            return s.count > maxLineLength ? String(s.prefix(maxLineLength)) + "…" : s
        }
        let total = lines.count
        if total > maxLines {
            lines = Array(lines.prefix(maxLines)) + ["…（共 \(total) 行）"]
        }

        let font = NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)
        let fg = dark ? rgb(0xE5E5E5) : rgb(0x1C1C1E)
        let bg = dark ? rgb(0x1E1E1E) : rgb(0xFFFFFF)
        let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: fg]
        let ctLines = lines.map { CTLineCreateWithAttributedString(NSAttributedString(string: $0, attributes: attrs)) }

        let lineHeight = ceil(font.ascender - font.descender + font.leading)
        let textWidth = ctLines.map { CTLineGetTypographicBounds($0, nil, nil, nil) }.max() ?? 0
        let size = CGSize(width: ceil(textWidth) + padding * 2, height: lineHeight * CGFloat(lines.count) + padding * 2)

        let pw = max(1, Int((size.width * scale).rounded()))
        let ph = max(1, Int((size.height * scale).rounded()))
        let ctx = CGContext(data: nil, width: pw, height: ph, bitsPerComponent: 8, bytesPerRow: 0,
                            space: CGColorSpace(name: CGColorSpace.sRGB)!,
                            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        ctx.scaleBy(x: CGFloat(pw) / size.width, y: CGFloat(ph) / size.height)
        ctx.addPath(CGPath(roundedRect: CGRect(origin: .zero, size: size), cornerWidth: cornerRadius, cornerHeight: cornerRadius, transform: nil))
        ctx.setFillColor(bg)
        ctx.fillPath()

        for (i, line) in ctLines.enumerated() {
            let baselineY = size.height - padding - CGFloat(i) * lineHeight - font.ascender
            ctx.textPosition = CGPoint(x: padding, y: baselineY)
            CTLineDraw(line, ctx)
        }
        return ctx.makeImage()!
    }

    private static func rgb(_ hex: UInt32) -> CGColor {
        CGColor(colorSpace: CGColorSpace(name: CGColorSpace.sRGB)!, components: [
            CGFloat((hex >> 16) & 0xFF) / 255, CGFloat((hex >> 8) & 0xFF) / 255, CGFloat(hex & 0xFF) / 255, 1])!
    }
}
