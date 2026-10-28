import AppKit
import CruxShotKit
import OSLog

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private static let logger = Logger(subsystem: "com.cruxshot", category: "App")
    private var statusItem: NSStatusItem?
    /// Debug-only capture flow; Task 15 replaces it with the real capture coordinator.
    private var debugOverlay: OverlayController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.image = NSImage(systemSymbolName: "camera.viewfinder", accessibilityDescription: "CruxShot")

        let menu = NSMenu()
        let debugItem = NSMenuItem(title: "截图（调试）", action: #selector(debugCapture), keyEquivalent: "")
        debugItem.target = self
        menu.addItem(debugItem)
        menu.addItem(.separator())
        menu.addItem(withTitle: "退出 CruxShot", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        item.menu = menu
        statusItem = item
    }

    // TODO(Task 15): remove this debug entry point.
    @objc private func debugCapture() {
        guard debugOverlay == nil else { return }
        CaptureSignpost.begin()
        Task { @MainActor in
            let snapshot: CaptureSnapshot
            do {
                snapshot = try await ScreenCaptureService().snapshot()
            } catch CaptureError.permissionDenied {
                CaptureSignpost.end()
                Self.logger.error("debug capture: screen recording permission denied")
                print("CruxShot: screen recording permission denied")
                return
            } catch {
                CaptureSignpost.end()
                Self.logger.error("debug capture failed: \(String(describing: error))")
                return
            }
            let controller = OverlayController(snapshot: snapshot, mode: .annotate, preferences: .shared)
            debugOverlay = controller
            controller.present { [weak self] result in
                self?.debugOverlay = nil
                Self.logDebugResult(result)
            }
        }
    }

    private static func logDebugResult(_ result: OverlayResult) {
        switch result {
        case .cancelled:
            logger.info("debug capture result: cancelled")
        case .copy(let image):
            ClipboardWriter.write(image: image)
            logger.info("debug capture result: copy \(image.width)x\(image.height)")
            Toast.show("已复制到剪贴板", detail: "\(image.width) × \(image.height)")
        case .save(let image):
            logger.info("debug capture result: save \(image.width)x\(image.height)")
        case .pin(let image, let frame):
            logger.info("debug capture result: pin \(image.width)x\(image.height) at \(String(describing: frame))")
        case .ocr(let image):
            logger.info("debug capture result: ocr \(image.width)x\(image.height)")
        case .copiedColor(let color):
            logger.info("debug capture result: copiedColor \(color)")
            Toast.show("已复制颜色", detail: color)
        }
    }
}
