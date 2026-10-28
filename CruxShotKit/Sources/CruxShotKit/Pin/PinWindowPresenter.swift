import AppKit

/// AppKit implementation of `PinPresenting`: one floating `PinWindow` per pin.
/// Closing and state changes always go through `manager`; this only maps items to windows.
@MainActor
public final class PinWindowPresenter: PinPresenting {
    public weak var manager: PinManager?
    /// Overrides the built-in OCR (copy recognised text + toast) when set.
    public var onOCR: ((CGImage) -> Void)?
    /// Overrides the built-in save (`ImageSaver` with `Preferences.shared` + toast) when set.
    public var onSave: ((CGImage) -> Void)?

    private var controllers: [PinItem.ID: PinWindowController] = [:]
    private var isHidden = false

    public init() {}

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

    func save(_ image: CGImage) {
        if let onSave { return onSave(image) }
        let prefs = Preferences.shared
        let name = FileNameTemplate(pattern: prefs.fileNameTemplate).fileName(for: Date())
        do {
            let result = try ImageSaver().save(image, directory: prefs.saveDirectory, fileName: name,
                                               format: prefs.imageFormat, fallbackDirectory: Preferences.fallbackDirectory)
            let url = result.url
            Toast.show(result.usedFallback ? "已保存到备用目录" : "已保存", detail: url.path(percentEncoded: false),
                       action: ("在 Finder 中显示", { NSWorkspace.shared.activateFileViewerSelecting([url]) }))
        } catch {
            Toast.show("保存失败", detail: error.localizedDescription)
        }
    }

    func ocr(_ image: CGImage) {
        if let onOCR { return onOCR(image) }
        Task { @MainActor in
            do {
                let lines = try await TextRecognizer.recognize(image)
                guard !lines.isEmpty else { return Toast.show("未识别到文字") }
                ClipboardWriter.write(text: lines.joinedAsLines)
                Toast.show("已复制识别的文字", detail: lines.joinedAsSingleLine)
            } catch {
                Toast.show("识别失败", detail: error.localizedDescription)
            }
        }
    }
}
