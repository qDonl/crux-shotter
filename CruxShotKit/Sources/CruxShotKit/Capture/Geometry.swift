import CoreGraphics

public enum Geometry {
    /// Converts a CG (top-left origin) global rect to AppKit (bottom-left origin) global coordinates.
    public static func appKitRect(fromCG rect: CGRect, primaryScreenHeight: CGFloat) -> CGRect {
        CGRect(x: rect.minX, y: primaryScreenHeight - rect.maxY, width: rect.width, height: rect.height)
    }

    /// Pixel rect (top-left origin) inside the display's screenshot for an AppKit global rect,
    /// rounded outward to whole pixels and clipped to the image bounds.
    public static func pixelRect(for globalRect: CGRect, on display: DisplayInfo) -> CGRect {
        let s = display.scale
        let minX = (globalRect.minX - display.frame.minX) * s
        let maxX = (globalRect.maxX - display.frame.minX) * s
        let minY = (display.frame.maxY - globalRect.maxY) * s
        let maxY = (display.frame.maxY - globalRect.minY) * s
        let outward = CGRect(x: minX.rounded(.down), y: minY.rounded(.down),
                             width: maxX.rounded(.up) - minX.rounded(.down),
                             height: maxY.rounded(.up) - minY.rounded(.down))
        let bounds = CGRect(x: 0, y: 0, width: display.frame.width * s, height: display.frame.height * s)
        return outward.intersection(bounds)
    }

    /// Global (AppKit) point to canvas image coordinates (top-left origin).
    public static func imagePoint(fromGlobal point: CGPoint, imageOriginGlobal: CGRect) -> CGPoint {
        CGPoint(x: point.x - imageOriginGlobal.minX, y: imageOriginGlobal.maxY - point.y)
    }
}
