import AppKit
import Carbon.HIToolbox
import os.log

private let logger = Logger(subsystem: "com.cpman.app", category: "ClipboardMonitor")

/// Polls `NSPasteboard.general` for new plain-text content and writes it into `HistoryStore`.
///
/// Capture rules:
///   • Only `NSPasteboard.PasteboardType.string` payloads are recorded.
///   • Whitespace-only strings are dropped.
///   • Finder-style file references (`fileURL` / `NSFilenamesPboardType`) are
///     dropped so the history never contains stale `file://` rows.
///   • Secure Event Input is honoured so the monitor never records the
///     pasteboard while the user is typing into a password field.
///     `IsSecureEventInputEnabled` is a Carbon API that requires no
///     entitlement and is safe to call from a sandboxed build.
@MainActor
final class ClipboardMonitor {
    static let shared = ClipboardMonitor()

    private var timer: Timer?
    private var lastChangeCount: Int = NSPasteboard.general.changeCount
    private let pollInterval: TimeInterval = 0.5

    private init() {}

    func start() {
        logger.info("Clipboard monitor started (poll interval: \(self.pollInterval)s)")
        timer = Timer.scheduledTimer(withTimeInterval: pollInterval, repeats: true) { _ in
            Task { @MainActor in
                ClipboardMonitor.shared.checkPasteboard()
            }
        }
    }

    /// Called after the picker writes the user's selection back to the pasteboard
    /// so the resulting change-count bump is not mistaken for a fresh user copy.
    func acknowledgeCurrentPasteboard() {
        lastChangeCount = NSPasteboard.general.changeCount
        logger.debug("ClipboardMonitor: acknowledged pasteboard change")
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        logger.info("Clipboard monitor stopped")
    }

    // MARK: - Core loop

    private func checkPasteboard() {
        let pasteboard = NSPasteboard.general
        guard pasteboard.changeCount != lastChangeCount else { return }
        lastChangeCount = pasteboard.changeCount

        if IsSecureEventInputEnabled() {
            logger.debug("Skipped clipboard read: Secure Event Input is active")
            return
        }

        let types = pasteboard.types ?? []
        if Self.shouldSkipForFileReferencePasteboardTypes(Array(types)) {
            logger.debug("Skipped file reference on pasteboard (Finder copy)")
            return
        }

        guard let text = pasteboard.string(forType: .string),
              !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            logger.debug("Pasteboard change had no plain-text content")
            return
        }

        let frontApp = NSWorkspace.shared.frontmostApplication
        let item = ClipboardItem(
            sourceApp: frontApp?.localizedName,
            sourceBundleId: frontApp?.bundleIdentifier,
            textValue: text
        )

        if Self.isDuplicateIncoming(item, latest: HistoryStore.shared.latestItem) {
            logger.debug("Skipped duplicate clipboard item")
            return
        }

        HistoryStore.shared.insert(item)
        logger.info("Captured text from \(item.sourceApp ?? "unknown")")
    }

    // MARK: - Predicates (unit-tested)

    /// Finder / file copies place a `fileURL` (or legacy `NSFilenamesPboardType`) on the
    /// pasteboard. Storing them as text would produce noisy `file://…` rows; skip instead.
    nonisolated static func shouldSkipForFileReferencePasteboardTypes(_ types: [NSPasteboard.PasteboardType]) -> Bool {
        types.contains(.fileURL) ||
            types.contains(NSPasteboard.PasteboardType("NSFilenamesPboardType"))
    }

    /// True when `incoming` is the same text as the most recent stored item.
    /// `HistoryStore.insert` performs its own duplicate check; this helper exists
    /// to keep the monitor's behaviour observable from tests.
    nonisolated static func isDuplicateIncoming(_ incoming: ClipboardItem, latest: ClipboardItem?) -> Bool {
        guard let latest else { return false }
        return incoming.textValue == latest.textValue
    }
}
