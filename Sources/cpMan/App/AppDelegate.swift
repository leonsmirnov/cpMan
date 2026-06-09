import AppKit
import KeyboardShortcuts
import os.log

private let logger = Logger(subsystem: "com.cpman.app", category: "AppDelegate")

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var pickerPanel: PickerPanel?

    /// Menu-bar-only agent: no Dock tile, no ⌘Tab entry. `LSUIElement` in Info.plist
    /// reinforces this; we still set policy in code so nothing can promote us to `.regular`.
    private func enforceMenuBarOnlyActivationPolicy() {
        if NSApp.setActivationPolicy(.accessory) {
            logger.debug("Activation policy: accessory (menu bar only)")
        } else {
            logger.warning("Failed to set activation policy to .accessory")
        }
    }

    func applicationWillFinishLaunching(_ notification: Notification) {
        enforceMenuBarOnlyActivationPolicy()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        logger.info("cpMan launching (version \(Bundle.main.shortVersion, privacy: .public))")
        enforceMenuBarOnlyActivationPolicy()

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

        // NOTE: We intentionally do NOT mutate the user's saved hotkey on launch.
        // KeyboardShortcuts persists the user's choice in UserDefaults; the ⌃⌥V
        // default (see KeyboardShortcuts+Names) already applies automatically when
        // nothing is saved. A previous "migration" here reset the shortcut whenever
        // it equalled ⇧⌘V, which silently wiped that (perfectly valid) user choice
        // on every relaunch — making the hotkey appear non-persistent.

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

    func applicationDidBecomeActive(_ notification: Notification) {
        // SwiftUI Settings or other APIs can sometimes move the process toward a regular
        // app presentation; keep forcing `.accessory` so we never get a Dock icon.
        enforceMenuBarOnlyActivationPolicy()
    }

    func applicationWillTerminate(_ notification: Notification) {
        ClipboardMonitor.shared.stop()
        logger.info("cpMan terminating")
    }

    /// Called when the user closes Settings and focuses another app.
    /// Normalizes activation policy to `.accessory` so cpMan stays out of the Dock.
    func applicationDidResignActive(_ notification: Notification) {
        // Only revert if no ordinary (non-panel) window is still open.
        // NSPanel (the picker) is excluded so toggling the picker doesn't flip policy.
        let hasOpenWindow = NSApp.windows.contains {
            $0.isVisible && !($0 is NSPanel)
        }
        if !hasOpenWindow {
            enforceMenuBarOnlyActivationPolicy()
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
