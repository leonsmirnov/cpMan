import AppKit
import SwiftUI

/// Drop-down menu content for the MenuBarExtra.
struct AppMenuView: View {
    let onOpenPicker: @MainActor () -> Void

    @Environment(\.openSettings) private var openSettings
    @EnvironmentObject private var settings: AppSettings

    var body: some View {
        Button("Open cpMan") {
            onOpenPicker()
        }

        Divider()

        if settings.isPrivateModeEnabled {
            Button("Disable Private Mode") {
                PrivateModeService.shared.disable()
            }
        } else {
            Menu("Enable Private Mode") {
                privateModeTimerButton(minutes: 15,  label: "15 Minutes")
                privateModeTimerButton(minutes: 30,  label: "30 Minutes")
                privateModeTimerButton(minutes: 60,  label: "1 Hour")
                privateModeTimerButton(minutes: 120, label: "2 Hours")
                Divider()
                privateModeTimerButton(minutes: 0,   label: "Until I Turn It Off")
            }
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

    @ViewBuilder
    private func privateModeTimerButton(minutes: Int, label: String) -> some View {
        let isSelected = settings.lastPrivateModeDurationMinutes == minutes
        Button {
            PrivateModeService.shared.enable(minutes: minutes)
        } label: {
            // Checkmark prefix on the last-used option so it reads as the default.
            Text(isSelected ? "✓  \(label)" : "    \(label)")
        }
    }
}
