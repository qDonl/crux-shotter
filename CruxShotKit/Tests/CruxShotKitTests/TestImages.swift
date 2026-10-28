import Foundation
import CoreGraphics
@testable import CruxShotKit

/// Builds an sRGB, 8-bit RGBA image (origin top-left) by calling `pixel(x, y)` for every pixel.
func makeImage(width: Int, height: Int, _ pixel: (Int, Int) -> RGBColor) -> CGImage {
    let space = CGColorSpace(name: CGColorSpace.sRGB)!
    var data = [UInt8](repeating: 0, count: width * height * 4)
    for y in 0..<height {
        for x in 0..<width {
            let c = pixel(x, y)
            let i = (y * width + x) * 4
            data[i] = c.r; data[i + 1] = c.g; data[i + 2] = c.b; data[i + 3] = 255
        }
    }
    let provider = CGDataProvider(data: Data(data) as CFData)!
    return CGImage(
        width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 32,
        bytesPerRow: width * 4, space: space,
        bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
        provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent)!
}
