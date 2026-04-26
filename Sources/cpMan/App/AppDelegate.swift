import AppKit
import KeyboardShortcuts
import os.log

private let logger = Logger(subsystem: "com.cpman.app", category: "AppDelegate")

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var pickerPanel: PickerPanel?

    func applicationDidFinishLaunching(_ notification: Notification) {
        logger.info("cpMan launching (version \(Bundle.main.shortVersion, privacy: .public))")
        NSApp.setActivationPolicy(.accessory)

        // ── Accessibility permission ──────────────────────────────────────────
        // prompt:true registers this binary in the TCC list (System Settings →
        // Privacy & Security → Accessibility) on every launch.  Without this call
        // the entry may not appear in the list at all, forcing the user to add it
        // manually with "+".  On macOS 13+ the call is often silent (no dialog box);
        // the picker banner then guides the user to flip the toggle.
        //
        // Unit tests use cpMan as TEST_HOST, so the full app launches for every test
        // run — `prompt: true` would spam the Accessibility dialog. Skip the prompt
        // in that process; `AccessibilityService` still reads trust with `prompt: false`.
        let isTestHost = NSClassFromString("XCTestCase") != nil
        let axPrompt = !isTestHost
        AXIsProcessTrustedWithOptions(["AXTrustedCheckOptionPrompt": axPrompt] as CFDictionary)
        if isTestHost {
            logger.debug("Test host: skipped Accessibility prompt on launch")
        }

        if AccessibilityService.shared.isGranted {
            logger.info("Accessibility permission: granted")
        } else {
            logger.info("Accessibility permission: not granted — picker banner will guide the user on first open")
        }

        // ── One-time hotkey migration ─────────────────────────────────────────
        // Clear stale ⇧⌘V shortcut saved by earlier builds so the new ⌃⌥V default applies.
        let oldShortcut = KeyboardShortcuts.Shortcut(.v, modifiers: [.shift, .command])
        if KeyboardShortcuts.getShortcut(for: .openPicker) == oldShortcut {
            KeyboardShortcuts.reset(.openPicker)
            logger.info("Migrated hotkey from ⇧⌘V to ⌃⌥V default")
        }

        pickerPanel = PickerPanel()
        ClipboardMonitor.shared.start()

        // If the app was quit while a timed Private Mode session was active,
        // the timer is lost — disable Private Mode so recording resumes.
        let settings = AppSettings.shared
        if settings.isPrivateModeEnabled && settings.lastPrivateModeDurationMinutes > 0 {
            settings.isPrivateModeEnabled = false
            logger.info("Private Mode was timed; reset to off after relaunch")
        }

        KeyboardShortcuts.onKeyUp(for: .openPicker) { [weak self] in
            Task { @MainActor in
                self?.togglePicker()
            }
        }

        logger.info("cpMan launched successfully")
    }

    func applicationWillTerminate(_ notification: Notification) {
        ClipboardMonitor.shared.stop()
        logger.info("cpMan terminating")
    }

    /// Called when the user closes Settings and focuses another app.
    /// Reverts the activation policy from .regular (needed while Settings was open)
    /// back to .accessory so cpMan disappears from the Dock again.
    func applicationDidResignActive(_ notification: Notification) {
        // Only revert if no ordinary (non-panel) window is still open.
        // NSPanel (the picker) is excluded so toggling the picker doesn't hide the Dock icon.
        let hasOpenWindow = NSApp.windows.contains {
            $0.isVisible && !($0 is NSPanel)
        }
        if !hasOpenWindow {
            NSApp.setActivationPolicy(.accessory)
            logger.debug("Reverted to .accessory policy (no visible windows)")
        }
    }

    func togglePicker() {
        pickerPanel?.toggle()
    }
}

// MARK: - Bundle helpers

private extension Bundle {
    var shortVersion: String {
        infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown"
    }
}
