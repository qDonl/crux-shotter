import Foundation
import Testing
@testable import CruxShotKit

@Suite struct ReleaseVersionTests {
    @Test func semanticOrderingAndMetadata() throws {
        let ordered = ["0.0.3-alpha", "0.0.3-alpha.2", "0.0.3-alpha.10", "0.0.3-beta", "0.0.3-rc.1", "0.0.3", "0.0.4-alpha", "0.0.10", "1.0.0"]
        let parsed = try ordered.map { try #require(ReleaseVersion($0)) }
        for pair in zip(parsed, parsed.dropFirst()) { #expect(pair.0 < pair.1) }
        #expect(ReleaseVersion("v1.2.0+build.10") == ReleaseVersion("1.2"))
        #expect(ReleaseVersion("1.2-alpha.99999999999999999999999")! > ReleaseVersion("1.2-alpha.9")!)
        #expect(ReleaseVersion("1.2-1")! < ReleaseVersion("1.2-alpha")!)
    }

    @Test(arguments: ["", "latest", "v", "01.2.3", "1..2", "1.2.3.4", "-1.0", "1.2-", "1.2-01", "1.2-alpha..1", "1.2+", "1.2+build+next", "999999999999999999999999.0", "1.2/3"])
    func rejectsInvalidVersions(_ value: String) { #expect(ReleaseVersion(value) == nil) }
}

@Suite(.serialized) struct GitHubReleaseServiceTests {
    private func release(_ tag: String, preview: Bool = true, draft: Bool = false,
                         asset: Bool = true, url: String? = nil, size: Int = 10) -> [String: Any] {
        let version = tag.hasPrefix("v") ? String(tag.dropFirst()) : tag
        return ["tag_name": tag, "prerelease": preview, "draft": draft,
                "html_url": "https://github.com/qDonl/crux-shotter/releases/tag/\(tag)",
                "assets": asset ? [["name": "CruxShotter-\(version).dmg", "state": "uploaded", "size": size,
                                     "browser_download_url": url ?? "https://github.com/qDonl/crux-shotter/releases/download/\(tag)/CruxShotter-\(version).dmg"]] : []]
    }

    private func service(_ payload: [[String: Any]], status: Int = 200, headers: [String: String] = [:]) throws -> GitHubReleaseService {
        let data = try JSONSerialization.data(withJSONObject: payload)
        UpdateURLProtocol.store.install { request in
            #expect(request.url == GitHubReleaseService.endpoint)
            #expect(request.value(forHTTPHeaderField: "Authorization") == nil)
            #expect(request.value(forHTTPHeaderField: "Accept") == "application/vnd.github+json")
            return (status, headers, data)
        }
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [UpdateURLProtocol.self]
        return GitHubReleaseService(session: URLSession(configuration: config))
    }

    @Test func previewBuildFindsPreviewAndIgnoresArrayOrderDraftsAndMissingAssets() async throws {
        let client = try service([release("v0.0.2-alpha"), release("v9.0.0", preview: false, draft: true),
                                  release("v0.0.10-alpha"), release("v0.0.3-alpha"), release("v10.0.0", asset: false)])
        let update = try await client.availableUpdate(currentVersion: "0.0.3-alpha")
        #expect(update?.version == "v0.0.10-alpha")
        #expect(update?.downloadURL.lastPathComponent == "CruxShotter-0.0.10-alpha.dmg")
    }

    @Test func stableClientSkipsPreviewsEvenWhenIncorrectlyMarkedStable() async throws {
        let client = try service([release("v9.0.0-alpha", preview: false), release("v8.0.0-beta"), release("v0.0.4", preview: false)])
        #expect(try await client.availableUpdate(currentVersion: "0.0.3")?.version == "v0.0.4")
    }

    @Test func previewCanUpgradeToSameVersionStableAndNeverDowngrades() async throws {
        let client = try service([release("v0.0.3", preview: false)])
        #expect(try await client.availableUpdate(currentVersion: "0.0.3-alpha")?.version == "v0.0.3")
        #expect(try await client.availableUpdate(currentVersion: "0.0.3") == nil)
        #expect(try await client.availableUpdate(currentVersion: "0.0.4-alpha") == nil)
    }

    @Test func ignoresUntrustedDownloadAndEmptyAssets() async throws {
        let client = try service([release("v9.0.0", url: "https://example.com/fake.dmg"), release("v8.0.0", size: 0),
                                  release("v7.0.0", url: "https://github.com/other/repo/releases/download/v7.0.0/app.dmg"),
                                  release("v0.0.4-alpha")])
        #expect(try await client.availableUpdate(currentVersion: "0.0.3-alpha")?.version == "v0.0.4-alpha")
    }

    @Test func noInstallableReleaseIsNotReportedAsUpToDate() async throws {
        let client = try service([release("v0.0.4-alpha", asset: false), release("nonsense")])
        do {
            _ = try await client.availableUpdate(currentVersion: "0.0.3-alpha")
            Issue.record("Expected missing release error")
        } catch UpdateError.noReleases {} catch { Issue.record("Unexpected error: \(error)") }
    }

    @Test func rateLimitAndServerErrorsRemainRetryable() async throws {
        for (status, headers) in [(429, [:]), (403, ["X-RateLimit-Remaining": "0"]), (503, [:])] {
            let client = try service([], status: status, headers: headers)
            do {
                _ = try await client.availableUpdate(currentVersion: "0.0.3-alpha")
                Issue.record("Expected HTTP failure")
            } catch UpdateError.rateLimited { #expect(status != 503) }
            catch UpdateError.http(let code) { #expect(code == 503) }
            catch { Issue.record("Unexpected error: \(error)") }
        }
    }

    @Test func malformedPayloadAndInvalidInstalledVersionFailClearly() async throws {
        UpdateURLProtocol.store.install { _ in (200, [:], Data("not json".utf8)) }
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [UpdateURLProtocol.self]
        let client = GitHubReleaseService(session: URLSession(configuration: config))
        do {
            _ = try await client.availableUpdate(currentVersion: "0.0.3")
            Issue.record("Expected invalid response")
        } catch UpdateError.invalidResponse {} catch { Issue.record("Unexpected error: \(error)") }
        do {
            _ = try await client.availableUpdate(currentVersion: "latest")
            Issue.record("Expected invalid version")
        } catch UpdateError.invalidCurrentVersion {} catch { Issue.record("Unexpected error: \(error)") }
    }
}

@Suite @MainActor struct UpdateCheckerTests {
    private func defaults() -> UserDefaults { UserDefaults(suiteName: "cruxshot.update.tests.\(UUID().uuidString)")! }
    private var release: AppRelease {
        AppRelease(version: "v0.0.4-alpha", pageURL: GitHubReleaseService.releasesURL,
                   downloadURL: URL(string: "https://github.com/qDonl/crux-shotter/releases/download/v0.0.4-alpha/CruxShotter-0.0.4-alpha.dmg")!)
    }

    @Test func successfulChecksThrottleAndNoticesAppearOncePerVersion() async {
        let store = defaults()
        let available = release
        let checker = UpdateChecker(currentVersion: "0.0.3-alpha", defaults: store, fetch: { _ in available })
        #expect(checker.shouldCheckAutomatically())
        #expect(await checker.check())
        #expect(checker.state == .available(available))
        #expect(!checker.shouldCheckAutomatically())
        #expect(checker.shouldCheckAutomatically(now: Date().addingTimeInterval(86_401)))
        #expect(checker.takeAutomaticNotice() == available)
        #expect(checker.takeAutomaticNotice() == nil)
        #expect(await checker.check()) // Manual checks bypass the background throttle.
        #expect(checker.takeAutomaticNotice() == nil)
        let relaunched = UpdateChecker(currentVersion: "0.0.3-alpha", defaults: store, fetch: { _ in available })
        #expect(!relaunched.shouldCheckAutomatically())
        await relaunched.check()
        #expect(relaunched.takeAutomaticNotice() == nil)
    }

    @Test func failuresDoNotClaimLatestOrSuppressRetry() async {
        let checker = UpdateChecker(currentVersion: "0.0.3-alpha", defaults: defaults(), fetch: { _ in throw URLError(.notConnectedToInternet) })
        await checker.check()
        guard case .failed = checker.state else { Issue.record("Expected failure state"); return }
        #expect(!checker.isChecking)
        #expect(checker.shouldCheckAutomatically())
        #expect(checker.takeAutomaticNotice() == nil)
    }

    @Test func noNewerReleaseReportsUpToDate() async {
        let checker = UpdateChecker(currentVersion: "0.0.3-alpha", defaults: defaults(), fetch: { _ in nil })
        await checker.check()
        #expect(checker.state == .upToDate)
        #expect(checker.takeAutomaticNotice() == nil)
    }

    @Test func concurrentChecksOnlyFetchAndPromptOnce() async {
        let gate = UpdateFetchGate()
        let checker = UpdateChecker(currentVersion: "0.0.3-alpha", defaults: defaults(), fetch: { _ in await gate.fetch() })
        let first = Task { await checker.check() }
        await gate.waitForStart()
        #expect(checker.isChecking)
        #expect(!checker.shouldCheckAutomatically())
        #expect(await checker.check() == false)
        await gate.finish()
        #expect(await first.value)
        #expect(await gate.count == 1)
        #expect(checker.state == .upToDate)
    }

    @Test func backgroundPreferenceDefaultsOnAndPersistsOff() {
        let store = defaults()
        let preferences = Preferences(defaults: store)
        #expect(preferences.automaticallyChecksForUpdates)
        preferences.automaticallyChecksForUpdates = false
        #expect(!Preferences(defaults: store).automaticallyChecksForUpdates)
    }
}

private actor UpdateFetchGate {
    private(set) var count = 0
    private var pending: CheckedContinuation<AppRelease?, Never>?
    private var started: CheckedContinuation<Void, Never>?
    func fetch() async -> AppRelease? {
        count += 1
        started?.resume()
        started = nil
        return await withCheckedContinuation { pending = $0 }
    }
    func waitForStart() async {
        if count > 0 { return }
        await withCheckedContinuation { started = $0 }
    }
    func finish() { pending?.resume(returning: nil); pending = nil }
}

private final class UpdateURLProtocol: URLProtocol, @unchecked Sendable {
    static let store = HandlerStore()
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        do {
            let (status, headers, data) = try Self.store.response(request)
            let response = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: headers)!
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch { client?.urlProtocol(self, didFailWithError: error) }
    }
    override func stopLoading() {}

    final class HandlerStore: @unchecked Sendable {
        private let lock = NSLock()
        private var handler: (@Sendable (URLRequest) throws -> (Int, [String: String], Data))?
        func install(_ handler: @escaping @Sendable (URLRequest) throws -> (Int, [String: String], Data)) {
            lock.lock(); defer { lock.unlock() }
            self.handler = handler
        }
        func response(_ request: URLRequest) throws -> (Int, [String: String], Data) {
            lock.lock()
            let handler = handler
            lock.unlock()
            return try handler!(request)
        }
    }
}

@Suite struct LiveUpdateTests {
    @Test(.enabled(if: ProcessInfo.processInfo.environment["CRUXSHOT_LIVE_UPDATE_TEST"] == "1"))
    func publicReleaseCanBeDetectedWithoutCredentials() async throws {
        let update = try #require(await GitHubReleaseService().availableUpdate(currentVersion: "0.0.0-alpha"))
        #expect(update.downloadURL.host == "github.com")
        #expect(update.downloadURL.pathExtension == "dmg")
        #expect(ReleaseVersion(update.version)! > ReleaseVersion("0.0.0-alpha")!)
    }
}
