import AppKit

/// Small child panel, outside the image; never participates in image composition or takes focus.
@MainActor
final class PinActionBar {
    private let panel: NSPanel
    private let surface: HoverSurface
    private weak var parent: NSWindow?
    private var overImage = false
    private var overBar = false
    private var hideTask: Task<Void, Never>?

    init(parent: NSWindow, action: @escaping (PinAction) -> Void, menu: @escaping () -> NSMenu?) {
        self.parent = parent
        surface = HoverSurface()
        panel = NSPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel],
                        backing: .buffered, defer: false)
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hidesOnDeactivate = false
        panel.hasShadow = true
        panel.isReleasedWhenClosed = false
        panel.level = .floating
        panel.contentView = surface
        let edit = ToolbarButton(symbol: "pencil", tooltip: "编辑标注 (E)") { action(.edit) }
        let copy = ToolbarButton(symbol: "doc.on.doc", tooltip: "复制 (⌘C)") { action(.copy) }
        let more = ToolbarButton(symbol: "ellipsis", tooltip: "更多操作") { [weak surface] in
            guard let surface else { return }
            menu()?.popUp(positioning: nil, at: NSPoint(x: 0, y: surface.bounds.minY), in: surface)
        }
        let close = ToolbarButton(symbol: "xmark", tooltip: "关闭贴图 (Esc)") { action(.close) }
        let stack = NSStackView(views: [edit, copy, more, close])
        stack.spacing = 2
        stack.translatesAutoresizingMaskIntoConstraints = false
        surface.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: surface.leadingAnchor, constant: 4),
            stack.trailingAnchor.constraint(equalTo: surface.trailingAnchor, constant: -4),
            stack.topAnchor.constraint(equalTo: surface.topAnchor, constant: 4),
            stack.bottomAnchor.constraint(equalTo: surface.bottomAnchor, constant: -4),
        ])
        surface.onHover = { [weak self] hovered in
            self?.overBar = hovered
            self?.updateVisibility()
        }
    }

    func hover(_ hovered: Bool) {
        overImage = hovered
        updateVisibility()
    }

    func layout() {
        guard let parent else { return }
        let size = surface.fittingSize
        let available = (parent.screen ?? NSScreen.main)?.visibleFrame ?? parent.frame
        let x = max(available.minX + 6, min(parent.frame.maxX - size.width, available.maxX - size.width - 6))
        var y = parent.frame.maxY + 6
        if y + size.height > available.maxY - 6 { y = parent.frame.minY - size.height - 6 }
        y = max(available.minY + 6, min(y, available.maxY - size.height - 6))
        panel.setFrame(CGRect(origin: CGPoint(x: x, y: y), size: size), display: true)
    }

    func hide() {
        hideTask?.cancel()
        overImage = false
        overBar = false
        panel.parent?.removeChildWindow(panel)
        panel.orderOut(nil)
    }

    private func updateVisibility() {
        guard let parent, parent.isVisible else { hide(); return }
        hideTask?.cancel()
        if overImage || overBar {
            layout()
            if panel.parent == nil { parent.addChildWindow(panel, ordered: .above) }
            panel.orderFrontRegardless()
        } else {
            hideTask = Task { @MainActor [weak self] in
                do { try await Task.sleep(for: .milliseconds(250)) } catch { return }
                self?.hide()
            }
        }
    }
}

@MainActor
private final class HoverSurface: ToolbarSurface {
    var onHover: ((Bool) -> Void)?
    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        for area in trackingAreas { removeTrackingArea(area) }
        addTrackingArea(NSTrackingArea(rect: .zero, options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
                                       owner: self, userInfo: nil))
    }
    override func mouseEntered(with event: NSEvent) { onHover?(true) }
    override func mouseExited(with event: NSEvent) { onHover?(false) }
}
