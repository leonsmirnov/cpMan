import KeyboardShortcuts
import SwiftUI

/// Single row that hosts the KeyboardShortcuts recorder for the picker hotkey.
///
/// basic_version no longer has a "Hotkeys" tab — the recorder is rendered
/// inline by `SettingsView` so we only need the bare row here.
struct HotkeyRow: View {
    var body: some View {
        KeyboardShortcuts.Recorder("Open picker:", name: .openPicker)
    }
}
