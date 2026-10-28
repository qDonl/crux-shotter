import Testing
import Carbon.HIToolbox
import KeyboardShortcuts
@testable import CruxShotKit

@MainActor
struct HotKeyProbeTests {
    @Test func unusualComboIsAvailable() {
        let shortcut = KeyboardShortcuts.Shortcut(.f12, modifiers: [.control, .option, .shift, .command])
        #expect(HotKeyProbe.isAvailable(shortcut))
        // The probe releases its registration, so a second probe still succeeds.
        #expect(HotKeyProbe.isAvailable(shortcut))
    }

    @Test func comboHeldElsewhereIsUnavailable() throws {
        let shortcut = KeyboardShortcuts.Shortcut(.f11, modifiers: [.control, .option, .shift, .command])
        var ref: EventHotKeyRef?
        let status = RegisterEventHotKey(UInt32(shortcut.carbonKeyCode), UInt32(shortcut.carbonModifiers),
                                         EventHotKeyID(signature: 0x5445_5354, id: 7),
                                         GetEventDispatcherTarget(), 0, &ref)
        try #require(status == noErr)
        let held = try #require(ref)
        defer { UnregisterEventHotKey(held) }
        #expect(!HotKeyProbe.isAvailable(shortcut))
    }
}
