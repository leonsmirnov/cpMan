import Foundation

/// Fictional clipboard samples for App Review. No real user data.
enum DemoSeedData {
    static func makeItems(now: Date = Date()) -> [ClipboardItem] {
        let offsets: [TimeInterval] = [
            45, 120, 300, 600, 900, 1_800, 3_600, 7_200,
            10_800, 18_000, 28_800, 43_200, 86_400, 172_800, 259_200
        ]

        let payloads: [(String, String?, String?)] = [
            (
                "Team standup notes - Q2 roadmap\n- Ship cpMan 1.0\n- Polish picker search\n- App Store submission",
                "Notes",
                "com.apple.Notes"
            ),
            (
                "https://developer.apple.com/app-store/review/guidelines/",
                "Safari",
                "com.apple.Safari"
            ),
            (
                "export CPMAN_DEVELOPMENT_TEAM=\"AB12CD34EF\"",
                "Terminal",
                "com.apple.Terminal"
            ),
            (
                "Meeting invite: Product review Thursday 2:00 PM PT",
                "Mail",
                "com.apple.mail"
            ),
            (
                "func togglePicker() {\n    pickerPanel?.toggle()\n}",
                "Xcode",
                "com.apple.dt.Xcode"
            ),
            (
                "Customer quote: \"I love having clipboard history one shortcut away.\"",
                "Slack",
                "com.tinyspeck.slackmacgap"
            ),
            (
                "Shipping checklist:\n1. Archive build\n2. Upload pkg\n3. Submit for review",
                "Notes",
                "com.apple.Notes"
            ),
            (
                "support@example.com",
                "Safari",
                "com.apple.Safari"
            ),
            (
                "Remember to update the privacy policy URL before resubmitting.",
                "Reminders",
                "com.apple.reminders"
            ),
            (
                "Lorem ipsum dolor sit amet, consectetur adipiscing elit. Paste this long clip to test preview and scrolling inside the picker list.",
                "TextEdit",
                "com.apple.TextEdit"
            ),
            (
                "API key placeholder: demo-only-not-real-00000000",
                "Safari",
                "com.apple.Safari"
            ),
            (
                "git commit -m \"Add demo mode for App Review\"",
                "Terminal",
                "com.apple.Terminal"
            ),
            (
                "Weekly summary: 12 bugs fixed, 3 features shipped, 0 network calls.",
                "Mail",
                "com.apple.mail"
            ),
            (
                "Shortcut tip: press 1-9 in the picker to copy a top item instantly.",
                "Notes",
                "com.apple.Notes"
            ),
            (
                "Filter demo: type \"meeting\" or \"git\" in the search field.",
                "Safari",
                "com.apple.Safari"
            )
        ]

        return zip(offsets, payloads).map { offset, payload in
            ClipboardItem(
                createdAt: now.addingTimeInterval(-offset),
                sourceApp: payload.1,
                sourceBundleId: payload.2,
                textValue: payload.0
            )
        }
    }
}
