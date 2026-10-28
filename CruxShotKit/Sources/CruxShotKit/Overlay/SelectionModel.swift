import CoreGraphics

/// Selection state for the capture overlay. Coordinates are AppKit global points (y up).
public struct SelectionModel: Sendable, Equatable {
    public enum Phase: Sendable, Equatable { case selecting, adjusting }

    /// Minimum drag displacement (points) that counts as a drag rather than a click.
    static let dragThreshold: CGFloat = 3

    public let bounds: CGRect
    public private(set) var phase: Phase = .selecting
    public private(set) var rect: CGRect?
    public private(set) var hoveredWindow: WindowInfo?
    private var anchor: CGPoint?

    public init(bounds: CGRect) { self.bounds = bounds }

    public mutating func hover(at point: CGPoint, windows: [WindowInfo]) {
        guard phase == .selecting else { return }
        hoveredWindow = WindowHitTester.window(at: point, in: windows)
    }

    public mutating func mouseDown(at point: CGPoint) {
        guard phase == .selecting else { return }
        anchor = point
        rect = nil
    }

    public mutating func mouseDragged(to point: CGPoint) {
        guard phase == .selecting, let anchor else { return }
        rect = Self.normalized(anchor, point).intersection(bounds).nonEmpty
    }

    public mutating func mouseUp(at point: CGPoint) {
        guard phase == .selecting, let start = anchor else { return }
        anchor = nil
        if hypot(point.x - start.x, point.y - start.y) < Self.dragThreshold {
            if let frame = hoveredWindow?.frame.intersection(bounds).nonEmpty {
                commit(frame)
            } else {
                rect = nil
            }
        } else if let r = Self.normalized(start, point).intersection(bounds).nonEmpty {
            commit(r)
        } else {
            rect = nil
        }
    }

    /// Moves the rect by `dx/pixelScale`, `dy/pixelScale` points, keeping it inside `bounds`.
    public mutating func nudge(dx: Int, dy: Int, pixelScale: CGFloat) {
        guard var r = rect, pixelScale > 0 else { return }
        r.origin.x += CGFloat(dx) / pixelScale
        r.origin.y += CGFloat(dy) / pixelScale
        r.origin.x = min(max(r.origin.x, bounds.minX), max(bounds.minX, bounds.maxX - r.width))
        r.origin.y = min(max(r.origin.y, bounds.minY), max(bounds.minY, bounds.maxY - r.height))
        rect = r
    }

    /// Grows/shrinks the rect (origin fixed) by whole pixels; never below 1 pixel.
    public mutating func resize(dw: Int, dh: Int, pixelScale: CGFloat) {
        guard var r = rect, pixelScale > 0 else { return }
        let minSide = 1 / pixelScale
        r.size.width = max(minSide, r.width + CGFloat(dw) / pixelScale)
        r.size.height = max(minSide, r.height + CGFloat(dh) / pixelScale)
        rect = r.intersection(bounds).nonEmpty ?? rect
    }

    /// Called by the view when dragging edges/handles; clamped to `bounds`.
    public mutating func setRect(_ newRect: CGRect) {
        guard let clamped = newRect.standardized.intersection(bounds).nonEmpty else { return }
        rect = clamped
    }

    /// Enters `.adjusting` with the given rect (clamped to bounds).
    mutating func commit(_ newRect: CGRect) {
        guard let clamped = newRect.intersection(bounds).nonEmpty else { return }
        rect = clamped
        phase = .adjusting
    }

    private static func normalized(_ a: CGPoint, _ b: CGPoint) -> CGRect {
        CGRect(x: min(a.x, b.x), y: min(a.y, b.y), width: abs(a.x - b.x), height: abs(a.y - b.y))
    }
}

private extension CGRect {
    /// nil when null/empty.
    var nonEmpty: CGRect? { isNull || isEmpty ? nil : self }
}
