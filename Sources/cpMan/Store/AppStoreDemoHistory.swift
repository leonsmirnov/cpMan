import AppKit
import Foundation

/// Fictional clipboard rows for App Store screenshots — appended above existing history.
@MainActor
enum AppStoreDemoHistory {
    /// Adds demo text rows plus one image at the top of MRU; keeps your current history below.
    static func appendDemoItemsForScreenshots(in store: HistoryStore) async {
        let spacing: TimeInterval = 0.05

        struct Row {
            let text: String
            let sourceApp: String
            let bundleId: String
            let pinned: Bool
        }

        // Oldest → newest within the batch; full batch is stamped newer than `latestItem()`.
        let rowsOldestFirst: [Row] = [
            Row(
                text: "Notes — QA: empty state copy, pin affordance, toolbar contrast.",
                sourceApp: "Notes",
                bundleId: "com.apple.Notes",
                pinned: false
            ),
            Row(
                text: "✓ Ship checklist\nLocalization\nApp Store shots\nNotarization",
                sourceApp: "Reminders",
                bundleId: "com.apple.reminders",
                pinned: false
            ),
            Row(
                text: "alex: Pasteboard flow LGTM — ship when you’re ready. 🎉",
                sourceApp: "Slack",
                bundleId: "com.tinyspeck.slackmacgap",
                pinned: false
            ),
            Row(
                text: "#1E3A5F  →  primary\n#F4F6FB  →  surface",
                sourceApp: "Figma",
                bundleId: "com.figma.Desktop",
                pinned: false
            ),
            Row(
                text: """
                {
                  "theme": "dark",
                  "maxHistory": 50,
                  "ocrEnabled": true,
                  "pinnedOnTop": true
                }
                """,
                sourceApp: "Cursor",
                bundleId: "com.todesktop.230313mzl4w4u92",
                pinned: false
            ),
            Row(
                text: "feat(history): MRU ordering + pin\n\nCloses #142",
                sourceApp: "Terminal",
                bundleId: "com.apple.Terminal",
                pinned: false
            ),
            Row(
                text: "https://developer.apple.com/design/human-interface-guidelines",
                sourceApp: "Safari",
                bundleId: "com.apple.Safari",
                pinned: false
            ),
            Row(
                text: """
                enum ClipboardContent {
                    case text(String)
                    case image(Data)
                }

                struct ClipboardItem: Identifiable {
                    let id: UUID
                }
                """,
                sourceApp: "Xcode",
                bundleId: "com.apple.dt.Xcode",
                pinned: false
            ),
            Row(
                text: "ssh deploy@build.acme.local 'systemctl reload clipboard-sync'",
                sourceApp: "Terminal",
                bundleId: "com.apple.Terminal",
                pinned: true
            ),
        ]

        let base = appendBaseDate(after: store)
        let demoImage = demoPlaceholderImage(width: 720, height: 420)

        guard let imageItem = await ImageProcessor.shared.processCapture(
            image: demoImage,
            sourceApp: "Preview",
            sourceBundleId: "com.apple.Preview"
        ) else {
            let textOnly = rowsOldestFirst.enumerated().map { idx, row in
                ClipboardItem(
                    createdAt: batchTimestamp(indexInBatch: idx, base: base, spacing: spacing),
                    sourceApp: row.sourceApp,
                    sourceBundleId: row.bundleId,
                    contentType: .text,
                    textValue: row.text,
                    isPinned: row.pinned
                )
            }
            store.insertBatchWithoutPruning(textOnly)
            return
        }

        var all: [ClipboardItem] = []
        for (idx, row) in rowsOldestFirst.enumerated() {
            all.append(
                ClipboardItem(
                    createdAt: batchTimestamp(indexInBatch: idx, base: base, spacing: spacing),
                    sourceApp: row.sourceApp,
                    sourceBundleId: row.bundleId,
                    contentType: .text,
                    textValue: row.text,
                    isPinned: row.pinned
                )
            )
        }
        imageItem.createdAt = batchTimestamp(
            indexInBatch: rowsOldestFirst.count,
            base: base,
            spacing: spacing
        )
        all.append(imageItem)

        store.insertBatchWithoutPruning(all)
    }

    /// First timestamp in the new batch — strictly after the current MRU row so demos sort above prior history.
    private static func appendBaseDate(after store: HistoryStore) -> Date {
        if let latest = store.latestItem() {
            return latest.createdAt.addingTimeInterval(0.05)
        }
        return Date()
    }

    /// Rows with higher `indexInBatch` are newer (sort above) within the appended block.
    private static func batchTimestamp(indexInBatch: Int, base: Date, spacing: TimeInterval) -> Date {
        base.addingTimeInterval(Double(indexInBatch) * spacing)
    }

    private static func demoPlaceholderImage(width: Int, height: Int) -> NSImage {
        let size = NSSize(width: width, height: height)
        let image = NSImage(size: size)
        image.lockFocus()
        let rect = NSRect(origin: .zero, size: size)
        let gradient = NSGradient(colors: [
            NSColor(calibratedRed: 0.22, green: 0.42, blue: 0.88, alpha: 1),
            NSColor(calibratedRed: 0.10, green: 0.18, blue: 0.42, alpha: 1),
        ])
        gradient?.draw(in: rect, angle: 128)

        let title = "Roadmap Q3"
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 28, weight: .semibold),
            .foregroundColor: NSColor.white.withAlphaComponent(0.95),
        ]
        let titleSize = (title as NSString).size(withAttributes: attrs)
        (title as NSString).draw(
            at: NSPoint(x: (CGFloat(width) - titleSize.width) / 2, y: CGFloat(height) / 2 - titleSize.height / 2),
            withAttributes: attrs
        )
        image.unlockFocus()
        return image
    }
}
