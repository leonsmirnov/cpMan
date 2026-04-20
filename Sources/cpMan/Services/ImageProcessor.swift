import AppKit
import CryptoKit
import os.log

private let logger = Logger(subsystem: "com.cpman.app", category: "ImageProcessor")

/// Handles image capture processing: resize, SHA-256 hashing, and disk storage.
/// @MainActor because it reads AppSettings.shared and uses NSImage drawing (main-thread only).
@MainActor
final class ImageProcessor {
    static let shared = ImageProcessor()

    private init() {}

    // MARK: - Capture

    func processCapture(
        image: NSImage,
        sourceApp: String?,
        sourceBundleId: String?
    ) -> ClipboardItem? {
        let settings = AppSettings.shared
        var processed = image

        if settings.imageMaxDimensionEnabled {
            processed = resize(processed, maxDimension: CGFloat(settings.imageMaxDimension))
            logger.debug("Resized image to max \(settings.imageMaxDimension)px")
        }

        // P5: early rough bail-out before allocating a full PNG encode.
        if settings.imageSizeLimitEnabled, settings.imageSizeLimitMB > 0 {
            let maxBytes = settings.imageSizeLimitMB * 1_048_576
            let roughBytes = Int(processed.size.width * processed.size.height) * 4
            if roughBytes > maxBytes * 8 {
                logger.warning("Image too large (~\(roughBytes / 1_048_576)MB estimated), skipping capture")
                return nil
            }
        }

        guard let data = pngData(from: processed) else {
            logger.error("Failed to encode captured image as PNG")
            return nil
        }

        if settings.imageSizeLimitEnabled, settings.imageSizeLimitMB > 0 {
            let maxBytes = settings.imageSizeLimitMB * 1_048_576
            if data.count > maxBytes {
                logger.warning("PNG (\(data.count / 1_048_576)MB) exceeds limit (\(settings.imageSizeLimitMB)MB), skipping")
                return nil
            }
        }

        let hash = sha256(data)
        guard let fileURL = writeToDisk(data: data) else {
            logger.error("Failed to write image to disk")
            return nil
        }

        logger.info("Captured image \(Int(processed.size.width))×\(Int(processed.size.height)) \(data.count / 1024)KB → \(fileURL.lastPathComponent)")

        return ClipboardItem(
            sourceApp: sourceApp,
            sourceBundleId: sourceBundleId,
            contentType: .image,
            imageFilePath: fileURL.path,
            imageWidth: Int(processed.size.width),
            imageHeight: Int(processed.size.height),
            imageSizeBytes: data.count,
            imageHash: hash
        )
    }

    // MARK: - Export

    /// Exports an image item as a PNG file to a temp location. Used by "Copy as File" action.
    func exportAsFile(item: ClipboardItem) -> URL? {
        guard let path = item.imageFilePath,
              let image = NSImage(contentsOfFile: path),
              let data = pngData(from: image)
        else {
            logger.error("exportAsFile: failed to load or encode image for item \(item.id)")
            return nil
        }

        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString + ".png")
        do {
            try data.write(to: tempURL)
            logger.debug("Exported image to temp file: \(tempURL.lastPathComponent)")
            return tempURL
        } catch {
            logger.error("exportAsFile: write failed: \(error)")
            return nil
        }
    }

    // MARK: - Private helpers

    private func resize(_ image: NSImage, maxDimension: CGFloat) -> NSImage {
        let size = image.size
        guard size.width > maxDimension || size.height > maxDimension else { return image }
        let scale   = maxDimension / max(size.width, size.height)
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)
        let result  = NSImage(size: newSize)
        result.lockFocus()
        image.draw(in: NSRect(origin: .zero, size: newSize))
        result.unlockFocus()
        return result
    }

    /// Encodes image as PNG via CGImage. Round-trip through CGImage unconditionally
    /// strips EXIF/XMP/IPTC metadata — no separate `stripMetadata` flag required.
    private func pngData(from image: NSImage) -> Data? {
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return nil }
        let rep = NSBitmapImageRep(cgImage: cgImage)
        return rep.representation(using: .png, properties: [:])
    }

    // SHA256 byte sequence is guaranteed non-nil — map, not compactMap
    internal func sha256(_ data: Data) -> String {
        SHA256.hash(data: data)
            .map { String(format: "%02x", $0) }
            .joined()
    }

    private func writeToDisk(data: Data) -> URL? {
        let dir = imagesDirectory
        let url = dir.appendingPathComponent(UUID().uuidString + ".png")
        do {
            try data.write(to: url)
            return url
        } catch {
            logger.error("writeToDisk failed: \(error)")
            return nil
        }
    }

    private var imagesDirectory: URL {
        let support = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let dir = support.appendingPathComponent("cpMan/Images", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }
}
