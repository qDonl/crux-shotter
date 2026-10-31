import Foundation

public struct AppRelease: Equatable, Sendable {
    public let version: String
    public let pageURL: URL
    public let downloadURL: URL
}

public enum UpdateError: LocalizedError {
    case invalidCurrentVersion, invalidResponse, noReleases, rateLimited, http(Int)

    public var errorDescription: String? {
        switch self {
        case .invalidCurrentVersion: "无法读取当前版本号。"
        case .invalidResponse: "GitHub 返回的更新信息无效，请稍后重试。"
        case .noReleases: "尚未找到适用于当前版本通道的安装包。"
        case .rateLimited: "GitHub 请求过于频繁，请稍后重试。"
        case .http(let code): "无法获取更新信息（HTTP \(code)），请稍后重试。"
        }
    }
}

public struct GitHubReleaseService: Sendable {
    private let session: URLSession
    public static let releasesURL = URL(string: "https://github.com/qDonl/crux-shotter/releases")!
    static let endpoint = URL(string: "https://api.github.com/repos/qDonl/crux-shotter/releases?per_page=100")!

    public init(session: URLSession = .shared) { self.session = session }

    public func availableUpdate(currentVersion: String) async throws -> AppRelease? {
        guard let current = ReleaseVersion(currentVersion) else { throw UpdateError.invalidCurrentVersion }
        var request = URLRequest(url: Self.endpoint, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 20)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("2022-11-28", forHTTPHeaderField: "X-GitHub-Api-Version")
        request.setValue("CruxShotter", forHTTPHeaderField: "User-Agent")
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw UpdateError.invalidResponse }
        if http.statusCode == 429 || (http.statusCode == 403 && http.value(forHTTPHeaderField: "X-RateLimit-Remaining") == "0") {
            throw UpdateError.rateLimited
        }
        guard http.statusCode == 200 else { throw UpdateError.http(http.statusCode) }
        let releases: [Release]
        do { releases = try JSONDecoder().decode([Release].self, from: data) }
        catch { throw UpdateError.invalidResponse }
        return try Self.select(releases, current: current)
    }

    /// Does not trust list order or tag spelling. Stable clients exclude all preview releases;
    /// preview clients can move to newer previews and to the final stable release.
    private static func select(_ releases: [Release], current: ReleaseVersion) throws -> AppRelease? {
        let candidates: [(ReleaseVersion, AppRelease)] = releases.compactMap { release in
            guard !release.draft, let version = ReleaseVersion(release.tag_name),
                  current.isPrerelease || !(release.prerelease || version.isPrerelease),
                  let page = trustedURL(release.html_url, prefix: "/qDonl/crux-shotter/releases/tag/"),
                  let asset = release.assets.first(where: {
                      $0.name == "CruxShotter-\(release.tag_name.drop(while: { $0 == "v" })).dmg"
                          && $0.state == "uploaded" && $0.size > 0
                  }),
                  let download = trustedURL(asset.browser_download_url, prefix: "/qDonl/crux-shotter/releases/download/")
            else { return nil }
            return (version, AppRelease(version: release.tag_name, pageURL: page, downloadURL: download))
        }
        guard let newest = candidates.max(by: { $0.0 < $1.0 }) else { throw UpdateError.noReleases }
        return newest.0 > current ? newest.1 : nil
    }

    private static func trustedURL(_ value: String, prefix: String) -> URL? {
        guard let url = URL(string: value), url.scheme == "https", url.host == "github.com",
              url.user == nil, url.password == nil, url.port == nil, url.path.hasPrefix(prefix) else { return nil }
        return url
    }

    private struct Release: Decodable {
        let tag_name: String
        let html_url: String
        let draft: Bool
        let prerelease: Bool
        let assets: [Asset]
    }
    private struct Asset: Decodable {
        let name: String
        let browser_download_url: String
        let state: String
        let size: Int
    }
}
