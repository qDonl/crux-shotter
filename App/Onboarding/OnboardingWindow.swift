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
    @State private var requested = false
    @State private var granted = ScreenCapturePermission.isGranted

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Label("开始使用 CruxShotter", systemImage: "viewfinder")
                .font(.title2.weight(.semibold))
            Text("允许屏幕录制，即可开始截图。")
            VStack(alignment: .leading, spacing: 10) {
                Label("仅用于截取屏幕画面", systemImage: "rectangle.dashed")
                Label("截图和文字识别均在本机处理", systemImage: "lock")
            }
            .font(.callout).foregroundStyle(.secondary)
            Divider()
            Text(granted ? "权限已开启，重启应用后开始使用。" :
                 "在系统设置的「屏幕与系统录音」中开启 CruxShotter，然后回到这里重启。")
                .font(.callout).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            HStack {
                if requested && !granted {
                    Button("已授权，重启应用", action: relaunch)
                }
                Spacer()
                Button(granted ? "重启并开始使用" : "打开系统设置") {
                    if granted { relaunch() } else { requested = true; openSettings() }
                }
                .keyboardShortcut(.defaultAction)
            }
            Text("稍后也可从菜单栏继续设置；剪贴板贴图无需录屏权限。")
                .font(.caption).foregroundStyle(.secondary)
        }
        .padding(28).frame(width: 440)
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            granted = ScreenCapturePermission.isGranted
        }
    }
}
