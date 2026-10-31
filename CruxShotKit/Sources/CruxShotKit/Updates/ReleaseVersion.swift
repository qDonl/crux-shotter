import Foundation

/// Semantic version ordering, including numeric prerelease identifiers (alpha.10 > alpha.2).
/// Build metadata does not affect precedence. Short numeric versions are padded with zeros.
struct ReleaseVersion: Comparable, Sendable {
    private let numbers: [Int]
    private let prerelease: [String]
    var isPrerelease: Bool { !prerelease.isEmpty }

    init?(_ value: String) {
        var value = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if value.hasPrefix("v") { value.removeFirst() }
        let metadata = value.split(separator: "+", maxSplits: 1, omittingEmptySubsequences: false)
        if metadata.count == 2, !Self.validIdentifiers(String(metadata[1])) { return nil }
        let parts = metadata[0].split(separator: "-", maxSplits: 1, omittingEmptySubsequences: false)
        let numeric = parts[0].split(separator: ".", omittingEmptySubsequences: false)
        guard (1...3).contains(numeric.count), numeric.allSatisfy({ Self.isNumber(String($0)) }),
              numeric.allSatisfy({ Int($0) != nil && ($0.count == 1 || !$0.hasPrefix("0")) }) else { return nil }
        numbers = numeric.map { Int($0)! } + Array(repeating: 0, count: 3 - numeric.count)
        if parts.count == 2 {
            guard Self.validIdentifiers(String(parts[1])) else { return nil }
            prerelease = parts[1].split(separator: ".").map(String.init)
            guard prerelease.allSatisfy({ !Self.isNumber($0) || $0.count == 1 || !$0.hasPrefix("0") }) else { return nil }
        } else {
            prerelease = []
        }
    }

    static func < (lhs: Self, rhs: Self) -> Bool {
        if lhs.numbers != rhs.numbers { return lhs.numbers.lexicographicallyPrecedes(rhs.numbers) }
        if lhs.prerelease.isEmpty { return false }
        if rhs.prerelease.isEmpty { return true }
        for (a, b) in zip(lhs.prerelease, rhs.prerelease) where a != b {
            let an = isNumber(a), bn = isNumber(b)
            if an && bn { return a.count == b.count ? a < b : a.count < b.count }
            if an != bn { return an }
            return a < b
        }
        return lhs.prerelease.count < rhs.prerelease.count
    }

    private static func isNumber(_ value: String) -> Bool {
        !value.isEmpty && value.utf8.allSatisfy { (48...57).contains($0) }
    }

    private static func validIdentifiers(_ value: String) -> Bool {
        value.split(separator: ".", omittingEmptySubsequences: false).allSatisfy { part in
            !part.isEmpty && part.utf8.allSatisfy {
                (48...57).contains($0) || (65...90).contains($0) || (97...122).contains($0) || $0 == 45
            }
        }
    }
}
