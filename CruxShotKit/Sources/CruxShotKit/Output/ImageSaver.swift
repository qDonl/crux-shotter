import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

public enum ImageFormat: String, CaseIterable, Sendable {
    case png, jpg

    public var fileExtension: String { rawValue }

    var utType: UTType { self == .png ? .png : .jpeg }
}

public struct SaveResult: Sendable, Equatable {
    public let url: URL
    public let usedFallback: Bool

    public init(url: URL, usedFallback: Bool) {
        self.url = url
        self.usedFallback = usedFallback
    }
}

public enum ImageSaverError: Error { case encodingFailed }

public struct ImageSaver {
    private let fileManager: FileManager

    public init(fileManager: FileManager = .default) { self.fileManager = fileManager }

    /// Saves into `directory` (created if missing); on any failure retries in `fallbackDirectory`.
    /// Existing files are never overwritten: ` 2`, ` 3`… is appended to the name.
    public func save(_ image: CGImage, directory: URL, fileName: String,
                     format: ImageFormat, fallbackDirectory: URL) throws -> SaveResult {
        do {
            return SaveResult(url: try write(image, to: directory, fileName: fileName, format: format),
                              usedFallback: false)
        } catch {
            return SaveResult(url: try write(image, to: fallbackDirectory, fileName: fileName, format: format),
                              usedFallback: true)
        }
    }

    private func write(_ image: CGImage, to directory: URL, fileName: String, format: ImageFormat) throws -> URL {
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = uniqueURL(in: directory, fileName: fileName, ext: format.fileExtension)

        guard let dest = CGImageDestinationCreateWithURL(url as CFURL, format.utType.identifier as CFString, 1, nil)
        else { throw ImageSaverError.encodingFailed }
        let options: [CFString: Any] = format == .jpg ? [kCGImageDestinationLossyCompressionQuality: 0.9] : [:]
        CGImageDestinationAddImage(dest, image, options as CFDictionary)
        guard CGImageDestinationFinalize(dest) else {
            try? fileManager.removeItem(at: url)
            throw ImageSaverError.encodingFailed
        }
        return url
    }

    private func uniqueURL(in directory: URL, fileName: String, ext: String) -> URL {
        var url = directory.appending(path: "\(fileName).\(ext)")
        var n = 2
        while fileManager.fileExists(atPath: url.path) {
            url = directory.appending(path: "\(fileName) \(n).\(ext)")
            n += 1
        }
        return url
    }
}
