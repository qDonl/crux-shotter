import AppKit

/// AppKit implementation of `PinPresenting`: one floating `PinWindow` per pin.
/// Closing and state changes always go through `manager`; this only maps items to windows.
@MainActor
public final class PinWindowPresenter: PinPresenting {
    public weak var manager: PinManager?
    /// Context-menu / ⌘S 「保存」: the app routes this through the same save flow as captures.
    private let onSave: (CGImage) -> Void
    /// Context-menu 「识别文字」: the app routes this through the same OCR flow as captures.
    private let onOCR: (CGImage) -> Void

    private var controllers: [PinItem.ID: PinWindowController] = [:]
    private var isHidden = false

    public init(onSave: @escaping (CGImage) -> Void, onOCR: @escaping (CGImage) -> Void) {
        self.onSave = onSave
        self.onOCR = onOCR
    }

    // MARK: PinPresenting

    public func show(_ item: PinItem) {
        let controller = controllers[item.id] ?? PinWindowController(item: item, presenter: self)
        controllers[item.id] = controller
        controller.apply(item)
        if !isHidden { controller.window.orderFrontRegardless() }
    }

    public func update(_ item: PinItem) {
        controllers[item.id]?.apply(item)
    }

    public func close(id: PinItem.ID) {
        controllers.removeValue(forKey: id)?.teardown()
    }

    public func setHidden(_ hidden: Bool) {
        isHidden = hidden
        for controller in controllers.values {
            if hidden { controller.window.orderOut(nil) } else { controller.window.orderFrontRegardless() }
        }
    }

    /// Orders the pin's window to the front without activating the app.
    public func bringToFront(id: PinItem.ID) {
        guard !isHidden else { return }
        controllers[id]?.window.orderFrontRegardless()
    }

    // MARK: Actions from windows

    func requestClose(id: PinItem.ID) {
        if let manager, manager.items.contains(where: { $0.id == id }) {
            manager.close(id: id)
        } else {
            close(id: id)
        }
    }

    func copy(_ image: CGImage) {
        ClipboardWriter.write(image: image)
        Toast.show("已复制")
    }

    func save(_ image: CGImage) { onSave(image) }

    func ocr(_ image: CGImage) { onOCR(image) }
}
