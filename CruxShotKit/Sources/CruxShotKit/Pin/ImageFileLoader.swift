import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

/// Loads an image file copied in Finder for pinning. PDFs render their first page at `scale`;
/// other images honor EXIF orientation and are capped at `maxPixelSize` on the long side.
public enum ImageFileLoader {
    public static let maxPixelSize = 8192

    public static func load(_ url: URL, scale: CGFloat) -> CGImage? {
        if UTType(filenameExtension: url.pathExtension)?.conforms(to: .pdf) == true {
            return renderPDF(url, scale: scale)
        }
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let props = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let w = props[kCGImagePropertyPixelWidth] as? Int,
              let h = props[kCGImagePropertyPixelHeight] as? Int else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: min(max(w, h), maxPixelSize),
        ]
        return CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
    }

    private static func renderPDF(_ url: URL, scale: CGFloat) -> CGImage? {
        guard let page = CGPDFDocument(url as CFURL)?.page(at: 1) else { return nil }
        let box = page.getBoxRect(.cropBox)
        let rotated = abs(page.rotationAngle) % 180 == 90
        let points = rotated ? CGSize(width: box.height, height: box.width) : box.size
        let s = min(scale, CGFloat(maxPixelSize) / max(points.width, points.height, 1))
        let pw = max(1, Int((points.width * s).rounded())), ph = max(1, Int((points.height * s).rounded()))
        guard let ctx = CGContext(data: nil, width: pw, height: ph, bitsPerComponent: 8, bytesPerRow: 0,
                                  space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        ctx.setFillColor(CGColor(gray: 1, alpha: 1))
        ctx.fill(CGRect(x: 0, y: 0, width: pw, height: ph))
        ctx.scaleBy(x: CGFloat(pw) / points.width, y: CGFloat(ph) / points.height)
        ctx.concatenate(page.getDrawingTransform(.cropBox, rect: CGRect(origin: .zero, size: points),
                                                 rotate: 0, preserveAspectRatio: true))
        ctx.drawPDFPage(page)
        return ctx.makeImage()
    }
}
