import AppKit

@MainActor
protocol PinViewDelegate: AnyObject {
    /// `anchor` is the cursor in AppKit global coordinates.
    func pinView(zoomBy factor: CGFloat, anchor: CGPoint)
    func pinView(adjustOpacityBy delta: CGFloat)
    func pinViewDoubleClicked()
    func pinViewMenu() -> NSMenu?
    /// true if handled.
    func pinView(keyDown event: NSEvent) -> Bool
}

/// Draws the pin image (with annotations baked in) rotated/flipped and scaled to the bounds,
/// a hover outline and a transient zoom percentage label. Forwards input to the delegate.
@MainActor
final class PinView: NSView {
    static let zoomLabelDuration: Double = 1

    weak var delegate: PinViewDelegate?
    /// Upright image including annotations; orientation is applied when drawing.
    var image: CGImage { didSet { needsDisplay = true } }
    var imagePointSize: CGSize { didSet { needsDisplay = true } }
    var transform = PinTransform() { didSet { if transform != oldValue { needsDisplay = true } } }

    private var isHovered = false { didSet { if isHovered != oldValue { needsDisplay = true } } }
    private let zoomLabel = NSTextField(labelWithString: "")
    private var zoomLabelGeneration = 0

    init(image: CGImage, pointSize: CGSize) {
        self.image = image
        imagePointSize = pointSize
        super.init(frame: CGRect(origin: .zero, size: pointSize))
        zoomLabel.font = .monospacedDigitSystemFont(ofSize: 11, weight: .medium)
        zoomLabel.textColor = .white
        zoomLabel.alignment = .center
        zoomLabel.wantsLayer = true
        zoomLabel.layer?.backgroundColor = NSColor(white: 0, alpha: 0.6).cgColor
        zoomLabel.layer?.cornerRadius = 4
        zoomLabel.isHidden = true
        zoomLabel.autoresizingMask = [.minXMargin, .maxYMargin]
        addSubview(zoomLabel)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    override var acceptsFirstResponder: Bool { true }
    override var mouseDownCanMoveWindow: Bool { false }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    // MARK: Drawing

    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        let oriented = PinGeometry.orientedSize(transform, size: imagePointSize)
        if oriented.width > 0, oriented.height > 0 {
            ctx.saveGState()
            ctx.interpolationQuality = .high
            ctx.scaleBy(x: bounds.width / oriented.width, y: bounds.height / oriented.height)
            ctx.concatenate(PinGeometry.orientation(transform, size: imagePointSize))
            ctx.draw(image, in: CGRect(origin: .zero, size: imagePointSize))
            ctx.restoreGState()
        }
        if isHovered {
            NSColor.controlAccentColor.withAlphaComponent(0.6).setStroke()
            let path = NSBezierPath(rect: bounds.insetBy(dx: 0.5, dy: 0.5))
            path.lineWidth = 1
            path.stroke()
        }
    }

    /// Shows e.g. "150%" in the bottom-right corner for `zoomLabelDuration` seconds.
    func showZoom(percent: Int) {
        zoomLabel.stringValue = "\(percent)%"
        let size = zoomLabel.fittingSize
        let w = size.width + 10, h = size.height + 4
        zoomLabel.frame = CGRect(x: bounds.maxX - w - 6, y: bounds.minY + 6, width: w, height: h)
        zoomLabel.isHidden = false
        addSubview(zoomLabel) // keep above an editing canvas
        zoomLabelGeneration += 1
        let g = zoomLabelGeneration
        Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(Self.zoomLabelDuration))
            guard let self, self.zoomLabelGeneration == g else { return }
            self.zoomLabel.isHidden = true
        }
    }

    // MARK: Hover

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        for area in trackingAreas { removeTrackingArea(area) }
        addTrackingArea(NSTrackingArea(rect: .zero, options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
                                       owner: self, userInfo: nil))
    }

    override func mouseEntered(with event: NSEvent) { isHovered = true }
    override func mouseExited(with event: NSEvent) { isHovered = false }

    // MARK: Input

    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
        if event.clickCount == 2 {
            delegate?.pinViewDoubleClicked()
        } else {
            window?.performDrag(with: event)
        }
    }

    override func scrollWheel(with event: NSEvent) {
        let dy = event.deltaY
        guard dy != 0, event.momentumPhase.isEmpty else { return }
        if event.modifierFlags.contains(.option) {
            delegate?.pinView(adjustOpacityBy: dy * 0.01)
        } else {
            // Mouse wheels report whole notches; trackpads report small precise deltas.
            let factor = event.hasPreciseScrollingDeltas ? 1 + dy * 0.01 : pow(1.1, dy)
            delegate?.pinView(zoomBy: factor, anchor: NSEvent.mouseLocation)
        }
    }

    override func magnify(with event: NSEvent) {
        delegate?.pinView(zoomBy: 1 + event.magnification, anchor: NSEvent.mouseLocation)
    }

    override func menu(for event: NSEvent) -> NSMenu? { delegate?.pinViewMenu() }

    override func keyDown(with event: NSEvent) {
        if delegate?.pinView(keyDown: event) != true { super.keyDown(with: event) }
    }
}
