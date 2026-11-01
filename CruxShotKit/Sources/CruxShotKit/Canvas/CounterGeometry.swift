import AppKit

/// One source of truth for counter drawing, bounds, hit testing and toolbar previews.
struct CounterGeometry {
    static let fontSize: CGFloat = 15
    static let strokeWidth: CGFloat = 1.5
    private static let backing = CGColor(srgbRed: 1, green: 0.992, blue: 0.986, alpha: 0.97)

    let center: CGPoint
    let number: Int
    let style: CounterStyle

    var bounds: CGRect {
        let digits = max(1, String(number).count)
        let size: CGSize
        switch style {
        case .preciseRing, .openRing:
            let diameter: CGFloat = switch digits {
            case 1: 27
            case 2: 35
            default: 44 + CGFloat(digits - 3) * 9
            }
            size = CGSize(width: diameter, height: diameter)
        case .baseline:
            let width: CGFloat = switch digits {
            case 1: 25
            case 2: 32
            default: 42 + CGFloat(digits - 3) * 9
            }
            size = CGSize(width: width, height: 29)
        }
        return CGRect(x: center.x - size.width / 2, y: center.y - size.height / 2,
                      width: size.width, height: size.height)
    }

    func draw(color: CGColor, in ctx: CGContext) {
        let frame = bounds
        ctx.saveGState()
        ctx.setFillColor(Self.backing)
        ctx.setStrokeColor(color)
        ctx.setLineWidth(Self.strokeWidth)
        ctx.setLineCap(.round)
        switch style {
        case .preciseRing:
            ctx.fillEllipse(in: frame)
            ctx.strokeEllipse(in: frame.insetBy(dx: Self.strokeWidth / 2, dy: Self.strokeWidth / 2))
        case .openRing:
            ctx.fillEllipse(in: frame)
            let radius = (frame.width - Self.strokeWidth) / 2
            let path = CGMutablePath()
            // y grows down in the annotation context; omit a small arc at the upper right.
            for step in 0...64 {
                let angle = (-25 + CGFloat(step) * 325 / 64) * .pi / 180
                let point = CGPoint(x: center.x + radius * cos(angle), y: center.y + radius * sin(angle))
                if step == 0 { path.move(to: point) } else { path.addLine(to: point) }
            }
            ctx.addPath(path)
            ctx.strokePath()
        case .baseline:
            let path = CGPath(roundedRect: frame, cornerWidth: 2, cornerHeight: 2, transform: nil)
            ctx.addPath(path)
            ctx.fillPath()
            ctx.move(to: CGPoint(x: frame.minX + 5, y: frame.maxY - 3.5))
            ctx.addLine(to: CGPoint(x: frame.maxX - 5, y: frame.maxY - 3.5))
            ctx.strokePath()
        }
        let font = NSFont.systemFont(ofSize: Self.fontSize, weight: .semibold)
        let text = NSAttributedString(string: String(number), attributes: [
            .font: font, .foregroundColor: NSColor(cgColor: color) ?? .red,
        ])
        let size = text.size()
        let previous = NSGraphicsContext.current
        NSGraphicsContext.current = NSGraphicsContext(cgContext: ctx, flipped: true)
        let shift: CGFloat = style == .baseline ? -2.5 : 0
        text.draw(at: CGPoint(x: center.x - size.width / 2,
                              y: center.y - size.height / 2 + shift))
        NSGraphicsContext.current = previous
        ctx.restoreGState()
    }
}
