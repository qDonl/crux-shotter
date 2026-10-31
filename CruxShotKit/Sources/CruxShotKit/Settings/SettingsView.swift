import SwiftUI
import AppKit
import KeyboardShortcuts

public struct SettingsView: View {
    @ObservedObject private var preferences: Preferences
    private let checkForUpdates: () -> Void
    @ObservedObject private var updates: UpdateChecker
    private let usesSparkle: Bool
    @State private var selected: Page = .general

    private enum Page: String, CaseIterable {
        case general = "通用", shortcuts = "快捷键", about = "关于"
        var symbol: String {
            switch self {
            case .general: "slider.horizontal.3"
            case .shortcuts: "keyboard"
            case .about: "info.circle"
            }
        }
    }

    public init(preferences: Preferences, checkForUpdates: @escaping () -> Void = {},
                updates: UpdateChecker = .shared, usesSparkle: Bool = false) {
        self.preferences = preferences
        self.checkForUpdates = checkForUpdates
        self.updates = updates
        self.usesSparkle = usesSparkle
    }

    public var body: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 4) {
                ForEach(Page.allCases, id: \.self) { page in
                    Button { selected = page } label: {
                        Label(page.rawValue, systemImage: page.symbol)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 10).padding(.vertical, 8)
                            .background(selected == page ? Color.accentColor.opacity(0.12) : .clear,
                                        in: RoundedRectangle(cornerRadius: 6))
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(selected == page ? .isSelected : [])
                }
                Spacer()
                Text("CruxShotter").font(.caption).foregroundStyle(.secondary).padding(.horizontal, 10)
            }
            .padding(12).frame(width: 144)
            .frame(maxHeight: .infinity)
            .background(.quaternary.opacity(0.35))
            Divider()
            VStack(alignment: .leading, spacing: 16) {
                Text(selected.rawValue).font(.title2.weight(.semibold))
                switch selected {
                case .general: GeneralTab(preferences: preferences)
                case .shortcuts: ShortcutsTab()
                case .about: AboutTab(preferences: preferences, updates: updates, checkForUpdates: checkForUpdates, usesSparkle: usesSparkle)
                }
            }
            .padding(24).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .frame(width: 660, height: 480)
        .background(Color(nsColor: .windowBackgroundColor))
    }
}

private struct GeneralTab: View {
    @ObservedObject var preferences: Preferences

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("保存截图").font(.subheadline).foregroundStyle(.secondary)
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("保存位置")
                        Text(preferences.saveDirectory.path)
                            .font(.caption).lineLimit(2).truncationMode(.middle).foregroundStyle(.secondary)
                            .help(preferences.saveDirectory.path).textSelection(.enabled)
                    }
                    Spacer()
                    Button("选择…", action: chooseDirectory)
                }
                Picker("图片格式", selection: $preferences.imageFormat) {
                    ForEach(ImageFormat.allCases, id: \.self) { Text($0.rawValue.uppercased()).tag($0) }
                }
                .pickerStyle(.segmented)
                VStack(alignment: .leading, spacing: 7) {
                    Text("文件名模板")
                    TextField("CruxShotter {yyyy-MM-dd HH.mm.ss}", text: $preferences.fileNameTemplate)
                        .textFieldStyle(.roundedBorder)
                    Text(FileNameTemplate(pattern: preferences.fileNameTemplate).fileName(for: Date())
                         + "." + preferences.imageFormat.rawValue)
                        .font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                        .textSelection(.enabled).lineLimit(2)
                    Text("花括号内填写日期格式，例如 {yyyy-MM-dd}；留空使用默认名称。")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Divider()
                Picker("菜单栏图标", selection: $preferences.menuBarIconStyle) {
                    ForEach(MenuBarIconStyle.allCases, id: \.self) { style in
                        Text(style.title).tag(style)
                    }
                }
                .pickerStyle(.segmented)
            }
        }
    }

    private func chooseDirectory() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.directoryURL = preferences.saveDirectory
        if let window = NSApp.keyWindow {
            panel.beginSheetModal(for: window) { response in
                if response == .OK, let url = panel.url { preferences.saveDirectory = url }
            }
        } else if panel.runModal() == .OK, let url = panel.url {
            preferences.saveDirectory = url
        }
    }
}

private struct ShortcutsTab: View {
    @ObservedObject private var conflicts = ShortcutConflicts.shared

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text("截图").font(.subheadline).foregroundStyle(.secondary)
                row("区域截图", .captureArea)
                row("全屏截图", .captureFullScreen)
                row("OCR 截图", .captureOCR)
                Divider().padding(.vertical, 4)
                Text("贴图").font(.subheadline).foregroundStyle(.secondary)
                row("剪贴板贴图", .pinClipboard)
                row("显示 / 隐藏贴图", .togglePins)
                row("恢复关闭的贴图", .restorePin)
                Text("点击快捷键即可重新录制。冲突时请更换组合，或清除其他应用的同名快捷键。")
                    .font(.caption).foregroundStyle(.secondary).padding(.top, 8)
            }
        }
    }

    private func row(_ title: String, _ name: KeyboardShortcuts.Name) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title)
                Spacer()
                KeyboardShortcuts.Recorder("", name: name).accessibilityLabel(title)
            }
            if conflicts.isConflicted(name) {
                Label("与其他应用冲突，请重新录制", systemImage: "exclamationmark.triangle")
                    .font(.caption).foregroundStyle(.red)
            }
        }
        .frame(minHeight: 30)
    }
}

private struct AboutTab: View {
    @ObservedObject var preferences: Preferences
    @ObservedObject var updates: UpdateChecker
    let checkForUpdates: () -> Void
    let usesSparkle: Bool

    private var version: String {
        let info = Bundle.main.infoDictionary ?? [:]
        let short = (info["CFBundleShortVersionString"] as? String) ?? CruxShotKit.version
        guard let build = info["CFBundleVersion"] as? String, !build.isEmpty else { return short }
        return "\(short) (\(build))"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("CruxShotter").font(.title.weight(.medium))
            Text("截图、标注、贴图，让工作保持流畅。")
            Text("版本 \(usesSparkle ? version : updates.currentVersion)").font(.callout).foregroundStyle(.secondary)
            Divider()
            Link("在 GitHub 查看项目", destination: URL(string: "https://github.com/qDonl/crux-shotter")!)
            HStack(spacing: 10) {
                Button(updates.isChecking ? "正在检查…" : "检查更新…", action: checkForUpdates)
                    .disabled(updates.isChecking)
                if updates.isChecking { ProgressView().controlSize(.small) }
            }
            if !usesSparkle {
                Toggle("启动时自动检查更新（每天最多一次）", isOn: $preferences.automaticallyChecksForUpdates)
                    .font(.callout)
                updateStatus
                Text("检测 GitHub 上的新版本，下载后手动安装。预览版本会同时检查后续预览版和正式版。")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder private var updateStatus: some View {
        switch updates.state {
        case .available(let release):
            HStack {
                Text("发现新版本 \(release.version)").font(.callout)
                Link("下载新版", destination: release.downloadURL)
            }
        case .upToDate:
            Label("当前已是最新版本", systemImage: "checkmark.circle").font(.caption).foregroundStyle(.secondary)
        case .failed(let message):
            Text(message).font(.caption).foregroundStyle(.red).fixedSize(horizontal: false, vertical: true)
        case .idle, .checking: EmptyView()
        }
    }

}
