import AppKit

public enum ClipboardContent: Equatable {
    case image(CGImage), text(String), none

    /// Images take priority; otherwise non-blank text.
    @MainActor
    public static func read(from pb: NSPasteboard) -> ClipboardContent {
        if let image = NSImage(pasteboard: pb),
           let cg = image.cgImage(forProposedRect: nil, context: nil, hints: nil) {
            return .image(cg)
        }
        if let s = pb.string(forType: .string),
           !s.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return .text(s)
        }
        return .none
    }
}
