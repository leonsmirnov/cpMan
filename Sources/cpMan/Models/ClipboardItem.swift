import Foundation

/// One captured plain-text clipboard event.
///
/// Persisted as JSON by `HistoryStore`, which keeps the file capped at
/// `HistoryStore.maxItems` entries with no user-facing knobs.
struct ClipboardItem: Identifiable, Codable, Equatable, Hashable {
    let id: UUID
    let createdAt: Date

    /// Display name of the app the user copied from (e.g. "Safari").
    /// Nil when the frontmost app could not be resolved at capture time.
    let sourceApp: String?

    /// Bundle identifier of the source app, captured for diagnostics only.
    let sourceBundleId: String?

    /// Raw clipboard text. Never empty / whitespace-only — the monitor filters those out.
    let textValue: String

    init(
        id: UUID = UUID(),
        createdAt: Date = Date(),
        sourceApp: String? = nil,
        sourceBundleId: String? = nil,
        textValue: String
    ) {
        self.id = id
        self.createdAt = createdAt
        self.sourceApp = sourceApp
        self.sourceBundleId = sourceBundleId
        self.textValue = textValue
    }
}
