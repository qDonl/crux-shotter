import AppKit
import Testing
@testable import CruxShotKit

@MainActor
struct TextPlacementTests {
    let canvas = CGRect(x: 0, y: 0, width: 100, height: 60)

    @Test func movesTextIntoVisibleCropWithoutChangingItsRenderedSize() {
        let origin = CanvasView.fittedTextOrigin(preferred: CGPoint(x: 90, y: 50),
                                                size: CGSize(width: 40, height: 20), in: canvas)
        #expect(origin == CGPoint(x: 60, y: 40))
    }

    @Test func textLargerThanCropStartsAtTheEdgeAndMatchesExportClipping() {
        let origin = CanvasView.fittedTextOrigin(preferred: CGPoint(x: 90, y: 50),
                                                size: CGSize(width: 150, height: 80), in: canvas)
        #expect(origin == .zero)
    }

    @Test func ordinaryTextRetainsItsClickLocation() {
        let point = CGPoint(x: 12, y: 14)
        #expect(CanvasView.fittedTextOrigin(preferred: point, size: CGSize(width: 20, height: 15), in: canvas) == point)
    }
}
