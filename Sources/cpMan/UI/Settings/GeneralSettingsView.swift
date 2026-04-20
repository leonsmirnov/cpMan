import SwiftUI

struct GeneralSettingsView: View {
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var axService: AccessibilityService

    var body: some View {
        Form {
            Section("Behaviour") {
                Toggle("Auto-paste on selection (closes picker + synthesises ⌘V)", isOn: $settings.autoPasteEnabled)
            }

            Section {
                HStack {
                    Label(
                        axService.isGranted ? "Granted" : "Not granted",
                        systemImage: axService.isGranted ? "checkmark.circle.fill" : "xmark.circle.fill"
                    )
                    .foregroundStyle(axService.isGranted ? .green : .red)
                    Spacer()
                    if !axService.isGranted {
                        Button("Open Settings…") {
                            axService.openAccessibilitySettings()
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                    }
                }
            } header: {
                Text("Accessibility Permission")
            } footer: {
                if axService.isGranted {
                    Text("Auto-paste is fully enabled.")
                        .foregroundStyle(.secondary)
                } else {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Click \"Open Settings…\" to go directly to the Accessibility pane, then:")
                        Text("• If cpMan is in the list → toggle it **ON**")
                        Text("• If cpMan is **not** in the list → click **+** at the bottom, open your Applications folder, and add cpMan")
                        Text("The status above updates automatically once access is granted.")
                    }
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                }
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}
