import CoreGraphics

public struct WindowInfo: Sendable, Equatable {
    public let windowID: CGWindowID
    /// AppKit global coordinates, in points.
    public let frame: CGRect
    public let title: String?
    public let appName: String?
    /// 0 = frontmost.
    public let zIndex: Int

    public init(windowID: CGWindowID, frame: CGRect, title: String?, appName: String?, zIndex: Int) {
        self.windowID = windowID
        self.frame = frame
        self.title = title
        self.appName = appName
        self.zIndex = zIndex
    }
}
