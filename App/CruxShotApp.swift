import SwiftUI

@main
struct CruxShotApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        // SwiftUI requires a scene; the real settings window is AppDelegate's own NSWindow, so this
        // scene is empty and ⌘, is routed there to keep a single settings window.
        Settings { EmptyView() }
            .commands {
                CommandGroup(replacing: .appSettings) {
                    Button("设置…") { appDelegate.showSettings() }
                        .keyboardShortcut(",", modifiers: .command)
                }
            }
    }
}
