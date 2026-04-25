import Foundation
import SwiftData
import os.log

private let logger = Logger(subsystem: "com.cpman.app", category: "HistoryStore")

/// Persistent clipboard history store backed by SwiftData.
/// All access must happen on the main actor (SwiftData main context requirement).
@MainActor
final class HistoryStore: ObservableObject {
    static let shared = HistoryStore()

    let container: ModelContainer

    // MARK: - Init (C4: graceful migration fallback instead of fatalError)

    private init(inMemory: Bool = false) {
        let schema = Schema([ClipboardItem.self])
        do {
            let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: inMemory)
            container = try ModelContainer(for: schema, configurations: [config])
        } catch {
            // Persistent store failed (schema migration after an update is the most
            // common cause). Fall back to in-memory so the app stays usable.
            // Data from this session will not be persisted.
            logger.error("Persistent container failed, using in-memory fallback: \(error)")
            let fallback = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
            container = try! ModelContainer(for: schema, configurations: [fallback])
        }
    }

    /// Returns a fresh in-memory store for unit tests.
    /// Never use in production code — access `HistoryStore.shared` instead.
    @MainActor
    static func makeForTesting() -> HistoryStore {
        HistoryStore(inMemory: true)
    }

    // MARK: - Write

    func insert(_ item: ClipboardItem) {
        container.mainContext.insert(item)
        // pruneIfNeeded() mutates the context but does NOT save/notify — we do
        // that once at the end so insert + prune is a single save + a single
        // objectWillChange notification, regardless of how many rows were pruned.
        _ = pruneIfNeeded()
        save()
        objectWillChange.send()
    }

    func delete(_ item: ClipboardItem) {
        removeItem(item)
        save()
        objectWillChange.send()
    }

    /// Deletes every item in history and removes all stored image files.
    func deleteAll() {
        // 1. Delete all images by wiping the directory
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let dir = support.appendingPathComponent("cpMan/Images", isDirectory: true)
        try? FileManager.default.removeItem(at: dir)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        
        // 2. Clear all thumbnails from memory
        ThumbnailCache.shared.removeAll()
        
        // 3. Batch delete all SwiftData rows (O(1) memory)
        try? container.mainContext.delete(model: ClipboardItem.self)
        
        save()
        objectWillChange.send()
        logger.info("Deleted all history items")
    }

    func updateOCR(forId id: UUID, text: String) {
        let descriptor = FetchDescriptor<ClipboardItem>(
            predicate: #Predicate<ClipboardItem> { $0.id == id }
        )
        guard let item = try? container.mainContext.fetch(descriptor).first else { return }
        item.ocrText = text
        save()
        objectWillChange.send()
    }

    func togglePin(_ item: ClipboardItem) {
        item.isPinned.toggle()
        save()
        objectWillChange.send()
    }

    /// Moves an item to the top of the history list (MRU behaviour).
    /// Called when the user selects an item from the picker so the most recently
    /// used item always appears first on the next open.
    func touch(_ item: ClipboardItem) {
        item.createdAt = Date()
        save()
        objectWillChange.send()
        logger.debug("Touched item \(item.id) — moved to top of history")
    }

    // MARK: - Read

    /// Returns items sorted by most recent, with an optional fetch cap.
    /// Search filtering is pushed to SwiftData for O(1) memory and full-table scope.
    func allItems(matching query: String = "", fetchLimit: Int = 500) -> [ClipboardItem] {
        var descriptor: FetchDescriptor<ClipboardItem>
        if query.isEmpty {
            descriptor = FetchDescriptor<ClipboardItem>(
                sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
            )
        } else {
            descriptor = FetchDescriptor<ClipboardItem>(
                predicate: #Predicate<ClipboardItem> {
                    ($0.textValue?.localizedStandardContains(query) ?? false) ||
                    ($0.ocrText?.localizedStandardContains(query) ?? false)
                },
                sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
            )
        }
        descriptor.fetchLimit = fetchLimit
        return (try? container.mainContext.fetch(descriptor)) ?? []
    }

    /// P2: O(1) fetch of the single most recent item for deduplication.
    func latestItem() -> ClipboardItem? {
        var descriptor = FetchDescriptor<ClipboardItem>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        descriptor.fetchLimit = 1
        return try? container.mainContext.fetch(descriptor).first
    }

    /// O(1) count of all items.
    func totalCount() -> Int {
        (try? container.mainContext.fetchCount(FetchDescriptor<ClipboardItem>())) ?? 0
    }

    // MARK: - Pruning

    /// Mutates the context to satisfy count/age/size limits. Does NOT save and
    /// does NOT call `objectWillChange.send()` — the caller is responsible for
    /// doing that exactly once after pruning, so insert + prune is a single
    /// save + a single notification regardless of how many rows were removed.
    /// Returns `true` if anything was removed.
    @discardableResult
    private func pruneIfNeeded() -> Bool {
        let settings = AppSettings.shared
        var didPrune = false

        // ── Count limit ──────────────────────────────────────────────────────
        let countLimit = settings.historyCountLimit
        if countLimit > 0 {
            let countDescriptor = FetchDescriptor<ClipboardItem>(
                predicate: #Predicate<ClipboardItem> { !$0.isPinned }
            )
            let unpinnedCount = (try? container.mainContext.fetchCount(countDescriptor)) ?? 0
            let buffer = min(100, countLimit / 10)

            if unpinnedCount > countLimit + buffer {
                let excessCount = unpinnedCount - countLimit
                var descriptor = FetchDescriptor<ClipboardItem>(
                    predicate: #Predicate<ClipboardItem> { !$0.isPinned },
                    sortBy: [SortDescriptor(\.createdAt, order: .forward)] // oldest first
                )
                descriptor.fetchLimit = excessCount
                if let excess = try? container.mainContext.fetch(descriptor) {
                    excess.forEach { removeItem($0) }
                    didPrune = true
                }
            }
        }

        // ── Age limit ────────────────────────────────────────────────────────
        if settings.historyAgeLimitEnabled, settings.historyAgeLimitDays > 0 {
            let cutoff = Date().addingTimeInterval(-Double(settings.historyAgeLimitDays) * 86_400)
            let descriptor = FetchDescriptor<ClipboardItem>(
                predicate: #Predicate<ClipboardItem> { !$0.isPinned && $0.createdAt < cutoff }
            )
            if let expired = try? container.mainContext.fetch(descriptor), !expired.isEmpty {
                expired.forEach { removeItem($0) }
                didPrune = true
            }
        }

        // ── Size limit (images only) ─────────────────────────────────────────
        // Only fetch and delete IMAGE items — text rows must never be
        // deleted to satisfy an image byte budget.
        if settings.historySizeLimitEnabled, settings.historySizeLimitMB > 0 {
            let maxBytes = settings.historySizeLimitMB * 1_048_576
            let descriptor = FetchDescriptor<ClipboardItem>(
                predicate: #Predicate<ClipboardItem> { !$0.isPinned && $0.imageFilePath != nil },
                sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
            )
            guard let imageItems = try? container.mainContext.fetch(descriptor) else { return didPrune }
            var totalBytes = imageItems.compactMap(\.imageSizeBytes).reduce(0, +)
            for item in imageItems.reversed() where totalBytes > maxBytes {
                totalBytes -= item.imageSizeBytes ?? 0
                removeItem(item)
                didPrune = true
            }
        }

        return didPrune
    }

    // MARK: - Private: item removal without save/notify

    /// Removes an item from the context and cleans up its image file, but does
    /// NOT call save() or objectWillChange.send(). Use this inside batch
    /// operations (pruning, deleteAll) to avoid redundant disk writes and UI
    /// refreshes. Callers are responsible for calling save() + objectWillChange
    /// once after all removals are complete.
    private func removeItem(_ item: ClipboardItem) {
        if let path = item.imageFilePath {
            try? FileManager.default.removeItem(atPath: path)
            ThumbnailCache.shared.evict(for: path)
        }
        container.mainContext.delete(item)
    }

    // MARK: - Helpers

    // SIM2: log save errors instead of silently swallowing them
    private func save() {
        do {
            try container.mainContext.save()
        } catch {
            logger.error("HistoryStore save failed: \(error)")
        }
    }
}
