import OSLog

/// `capture-to-overlay` signpost interval (subsystem `com.cruxshot`, Points of Interest):
/// begun by the caller right before taking the snapshot, ended by `OverlayController`
/// when the first overlay window is ordered front. Measure it in Instruments.
@MainActor
public enum CaptureSignpost {
    private static let signposter = OSSignposter(subsystem: "com.cruxshot", category: .pointsOfInterest)
    private static var state: OSSignpostIntervalState?

    public static func begin() {
        end()
        state = signposter.beginInterval("capture-to-overlay")
    }

    /// Ends the interval if one is open; safe to call more than once.
    public static func end() {
        guard let state else { return }
        signposter.endInterval("capture-to-overlay", state)
        self.state = nil
    }
}
