import AppKit
import CoreGraphics
import OSLog
@preconcurrency import ScreenCaptureKit

public enum CaptureError: Error {
    case permissionDenied
    case noDisplays
    case underlying(String)
}

public protocol ScreenCapturing: Sendable {
    func snapshot() async throws -> CaptureSnapshot
}

/// ScreenCaptureKit objects are not marked Sendable; they are immutable once built here.
private struct CaptureJob: @unchecked Sendable {
    let filter: SCContentFilter
    let config: SCStreamConfiguration
}

public struct ScreenCaptureService: ScreenCapturing {
    private static let logger = Logger(subsystem: "com.cruxshot", category: "Capture")
    private static let minWindowSide: CGFloat = 40

    public init() {}

    public func snapshot() async throws -> CaptureSnapshot {
        guard ScreenCapturePermission.isGranted else { throw CaptureError.permissionDenied }

        let content: SCShareableContent
        do {
            content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
        } catch {
            Self.logger.error("SCShareableContent failed: \(error.localizedDescription)")
            throw CaptureError.underlying(error.localizedDescription)
        }
        guard !content.displays.isEmpty else { throw CaptureError.noDisplays }

        let ownBundleID = Bundle.main.bundleIdentifier
        let ownApps = content.applications.filter { $0.bundleIdentifier == ownBundleID }

        let scales = await Self.screenScales()
        let primaryHeight = await Self.primaryScreenHeight()

        let frames: [CapturedFrame]
        do {
            frames = try await withThrowingTaskGroup(of: (Int, CapturedFrame).self) { group in
                for (index, display) in content.displays.enumerated() {
                    let scale = scales[display.displayID] ?? 1
                    let info = DisplayInfo(
                        displayID: display.displayID,
                        frame: Geometry.appKitRect(fromCG: display.frame, primaryScreenHeight: primaryHeight),
                        scale: scale
                    )
                    let job = CaptureJob(
                        filter: SCContentFilter(display: display, excludingApplications: ownApps, exceptingWindows: []),
                        config: {
                            let config = SCStreamConfiguration()
                            config.width = Int((info.frame.width * scale).rounded())
                            config.height = Int((info.frame.height * scale).rounded())
                            config.showsCursor = false
                            config.captureResolution = .best
                            return config
                        }()
                    )
                    group.addTask {
                        let image = try await SCScreenshotManager.captureImage(contentFilter: job.filter, configuration: job.config)
                        return (index, CapturedFrame(display: info, image: image))
                    }
                }
                var result: [(Int, CapturedFrame)] = []
                for try await item in group { result.append(item) }
                return result.sorted { $0.0 < $1.0 }.map(\.1)
            }
        } catch {
            Self.logger.error("captureImage failed: \(error.localizedDescription)")
            throw CaptureError.underlying(error.localizedDescription)
        }

        var windows: [WindowInfo] = []
        for window in content.windows {
            guard window.windowLayer == 0,
                  window.owningApplication?.bundleIdentifier != ownBundleID,
                  window.frame.width >= Self.minWindowSide,
                  window.frame.height >= Self.minWindowSide else { continue }
            windows.append(WindowInfo(
                windowID: window.windowID,
                frame: Geometry.appKitRect(fromCG: window.frame, primaryScreenHeight: primaryHeight),
                title: window.title,
                appName: window.owningApplication?.applicationName,
                zIndex: windows.count
            ))
        }
        Self.logger.debug("snapshot: \(frames.count) frames, \(windows.count) windows")
        return CaptureSnapshot(frames: frames, windows: windows)
    }

    @MainActor private static func screenScales() -> [CGDirectDisplayID: CGFloat] {
        var map: [CGDirectDisplayID: CGFloat] = [:]
        for screen in NSScreen.screens {
            if let number = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber {
                map[CGDirectDisplayID(number.uint32Value)] = screen.backingScaleFactor
            }
        }
        return map
    }

    /// Height of the primary display (the one at the global origin), used for CG -> AppKit flips.
    @MainActor private static func primaryScreenHeight() -> CGFloat {
        NSScreen.screens.first?.frame.height ?? 0
    }
}
