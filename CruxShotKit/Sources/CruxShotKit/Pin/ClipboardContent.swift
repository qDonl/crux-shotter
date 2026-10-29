import AppKit
import UniformTypeIdentifiers

public enum ClipboardContent: Equatable {
    case image(CGImage)
    /// Image or PDF files copied in Finder, in pasteboard order.
    case imageFiles([URL])
    case color(ColorLiteral)
    case richText(NSAttributedString)
    case text(String)
    case none

    /// At most this many copied files are pinned at once.
    public static let maxImageFiles = 10

    /// Priority: image files > image data > color value > rich text (RTF, then HTML) > plain text.
    /// When files are on the pasteboard but none is an image, image data is skipped: Finder puts
    /// the file icon there, which is never what the user meant to pin.
    @MainActor
    public static func read(from pb: NSPasteboard) -> ClipboardContent {
        let fileURLs = pb.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL] ?? []
        let imageTypes = [UTType.image, UTType.pdf]
        let imageFiles = fileURLs.filter { url in
            guard let type = UTType(filenameExtension: url.pathExtension) else { return false }
            return imageTypes.contains { type.conforms(to: $0) }
        }
        if !imageFiles.isEmpty { return .imageFiles(imageFiles) }

        if fileURLs.isEmpty, let image = NSImage(pasteboard: pb),
           let cg = image.cgImage(forProposedRect: nil, context: nil, hints: nil) {
            return .image(cg)
        }

        let plain = pb.string(forType: .string)
        if let plain, let color = ColorLiteral.parse(plain) { return .color(color) }

        if let rich = richText(from: pb) { return .richText(rich) }

        if let plain, !plain.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return .text(plain)
        }
        return .none
    }

    /// RTF or HTML, with trailing whitespace trimmed; nil when absent or blank.
    @MainActor
    private static func richText(from pb: NSPasteboard) -> NSAttributedString? {
        var parsed: NSAttributedString?
        if let data = pb.data(forType: .rtf) {
            parsed = NSAttributedString(rtf: data, documentAttributes: nil)
        } else if let data = pb.data(forType: .html) {
            // Pasteboard HTML is UTF-8 and often lacks a charset declaration.
            parsed = NSAttributedString(html: data, options: [.characterEncoding: String.Encoding.utf8.rawValue],
                                        documentAttributes: nil)
        }
        guard let parsed else { return nil }
        let text = parsed.string as NSString
        var end = text.length
        while end > 0, let scalar = UnicodeScalar(text.character(at: end - 1)),
              CharacterSet.whitespacesAndNewlines.contains(scalar) {
            end -= 1
        }
        guard end > 0 else { return nil }
        return parsed.attributedSubstring(from: NSRange(location: 0, length: end))
    }
}
