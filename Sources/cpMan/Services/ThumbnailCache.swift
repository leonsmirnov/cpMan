import AppKit
import ImageIO

/// Single source of truth for thumbnail sizing. Any UI surface that displays a
/// cached thumbnail MUST pick its `maxPoints` value from here so the cache key
/// schema (and `evict(for:)`) stays consistent.
enum ThumbnailSize {
    /// Default row thumbnail in the picker.
    static let normal: CGFloat = 80
    /// Expanded ("chevron-open") thumbnail in the picker.
    static let expanded: CGFloat = 240

    /// Every point size the cache might be queried with. New UI surfaces that
    /// use a different size must add their constant here so eviction frees it.
    static let allPoints: [CGFloat] = [normal, expanded]

    /// Pixel size used in the cache key for a given point size (@2x for Retina).
    static func pixels(for points: CGFloat) -> Int {
        Int(points * 2)
    }
}

/// Memory-efficient thumbnail cache backed by NSCache.
/// Uses CGImageSource to decode only a downscaled version of each image,
/// avoiding the need to load full-resolution bitmaps for thumbnail display.
final class ThumbnailCache: @unchecked Sendable {
    static let shared = ThumbnailCache()

    private let cache = NSCache<NSString, NSImage>()

    private init() {
        cache.countLimit = 300
        cache.totalCostLimit = 60 * 1_024 * 1_024 // 60 MB
    }

    /// Returns a thumbnail for the image at `path`, sized to `maxPoints` on the
    /// longest side (@2x for Retina). Thread-safe; no main-actor requirement.
    func thumbnail(for path: String, maxPoints: CGFloat = ThumbnailSize.normal) -> NSImage? {
        let maxPixels = ThumbnailSize.pixels(for: maxPoints)
        let cacheKey = Self.cacheKey(path: path, pixels: maxPixels)

        if let cached = cache.object(forKey: cacheKey) { return cached }

        guard let (image, cost) = Self.decodeThumbnail(path: path, maxPixels: maxPixels)
        else { return nil }

        cache.setObject(image, forKey: cacheKey, cost: cost)
        return image
    }

    /// Call when an item is deleted so its cached thumbnails are freed promptly.
    /// Removes every variant declared in `ThumbnailSize.allPoints` so adding a
    /// new size requires only updating that single list.
    func evict(for path: String) {
        for points in ThumbnailSize.allPoints {
            let pixels = ThumbnailSize.pixels(for: points)
            cache.removeObject(forKey: Self.cacheKey(path: path, pixels: pixels))
        }
    }

    /// Clears the entire cache.
    func removeAll() {
        cache.removeAllObjects()
    }

    /// Returns a thumbnail asynchronously, offloading disk I/O to a background thread.
    /// Decoding returns `CGImage` from `Task.detached` (Sendable); `NSImage` is created
    /// on the main actor so `NSImage?` is not returned across a nonisolated async boundary
    /// (it is not `Sendable` under strict concurrency).
    @MainActor
    func thumbnailAsync(for path: String, maxPoints: CGFloat = ThumbnailSize.normal) async -> NSImage? {
        let maxPixels = ThumbnailSize.pixels(for: maxPoints)
        let cacheKey = Self.cacheKey(path: path, pixels: maxPixels)

        if let cached = cache.object(forKey: cacheKey) { return cached }

        let decoded: (CGImage, Int)? = await Task.detached(priority: .userInitiated) {
            Self.decodeThumbnailCGImage(path: path, maxPixels: maxPixels)
        }.value
        guard let (cg, cost) = decoded else { return nil }
        let image = NSImage(cgImage: cg, size: .zero)
        cache.setObject(image, forKey: cacheKey, cost: cost)
        return image
    }

    // MARK: - Private helpers

    private static func cacheKey(path: String, pixels: Int) -> NSString {
        "\(path):\(pixels)" as NSString
    }

    /// Decodes a downscaled bitmap with CGImageSource. Safe to call from any thread.
    /// `CGImage` is Sendable; use this inside `Task.detached`, then wrap in `NSImage`.
    private static func decodeThumbnailCGImage(path: String, maxPixels: Int) -> (CGImage, Int)? {
        let url = URL(fileURLWithPath: path) as CFURL
        let opts: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageIfAbsent: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixels,
            kCGImageSourceCreateThumbnailWithTransform: true,
        ]
        guard let source = CGImageSourceCreateWithURL(url, nil),
              let cgThumb = CGImageSourceCreateThumbnailAtIndex(source, 0, opts as CFDictionary)
        else { return nil }

        let cost = cgThumb.width * cgThumb.height * 4
        return (cgThumb, cost)
    }

    private static func decodeThumbnail(path: String, maxPixels: Int) -> (NSImage, Int)? {
        guard let (cg, cost) = decodeThumbnailCGImage(path: path, maxPixels: maxPixels) else { return nil }
        return (NSImage(cgImage: cg, size: .zero), cost)
    }
}
