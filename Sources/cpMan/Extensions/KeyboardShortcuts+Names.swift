import KeyboardShortcuts

extension KeyboardShortcuts.Name {
    // ⌃⌥V (Control+Option+V) — rarely claimed by other apps.
    // User can rebind this in Settings → Hotkeys.
    static let openPicker = Self("openPicker", default: .init(.v, modifiers: [.control, .option]))
}
