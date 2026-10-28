import Testing
import Foundation
import CoreGraphics
import CoreText
import CoreImage
import CoreImage.CIFilterBuiltins
@testable import CruxShotKit

private func blank(_ w: Int, _ h: Int) -> CGImage {
    makeImage(width: w, height: h) { _, _ in RGBColor(r: 255, g: 255, b: 255) }
}

private func renderText(_ lines: [String], fontSize: CGFloat) -> CGImage {
    let lineHeight = fontSize * 1.8
    let pad = fontSize * 2
    let width = Int(fontSize * 20 + pad * 2)
    let height = Int(lineHeight * CGFloat(lines.count) + pad * 2)
    let ctx = CGContext(
        data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
        space: CGColorSpace(name: CGColorSpace.sRGB)!,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    ctx.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
    ctx.fill(CGRect(x: 0, y: 0, width: width, height: height))
    let font = CTFontCreateWithName("PingFang SC" as CFString, fontSize, nil)
    for (i, text) in lines.enumerated() {
        let attrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: CGColor(red: 0, green: 0, blue: 0, alpha: 1),
        ]
        let line = CTLineCreateWithAttributedString(NSAttributedString(string: text, attributes: attrs))
        ctx.textPosition = CGPoint(x: pad, y: CGFloat(height) - pad - lineHeight * CGFloat(i + 1) + fontSize * 0.5)
        CTLineDraw(line, ctx)
    }
    return ctx.makeImage()!
}

private func qrImage(_ text: String) -> CGImage {
    let filter = CIFilter.qrCodeGenerator()
    filter.message = Data(text.utf8)
    let scaled = filter.outputImage!.transformed(by: CGAffineTransform(scaleX: 10, y: 10))
    let padded = scaled.composited(over: CIImage(color: .white).cropped(to: scaled.extent.insetBy(dx: -40, dy: -40)))
    return CIContext().createCGImage(padded, from: padded.extent)!
}

@Test func recognizesEnglishAndChinese() async throws {
    let lines = try await TextRecognizer.recognize(renderText(["Hello CruxShot", "截图测试"], fontSize: 32))
    #expect(lines.contains { $0.contains("Hello CruxShot") })
    #expect(lines.contains { $0.contains("截图测试") })
}

@Test func blankImageReturnsNoLines() async throws {
    #expect(try await TextRecognizer.recognize(blank(200, 100)).isEmpty)
}

@Test func detectsQR() async throws {
    #expect(try await QRDetector.detect(qrImage("https://cruxshot.app")) == ["https://cruxshot.app"])
}

@Test func singleLineJoin() {
    #expect(["foo", "bar"].joinedAsSingleLine == "foo bar")
    #expect(["你好", "世界"].joinedAsSingleLine == "你好世界")
    #expect(["你好", "world"].joinedAsSingleLine == "你好 world")
    #expect(["a", "b"].joinedAsLines == "a\nb")
}

@MainActor @Test func ocrPanelSingleLineDropsBlankLinesAndJoinsCJK() {
    #expect(OCRResultPanel.singleLine(from: "Hello\n\n  world  \n") == "Hello world")
    #expect(OCRResultPanel.singleLine(from: "你好\n世界\r\nok") == "你好世界 ok")
    #expect(OCRResultPanel.singleLine(from: "") == "")
}
