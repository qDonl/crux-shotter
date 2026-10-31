import CoreGraphics
import Testing
@testable import CruxShotKit

@MainActor
@Suite struct SnapshotPixelsTests {
    // Left: 100×50pt @2x at x 0...100. Right: 80×40pt @1x at x 100...180 (bottom-aligned).
    let left = DisplayInfo(displayID: 1, frame: CGRect(x: 0, y: 0, width: 100, height: 50), scale: 2)
    let right = DisplayInfo(displayID: 2, frame: CGRect(x: 100, y: 0, width: 80, height: 40), scale: 1)

    func pixels() -> SnapshotPixels {
        let l = makeImage(width: 200, height: 100) { x, y in RGBColor(r: UInt8(x), g: UInt8(y), b: 1) }
        let r = makeImage(width: 80, height: 40) { x, y in RGBColor(r: UInt8(x), g: UInt8(y), b: 2) }
        return SnapshotPixels(snapshot: CaptureSnapshot(
            frames: [CapturedFrame(display: left, image: l), CapturedFrame(display: right, image: r)], windows: []))
    }

    @Test func cropUsesCenterDisplayAndReportsCoveredGlobalRect() throws {
        let crop = try #require(pixels().crop(CGRect(x: 10, y: 20, width: 30, height: 10)))
        #expect(crop.frame.display == left)
        #expect(crop.image.width == 60 && crop.image.height == 20)
        #expect(crop.globalRect == CGRect(x: 10, y: 20, width: 30, height: 10))
    }

    @Test func spanningCropIsClippedToCenterDisplay() throws {
        // Center x = 130 → right display; the part on the left display is dropped.
        let crop = try #require(pixels().crop(CGRect(x: 90, y: 0, width: 80, height: 20)))
        #expect(crop.frame.display == right)
        #expect(crop.globalRect == CGRect(x: 100, y: 0, width: 70, height: 20))
        #expect(crop.image.width == 70 && crop.image.height == 20)
    }

    @Test func centerInGapFallsBackToLargestOverlap() {
        // Center (150, 45) is above the shorter right display; overlaps left more.
        let f = pixels().bestFrame(for: CGRect(x: 60, y: 40, width: 180, height: 10))
        #expect(f?.display == left)
    }

    @Test func pixelSizeAndColorAt() {
        let p = pixels()
        #expect(p.pixelSize(of: CGRect(x: 0, y: 0, width: 10, height: 5)) == CGSize(width: 20, height: 10))
        // Global (10.2, 49.9) on left → pixel (20, 0)
        #expect(p.colorString(at: CGPoint(x: 10.2, y: 49.9), format: .rgb) == "rgb(20, 0, 1)")
        #expect(p.colorString(at: CGPoint(x: 150, y: 45), format: .hex) == nil)
    }
    @Test func explicitDisplayKeepsCropOnOriginalScreen() throws {
        let rect = CGRect(x: 90, y: 0, width: 80, height: 20)
        let crop = try #require(pixels().crop(rect, displayID: left.displayID))
        #expect(crop.frame.display == left)
        #expect(crop.globalRect == CGRect(x: 90, y: 0, width: 10, height: 20))
        #expect(crop.image.width == 20 && crop.image.height == 40)
        #expect(pixels().crop(rect, displayID: 999) == nil)
        #expect(pixels().crop(right.frame, displayID: left.displayID) == nil)
    }

}
