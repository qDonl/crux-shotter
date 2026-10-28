import AppKit
import Testing
@testable import CruxShotKit

@MainActor @Suite struct ClipboardContentTests {
    func privatePB() -> NSPasteboard {
        let pb = NSPasteboard(name: NSPasteboard.Name("crux.test.\(UUID().uuidString)"))
        pb.clearContents(); return pb
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
}
