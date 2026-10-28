import SwiftUI
import AppKit
import KeyboardShortcuts

public struct SettingsView: View {
    @ObservedObject private var preferences: Preferences
    private let checkForUpdates: () -> Void

    public init(preferences: Preferences, checkForUpdates: @escaping () -> Void = {}) {
        self.preferences = preferences
        self.checkForUpdates = checkForUpdates
    }

    public var body: some View {
        TabView {
            GeneralTab(preferences: preferences)
                .tabItem { Text("通用") }
            ShortcutsTab()
                .tabItem { Text("快捷键") }
            AboutTab(checkForUpdates: checkForUpdates)
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
    var body: some View {
        Form {
            KeyboardShortcuts.Recorder("区域截图", name: .captureArea)
            KeyboardShortcuts.Recorder("全屏截图", name: .captureFullScreen)
            KeyboardShortcuts.Recorder("OCR 截图", name: .captureOCR)
            KeyboardShortcuts.Recorder("剪贴板贴图", name: .pinClipboard)
            KeyboardShortcuts.Recorder("显示/隐藏贴图", name: .togglePins)
            KeyboardShortcuts.Recorder("恢复关闭的贴图", name: .restorePin)
        }
        .padding(20)
    }
}

private struct AboutTab: View {
    let checkForUpdates: () -> Void

    private var version: String {
        (Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String)
            ?? CruxShotKit.version
    }

    var body: some View {
        VStack(spacing: 12) {
            Text("CruxShot").font(.title)
            Text("版本 \(version)").foregroundStyle(.secondary)
            Link("GitHub", destination: URL(string: "https://github.com/cruxshot/cruxshot")!)
            Button("检查更新", action: checkForUpdates)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
