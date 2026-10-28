import CoreGraphics

public struct DisplayInfo: Sendable, Equatable {
    public let displayID: CGDirectDisplayID
    /// AppKit global coordinates, in points.
    public let frame: CGRect
    public let scale: CGFloat

    public init(displayID: CGDirectDisplayID, frame: CGRect, scale: CGFloat) {
        self.displayID = displayID
        self.frame = frame
        self.scale = scale
    }
}
