import SwiftUI

/// Single-screen Settings window. Exposes the picker hotkey recorder and a
/// read-only version row.
struct SettingsView: View {
    @ObservedObject private var store = HistoryStore.shared
    @AppStorage(DemoMode.activeUserDefaultsKey) private var demoModeActive = false

    var body: some View {
        Form {
            if demoModeActive {
                Section {
                    Text("Sample clipboard clips are loaded so you can explore cpMan without copying from other apps. Copy your own text anytime; real clips mix with the samples.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                    Button("Clear demo content") {
                        DemoMode.clearDemoContent(in: store)
                    }
                    Button("Reload demo content") {
                        DemoMode.reloadDemoContent(in: store)
                    }
                } header: {
                    Text("Demo content")
                }
            }

            Section {
                HotkeyRow()
            } header: {
                Text("Shortcut")
            } footer: {
                Text("Press the recorded shortcut anywhere on macOS to open the cpMan picker.")
                    .foregroundStyle(.secondary)
            }

            Section("About") {
                LabeledContent("Version", value: Bundle.main.shortVersion)
                LabeledContent("Build", value: Bundle.main.buildNumber)
            }
        }
        .formStyle(.grouped)
        .padding()
        .frame(width: 460, height: demoModeActive ? 320 : 240)
    }
}

private extension Bundle {
    var shortVersion: String {
        infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
    }
    var buildNumber: String {
        infoDictionary?["CFBundleVersion"] as? String ?? "—"
    }
}
