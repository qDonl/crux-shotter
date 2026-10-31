import AppKit

enum ToolbarCommand {
    case action(OverlayAction)
    case select
    case toggleTool(CanvasTool)
    case color(PaletteColor)
    case lineWidth(LineWidth)
    case mosaicMode(MosaicMode)
    case arrowStyle(ArrowStyle)
    case done, discard
}

/// Separate drawing rack and output bar, shared by capture and pin editing.
@MainActor
final class ToolbarView: ToolbarSurface {
    static let buttonSide: CGFloat = 32
    enum Variant { case overlay, pinEdit }

    let toolRack = ToolbarSurface()
    var onCommand: ((ToolbarCommand) -> Void)?
    private var toolButtons: [CanvasTool: ToolbarButton] = [:]
    private var colorButtons: [PaletteColor: ToolbarButton] = [:]
    private var widthButtons: [LineWidth: ToolbarButton] = [:]
    private var mosaicButtons: [MosaicMode: ToolbarButton] = [:]
    private var selectButton: ToolbarButton!
    private var arrowStyleButton: ToolbarButton!
    let arrowStyleMenu = NSMenu()
    private var undoButton: ToolbarButton!
    private var redoButton: ToolbarButton!
    private let properties = NSStackView()
    private let styles = NSStackView()
    private let mosaic = NSStackView()
    private let toolLabel = NSTextField(labelWithString: "选择")

    init(variant: Variant = .overlay) {
        super.init(frame: .zero)
        setAccessibilityLabel("输出与样式")
        toolRack.setAccessibilityLabel("绘图工具")
        selectButton = ToolbarButton(symbol: "cursorarrow", tooltip: "选择 / 移动标注 (V)") { [weak self] in
            self?.onCommand?(.select)
        }
        var tools: [NSView] = [selectButton, Self.separator(horizontal: true)]
        for (tool, symbol, title) in [
            (CanvasTool.rect, "square", "矩形 (R)"), (.arrow, "arrow.up.right", "箭头 (A)"),
            (.pen, "pencil.tip", "画笔 (P)"), (.text, "textformat", "文字 (T)"),
            (.counter, "1.circle", "序号 (N)"), (.mosaic, "checkerboard.rectangle", "马赛克 (M)"),
        ] {
            let b = ToolbarButton(symbol: symbol, tooltip: title) { [weak self] in self?.onCommand?(.toggleTool(tool)) }
            toolButtons[tool] = b
            tools.append(b)
        }
        Self.install(NSStackView(views: tools), in: toolRack, orientation: .vertical)

        undoButton = button("arrow.uturn.backward", "撤销 (⌘Z)", .undo)
        redoButton = button("arrow.uturn.forward", "重做 (⇧⌘Z)", .redo)
        var actions: [NSView] = [undoButton, redoButton, Self.separator(),
                                 button("text.viewfinder", "识别文字 (⇧⌘C)", .ocr)]
        if variant == .overlay { actions.append(button("pin", "贴图 (⌘T)", .pin)) }
        actions.append(button("square.and.arrow.down", "保存 (⌘S)", .save))
        if variant == .overlay {
            actions.append(ToolbarButton(title: "复制 ↩", primary: true) { [weak self] in self?.onCommand?(.action(.copy)) })
        } else {
            actions.append(button("doc.on.doc", "复制 (⌘C)", .copy))
            actions.append(ToolbarButton(symbol: "xmark", tooltip: "取消本次修改 (Esc)") { [weak self] in
                self?.onCommand?(.discard)
            })
            actions.append(ToolbarButton(title: "完成 ↩", primary: true) { [weak self] in self?.onCommand?(.done) })
        }
        arrowStyleButton = ToolbarButton(image: Self.arrowPreview(.classic), tooltip: "箭头样式：经典实心") { [weak self] in
            guard let self else { return }
            arrowStyleMenu.popUp(positioning: arrowStyleMenu.items.first { $0.state == .on },
                                 at: NSPoint(x: 0, y: arrowStyleButton.bounds.maxY), in: arrowStyleButton)
        }
        arrowStyleMenu.autoenablesItems = false
        for style in ArrowStyle.allCases {
            let item = NSMenuItem(title: style.title, action: #selector(selectArrowStyle(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = style.rawValue
            item.image = Self.arrowPreview(style)
            arrowStyleMenu.addItem(item)
        }
        styles.addArrangedSubview(arrowStyleButton)
        for color in PaletteColor.allCases {
            let b = ToolbarButton(image: Self.swatch(color), tooltip: Self.colorName(color)) { [weak self] in
                self?.onCommand?(.color(color))
            }
            colorButtons[color] = b
            styles.addArrangedSubview(b)
        }
        styles.addArrangedSubview(Self.separator())
        for width in LineWidth.allCases {
            let b = ToolbarButton(title: "\(Int(width.rawValue))") { [weak self] in self?.onCommand?(.lineWidth(width)) }
            b.toolTip = "线宽 \(Int(width.rawValue))pt"
            b.setAccessibilityLabel(b.toolTip)
            widthButtons[width] = b
            styles.addArrangedSubview(b)
        }
        for (mode, title) in [(MosaicMode.pixelate, "像素化"), (.blur, "模糊")] {
            let b = ToolbarButton(title: title) { [weak self] in self?.onCommand?(.mosaicMode(mode)) }
            mosaicButtons[mode] = b
            mosaic.addArrangedSubview(b)
        }
        for row in [styles, mosaic] { row.orientation = .horizontal; row.spacing = 2 }
        // Reserve one property row so changing tools never moves the output actions.
        properties.orientation = .horizontal
        properties.alignment = .centerY
        properties.addArrangedSubview(toolLabel)
        properties.addArrangedSubview(styles)
        properties.addArrangedSubview(mosaic)
        toolLabel.font = .systemFont(ofSize: 11)
        toolLabel.textColor = .secondaryLabelColor
        toolLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
        let actionRow = NSStackView(views: actions)
        actionRow.orientation = .horizontal
        actionRow.spacing = 2
        let stack = NSStackView(views: [actionRow, properties])
        Self.install(stack, in: self, orientation: .vertical)
        properties.heightAnchor.constraint(equalToConstant: Self.buttonSide).isActive = true
        properties.widthAnchor.constraint(greaterThanOrEqualToConstant: styles.fittingSize.width).isActive = true
        styles.isHidden = true
        mosaic.isHidden = true
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    func update(tool: CanvasTool?, color: PaletteColor, lineWidth: LineWidth, mosaicMode: MosaicMode,
                canUndo: Bool, canRedo: Bool, arrowStyle: ArrowStyle = .classic, selectedArrowStyle: ArrowStyle? = nil) {
        selectButton.isActive = tool == nil
        for (t, b) in toolButtons { b.isActive = t == tool }
        for (c, b) in colorButtons { b.isActive = c == color }
        for (w, b) in widthButtons { b.isActive = w == lineWidth }
        for (m, b) in mosaicButtons { b.isActive = m == mosaicMode }
        undoButton.isEnabled = canUndo
        redoButton.isEnabled = canRedo
        let displaysArrow = tool == .arrow || selectedArrowStyle != nil
        let currentArrow = selectedArrowStyle ?? arrowStyle
        arrowStyleButton.isHidden = !displaysArrow
        arrowStyleButton.image = Self.arrowPreview(currentArrow)
        arrowStyleButton.toolTip = "箭头样式：\(currentArrow.title)"
        arrowStyleButton.setAccessibilityLabel(arrowStyleButton.toolTip)
        for item in arrowStyleMenu.items { item.state = item.representedObject as? String == currentArrow.rawValue ? .on : .off }
        styles.isHidden = (tool == nil && !displaysArrow) || tool == .mosaic
        mosaic.isHidden = tool != .mosaic
        toolLabel.isHidden = tool != nil || displaysArrow
        toolLabel.stringValue = "选择模式 · V 选择 · R 矩形 · Esc 退出"
        layoutSubtreeIfNeeded()
    }

    @objc private func selectArrowStyle(_ sender: NSMenuItem) {
        guard let value = sender.representedObject as? String, let style = ArrowStyle(rawValue: value) else { return }
        onCommand?(.arrowStyle(style))
    }

    private static func arrowPreview(_ style: ArrowStyle) -> NSImage {
        NSImage(size: CGSize(width: 32, height: 20), flipped: true) { _ in
            guard let context = NSGraphicsContext.current?.cgContext else { return false }
            NSColor.labelColor.setStroke()
            NSColor.labelColor.setFill()
            ArrowGeometry(from: CGPoint(x: 3, y: 14), to: CGPoint(x: 29, y: 6),
                          style: style, lineWidth: 2).draw(in: context)
            return true
        }
    }

    private func button(_ symbol: String, _ tip: String, _ action: OverlayAction) -> ToolbarButton {
        ToolbarButton(symbol: symbol, tooltip: tip) { [weak self] in self?.onCommand?(.action(action)) }
    }

    private static func install(_ stack: NSStackView, in view: NSView, orientation: NSUserInterfaceLayoutOrientation) {
        stack.orientation = orientation
        stack.alignment = orientation == .vertical ? .centerX : .centerY
        stack.spacing = 4
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 6),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -6),
            stack.topAnchor.constraint(equalTo: view.topAnchor, constant: 6),
            stack.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -6),
        ])
    }

    private static func separator(horizontal: Bool = false) -> NSView {
        let view = NSBox()
        view.boxType = .separator
        view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            view.widthAnchor.constraint(equalToConstant: horizontal ? 20 : 1),
            view.heightAnchor.constraint(equalToConstant: horizontal ? 1 : 18),
        ])
        return view
    }

    private static func colorName(_ color: PaletteColor) -> String {
        switch color {
        case .red: "红色"
        case .yellow: "黄色"
        case .green: "绿色"
        case .blue: "蓝色"
        case .orange: "橙色"
        case .black: "黑色"
        }
    }

    private static func swatch(_ color: PaletteColor) -> NSImage {
        NSImage(size: CGSize(width: 16, height: 16), flipped: false) { rect in
            let circle = NSBezierPath(ovalIn: rect.insetBy(dx: 2, dy: 2))
            (NSColor(cgColor: color.cgColor) ?? .red).setFill()
            circle.fill()
            NSColor.secondaryLabelColor.setStroke()
            circle.lineWidth = 1
            circle.stroke()
            return true
        }
    }
}

/// A quiet, opaque surface keeps controls readable over any screenshot.
@MainActor
class ToolbarSurface: NSView {
    override init(frame: NSRect) {
        super.init(frame: frame)
        appearance = NSAppearance(named: .darkAqua)
        wantsLayer = true
        layer?.cornerRadius = 8
        layer?.masksToBounds = true
    }

    convenience init() { self.init(frame: .zero) }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    override func draw(_ dirtyRect: NSRect) {
        NSColor.windowBackgroundColor.setFill()
        NSBezierPath(roundedRect: bounds, xRadius: 8, yRadius: 8).fill()
        NSColor.separatorColor.setStroke()
        NSBezierPath(roundedRect: bounds.insetBy(dx: 0.5, dy: 0.5), xRadius: 8, yRadius: 8).stroke()
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}

/// Borderless button; drawing controls never take focus away from the text/canvas responder.
@MainActor
final class ToolbarButton: NSButton {
    private let handler: () -> Void
    private let primary: Bool
    private var hovered = false
    var isActive = false {
        didSet { state = isActive ? .on : .off; needsDisplay = true }
    }
    override var isEnabled: Bool { didSet { alphaValue = isEnabled ? 1 : 0.35; needsDisplay = true } }

    convenience init(symbol: String, tooltip: String, handler: @escaping () -> Void) {
        self.init(image: NSImage(systemSymbolName: symbol, accessibilityDescription: tooltip),
                  tooltip: tooltip, handler: handler)
    }

    init(image: NSImage?, tooltip: String, handler: @escaping () -> Void) {
        self.handler = handler
        primary = false
        super.init(frame: .zero)
        title = ""
        self.image = image
        imagePosition = .imageOnly
        configure(width: ToolbarView.buttonSide, tooltip: tooltip)
    }

    init(title: String, primary: Bool = false, handler: @escaping () -> Void) {
        self.handler = handler
        self.primary = primary
        super.init(frame: .zero)
        self.title = title
        font = .systemFont(ofSize: 12, weight: primary ? .medium : .regular)
        imagePosition = .noImage
        configure(width: max(ToolbarView.buttonSide, ceil((title as NSString).size(withAttributes: [.font: font!]).width) + 20),
                  tooltip: title)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    private func configure(width: CGFloat, tooltip: String) {
        toolTip = tooltip
        setAccessibilityLabel(tooltip)
        isBordered = false
        setButtonType(.momentaryChange)
        bezelStyle = .regularSquare
        contentTintColor = primary ? .white : .labelColor
        refusesFirstResponder = true
        target = self
        action = #selector(fire)
        translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            widthAnchor.constraint(equalToConstant: width),
            heightAnchor.constraint(equalToConstant: ToolbarView.buttonSide),
        ])
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        for area in trackingAreas { removeTrackingArea(area) }
        addTrackingArea(NSTrackingArea(rect: .zero, options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
                                       owner: self, userInfo: nil))
    }
    override func mouseEntered(with event: NSEvent) { hovered = true; needsDisplay = true }
    override func mouseExited(with event: NSEvent) { hovered = false; needsDisplay = true }
    override func highlight(_ flag: Bool) { super.highlight(flag); needsDisplay = true }
    override func draw(_ dirtyRect: NSRect) {
        let color: NSColor = primary ? .controlAccentColor : isActive ? .selectedContentBackgroundColor
            : isHighlighted ? .quaternaryLabelColor : hovered && isEnabled ? .quinaryLabel : .clear
        color.setFill()
        NSBezierPath(roundedRect: bounds.insetBy(dx: 1, dy: 1), xRadius: 5, yRadius: 5).fill()
        super.draw(dirtyRect)
    }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
    @objc private func fire() { handler() }
}
