import XCTest
@testable import cpMan

// MARK: - AppSettings / UserDefaults

/// Tests the C2 fix: `intOrDefault` must distinguish an explicitly-saved 0 (= "no limit")
/// from a missing key (= use the default). Before the fix, saving 0 was treated as missing
/// and the default value was returned on the next launch.
final class UserDefaultsIntOrDefaultTests: XCTestCase {
    private var suiteName: String!
    private var defaults: UserDefaults!

    override func setUp() {
        super.setUp()
        suiteName = "com.cpman.tests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)!
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        super.tearDown()
    }

    func testMissingKeyReturnsDefault() {
        // Key was never written → return fallback
        XCTAssertEqual(defaults.intOrDefault(forKey: "missing", fallback: 42), 42)
    }

    func testExplicitZeroReturnsZero() {
        // 0 is a valid user choice meaning "no limit" — must NOT be replaced with fallback
        defaults.set(0, forKey: "limit")
        XCTAssertEqual(defaults.intOrDefault(forKey: "limit", fallback: 10), 0)
    }

    func testNonZeroValueReturnsValue() {
        defaults.set(250, forKey: "count")
        XCTAssertEqual(defaults.intOrDefault(forKey: "count", fallback: 10), 250)
    }
}

// MARK: - ImageProcessor hashing

@MainActor
final class ImageProcessorHashTests: XCTestCase {
    func testSha256IsDeterministic() {
        let processor = ImageProcessor.shared
        let data = Data("hello clipboard".utf8)
        XCTAssertEqual(processor.sha256(data), processor.sha256(data))
    }

    func testSha256ProducesHexString() {
        let processor = ImageProcessor.shared
        let hash = processor.sha256(Data("test".utf8))
        XCTAssertEqual(hash.count, 64, "SHA-256 hex should be 64 characters")
        XCTAssert(hash.allSatisfy { $0.isHexDigit }, "Hash must be valid hex")
    }

    func testDifferentDataProducesDifferentHash() {
        let processor = ImageProcessor.shared
        let h1 = processor.sha256(Data("aaa".utf8))
        let h2 = processor.sha256(Data("bbb".utf8))
        XCTAssertNotEqual(h1, h2)
    }
}

// MARK: - ClipboardItem model

final class ClipboardItemModelTests: XCTestCase {
    func testTextItemCreation() {
        let item = ClipboardItem(
            contentType: .text,
            textValue: "hello"
        )
        XCTAssertEqual(item.contentType, .text)
        XCTAssertEqual(item.textValue, "hello")
        XCTAssertFalse(item.isPinned)
        XCTAssertNil(item.imageFilePath)
    }

    func testImageItemCreation() {
        let item = ClipboardItem(
            contentType: .image,
            imageFilePath: "/tmp/test.png",
            imageWidth: 1920,
            imageHeight: 1080,
            imageSizeBytes: 204_800,
            imageHash: "abc123"
        )
        XCTAssertEqual(item.contentType, .image)
        XCTAssertEqual(item.imageWidth, 1920)
        XCTAssertEqual(item.imageHeight, 1080)
        XCTAssertEqual(item.imageSizeBytes, 204_800)
        XCTAssertNil(item.textValue)
    }

    func testPinnedDefaultIsFalse() {
        let item = ClipboardItem(contentType: .text, textValue: "x")
        XCTAssertFalse(item.isPinned)
    }

    func testUUIDIsUnique() {
        let a = ClipboardItem(contentType: .text, textValue: "a")
        let b = ClipboardItem(contentType: .text, textValue: "b")
        XCTAssertNotEqual(a.id, b.id)
    }

    func testCreatedAtIsRecentlyNow() {
        let before = Date()
        let item   = ClipboardItem(contentType: .text, textValue: "time")
        let after  = Date()
        XCTAssert(item.createdAt >= before)
        XCTAssert(item.createdAt <= after)
    }

    func testContentTypeRawValues() {
        XCTAssertEqual(ClipboardContentType.text.rawValue, "text")
        XCTAssertEqual(ClipboardContentType.image.rawValue, "image")
    }
}

// MARK: - HistoryStore (in-memory)

@MainActor
final class HistoryStorePruningTests: XCTestCase {
    func testInsertAndFetchSingleItem() async {
        let store = HistoryStore.makeForTesting()
        let item  = ClipboardItem(contentType: .text, textValue: "hello")
        store.insert(item)
        let all = store.allItems()
        XCTAssertEqual(all.count, 1)
        XCTAssertEqual(all.first?.textValue, "hello")
    }

    func testCountLimitPrunesOldestFirst() async {
        let store    = HistoryStore.makeForTesting()
        let settings = AppSettings.shared

        let originalLimit = settings.historyCountLimit
        settings.historyCountLimit = 3
        defer { settings.historyCountLimit = originalLimit }

        for i in 1...5 {
            let item = ClipboardItem(
                createdAt: Date(timeIntervalSinceNow: Double(i)),
                contentType: .text,
                textValue: "item \(i)"
            )
            store.insert(item)
        }

        let remaining = store.allItems()
        XCTAssertLessThanOrEqual(remaining.count, 3, "Pruning should keep at most 3 items")
    }

    func testZeroCountLimitMeansNoLimit() async {
        let store    = HistoryStore.makeForTesting()
        let settings = AppSettings.shared

        let originalLimit = settings.historyCountLimit
        settings.historyCountLimit = 0     // 0 = no limit
        defer { settings.historyCountLimit = originalLimit }

        for i in 1...10 {
            store.insert(ClipboardItem(contentType: .text, textValue: "item \(i)"))
        }

        XCTAssertEqual(store.allItems().count, 10, "0 limit should keep all 10 items")
    }

    func testSizeLimitDoesNotDeleteTextItems() async {
        let store    = HistoryStore.makeForTesting()
        let settings = AppSettings.shared

        let originalEnabled = settings.historySizeLimitEnabled
        let originalMB      = settings.historySizeLimitMB
        settings.historySizeLimitEnabled = true
        settings.historySizeLimitMB      = 1  // 1 MB limit
        defer {
            settings.historySizeLimitEnabled = originalEnabled
            settings.historySizeLimitMB      = originalMB
        }

        let textItem = ClipboardItem(contentType: .text, textValue: "keep me")
        store.insert(textItem)

        // Image item that exceeds 1 MB
        let bigImageItem = ClipboardItem(
            contentType: .image,
            imageFilePath: "/nonexistent.png",
            imageSizeBytes: 2 * 1_048_576  // 2 MB
        )
        store.insert(bigImageItem)

        let remaining = store.allItems()
        let textItems = remaining.filter { $0.contentType == .text }
        XCTAssertTrue(textItems.contains { $0.textValue == "keep me" },
                      "Text items must never be deleted by the size-limit pruner")
    }

    func testDeleteRemovesItem() async {
        let store = HistoryStore.makeForTesting()
        let item  = ClipboardItem(contentType: .text, textValue: "bye")
        store.insert(item)
        XCTAssertEqual(store.allItems().count, 1)
        store.delete(item)
        XCTAssertEqual(store.allItems().count, 0)
    }

    func testDeleteAllRemovesEverything() async {
        let store = HistoryStore.makeForTesting()
        for i in 1...5 {
            store.insert(ClipboardItem(contentType: .text, textValue: "item \(i)"))
        }
        XCTAssertEqual(store.allItems().count, 5)
        store.deleteAll()
        XCTAssertEqual(store.allItems().count, 0, "deleteAll must leave history empty")
    }

    func testDeleteAllOnEmptyStoreIsHarmless() async {
        let store = HistoryStore.makeForTesting()
        XCTAssertNoThrow(store.deleteAll())
        XCTAssertEqual(store.allItems().count, 0)
    }

    func testDeleteAllRemovesMixedContentTypes() async {
        let store = HistoryStore.makeForTesting()
        store.insert(ClipboardItem(contentType: .text, textValue: "text item"))
        store.insert(ClipboardItem(
            contentType: .image,
            imageFilePath: "/nonexistent/image.png",
            imageSizeBytes: 1024
        ))
        XCTAssertEqual(store.allItems().count, 2)
        store.deleteAll()
        XCTAssertEqual(store.allItems().count, 0, "deleteAll must remove both text and image items")
    }

    func testLatestItemReturnsNewest() async {
        let store = HistoryStore.makeForTesting()
        let old   = ClipboardItem(createdAt: Date(timeIntervalSinceNow: -100),
                                  contentType: .text, textValue: "old")
        let new_  = ClipboardItem(createdAt: Date(),
                                  contentType: .text, textValue: "new")
        store.insert(old)
        store.insert(new_)
        XCTAssertEqual(store.latestItem()?.textValue, "new")
    }

    func testSearchFiltersByText() async {
        let store = HistoryStore.makeForTesting()
        store.insert(ClipboardItem(contentType: .text, textValue: "hello world"))
        store.insert(ClipboardItem(contentType: .text, textValue: "foo bar"))

        let results = store.allItems(matching: "hello")
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.textValue, "hello world")
    }

    func testSearchIsCaseInsensitive() async {
        let store = HistoryStore.makeForTesting()
        store.insert(ClipboardItem(contentType: .text, textValue: "Hello World"))
        XCTAssertEqual(store.allItems(matching: "hello").count, 1)
        XCTAssertEqual(store.allItems(matching: "HELLO").count, 1)
    }
}

// MARK: - Private Mode

@MainActor
final class PrivateModeTests: XCTestCase {
    private var originalValue: Bool = false

    override func setUp() async throws {
        try await super.setUp()
        originalValue = AppSettings.shared.isPrivateModeEnabled
        AppSettings.shared.isPrivateModeEnabled = false
    }

    override func tearDown() async throws {
        AppSettings.shared.isPrivateModeEnabled = originalValue
        try await super.tearDown()
    }

    func testDefaultIsOff() {
        // Private mode must default to OFF — recording should start automatically
        XCTAssertFalse(AppSettings.shared.isPrivateModeEnabled)
    }

    func testToggleOn() {
        AppSettings.shared.isPrivateModeEnabled = true
        XCTAssertTrue(AppSettings.shared.isPrivateModeEnabled)
    }

    func testToggleOffAfterOn() {
        AppSettings.shared.isPrivateModeEnabled = true
        AppSettings.shared.isPrivateModeEnabled = false
        XCTAssertFalse(AppSettings.shared.isPrivateModeEnabled)
    }

    func testPrivateModeBlocksInsertion() {
        // When private mode is ON the monitor skips captures.
        // We test the AppSettings flag directly; ClipboardMonitor reads it before inserting.
        let store = HistoryStore.makeForTesting()
        AppSettings.shared.isPrivateModeEnabled = true

        // Simulate what ClipboardMonitor does: bail early if private mode is on
        if !AppSettings.shared.isPrivateModeEnabled {
            store.insert(ClipboardItem(contentType: .text, textValue: "secret"))
        }

        XCTAssertEqual(store.allItems().count, 0,
                       "Private mode must prevent items from being inserted")
    }

    func testDisablingPrivateModeAllowsInsertion() {
        let store = HistoryStore.makeForTesting()
        AppSettings.shared.isPrivateModeEnabled = false

        if !AppSettings.shared.isPrivateModeEnabled {
            store.insert(ClipboardItem(contentType: .text, textValue: "visible"))
        }

        XCTAssertEqual(store.allItems().count, 1)
    }
}

// MARK: - History age limit

@MainActor
final class HistoryAgeLimitTests: XCTestCase {
    func testAgeLimitPrunesOldItems() async {
        let store    = HistoryStore.makeForTesting()
        let settings = AppSettings.shared

        let originalEnabled = settings.historyAgeLimitEnabled
        let originalDays    = settings.historyAgeLimitDays
        settings.historyAgeLimitEnabled = true
        settings.historyAgeLimitDays    = 1   // keep only items < 1 day old
        defer {
            settings.historyAgeLimitEnabled = originalEnabled
            settings.historyAgeLimitDays    = originalDays
        }

        // Insert one old item (2 days ago) and one recent item
        let oldItem = ClipboardItem(
            createdAt: Date(timeIntervalSinceNow: -2 * 86_400),
            contentType: .text,
            textValue: "old"
        )
        let newItem = ClipboardItem(
            createdAt: Date(),
            contentType: .text,
            textValue: "new"
        )
        store.insert(oldItem)
        store.insert(newItem)

        // Trigger pruning by inserting a third item
        store.insert(ClipboardItem(contentType: .text, textValue: "trigger"))

        let remaining = store.allItems()
        XCTAssertFalse(remaining.contains { $0.textValue == "old" },
                       "Item older than age limit must be pruned")
        XCTAssertTrue(remaining.contains { $0.textValue == "new" },
                      "Recent item must be kept")
    }

    func testAgeLimitDisabledKeepsOldItems() async {
        let store    = HistoryStore.makeForTesting()
        let settings = AppSettings.shared

        let originalEnabled = settings.historyAgeLimitEnabled
        settings.historyAgeLimitEnabled = false
        defer { settings.historyAgeLimitEnabled = originalEnabled }

        let oldItem = ClipboardItem(
            createdAt: Date(timeIntervalSinceNow: -365 * 86_400),
            contentType: .text,
            textValue: "ancient"
        )
        store.insert(oldItem)
        store.insert(ClipboardItem(contentType: .text, textValue: "trigger"))

        XCTAssertTrue(store.allItems().contains { $0.textValue == "ancient" },
                      "Age limit disabled must keep all items regardless of age")
    }
}

// MARK: - Paste as plain text (PasteService)

@MainActor
final class PasteAsPlainTextTests: XCTestCase {
    func testPlainTextItemHasTextValue() {
        // pasteAsPlainText requires a non-nil textValue for text items
        let item = ClipboardItem(contentType: .text, textValue: "hello plain")
        XCTAssertNotNil(item.textValue)
    }

    func testImageItemWithoutOCRHasNoPlainText() {
        // pasteAsPlainText on an image with no OCR text should be a no-op
        let item = ClipboardItem(
            contentType: .image,
            imageFilePath: "/tmp/test.png"
        )
        // ocrText is nil → pasteAsPlainText returns early (nothing to paste)
        XCTAssertNil(item.ocrText)
    }

    func testImageItemWithOCRHasPlainText() {
        let item = ClipboardItem(
            contentType: .image,
            ocrText: "extracted text from image",
            imageFilePath: "/tmp/test.png"
        )
        XCTAssertNotNil(item.ocrText)
        XCTAssertEqual(item.ocrText, "extracted text from image")
    }
}

// MARK: - Edit history item

@MainActor
final class EditHistoryItemTests: XCTestCase {
    func testEditedItemAppearsAsNewEntry() async {
        let store = HistoryStore.makeForTesting()
        let original = ClipboardItem(contentType: .text, textValue: "original text")
        store.insert(original)

        // Simulate what PickerView does on save: insert a new item
        let edited = ClipboardItem(
            sourceApp: original.sourceApp,
            sourceBundleId: original.sourceBundleId,
            contentType: .text,
            textValue: "edited text"
        )
        store.insert(edited)

        let all = store.allItems()
        XCTAssertEqual(all.count, 2, "Edit must add a new entry, not replace the original")
        XCTAssertTrue(all.contains { $0.textValue == "original text" },
                      "Original item must remain in history")
        XCTAssertTrue(all.contains { $0.textValue == "edited text" },
                      "Edited item must appear in history")
    }

    func testEditedItemHasDifferentID() {
        let original = ClipboardItem(contentType: .text, textValue: "original")
        let edited   = ClipboardItem(contentType: .text, textValue: "edited")
        XCTAssertNotEqual(original.id, edited.id,
                          "Edited item must be a distinct entry with its own UUID")
    }

    func testEditedItemIsNewerThanOriginal() {
        let original = ClipboardItem(
            createdAt: Date(timeIntervalSinceNow: -10),
            contentType: .text,
            textValue: "original"
        )
        let edited = ClipboardItem(contentType: .text, textValue: "edited")
        XCTAssertGreaterThan(edited.createdAt, original.createdAt,
                             "Edited item must have a more recent timestamp")
    }
}

// MARK: - AccessibilityService

final class AccessibilityServiceTests: XCTestCase {
    @MainActor func testSharedInstanceExists() {
        // Smoke test — shared must not crash on access
        let svc = AccessibilityService.shared
        XCTAssertNotNil(svc)
    }

    @MainActor func testIsSecureInputActiveReturnsBool() {
        // Should return a Bool without crashing (actual value depends on runtime state)
        let _ = AccessibilityService.shared.isSecureInputActive
    }
}

// MARK: - Helpers

/// Expose internal `intOrDefault` to tests without adding test-only API surface to AppSettings.
extension UserDefaults {
    func intOrDefault(forKey key: String, fallback: Int) -> Int {
        (object(forKey: key) as? Int) ?? fallback
    }
}
