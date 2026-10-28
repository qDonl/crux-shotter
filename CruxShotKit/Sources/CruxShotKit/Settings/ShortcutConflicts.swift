import Foundation
import Combine
import KeyboardShortcuts

/// Which global shortcuts could not be registered because another app holds them.
/// Read by the menu bar icon (orange dot) and the settings Shortcuts tab.
@MainActor
public final class ShortcutConflicts: ObservableObject {
    public static let shared = ShortcutConflicts()

    /// KeyboardShortcuts posts this (internal) notification with `userInfo["name"]` on every change.
    private static let changeNotification = Notification.Name("KeyboardShortcuts_shortcutByNameDidChange")

    @Published public private(set) var conflicted: Set<KeyboardShortcuts.Name> = []
    private var monitored: Set<KeyboardShortcuts.Name> = []
    private var observer: NSObjectProtocol?

    public init() {}

    public var hasConflicts: Bool { !conflicted.isEmpty }

    public func isConflicted(_ name: KeyboardShortcuts.Name) -> Bool { conflicted.contains(name) }

    /// Probes `names` now (call before adding `onKeyDown` handlers) and again whenever one changes.
    public func monitor(_ names: [KeyboardShortcuts.Name]) {
        monitored.formUnion(names)
        for name in names { recheck(name) }
        guard observer == nil else { return }
        observer = NotificationCenter.default.addObserver(
            forName: Self.changeNotification, object: nil, queue: .main
        ) { [weak self] note in
            guard let name = note.userInfo?["name"] as? KeyboardShortcuts.Name else { return }
            MainActor.assumeIsolated {
                guard let self, self.monitored.contains(name) else { return }
                self.recheck(name)
            }
        }
    }

    /// Releases our own registration first so the probe does not collide with ourselves.
    public func recheck(_ name: KeyboardShortcuts.Name) {
        guard let shortcut = KeyboardShortcuts.getShortcut(for: name) else {
            conflicted.remove(name)
            return
        }
        KeyboardShortcuts.disable(name)
        let available = HotKeyProbe.isAvailable(shortcut)
        KeyboardShortcuts.enable(name)
        if available { conflicted.remove(name) } else { conflicted.insert(name) }
    }
}
