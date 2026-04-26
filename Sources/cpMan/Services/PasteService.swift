import AppKit
import Carbon
import os.log

private let logger = Logger(subsystem: "com.cpman.app", category: "PasteService")

/// Writes a ClipboardItem back to NSPasteboard and simulates ⌘V in the target app via `CGEvent`.
///
/// Requires Accessibility permission for cross-process keystroke synthesis (`postToPid` /
/// session tap). cpMan does not send Apple Events to System Events or other apps for paste.
///
/// The reliable development workflow:
///   1. Build once (⌘B in Xcode).
///   2. The post-build script copies the app to /Applications/cpMan.app.
///   3. Launch from /Applications (Spotlight or Finder).
///   4. Grant Accessibility for that app — once per stable path.
///   5. Future builds overwrite the same /Applications copy; TCC keeps the grant.
@MainActor
final class PasteService {
    static let shared = PasteService()

    private init() {}

    // MARK: - Public API

    /// Writes the item to the clipboard and synthesises ⌘V into `targetApp`.
    /// `targetApp` must be captured BEFORE the picker panel closes.
    func paste(item: ClipboardItem, into targetApp: NSRunningApplication?) {
        let axGranted   = AccessibilityService.shared.isAccessibilityGranted
        let secureInput = AccessibilityService.shared.isSecureInputActive
        let targetName  = targetApp?.localizedName ?? "unknown"
        let targetPID   = targetApp?.processIdentifier

        NSLog("[cpMan] paste — AX:%@  secureInput:%@  target:%@  pid:%@",
              axGranted ? "✓" : "✗",
              secureInput ? "✓" : "✗",
              targetName,
              targetPID.map { "\($0)" } ?? "nil")

        guard !secureInput else {
            NSLog("[cpMan] paste BLOCKED — Secure Event Input active")
            logger.warning("Paste blocked: Secure Event Input active")
            return
        }

        writeToPasteboard(item: item)

        guard axGranted else {
            NSLog("[cpMan] paste BLOCKED — Accessibility not granted. Launch from /Applications and grant AX once.")
            logger.warning("Paste blocked: Accessibility not granted")
            return
        }

        // 300 ms lets the panel close animation finish and macOS complete the
        // window-focus handoff before the synthetic keystroke is delivered.
        let pid = targetPID
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            self?.synthesizeViaCGEvent(targetPID: pid)
        }
    }

    /// Pastes the item as plain text only — strips any rich formatting.
    /// For text items this is the same as paste (cpMan already stores plain text).
    /// For image items, pastes the OCR-extracted text if available.
    func pasteAsPlainText(item: ClipboardItem, into targetApp: NSRunningApplication?) {
        guard !AccessibilityService.shared.isSecureInputActive else { return }

        let plainText: String
        switch item.contentType {
        case .text:
            guard let text = item.textValue else { return }
            plainText = text
        case .image:
            guard let text = item.ocrText, !text.isEmpty else {
                logger.warning("pasteAsPlainText: no OCR text available for image item")
                return
            }
            plainText = text
        }

        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(plainText, forType: .string)
        ClipboardMonitor.shared.acknowledgeCurrentPasteboard()

        NSLog("[cpMan] pasteAsPlainText — AX:%@  target:%@",
              AccessibilityService.shared.isAccessibilityGranted ? "✓" : "✗",
              targetApp?.localizedName ?? "nil")

        guard AccessibilityService.shared.isAccessibilityGranted else { return }
        let pid = targetApp?.processIdentifier
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            self?.synthesizeViaCGEvent(targetPID: pid)
        }
    }

    /// Writes item to clipboard only — no ⌘V synthesis.
    func writeToPasteboardOnly(item: ClipboardItem) {
        writeToPasteboard(item: item)
        logger.debug("Wrote \(item.contentType.rawValue) to pasteboard (auto-paste disabled)")
    }

    /// Exports image as PNG file, places its URL on the pasteboard, then synthesises ⌘V.
    func pasteAsFile(item: ClipboardItem, into targetApp: NSRunningApplication?) {
        guard !AccessibilityService.shared.isSecureInputActive else { return }
        guard item.contentType == .image else { return }
        guard let exportURL = ImageProcessor.shared.exportAsFile(item: item) else {
            logger.error("pasteAsFile: export failed for item \(item.id)")
            return
        }
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.writeObjects([exportURL as NSURL])
        ClipboardMonitor.shared.acknowledgeCurrentPasteboard()

        guard AccessibilityService.shared.isAccessibilityGranted else { return }
        let pid = targetApp?.processIdentifier
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            self?.synthesizeViaCGEvent(targetPID: pid)
        }
    }

    // MARK: - Private: Pasteboard

    private func writeToPasteboard(item: ClipboardItem) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        switch item.contentType {
        case .text:
            if let text = item.textValue {
                pasteboard.setString(text, forType: .string)
            }
        case .image:
            if let path = item.imageFilePath,
               let image = NSImage(contentsOfFile: path) {
                pasteboard.writeObjects([image])
            }
        }
        ClipboardMonitor.shared.acknowledgeCurrentPasteboard()
    }

    // MARK: - Private: CGEvent synthesis

    /// Posts ⌘V directly to the target process.
    /// Uses postToPid when a PID is known so the event arrives even if the focus
    /// transition from the picker panel to the target app hasn't fully completed.
    private func synthesizeViaCGEvent(targetPID: pid_t?) {
        let src     = CGEventSource(stateID: .hidSystemState)
        let keyDown = CGEvent(keyboardEventSource: src, virtualKey: CGKeyCode(kVK_ANSI_V), keyDown: true)
        let keyUp   = CGEvent(keyboardEventSource: src, virtualKey: CGKeyCode(kVK_ANSI_V), keyDown: false)
        keyDown?.flags = .maskCommand
        keyUp?.flags   = .maskCommand

        if let pid = targetPID {
            keyDown?.postToPid(pid)
            keyUp?.postToPid(pid)
            NSLog("[cpMan] ⌘V via CGEvent → pid %d ✓", pid)
        } else {
            keyDown?.post(tap: .cgSessionEventTap)
            keyUp?.post(tap: .cgSessionEventTap)
            NSLog("[cpMan] ⌘V via CGEvent → session tap ✓")
        }
        logger.debug("Synthesised ⌘V via CGEvent")
    }
}
