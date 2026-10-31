import AppKit
import Testing
@testable import CruxShotKit

@Suite @MainActor struct PinActionBarTests {
    @Test func lateHoverDoesNotShowControlsForHiddenPin() {
        _ = NSApplication.shared
        // Never order the parent on screen: this exercises the stale-event guard without UI automation.
        let parent = NSWindow(contentRect: CGRect(x: 100, y: 100, width: 200, height: 100),
                              styleMask: [.borderless], backing: .buffered, defer: false)
        parent.isReleasedWhenClosed = false
        defer { parent.close() }
        let actions = PinActionBar(parent: parent, action: { _ in }, menu: { nil })
        defer { actions.hide() }
        actions.hover(true)
        #expect(!parent.isVisible)
        #expect(parent.childWindows?.isEmpty ?? true)
        actions.hover(false)
        actions.hover(true)
        #expect(parent.childWindows?.isEmpty ?? true)
    }
}
