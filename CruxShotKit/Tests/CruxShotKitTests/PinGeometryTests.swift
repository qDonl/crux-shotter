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
}
