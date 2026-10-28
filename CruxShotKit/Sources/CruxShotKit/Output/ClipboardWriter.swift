import AppKit

public enum ClipboardWriter {
    /// Writes the image as PNG, plus TIFF for apps that only read TIFF.
    @MainActor
    public static func write(image: CGImage, to pb: NSPasteboard = .general) {
        let rep = NSBitmapImageRep(cgImage: image)
        pb.clearContents()
        pb.declareTypes([.png, .tiff], owner: nil)
        if let png = rep.representation(using: .png, properties: [:]) { pb.setData(png, forType: .png) }
        if let tiff = rep.tiffRepresentation { pb.setData(tiff, forType: .tiff) }
    }

    @MainActor
    public static func write(text: String, to pb: NSPasteboard = .general) {
        pb.clearContents()
        pb.setString(text, forType: .string)
    }
}
