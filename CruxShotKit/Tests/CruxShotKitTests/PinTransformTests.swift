import CoreGraphics
import Testing
@testable import CruxShotKit

@Suite struct PinTransformTests {
    @Test func zoomClamped() {
        var t = PinTransform(); t.zoom(by: 100); #expect(t.scale == 5)
        t.zoom(by: 0.0001); #expect(t.scale == 0.1)
    }
    @Test func rotationWrapsAndSwapsSize() {
        var t = PinTransform(); t.rotateCCW(); #expect(t.quarterTurns == 3)
        #expect(t.displaySize(for: CGSize(width: 200, height: 100)) == CGSize(width: 100, height: 200))
        t.rotateCW(); #expect(t.quarterTurns == 0)
        t.rotateCW(); #expect(t.quarterTurns == 1)
    }
    @Test func opacityClamped() {
        var t = PinTransform(); t.adjustOpacity(by: -5); #expect(t.opacity == 0.1)
        t.adjustOpacity(by: 5); #expect(t.opacity == 1)
    }
    @Test func displaySizeScales() {
        var t = PinTransform(); t.scale = 2
        #expect(t.displaySize(for: CGSize(width: 10, height: 20)) == CGSize(width: 20, height: 40))
        t.resetScale(); #expect(t.scale == 1)
    }
}
