import AppKit
import Testing
@testable import CruxShotKit

@Suite struct ImageFileLoaderTests {
    private func tempURL(_ name: String) throws -> URL {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("crux.test.\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent(name)
    }

    @Test func loadsPNG() throws {
        let url = try tempURL("a.png")
        let rep = NSBitmapImageRep(cgImage: makeImage(width: 30, height: 20) { _, _ in RGBColor(r: 0, g: 255, b: 0) })
        try rep.representation(using: .png, properties: [:])!.write(to: url)
        let img = try #require(ImageFileLoader.load(url, scale: 2))
        #expect(img.width == 30 && img.height == 20)
    }

    @Test func rendersFirstPDFPageAtScale() throws {
        let url = try tempURL("a.pdf")
        var box = CGRect(x: 0, y: 0, width: 200, height: 100)
        let ctx = try #require(CGContext(url as CFURL, mediaBox: &box, nil))
        for _ in 0..<2 { ctx.beginPDFPage(nil); ctx.endPDFPage() }
        ctx.closePDF()
        let img = try #require(ImageFileLoader.load(url, scale: 2))
        #expect(img.width == 400 && img.height == 200)
    }

    @Test func unreadableFileIsNil() throws {
        let url = try tempURL("a.png")
        try Data("not an image".utf8).write(to: url)
        #expect(ImageFileLoader.load(url, scale: 2) == nil)
    }
}
