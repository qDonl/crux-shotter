import CoreGraphics
import Testing
@testable import CruxShotKit

@Suite struct PinGeometryTests {
    @Test func zoomKeepsAnchorFixed() {
        let f = CGRect(x: 100, y: 200, width: 200, height: 100)
        let anchor = CGPoint(x: 150, y: 275) // 25% across, 75% up
        let z = PinGeometry.zoomedFrame(f, to: CGSize(width: 400, height: 200), anchor: anchor)
        #expect(z == CGRect(x: 50, y: 125, width: 400, height: 200))
        #expect(z.minX + 0.25 * z.width == anchor.x)
        #expect(z.minY + 0.75 * z.height == anchor.y)
    }

    @Test func zoomOutAroundCenter() {
        let f = CGRect(x: 0, y: 0, width: 100, height: 100)
        let z = PinGeometry.zoomedFrame(f, to: CGSize(width: 50, height: 50), anchor: CGPoint(x: 50, y: 50))
        #expect(z == CGRect(x: 25, y: 25, width: 50, height: 50))
    }

    @Test func anchorOutsideFrameIsClamped() {
        let f = CGRect(x: 0, y: 0, width: 100, height: 100)
        let z = PinGeometry.zoomedFrame(f, to: CGSize(width: 200, height: 200), anchor: CGPoint(x: -50, y: 500))
        #expect(z == CGRect(x: 0, y: -100, width: 200, height: 200))
    }

    @Test func pointSizeUsesScale() {
        let img = makeImage(width: 40, height: 20) { _, _ in RGBColor(r: 0, g: 0, b: 0) }
        #expect(PinGeometry.pointSize(of: img, scale: 2) == CGSize(width: 20, height: 10))
    }

    @Test func fittingScaleShrinksOnlyLargeImages() {
        let screen = CGSize(width: 1000, height: 800)
        #expect(PinGeometry.fittingScale(pixelSize: CGSize(width: 400, height: 300), baseScale: 2, within: screen) == 2)
        // 4000 px wide at 2x = 2000 pt; 80% of 1000 pt = 800 pt -> scale 5.
        #expect(PinGeometry.fittingScale(pixelSize: CGSize(width: 4000, height: 100), baseScale: 2, within: screen) == 5)
        #expect(PinGeometry.fittingScale(pixelSize: CGSize(width: 100, height: 3200), baseScale: 2, within: screen) == 5)
    }

    @Test func cascadeFramesStartAtMouseAndStepDownRight() {
        let visible = CGRect(x: 0, y: 0, width: 1000, height: 800)
        let frames = PinGeometry.cascadeFrames(sizes: [CGSize(width: 100, height: 50), CGSize(width: 100, height: 50)],
                                               around: CGPoint(x: 500, y: 400), visible: visible)
        #expect(frames == [CGRect(x: 450, y: 375, width: 100, height: 50), CGRect(x: 474, y: 351, width: 100, height: 50)])
    }

    @Test func cascadeFramesStayOnScreen() {
        let visible = CGRect(x: 0, y: 0, width: 1000, height: 800)
        let frames = PinGeometry.cascadeFrames(sizes: [CGSize(width: 200, height: 100)], around: CGPoint(x: 990, y: 5), visible: visible)
        #expect(frames == [CGRect(x: 800, y: 0, width: 200, height: 100)])
    }
}
