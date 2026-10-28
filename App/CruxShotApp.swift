import SwiftUI
import CruxShotKit

@main
struct CruxShotApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Settings { SettingsView(preferences: .shared, checkForUpdates: {}, updatesEnabled: false) }
    }
}
