import SwiftUI

struct SettingsView: View {
    var body: some View {
        TabView {
            GeneralSettingsView()
                .tabItem { Label("General", systemImage: "gearshape") }

            HistorySettingsView()
                .tabItem { Label("History", systemImage: "clock") }

            ImagesSettingsView()
                .tabItem { Label("Images", systemImage: "photo") }

            IgnoreListSettingsView()
                .tabItem { Label("Ignore List", systemImage: "nosign") }

            HotkeysSettingsView()
                .tabItem { Label("Hotkeys", systemImage: "keyboard") }
        }
        .frame(width: 520, height: 380)
        .environmentObject(AppSettings.shared)
    }
}
