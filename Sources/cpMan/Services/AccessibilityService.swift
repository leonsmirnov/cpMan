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

    /// Registers the app in the Accessibility list and opens System Settings so
    /// the user can toggle the switch on.
    ///
    /// Two steps are needed:
    /// 1. `AXIsProcessTrustedWithOptions(prompt: true)` — adds THIS binary to the
    ///    Accessibility list in System Settings. Without this call, cpMan might not
    ///    appear in the list at all (especially after an Xcode rebuild which changes
    ///    the binary's code signature).
    /// 2. Open the direct URL — lands the user on the exact pane so they only need
    ///    to find cpMan in the list and flip the toggle.
    ///
    /// Schedules rechecks so the banner auto-hides as soon as the user grants access.
    func openAccessibilitySettings() {
        // Step 1: register / prompt — ensures cpMan appears in the list
        let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        AXIsProcessTrustedWithOptions(options)

        // Step 2: open System Settings after a brief delay so step 1 can complete
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                NSWorkspace.shared.open(url)
            }
        }

        logger.info("Accessibility settings opened (prompt + URL)")

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
