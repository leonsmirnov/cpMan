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

        // ── One-time hotkey migration ─────────────────────────────────────────
        // Clear stale ⇧⌘V shortcut saved by earlier builds so the new ⌃⌥V default applies.
        let oldShortcut = KeyboardShortcuts.Shortcut(.v, modifiers: [.shift, .command])
        if KeyboardShortcuts.getShortcut(for: .openPicker) == oldShortcut {
            KeyboardShortcuts.reset(.openPicker)
            logger.info("Migrated hotkey from ⇧⌘V to ⌃⌥V default")
        }

        pickerPanel = PickerPanel()
        DemoMode.applyOnLaunch(to: HistoryStore.shared)
        ClipboardMonitor.shared.start()

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
