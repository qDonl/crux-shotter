import AppKit
import SwiftUI
import CruxShotKit
import OSLog

/// Screen-recording permission guide. One window, reused; shown on first launch without
/// permission and whenever a capture is attempted without it.
@MainActor
final class OnboardingWindow {
    private static let logger = Logger(subsystem: "com.cruxshot", category: "Onboarding")
    private var window: NSWindow?
    /// Called right before relaunching so the old instance releases its global shortcuts (the new
    /// instance would otherwise probe them as taken), and again if the relaunch fails.
    var willRelaunch: () -> Void = {}
    var relaunchFailed: () -> Void = {}

    func show() {
        let w = window ?? makeWindow()
        window = w
        ActivationHelper.activateForKeyboard()
        if !w.isVisible { w.center() }
        w.makeKeyAndOrderFront(nil)
    }

    private func makeWindow() -> NSWindow {
        let view = OnboardingView(openSettings: Self.openSystemSettings,
                                  relaunch: { [weak self] in self?.relaunch() })
        let w = NSWindow(contentViewController: NSHostingController(rootView: view))
        w.title = "CruxShotter"
        w.styleMask = [.titled, .closable]
        w.isReleasedWhenClosed = false
        w.level = .normal
        return w
    }

    private static func openSystemSettings() {
        ScreenCapturePermission.request()
        NSWorkspace.shared.open(ScreenCapturePermission.settingsURL)
    }

    /// Screen-recording permission only takes effect in a new process.
    private func relaunch() {
        willRelaunch()
        let config = NSWorkspace.OpenConfiguration()
        config.createsNewApplicationInstance = true
        NSWorkspace.shared.openApplication(at: Bundle.main.bundleURL, configuration: config) { [weak self] _, error in
            Task { @MainActor in
                if let error {
                    Self.logger.error("relaunch failed: \(error.localizedDescription)")
                    self?.relaunchFailed()
                    Toast.show("重启失败", detail: "请手动退出并重新打开 CruxShotter")
                    return
                }
                NSApp.terminate(nil)
            }
        }
    }
}

private struct OnboardingView: View {
    let openSettings: () -> Void
    let relaunch: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "rectangle.dashed.badge.record")
                .font(.system(size: 44))
                .foregroundStyle(.tint)
                .accessibilityHidden(true)
            Text("CruxShotter 需要屏幕录制权限")
                .font(.title2.weight(.semibold))
            Text("仅用于截取屏幕画面，所有数据只保存在本机。")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Text("在「系统设置 › 隐私与安全性 › 屏幕与系统录音」中打开 CruxShotter，然后重启应用。")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 12) {
                Button("打开系统设置", action: openSettings)
                    .keyboardShortcut(.defaultAction)
                Button("我已授权，立即重启", action: relaunch)
            }
            .padding(.top, 4)
        }
        .padding(28)
        .frame(width: 420)
    }
}
