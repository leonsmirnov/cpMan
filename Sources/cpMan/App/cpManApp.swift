import SwiftUI

@main
struct cpManApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        MenuBarExtra {
            AppMenuView(onOpenPicker: { appDelegate.togglePicker() })
        } label: {
            Image(systemName: "doc.on.clipboard")
                .renderingMode(.template)
        }
        .menuBarExtraStyle(.menu)

        Settings {
            SettingsView()
        }
    }
}
