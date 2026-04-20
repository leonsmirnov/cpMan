import AppKit
import ImageIO

/// Memory-efficient thumbnail cache backed by NSCache.
/// Uses CGImageSource to decode only a downscaled version of each image,
/// avoiding the need to load full-resolution bitmaps for thumbnail display.
@MainActor
final class ThumbnailCache {
    static let shared = ThumbnailCache()

    private let cache = NSCache<NSString, NSImage>()

    private init() {
        cache.countLimit = 300
        cache.totalCostLimit = 60 * 1_024 * 1_024 // 60 MB
    }

    /// Returns a thumbnail for the image at `path`, sized to `maxPixels` on the
    /// longest side (@2x for Retina). Thread-safe; no main-actor requirement.
    func thumbnail(for path: String, maxPoints: CGFloat = 80) -> NSImage? {
        let maxPixels = Int(maxPoints * 2) // @2x
        let cacheKey = "\(path):\(maxPixels)" as NSString

        if let cached = cache.object(forKey: cacheKey) { return cached }

        let url = URL(fileURLWithPath: path) as CFURL
        let opts: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageIfAbsent: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixels,
            kCGImageSourceCreateThumbnailWithTransform: true,
        ]
        guard let source = CGImageSourceCreateWithURL(url, nil),
              let cgThumb = CGImageSourceCreateThumbnailAtIndex(source, 0, opts as CFDictionary)
        else { return nil }

        let image = NSImage(cgImage: cgThumb, size: .zero)
        let cost = cgThumb.width * cgThumb.height * 4
        cache.setObject(image, forKey: cacheKey, cost: cost)
        return image
    }

    /// Call when an item is deleted so its cached thumbnails are freed promptly.
    func evict(for path: String) {
        cache.removeObject(forKey: "\(path):160" as NSString)
    }
}
