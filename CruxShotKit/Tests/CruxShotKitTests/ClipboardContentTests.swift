import AppKit
import Testing
@testable import CruxShotKit

@MainActor @Suite struct ClipboardContentTests {
    func privatePB() -> NSPasteboard {
        let pb = NSPasteboard(name: NSPasteboard.Name("crux.test.\(UUID().uuidString)"))
        pb.clearContents(); return pb
    }
    func tempFile(_ name: String, _ data: Data) throws -> URL {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("crux.test.\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let url = dir.appendingPathComponent(name)
        try data.write(to: url)
        return url
    }
    func pngData() -> Data {
        let rep = NSBitmapImageRep(cgImage: makeImage(width: 4, height: 4) { _, _ in RGBColor(r: 255, g: 0, b: 0) })
        return rep.representation(using: .png, properties: [:])!
    }

    @Test func clipboardPrefersImage() {
        let pb = privatePB()
        pb.writeObjects([NSImage(size: .init(width: 2, height: 2), flipped: false) { _ in true }])
        pb.setString("hello", forType: .string)
        if case .image = ClipboardContent.read(from: pb) {} else { Issue.record("expected image") }
    }
    @Test func textWhenNoImage() {
        let pb = privatePB(); pb.setString("hello", forType: .string)
        #expect(ClipboardContent.read(from: pb) == .text("hello"))
    }
    @Test func whitespaceTextIsNone() {
        let pb = privatePB(); pb.setString("  \n ", forType: .string)
        #expect(ClipboardContent.read(from: pb) == .none)
    }

    @Test func imageFilesFromFinder() throws {
        let png = try tempFile("a.png", pngData())
        let txt = try tempFile("b.txt", Data("hi".utf8))
        let pb = privatePB()
        pb.writeObjects([png as NSURL, txt as NSURL])
        #expect(ClipboardContent.read(from: pb) == .imageFiles([png]))
    }
    @Test func nonImageFilesNeverPinTheFinderIcon() throws {
        let txt = try tempFile("b.txt", Data("hi".utf8))
        let pb = privatePB()
        pb.writeObjects([txt as NSURL])
        pb.addTypes([.tiff], owner: nil)
        pb.setData(NSImage(size: .init(width: 2, height: 2), flipped: false) { _ in true }.tiffRepresentation, forType: .tiff)
        pb.setString("b.txt", forType: .string)
        #expect(ClipboardContent.read(from: pb) == .text("b.txt"))
    }

    @Test func colorValue() {
        let pb = privatePB(); pb.setString(" #FF6A00 ", forType: .string)
        #expect(ClipboardContent.read(from: pb) == .color(ColorLiteral(rgb: RGBColor(r: 255, g: 106, b: 0), alpha: 1)))
    }
    @Test func colorBeatsRichText() throws {
        let pb = privatePB()
        let rich = NSAttributedString(string: "#00FF00", attributes: [.font: NSFont.boldSystemFont(ofSize: 20)])
        pb.setData(try rich.data(from: NSRange(location: 0, length: rich.length),
                                 documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf]), forType: .rtf)
        pb.setString("#00FF00", forType: .string)
        if case .color = ClipboardContent.read(from: pb) {} else { Issue.record("expected color") }
    }

    @Test func richTextFromRTF() throws {
        let pb = privatePB()
        let rich = NSAttributedString(string: "Bold\n", attributes: [.font: NSFont.boldSystemFont(ofSize: 20)])
        pb.setData(try rich.data(from: NSRange(location: 0, length: rich.length),
                                 documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf]), forType: .rtf)
        pb.setString("Bold", forType: .string)
        guard case .richText(let s) = ClipboardContent.read(from: pb) else { Issue.record("expected rich text"); return }
        #expect(s.string == "Bold")
        let font = s.attribute(.font, at: 0, effectiveRange: nil) as? NSFont
        #expect(font?.pointSize == 20)
    }
    @Test func richTextFromHTML() {
        let pb = privatePB()
        pb.setString("<p>Hello <b>世界</b></p>", forType: .html)
        pb.setString("Hello 世界", forType: .string)
        guard case .richText(let s) = ClipboardContent.read(from: pb) else { Issue.record("expected rich text"); return }
        #expect(s.string == "Hello 世界")
    }
    @Test func blankRichTextFallsBackToNone() {
        let pb = privatePB()
        pb.setString("<p> </p>", forType: .html)
        #expect(ClipboardContent.read(from: pb) == .none)
    }
}
