import Foundation
import CoreGraphics
import CoreImage
import AppKit

public enum AnnotationRenderer {
    static let pixelateBlock: CGFloat = 12
    static let blurRadius: CGFloat = 10

    /// Shared; CIContext is thread-safe, but not annotated Sendable.
    nonisolated(unsafe) private static let ciContext: CIContext = {
        let space = CGColorSpace(name: CGColorSpace.sRGB)!
        return CIContext(options: [.workingColorSpace: space, .outputColorSpace: space])
    }()

    /// Draws `annotations` in order into `ctx`, whose user space must be image points with a
    /// top-left origin (the caller sets up the flip/scale). Mosaics always sample `source`.
    public static func draw(_ annotations: [Annotation], source: CGImage, scale: CGFloat, in ctx: CGContext) {
        for a in annotations {
            ctx.saveGState()
            drawOne(a, source: source, scale: scale, in: ctx)
            ctx.restoreGState()
        }
    }

    /// Renders the document into a bitmap of exactly `doc.image`'s pixel size.
    @MainActor
    public static func render(_ doc: AnnotationDocument) -> CGImage {
        let w = doc.image.width, h = doc.image.height
        let space = CGColorSpace(name: CGColorSpace.sRGB)!
        guard let ctx = CGContext(
            data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: 0, space: space,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        else { return doc.image }
        // Source first, in the context's native (bottom-left) space so it stays upright.
        ctx.draw(doc.image, in: CGRect(x: 0, y: 0, width: w, height: h))
        // Then flip to top-left origin and scale to points.
        ctx.translateBy(x: 0, y: CGFloat(h))
        ctx.scaleBy(x: doc.scale, y: -doc.scale)
        draw(doc.annotations, source: doc.image, scale: doc.scale, in: ctx)
        return ctx.makeImage() ?? doc.image
    }

    // MARK: - Drawing

    private static func drawOne(_ a: Annotation, source: CGImage, scale: CGFloat, in ctx: CGContext) {
        let color = a.style.color.cgColor
        let lw = a.style.lineWidth.rawValue
        ctx.setStrokeColor(color)
        ctx.setFillColor(color)
        ctx.setLineWidth(lw)
        ctx.setLineCap(.round)
        ctx.setLineJoin(.round)

        switch a.kind {
        case .rect(let r):
            ctx.stroke(r)
        case .arrow(let from, let to):
            drawArrow(from: from, to: to, lineWidth: lw, in: ctx)
        case .pen(let pts):
            guard let first = pts.first else { return }
            if pts.count == 1 {
                ctx.fillEllipse(in: CGRect(x: first.x - lw / 2, y: first.y - lw / 2, width: lw, height: lw))
            } else {
                ctx.addLines(between: pts)
                ctx.strokePath()
            }
        case .text(let origin, let string):
            drawText(string, at: origin, fontSize: a.style.fontSize, color: color, in: ctx)
        case .counter(let center, let number):
            let d = Annotation.counterDiameterFactor * a.style.fontSize
            ctx.fillEllipse(in: CGRect(x: center.x - d / 2, y: center.y - d / 2, width: d, height: d))
            drawCenteredNumber(number, at: center, fontSize: a.style.fontSize, in: ctx)
        case .mosaic(let rect, let mode):
            drawMosaic(rect, mode: mode, source: source, scale: scale, in: ctx)
        }
    }

    private static func drawArrow(from: CGPoint, to: CGPoint, lineWidth lw: CGFloat, in ctx: CGContext) {
        let dx = to.x - from.x, dy = to.y - from.y
        let len = hypot(dx, dy)
        guard len > 0 else { return }
        let ux = dx / len, uy = dy / len
        let headLen = min(max(4 * lw, 12), len)
        let halfWidth = max(4 * lw, 12) * 0.5
        let base = CGPoint(x: to.x - ux * headLen, y: to.y - uy * headLen)
        // Shaft stops inside the head so the tip stays sharp.
        let shaftEnd = CGPoint(x: to.x - ux * headLen * 0.8, y: to.y - uy * headLen * 0.8)
        ctx.move(to: from)
        ctx.addLine(to: shaftEnd)
        ctx.strokePath()
        ctx.move(to: to)
        ctx.addLine(to: CGPoint(x: base.x - uy * halfWidth, y: base.y + ux * halfWidth))
        ctx.addLine(to: CGPoint(x: base.x + uy * halfWidth, y: base.y - ux * halfWidth))
        ctx.closePath()
        ctx.fillPath()
    }

    /// The context is already top-left/flipped, so a flipped NSGraphicsContext keeps glyphs upright.
    private static func withFlippedGraphics(_ ctx: CGContext, _ body: () -> Void) {
        let previous = NSGraphicsContext.current
        NSGraphicsContext.current = NSGraphicsContext(cgContext: ctx, flipped: true)
        body()
        NSGraphicsContext.current = previous
    }

    private static func drawText(_ string: String, at origin: CGPoint, fontSize: CGFloat, color: CGColor, in ctx: CGContext) {
        let attrs: [NSAttributedString.Key: Any] = [
            .font: Annotation.textFont(size: fontSize),
            .foregroundColor: NSColor(cgColor: color) ?? NSColor.red,
        ]
        let str = NSAttributedString(string: string, attributes: attrs)
        let extent = Annotation.textLayoutExtent
        withFlippedGraphics(ctx) {
            // Huge layout width: never wraps; only explicit newlines break lines (same as the editor).
            str.draw(with: CGRect(x: origin.x, y: origin.y, width: extent, height: extent),
                     options: [.usesLineFragmentOrigin])
        }
    }

    private static func drawCenteredNumber(_ n: Int, at center: CGPoint, fontSize: CGFloat, in ctx: CGContext) {
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: fontSize, weight: .semibold),
            .foregroundColor: NSColor.white,
        ]
        let str = NSAttributedString(string: String(n), attributes: attrs)
        let size = str.size()
        withFlippedGraphics(ctx) {
            str.draw(at: CGPoint(x: center.x - size.width / 2, y: center.y - size.height / 2))
        }
    }

    // MARK: - Mosaic

    private static func drawMosaic(_ rect: CGRect, mode: MosaicMode, source: CGImage, scale: CGFloat, in ctx: CGContext) {
        // Pixel rect (top-left origin), snapped outward and clamped to the image.
        let full = CGRect(x: 0, y: 0, width: source.width, height: source.height)
        let px = CGRect(x: rect.minX * scale, y: rect.minY * scale,
                        width: rect.width * scale, height: rect.height * scale)
            .standardized.integral.intersection(full)
        guard !px.isNull, px.width >= 1, px.height >= 1, let crop = source.cropping(to: px) else { return }

        let ci = CIImage(cgImage: crop)
        let filtered: CIImage?
        switch mode {
        case .pixelate:
            let f = CIFilter(name: "CIPixellate")
            f?.setValue(ci, forKey: kCIInputImageKey)
            f?.setValue(pixelateBlock * scale, forKey: kCIInputScaleKey)
            // Blocks are anchored at `center` in CI space (origin bottom-left); using the crop's
            // origin anchors them at the crop's bottom-left, so only the top/right edge blocks can be partial.
            f?.setValue(CIVector(x: ci.extent.minX, y: ci.extent.minY), forKey: kCIInputCenterKey)
            filtered = f?.outputImage?.cropped(to: ci.extent)
        case .blur:
            let f = CIFilter(name: "CIGaussianBlur")
            f?.setValue(ci.clampedToExtent(), forKey: kCIInputImageKey)
            f?.setValue(blurRadius * scale, forKey: kCIInputRadiusKey)
            filtered = f?.outputImage?.cropped(to: ci.extent)
        }
        let cictx = ciContext
        guard let out = filtered, let result = cictx.createCGImage(out, from: ci.extent) else { return }

        // Draw back at the snapped location; local flip because ctx is top-left.
        let dest = CGRect(x: px.minX / scale, y: px.minY / scale, width: px.width / scale, height: px.height / scale)
        ctx.translateBy(x: dest.minX, y: dest.maxY)
        ctx.scaleBy(x: 1, y: -1)
        ctx.interpolationQuality = .none
        ctx.draw(result, in: CGRect(x: 0, y: 0, width: dest.width, height: dest.height))
    }
}
