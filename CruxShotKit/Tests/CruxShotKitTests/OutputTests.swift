import Testing
import AppKit
import Foundation
@testable import CruxShotKit

private func img() -> CGImage {
    makeImage(width: 4, height: 4) { _, _ in RGBColor(r: 10, g: 20, b: 30) }
}

private func tmp() throws -> URL {
    let url = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
}

private func cleanup(_ urls: URL...) {
    for u in urls {
        try? FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: u.path)
        try? FileManager.default.removeItem(at: u)
    }
}

@Suite struct OutputTests {
    @Test func defaultFileName() {
        let date = ISO8601DateFormatter().date(from: "2026-10-28T13:03:15Z")!
        #expect(FileNameTemplate.default.fileName(for: date, timeZone: TimeZone(identifier: "Asia/Shanghai")!)
                == "CruxShotter 2026-10-28 21.03.15")
    }

    @Test func slashAndColonReplaced() {
        let date = ISO8601DateFormatter().date(from: "2026-10-28T13:03:15Z")!
        let t = FileNameTemplate(pattern: "a/b {HH:mm}")
        #expect(t.fileName(for: date, timeZone: TimeZone(identifier: "UTC")!) == "a-b 13-03")
    }

    @Test(arguments: ["", "   ", " \n "])
    func emptyTemplateFallsBackToDefault(pattern: String) {
        let date = ISO8601DateFormatter().date(from: "2026-10-28T13:03:15Z")!
        let tz = TimeZone(identifier: "Asia/Shanghai")!
        #expect(FileNameTemplate(pattern: pattern).fileName(for: date, timeZone: tz)
                == "CruxShotter 2026-10-28 21.03.15")
    }

    @Test func createsMissingDirectory() throws {
        let base = try tmp(); let fb = try tmp()
        defer { cleanup(base, fb) }
        let dir = base.appending(path: "a/b")
        let r = try ImageSaver().save(img(), directory: dir, fileName: "x", format: .png, fallbackDirectory: fb)
        #expect(r.url.path == dir.appending(path: "x.png").path && !r.usedFallback)
        #expect(FileManager.default.fileExists(atPath: r.url.path))
    }

    @Test func fallsBackWhenUnwritable() throws {
        let ro = try tmp(); let fb = try tmp()
        defer { cleanup(ro, fb) }
        try FileManager.default.setAttributes([.posixPermissions: 0o500], ofItemAtPath: ro.path)
        let r = try ImageSaver().save(img(), directory: ro, fileName: "x", format: .png, fallbackDirectory: fb)
        #expect(r.usedFallback && r.url.deletingLastPathComponent().path == fb.path)
    }

    @Test func throwsWhenBothFail() throws {
        let ro = try tmp()
        defer { cleanup(ro) }
        try FileManager.default.setAttributes([.posixPermissions: 0o500], ofItemAtPath: ro.path)
        #expect(throws: (any Error).self) {
            try ImageSaver().save(img(), directory: ro, fileName: "x", format: .png, fallbackDirectory: ro)
        }
    }

    @Test func avoidsOverwrite() throws {
        let dir = try tmp(); let fb = try tmp()
        defer { cleanup(dir, fb) }
        func save() throws -> SaveResult {
            try ImageSaver().save(img(), directory: dir, fileName: "x", format: .png, fallbackDirectory: fb)
        }
        _ = try save()
        let r = try save()
        #expect(r.url.lastPathComponent == "x 2.png")
        #expect(try save().url.lastPathComponent == "x 3.png")
    }

    @Test func jpgWrites() throws {
        let dir = try tmp()
        defer { cleanup(dir) }
        let r = try ImageSaver().save(img(), directory: dir, fileName: "y", format: .jpg, fallbackDirectory: dir)
        #expect(r.url.lastPathComponent == "y.jpg")
        let data = try Data(contentsOf: r.url)
        #expect(data.prefix(2) == Data([0xFF, 0xD8]))
    }

    @MainActor @Test func clipboardRoundTrip() {
        let pb = NSPasteboard(name: .init(UUID().uuidString))
        ClipboardWriter.write(text: "hi", to: pb)
        #expect(pb.string(forType: .string) == "hi")
    }

    @MainActor @Test func clipboardImage() {
        let pb = NSPasteboard(name: .init(UUID().uuidString))
        ClipboardWriter.write(image: img(), to: pb)
        #expect(pb.data(forType: .png) != nil)
        #expect(pb.data(forType: .tiff) != nil)
    }
}
