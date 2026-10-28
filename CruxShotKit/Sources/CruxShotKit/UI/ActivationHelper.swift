import AppKit

/// Single place for the "steal focus so our window gets the keyboard" activation.
@MainActor
public enum ActivationHelper {
    /// Activates the app even when another app is frontmost.
    ///
    /// CruxShotter is an accessory (LSUIElement) app usually triggered by a global hotkey while
    /// another app is focused. macOS 14's cooperative `NSApp.activate()` may be refused in that
    /// case, leaving the overlay / OCR panel visible but without key focus (Esc, Enter, R… then go
    /// to the previous app). `activate(ignoringOtherApps: true)` is deprecated in macOS 14 but
    /// still forces activation reliably, so it is used deliberately here — this is the only call
    /// site and the only expected deprecation warning.
    public static func activateForKeyboard() {
        NSApp.activate(ignoringOtherApps: true)
    }
}
