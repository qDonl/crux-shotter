import AppKit

enum ToolbarCommand {
    case action(OverlayAction)
    case select
    case toggleTool(CanvasTool)
    case color(PaletteColor)
    case lineWidth(LineWidth)
    case mosaicMode(MosaicMode)
    case arrowStyle(ArrowStyle)
    case counterStyle(CounterStyle)
    case done, discard
}

/// Separate drawing rack and output bar, shared by capture and pin editing.
@MainActor
final class ToolbarView: ToolbarSurface {
    static let buttonSide: CGFloat = 32
    enum Variant { case overlay, pinEdit }

    let toolRack = ToolbarSurface()
    let propertyBar = ToolbarSurface()
    var onCommand: ((ToolbarCommand) -> Void)?
    private var toolButtons: [CanvasTool: ToolbarButton] = [:]
    private var mosaicButtons: [MosaicMode: ToolbarButton] = [:]
    private var selectButton: ToolbarButton!
    private var arrowStyleButton: ToolbarButton!
    private var counterStyleButton: ToolbarButton!
    private var swatchButton: ToolbarButton!
    let arrowStylePopover = NSPopover()
    let counterStylePopover = NSPopover()
    let colorPopover = NSPopover()
    private(set) var arrowStyleChoices: [ArrowStyle: ToolbarButton] = [:]
    private(set) var counterStyleChoices: [CounterStyle: ToolbarButton] = [:]
    private(set) var colorChoices: [PaletteColor: ToolbarButton] = [:]
    private var undoButton: ToolbarButton!
    private var redoButton: ToolbarButton!
    private let styles = NSStackView()
    private let mosaic = NSStackView()

    init(variant: Variant = .overlay) {
        super.init(frame: .zero)
        setAccessibilityLabel("输出与样式")
        toolRack.setAccessibilityLabel("绘图工具")
        propertyBar.setAccessibilityLabel("当前工具属性")
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
            actions.append(ToolbarButton(symbol: "doc.on.doc", tooltip: "复制截图 (Enter)", primary: true) { [weak self] in
                self?.onCommand?(.action(.copy))
            })
        } else {
            actions.append(button("doc.on.doc", "复制 (⌘C)", .copy))
            actions.append(ToolbarButton(symbol: "xmark", tooltip: "取消本次修改 (Esc)") { [weak self] in
                self?.onCommand?(.discard)
            })
            actions.append(ToolbarButton(symbol: "checkmark", tooltip: "完成编辑 (Enter)", primary: true) { [weak self] in
                self?.onCommand?(.done)
            })
        }
        arrowStyleButton = ToolbarButton(image: Self.arrowPreview(.classic), tooltip: "箭头样式：经典实心") { [weak self] in
            guard let self else { return }
            arrowStylePopover.show(relativeTo: arrowStyleButton.bounds, of: arrowStyleButton, preferredEdge: .maxY)
        }
        for style in ArrowStyle.allCases {
            let choice = ToolbarButton(image: Self.arrowPreview(style), tooltip: style.title, width: 54) { [weak self] in
                self?.arrowStylePopover.performClose(nil)
                self?.onCommand?(.arrowStyle(style))
            }
            arrowStyleChoices[style] = choice
        }
        arrowStylePopover.behavior = .transient
        arrowStylePopover.animates = false
        arrowStylePopover.contentViewController = Self.picker(ArrowStyle.allCases.compactMap { arrowStyleChoices[$0] }, columns: 2)
        counterStyleButton = ToolbarButton(image: Self.counterPreview(.preciseRing), tooltip: "序号样式：精密圆环") { [weak self] in
            guard let self else { return }
            counterStylePopover.show(relativeTo: counterStyleButton.bounds, of: counterStyleButton, preferredEdge: .maxY)
        }
        for style in CounterStyle.allCases {
            let choice = ToolbarButton(image: Self.counterPreview(style), tooltip: style.title, width: 44) { [weak self] in
                self?.counterStylePopover.performClose(nil)
                self?.onCommand?(.counterStyle(style))
            }
            counterStyleChoices[style] = choice
        }
        counterStylePopover.behavior = .transient
        counterStylePopover.animates = false
        counterStylePopover.contentViewController = Self.picker(CounterStyle.allCases.compactMap { counterStyleChoices[$0] }, columns: 3)
        swatchButton = ToolbarButton(image: Self.swatch(.red), tooltip: "颜色：红色") { [weak self] in
            guard let self else { return }
            colorPopover.show(relativeTo: swatchButton.bounds, of: swatchButton, preferredEdge: .maxY)
        }
        for color in PaletteColor.allCases {
            let choice = ToolbarButton(image: Self.swatch(color), tooltip: Self.colorName(color)) { [weak self] in
                self?.colorPopover.performClose(nil)
                self?.onCommand?(.color(color))
            }
            colorChoices[color] = choice
        }
        colorPopover.behavior = .transient
        colorPopover.animates = false
        colorPopover.contentViewController = Self.picker(PaletteColor.allCases.compactMap { colorChoices[$0] }, columns: 3)
        styles.addArrangedSubview(swatchButton)
        styles.addArrangedSubview(arrowStyleButton)
        styles.addArrangedSubview(counterStyleButton)
        for (mode, symbol, title) in [(MosaicMode.pixelate, "square.grid.3x3.fill", "像素化"),
                                      (.blur, "circle.dotted", "模糊")] {
            let b = ToolbarButton(symbol: symbol, tooltip: title) { [weak self] in self?.onCommand?(.mosaicMode(mode)) }
            mosaicButtons[mode] = b
            mosaic.addArrangedSubview(b)
        }
        for row in [styles, mosaic] { row.orientation = .horizontal; row.spacing = 2 }
        let properties = NSStackView(views: [styles, mosaic])
        properties.orientation = .horizontal
        properties.alignment = .centerY
        Self.install(properties, in: propertyBar, orientation: .horizontal)
        let actionRow = NSStackView(views: actions)
        actionRow.orientation = .horizontal
        actionRow.spacing = 2
        Self.install(actionRow, in: self, orientation: .horizontal)
        mosaic.isHidden = true
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    func update(tool: CanvasTool?, color: PaletteColor, lineWidth: LineWidth, mosaicMode: MosaicMode,
                canUndo: Bool, canRedo: Bool, arrowStyle: ArrowStyle = .classic,
                selectedArrowStyle: ArrowStyle? = nil, counterStyle: CounterStyle = .preciseRing,
                selectedCounterStyle: CounterStyle? = nil, hasSelection: Bool = false) {
        selectButton.isActive = tool == nil
        for (t, b) in toolButtons { b.isActive = t == tool }
        swatchButton.image = Self.swatch(color)
        swatchButton.toolTip = "颜色：\(Self.colorName(color))；线宽 \(Int(lineWidth.rawValue))pt（1/2 调整）"
        swatchButton.setAccessibilityLabel(swatchButton.toolTip)
        for (choice, button) in colorChoices { button.isActive = choice == color }
        for (m, b) in mosaicButtons { b.isActive = m == mosaicMode }
        undoButton.isEnabled = canUndo
        redoButton.isEnabled = canRedo
        let displaysArrow = selectedArrowStyle != nil || (selectedCounterStyle == nil && tool == .arrow)
        let currentArrow = selectedArrowStyle ?? arrowStyle
        arrowStyleButton.isHidden = !displaysArrow
        arrowStyleButton.image = Self.arrowPreview(currentArrow)
        arrowStyleButton.toolTip = "箭头样式：\(currentArrow.title)"
        arrowStyleButton.setAccessibilityLabel(arrowStyleButton.toolTip)
        for (choice, button) in arrowStyleChoices { button.isActive = choice == currentArrow }
        let displaysCounter = selectedCounterStyle != nil || (selectedArrowStyle == nil && tool == .counter)
        let currentCounter = selectedCounterStyle ?? counterStyle
        counterStyleButton.isHidden = !displaysCounter
        counterStyleButton.image = Self.counterPreview(currentCounter)
        counterStyleButton.toolTip = "序号样式：\(currentCounter.title)"
        counterStyleButton.setAccessibilityLabel(counterStyleButton.toolTip)
        for (choice, button) in counterStyleChoices { button.isActive = choice == currentCounter }
        let displaysMosaic = tool == .mosaic && !displaysArrow && !displaysCounter
        styles.isHidden = displaysMosaic
        mosaic.isHidden = !displaysMosaic
        propertyBar.isHidden = tool == nil && !hasSelection
        layoutSubtreeIfNeeded()
    }

    private static func picker(_ buttons: [ToolbarButton], columns: Int) -> NSViewController {
        let rows = stride(from: 0, to: buttons.count, by: columns).map { offset in
            let row = NSStackView(views: Array(buttons[offset..<min(offset + columns, buttons.count)]))
            row.orientation = .horizontal
            row.spacing = 4
            return row
        }
        let stack = NSStackView(views: rows)
        stack.orientation = .vertical
        stack.spacing = 4
        let surface = ToolbarSurface()
        install(stack, in: surface, orientation: .vertical)
        let controller = NSViewController()
        controller.view = surface
        controller.preferredContentSize = surface.fittingSize
        return controller
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

    private static func counterPreview(_ style: CounterStyle) -> NSImage {
        NSImage(size: CGSize(width: 28, height: 28), flipped: true) { _ in
            guard let context = NSGraphicsContext.current?.cgContext else { return false }
            context.saveGState()
            context.translateBy(x: 14, y: 14)
            context.scaleBy(x: 0.86, y: 0.86)
            CounterGeometry(center: .zero, number: 1, style: style).draw(color: NSColor.labelColor.cgColor, in: context)
            context.restoreGState()
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

/// Light, narrow control rails remain legible without forming a dark block over the capture.
@MainActor
class ToolbarSurface: NSView {
    override init(frame: NSRect) {
        super.init(frame: frame)
        appearance = NSAppearance(named: .aqua)
        wantsLayer = true
        layer?.cornerRadius = 3
        layer?.masksToBounds = true
    }

    convenience init() { self.init(frame: .zero) }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    override func draw(_ dirtyRect: NSRect) {
        NSColor(calibratedWhite: 0.985, alpha: 0.96).setFill()
        NSBezierPath(roundedRect: bounds, xRadius: 3, yRadius: 3).fill()
        NSColor(calibratedWhite: 0.3, alpha: 0.22).setStroke()
        NSBezierPath(roundedRect: bounds.insetBy(dx: 0.5, dy: 0.5), xRadius: 3, yRadius: 3).stroke()
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

    convenience init(symbol: String, tooltip: String, primary: Bool = false, handler: @escaping () -> Void) {
        self.init(image: NSImage(systemSymbolName: symbol, accessibilityDescription: tooltip),
                  tooltip: tooltip, primary: primary, handler: handler)
    }

    init(image: NSImage?, tooltip: String, primary: Bool = false, width: CGFloat = ToolbarView.buttonSide,
         handler: @escaping () -> Void) {
        self.handler = handler
        self.primary = primary
        super.init(frame: .zero)
        title = ""
        self.image = image
        imagePosition = .imageOnly
        configure(width: width, tooltip: tooltip)
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
        contentTintColor = primary ? .controlAccentColor : .labelColor
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
        let color: NSColor = isHighlighted ? NSColor.black.withAlphaComponent(0.10)
            : hovered && isEnabled ? NSColor.black.withAlphaComponent(0.06) : .clear
        color.setFill()
        NSBezierPath(roundedRect: bounds.insetBy(dx: 1, dy: 1), xRadius: 3, yRadius: 3).fill()
        if isActive {
            NSColor.controlAccentColor.setFill()
            NSRect(x: 7, y: 1, width: bounds.width - 14, height: 2).fill()
        }
        super.draw(dirtyRect)
    }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
    @objc private func fire() { handler() }
}
