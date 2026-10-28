import AppKit
import Sparkle
import SwiftUI
import CruxShotKit
import KeyboardShortcuts

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private static let onboardingShownKey = "cruxshot.onboardingShown"
    private static let allShortcuts: [KeyboardShortcuts.Name] = [
        .captureArea, .captureFullScreen, .captureOCR, .pinClipboard, .togglePins, .restorePin,
    ]

    private var coordinator: AppCoordinator?
    private var statusController: StatusItemController?
    private let onboarding = OnboardingWindow()
    private var settingsWindow: NSWindow?

    /// Updates need an EdDSA public key baked in at build time (`SPARKLE_PUBLIC_KEY`); without one
    /// the updater is created but never started and the UI entry points are disabled.
    private static let hasUpdateKey: Bool = {
        let key = Bundle.main.object(forInfoDictionaryKey: "SUPublicEDKey") as? String
        return !(key ?? "").trimmingCharacters(in: .whitespaces).isEmpty
    }()
    private var updaterController: SPUStandardUpdaterController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        updaterController = SPUStandardUpdaterController(
            startingUpdater: Self.hasUpdateKey, updaterDelegate: nil, userDriverDelegate: nil)
        let presenter = PinWindowPresenter()
        let pins = PinManager(presenter: presenter)
        presenter.manager = pins

        let coordinator = AppCoordinator(capture: ScreenCaptureService(), preferences: .shared, pins: pins)
        coordinator.showOnboarding = { [onboarding] in onboarding.show() }
        presenter.onSave = { [weak coordinator] image in coordinator?.save(image) }
        presenter.onOCR = { [weak coordinator] image in coordinator?.recognizeToClipboard(image) }
        self.coordinator = coordinator

        onboarding.willRelaunch = { KeyboardShortcuts.disable(Self.allShortcuts) }
        onboarding.relaunchFailed = { KeyboardShortcuts.enable(Self.allShortcuts) }

        // Probe before adding listeners; re-probes whenever a shortcut changes.
        ShortcutConflicts.shared.monitor(Self.allShortcuts)
        registerShortcuts(coordinator)

        statusController = StatusItemController(coordinator: coordinator, presenter: presenter,
                                                conflicts: .shared,
                                                openSettings: { [weak self] in self?.showSettings() })
        if Self.hasUpdateKey {
            statusController?.checkForUpdates = { [weak self] in self?.updaterController?.checkForUpdates(nil) }
        }

        let defaults = UserDefaults.standard
        if !ScreenCapturePermission.isGranted, !defaults.bool(forKey: Self.onboardingShownKey) {
            defaults.set(true, forKey: Self.onboardingShownKey)
            onboarding.show()
        }
    }

    private func registerShortcuts(_ c: AppCoordinator) {
        KeyboardShortcuts.onKeyUp(for: .captureArea) { [weak c] in c?.captureArea() }
        KeyboardShortcuts.onKeyUp(for: .captureFullScreen) { [weak c] in c?.captureFullScreen() }
        KeyboardShortcuts.onKeyUp(for: .captureOCR) { [weak c] in c?.captureOCR() }
        KeyboardShortcuts.onKeyUp(for: .pinClipboard) { [weak c] in c?.pinClipboard() }
        KeyboardShortcuts.onKeyUp(for: .togglePins) { [weak c] in c?.togglePins() }
        KeyboardShortcuts.onKeyUp(for: .restorePin) { [weak c] in c?.restorePin() }
    }

    /// Own window rather than the SwiftUI `Settings` scene: opening that scene from an accessory
    /// (LSUIElement) app is unreliable on macOS 14.
    private func showSettings() {
        let window = settingsWindow ?? {
            let view = SettingsView(preferences: .shared,
                                    checkForUpdates: { [weak self] in self?.updaterController?.checkForUpdates(nil) },
                                    updatesEnabled: Self.hasUpdateKey)
            let w = NSWindow(contentViewController: NSHostingController(rootView: view))
            w.title = "CruxShotter 设置"
            w.styleMask = [.titled, .closable]
            w.isReleasedWhenClosed = false
            w.center()
            return w
        }()
        settingsWindow = window
        NSApp.activate()
        window.makeKeyAndOrderFront(nil)
    }
}
