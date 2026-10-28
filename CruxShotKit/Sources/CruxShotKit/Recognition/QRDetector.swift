import Foundation
import CoreGraphics
import Vision

public enum QRDetector {
    /// Returns the non-empty payloads of all QR codes found in the image.
    public static func detect(_ image: CGImage) async throws -> [String] {
        try await Task.detached(priority: .userInitiated) {
            let request = VNDetectBarcodesRequest()
            request.symbologies = [.qr]
            do {
                try VNImageRequestHandler(cgImage: image, options: [:]).perform([request])
            } catch {
                throw RecognitionError.failed(error.localizedDescription)
            }
            return (request.results ?? []).compactMap { $0.payloadStringValue }.filter { !$0.isEmpty }
        }.value
    }
}
