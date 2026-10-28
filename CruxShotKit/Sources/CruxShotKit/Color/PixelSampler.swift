import Foundation
import CoreGraphics

/// Reads pixels from an image. The image is drawn once into an sRGB, 8-bit,
/// premultiplied RGBA buffer; coordinates are pixels with a top-left origin.
public struct PixelSampler {
    public let width: Int
    public let height: Int
    private let buffer: [UInt8]  // premultiplied RGBA, row 0 = top

    public init(image: CGImage) {
        let w = image.width, h = image.height
        var buf = [UInt8](repeating: 0, count: max(w * h * 4, 0))
        if w > 0, h > 0, let space = CGColorSpace(name: CGColorSpace.sRGB) {
            buf.withUnsafeMutableBytes { raw in
                if let ctx = CGContext(
                    data: raw.baseAddress, width: w, height: h, bitsPerComponent: 8,
                    bytesPerRow: w * 4, space: space,
                    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
                {
                    ctx.draw(image, in: CGRect(x: 0, y: 0, width: w, height: h))
                }
            }
        }
        width = w
        height = h
        buffer = buf
    }

    private func offset(_ x: Int, _ y: Int) -> Int? {
        guard x >= 0, y >= 0, x < width, y < height else { return nil }
        return (y * width + x) * 4
    }

    public func color(atPixel x: Int, _ y: Int) -> RGBColor? {
        guard let i = offset(x, y) else { return nil }
        let a = Int(buffer[i + 3])
        guard a > 0 else { return RGBColor(r: 0, g: 0, b: 0) }
        func un(_ v: UInt8) -> UInt8 { a == 255 ? v : UInt8(min(255, (Int(v) * 255 + a / 2) / a)) }
        return RGBColor(r: un(buffer[i]), g: un(buffer[i + 1]), b: un(buffer[i + 2]))
    }

    func alpha(atPixel x: Int, _ y: Int) -> UInt8? {
        offset(x, y).map { buffer[$0 + 3] }
    }

    /// A (2*radius+1)-square crop centered on the pixel; parts outside the image are transparent.
    public func patch(centerX: Int, centerY: Int, radius: Int) -> CGImage? {
        guard radius >= 0, let space = CGColorSpace(name: CGColorSpace.sRGB) else { return nil }
        let side = radius * 2 + 1
        var out = [UInt8](repeating: 0, count: side * side * 4)
        for py in 0..<side {
            for px in 0..<side {
                guard let s = offset(centerX - radius + px, centerY - radius + py) else { continue }
                let d = (py * side + px) * 4
                out[d] = buffer[s]; out[d + 1] = buffer[s + 1]
                out[d + 2] = buffer[s + 2]; out[d + 3] = buffer[s + 3]
            }
        }
        guard let provider = CGDataProvider(data: Data(out) as CFData) else { return nil }
        return CGImage(
            width: side, height: side, bitsPerComponent: 8, bitsPerPixel: 32,
            bytesPerRow: side * 4, space: space,
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
            provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent)
    }
}
