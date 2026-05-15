import Foundation
import Combine
import os.log

private let logger = Logger(subsystem: "com.cpman.app", category: "HistoryStore")

/// In-memory list of recent text clips, persisted as JSON.
///
/// Hard contract for basic_version:
///   • Text only — non-string pasteboard contents are filtered upstream.
///   • Hard cap of `Self.maxItems` entries, newest-first.
///   • No user-configurable knobs (no size limits, no age limits, no pinning).
///   • Persisted to a single JSON file inside the sandbox container so the
///     history survives quit/restart but is fully scoped to the app.
@MainActor
final class HistoryStore: ObservableObject {
    static let shared = HistoryStore()

    /// Maximum number of clips kept in history. Anything beyond this cap is dropped
    /// from the oldest end immediately on insert. Not user-configurable in basic_version.
    static let maxItems = 100

    @Published private(set) var items: [ClipboardItem] = []

    private let storageURL: URL?

    // MARK: - Init

    /// Designated initializer used by the singleton. `storageURL: nil` means
    /// "in-memory only" and is the path used by tests via `makeForTesting()`.
    private init(storageURL: URL?) {
        self.storageURL = storageURL
        if let url = storageURL {
            items = Self.load(from: url)
        }
    }

    private convenience init() {
        self.init(storageURL: Self.defaultStorageURL())
    }

    /// Fresh in-memory store with no on-disk persistence. Production code must
    /// use `HistoryStore.shared`; this is only for unit tests.
    static func makeForTesting() -> HistoryStore {
        HistoryStore(storageURL: nil)
    }

    // MARK: - Write API

    /// Inserts a new item at the top of the list and trims to `maxItems`.
    /// Skips silently when the incoming text duplicates the most recent entry —
    /// this matches the dedupe contract the clipboard monitor relies on so that
    /// re-copying the same string does not push older items out of history.
    func insert(_ item: ClipboardItem) {
        if let latest = items.first, latest.textValue == item.textValue {
            logger.debug("HistoryStore.insert: dropping duplicate of top item")
            return
        }
        items.insert(item, at: 0)
        if items.count > Self.maxItems {
            items.removeLast(items.count - Self.maxItems)
        }
        persist()
    }

    /// Removes the entry with this id, if present. No-op when the id is unknown.
    func delete(id: UUID) {
        guard let idx = items.firstIndex(where: { $0.id == id }) else { return }
        items.remove(at: idx)
        persist()
    }

    /// Moves an item to the top of the list (MRU). Used after the user selects
    /// an item from the picker so the next open shows their most-recent choice
    /// at row 1. No-op when the id is unknown.
    func touch(id: UUID) {
        guard let idx = items.firstIndex(where: { $0.id == id }) else { return }
        var item = items.remove(at: idx)
        item = ClipboardItem(
            id: item.id,
            createdAt: Date(),
            sourceApp: item.sourceApp,
            sourceBundleId: item.sourceBundleId,
            textValue: item.textValue
        )
        items.insert(item, at: 0)
        persist()
    }

    // MARK: - Read API

    /// Returns items matching `query` (case- and diacritic-insensitive), newest first.
    /// Empty query returns every item.
    func all(matching query: String = "") -> [ClipboardItem] {
        guard !query.isEmpty else { return items }
        return items.filter { $0.textValue.localizedStandardContains(query) }
    }

    /// O(1) accessor for the single most recent item — used by the monitor's
    /// duplicate-skip logic before allocating a new entry.
    var latestItem: ClipboardItem? { items.first }

    /// Resolves an id to the live snapshot. Returns nil for unknown / deleted ids.
    func item(for id: UUID) -> ClipboardItem? {
        items.first { $0.id == id }
    }

    // MARK: - Persistence

    private func persist() {
        guard let url = storageURL else { return }
        do {
            let data = try Self.encoder.encode(items)
            try data.write(to: url, options: [.atomic])
        } catch {
            logger.error("HistoryStore persist failed: \(error)")
        }
    }

    private static func load(from url: URL) -> [ClipboardItem] {
        guard FileManager.default.fileExists(atPath: url.path) else { return [] }
        do {
            let data = try Data(contentsOf: url)
            let decoded = try decoder.decode([ClipboardItem].self, from: data)
            if decoded.count > maxItems {
                return Array(decoded.prefix(maxItems))
            }
            return decoded
        } catch {
            // A corrupt file from an earlier schema must not crash the app —
            // basic_version is intentionally permissive: start with an empty
            // history and overwrite the file on the next insert.
            logger.error("HistoryStore load failed (using empty history): \(error)")
            return []
        }
    }

    private static func defaultStorageURL() -> URL? {
        let fm = FileManager.default
        guard let support = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            return nil
        }
        let dir = support.appendingPathComponent("cpMan", isDirectory: true)
        try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("history.json", isDirectory: false)
    }

    private static let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        return e
    }()

    private static let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()
}
