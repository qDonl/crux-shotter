import CoreGraphics

public enum WindowHitTester {
    /// Frontmost window (smallest zIndex) whose frame contains the point.
    public static func window(at point: CGPoint, in windows: [WindowInfo]) -> WindowInfo? {
        windows.filter { $0.frame.contains(point) }.min { $0.zIndex < $1.zIndex }
    }
}
