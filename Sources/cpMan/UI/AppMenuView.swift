import AppKit
import SwiftUI

/// Drop-down menu content for the menu-bar item.
///
/// basic_version keeps this menu intentionally tiny: open the picker, jump to
/// Settings, or quit. Anything more is reserved for the full master-branch build.
struct AppMenuView: View {
    let onOpenPicker: @MainActor () -> Void

    @Environment(\.openSettings) private var openSettings

    var body: some View {
        Button("Open cpMan") {
            onOpenPicker()
        }

        Divider()

        Button("Settings…") {
            // Keep `.accessory` activation policy (see AppDelegate) so cpMan never
            // appears in the Dock. Opening Settings only needs a focused app, not `.regular`.
            NSApp.activate(ignoringOtherApps: true)
            openSettings()
        }

        Divider()

        Button("Quit cpMan") {
            NSApplication.shared.terminate(nil)
        }
    }
}
