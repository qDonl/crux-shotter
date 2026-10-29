import AppKit

/// Renders a copied color value as a card: a swatch (over a checkerboard when translucent)
/// with the HEX and RGB strings underneath.
public enum ColorCardRenderer {
    static let width: CGFloat = 240
    static let padding: CGFloat = 12
    static let swatchHeight: CGFloat = 100

    public static func render(_ color: ColorLiteral, dark: Bool, scale: CGFloat) -> CGImage {
        let fg = NSColor(cgColor: TextCardRenderer.rgb(dark ? 0xE5E5E5 : 0x1C1C1E))!
        let label = NSAttributedString(string: color.hexString + "\n" + color.rgbString, attributes: [
            .font: NSFont.monospacedSystemFont(ofSize: 13, weight: .regular), .foregroundColor: fg])
        let inner = width - padding * 2
        let labelHeight = ceil(label.boundingRect(with: CGSize(width: inner, height: .greatestFiniteMagnitude),
                                                  options: [.usesLineFragmentOrigin, .usesFontLeading]).height)
        let size = CGSize(width: width, height: padding * 3 + swatchHeight + labelHeight)
        let ctx = TextCardRenderer.makeContext(size: size, scale: scale)
        TextCardRenderer.fillCard(ctx, size: size,
                                  color: dark ? TextCardRenderer.darkBackground : TextCardRenderer.lightBackground)

        // y-up: the label sits at the bottom, the swatch above it.
        let swatch = CGRect(x: padding, y: padding * 2 + labelHeight, width: inner, height: swatchHeight)
        let path = CGPath(roundedRect: swatch, cornerWidth: 6, cornerHeight: 6, transform: nil)
        ctx.saveGState()
        ctx.addPath(path)
        ctx.clip()
        if color.alpha < 1 { drawCheckerboard(in: swatch, context: ctx) }
        ctx.setFillColor(CGColor(srgbRed: CGFloat(color.rgb.r) / 255, green: CGFloat(color.rgb.g) / 255,
                                 blue: CGFloat(color.rgb.b) / 255, alpha: color.alpha))
        ctx.fill(swatch)
        ctx.restoreGState()
        // Hairline so white-on-white and black-on-black swatches stay visible.
        ctx.addPath(path)
        ctx.setStrokeColor(CGColor(gray: 0.5, alpha: 0.35))
        ctx.setLineWidth(1)
        ctx.strokePath()

        TextCardRenderer.drawText(label, in: CGRect(x: padding, y: padding, width: inner, height: labelHeight), context: ctx)
        return ctx.makeImage()!
    }

    private static func drawCheckerboard(in rect: CGRect, context ctx: CGContext) {
        let cell: CGFloat = 8
        ctx.setFillColor(CGColor(gray: 1, alpha: 1))
        ctx.fill(rect)
        ctx.setFillColor(CGColor(gray: 0.8, alpha: 1))
        var y = rect.minY, row = 0
        while y < rect.maxY {
            var x = rect.minX + (row % 2 == 0 ? 0 : cell)
            while x < rect.maxX {
                ctx.fill(CGRect(x: x, y: y, width: cell, height: cell))
                x += cell * 2
            }
            y += cell
            row += 1
        }
    }
}
