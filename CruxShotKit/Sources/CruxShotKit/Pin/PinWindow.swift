import AppKit

/// Borderless floating panel for one pin. Becomes key on click (to receive keys) without
/// activating the app, so the frontmost app keeps its focus when a pin is shown.
@MainActor
final class PinWindow: NSPanel {
    init(frame: CGRect) {
        super.init(contentRect: frame, styleMask: [.borderless, .nonactivatingPanel],
                   backing: .buffered, defer: false)
        level = .floating
        hasShadow = true
        isMovableByWindowBackground = true
        becomesKeyOnlyIfNeeded = false
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
        isOpaque = false
        backgroundColor = .clear
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    func setFollowsSpaces(_ follows: Bool) {
        // Not following: default managed behaviour keeps the pin on the Space it was created on.
        let behavior: NSWindow.CollectionBehavior = follows
            ? [.canJoinAllSpaces, .fullScreenAuxiliary] : [.fullScreenAuxiliary]
        if collectionBehavior != behavior { collectionBehavior = behavior }
    }
}

/// `NSMenuItem` whose action is a closure (the item retains it via `representedObject`).
@MainActor
final class PinMenuAction: NSObject {
    private let handler: () -> Void
    init(_ handler: @escaping () -> Void) { self.handler = handler }
    @objc func fire() { handler() }

    static func item(_ title: String, checked: Bool = false, _ handler: @escaping () -> Void) -> NSMenuItem {
        let target = PinMenuAction(handler)
        let item = NSMenuItem(title: title, action: #selector(fire), keyEquivalent: "")
        item.target = target
        item.representedObject = target
        item.state = checked ? .on : .off
        return item
    }
}
