import AppKit
import CryptoKit
import os.log

private let logger = Logger(subsystem: "com.cpman.app", category: "DemoSeedData")

/// Fictional clipboard samples for App Review. No real user data.
///
/// Produces a mix of text clips and a couple of generated image clips (with OCR
/// text pre-filled) so a reviewer can exercise the full 2.0 feature set: search,
/// pinning, text vs. image rows, image preview, and "paste as plain text" from an
/// image's OCR. Image files are written into the app's own Application Support
/// container, exactly like a real capture.
@MainActor
enum DemoSeedData {
    /// All demo items, newest first by `createdAt`.
    static func makeItems(now: Date = Date()) -> [ClipboardItem] {
        makeTextItems(now: now) + makeImageItems(now: now)
    }

    // MARK: - Text clips

    private static func makeTextItems(now: Date) -> [ClipboardItem] {
        // (text, sourceApp, sourceBundleId, pinned)
        let payloads: [(String, String?, String?, Bool)] = [
            (
                "Team standup notes — Q3 roadmap\n- Ship cpMan 2.0 (images + OCR)\n- Polish picker search\n- App Store submission",
                "Notes", "com.apple.Notes", true
            ),
            (
                "https://developer.apple.com/app-store/review/guidelines/",
                "Safari", "com.apple.Safari", false
            ),
            (
                "func togglePicker() {\n    pickerPanel?.toggle()\n}",
                "Xcode", "com.apple.dt.Xcode", false
            ),
            (
                "Customer quote: \"I love having clipboard history one shortcut away — and now it remembers images too.\"",
                "Slack", "com.tinyspeck.slackmacgap", false
            ),
            (
                "Shipping checklist:\n1. Archive build\n2. Upload pkg\n3. Submit for review",
                "Notes", "com.apple.Notes", false
            ),
            (
                "support@example.com",
                "Mail", "com.apple.mail", false
            ),
            (
                "Try Private Mode: menu bar icon → Private Mode → pause recording for 30 minutes.",
                "Reminders", "com.apple.reminders", true
            ),
            (
                "Lorem ipsum dolor sit amet, consectetur adipiscing elit. Paste this long clip to test preview and scrolling inside the picker list.",
                "TextEdit", "com.apple.TextEdit", false
            ),
            (
                "git commit -m \"Add demo mode for App Review\"",
                "Terminal", "com.apple.Terminal", false
            ),
            (
                "Weekly summary: 12 bugs fixed, 3 features shipped, 0 network calls.",
                "Mail", "com.apple.mail", false
            ),
            (
                "Shortcut tip: open the picker with ⌃⌥V, then type to filter.",
                "Notes", "com.apple.Notes", false
            ),
            (
                "Filter demo: type \"roadmap\" or \"git\" in the search field.",
                "Safari", "com.apple.Safari", false
            ),
        ]

        // Spread timestamps so the list looks like real history (newest first).
        return payloads.enumerated().map { index, payload in
            let offset = TimeInterval(45 + index * 900)
            return ClipboardItem(
                createdAt: now.addingTimeInterval(-offset),
                sourceApp: payload.1,
                sourceBundleId: payload.2,
                contentType: .text,
                textValue: payload.0,
                isPinned: payload.3
            )
        }
    }

    // MARK: - Image clips (generated on disk, with OCR text pre-filled)

    private static func makeImageItems(now: Date) -> [ClipboardItem] {
        let specs: [(title: String, body: String, bg: NSColor, app: String, bundle: String, ageDays: Int)] = [
            (
                "Release plan — cpMan 2.0",
                "Images + OCR\nAuto-paste\nPrivate Mode\nIgnore list",
                NSColor(calibratedRed: 0.16, green: 0.22, blue: 0.42, alpha: 1),
                "Preview", "com.apple.Preview", 1
            ),
            (
                "OCR demo screenshot",
                "Select this image, then choose\n\"Paste as Plain Text\" to paste\nthis extracted text.",
                NSColor(calibratedRed: 0.10, green: 0.32, blue: 0.28, alpha: 1),
                "Safari", "com.apple.Safari", 2
            ),
        ]

        return specs.compactMap { spec in
            guard let png = renderCard(title: spec.title, body: spec.body, background: spec.bg),
                  let url = writeImageToContainer(png.data)
            else {
                logger.warning("Demo image generation failed for \(spec.title, privacy: .public); skipping")
                return nil
            }
            let ocr = "\(spec.title)\n\(spec.body)"
            return ClipboardItem(
                createdAt: now.addingTimeInterval(-TimeInterval(spec.ageDays) * 86_400),
                sourceApp: spec.app,
                sourceBundleId: spec.bundle,
                contentType: .image,
                ocrText: ocr,
                imageFilePath: url.path,
                imageWidth: png.width,
                imageHeight: png.height,
                imageSizeBytes: png.data.count,
                imageHash: sha256(png.data)
            )
        }
    }

    /// Draws a simple titled card and returns PNG bytes + pixel dimensions.
    ///
    /// Draws directly into an `NSBitmapImageRep`-backed context rather than using
    /// `NSImage.lockFocus()`, so rendering does not depend on a window-server
    /// graphics context (works reliably at launch and in headless test runners).
    private static func renderCard(
        title: String,
        body: String,
        background: NSColor
    ) -> (data: Data, width: Int, height: Int)? {
        let width = 1200
        let height = 800

        guard let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: width,
            pixelsHigh: height,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .calibratedRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ), let context = NSGraphicsContext(bitmapImageRep: rep) else {
            return nil
        }

        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = context

        background.setFill()
        NSRect(x: 0, y: 0, width: width, height: height).fill()

        let titleAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.boldSystemFont(ofSize: 72),
            .foregroundColor: NSColor.white,
        ]
        let bodyAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 44),
            .foregroundColor: NSColor(calibratedWhite: 0.92, alpha: 1),
        ]
        (title as NSString).draw(at: NSPoint(x: 80, y: height - 200), withAttributes: titleAttrs)
        (body as NSString).draw(
            in: NSRect(x: 80, y: 80, width: width - 160, height: height - 320),
            withAttributes: bodyAttrs
        )

        context.flushGraphics()
        NSGraphicsContext.restoreGraphicsState()

        guard let data = rep.representation(using: .png, properties: [:]) else { return nil }
        return (data, rep.pixelsWide, rep.pixelsHigh)
    }

    /// Writes demo PNG bytes into Application Support/cpMan/Images, matching the
    /// real capture path so the picker, pruning, and "delete all" treat it identically.
    private static func writeImageToContainer(_ data: Data) -> URL? {
        let support = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let dir = support.appendingPathComponent("cpMan/Images", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let url = dir.appendingPathComponent(UUID().uuidString + ".png")
        do {
            try data.write(to: url)
            try? FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
            return url
        } catch {
            logger.error("Demo image write failed: \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }

    private static func sha256(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }
}
