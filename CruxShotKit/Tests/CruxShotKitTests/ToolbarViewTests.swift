import AppKit
import SwiftUI
import Testing
@testable import CruxShotKit

@Suite @MainActor struct ToolbarViewTests {
    @Test func twoRowRackKeepsOutputSeparateAndCanvasFocus() throws {
        _ = NSApplication.shared
        let toolbar = ToolbarView()
        let window = NSWindow(contentRect: CGRect(x: 0, y: 0, width: 700, height: 450),
                              styleMask: [.borderless], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        defer { window.close() }
        let responder = NSTextView(frame: CGRect(x: 160, y: 150, width: 380, height: 220))
        let content = NSView(frame: CGRect(x: 0, y: 0, width: 700, height: 450))
        window.contentView = content
        content.wantsLayer = true
        content.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
        responder.string = "func captureArea() {\n    let snapshot = await screen.capture()\n    overlay.present(snapshot)\n\n    // 让每一次捕捉都恰到好处。\n}"
        responder.font = .monospacedSystemFont(ofSize: 13, weight: .regular)
        responder.textContainerInset = CGSize(width: 16, height: 18)
        content.addSubview(responder)
        content.addSubview(toolbar)
        content.addSubview(toolbar.toolRack)
        window.makeFirstResponder(responder)
        var sizes: [CGSize] = []
        for tool in [nil, CanvasTool.rect, .arrow, .text, .mosaic] {
            toolbar.update(tool: tool, color: .red, lineWidth: .medium, mosaicMode: .pixelate,
                           canUndo: false, canRedo: false)
            let placement = ToolbarLayout(selection: responder.frame, available: content.bounds,
                                          toolSize: toolbar.toolRack.fittingSize, actionSize: toolbar.fittingSize)
            toolbar.frame = placement.actions
            toolbar.toolRack.frame = placement.tools
            content.layoutSubtreeIfNeeded()
            sizes.append(toolbar.fittingSize)
            #expect(toolbar.fittingSize.width > 200 && toolbar.fittingSize.width < 300)
            #expect(toolbar.toolRack.fittingSize.width > 240)
            #expect(toolbar.toolRack.fittingSize.height <= 90)
            #expect(!placement.tools.intersects(placement.actions))
        }
        #expect(Set(sizes.map { $0.width }).count == 1)
        #expect(Set(sizes.map { $0.height }).count == 1)
        let tight = ToolbarLayout(selection: CGRect(x: 85, y: 90, width: 340, height: 240),
                                  available: CGRect(x: 0, y: 0, width: 512, height: 384),
                                  toolSize: toolbar.toolRack.fittingSize, actionSize: toolbar.fittingSize)
        #expect(CGRect(x: 0, y: 0, width: 512, height: 384).contains(tight.tools))
        #expect(!tight.tools.intersects(tight.actions))
        let buttons = descendants(toolbar.toolRack).compactMap { $0 as? ToolbarButton }
        let actionButtons = descendants(toolbar).compactMap { $0 as? ToolbarButton }
        #expect(actionButtons.allSatisfy { $0.title.isEmpty })
        #expect(toolbar.colorChoices.count == PaletteColor.allCases.count)
        #expect(toolbar.colorChoices.values.allSatisfy { $0.title.isEmpty && $0.toolTip != nil })
        #expect(toolbar.colorChoices.values.allSatisfy { $0.isDescendant(of: toolbar.toolRack) })
        let select = try #require(buttons.first { $0.toolTip == "选择 / 移动标注 (V)" })
        var selected = false
        toolbar.onCommand = { if case .select = $0 { selected = true } }
        select.performClick(nil)
        #expect(selected)
        #expect(window.firstResponder === responder)
        toolbar.update(tool: .rect, color: .red, lineWidth: .medium, mosaicMode: .pixelate,
                       canUndo: false, canRedo: false)
        #expect(!toolbar.propertyBar.isHidden)
        content.layoutSubtreeIfNeeded()
        try snapshot(content, name: "split-editor-native")
        try snapshot(toolbar, name: "output-bar")
        try snapshot(toolbar.toolRack, name: "tool-rack")
    }

    @Test func settingsHaveSpaceForLongPathsAndFilenameTemplates() throws {
        let suite = "cruxshot.ui.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let preferences = Preferences(defaults: defaults)
        preferences.saveDirectory = URL(fileURLWithPath: "/Users/Developer/Documents/项目文件/非常长的截图保存文件夹名称/CruxShotter")
        let host = NSHostingView(rootView: SettingsView(preferences: preferences))
        host.frame = CGRect(x: 0, y: 0, width: 660, height: 480)
        host.layoutSubtreeIfNeeded()
        #expect(host.fittingSize.width == 660)
        #expect(host.fittingSize.height == 480)
        try snapshot(host, name: "settings")
    }

    private func descendants(_ view: NSView) -> [NSView] {
        view.subviews.flatMap { [$0] + descendants($0) }
    }

    /// Opt-in native renders for visual inspection; no screenshot baselines are asserted.
    private func snapshot(_ view: NSView, name: String) throws {
        guard let path = ProcessInfo.processInfo.environment["CRUXSHOT_UI_SNAPSHOTS"] else { return }
        for (suffix, appearance) in [("light", NSAppearance.Name.aqua), ("dark", .darkAqua)] {
            // Capture HUDs keep their explicit dark appearance; settings follow the chosen appearance.
            if !(view is ToolbarSurface) { view.appearance = NSAppearance(named: appearance) }
            view.layoutSubtreeIfNeeded()
            let bitmap = try #require(view.bitmapImageRepForCachingDisplay(in: view.bounds))
            view.cacheDisplay(in: view.bounds, to: bitmap)
            let png = try #require(bitmap.representation(using: .png, properties: [:]))
            try png.write(to: URL(fileURLWithPath: path).appendingPathComponent("\(name)-\(suffix).png"))
        }
    }
}
