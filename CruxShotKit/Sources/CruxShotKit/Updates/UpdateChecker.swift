import Foundation
import Combine

@MainActor
public final class UpdateChecker: ObservableObject {
    public static let shared = UpdateChecker()
    public enum State: Equatable, Sendable {
        case idle, checking, upToDate, available(AppRelease), failed(String)
    }
    @Published public private(set) var state: State = .idle
    public let currentVersion: String
    private let defaults: UserDefaults
    private let fetch: @Sendable (String) async throws -> AppRelease?
    private static let lastCheckKey = "cruxshot.updates.lastSuccessfulCheck"
    private static let lastNotifiedKey = "cruxshot.updates.lastNotifiedVersion"

    public init(currentVersion: String? = nil, defaults: UserDefaults = .standard,
                fetch: @escaping @Sendable (String) async throws -> AppRelease? = {
                    try await GitHubReleaseService().availableUpdate(currentVersion: $0)
                }) {
        let release = Bundle.main.object(forInfoDictionaryKey: "CruxShotReleaseVersion") as? String
        let numeric = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        self.currentVersion = currentVersion ?? release.flatMap { ReleaseVersion($0) != nil ? $0 : nil }
            ?? numeric ?? CruxShotKit.version
        self.defaults = defaults
        self.fetch = fetch
    }

    public var isChecking: Bool { state == .checking }

    /// True only for the caller that started a request, so repeated clicks never duplicate prompts.
    @discardableResult
    public func check() async -> Bool {
        guard !isChecking else { return false }
        state = .checking
        do {
            let release = try await fetch(currentVersion)
            state = release.map(State.available) ?? .upToDate
            defaults.set(Date(), forKey: Self.lastCheckKey)
        } catch {
            state = .failed(error.localizedDescription)
        }
        return true
    }

    public func shouldCheckAutomatically(now: Date = .now) -> Bool {
        guard !isChecking else { return false }
        guard let last = defaults.object(forKey: Self.lastCheckKey) as? Date else { return true }
        let elapsed = now.timeIntervalSince(last)
        return elapsed >= 24 * 60 * 60 || elapsed < 0
    }

    /// Once per version for background notices; manual checks always report their result.
    public func takeAutomaticNotice() -> AppRelease? {
        guard case .available(let release) = state,
              defaults.string(forKey: Self.lastNotifiedKey) != release.version else { return nil }
        defaults.set(release.version, forKey: Self.lastNotifiedKey)
        return release
    }
}
