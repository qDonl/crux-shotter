import Testing
import CoreGraphics
@testable import CruxShotKit

@Test func hexFormat() { #expect(ColorFormat.hex.string(for: RGBColor(r: 255, g: 0, b: 16)) == "#FF0010") }
@Test func rgbFormat() { #expect(ColorFormat.rgb.string(for: RGBColor(r: 255, g: 0, b: 16)) == "rgb(255, 0, 16)") }
@Test func toggle() { #expect(ColorFormat.hex.toggled == .rgb && ColorFormat.rgb.toggled == .hex) }
@Test func samplesPixel() {
    let img = makeImage(width: 4, height: 4) { x, y in x == 1 && y == 2 ? RGBColor(r: 10, g: 20, b: 30) : RGBColor(r: 0, g: 0, b: 0) }
    #expect(PixelSampler(image: img).color(atPixel: 1, 2) == RGBColor(r: 10, g: 20, b: 30))
    #expect(PixelSampler(image: img).color(atPixel: 4, 0) == nil)
    #expect(PixelSampler(image: img).color(atPixel: -1, 0) == nil)
}
@Test func patchSize() {
    #expect(PixelSampler(image: makeImage(width: 4, height: 4) { _, _ in .init(r: 0, g: 0, b: 0) })
            .patch(centerX: 0, centerY: 0, radius: 7)?.width == 15)
}
@Test func patchContentAndTransparency() {
    let img = makeImage(width: 4, height: 4) { _, _ in RGBColor(r: 200, g: 100, b: 50) }
    let patch = PixelSampler(image: img).patch(centerX: 0, centerY: 0, radius: 1)!
    let p = PixelSampler(image: patch)
    #expect(p.color(atPixel: 1, 1) == RGBColor(r: 200, g: 100, b: 50))
    #expect(p.alpha(atPixel: 0, 0) == 0)
    #expect(p.alpha(atPixel: 2, 2) == 255)
}
