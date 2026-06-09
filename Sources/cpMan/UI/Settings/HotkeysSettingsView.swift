import SwiftUI
import KeyboardShortcuts

struct HotkeysSettingsView: View {
    var body: some View {
        Form {
            Section {
                HStack {
                    Text("Open picker")
                    Spacer()
                    KeyboardShortcuts.Recorder(for: .openPicker)
                }
            } header: {
                Text("Global Shortcut")
            } footer: {
                VStack(alignment: .leading, spacing: 4) {
                    Text("This shortcut opens the clipboard picker from anywhere.")
                    Text("To change it, click the shortcut field above, then press the new key combination you want to use.")
                    Text("Click the **✕** in the field to clear it, or use **Reset to Default** below.")
                    Text("Default: ⌃⌥V (Control-Option-V).")
                }
                .font(.footnote)
                .foregroundStyle(.secondary)
            }

            Section {
                Button("Reset to Default") {
                    KeyboardShortcuts.reset(.openPicker)
                }
                .controlSize(.small)
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}
