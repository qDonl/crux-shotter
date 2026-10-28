import CoreGraphics
import Foundation

public enum ScreenCapturePermission {
    public static var isGranted: Bool { CGPreflightScreenCaptureAccess() }

    /// May show a system dialog.
    public static func request() { _ = CGRequestScreenCaptureAccess() }

    public static let settingsURL = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture")!
}
