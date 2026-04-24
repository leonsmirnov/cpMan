import AppKit
import os.log

private let logger = Logger(subsystem: "com.cpman.app", category: "ClipboardMonitor")

/// Polls NSPasteboard.general every 500ms and emits new ClipboardItems to HistoryStore.
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
                await ClipboardMonitor.shared.checkPasteboard()
            }
        }
    }

    /// Called by PasteService after writing to the pasteboard so the monitor
    /// does not re-capture cpMan's own paste action as a new clipboard event.
    func acknowledgeCurrentPasteboard() {
        lastChangeCount = NSPasteboard.general.changeCount
        logger.debug("ClipboardMonitor: acknowledged pasteboard change from paste")
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        logger.info("Clipboard monitor stopped")
    }

    private func checkPasteboard() async {
        let pasteboard = NSPasteboard.general
        guard pasteboard.changeCount != lastChangeCount else { return }
        lastChangeCount = pasteboard.changeCount

        let frontApp = NSWorkspace.shared.frontmostApplication
        let frontBundle = frontApp?.bundleIdentifier
        if !Self.shouldRecordClipboard(
            secureInputActive: AccessibilityService.shared.isSecureInputActive,
            privateModeEnabled: AppSettings.shared.isPrivateModeEnabled,
            frontmostBundleId: frontBundle,
            ignoredBundleIds: AppSettings.shared.ignoredBundleIds
        ) {
            if AccessibilityService.shared.isSecureInputActive {
                logger.debug("Skipped clipboard read: Secure Event Input is active")
            } else if AppSettings.shared.isPrivateModeEnabled {
                logger.debug("Skipped clipboard read: Private Mode is active")
            } else if let bundleId = frontBundle, IgnoreListService.shared.isIgnored(bundleId: bundleId) {
                logger.debug("Skipped clipboard read: \(bundleId) is in ignore list")
            }
            return
        }

        guard let item = await readItem(from: pasteboard, sourceApp: frontApp) else {
            logger.debug("Pasteboard change contained no supported content (text/image)")
            return
        }

        if Self.isDuplicateIncoming(item, latest: HistoryStore.shared.latestItem()) {
            logger.debug("Skipped duplicate clipboard item")
            return
        }

        HistoryStore.shared.insert(item)
        logger.info("Captured \(item.contentType.rawValue) from \(item.sourceApp ?? "unknown")")

        if AppSettings.shared.ocrEnabled,
           item.contentType == .image,
           let path = item.imageFilePath {
            let itemId = item.id
            Task {
                logger.debug("Scheduling OCR for item \(itemId)")
                await OCRService.shared.processImage(itemId: itemId, imagePath: path)
            }
        }
    }

    private func readItem(
        from pasteboard: NSPasteboard,
        sourceApp: NSRunningApplication?
    ) async -> ClipboardItem? {
        let appName  = sourceApp?.localizedName
        let bundleId = sourceApp?.bundleIdentifier

        // Skip file references (files copied in Finder via ⌘C).
        // File URLs are ephemeral — the file can move or be deleted, making the
        // stored reference useless. Pasting a raw file:// URL also produces the
        // broken "generic file" icon seen in many apps.
        let types = pasteboard.types ?? []
        if Self.shouldSkipForFileReferencePasteboardTypes(Array(types)) {
            logger.debug("Skipped file reference on pasteboard (Finder copy)")
            return nil
        }

        // Images take priority over text (apps often write both representations)
        if let image = NSImage(pasteboard: pasteboard) {
            return await ImageProcessor.shared.processCapture(
                image: image,
                sourceApp: appName,
                sourceBundleId: bundleId
            )
        }

        if let text = pasteboard.string(forType: .string),
           !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return ClipboardItem(
                sourceApp: appName,
                sourceBundleId: bundleId,
                contentType: .text,
                textValue: text
            )
        }

        return nil
    }

    // MARK: - Predicates (shared with unit tests)

    /// Finder / file copies — storing these as text produces broken history rows.
    nonisolated static func shouldSkipForFileReferencePasteboardTypes(_ types: [NSPasteboard.PasteboardType]) -> Bool {
        types.contains(.fileURL) ||
            types.contains(NSPasteboard.PasteboardType("NSFilenamesPboardType"))
    }

    /// Mirrors the guards in `checkPasteboard` before reading pasteboard contents.
    nonisolated static func shouldRecordClipboard(
        secureInputActive: Bool,
        privateModeEnabled: Bool,
        frontmostBundleId: String?,
        ignoredBundleIds: [String]
    ) -> Bool {
        if secureInputActive { return false }
        if privateModeEnabled { return false }
        if let bid = frontmostBundleId, ignoredBundleIds.contains(bid) { return false }
        return true
    }

    /// Same dedupe rule as production before `HistoryStore.insert`.
    nonisolated static func isDuplicateIncoming(_ incoming: ClipboardItem, latest: ClipboardItem?) -> Bool {
        guard let latest else { return false }
        switch incoming.contentType {
        case .text:
            return incoming.textValue == latest.textValue
        case .image:
            guard let h1 = incoming.imageHash, let h2 = latest.imageHash else { return false }
            return h1 == h2
        }
    }
}
