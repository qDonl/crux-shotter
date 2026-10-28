import CoreGraphics

public struct PinTransform: Sendable, Equatable {
    public var scale: CGFloat = 1
    public var opacity: CGFloat = 1
    /// Clockwise quarter turns, 0...3.
    public var quarterTurns: Int = 0
    public var flippedH = false
    public var flippedV = false

    public init() {}

    public mutating func zoom(by factor: CGFloat) {
        scale = min(max(scale * factor, 0.1), 5.0)
    }

    public mutating func adjustOpacity(by delta: CGFloat) {
        opacity = min(max(opacity + delta, 0.1), 1.0)
    }

    public mutating func rotateCW() { quarterTurns = (quarterTurns + 1) % 4 }
    public mutating func rotateCCW() { quarterTurns = (quarterTurns + 3) % 4 }
    public mutating func resetScale() { scale = 1 }

    public func displaySize(for imagePointSize: CGSize) -> CGSize {
        let base = quarterTurns % 2 == 0
            ? imagePointSize
            : CGSize(width: imagePointSize.height, height: imagePointSize.width)
        return CGSize(width: base.width * scale, height: base.height * scale)
    }
}
