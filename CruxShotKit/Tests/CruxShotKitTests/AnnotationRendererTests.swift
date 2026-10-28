import Testing
import CoreGraphics
@testable import CruxShotKit

@MainActor
struct AnnotationRendererTests {
    private let white = RGBColor(r: 255, g: 255, b: 255)

    private func doc(width: Int, height: Int, scale: CGFloat = 1,
                     _ pixel: (Int, Int) -> RGBColor = { _, _ in RGBColor(r: 255, g: 255, b: 255) }) -> AnnotationDocument {
        AnnotationDocument(image: makeImage(width: width, height: height, pixel), scale: scale)
    }

    private func noise(_ x: Int, _ y: Int) -> RGBColor {
        var h = UInt32(truncatingIfNeeded: x &* 73856093 ^ y &* 19349663)
        h = h &* 2654435761
        return RGBColor(r: UInt8(h >> 24 & 0xFF), g: UInt8(h >> 16 & 0xFF), b: UInt8(h >> 8 & 0xFF))
    }

    @Test func renderKeepsPixelSize() {
        let d = doc(width: 200, height: 100, scale: 2)
        d.add(Annotation(kind: .rect(CGRect(x: 10, y: 10, width: 50, height: 50))))
        let out = AnnotationRenderer.render(d)
        #expect(out.width == 200 && out.height == 100)
    }

    @Test func sourceIsNotMirrored() {
        let d = doc(width: 6, height: 5) { x, y in
            (x == 1 && y == 2) ? RGBColor(r: 10, g: 200, b: 30) : RGBColor(r: 255, g: 255, b: 255)
        }
        let s = PixelSampler(image: AnnotationRenderer.render(d))
        #expect(s.color(atPixel: 1, 2) == RGBColor(r: 10, g: 200, b: 30))
        #expect(s.color(atPixel: 1, 3) == white)
        #expect(s.color(atPixel: 4, 2) == white)
    }

    @Test func rectStrokeIsDrawn() {
        let d = doc(width: 100, height: 100)
        d.add(Annotation(kind: .rect(CGRect(x: 10, y: 10, width: 50, height: 50))))
        let s = PixelSampler(image: AnnotationRenderer.render(d))
        #expect(s.color(atPixel: 10, 30) == RGBColor(r: 255, g: 59, b: 48))
        #expect(s.color(atPixel: 30, 30) == white)
    }

    @Test func pixelateMakesUniformBlocks() {
        let d = doc(width: 48, height: 48, scale: 1, noise)
        d.add(Annotation(kind: .mosaic(CGRect(x: 0, y: 0, width: 48, height: 48), .pixelate)))
        let s = PixelSampler(image: AnnotationRenderer.render(d))
        #expect(s.color(atPixel: 1, 1) == s.color(atPixel: 10, 10))
        #expect(s.color(atPixel: 1, 1) != PixelSampler(image: d.image).color(atPixel: 1, 1))
    }

    @Test func blurSmoothsNoise() {
        let d = doc(width: 48, height: 48, scale: 1, noise)
        d.add(Annotation(kind: .mosaic(CGRect(x: 0, y: 0, width: 48, height: 48), .blur)))
        let out = PixelSampler(image: AnnotationRenderer.render(d))
        let src = PixelSampler(image: d.image)
        #expect(out.color(atPixel: 20, 20) != src.color(atPixel: 20, 20))
    }

    @Test func mosaicLeavesOutsideUntouched() {
        let d = doc(width: 48, height: 48, scale: 1, noise)
        d.add(Annotation(kind: .mosaic(CGRect(x: 0, y: 0, width: 24, height: 48), .pixelate)))
        let out = PixelSampler(image: AnnotationRenderer.render(d))
        let src = PixelSampler(image: d.image)
        #expect(out.color(atPixel: 40, 5) == src.color(atPixel: 40, 5))
        #expect(out.color(atPixel: 30, 40) == src.color(atPixel: 30, 40))
    }

    @Test func mosaicSamplesSourceNotEarlierAnnotations() {
        let d = doc(width: 48, height: 48)
        d.add(Annotation(kind: .rect(CGRect(x: 2, y: 2, width: 40, height: 40))))
        d.add(Annotation(kind: .mosaic(CGRect(x: 0, y: 0, width: 48, height: 48), .pixelate)))
        let s = PixelSampler(image: AnnotationRenderer.render(d))
        #expect(s.color(atPixel: 2, 20) == white)
    }

    @Test func counterDrawsFilledCircle() {
        let d = doc(width: 100, height: 100)
        d.add(Annotation(kind: .counter(center: CGPoint(x: 50, y: 50), number: 1)))
        let s = PixelSampler(image: AnnotationRenderer.render(d))
        // diameter 2.2*18 = 39.6; near the rim, away from the digit
        #expect(s.color(atPixel: 34, 50) == RGBColor(r: 255, g: 59, b: 48))
        #expect(s.color(atPixel: 50, 20) == white)
    }

    @Test func arrowAndPenAndTextDraw() {
        let d = doc(width: 100, height: 100)
        d.add(Annotation(kind: .arrow(from: CGPoint(x: 10, y: 50), to: CGPoint(x: 90, y: 50))))
        d.add(Annotation(kind: .pen([CGPoint(x: 10, y: 10), CGPoint(x: 90, y: 10)])))
        d.add(Annotation(kind: .text(origin: CGPoint(x: 10, y: 70), string: "Hi\nYo")))
        let s = PixelSampler(image: AnnotationRenderer.render(d))
        #expect(s.color(atPixel: 40, 50) == RGBColor(r: 255, g: 59, b: 48))
        #expect(s.color(atPixel: 50, 10) == RGBColor(r: 255, g: 59, b: 48))
        var textPixels = 0
        for y in 70..<100 { for x in 10..<60 where s.color(atPixel: x, y) != white { textPixels += 1 } }
        #expect(textPixels > 20)
    }
}
