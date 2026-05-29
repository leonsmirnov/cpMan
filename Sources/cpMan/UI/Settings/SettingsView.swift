import SwiftUI

/// Single-screen Settings window. Exposes the picker hotkey recorder and a
/// read-only version row.
struct SettingsView: View {
    var body: some View {
        Form {
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
        .frame(width: 460, height: 240)
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
