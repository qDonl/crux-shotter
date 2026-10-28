import AppKit
import Combine
import CruxShotKit
import KeyboardShortcuts

/// Menu bar icon and its menu. Pin-related items are rebuilt each time the menu opens; the icon
/// shows an orange dot while any global shortcut conflicts with another app.
@MainActor
final class StatusItemController: NSObject, NSMenuDelegate {
    private static let dotSize: CGFloat = 6

    private let coordinator: AppCoordinator
    private let presenter: PinWindowPresenter
    private let openSettings: () -> Void
    /// Nil when auto-update is not configured (no Sparkle public key); the item stays disabled.
    var checkForUpdates: (() -> Void)?

    private let statusItem: NSStatusItem
    private let conflictDot = NSView()
    private var conflictsObserver: AnyCancellable?

    private let restoreItem = NSMenuItem(title: "恢复关闭的贴图", action: #selector(restorePin), keyEquivalent: "")
    private let closeAllItem = NSMenuItem(title: "关闭全部贴图", action: #selector(closeAllPins), keyEquivalent: "")
    private let pinListItem = NSMenuItem(title: "贴图列表", action: nil, keyEquivalent: "")
    private let updatesItem = NSMenuItem(title: "检查更新…", action: #selector(checkUpdates), keyEquivalent: "")

    init(coordinator: AppCoordinator, presenter: PinWindowPresenter, conflicts: ShortcutConflicts,
         openSettings: @escaping () -> Void) {
        self.coordinator = coordinator
        self.presenter = presenter
        self.openSettings = openSettings
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        super.init()
        setUpButton()
        statusItem.menu = makeMenu()
        conflictsObserver = conflicts.$conflicted.sink { [weak self] names in
            self?.conflictDot.isHidden = names.isEmpty
            self?.statusItem.button?.setAccessibilityHelp(names.isEmpty ? nil : "有快捷键与其他应用冲突")
        }
    }

    private func setUpButton() {
        guard let button = statusItem.button else { return }
        let image = NSImage(systemSymbolName: "camera.viewfinder", accessibilityDescription: "CruxShotter")
        image?.isTemplate = true
        button.image = image
        button.toolTip = "CruxShotter"

        conflictDot.wantsLayer = true
        conflictDot.layer?.backgroundColor = NSColor.systemOrange.cgColor
        conflictDot.layer?.cornerRadius = Self.dotSize / 2
        conflictDot.isHidden = true
        conflictDot.translatesAutoresizingMaskIntoConstraints = false
        button.addSubview(conflictDot)
        NSLayoutConstraint.activate([
            conflictDot.widthAnchor.constraint(equalToConstant: Self.dotSize),
            conflictDot.heightAnchor.constraint(equalToConstant: Self.dotSize),
            conflictDot.topAnchor.constraint(equalTo: button.topAnchor, constant: 2),
            conflictDot.trailingAnchor.constraint(equalTo: button.trailingAnchor, constant: -2),
        ])
    }

    private func makeMenu() -> NSMenu {
        let menu = NSMenu()
        menu.delegate = self
        menu.autoenablesItems = false
        menu.addItem(item("区域截图", #selector(captureArea), shortcut: .captureArea))
        menu.addItem(item("全屏截图", #selector(captureFullScreen), shortcut: .captureFullScreen))
        menu.addItem(item("OCR 截图", #selector(captureOCR), shortcut: .captureOCR))
        menu.addItem(.separator())
        menu.addItem(item("剪贴板贴图", #selector(pinClipboard), shortcut: .pinClipboard))
        menu.addItem(item("显示/隐藏贴图", #selector(togglePins), shortcut: .togglePins))
        restoreItem.target = self
        restoreItem.setShortcut(for: .restorePin)
        menu.addItem(restoreItem)
        closeAllItem.target = self
        menu.addItem(closeAllItem)
        pinListItem.submenu = NSMenu()
        menu.addItem(pinListItem)
        menu.addItem(.separator())
        menu.addItem(item("设置…", #selector(showSettings)))
        updatesItem.target = self
        menu.addItem(updatesItem)
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "退出 CruxShotter", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        return menu
    }

    private func item(_ title: String, _ action: Selector, shortcut: KeyboardShortcuts.Name? = nil) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
        item.target = self
        if let shortcut { item.setShortcut(for: shortcut) }
        return item
    }

    // MARK: NSMenuDelegate

    func menuNeedsUpdate(_ menu: NSMenu) {
        guard menu === statusItem.menu else { return }
        let pins = coordinator.pins
        restoreItem.isEnabled = pins.canRestore
        closeAllItem.isEnabled = !pins.items.isEmpty
        updatesItem.isEnabled = checkForUpdates != nil
        updatesItem.toolTip = checkForUpdates == nil ? "自动更新尚未配置" : nil

        let submenu = NSMenu()
        submenu.autoenablesItems = false
        for (index, pin) in pins.items.enumerated() {
            let entry = NSMenuItem(title: "贴图 \(index + 1)（\(pin.image.width)×\(pin.image.height)）",
                                   action: #selector(focusPin(_:)), keyEquivalent: "")
            entry.target = self
            entry.representedObject = pin.id
            submenu.addItem(entry)
        }
        pinListItem.submenu = submenu
        pinListItem.isEnabled = !pins.items.isEmpty
    }

    // MARK: Actions

    @objc private func captureArea() { coordinator.captureArea() }
    @objc private func captureFullScreen() { coordinator.captureFullScreen() }
    @objc private func captureOCR() { coordinator.captureOCR() }
    @objc private func pinClipboard() { coordinator.pinClipboard() }
    @objc private func togglePins() { coordinator.togglePins() }
    @objc private func restorePin() { coordinator.restorePin() }
    @objc private func closeAllPins() { coordinator.pins.closeAll() }
    @objc private func showSettings() { openSettings() }
    @objc private func checkUpdates() { checkForUpdates?() }

    /// Makes the pin interactive again (click-through off) and brings it to the front.
    @objc private func focusPin(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? UUID else { return }
        let pins = coordinator.pins
        if pins.isHidden { pins.toggleHidden() }
        guard var item = pins.items.first(where: { $0.id == id }) else { return }
        if item.clickThrough {
            item.clickThrough = false
            pins.update(item)
        }
        presenter.bringToFront(id: id)
    }
}
