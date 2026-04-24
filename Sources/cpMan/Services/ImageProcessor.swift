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
    ) async -> ClipboardItem? {
        let settings = AppSettings.shared
        
        let maxDimEnabled = settings.imageMaxDimensionEnabled
        let maxDim = CGFloat(settings.imageMaxDimension)
        let sizeLimitEnabled = settings.imageSizeLimitEnabled
        let sizeLimitMB = settings.imageSizeLimitMB

        // Offload heavy CPU and I/O work
        let result: (URL, Int, Int, Int, String)? = await Task.detached(priority: .userInitiated) {
            var processed = image

            if maxDimEnabled {
                processed = Self.resize(processed, maxDimension: maxDim)
                logger.debug("Resized image to max \(maxDim)px")
            }

            // P5: early rough bail-out before allocating a full PNG encode.
            if sizeLimitEnabled, sizeLimitMB > 0 {
                let maxBytes = sizeLimitMB * 1_048_576
                let roughBytes = Int(processed.size.width * processed.size.height) * 4
                if roughBytes > maxBytes * 8 {
                    logger.warning("Image too large (~\(roughBytes / 1_048_576)MB estimated), skipping capture")
                    return nil
                }
            }

            guard let data = Self.pngData(from: processed) else {
                logger.error("Failed to encode captured image as PNG")
                return nil
            }

            if sizeLimitEnabled, sizeLimitMB > 0 {
                let maxBytes = sizeLimitMB * 1_048_576
                if data.count > maxBytes {
                    logger.warning("PNG (\(data.count / 1_048_576)MB) exceeds limit (\(sizeLimitMB)MB), skipping")
                    return nil
                }
            }

            let hash = Self.sha256(data)
            guard let fileURL = Self.writeToDisk(data: data) else {
                logger.error("Failed to write image to disk")
                return nil
            }

            logger.info("Captured image \(Int(processed.size.width))×\(Int(processed.size.height)) \(data.count / 1024)KB → \(fileURL.lastPathComponent)")

            return (fileURL, Int(processed.size.width), Int(processed.size.height), data.count, hash)
        }.value

        guard let result else { return nil }

        return ClipboardItem(
            sourceApp: sourceApp,
            sourceBundleId: sourceBundleId,
            contentType: .image,
            imageFilePath: result.0.path,
            imageWidth: result.1,
            imageHeight: result.2,
            imageSizeBytes: result.3,
            imageHash: result.4
        )
    }

    // MARK: - Export

    /// Exports an image item as a PNG file for pasteboard use. Used by "Copy as File" action.
    /// Files are written to a dedicated Exports directory with owner-only permissions.
    /// Stale exports older than 5 minutes are cleaned up on each call.
    func exportAsFile(item: ClipboardItem) -> URL? {
        guard let path = item.imageFilePath,
              let image = NSImage(contentsOfFile: path),
              let data = Self.pngData(from: image)
        else {
            logger.error("exportAsFile: failed to load or encode image for item \(item.id)")
            return nil
        }

        let exportDir = exportsDirectory
        let fileURL = exportDir.appendingPathComponent(UUID().uuidString + ".png")
        do {
            try data.write(to: fileURL)
            try FileManager.default.setAttributes(
                [.posixPermissions: 0o600], ofItemAtPath: fileURL.path
            )
            logger.debug("Exported image to: \(fileURL.lastPathComponent)")
            return fileURL
        } catch {
            logger.error("exportAsFile: write failed: \(error)")
            return nil
        }
    }

    /// Dedicated export directory under Application Support with owner-only
    /// permissions. Cleans up files older than 5 minutes on each access.
    private var exportsDirectory: URL {
        let support = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let dir = support.appendingPathComponent("cpMan/Exports", isDirectory: true)
        let fm = FileManager.default
        try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        try? fm.setAttributes([.posixPermissions: 0o700], ofItemAtPath: dir.path)

        // Clean up stale export files (older than 5 minutes).
        let cutoff = Date().addingTimeInterval(-300)
        if let files = try? fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: [.creationDateKey]) {
            for file in files {
                if let created = (try? file.resourceValues(forKeys: [.creationDateKey]))?.creationDate,
                   created < cutoff {
                    try? fm.removeItem(at: file)
                }
            }
        }
        return dir
    }

    // MARK: - Private helpers

    nonisolated private static func resize(_ image: NSImage, maxDimension: CGFloat) -> NSImage {
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
    nonisolated private static func pngData(from image: NSImage) -> Data? {
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return nil }
        let rep = NSBitmapImageRep(cgImage: cgImage)
        return rep.representation(using: .png, properties: [:])
    }

    /// Pure crypto — safe to call from any isolation (used by tests without MainActor).
    nonisolated static func sha256(_ data: Data) -> String {
        SHA256.hash(data: data)
            .map { String(format: "%02x", $0) }
            .joined()
    }

    nonisolated private static func writeToDisk(data: Data) -> URL? {
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

    nonisolated private static var imagesDirectory: URL {
        let support = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let dir = support.appendingPathComponent("cpMan/Images", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }
}
