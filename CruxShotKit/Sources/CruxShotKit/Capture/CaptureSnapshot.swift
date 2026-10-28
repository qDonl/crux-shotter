import CoreGraphics

public struct CapturedFrame: @unchecked Sendable {
    public let display: DisplayInfo
    public let image: CGImage

    public init(display: DisplayInfo, image: CGImage) {
        self.display = display
        self.image = image
    }
}

public struct CaptureSnapshot: Sendable {
    public let frames: [CapturedFrame]
    public let windows: [WindowInfo]

    public init(frames: [CapturedFrame], windows: [WindowInfo]) {
        self.frames = frames
        self.windows = windows
    }

    public func frame(containing point: CGPoint) -> CapturedFrame? {
        frames.first { $0.display.frame.contains(point) }
    }
}
