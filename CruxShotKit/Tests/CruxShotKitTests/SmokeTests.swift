import Testing
@testable import CruxShotKit

@Suite struct SmokeTests {
    @Test func versionIsSet() { #expect(!CruxShotKit.version.isEmpty) }
}
