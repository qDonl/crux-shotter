import AppKit
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

    @Test func longTextWrapsAtMaxWidth() {
        let prose = String(repeating: "word ", count: 60)
        let img = TextCardRenderer.render(prose, dark: false, scale: 1)
        #expect(CGFloat(img.width) <= TextCardRenderer.maxTextWidth + 2 * TextCardRenderer.padding + 1)
        let one = TextCardRenderer.render("word", dark: false, scale: 1)
        #expect(img.height > one.height + 20) // at least two more lines
    }
    @Test func shortTextIsNarrow() {
        let img = TextCardRenderer.render("hi", dark: false, scale: 1)
        #expect(CGFloat(img.width) < 100)
    }
    @Test func codeDetection() {
        #expect(TextCardRenderer.isCodeLike("func a() {\n    return 1\n}"))
        #expect(TextCardRenderer.isCodeLike("\tindented"))
        #expect(TextCardRenderer.isCodeLike("let x = 1;"))
        #expect(!TextCardRenderer.isCodeLike("Hello, world. This is prose."))
        #expect(!TextCardRenderer.isCodeLike("第一行\n第二行"))
    }
    @Test func textStartsAtTop() {
        let img = TextCardRenderer.render(String(repeating: "W", count: 3), dark: false, scale: 1)
        let d = pixels(img)
        let row = { (y: Int) -> Bool in (0..<img.width).contains { x in let i = (y * img.width + x) * 4; return d[i] < 100 && d[i + 3] == 255 } }
        // Bitmap rows run top-down; the first dark row sits within the top padding + one line.
        let firstDark = (0..<img.height).first(where: row)
        #expect(firstDark != nil && firstDark! < Int(TextCardRenderer.padding) + 8)
    }

    @Test func richTextKeepsColors() {
        let s = NSAttributedString(string: "RED RED RED", attributes: [
            .font: NSFont.boldSystemFont(ofSize: 24),
            .foregroundColor: NSColor(srgbRed: 1, green: 0, blue: 0, alpha: 1)])
        let img = TextCardRenderer.renderRich(s, scale: 2)
        #expect(hasPixel(img, near: (0xFF, 0xFF, 0xFF)))
        #expect(hasPixel(img, near: (0xFF, 0x00, 0x00)))
    }
    @Test func lightRichTextGetsDarkBackground() {
        let s = NSAttributedString(string: "light text", attributes: [
            .font: NSFont.systemFont(ofSize: 14),
            .foregroundColor: NSColor(srgbRed: 0.9, green: 0.9, blue: 0.9, alpha: 1)])
        let img = TextCardRenderer.renderRich(s, scale: 1)
        #expect(hasPixel(img, near: (0x1E, 0x1E, 0x1E)))
        #expect(!hasPixel(img, near: (0xFF, 0xFF, 0xFF)))
    }
    @Test func richTextTruncatesTo80Lines() {
        let font: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: 13)]
        let tall = TextCardRenderer.renderRich(NSAttributedString(string: (1...500).map(String.init).joined(separator: "\n"), attributes: font), scale: 1)
        let eighty = TextCardRenderer.renderRich(NSAttributedString(string: (1...81).map(String.init).joined(separator: "\n"), attributes: font), scale: 1)
        #expect(tall.height == eighty.height)
    }

    @Test func colorCardShowsSwatch() {
        let img = ColorCardRenderer.render(ColorLiteral(rgb: RGBColor(r: 255, g: 106, b: 0), alpha: 1), dark: false, scale: 2)
        #expect(hasPixel(img, near: (255, 106, 0)))
        #expect(hasPixel(img, near: (0xFF, 0xFF, 0xFF)))
        let dark = ColorCardRenderer.render(ColorLiteral(rgb: RGBColor(r: 0, g: 0, b: 255), alpha: 1), dark: true, scale: 1)
        #expect(hasPixel(dark, near: (0, 0, 255)))
        #expect(hasPixel(dark, near: (0x1E, 0x1E, 0x1E)))
    }
    @Test func colorCardFitsLongestRGBAOnOneLine() {
        let one = ColorCardRenderer.render(ColorLiteral(rgb: RGBColor(r: 1, g: 2, b: 3), alpha: 1), dark: false, scale: 1)
        let widest = ColorCardRenderer.render(ColorLiteral(rgb: RGBColor(r: 255, g: 255, b: 255), alpha: 0.55), dark: false, scale: 1)
        #expect(one.height == widest.height)
    }
}
