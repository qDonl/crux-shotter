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

    /// Signed Sparkle feeds support in-app installation. Alpha builds use GitHub release detection.
    private static let hasUpdateKey: Bool = {
        let key = Bundle.main.object(forInfoDictionaryKey: "SUPublicEDKey") as? String
        return !(key ?? "").trimmingCharacters(in: .whitespaces).isEmpty
    }()
    private let githubUpdates = UpdateChecker.shared
    private var automaticUpdateTask: Task<Void, Never>?
    private var updaterController: SPUStandardUpdaterController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        updaterController = SPUStandardUpdaterController(
            startingUpdater: Self.hasUpdateKey, updaterDelegate: nil, userDriverDelegate: nil)
        // The presenter is needed to build the coordinator, so its callbacks reach it weakly.
        weak var weakCoordinator: AppCoordinator?
        let presenter = PinWindowPresenter(onSave: { weakCoordinator?.save($0) },
                                           onOCR: { weakCoordinator?.recognizeToClipboard($0) })
        let pins = PinManager(presenter: presenter)
        presenter.manager = pins

        let coordinator = AppCoordinator(capture: ScreenCaptureService(), preferences: .shared, pins: pins)
        coordinator.showOnboarding = { [onboarding] in onboarding.show() }
        weakCoordinator = coordinator
        self.coordinator = coordinator

        onboarding.willRelaunch = { KeyboardShortcuts.disable(Self.allShortcuts) }
        onboarding.relaunchFailed = { KeyboardShortcuts.enable(Self.allShortcuts) }

        // Probe before adding listeners; re-probes whenever a shortcut changes.
        ShortcutConflicts.shared.monitor(Self.allShortcuts)
        registerShortcuts(coordinator)

        statusController = StatusItemController(coordinator: coordinator, presenter: presenter,
                                                conflicts: .shared,
                                                openSettings: { [weak self] in self?.showSettings() })
        statusController?.checkForUpdates = { [weak self] in self?.checkForUpdates() }
        statusController?.updatesAreChecking = { [weak self] in self?.githubUpdates.isChecking ?? false }
        if !Self.hasUpdateKey {
            automaticUpdateTask = Task { @MainActor [weak self] in
                do { try await Task.sleep(for: .seconds(5)) } catch { return }
                guard let self, Preferences.shared.automaticallyChecksForUpdates,
                      githubUpdates.shouldCheckAutomatically() else { return }
                guard await githubUpdates.check(), !Task.isCancelled, Preferences.shared.automaticallyChecksForUpdates,
                      let release = githubUpdates.takeAutomaticNotice() else { return }
                Toast.show("发现新版本 \(release.version)", detail: "当前版本 \(githubUpdates.currentVersion)",
                           action: ("查看新版", { NSWorkspace.shared.open(release.pageURL) }))
            }
        }

        let defaults = UserDefaults.standard
        if !ScreenCapturePermission.isGranted, !defaults.bool(forKey: Self.onboardingShownKey) {
            defaults.set(true, forKey: Self.onboardingShownKey)
            onboarding.show()
        }
    }

    func applicationWillTerminate(_ notification: Notification) { automaticUpdateTask?.cancel() }

    private func checkForUpdates() {
        if Self.hasUpdateKey {
            updaterController?.checkForUpdates(nil)
            return
        }
        Task { @MainActor [weak self] in
            guard let self, await githubUpdates.check() else { return }
            let alert = NSAlert()
            switch githubUpdates.state {
            case .available(let release):
                alert.messageText = "发现新版本 \(release.version)"
                alert.informativeText = "当前版本 \(githubUpdates.currentVersion)。下载 DMG 后退出旧版，再将新版拖入应用程序。"
                alert.addButton(withTitle: "下载新版")
                alert.addButton(withTitle: "查看发布说明")
                alert.addButton(withTitle: "稍后")
                ActivationHelper.activateForKeyboard()
                switch alert.runModal() {
                case .alertFirstButtonReturn: NSWorkspace.shared.open(release.downloadURL)
                case .alertSecondButtonReturn: NSWorkspace.shared.open(release.pageURL)
                default: break
                }
                return
            case .upToDate:
                alert.messageText = "当前已是最新版本"
                alert.informativeText = "CruxShotter \(githubUpdates.currentVersion)"
            case .failed(let message):
                alert.alertStyle = .warning
                alert.messageText = "检查更新失败"
                alert.informativeText = message
                alert.addButton(withTitle: "好")
                alert.addButton(withTitle: "前往 GitHub")
                ActivationHelper.activateForKeyboard()
                if alert.runModal() == .alertSecondButtonReturn { NSWorkspace.shared.open(GitHubReleaseService.releasesURL) }
                return
            case .idle, .checking: return
            }
            alert.addButton(withTitle: "好")
            ActivationHelper.activateForKeyboard()
            alert.runModal()
        }
    }

    private func registerShortcuts(_ c: AppCoordinator) {
        KeyboardShortcuts.onKeyDown(for: .captureArea) { [weak c] in c?.captureArea() }
        KeyboardShortcuts.onKeyDown(for: .captureFullScreen) { [weak c] in c?.captureFullScreen() }
        KeyboardShortcuts.onKeyDown(for: .captureOCR) { [weak c] in c?.captureOCR() }
        KeyboardShortcuts.onKeyDown(for: .pinClipboard) { [weak c] in c?.pinClipboard() }
        KeyboardShortcuts.onKeyDown(for: .togglePins) { [weak c] in c?.togglePins() }
        KeyboardShortcuts.onKeyDown(for: .restorePin) { [weak c] in c?.restorePin() }
    }

    /// Own window rather than the SwiftUI `Settings` scene: opening that scene from an accessory
    /// (LSUIElement) app is unreliable on macOS 14.
    func showSettings() {
        let window = settingsWindow ?? {
            let view = SettingsView(preferences: .shared,
                                    checkForUpdates: { [weak self] in self?.checkForUpdates() },
                                    updates: githubUpdates, usesSparkle: Self.hasUpdateKey)
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
