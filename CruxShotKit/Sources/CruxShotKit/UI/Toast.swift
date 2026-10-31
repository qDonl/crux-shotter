import AppKit

/// Non-activating notice on the pointer's screen. A new toast replaces the current one;
/// notices last 2.5s (6s with an action), and remain visible while hovered.
@MainActor
public enum Toast {
    static let width: CGFloat = 300
    static let inset: CGFloat = 16
    static let duration: Double = 2.5
    static let durationWithAction: Double = 6
    static let fadeDuration: Double = 0.2

    private static var panel: NSPanel?
    private static var actionTarget: ActionTarget?
    private static var generation = 0

    public static func show(_ message: String, detail: String? = nil,
                            action: (title: String, handler: () -> Void)? = nil) {
        dismissNow()
        generation += 1
        let g = generation

        let title = NSTextField(labelWithString: message)
        title.font = .systemFont(ofSize: 13, weight: .semibold)
        title.lineBreakMode = .byTruncatingTail
        var views: [NSView] = [title]
        if let detail {
            let label = NSTextField(wrappingLabelWithString: detail)
            label.font = .systemFont(ofSize: 11)
            label.textColor = .secondaryLabelColor
            label.maximumNumberOfLines = 3
            label.toolTip = detail
            label.setAccessibilityValue(detail)
            label.lineBreakMode = .byTruncatingTail
            label.preferredMaxLayoutWidth = width - 24
            views.append(label)
        }
        if let action {
            let target = ActionTarget(handler: action.handler)
            actionTarget = target
            let button = NSButton(title: action.title, target: target, action: #selector(ActionTarget.fire))
            button.bezelStyle = .rounded
            button.controlSize = .small
            views.append(button)
        }
        let stack = NSStackView(views: views)
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 4
        stack.translatesAutoresizingMaskIntoConstraints = false

        let effect = ToastSurface()
        effect.material = .hudWindow
        effect.blendingMode = .behindWindow
        effect.state = .active
        effect.wantsLayer = true
        effect.layer?.cornerRadius = 10
        effect.layer?.masksToBounds = true
        effect.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: effect.leadingAnchor, constant: 12),
            stack.trailingAnchor.constraint(lessThanOrEqualTo: effect.trailingAnchor, constant: -12),
            stack.topAnchor.constraint(equalTo: effect.topAnchor, constant: 10),
            stack.bottomAnchor.constraint(equalTo: effect.bottomAnchor, constant: -10),
            effect.widthAnchor.constraint(equalToConstant: width),
        ])
        let size = effect.fittingSize

        let p = NSPanel(contentRect: CGRect(origin: .zero, size: size),
                        styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: true)
        p.isFloatingPanel = true
        p.level = .statusBar
        p.hidesOnDeactivate = false
        p.becomesKeyOnlyIfNeeded = true
        p.isOpaque = false
        p.backgroundColor = .clear
        p.hasShadow = true
        p.isReleasedWhenClosed = false
        p.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        p.contentView = effect
        if let screen = NSScreen.screens.first(where: { $0.frame.contains(NSEvent.mouseLocation) }) ?? NSScreen.main {
            let vf = screen.visibleFrame
            p.setFrameOrigin(CGPoint(x: vf.maxX - inset - size.width, y: vf.maxY - inset - size.height))
        }
        p.alphaValue = 1
        p.orderFrontRegardless()
        panel = p

        let seconds = action == nil ? duration : durationWithAction
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(seconds))
            guard generation == g else { return }
            // Leave actionable notices readable while the pointer is over the panel.
            while generation == g, effect.isHovered {
                try? await Task.sleep(for: .seconds(1))
            }
            guard generation == g else { return }
            await fadeOut(generation: g)
        }
    }

    private static func fadeOut(generation g: Int) async {
        guard generation == g, let p = panel else { return }
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion ? 0 : fadeDuration
            p.animator().alphaValue = 0
        }, completionHandler: nil)
        try? await Task.sleep(for: .seconds(fadeDuration))
        guard generation == g else { return }
        dismissNow()
    }

    private static func dismissNow() {
        panel?.orderOut(nil)
        panel = nil
        actionTarget = nil
    }

    fileprivate static func actionFired(_ handler: () -> Void) {
        generation += 1
        dismissNow()
        handler()
    }
}

@MainActor
private final class ActionTarget: NSObject {
    let handler: () -> Void
    init(handler: @escaping () -> Void) { self.handler = handler }
    @objc func fire() {
        let h = handler
        Toast.actionFired(h)
    }
}

@MainActor
private final class ToastSurface: NSVisualEffectView {
    private(set) var isHovered = false
    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        for area in trackingAreas { removeTrackingArea(area) }
        addTrackingArea(NSTrackingArea(rect: .zero, options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
                                       owner: self, userInfo: nil))
    }
    override func mouseEntered(with event: NSEvent) { isHovered = true }
    override func mouseExited(with event: NSEvent) { isHovered = false }
}
