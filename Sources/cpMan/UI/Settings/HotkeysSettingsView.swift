import SwiftUI
import KeyboardShortcuts

struct HotkeysSettingsView: View {
    var body: some View {
        Form {
            Section("Shortcuts") {
                KeyboardShortcuts.Recorder("Open picker:", name: .openPicker)
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}
