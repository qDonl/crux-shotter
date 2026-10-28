import AppKit

/// One borderless, shielding-level window per captured display. Its content is the frozen
/// screenshot (as a layer, so redraws of the overlay never re-decode the image) with an
/// `OverlayView` on top.
@MainActor
final class OverlayWindow: NSWindow {
    let overlayView: OverlayView

    init(frame captured: CapturedFrame, controller: OverlayController) {
        let rect = captured.display.frame
        overlayView = OverlayView(captured: captured, controller: controller)
        super.init(contentRect: rect, styleMask: .borderless, backing: .buffered, defer: false)
        level = NSWindow.Level(rawValue: Int(CGShieldingWindowLevel()))
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        isOpaque = true
        backgroundColor = .black
        hasShadow = false
        isReleasedWhenClosed = false
        animationBehavior = .none

        let backdrop = FrozenImageView(image: captured.image)
        backdrop.frame = CGRect(origin: .zero, size: rect.size)
        overlayView.frame = backdrop.bounds
        overlayView.autoresizingMask = [.width, .height]
        backdrop.addSubview(overlayView)
        contentView = backdrop
        setFrame(rect, display: false)
        initialFirstResponder = overlayView
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }

    /// Borderless windows must cover the menu bar area too; never let AppKit nudge them.
    override func constrainFrameRect(_ frameRect: NSRect, to screen: NSScreen?) -> NSRect { frameRect }
}

/// Shows the frozen screenshot as layer contents.
@MainActor
private final class FrozenImageView: NSView {
    private let image: CGImage

    init(image: CGImage) {
        self.image = image
        super.init(frame: .zero)
        wantsLayer = true
        layerContentsRedrawPolicy = .onSetNeedsDisplay
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    override var wantsUpdateLayer: Bool { true }
    override var isOpaque: Bool { true }

    override func updateLayer() {
        layer?.contents = image
        layer?.contentsGravity = .resize
    }
}
