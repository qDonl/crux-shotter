import Foundation

public struct FileNameTemplate: Sendable {
    public static let `default` = FileNameTemplate(pattern: "CruxShot {yyyy-MM-dd HH.mm.ss}")

    public let pattern: String

    public init(pattern: String) { self.pattern = pattern }

    /// Expands each `{…}` group as a `DateFormatter` format; other text is kept verbatim.
    /// `/` and `:` in the result are replaced with `-`.
    public func fileName(for date: Date, timeZone: TimeZone = .current) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = timeZone

        var result = ""
        var rest = Substring(pattern)
        while let open = rest.firstIndex(of: "{") {
            result += rest[rest.startIndex..<open]
            let afterOpen = rest.index(after: open)
            guard let close = rest[afterOpen...].firstIndex(of: "}") else {
                result += rest[open...]
                rest = ""
                break
            }
            formatter.dateFormat = String(rest[afterOpen..<close])
            result += formatter.string(from: date)
            rest = rest[rest.index(after: close)...]
        }
        result += rest
        return result.replacingOccurrences(of: "/", with: "-").replacingOccurrences(of: ":", with: "-")
    }
}
