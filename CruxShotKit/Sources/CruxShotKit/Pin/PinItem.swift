import Foundation
import CoreGraphics

public struct PinItem: Identifiable {
    public let id: UUID
    public let image: CGImage
    public let imageScale: CGFloat
    /// AppKit global coordinates.
    public var frame: CGRect
    public var transform: PinTransform
    public var clickThrough: Bool
    public var followsSpaces: Bool
    public var annotations: [Annotation]

    public init(id: UUID = UUID(), image: CGImage, imageScale: CGFloat, frame: CGRect,
                transform: PinTransform = PinTransform(), clickThrough: Bool = false,
                followsSpaces: Bool = true, annotations: [Annotation] = []) {
        self.id = id
        self.image = image
        self.imageScale = imageScale
        self.frame = frame
        self.transform = transform
        self.clickThrough = clickThrough
        self.followsSpaces = followsSpaces
        self.annotations = annotations
    }
}
