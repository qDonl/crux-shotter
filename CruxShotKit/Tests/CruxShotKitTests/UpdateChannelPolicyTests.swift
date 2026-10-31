import Testing
@testable import CruxShotKit

struct UpdateChannelPolicyTests {
    @Test(arguments: ["0.0.6-alpha", "v0.0.6-beta.2", "1.0.0-rc.1"])
    func previewsIncludePreviewChannel(_ version: String) {
        #expect(UpdateChannelPolicy.allowedChannels(currentVersion: version) == ["preview"])
    }

    @Test(arguments: ["1.0.0", "v1.0.0+build", "invalid"])
    func stableOrInvalidVersionsNeverReceivePreviews(_ version: String) {
        #expect(UpdateChannelPolicy.allowedChannels(currentVersion: version).isEmpty)
    }
}
