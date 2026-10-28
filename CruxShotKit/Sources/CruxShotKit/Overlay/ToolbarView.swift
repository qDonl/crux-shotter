import AppKit

enum ToolbarCommand {
    case action(OverlayAction)
    /// Clicking the active tool deselects it (back to annotation-selection mode).
    case toggleTool(CanvasTool)
    case color(PaletteColor)
    case lineWidth(LineWidth)
    case mosaicMode(MosaicMode)
}

/// Annotation toolbar shown under the selection. Row 1: tools | undo redo | ocr pin save copy.
/// Row 2 (only while a drawing tool is active): 6 colors + 3 line widths, or pixelate/blur for mosaic.
@MainActor
final class ToolbarView: NSView {
    static let buttonSide: CGFloat = 28

    var onCommand: ((ToolbarCommand) -> Void)?

    private static let tools: [(CanvasTool, String, String)] = [
        (.rect, "square", "矩形 (R)"),
        (.arrow, "arrow.up.right", "箭头 (A)"),
        (.pen, "pencil.tip", "画笔 (P)"),
        (.text, "textformat", "文字 (T)"),
        (.counter, "1.circle", "序号 (N)"),
        (.mosaic, "checkerboard.rectangle", "马赛克 (M)"),
    ]

    private var toolButtons: [CanvasTool: ToolbarButton] = [:]
    private var colorButtons: [PaletteColor: ToolbarButton] = [:]
    private var widthButtons: [LineWidth: ToolbarButton] = [:]
    private var mosaicButtons: [MosaicMode: ToolbarButton] = [:]
    private var undoButton: ToolbarButton!
    private var redoButton: ToolbarButton!
    private let styleRow = NSStackView()
    private let mosaicRow = NSStackView()

    init() {
        super.init(frame: .zero)
        wantsLayer = true
        layer?.backgroundColor = NSColor(white: 0.12, alpha: 0.94).cgColor
        layer?.cornerRadius = 8

        var row1: [NSView] = []
        for (tool, symbol, tip) in Self.tools {
            let b = ToolbarButton(symbol: symbol, tooltip: tip) { [weak self] in self?.onCommand?(.toggleTool(tool)) }
            toolButtons[tool] = b
            row1.append(b)
        }
        row1.append(Self.separator())
        undoButton = button("arrow.uturn.backward", "撤销 (⌘Z)", .undo)
        redoButton = button("arrow.uturn.forward", "重做 (⇧⌘Z)", .redo)
        row1 += [undoButton, redoButton, Self.separator()]
        row1 += [
            button("text.viewfinder", "识别文字 (⇧⌘C)", .ocr),
            button("pin", "贴图 (⌘T)", .pin),
            button("square.and.arrow.down", "保存 (⌘S)", .save),
            button("checkmark", "复制 (↩)", .copy),
        ]

        for color in PaletteColor.allCases {
            let b = ToolbarButton(image: Self.swatch(color), tooltip: color.rawValue) { [weak self] in
                self?.onCommand?(.color(color))
            }
            colorButtons[color] = b
            styleRow.addArrangedSubview(b)
        }
        styleRow.addArrangedSubview(Self.separator())
        for width in LineWidth.allCases {
            let b = ToolbarButton(image: Self.dot(width), tooltip: "\(Int(width.rawValue))pt") { [weak self] in
                self?.onCommand?(.lineWidth(width))
            }
            widthButtons[width] = b
            styleRow.addArrangedSubview(b)
        }
        for (mode, title) in [(MosaicMode.pixelate, "像素化"), (.blur, "模糊")] {
            let b = ToolbarButton(title: title) { [weak self] in self?.onCommand?(.mosaicMode(mode)) }
            mosaicButtons[mode] = b
            mosaicRow.addArrangedSubview(b)
        }

        let firstRow = NSStackView(views: row1)
        for row in [firstRow, styleRow, mosaicRow] {
            row.orientation = .horizontal
            row.spacing = 2
        }
        let stack = NSStackView(views: [firstRow, styleRow, mosaicRow])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 4
        stack.edgeInsets = NSEdgeInsets(top: 4, left: 4, bottom: 4, right: 4)
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor),
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
        styleRow.isHidden = true
        mosaicRow.isHidden = true
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    func update(tool: CanvasTool?, color: PaletteColor, lineWidth: LineWidth, mosaicMode: MosaicMode,
                canUndo: Bool, canRedo: Bool) {
        for (t, b) in toolButtons { b.isActive = t == tool }
        for (c, b) in colorButtons { b.isActive = c == color }
        for (w, b) in widthButtons { b.isActive = w == lineWidth }
        for (m, b) in mosaicButtons { b.isActive = m == mosaicMode }
        undoButton.isEnabled = canUndo
        redoButton.isEnabled = canRedo
        styleRow.isHidden = tool == nil || tool == .mosaic
        mosaicRow.isHidden = tool != .mosaic
        layoutSubtreeIfNeeded()
    }

    private func button(_ symbol: String, _ tip: String, _ action: OverlayAction) -> ToolbarButton {
        ToolbarButton(symbol: symbol, tooltip: tip) { [weak self] in self?.onCommand?(.action(action)) }
    }

    private static func separator() -> NSView {
        let v = NSView()
        v.wantsLayer = true
        v.layer?.backgroundColor = NSColor(white: 1, alpha: 0.25).cgColor
        v.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            v.widthAnchor.constraint(equalToConstant: 1),
            v.heightAnchor.constraint(equalToConstant: 18),
        ])
        return v
    }

    private static func swatch(_ color: PaletteColor) -> NSImage {
        NSImage(size: CGSize(width: 16, height: 16), flipped: false) { rect in
            let circle = NSBezierPath(ovalIn: rect.insetBy(dx: 1.5, dy: 1.5))
            (NSColor(cgColor: color.cgColor) ?? .red).setFill()
            circle.fill()
            NSColor(white: 1, alpha: 0.8).setStroke()
            circle.lineWidth = 1
            circle.stroke()
            return true
        }
    }

    private static func dot(_ width: LineWidth) -> NSImage {
        let d = width.rawValue + 2
        return NSImage(size: CGSize(width: 16, height: 16), flipped: false) { rect in
            NSColor.white.setFill()
            NSBezierPath(ovalIn: CGRect(x: rect.midX - d / 2, y: rect.midY - d / 2, width: d, height: d)).fill()
            return true
        }
    }
}

/// Borderless toolbar button that never takes first responder (keys stay with the canvas/overlay).
@MainActor
final class ToolbarButton: NSButton {
    private let handler: () -> Void

    var isActive = false { didSet { updateAppearance() } }
    override var isEnabled: Bool { didSet { updateAppearance() } }

    convenience init(symbol: String, tooltip: String, handler: @escaping () -> Void) {
        let image = NSImage(systemSymbolName: symbol, accessibilityDescription: tooltip)
        self.init(image: image, tooltip: tooltip, handler: handler)
        if image == nil { setWhiteTitle(String(tooltip.prefix(1))) }
    }

    init(image: NSImage?, tooltip: String, handler: @escaping () -> Void) {
        self.handler = handler
        super.init(frame: .zero)
        title = ""
        self.image = image
        imagePosition = image == nil ? .noImage : .imageOnly
        toolTip = tooltip
        setAccessibilityLabel(tooltip)
        configure(width: ToolbarView.buttonSide)
    }

    init(title: String, handler: @escaping () -> Void) {
        self.handler = handler
        super.init(frame: .zero)
        setWhiteTitle(title)
        imagePosition = .noImage
        configure(width: 56)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    private func configure(width: CGFloat) {
        isBordered = false
        bezelStyle = .regularSquare
        imageScaling = .scaleProportionallyDown
        contentTintColor = .white
        refusesFirstResponder = true
        wantsLayer = true
        layer?.cornerRadius = 5
        target = self
        action = #selector(fire)
        translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            widthAnchor.constraint(equalToConstant: width),
            heightAnchor.constraint(equalToConstant: ToolbarView.buttonSide),
        ])
    }

    private func setWhiteTitle(_ text: String) {
        attributedTitle = NSAttributedString(string: text, attributes: [
            .foregroundColor: NSColor.white, .font: NSFont.systemFont(ofSize: 12),
        ])
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    @objc private func fire() { handler() }

    private func updateAppearance() {
        layer?.backgroundColor = isActive ? OverlayView.accent.withAlphaComponent(0.85).cgColor : nil
        alphaValue = isEnabled ? 1 : 0.35
    }
}
