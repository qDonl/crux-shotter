import CoreGraphics

/// Pixel-level queries on a `CaptureSnapshot` for the overlay: which display a rect belongs to,
/// selection crops, and (lazily built, cached per display) color sampling.
@MainActor
final class SnapshotPixels {
    struct Crop {
        let image: CGImage
        let frame: CapturedFrame
        /// AppKit global rect actually covered by `image`.
        let globalRect: CGRect
    }

    let snapshot: CaptureSnapshot
    private var samplers: [CGDirectDisplayID: PixelSampler] = [:]

    init(snapshot: CaptureSnapshot) { self.snapshot = snapshot }

    /// The frame whose display contains the rect's center, else the one it overlaps most.
    func bestFrame(for rect: CGRect) -> CapturedFrame? {
        if let f = snapshot.frame(containing: CGPoint(x: rect.midX, y: rect.midY)) { return f }
        func area(_ f: CapturedFrame) -> CGFloat {
            let i = f.display.frame.intersection(rect)
            return i.isNull ? 0 : i.width * i.height
        }
        return snapshot.frames.max { area($0) < area($1) }
    }

    /// Pixel size of a global rect on the display containing its center.
    func pixelSize(of rect: CGRect) -> CGSize? {
        guard let frame = bestFrame(for: rect) else { return nil }
        let px = Geometry.pixelRect(for: rect, on: frame.display)
        return px.isNull || px.isEmpty ? nil : px.size
    }

    /// Crops `rect` from the display containing its center (clipped to that display; v1 does not
    /// stitch displays). An explicit display ID keeps adjustments on the original display.
    func crop(_ rect: CGRect, displayID: CGDirectDisplayID? = nil) -> Crop? {
        let selected: CapturedFrame?
        if let displayID {
            selected = snapshot.frames.first { $0.display.displayID == displayID }
        } else {
            selected = bestFrame(for: rect)
        }
        guard let frame = selected else { return nil }
        let px = Geometry.pixelRect(for: rect, on: frame.display)
        guard !px.isNull, !px.isEmpty, let image = frame.image.cropping(to: px) else { return nil }
        let d = frame.display, s = d.scale
        let global = CGRect(x: d.frame.minX + px.minX / s, y: d.frame.maxY - px.maxY / s,
                            width: px.width / s, height: px.height / s)
        return Crop(image: image, frame: frame, globalRect: global)
    }

    /// Pixel (top-left origin) under a global point on the given display.
    func pixel(of g: CGPoint, on d: DisplayInfo) -> (x: Int, y: Int) {
        (Int(((g.x - d.frame.minX) * d.scale).rounded(.down)), Int(((d.frame.maxY - g.y) * d.scale).rounded(.down)))
    }

    func sampler(for frame: CapturedFrame) -> PixelSampler {
        if let s = samplers[frame.display.displayID] { return s }
        let s = PixelSampler(image: frame.image)
        samplers[frame.display.displayID] = s
        return s
    }

    /// Color string at a global point, or nil when it is on no display.
    func colorString(at g: CGPoint, format: ColorFormat) -> String? {
        guard let frame = snapshot.frame(containing: g) else { return nil }
        let p = pixel(of: g, on: frame.display)
        return sampler(for: frame).color(atPixel: p.x, p.y).map(format.string(for:))
    }

    func releaseSamplers() { samplers.removeAll() }
}
