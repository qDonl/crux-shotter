import Carbon.HIToolbox
import KeyboardShortcuts

/// KeyboardShortcuts does not report Carbon registration failures, so availability is probed by
/// registering the combination exclusively and releasing it straight away. Callers must first
/// `KeyboardShortcuts.disable(_:)` their own registration of the same shortcut, or it will look taken.
@MainActor
public enum HotKeyProbe {
    /// "CXPR"
    private static let signature: OSType = 0x4358_5052

    public static func isAvailable(_ shortcut: KeyboardShortcuts.Shortcut) -> Bool {
        var ref: EventHotKeyRef?
        let status = RegisterEventHotKey(
            UInt32(shortcut.carbonKeyCode),
            UInt32(shortcut.carbonModifiers),
            EventHotKeyID(signature: signature, id: 1),
            GetEventDispatcherTarget(),
            OptionBits(kEventHotKeyExclusive),
            &ref
        )
        guard status == noErr, let ref else { return false }
        UnregisterEventHotKey(ref)
        return true
    }
}
