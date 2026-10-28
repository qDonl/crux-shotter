import AppKit
import Testing
@testable import CruxShotKit

@Suite struct ScreenCaptureServiceTests {
    @Test(.enabled(if: ScreenCapturePermission.isGranted))
    func snapshotHasOneFramePerScreen() async throws {
        let s = try await ScreenCaptureService().snapshot()
        #expect(s.frames.count == NSScreen.screens.count)
        for f in s.frames { #expect(CGFloat(f.image.width) == f.display.frame.width * f.display.scale) }
    }
}
