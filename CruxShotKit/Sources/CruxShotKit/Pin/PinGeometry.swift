import CoreGraphics
import AppKit

/// Pure frame/orientation math for pin windows.
public enum PinGeometry {
    /// Resizes `frame` to `newSize` keeping `anchor` (same coordinate space as `frame`) at the
    /// same relative position, so the image point under the cursor stays put on screen.
    /// An anchor outside the frame is clamped to it.
    public static func zoomedFrame(_ frame: CGRect, to newSize: CGSize, anchor: CGPoint) -> CGRect {
        guard frame.width > 0, frame.height > 0 else { return CGRect(origin: frame.origin, size: newSize) }
        let fx = min(max((anchor.x - frame.minX) / frame.width, 0), 1)
        let fy = min(max((anchor.y - frame.minY) / frame.height, 0), 1)
        let ax = frame.minX + fx * frame.width, ay = frame.minY + fy * frame.height
        return CGRect(x: ax - fx * newSize.width, y: ay - fy * newSize.height,
                      width: newSize.width, height: newSize.height)
    }

    /// Image size in points (pixels / backing scale).
    public static func pointSize(of image: CGImage, scale: CGFloat) -> CGSize {
        let s = scale > 0 ? scale : 1
        return CGSize(width: CGFloat(image.width) / s, height: CGFloat(image.height) / s)
    }

    /// Maps the rect `(0, 0, size)` of the upright image onto the oriented output rect, in a
    /// y-up coordinate system: first `quarterTurns` clockwise rotations, then flips in the
    /// rotated (on-screen) space, so H always mirrors left/right as seen.
    public static func orientation(_ t: PinTransform, size: CGSize) -> CGAffineTransform {
        var result = CGAffineTransform.identity
        var w = size.width, h = size.height
        for _ in 0..<((t.quarterTurns % 4 + 4) % 4) {
            // Visual clockwise turn in y-up space: (x, y) -> (y, w - x).
            result = result.concatenating(CGAffineTransform(a: 0, b: -1, c: 1, d: 0, tx: 0, ty: w))
            swap(&w, &h)
        }
        if t.flippedH { result = result.concatenating(CGAffineTransform(a: -1, b: 0, c: 0, d: 1, tx: w, ty: 0)) }
        if t.flippedV { result = result.concatenating(CGAffineTransform(a: 1, b: 0, c: 0, d: -1, tx: 0, ty: h)) }
        return result
    }

    static func orientedSize(_ t: PinTransform, size: CGSize) -> CGSize {
        t.quarterTurns % 2 == 0 ? size : CGSize(width: size.height, height: size.width)
    }

    static func hasOrientation(_ t: PinTransform) -> Bool {
        t.quarterTurns % 4 != 0 || t.flippedH || t.flippedV
    }
}

public extension PinItem {
    /// Image with annotations drawn on it, at the image's pixel size (no rotation/flip).
    func annotatedImage() -> CGImage {
        guard !annotations.isEmpty else { return image }
        let w = image.width, h = image.height
        guard let ctx = PinItem.bitmap(width: w, height: h) else { return image }
        ctx.draw(image, in: CGRect(x: 0, y: 0, width: w, height: h))
        ctx.translateBy(x: 0, y: CGFloat(h))
        ctx.scaleBy(x: imageScale, y: -imageScale)
        AnnotationRenderer.draw(annotations, source: image, scale: imageScale, in: ctx)
        return ctx.makeImage() ?? image
    }

    /// Final image used for copy / save / OCR: annotations, then rotation and flips.
    /// Pixel size is the rotated image pixel size; the pin's zoom is not applied.
    func composedImage() -> CGImage {
        let base = annotatedImage()
        guard PinGeometry.hasOrientation(transform) else { return base }
        let src = CGSize(width: base.width, height: base.height)
        let out = PinGeometry.orientedSize(transform, size: src)
        guard let ctx = PinItem.bitmap(width: Int(out.width), height: Int(out.height)) else { return base }
        ctx.interpolationQuality = .none
        ctx.concatenate(PinGeometry.orientation(transform, size: src))
        ctx.draw(base, in: CGRect(origin: .zero, size: src))
        return ctx.makeImage() ?? base
    }

    private static func bitmap(width: Int, height: Int) -> CGContext? {
        CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                  space: CGColorSpace(name: CGColorSpace.sRGB)!,
                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
    }
}
