import Foundation
import CoreGraphics
import Vision

public enum RecognitionError: Error {
    case failed(String)
}

public enum TextRecognizer {
    /// Recognizes text lines, ordered top-to-bottom then left-to-right.
    public static func recognize(_ image: CGImage) async throws -> [String] {
        try await Task.detached(priority: .userInitiated) {
            let request = VNRecognizeTextRequest()
            request.recognitionLevel = .accurate
            request.recognitionLanguages = ["zh-Hans", "zh-Hant", "en-US"]
            request.usesLanguageCorrection = true
            do {
                try VNImageRequestHandler(cgImage: image, options: [:]).perform([request])
            } catch {
                throw RecognitionError.failed(error.localizedDescription)
            }
            let observations = request.results ?? []
            // Vision boxes are normalized with origin bottom-left, so larger maxY is higher.
            let sorted = observations.sorted { a, b in
                let ay = a.boundingBox.maxY, by = b.boundingBox.maxY
                if abs(ay - by) > 0.005 { return ay > by }
                return a.boundingBox.minX < b.boundingBox.minX
            }
            return sorted.compactMap { $0.topCandidates(1).first?.string }
        }.value
    }
}

extension Array where Element == String {
    public var joinedAsLines: String { joined(separator: "\n") }

    public var joinedAsSingleLine: String {
        var result = ""
        for line in self {
            if let last = result.unicodeScalars.last, let first = line.unicodeScalars.first,
               Self.isCJK(last), Self.isCJK(first) {
                result += line
            } else if result.isEmpty {
                result = line
            } else {
                result += " " + line
            }
        }
        return result
    }

    private static func isCJK(_ s: Unicode.Scalar) -> Bool {
        switch s.value {
        case 0x4E00...0x9FFF, 0x3400...0x4DBF, 0x20000...0x2A6DF, 0xF900...0xFAFF, // Han
             0x3040...0x309F, 0x30A0...0x30FF, 0x31F0...0x31FF,                     // Kana
             0xAC00...0xD7AF, 0x1100...0x11FF, 0x3130...0x318F,                     // Hangul
             0x3000...0x303F, 0xFF00...0xFFEF:                                      // CJK punctuation, fullwidth
            return true
        default:
            return false
        }
    }
}
