import AppKit
import ApplicationServices
import Carbon.HIToolbox
import os.log

private let logger = Logger(subsystem: "com.cpman.app", category: "Accessibility")

/// Wraps macOS Accessibility (AX) and Secure Event Input APIs.
///
/// `@Published isGranted` is polled every second so SwiftUI views react
/// without requiring an app restart after the user grants permission in System Settings.
///
/// After the user clicks "Enable Access", additional rechecks are scheduled at 1 s, 2 s,
/// and 5 s to cover the window where the user opens System Settings and flips the toggle.
/// The service also rechecks immediately when System Settings becomes active — that is
/// the moment the user is most likely about to grant permission.
@MainActor
final class AccessibilityService: ObservableObject {
    static let shared = AccessibilityService()

    @Published private(set) var isGranted: Bool = false

    private var pollTimer: Timer?
    private var workspaceObserver: Any?

    private init() {
        isGranted = AXIsProcessTrusted()
        startPolling()
        observeAppSwitches()
    }

    // MARK: - Public API

    /// Latest AX trust value (updated every second by the polling timer).
    var isAccessibilityGranted: Bool { isGranted }

    /// True while a Secure Event Input app (e.g. a password field) has focus.
    var isSecureInputActive: Bool { IsSecureEventInputEnabled() }

    /// Opens **System Settings → Privacy & Security → Accessibility** for the user.
    ///
    /// We intentionally do **not** call `AXIsProcessTrustedWithOptions(prompt: true)` here:
    /// that API shows the legacy “Accessibility” / “Accessibility Access” dialog, and we
    /// were *also* opening System Settings — so users saw two competing windows. Launch
    /// already runs a trust check in `AppDelegate` to register this build with TCC; for
    /// in-app “Open Settings” we only deep-link once.
    ///
    /// Schedules rechecks so the banner auto-hides as soon as the user grants access.
    func openAccessibilitySettings() {
        AXIsProcessTrustedWithOptions(["AXTrustedCheckOptionPrompt": false] as CFDictionary)

        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }

        logger.info("Opened System Settings → Accessibility (single window, no AX prompt)")

        // Rechecks at 2 s / 4 s / 8 s / 15 s cover the time the user spends in
        // System Settings toggling the switch and switching back to cpMan.
        for delay in [2.0, 4.0, 8.0, 15.0] {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                AccessibilityService.shared.refreshStatus()
            }
        }
    }

    /// Opens the AX prompt (adds app to the list). On macOS 13+ the user still
    /// needs to manually toggle the switch — prefer openAccessibilitySettings().
    func requestAccess() {
        let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        AXIsProcessTrustedWithOptions(options)
        logger.info("AX permission prompt presented via AXIsProcessTrustedWithOptions")
    }

    /// Forces an immediate re-evaluation of `AXIsProcessTrusted()`.
    /// Call after returning from System Settings for instant banner update.
    func refreshStatus() {
        let current = AXIsProcessTrusted()
        guard isGranted != current else { return }
        isGranted = current
        logger.info("Accessibility permission updated to: \(current)")
    }

    // MARK: - Private

    private func startPolling() {
        // 1-second poll keeps the banner in sync at steady state.
        pollTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            MainActor.assumeIsolated {
                AccessibilityService.shared.refreshStatus()
            }
        }
    }

    /// Listens for app-activation switches so we can recheck the moment the user
    /// returns from System Settings (they activated System Settings to grant access,
    /// then click back — at that point the grant is already committed).
    private func observeAppSwitches() {
        workspaceObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { notification in
            // Recheck when the user switches AWAY from System Settings back to any app,
            // because that's the moment the permission toggle is already saved.
            if let info = notification.userInfo,
               let app = info[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
               app.bundleIdentifier == "com.apple.systempreferences" {
                // System Settings became active — user is in the process of granting.
                // Schedule a check shortly after they leave.
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    AccessibilityService.shared.refreshStatus()
                }
            } else {
                // Any other app became active (including cpMan returning to focus).
                // Do a quick check in case the user just left System Settings.
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    AccessibilityService.shared.refreshStatus()
                }
            }
        }
    }
}
