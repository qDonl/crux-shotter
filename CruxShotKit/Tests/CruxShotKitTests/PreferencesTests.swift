import Foundation
import Testing
import KeyboardShortcuts
@testable import CruxShotKit

@MainActor
@Test func defaults() {
    let p = Preferences(defaults: UserDefaults(suiteName: UUID().uuidString)!)
    #expect(p.saveDirectory.path.hasSuffix("/Desktop/CruxShot"))
    #expect(p.imageFormat == .png)
    #expect(p.fileNameTemplate == FileNameTemplate.default.pattern)
    #expect(p.lastColor == .red && p.lastLineWidth == .medium && p.colorFormat == .hex)
    #expect(p.mosaicMode == .pixelate)
    #expect(Preferences.fallbackDirectory.path.hasSuffix("/Pictures"))
}

@MainActor
@Test func persists() {
    let ud = UserDefaults(suiteName: UUID().uuidString)!
    let p = Preferences(defaults: ud)
    p.imageFormat = .jpg
    p.fileNameTemplate = "X {yyyy}"
    p.lastColor = .blue
    p.lastLineWidth = .thick
    p.colorFormat = .rgb
    p.mosaicMode = .blur
    p.saveDirectory = URL(fileURLWithPath: "/tmp/shots")
    let q = Preferences(defaults: ud)
    #expect(q.imageFormat == .jpg)
    #expect(q.fileNameTemplate == "X {yyyy}")
    #expect(q.lastColor == .blue && q.lastLineWidth == .thick && q.colorFormat == .rgb)
    #expect(q.mosaicMode == .blur)
    #expect(q.saveDirectory.path == "/tmp/shots")
}

@MainActor
@Test func invalidStoredValuesFallBack() {
    let ud = UserDefaults(suiteName: UUID().uuidString)!
    ud.set("bmp", forKey: "cruxshot.imageFormat")
    ud.set("pink", forKey: "cruxshot.lastColor")
    ud.set(99.0, forKey: "cruxshot.lastLineWidth")
    let p = Preferences(defaults: ud)
    #expect(p.imageFormat == .png && p.lastColor == .red && p.lastLineWidth == .medium)
}

@Test func shortcutDefaults() {
    #expect(KeyboardShortcuts.Name.captureArea.defaultShortcut == .init(.a, modifiers: [.control, .shift]))
    #expect(KeyboardShortcuts.Name.captureFullScreen.defaultShortcut == .init(.f, modifiers: [.control, .shift]))
    #expect(KeyboardShortcuts.Name.captureOCR.defaultShortcut == .init(.o, modifiers: [.control, .shift]))
    #expect(KeyboardShortcuts.Name.pinClipboard.defaultShortcut == .init(.p, modifiers: [.control, .shift]))
    #expect(KeyboardShortcuts.Name.togglePins.defaultShortcut == .init(.h, modifiers: [.control, .shift]))
    #expect(KeyboardShortcuts.Name.restorePin.defaultShortcut == .init(.z, modifiers: [.control, .shift]))
}
