import CoreGraphics
import Testing
@testable import CruxShotKit

@Suite struct TextCardRendererTests {
    @Test func truncatesTo80Lines() {
        let tall = TextCardRenderer.render((1...10_000).map(String.init).joined(separator: "\n"), dark: false, scale: 1)
        let eighty = TextCardRenderer.render((1...81).map(String.init).joined(separator: "\n"), dark: false, scale: 1)
        #expect(tall.height == eighty.height)
        let exact = TextCardRenderer.render((1...80).map(String.init).joined(separator: "\n"), dark: false, scale: 1)
        #expect(exact.height < eighty.height)
    }
    @Test func truncatesLongLines() {
        let a = TextCardRenderer.render(String(repeating: "x", count: 5_000), dark: false, scale: 1)
        let b = TextCardRenderer.render(String(repeating: "x", count: 301), dark: false, scale: 1)
        #expect(a.width == b.width)
    }
    @Test func scaleMultipliesPixels() {
        let a = TextCardRenderer.render("hello", dark: true, scale: 1)
        let b = TextCardRenderer.render("hello", dark: true, scale: 2)
        #expect(abs(b.width - 2 * a.width) <= 1 && abs(b.height - 2 * a.height) <= 1)
    }
    @Test func tabsExpand() {
        let a = TextCardRenderer.render("\tx", dark: false, scale: 1)
        let b = TextCardRenderer.render("    x", dark: false, scale: 1)
        #expect(a.width == b.width)
    }
    @Test func emptyTextStillRenders() {
        let a = TextCardRenderer.render("", dark: false, scale: 1)
        #expect(a.width > 0 && a.height > 0)
    }

    private func pixels(_ img: CGImage) -> [UInt8] {
        var d = [UInt8](repeating: 0, count: img.width * img.height * 4)
        let c = CGContext(data: &d, width: img.width, height: img.height, bitsPerComponent: 8, bytesPerRow: img.width * 4,
                          space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        c.draw(img, in: CGRect(x: 0, y: 0, width: img.width, height: img.height))
        return d
    }
    private func hasPixel(_ img: CGImage, near rgb: (Int, Int, Int)) -> Bool {
        let d = pixels(img)
        for i in stride(from: 0, to: d.count, by: 4) where d[i + 3] == 255 {
            if abs(Int(d[i]) - rgb.0) < 8 && abs(Int(d[i + 1]) - rgb.1) < 8 && abs(Int(d[i + 2]) - rgb.2) < 8 { return true }
        }
        return false
    }
    @Test func textIsDrawnInForegroundColor() {
        let light = TextCardRenderer.render("Hello", dark: false, scale: 2)
        #expect(hasPixel(light, near: (0xFF, 0xFF, 0xFF)))
        #expect(hasPixel(light, near: (0x1C, 0x1C, 0x1E)))
        let dark = TextCardRenderer.render("Hello", dark: true, scale: 2)
        #expect(hasPixel(dark, near: (0x1E, 0x1E, 0x1E)))
        #expect(hasPixel(dark, near: (0xE5, 0xE5, 0xE5)))
    }
}
