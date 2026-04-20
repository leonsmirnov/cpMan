import Vision
import AppKit
import ImageIO
import os.log

private let logger = Logger(subsystem: "com.cpman.app", category: "OCRService")

/// Runs Apple Vision text recognition on captured images in the background.
/// Accepts only Sendable primitives (UUID + file path) — never touches the
/// main-actor-isolated ClipboardItem across the actor boundary.
actor OCRService {
    static let shared = OCRService()

    private init() {}

    func processImage(itemId: UUID, imagePath: String) async {
        // P6: downscale via CGImageSource before Vision — avoids loading a full 4-8K bitmap.
        guard let cgImage = thumbnail(at: imagePath, maxPixels: 2048) else {
            logger.warning("OCR skipped: could not decode image at \(imagePath)")
            return
        }

        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true

        do {
            let handler = VNImageRequestHandler(cgImage: cgImage)
            try handler.perform([request])

            let recognized = request.results?
                .compactMap { $0.topCandidates(1).first?.string }
                .joined(separator: "\n") ?? ""

            guard !recognized.isEmpty else {
                logger.debug("OCR found no text in item \(itemId)")
                return
            }

            logger.info("OCR extracted \(recognized.count) chars for item \(itemId)")

            await MainActor.run {
                HistoryStore.shared.updateOCR(forId: itemId, text: recognized)
            }
        } catch {
            logger.error("OCR failed for item \(itemId): \(error)")
        }
    }

    // MARK: - Private

    /// Returns a CGImage downscaled to maxPixels on its longest side using CGImageSource.
    /// Thread-safe; does not require the main thread.
    private func thumbnail(at path: String, maxPixels: Int) -> CGImage? {
        let url = URL(fileURLWithPath: path) as CFURL
        let opts: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageIfAbsent: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixels,
            kCGImageSourceCreateThumbnailWithTransform: true,
        ]
        guard let source = CGImageSourceCreateWithURL(url, nil) else { return nil }
        return CGImageSourceCreateThumbnailAtIndex(source, 0, opts as CFDictionary)
    }
}
