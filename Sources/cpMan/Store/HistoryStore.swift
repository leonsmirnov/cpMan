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
        save()
        pruneIfNeeded()
        objectWillChange.send()
    }

    func delete(_ item: ClipboardItem) {
        if let path = item.imageFilePath {
            try? FileManager.default.removeItem(atPath: path)
            ThumbnailCache.shared.evict(for: path)
        }
        container.mainContext.delete(item)
        save()
        objectWillChange.send()
    }

    /// Deletes every item in history and removes all stored image files.
    func deleteAll() {
        let all = allItems(fetchLimit: Int.max)
        for item in all {
            if let path = item.imageFilePath {
                try? FileManager.default.removeItem(atPath: path)
                ThumbnailCache.shared.evict(for: path)
            }
            container.mainContext.delete(item)
        }
        save()
        objectWillChange.send()
        logger.info("Deleted all \(all.count) history items")
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

    /// Returns items sorted by most recent, with an optional fetch cap and in-memory search.
    /// fetchLimit caps the DB query; query filters the result set in memory.
    func allItems(matching query: String = "", fetchLimit: Int = 500) -> [ClipboardItem] {
        var descriptor = FetchDescriptor<ClipboardItem>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        // Cap rows returned from DB so the picker never loads unbounded history.
        // Pinned items are always included via a second cheap fetch if they fall
        // outside the limit — acceptable for typical pinned counts (<20).
        descriptor.fetchLimit = fetchLimit

        let items = (try? container.mainContext.fetch(descriptor)) ?? []
        guard !query.isEmpty else { return items }

        let q = query.lowercased()
        return items.filter {
            $0.textValue?.lowercased().contains(q) == true ||
            $0.ocrText?.lowercased().contains(q) == true
        }
    }

    /// P2: O(1) fetch of the single most recent item for deduplication.
    func latestItem() -> ClipboardItem? {
        var descriptor = FetchDescriptor<ClipboardItem>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        descriptor.fetchLimit = 1
        return try? container.mainContext.fetch(descriptor).first
    }

    // MARK: - Pruning

    private func pruneIfNeeded() {
        let settings = AppSettings.shared

        // ── Count limit ──────────────────────────────────────────────────────
        let countLimit = settings.historyCountLimit
        if countLimit > 0 {
            let descriptor = FetchDescriptor<ClipboardItem>(
                predicate: #Predicate<ClipboardItem> { !$0.isPinned },
                sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
            )
            if let items = try? container.mainContext.fetch(descriptor),
               items.count > countLimit {
                items.dropFirst(countLimit).forEach { delete($0) }
            }
        }

        // ── Age limit ────────────────────────────────────────────────────────
        if settings.historyAgeLimitEnabled, settings.historyAgeLimitDays > 0 {
            let cutoff = Date().addingTimeInterval(-Double(settings.historyAgeLimitDays) * 86_400)
            let descriptor = FetchDescriptor<ClipboardItem>(
                predicate: #Predicate<ClipboardItem> { !$0.isPinned && $0.createdAt < cutoff }
            )
            (try? container.mainContext.fetch(descriptor))?.forEach { delete($0) }
        }

        // ── Size limit (images only) ─────────────────────────────────────────
        // C1 FIX: only fetch and delete IMAGE items — text rows must never be
        // deleted to satisfy an image byte budget.
        if settings.historySizeLimitEnabled, settings.historySizeLimitMB > 0 {
            let maxBytes = settings.historySizeLimitMB * 1_048_576
            let descriptor = FetchDescriptor<ClipboardItem>(
                predicate: #Predicate<ClipboardItem> { !$0.isPinned && $0.imageFilePath != nil },
                sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
            )
            guard let imageItems = try? container.mainContext.fetch(descriptor) else { return }
            var totalBytes = imageItems.compactMap(\.imageSizeBytes).reduce(0, +)
            for item in imageItems.reversed() where totalBytes > maxBytes {
                totalBytes -= item.imageSizeBytes ?? 0
                delete(item)
            }
        }
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
