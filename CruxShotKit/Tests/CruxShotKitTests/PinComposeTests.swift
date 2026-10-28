import CoreGraphics
import Testing
@testable import CruxShotKit

private let red = RGBColor(r: 255, g: 0, b: 0)
private let blue = RGBColor(r: 0, g: 0, b: 255)
private let white = RGBColor(r: 255, g: 255, b: 255)

/// 2×1: left red, right blue.
private func pin(_ configure: (inout PinTransform) -> Void = { _ in }) -> PinItem {
    var t = PinTransform()
    configure(&t)
    let img = makeImage(width: 2, height: 1) { x, _ in x == 0 ? red : blue }
    return PinItem(image: img, imageScale: 1, frame: CGRect(x: 0, y: 0, width: 2, height: 1), transform: t)
}

private func colors(_ img: CGImage) -> [RGBColor?] {
    let s = PixelSampler(image: img)
    var out: [RGBColor?] = []
    for y in 0..<img.height { for x in 0..<img.width { out.append(s.color(atPixel: x, y)) } }
    return out
}

@Suite struct PinComposeTests {
    @Test func identityReturnsSamePixels() {
        let img = pin().composedImage()
        #expect(img.width == 2 && img.height == 1)
        #expect(colors(img) == [red, blue])
    }

    @Test func rotateCWPutsLeftOnTop() {
        let img = pin { $0.rotateCW() }.composedImage()
        #expect(img.width == 1 && img.height == 2)
        #expect(colors(img) == [red, blue])
    }

    @Test func rotateCCWPutsRightOnTop() {
        let img = pin { $0.rotateCCW() }.composedImage()
        #expect(img.width == 1 && img.height == 2)
        #expect(colors(img) == [blue, red])
    }

    @Test func rotate180() {
        let img = pin { $0.rotateCW(); $0.rotateCW() }.composedImage()
        #expect(img.width == 2 && img.height == 1)
        #expect(colors(img) == [blue, red])
    }

    @Test func flipHorizontal() {
        #expect(colors(pin { $0.flippedH = true }.composedImage()) == [blue, red])
    }

    @Test func flipIsAppliedInRotatedSpace() {
        // CW → [red over blue]; vertical flip on screen → [blue over red].
        let img = pin { $0.rotateCW(); $0.flippedV = true }.composedImage()
        #expect(img.width == 1 && img.height == 2)
        #expect(colors(img) == [blue, red])
        // Horizontal flip of a 1-wide column changes nothing.
        #expect(colors(pin { $0.rotateCW(); $0.flippedH = true }.composedImage()) == [red, blue])
    }

    @Test func scaleIsNotApplied() {
        let img = pin { $0.zoom(by: 3); $0.rotateCW() }.composedImage()
        #expect(img.width == 1 && img.height == 2)
    }

    @Test func annotationsAreDrawnInPointSpace() {
        let img = makeImage(width: 40, height: 20) { _, _ in white }
        let stroke = RGBColor(r: 255, g: 59, b: 48)
        // Vertically off-centre (top half) so a vertical flip would move it to the bottom.
        let a = Annotation(kind: .rect(CGRect(x: 2, y: 1, width: 6, height: 3)),
                           style: AnnotationStyle(color: .red, lineWidth: .medium))
        var item = PinItem(image: img, imageScale: 2, frame: .zero, annotations: [a])
        let plain = item.composedImage()
        #expect(plain.width == 40 && plain.height == 20)
        // Left edge at x = 2pt → 4px, spanning y 2...8px (±4px stroke); bottom of that column untouched.
        let s = PixelSampler(image: plain)
        #expect(s.color(atPixel: 4, 4) == stroke)
        #expect(s.color(atPixel: 4, 15) == white)
        #expect(s.color(atPixel: 38, 18) == white)
        item.transform.rotateCW()
        let rotated = item.composedImage()
        #expect(rotated.width == 20 && rotated.height == 40)
        // CW maps source pixel (x, y) → (20 - 1 - y, x).
        let r = PixelSampler(image: rotated)
        #expect(r.color(atPixel: 15, 4) == stroke)
        #expect(r.color(atPixel: 4, 4) == white)
    }
}
