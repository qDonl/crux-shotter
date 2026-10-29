import AppKit
import CruxShotKit
import OSLog

/// Runs every user-facing flow: capture → overlay → result handling, clipboard pins and the pin
/// toggles. Menu items and global shortcuts both call into here.
@MainActor
final class AppCoordinator {
    private static let logger = Logger(subsystem: "com.cruxshot", category: "Coordinator")

    private let capture: ScreenCapturing
    private let preferences: Preferences
    let pins: PinManager
    /// Called when a capture entry finds no screen recording permission.
    var showOnboarding: () -> Void = {}

    private var overlay: OverlayController?
    /// True from the moment a capture starts until its overlay (if any) has closed.
    private var isCapturing = false
    /// App that was frontmost before we activated for the overlay; focus goes back to it afterwards.
    private var previousApp: NSRunningApplication?

    init(capture: ScreenCapturing, preferences: Preferences, pins: PinManager) {
        self.capture = capture
        self.preferences = preferences
        self.pins = pins
    }

    // MARK: Capture entries

    func captureArea() {
        startOverlay(mode: .annotate) { [weak self] result in self?.handleAnnotate(result) }
    }

    func captureOCR() {
        startOverlay(mode: .ocr) { [weak self] result in
            guard let self else { return }
            switch result {
            case .ocr(let image): recognizeToClipboard(image)
            case .cancelled: break
            default: handleAnnotate(result)
            }
        }
    }

    func captureFullScreen() {
        guard beginCapture() else { return }
        Task { @MainActor in
            defer { isCapturing = false }
            guard let snapshot = await takeSnapshot() else { return }
            guard let frame = snapshot.frame(containing: NSEvent.mouseLocation) ?? snapshot.frames.first else {
                return report(CaptureError.noDisplays)
            }
            ClipboardWriter.write(image: frame.image)
            Toast.show("已复制全屏截图", detail: "\(frame.image.width) × \(frame.image.height)")
        }
    }

    // MARK: Pin entries

    func pinClipboard() {
        let mouse = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { $0.frame.contains(mouse) } ?? NSScreen.main
        let scale = screen?.backingScaleFactor ?? 2
        let dark = NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        let images: [CGImage]
        switch ClipboardContent.read(from: .general) {
        case .image(let cg):
            images = [cg]
        case .imageFiles(let urls):
            images = urls.prefix(ClipboardContent.maxImageFiles).compactMap { ImageFileLoader.load($0, scale: scale) }
            if images.isEmpty {
                Toast.show("无法读取复制的图片文件")
                return
            }
            if urls.count > ClipboardContent.maxImageFiles {
                Toast.show("一次最多贴 \(ClipboardContent.maxImageFiles) 张图片", detail: "已贴出前 \(images.count) 张")
            }
        case .color(let color):
            images = [ColorCardRenderer.render(color, dark: dark, scale: scale)]
        case .richText(let text):
            images = [TextCardRenderer.renderRich(text, scale: scale)]
        case .text(let text):
            images = [TextCardRenderer.render(text, dark: dark, scale: scale)]
        case .none:
            Toast.show("剪贴板没有可贴的内容")
            return
        }
        let visible = screen?.visibleFrame
        let scales = images.map { image in
            PinGeometry.fittingScale(pixelSize: CGSize(width: image.width, height: image.height), baseScale: scale,
                                     within: visible?.size ?? .zero)
        }
        let sizes = zip(images, scales).map { PinGeometry.pointSize(of: $0, scale: $1) }
        let frames = PinGeometry.cascadeFrames(sizes: sizes, around: mouse, visible: visible)
        for (i, image) in images.enumerated() {
            pins.add(PinItem(image: image, imageScale: scales[i], frame: frames[i]))
        }
    }

    func togglePins() {
        pins.toggleHidden()
    }

    func restorePin() {
        if !pins.restoreLast() { Toast.show("没有可恢复的贴图") }
    }

    // MARK: Shared result handlers (overlay results and pin context menu)

    func save(_ image: CGImage) {
        let name = FileNameTemplate(pattern: preferences.fileNameTemplate).fileName(for: .now)
        do {
            let result = try ImageSaver().save(image, directory: preferences.saveDirectory, fileName: name,
                                               format: preferences.imageFormat,
                                               fallbackDirectory: Preferences.fallbackDirectory)
            let url = result.url
            let reveal = (title: "在访达中显示", handler: { NSWorkspace.shared.activateFileViewerSelecting([url]) })
            if result.usedFallback {
                Toast.show("保存位置不可写，已保存到「图片」", detail: url.path(percentEncoded: false), action: reveal)
            } else {
                Toast.show("已保存", detail: url.path(percentEncoded: false), action: reveal)
            }
        } catch {
            Self.logger.error("save failed: \(error.localizedDescription)")
            Toast.show("保存失败", detail: error.localizedDescription)
        }
    }

    /// OCR-mode capture and the pin menu: copy recognised text, toast the first lines.
    func recognizeToClipboard(_ image: CGImage) {
        Task { @MainActor in
            let (lines, link) = await Self.recognize(image)
            if !lines.isEmpty {
                ClipboardWriter.write(text: lines.joinedAsLines)
                Toast.show("已复制文字", detail: lines.prefix(3).joined(separator: "\n"),
                           action: link.map(Self.copyLinkAction))
            } else if let link {
                Self.showQRToast(link)
            } else {
                Toast.show("未识别到文字")
            }
        }
    }

    /// Annotate-mode 「识别文字」: editable result panel.
    private func recognizeToPanel(_ image: CGImage) {
        Task { @MainActor in
            let (lines, link) = await Self.recognize(image)
            if !lines.isEmpty {
                OCRResultPanel.show(text: lines.joinedAsLines)
                if let link { Self.showQRToast(link) }
            } else if let link {
                Self.showQRToast(link)
            } else {
                Toast.show("未识别到文字")
            }
        }
    }

    // MARK: Private

    private func handleAnnotate(_ result: OverlayResult) {
        switch result {
        case .cancelled:
            break
        case .copy(let image):
            ClipboardWriter.write(image: image)
            Toast.show("已复制", detail: "\(image.width) × \(image.height)")
        case .save(let image):
            save(image)
        case .pin(let image, let globalFrame):
            guard globalFrame.width > 0 else { return }
            pins.add(PinItem(image: image, imageScale: CGFloat(image.width) / globalFrame.width, frame: globalFrame))
        case .ocr(let image):
            recognizeToPanel(image)
        case .copiedColor(let color):
            Toast.show("已复制 \(color)")
        }
    }

    private func startOverlay(mode: OverlayMode, completion: @escaping (OverlayResult) -> Void) {
        guard beginCapture() else { return }
        CaptureSignpost.begin()
        Task { @MainActor in
            guard let snapshot = await takeSnapshot() else {
                CaptureSignpost.end()
                isCapturing = false
                return
            }
            let front = NSWorkspace.shared.frontmostApplication
            previousApp = front == .current ? nil : front
            let controller = OverlayController(snapshot: snapshot, mode: mode, preferences: preferences)
            overlay = controller
            ActivationHelper.activateForKeyboard()
            controller.present { [weak self] result in
                guard let self else { return }
                overlay = nil
                isCapturing = false
                restoreFocus(mode: mode, result: result)
                completion(result)
            }
        }
    }

    /// Permission check plus the re-entrancy guard shared by every capture entry.
    private func beginCapture() -> Bool {
        guard !isCapturing, overlay == nil else { return false }
        guard ScreenCapturePermission.isGranted else {
            showOnboarding()
            return false
        }
        isCapturing = true
        return true
    }

    private func takeSnapshot() async -> CaptureSnapshot? {
        do {
            return try await capture.snapshot()
        } catch {
            report(error)
            return nil
        }
    }

    private func report(_ error: Error) {
        Self.logger.error("capture failed: \(String(describing: error))")
        switch error as? CaptureError {
        case .permissionDenied:
            showOnboarding()
        case .noDisplays:
            Toast.show("截图失败", detail: "没有找到可截取的显示器")
        case .underlying(let reason):
            Toast.show("截图失败", detail: reason)
        case nil:
            Toast.show("截图失败", detail: error.localizedDescription)
        }
    }

    /// Hands activation back to the app the user was in, unless the result opens a window of ours
    /// (annotate-mode 「识别文字」 shows the OCR panel, which activates the app itself).
    private func restoreFocus(mode: OverlayMode, result: OverlayResult) {
        let app = previousApp
        previousApp = nil
        if mode == .annotate, case .ocr = result { return }
        app?.activate()
    }

    private static func showQRToast(_ link: String) {
        Toast.show("识别到二维码", detail: link, action: Self.copyLinkAction(link))
    }

    private static func copyLinkAction(_ link: String) -> (title: String, handler: () -> Void) {
        ("复制链接", { ClipboardWriter.write(text: link) })
    }

    /// Text lines (empty on failure) and the first QR payload, recognised concurrently.
    private static func recognize(_ image: CGImage) async -> (lines: [String], link: String?) {
        async let codes = detectQR(image)
        let lines: [String]
        do {
            lines = try await TextRecognizer.recognize(image)
        } catch {
            logger.error("text recognition failed: \(error.localizedDescription)")
            lines = []
        }
        return (lines, await codes.first)
    }

    private static func detectQR(_ image: CGImage) async -> [String] {
        do {
            return try await QRDetector.detect(image)
        } catch {
            logger.error("QR detection failed: \(error.localizedDescription)")
            return []
        }
    }
}
