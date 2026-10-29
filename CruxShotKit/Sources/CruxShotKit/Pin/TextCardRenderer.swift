import AppKit

/// Renders clipboard text into a rounded card image. Lines wrap at `maxTextWidth`; at most
/// `maxLines` lines are kept, followed by a "…（共 N 行）" marker.
public enum TextCardRenderer {
    public static let maxLines = 80
    public static let maxLineLength = 300
    public static let maxTextWidth: CGFloat = 640
    static let padding: CGFloat = 16
    static let cornerRadius: CGFloat = 10
    static let lightBackground = rgb(0xFFFFFF)
    static let darkBackground = rgb(0x1E1E1E)

    /// Plain text: monospaced for code-like text, system font otherwise; colors follow `dark`.
    public static func render(_ text: String, dark: Bool, scale: CGFloat) -> CGImage {
        let (head, total) = truncatedLines(of: text.replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n"))
        let lines = head.map { raw -> String in
            let s = String(raw.prefix(maxLineLength + 1)).replacingOccurrences(of: "\t", with: "    ")
            return s.count > maxLineLength ? String(s.prefix(maxLineLength)) + "…" : s
        }
        let joined = lines.joined(separator: "\n")
        let font = isCodeLike(joined) ? NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)
                                      : NSFont.systemFont(ofSize: 14)
        let fg = NSColor(cgColor: dark ? rgb(0xE5E5E5) : rgb(0x1C1C1E))!
        let result = NSMutableAttributedString(string: joined, attributes: [.font: font, .foregroundColor: fg])
        if total > maxLines { appendMore(total, to: result, color: fg) }
        return draw(result, background: dark ? darkBackground : lightBackground, scale: scale)
    }

    /// Rich text keeps its own fonts and colors. The card is white unless most of the text is
    /// light-colored (e.g. copied from a dark-theme editor), in which case it is dark.
    public static func renderRich(_ text: NSAttributedString, scale: CGFloat) -> CGImage {
        let dark = isMostlyLight(text)
        let (head, total) = truncatedLines(of: text.string)
        let keep = head.reduce(0) { $0 + $1.utf16.count } + max(0, head.count - 1)
        let result = NSMutableAttributedString(attributedString: text.attributedSubstring(
            from: NSRange(location: 0, length: min(keep, text.length))))
        let fallback = NSColor(cgColor: dark ? rgb(0xE5E5E5) : rgb(0x1C1C1E))!
        result.enumerateAttribute(.foregroundColor, in: NSRange(location: 0, length: result.length)) { value, range, _ in
            if value == nil { result.addAttribute(.foregroundColor, value: fallback, range: range) }
        }
        if total > maxLines { appendMore(total, to: result, color: fallback) }
        return draw(result, background: dark ? darkBackground : lightBackground, scale: scale)
    }

    /// Indented lines or lines ending in `{`, `}` or `;` read as code.
    static func isCodeLike(_ text: String) -> Bool {
        text.split(separator: "\n").contains { line in
            if line.hasPrefix("\t") || line.hasPrefix("  ") { return true }
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            return ["{", "}", ";"].contains { trimmed.hasSuffix($0) }
        }
    }

    // MARK: Drawing

    static func makeContext(size: CGSize, scale: CGFloat) -> CGContext {
        let pw = max(1, Int((size.width * scale).rounded()))
        let ph = max(1, Int((size.height * scale).rounded()))
        let ctx = CGContext(data: nil, width: pw, height: ph, bitsPerComponent: 8, bytesPerRow: 0,
                            space: CGColorSpace(name: CGColorSpace.sRGB)!,
                            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        ctx.scaleBy(x: CGFloat(pw) / size.width, y: CGFloat(ph) / size.height)
        return ctx
    }

    static func fillCard(_ ctx: CGContext, size: CGSize, color: CGColor) {
        ctx.addPath(CGPath(roundedRect: CGRect(origin: .zero, size: size), cornerWidth: cornerRadius,
                           cornerHeight: cornerRadius, transform: nil))
        ctx.setFillColor(color)
        ctx.fillPath()
    }

    /// Draws `text` with AppKit into a y-up context; `rect` is in that context's coordinates.
    static func drawText(_ text: NSAttributedString, in rect: CGRect, context ctx: CGContext) {
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(cgContext: ctx, flipped: false)
        text.draw(with: rect, options: [.usesLineFragmentOrigin, .usesFontLeading])
        NSGraphicsContext.restoreGraphicsState()
    }

    private static func draw(_ text: NSAttributedString, background: CGColor, scale: CGFloat) -> CGImage {
        let bounds = text.boundingRect(with: CGSize(width: maxTextWidth, height: .greatestFiniteMagnitude),
                                       options: [.usesLineFragmentOrigin, .usesFontLeading])
        let textSize = CGSize(width: min(ceil(bounds.width), maxTextWidth), height: ceil(bounds.height))
        let size = CGSize(width: textSize.width + padding * 2, height: textSize.height + padding * 2)
        let ctx = makeContext(size: size, scale: scale)
        fillCard(ctx, size: size, color: background)
        drawText(text, in: CGRect(origin: CGPoint(x: padding, y: padding), size: textSize), context: ctx)
        return ctx.makeImage()!
    }

    // MARK: Helpers

    /// The first `maxLines` lines and the total line count.
    private static func truncatedLines(of text: String) -> ([Substring], Int) {
        let total = text.utf8.reduce(1) { $1 == 0x0A ? $0 + 1 : $0 }
        let head = text.split(separator: "\n", maxSplits: maxLines, omittingEmptySubsequences: false).prefix(maxLines)
        return (Array(head), total)
    }

    private static func appendMore(_ total: Int, to text: NSMutableAttributedString, color: NSColor) {
        text.append(NSAttributedString(string: "\n…（共 \(total) 行）", attributes: [
            .font: NSFont.systemFont(ofSize: 12), .foregroundColor: color.withAlphaComponent(0.6)]))
    }

    /// True when more than half of the explicitly colored characters are light (luminance > 0.6).
    private static func isMostlyLight(_ text: NSAttributedString) -> Bool {
        var light = 0, colored = 0
        text.enumerateAttribute(.foregroundColor, in: NSRange(location: 0, length: text.length)) { value, range, _ in
            guard let color = (value as? NSColor)?.usingColorSpace(.sRGB) else { return }
            colored += range.length
            let luminance = 0.2126 * color.redComponent + 0.7152 * color.greenComponent + 0.0722 * color.blueComponent
            if luminance > 0.6 { light += range.length }
        }
        return colored > 0 && light * 2 > colored
    }

    static func rgb(_ hex: UInt32) -> CGColor {
        CGColor(colorSpace: CGColorSpace(name: CGColorSpace.sRGB)!, components: [
            CGFloat((hex >> 16) & 0xFF) / 255, CGFloat((hex >> 8) & 0xFF) / 255, CGFloat(hex & 0xFF) / 255, 1])!
    }
}
