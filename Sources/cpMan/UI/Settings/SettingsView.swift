import SwiftUI

struct SettingsView: View {
    private enum Tab: Hashable {
        case general, history, images, ignoreList, hotkeys
    }

    @State private var selection: Tab = .general

    var body: some View {
        TabView(selection: $selection) {
            GeneralSettingsView()
                .tabItem { Label("General", systemImage: "gearshape") }
                .tag(Tab.general)

            HistorySettingsView()
                .tabItem { Label("History", systemImage: "clock") }
                .tag(Tab.history)

            ImagesSettingsView()
                .tabItem { Label("Images", systemImage: "photo") }
                .tag(Tab.images)

            IgnoreListSettingsView()
                .tabItem { Label("Ignore List", systemImage: "nosign") }
                .tag(Tab.ignoreList)

            HotkeysSettingsView()
                .tabItem { Label("Hotkeys", systemImage: "keyboard") }
                .tag(Tab.hotkeys)
        }
        .frame(width: 520, height: 380)
        .environmentObject(AppSettings.shared)
        // Always reopen on the General tab: reset selection when the Settings
        // window closes so the next open starts fresh instead of restoring the
        // last-viewed tab.
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.willCloseNotification)) { _ in
            selection = .general
        }
    }
}
