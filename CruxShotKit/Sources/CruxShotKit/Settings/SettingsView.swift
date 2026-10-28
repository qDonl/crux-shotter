import SwiftUI
import AppKit
import KeyboardShortcuts

public struct SettingsView: View {
    @ObservedObject private var preferences: Preferences
    private let checkForUpdates: () -> Void
    private let updatesEnabled: Bool

    public init(preferences: Preferences, checkForUpdates: @escaping () -> Void = {},
                updatesEnabled: Bool = true) {
        self.preferences = preferences
        self.checkForUpdates = checkForUpdates
        self.updatesEnabled = updatesEnabled
    }

    public var body: some View {
        TabView {
            GeneralTab(preferences: preferences)
                .tabItem { Text("通用") }
            ShortcutsTab()
                .tabItem { Text("快捷键") }
            AboutTab(checkForUpdates: checkForUpdates, updatesEnabled: updatesEnabled)
                .tabItem { Text("关于") }
        }
        .frame(width: 480, height: 320)
    }
}

private struct GeneralTab: View {
    @ObservedObject var preferences: Preferences

    var body: some View {
        Form {
            HStack {
                Text("保存目录")
                Text(preferences.saveDirectory.path)
                    .lineLimit(1).truncationMode(.middle).foregroundStyle(.secondary)
                Spacer()
                Button("选择…", action: chooseDirectory)
            }
            Picker("图片格式", selection: $preferences.imageFormat) {
                ForEach(ImageFormat.allCases, id: \.self) { Text($0.rawValue.uppercased()).tag($0) }
            }
            TextField("文件名模板", text: $preferences.fileNameTemplate)
            LabeledContent("预览") {
                Text(FileNameTemplate(pattern: preferences.fileNameTemplate).fileName(for: Date())
                     + "." + preferences.imageFormat.rawValue)
                    .foregroundStyle(.secondary)
            }
            Picker("菜单栏图标", selection: $preferences.menuBarIconStyle) {
                ForEach(MenuBarIconStyle.allCases, id: \.self) { style in
                    Label {
                        Text(style.title)
                    } icon: {
                        if let image = NSImage(named: style.assetName) { Image(nsImage: image) }
                    }
                    .tag(style)
                }
            }
            .pickerStyle(.radioGroup)
        }
        .padding(20)
    }

    private func chooseDirectory() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.directoryURL = preferences.saveDirectory
        if panel.runModal() == .OK, let url = panel.url {
            preferences.saveDirectory = url
        }
    }
}

private struct ShortcutsTab: View {
    @ObservedObject private var conflicts = ShortcutConflicts.shared

    var body: some View {
        Form {
            row("区域截图", .captureArea)
            row("全屏截图", .captureFullScreen)
            row("OCR 截图", .captureOCR)
            row("剪贴板贴图", .pinClipboard)
            row("显示/隐藏贴图", .togglePins)
            row("恢复关闭的贴图", .restorePin)
        }
        .padding(20)
    }

    private func row(_ title: String, _ name: KeyboardShortcuts.Name) -> some View {
        HStack {
            KeyboardShortcuts.Recorder(title, name: name)
            if conflicts.isConflicted(name) {
                Text("与其他应用冲突").font(.caption).foregroundStyle(.red)
            }
        }
    }
}

private struct AboutTab: View {
    let checkForUpdates: () -> Void
    let updatesEnabled: Bool

    private var version: String {
        let info = Bundle.main.infoDictionary ?? [:]
        let short = (info["CFBundleShortVersionString"] as? String) ?? CruxShotKit.version
        guard let build = info["CFBundleVersion"] as? String, !build.isEmpty else { return short }
        return "\(short) (\(build))"
    }

    var body: some View {
        VStack(spacing: 12) {
            Text("CruxShotter").font(.title)
            Text("版本 \(version)").foregroundStyle(.secondary)
            Link("GitHub", destination: URL(string: "https://github.com/qDonl/crux-shotter")!)
            Button("检查更新", action: checkForUpdates)
                .disabled(!updatesEnabled)
                .help(updatesEnabled ? "" : "自动更新尚未配置")
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
