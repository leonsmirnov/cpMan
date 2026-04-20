import SwiftUI

@main
struct cpManApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @ObservedObject private var settings = AppSettings.shared

    var body: some Scene {
        MenuBarExtra {
            AppMenuView(onOpenPicker: { appDelegate.togglePicker() })
                .environmentObject(AppSettings.shared)
        } label: {
            if settings.isPrivateModeEnabled {
                Image(systemName: "lock.fill")
            } else {
                Image(systemName: "doc.on.clipboard")
                    .renderingMode(.template)
            }
        }
        .menuBarExtraStyle(.menu)

        Settings {
            SettingsView()
                .environmentObject(AppSettings.shared)
                .environmentObject(AccessibilityService.shared)
                .environmentObject(HistoryStore.shared)
        }
    }
}
