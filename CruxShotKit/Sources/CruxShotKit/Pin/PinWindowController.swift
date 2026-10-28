import AppKit

/// Maps one `PinItem` onto a `PinWindow`. Every user change builds a new item and goes through
/// `PinManager.update` (which calls back into `apply`), so the manager's copy stays current.
@MainActor
final class PinWindowController: NSObject, NSWindowDelegate, PinViewDelegate {
    private(set) var item: PinItem
    let window: PinWindow
    private let view: PinView
    private unowned let presenter: PinWindowPresenter
    private var editor: PinEditor?
    /// Orientation to restore after editing (editing happens upright).
    private var savedOrientation: PinTransform?

    private var pointSize: CGSize { PinGeometry.pointSize(of: item.image, scale: item.imageScale) }

    init(item: PinItem, presenter: PinWindowPresenter) {
        self.item = item
        self.presenter = presenter
        window = PinWindow(frame: item.frame)
        view = PinView(image: item.annotatedImage(),
                       pointSize: PinGeometry.pointSize(of: item.image, scale: item.imageScale))
        super.init()
        view.autoresizingMask = [.width, .height]
        view.transform = item.transform
        window.contentView = view
        window.delegate = self
        view.delegate = self
        window.alphaValue = item.transform.opacity
        window.ignoresMouseEvents = item.clickThrough
        window.setFollowsSpaces(item.followsSpaces)
    }

    // MARK: Mapping

    /// Idempotent: only touches what differs from the window's current state.
    func apply(_ new: PinItem) {
        let annotationsChanged = new.annotations != item.annotations
        item = new
        if window.frame != new.frame { window.setFrame(new.frame, display: true) }
        if window.alphaValue != new.transform.opacity { window.alphaValue = new.transform.opacity }
        if window.ignoresMouseEvents != new.clickThrough { window.ignoresMouseEvents = new.clickThrough }
        window.setFollowsSpaces(new.followsSpaces)
        if annotationsChanged { view.image = new.annotatedImage() }
        view.transform = new.transform
        editor?.layout()
    }

    private func commit(_ new: PinItem) {
        if let manager = presenter.manager, manager.items.contains(where: { $0.id == new.id }) {
            manager.update(new)
        } else {
            apply(new)
        }
    }

    func teardown() {
        if let editor { _ = editor.finish() }
        editor = nil
        window.delegate = nil
        view.delegate = nil
        window.orderOut(nil)
        window.close()
    }

    // MARK: Transform changes

    private func zoom(by factor: CGFloat, anchor: CGPoint) {
        var n = item
        n.transform.zoom(by: factor)
        guard n.transform.scale != item.transform.scale else { return }
        n.frame = PinGeometry.zoomedFrame(window.frame, to: n.transform.displaySize(for: pointSize), anchor: anchor)
        commit(n)
        view.showZoom(percent: Int((n.transform.scale * 100).rounded()))
    }

    /// Applies an orientation/scale change, resizing around the window centre.
    private func reshape(_ change: (inout PinTransform) -> Void) {
        var n = item
        change(&n.transform)
        let f = window.frame
        n.frame = PinGeometry.zoomedFrame(f, to: n.transform.displaySize(for: pointSize),
                                          anchor: CGPoint(x: f.midX, y: f.midY))
        commit(n)
    }

    func perform(_ action: PinAction) {
        switch action {
        case .close: presenter.requestClose(id: item.id)
        case .resetScale:
            reshape { $0.resetScale() }
            view.showZoom(percent: 100)
        case .rotateCW: reshape { $0.rotateCW() }
        case .rotateCCW: reshape { $0.rotateCCW() }
        case .flipH: reshape { $0.flippedH.toggle() }
        case .flipV: reshape { $0.flippedV.toggle() }
        case .edit: beginEditing()
        case .toggleClickThrough:
            var n = item
            n.clickThrough.toggle()
            commit(n)
        case .copy: presenter.copy(item.composedImage())
        case .save: presenter.save(item.composedImage())
        }
    }

    private func toggleFollowsSpaces() {
        var n = item
        n.followsSpaces.toggle()
        commit(n)
    }

    // MARK: Editing

    private func beginEditing() {
        guard editor == nil else { return }
        if PinGeometry.hasOrientation(item.transform) {
            savedOrientation = item.transform
            reshape { $0.quarterTurns = 0; $0.flippedH = false; $0.flippedV = false }
        }
        window.isMovableByWindowBackground = false
        view.image = item.image // annotations are drawn by the canvas while editing
        let e = PinEditor(item: item, host: view)
        e.onDone = { [weak self] in self?.endEditing() }
        editor = e
    }

    private func endEditing() {
        guard let e = editor else { return }
        editor = nil
        let annotations = e.finish()
        window.isMovableByWindowBackground = true
        var n = item
        n.annotations = annotations
        view.image = n.annotatedImage()
        if let saved = savedOrientation {
            savedOrientation = nil
            n.transform.quarterTurns = saved.quarterTurns
            n.transform.flippedH = saved.flippedH
            n.transform.flippedV = saved.flippedV
            let f = window.frame
            n.frame = PinGeometry.zoomedFrame(f, to: n.transform.displaySize(for: pointSize),
                                              anchor: CGPoint(x: f.midX, y: f.midY))
        }
        commit(n)
    }

    // MARK: NSWindowDelegate

    func windowDidMove(_ notification: Notification) {
        guard window.frame != item.frame else { return }
        var n = item
        n.frame = window.frame
        commit(n)
    }

    // MARK: PinViewDelegate

    func pinView(zoomBy factor: CGFloat, anchor: CGPoint) { zoom(by: factor, anchor: anchor) }

    func pinView(adjustOpacityBy delta: CGFloat) {
        var n = item
        n.transform.adjustOpacity(by: delta)
        guard n.transform.opacity != item.transform.opacity else { return }
        commit(n)
    }

    func pinViewDoubleClicked() {
        guard editor == nil else { return }
        presenter.requestClose(id: item.id)
    }

    func pinViewMenu() -> NSMenu? {
        guard editor == nil else { return nil }
        let menu = NSMenu()
        menu.autoenablesItems = false
        menu.addItem(PinMenuAction.item("复制") { [weak self] in self?.perform(.copy) })
        menu.addItem(PinMenuAction.item("保存") { [weak self] in self?.perform(.save) })
        menu.addItem(PinMenuAction.item("识别文字") { [weak self] in
            guard let self else { return }
            self.presenter.ocr(self.item.composedImage())
        })
        menu.addItem(.separator())
        menu.addItem(PinMenuAction.item("点击穿透", checked: item.clickThrough) { [weak self] in
            self?.perform(.toggleClickThrough)
        })
        menu.addItem(PinMenuAction.item("跟随切换桌面", checked: item.followsSpaces) { [weak self] in
            self?.toggleFollowsSpaces()
        })
        menu.addItem(.separator())
        menu.addItem(PinMenuAction.item("关闭") { [weak self] in self?.perform(.close) })
        return menu
    }

    func pinView(keyDown event: NSEvent) -> Bool {
        if let editor { return editor.handleKey(event) }
        guard let action = PinKeyMap.action(characters: event.charactersIgnoringModifiers,
                                            keyCode: event.keyCode, modifiers: event.modifierFlags)
        else { return false }
        perform(action)
        return true
    }
}
