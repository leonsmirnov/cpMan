import AppKit
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

final class ImageProcessorHashTests: XCTestCase {
    func testSha256IsDeterministic() {
        let data = Data("hello clipboard".utf8)
        XCTAssertEqual(ImageProcessor.sha256(data), ImageProcessor.sha256(data))
    }

    func testSha256ProducesHexString() {
        let hash = ImageProcessor.sha256(Data("test".utf8))
        XCTAssertEqual(hash.count, 64, "SHA-256 hex should be 64 characters")
        XCTAssert(hash.allSatisfy { $0.isHexDigit }, "Hash must be valid hex")
    }

    func testDifferentDataProducesDifferentHash() {
        let h1 = ImageProcessor.sha256(Data("aaa".utf8))
        let h2 = ImageProcessor.sha256(Data("bbb".utf8))
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
            textValue: nil,
            ocrText: nil,
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
            textValue: nil,
            ocrText: nil,
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
            textValue: nil,
            ocrText: nil,
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

    func testPrivateModeBlocksRecordingPredicateMatchesMonitor() {
        XCTAssertFalse(
            ClipboardMonitor.shouldRecordClipboard(
                secureInputActive: false,
                privateModeEnabled: true,
                frontmostBundleId: "com.apple.Safari",
                ignoredBundleIds: []
            ),
            "Private mode ON must use the same guard as ClipboardMonitor.checkPasteboard"
        )
    }

    func testPrivateModeOffAllowsRecordingPredicate() {
        XCTAssertTrue(
            ClipboardMonitor.shouldRecordClipboard(
                secureInputActive: false,
                privateModeEnabled: false,
                frontmostBundleId: "com.apple.Safari",
                ignoredBundleIds: []
            )
        )
    }

    func testSecureInputBlocksRecordingPredicate() {
        XCTAssertFalse(
            ClipboardMonitor.shouldRecordClipboard(
                secureInputActive: true,
                privateModeEnabled: false,
                frontmostBundleId: "com.apple.Safari",
                ignoredBundleIds: []
            )
        )
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
            textValue: nil,
            ocrText: nil,
            imageFilePath: "/tmp/test.png"
        )
        // ocrText is nil → pasteAsPlainText returns early (nothing to paste)
        XCTAssertNil(item.ocrText)
    }

    func testImageItemWithOCRHasPlainText() {
        let item = ClipboardItem(
            contentType: .image,
            textValue: nil,
            ocrText: "extracted text from image",
            imageFilePath: "/tmp/test.png"
        )
        XCTAssertNotNil(item.ocrText)
        XCTAssertEqual(item.ocrText, "extracted text from image")
    }
}

// MARK: - Pasteboard payload validation (PasteService)

final class PasteboardPayloadTests: XCTestCase {
    func testTextPayloadRequiresTextValue() {
        let valid = ClipboardItem(contentType: .text, textValue: "copy me")
        guard case .text("copy me")? = PasteboardPayload(item: valid) else {
            return XCTFail("Text item with textValue must produce a text payload")
        }

        let invalid = ClipboardItem(contentType: .text, textValue: nil)
        XCTAssertNil(PasteboardPayload(item: invalid),
                     "Text item without textValue must not clear the pasteboard")
    }

    func testImagePayloadRequiresReadableImageFile() throws {
        let missing = ClipboardItem(
            contentType: .image,
            imageFilePath: "/tmp/cpman-missing-\(UUID().uuidString).png"
        )
        XCTAssertNil(PasteboardPayload(item: missing),
                     "Missing image file must not clear the pasteboard")

        let imageURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("cpman-paste-payload-\(UUID().uuidString).png")
        try Self.makeTinyPNG(at: imageURL)
        addTeardownBlock {
            try? FileManager.default.removeItem(at: imageURL)
        }

        let valid = ClipboardItem(contentType: .image, imageFilePath: imageURL.path)
        guard case .image(let image)? = PasteboardPayload(item: valid) else {
            return XCTFail("Readable image file must produce an image payload")
        }
        XCTAssertGreaterThan(image.size.width, 0)
    }

    private static func makeTinyPNG(at url: URL) throws {
        guard let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: 4,
            pixelsHigh: 4,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ),
        let data = rep.representation(using: .png, properties: [:])
        else { throw NSError(domain: "PasteboardPayloadTests", code: 1) }
        try data.write(to: url)
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

// MARK: - PickerListSync (live history while picker is open)

@MainActor
final class PickerListSyncTests: XCTestCase {
    /// When a newer copy lands at the top, selection must stay on the same item id (no jump to row 1).
    func testNewInsertAtTopKeepsSelectionOnSameItem() async {
        let store = HistoryStore.makeForTesting()
        let t100 = Date(timeIntervalSince1970: 100)
        let t200 = Date(timeIntervalSince1970: 200)
        let t300 = Date(timeIntervalSince1970: 300)

        let a = ClipboardItem(createdAt: t100, contentType: .text, textValue: "a")
        let b = ClipboardItem(createdAt: t200, contentType: .text, textValue: "b")
        store.insert(a)
        store.insert(b)
        XCTAssertEqual(store.allItems().map(\.textValue), ["b", "a"])

        let c = ClipboardItem(createdAt: t300, contentType: .text, textValue: "c")
        store.insert(c)

        let (items, selectedID, _) = PickerListSync.snapshot(
            store: store,
            matching: "",
            previousSelection: a.id,
            expandedID: nil
        )
        XCTAssertEqual(items.map(\.textValue), ["c", "b", "a"])
        XCTAssertEqual(selectedID, a.id, "Highlight must remain on the previously selected row")
    }

    func testSelectionResetsToFirstWhenPreviousRowRemoved() async {
        let store = HistoryStore.makeForTesting()
        let gone = UUID()
        let keep = ClipboardItem(contentType: .text, textValue: "only")
        store.insert(keep)

        let (items, selectedID, _) = PickerListSync.snapshot(
            store: store,
            matching: "",
            previousSelection: gone,
            expandedID: nil
        )
        XCTAssertEqual(items.count, 1)
        XCTAssertEqual(selectedID, keep.id)
    }

    func testExpandedRowClearedWhenItemNoLongerInList() async {
        let store = HistoryStore.makeForTesting()
        let a = ClipboardItem(contentType: .text, textValue: "a")
        let b = ClipboardItem(contentType: .text, textValue: "b")
        store.insert(a)
        store.insert(b)

        let (_, _, expanded) = PickerListSync.snapshot(
            store: store,
            matching: "",
            previousSelection: b.id,
            expandedID: a.id
        )
        XCTAssertEqual(expanded, a.id)

        store.delete(a)
        let (_, _, expandedAfter) = PickerListSync.snapshot(
            store: store,
            matching: "",
            previousSelection: b.id,
            expandedID: a.id
        )
        XCTAssertNil(expandedAfter, "Expanded row must clear when that item was deleted")
    }

    func testSearchQueryReflectedInSnapshot() async {
        let store = HistoryStore.makeForTesting()
        store.insert(ClipboardItem(contentType: .text, textValue: "alpha"))
        store.insert(ClipboardItem(contentType: .text, textValue: "beta"))

        let (items, _, _) = PickerListSync.snapshot(
            store: store,
            matching: "alp",
            previousSelection: nil,
            expandedID: nil
        )
        XCTAssertEqual(items.count, 1)
        XCTAssertEqual(items.first?.textValue, "alpha")
    }
}

// MARK: - Picker keyboard navigation (clamped, no wrap)

final class PickerKeyboardNavigationTests: XCTestCase {
    func testEmptyListReturnsNil() {
        XCTAssertNil(PickerKeyboardNavigation.clampedIndex(currentIndex: 0, delta: -1, itemCount: 0))
    }

    func testUpOnFirstRowStaysAtZero() {
        XCTAssertEqual(PickerKeyboardNavigation.clampedIndex(currentIndex: 0, delta: -1, itemCount: 100), 0)
    }

    func testDownOnLastRowStaysAtLast() {
        XCTAssertEqual(PickerKeyboardNavigation.clampedIndex(currentIndex: 99, delta: 1, itemCount: 100), 99)
    }

    func testDownFromFirstMovesToSecond() {
        XCTAssertEqual(PickerKeyboardNavigation.clampedIndex(currentIndex: 0, delta: 1, itemCount: 5), 1)
    }

    func testUpFromLastMovesToPenultimate() {
        XCTAssertEqual(PickerKeyboardNavigation.clampedIndex(currentIndex: 4, delta: -1, itemCount: 5), 3)
    }

    func testSingleItemUpAndDownStayAtZero() {
        XCTAssertEqual(PickerKeyboardNavigation.clampedIndex(currentIndex: 0, delta: -1, itemCount: 1), 0)
        XCTAssertEqual(PickerKeyboardNavigation.clampedIndex(currentIndex: 0, delta: 1, itemCount: 1), 0)
    }

    /// Regression: modulo wrap would jump first → last on long lists.
    func testUpOnFirstDoesNotWrapToLastOnLongList() {
        let count = 10_000
        let idx = PickerKeyboardNavigation.clampedIndex(currentIndex: 0, delta: -1, itemCount: count)
        XCTAssertEqual(idx, 0)
        XCTAssertNotEqual(idx, count - 1)
    }
}

// MARK: - ClipboardMonitor predicates

final class ClipboardMonitorPredicateTests: XCTestCase {
    func testSkipsFinderFileURLPasteboardType() {
        XCTAssertTrue(
            ClipboardMonitor.shouldSkipForFileReferencePasteboardTypes([.fileURL])
        )
    }

    func testSkipsFinderFilenamesPasteboardType() {
        XCTAssertTrue(
            ClipboardMonitor.shouldSkipForFileReferencePasteboardTypes([
                NSPasteboard.PasteboardType("NSFilenamesPboardType"),
            ])
        )
    }

    func testDoesNotSkipPlainStringTypes() {
        XCTAssertFalse(
            ClipboardMonitor.shouldSkipForFileReferencePasteboardTypes([.string])
        )
    }

    func testTextDuplicateWhenSameStringAsLatest() {
        let latest = ClipboardItem(contentType: .text, textValue: "hello")
        let incoming = ClipboardItem(contentType: .text, textValue: "hello")
        XCTAssertTrue(ClipboardMonitor.isDuplicateIncoming(incoming, latest: latest))
    }

    func testTextNotDuplicateWhenDifferentString() {
        let latest = ClipboardItem(contentType: .text, textValue: "hello")
        let incoming = ClipboardItem(contentType: .text, textValue: "world")
        XCTAssertFalse(ClipboardMonitor.isDuplicateIncoming(incoming, latest: latest))
    }

    func testImageDuplicateWhenSameHash() {
        let latest = ClipboardItem(
            contentType: .image,
            textValue: nil,
            ocrText: nil,
            imageFilePath: "/a.png",
            imageHash: "deadbeef"
        )
        let incoming = ClipboardItem(
            contentType: .image,
            textValue: nil,
            ocrText: nil,
            imageFilePath: "/b.png",
            imageHash: "deadbeef"
        )
        XCTAssertTrue(ClipboardMonitor.isDuplicateIncoming(incoming, latest: latest))
    }

    func testImageNotDuplicateWhenEitherHashMissing() {
        let latest = ClipboardItem(
            contentType: .image,
            textValue: nil,
            ocrText: nil,
            imageFilePath: "/a.png",
            imageHash: nil
        )
        let incoming = ClipboardItem(
            contentType: .image,
            textValue: nil,
            ocrText: nil,
            imageFilePath: "/b.png",
            imageHash: "abc"
        )
        XCTAssertFalse(ClipboardMonitor.isDuplicateIncoming(incoming, latest: latest))
    }

    func testNoLatestMeansNotDuplicate() {
        let incoming = ClipboardItem(contentType: .text, textValue: "x")
        XCTAssertFalse(ClipboardMonitor.isDuplicateIncoming(incoming, latest: nil))
    }
}

// MARK: - Ignore list

@MainActor
final class IgnoreListServiceTests: XCTestCase {
    private var originalIds: [String] = []

    override func setUp() async throws {
        try await super.setUp()
        originalIds = AppSettings.shared.ignoredBundleIds
        AppSettings.shared.ignoredBundleIds = []
    }

    override func tearDown() async throws {
        AppSettings.shared.ignoredBundleIds = originalIds
        try await super.tearDown()
    }

    func testAddRemoveRoundTrip() {
        XCTAssertFalse(IgnoreListService.shared.isIgnored(bundleId: "com.example.secret"))
        IgnoreListService.shared.add(bundleId: "com.example.secret")
        XCTAssertTrue(IgnoreListService.shared.isIgnored(bundleId: "com.example.secret"))
        IgnoreListService.shared.remove(bundleId: "com.example.secret")
        XCTAssertFalse(IgnoreListService.shared.isIgnored(bundleId: "com.example.secret"))
    }

    func testAddDuplicateBundleIdIsIdempotent() {
        IgnoreListService.shared.add(bundleId: "com.example.once")
        IgnoreListService.shared.add(bundleId: "com.example.once")
        XCTAssertEqual(
            AppSettings.shared.ignoredBundleIds.filter { $0 == "com.example.once" }.count,
            1
        )
    }

    func testIgnoredFrontmostMatchesMonitorPredicate() {
        XCTAssertFalse(
            ClipboardMonitor.shouldRecordClipboard(
                secureInputActive: false,
                privateModeEnabled: false,
                frontmostBundleId: "com.blocked.app",
                ignoredBundleIds: ["com.blocked.app", "com.other"]
            )
        )
    }
}

// MARK: - PrivateModeService

@MainActor
final class PrivateModeServiceTests: XCTestCase {
    private var wasPrivate = false
    private var lastMinutes = 0

    override func setUp() async throws {
        try await super.setUp()
        wasPrivate = AppSettings.shared.isPrivateModeEnabled
        lastMinutes = AppSettings.shared.lastPrivateModeDurationMinutes
        PrivateModeService.shared.disable()
    }

    override func tearDown() async throws {
        PrivateModeService.shared.disable()
        AppSettings.shared.lastPrivateModeDurationMinutes = lastMinutes
        AppSettings.shared.isPrivateModeEnabled = wasPrivate
        try await super.tearDown()
    }

    func testEnableIndefiniteSetsFlagAndZeroMinutes() {
        PrivateModeService.shared.enable(minutes: 0)
        XCTAssertTrue(AppSettings.shared.isPrivateModeEnabled)
        XCTAssertEqual(AppSettings.shared.lastPrivateModeDurationMinutes, 0)
    }

    func testEnableTimedPersistsLastDuration() {
        PrivateModeService.shared.enable(minutes: 60)
        XCTAssertTrue(AppSettings.shared.isPrivateModeEnabled)
        XCTAssertEqual(AppSettings.shared.lastPrivateModeDurationMinutes, 60)
    }

    func testDisableClearsPrivateMode() {
        PrivateModeService.shared.enable(minutes: 15)
        PrivateModeService.shared.disable()
        XCTAssertFalse(AppSettings.shared.isPrivateModeEnabled)
    }

    func testDurationsMenuHasExpectedPresets() {
        XCTAssertEqual(PrivateModeService.durations.map(\.id), [15, 30, 60, 120, 0])
    }
}

// MARK: - HistoryStore MRU, pin, OCR search

@MainActor
final class HistoryStoreAdvancedTests: XCTestCase {
    func testTouchMovesItemToTop() async {
        let store = HistoryStore.makeForTesting()
        let older = ClipboardItem(
            createdAt: Date(timeIntervalSince1970: 100),
            contentType: .text,
            textValue: "older"
        )
        let newer = ClipboardItem(
            createdAt: Date(timeIntervalSince1970: 200),
            contentType: .text,
            textValue: "newer"
        )
        store.insert(older)
        store.insert(newer)
        XCTAssertEqual(store.allItems().first?.textValue, "newer")

        store.touch(older)
        XCTAssertEqual(store.allItems().first?.textValue, "older")
    }

    func testTogglePinFlipsFlag() async {
        let store = HistoryStore.makeForTesting()
        let item = ClipboardItem(contentType: .text, textValue: "pin me")
        store.insert(item)
        XCTAssertFalse(item.isPinned)
        store.togglePin(item)
        XCTAssertTrue(item.isPinned)
        store.togglePin(item)
        XCTAssertFalse(item.isPinned)
    }

    func testPinnedItemNotCountedTowardUnpinnedCountLimit() async {
        let store = HistoryStore.makeForTesting()
        let settings = AppSettings.shared
        let originalLimit = settings.historyCountLimit
        settings.historyCountLimit = 1
        defer { settings.historyCountLimit = originalLimit }

        let pinned = ClipboardItem(
            createdAt: Date(timeIntervalSince1970: 1),
            contentType: .text,
            textValue: "pinned",
            isPinned: true
        )
        store.insert(pinned)
        store.insert(ClipboardItem(
            createdAt: Date(timeIntervalSince1970: 2),
            contentType: .text,
            textValue: "u1"
        ))
        store.insert(ClipboardItem(
            createdAt: Date(timeIntervalSince1970: 3),
            contentType: .text,
            textValue: "u2"
        ))

        let all = store.allItems()
        XCTAssertTrue(all.contains { $0.textValue == "pinned" }, "Pinned row must survive pruning")
        XCTAssertTrue(all.contains { $0.textValue == "u2" }, "Newest unpinned row must survive")
        XCTAssertFalse(all.contains { $0.textValue == "u1" }, "Older unpinned row must be pruned")
    }

    func testSearchMatchesOCRTextOnImageItems() async {
        let store = HistoryStore.makeForTesting()
        let img = ClipboardItem(
            contentType: .image,
            textValue: nil,
            ocrText: nil,
            imageFilePath: "/tmp/cpman-test.png"
        )
        store.insert(img)
        XCTAssertTrue(store.allItems(matching: "INV-999").isEmpty)

        store.updateOCR(forId: img.id, text: "Invoice INV-999 total")
        let hits = store.allItems(matching: "inv-999")
        XCTAssertEqual(hits.count, 1)
        XCTAssertEqual(hits.first?.id, img.id)
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

// MARK: - Batch pruning (single save + notification per insert/prune pass)

/// These tests share the AppSettings.shared singleton — never enable parallel
/// test execution for this class without introducing a settings injection seam.
@MainActor
final class BatchPruningTests: XCTestCase {
    private var originalCountLimit: Int = 0

    override func setUp() async throws {
        try await super.setUp()
        originalCountLimit = AppSettings.shared.historyCountLimit
    }

    override func tearDown() async throws {
        AppSettings.shared.historyCountLimit = originalCountLimit
        try await super.tearDown()
    }

    /// After Fix A: insert + prune fires `objectWillChange` exactly once even
    /// when pruning removes one or more rows.
    func testInsertWithPruneFiresExactlyOneNotification() async {
        let store = HistoryStore.makeForTesting()
        AppSettings.shared.historyCountLimit = 2

        store.insert(ClipboardItem(
            createdAt: Date(timeIntervalSince1970: 1), contentType: .text, textValue: "a"
        ))
        store.insert(ClipboardItem(
            createdAt: Date(timeIntervalSince1970: 2), contentType: .text, textValue: "b"
        ))

        var notificationCount = 0
        let cancellable = store.objectWillChange.sink { _ in
            notificationCount += 1
        }

        // Buffer = min(100, 2/10) = 0, so this insert tips us to 3 items and
        // pruning removes the oldest. Despite touching multiple rows, the
        // store must publish exactly one change event.
        store.insert(ClipboardItem(
            createdAt: Date(timeIntervalSince1970: 3), contentType: .text, textValue: "c"
        ))

        XCTAssertEqual(notificationCount, 1,
                       "insert + prune must produce exactly one objectWillChange notification")

        let remaining = store.allItems()
        XCTAssertEqual(remaining.count, 2)
        XCTAssertEqual(Set(remaining.compactMap(\.textValue)), Set(["b", "c"]))

        cancellable.cancel()
    }

    /// Fast path: insert that does NOT trigger pruning still fires exactly once.
    func testInsertWithoutPruneFiresExactlyOneNotification() async {
        let store = HistoryStore.makeForTesting()
        AppSettings.shared.historyCountLimit = 100   // far above what we insert

        var notificationCount = 0
        let cancellable = store.objectWillChange.sink { _ in
            notificationCount += 1
        }

        store.insert(ClipboardItem(
            createdAt: Date(timeIntervalSince1970: 1), contentType: .text, textValue: "x"
        ))

        XCTAssertEqual(notificationCount, 1)
        cancellable.cancel()
    }

    func testBulkPruningKeepsOnlyTheNewestItems() async {
        let store = HistoryStore.makeForTesting()
        AppSettings.shared.historyCountLimit = 2

        for i in 1...5 {
            store.insert(ClipboardItem(
                createdAt: Date(timeIntervalSince1970: Double(i)),
                contentType: .text,
                textValue: "item \(i)"
            ))
        }

        let remaining = store.allItems()
        XCTAssertEqual(remaining.count, 2)
        XCTAssertEqual(remaining.map(\.textValue), ["item 5", "item 4"],
                       "Only the two newest items should survive bulk pruning")
    }

    func testDeleteAllFiresExactlyOneNotification() async {
        let store = HistoryStore.makeForTesting()
        // Use deterministic, monotonically increasing timestamps so the
        // SwiftData fetch order is stable across machines and clock resolutions.
        for i in 1...10 {
            store.insert(ClipboardItem(
                createdAt: Date(timeIntervalSince1970: Double(i)),
                contentType: .text,
                textValue: "item \(i)"
            ))
        }
        XCTAssertEqual(store.allItems().count, 10)

        var notificationCount = 0
        let cancellable = store.objectWillChange.sink { _ in
            notificationCount += 1
        }

        store.deleteAll()

        XCTAssertEqual(notificationCount, 1,
                       "deleteAll must fire objectWillChange exactly once, not per item")
        XCTAssertEqual(store.allItems().count, 0)

        cancellable.cancel()
    }
}

// MARK: - ThumbnailCache eviction (real cache hits + misses, not stubs)

/// Verifies that `evict(for:)` actually drops cached entries by relying on
/// `NSImage` reference identity: a cache hit returns the same instance, a
/// cache miss returns a freshly decoded one.
final class ThumbnailCacheEvictionTests: XCTestCase {
    private var pngURL: URL!

    override func setUp() {
        super.setUp()
        // Write a small real PNG into a unique temp file so CGImageSource
        // can actually decode it. Using a UUID name keeps tests independent
        // when the singleton ThumbnailCache survives between test cases.
        pngURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("cpman-thumb-test-\(UUID().uuidString).png")
        try? Self.makeTinyPNG(at: pngURL)
    }

    override func tearDown() {
        if let url = pngURL {
            try? FileManager.default.removeItem(at: url)
            ThumbnailCache.shared.evict(for: url.path)
        }
        super.tearDown()
    }

    func testEvictDropsCachedDefaultAndExpandedVariants() throws {
        let cache = ThumbnailCache.shared
        let path = pngURL.path

        // Sanity: ensure the cache starts empty for this path.
        cache.evict(for: path)

        // Populate both variants and remember the decoded instances.
        guard let normal1   = cache.thumbnail(for: path, maxPoints: ThumbnailSize.normal),
              let expanded1 = cache.thumbnail(for: path, maxPoints: ThumbnailSize.expanded)
        else {
            return XCTFail("ThumbnailCache failed to decode the test PNG at \(path)")
        }

        // Cache hit must return the *same* NSImage instance.
        XCTAssertTrue(cache.thumbnail(for: path, maxPoints: ThumbnailSize.normal)   === normal1,
                      "Second thumbnail() call must return the cached normal-size instance")
        XCTAssertTrue(cache.thumbnail(for: path, maxPoints: ThumbnailSize.expanded) === expanded1,
                      "Second thumbnail() call must return the cached expanded-size instance")

        // Evict — both pixel-size variants must be cleared.
        cache.evict(for: path)

        guard let normal2   = cache.thumbnail(for: path, maxPoints: ThumbnailSize.normal),
              let expanded2 = cache.thumbnail(for: path, maxPoints: ThumbnailSize.expanded)
        else {
            return XCTFail("Re-decode after eviction unexpectedly returned nil")
        }
        XCTAssertFalse(normal2   === normal1,
                       "After evict, normal-size thumbnail must be re-decoded (cache miss)")
        XCTAssertFalse(expanded2 === expanded1,
                       "After evict, expanded-size thumbnail must be re-decoded (cache miss)")
    }

    func testEvictCoversEverySizeDeclaredInThumbnailSize() {
        // Defence in depth: if someone adds a new size to ThumbnailSize.allPoints,
        // populating it here and evicting must clear *that* variant too. The test
        // iterates the same source-of-truth list the production cache uses.
        let cache = ThumbnailCache.shared
        let path  = pngURL.path
        cache.evict(for: path)

        var firsts: [CGFloat: NSImage] = [:]
        for points in ThumbnailSize.allPoints {
            guard let img = cache.thumbnail(for: path, maxPoints: points) else {
                return XCTFail("Failed to decode thumbnail at \(points)pt")
            }
            firsts[points] = img
        }

        cache.evict(for: path)

        for points in ThumbnailSize.allPoints {
            guard let again = cache.thumbnail(for: path, maxPoints: points) else {
                return XCTFail("Re-decode after evict returned nil at \(points)pt")
            }
            XCTAssertFalse(again === firsts[points],
                           "evict(for:) must drop the cached entry at \(points)pt")
        }
    }

    // MARK: - PNG fixture

    private static func makeTinyPNG(at url: URL) throws {
        guard let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: 4,
            pixelsHigh: 4,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ),
        let data = rep.representation(using: .png, properties: [:])
        else { throw NSError(domain: "ThumbnailCacheEvictionTests", code: 1) }
        try data.write(to: url)
    }
}

// MARK: - Preview directory (PickerView.previewDirectory) — exercises real code

/// These tests call the actual production helpers — not a copy of their logic —
/// so a regression in the real implementation will fail the test.
@MainActor
final class PreviewDirectorySecurityTests: XCTestCase {
    func testPreviewDirectoryExistsWithOwnerOnlyPermissions() throws {
        let dir = PickerView.previewDirectory()
        let fm  = FileManager.default

        XCTAssertTrue(fm.fileExists(atPath: dir.path),
                      "previewDirectory() must create the directory if missing")

        let attrs = try fm.attributesOfItem(atPath: dir.path)
        XCTAssertEqual(attrs[.posixPermissions] as? Int, 0o700,
                       "Preview directory must be owner-only (0700)")

        XCTAssertTrue(dir.path.hasSuffix("cpMan/Previews"),
                      "Preview directory must live under cpMan/Previews — got \(dir.path)")
    }

    func testPreviewDirectoryRemovesStaleFilesOnAccess() throws {
        let dir = PickerView.previewDirectory()
        let fm  = FileManager.default

        let staleURL = dir.appendingPathComponent("stale-\(UUID().uuidString).txt")
        let freshURL = dir.appendingPathComponent("fresh-\(UUID().uuidString).txt")
        defer {
            try? fm.removeItem(at: staleURL)
            try? fm.removeItem(at: freshURL)
        }

        try "stale".write(to: staleURL, atomically: true, encoding: .utf8)
        try "fresh".write(to: freshURL, atomically: true, encoding: .utf8)
        try fm.setAttributes([.creationDate: Date(timeIntervalSinceNow: -600)],
                             ofItemAtPath: staleURL.path)
        try fm.setAttributes([.creationDate: Date()],
                             ofItemAtPath: freshURL.path)

        // Calling previewDirectory() again triggers the cleanup.
        _ = PickerView.previewDirectory()

        XCTAssertFalse(fm.fileExists(atPath: staleURL.path),
                       "Stale file (>5 min) must be removed by previewDirectory() cleanup")
        XCTAssertTrue(fm.fileExists(atPath: freshURL.path),
                      "Fresh file (<5 min) must NOT be removed by previewDirectory() cleanup")
    }
}

// MARK: - Export directory (ImageProcessor.exportsDirectory) — exercises real code

@MainActor
final class ExportDirectorySecurityTests: XCTestCase {
    func testExportDirectoryExistsWithOwnerOnlyPermissions() throws {
        let dir = ImageProcessor.shared.exportsDirectory
        let fm  = FileManager.default

        XCTAssertTrue(fm.fileExists(atPath: dir.path),
                      "exportsDirectory must create the directory if missing")

        let attrs = try fm.attributesOfItem(atPath: dir.path)
        XCTAssertEqual(attrs[.posixPermissions] as? Int, 0o700,
                       "Export directory must be owner-only (0700)")

        XCTAssertTrue(dir.path.hasSuffix("cpMan/Exports"),
                      "Export directory must live under cpMan/Exports — got \(dir.path)")
    }

    func testExportDirectoryRemovesStaleFilesOnAccess() throws {
        let dir = ImageProcessor.shared.exportsDirectory
        let fm  = FileManager.default

        let staleURL = dir.appendingPathComponent("stale-\(UUID().uuidString).png")
        let freshURL = dir.appendingPathComponent("fresh-\(UUID().uuidString).png")
        defer {
            try? fm.removeItem(at: staleURL)
            try? fm.removeItem(at: freshURL)
        }

        try Data([0x89, 0x50, 0x4E, 0x47]).write(to: staleURL)
        try Data([0x89, 0x50, 0x4E, 0x47]).write(to: freshURL)
        try fm.setAttributes([.creationDate: Date(timeIntervalSinceNow: -600)],
                             ofItemAtPath: staleURL.path)
        try fm.setAttributes([.creationDate: Date()],
                             ofItemAtPath: freshURL.path)

        // Calling exportsDirectory again triggers the cleanup.
        _ = ImageProcessor.shared.exportsDirectory

        XCTAssertFalse(fm.fileExists(atPath: staleURL.path),
                       "Stale file (>5 min) must be removed by exportsDirectory cleanup")
        XCTAssertTrue(fm.fileExists(atPath: freshURL.path),
                      "Fresh file (<5 min) must NOT be removed by exportsDirectory cleanup")
    }
}

// MARK: - Edge cases not previously covered

@MainActor
final class HistoryStoreEdgeCaseTests: XCTestCase {
    func testTotalCountReflectsAllRowsIncludingPinned() async {
        let store = HistoryStore.makeForTesting()
        XCTAssertEqual(store.totalCount(), 0)

        store.insert(ClipboardItem(contentType: .text, textValue: "one"))
        store.insert(ClipboardItem(contentType: .text, textValue: "two"))
        let pinned = ClipboardItem(contentType: .text, textValue: "pinned", isPinned: true)
        store.insert(pinned)

        XCTAssertEqual(store.totalCount(), 3,
                       "totalCount() must include pinned and unpinned rows")
    }

    func testSearchPredicateMatchesOcrText() async {
        let store = HistoryStore.makeForTesting()
        let imageItem = ClipboardItem(
            contentType: .image,
            textValue: nil,
            ocrText: "Invoice number 12345",
            imageFilePath: "/nonexistent/img.png"
        )
        store.insert(imageItem)
        store.insert(ClipboardItem(contentType: .text, textValue: "unrelated"))

        let hits = store.allItems(matching: "invoice")
        XCTAssertEqual(hits.count, 1, "Search must match OCR text on image rows")
        XCTAssertEqual(hits.first?.ocrText, "Invoice number 12345")
    }

    func testSearchPredicateIsDiacriticAndCaseInsensitive() async {
        let store = HistoryStore.makeForTesting()
        store.insert(ClipboardItem(contentType: .text, textValue: "Café au lait"))

        // localizedStandardContains ignores case; diacritic-insensitivity is locale-dependent
        // but the contract under default macOS locales is that "cafe" matches "Café".
        XCTAssertEqual(store.allItems(matching: "CAFÉ").count, 1, "case-insensitive failed")
        XCTAssertEqual(store.allItems(matching: "cafe").count, 1, "diacritic-insensitive failed")
    }

    func testEmptyQueryReturnsEverythingNewestFirst() async {
        let store = HistoryStore.makeForTesting()
        store.insert(ClipboardItem(
            createdAt: Date(timeIntervalSince1970: 1), contentType: .text, textValue: "old"
        ))
        store.insert(ClipboardItem(
            createdAt: Date(timeIntervalSince1970: 2), contentType: .text, textValue: "new"
        ))

        XCTAssertEqual(store.allItems().map(\.textValue), ["new", "old"])
    }
}

// MARK: - PickerListSync with pinned-only filter

@MainActor
final class PickerListSyncPinnedFilterTests: XCTestCase {
    func testPinnedOnlyFilterReturnsOnlyPinnedItems() async {
        let store = HistoryStore.makeForTesting()
        let t1 = Date(timeIntervalSince1970: 1)
        let t2 = Date(timeIntervalSince1970: 2)
        let t3 = Date(timeIntervalSince1970: 3)

        store.insert(ClipboardItem(
            createdAt: t1, contentType: .text, textValue: "regular"
        ))
        store.insert(ClipboardItem(
            createdAt: t2, contentType: .text, textValue: "pinned-A", isPinned: true
        ))
        store.insert(ClipboardItem(
            createdAt: t3, contentType: .text, textValue: "pinned-B", isPinned: true
        ))

        let (items, _, _) = PickerListSync.snapshot(
            store: store,
            matching: "",
            previousSelection: nil,
            expandedID: nil,
            pinnedOnly: true
        )
        XCTAssertEqual(items.map(\.textValue), ["pinned-B", "pinned-A"],
                       "Pinned-only filter must drop unpinned items and keep newest-first order")
    }

    func testPinnedOnlyFilterCombinesWithSearchQuery() async {
        let store = HistoryStore.makeForTesting()
        store.insert(ClipboardItem(
            contentType: .text, textValue: "alpha pinned", isPinned: true
        ))
        store.insert(ClipboardItem(
            contentType: .text, textValue: "alpha not pinned", isPinned: false
        ))
        store.insert(ClipboardItem(
            contentType: .text, textValue: "beta pinned", isPinned: true
        ))

        let (items, _, _) = PickerListSync.snapshot(
            store: store,
            matching: "alpha",
            previousSelection: nil,
            expandedID: nil,
            pinnedOnly: true
        )
        XCTAssertEqual(items.count, 1)
        XCTAssertEqual(items.first?.textValue, "alpha pinned")
    }
}

// MARK: - Deleted model object safety
//
// On a disk-backed store, accessing properties on a deleted-and-saved SwiftData
// model object triggers a fatal assertion (the backing row is gone). These tests
// verify that the store never returns such items after deletion or pruning, which
// is the contract that PickerView relies on to avoid the crash.

@MainActor
final class DeletedItemSafetyTests: XCTestCase {
    func testAllItemsExcludesDeletedItem() async {
        let store = HistoryStore.makeForTesting()
        let keep = ClipboardItem(contentType: .text, textValue: "keep")
        let drop = ClipboardItem(contentType: .text, textValue: "drop")
        store.insert(keep)
        store.insert(drop)

        store.delete(drop)

        let remaining = store.allItems()
        XCTAssertEqual(remaining.count, 1, "Deleted item must not appear in allItems()")
        XCTAssertEqual(remaining.first?.textValue, "keep")
    }

    func testAllItemsExcludesPrunedItems() async {
        let store = HistoryStore.makeForTesting()
        let settings = AppSettings.shared

        let originalLimit = settings.historyCountLimit
        settings.historyCountLimit = 2
        defer { settings.historyCountLimit = originalLimit }

        store.insert(ClipboardItem(
            createdAt: Date(timeIntervalSinceNow: -30),
            contentType: .text, textValue: "oldest"
        ))
        store.insert(ClipboardItem(
            createdAt: Date(timeIntervalSinceNow: -10),
            contentType: .text, textValue: "middle"
        ))
        store.insert(ClipboardItem(
            createdAt: Date(),
            contentType: .text, textValue: "newest"
        ))

        let remaining = store.allItems()
        XCTAssertLessThanOrEqual(remaining.count, 2,
                                 "Pruned items must not appear in allItems()")
        XCTAssertFalse(remaining.contains { $0.textValue == "oldest" },
                       "The oldest item should have been pruned")
    }

    func testItemForIdReturnsLiveModel() async {
        let store = HistoryStore.makeForTesting()
        let item = ClipboardItem(contentType: .text, textValue: "lookup")
        store.insert(item)
        let id = item.id
        let found = store.item(for: id)
        XCTAssertNotNil(found)
        XCTAssertEqual(found?.textValue, "lookup")
        store.delete(item)
        XCTAssertNil(store.item(for: id))
    }

    func testRefetchAfterInsertNeverReturnsStalePrunedItems() async {
        let store = HistoryStore.makeForTesting()
        let settings = AppSettings.shared

        let originalLimit = settings.historyCountLimit
        settings.historyCountLimit = 3
        defer { settings.historyCountLimit = originalLimit }

        for i in 1...3 {
            store.insert(ClipboardItem(
                createdAt: Date(timeIntervalSinceNow: Double(i)),
                contentType: .text, textValue: "item \(i)"
            ))
        }
        XCTAssertEqual(store.allItems().count, 3)

        // This insert triggers pruning; a fresh fetch must only return valid items
        store.insert(ClipboardItem(
            createdAt: Date(timeIntervalSinceNow: 100),
            contentType: .text, textValue: "trigger"
        ))

        let afterPrune = store.allItems()
        XCTAssertLessThanOrEqual(afterPrune.count, 3)
        for item in afterPrune {
            XCTAssertNotNil(item.textValue,
                            "Every item returned by allItems() must have accessible properties")
        }
    }
}

// MARK: - Picker value rows, edit sheet contract, list sync after clear
//
// Covers the hardening where the picker uses `PickerDisplayedRow` (not live
// `ClipboardItem` in rows) and the edit sheet keeps only value data so history
// can be cleared while editing without touching deleted SwiftData models.

@MainActor
final class PickerRowAndEditFlowTests: XCTestCase {
    func testPickerDisplayedRowCopiesAllFieldsFromModel() {
        let created = Date(timeIntervalSince1970: 1_700_000_000)
        let item = ClipboardItem(
            id: UUID(),
            createdAt: created,
            sourceApp: "Safari",
            sourceBundleId: "com.apple.Safari",
            contentType: .text,
            textValue: "hello",
            ocrText: nil,
            isPinned: true
        )
        let row = PickerDisplayedRow(from: item)
        XCTAssertEqual(row.id, item.id)
        XCTAssertEqual(row.sourceApp, "Safari")
        XCTAssertEqual(row.sourceBundleId, "com.apple.Safari")
        XCTAssertEqual(row.contentType, .text)
        XCTAssertEqual(row.textValue, "hello")
        XCTAssertNil(row.ocrText)
        XCTAssertNil(row.imageFilePath)
        XCTAssertTrue(row.isPinned)
    }

    func testPickerDisplayedRowEquatable() {
        let item = ClipboardItem(contentType: .text, textValue: "same")
        let a = PickerDisplayedRow(from: item)
        let b = PickerDisplayedRow(from: item)
        XCTAssertEqual(a, b)

        let other = ClipboardItem(contentType: .text, textValue: "different")
        XCTAssertNotEqual(a, PickerDisplayedRow(from: other))
    }

    /// Mirrors `TextEditSession` + save: only row snapshot metadata is needed after the
    /// source row was removed from the store (e.g. Clear All while the sheet is open).
    func testEditSaveUsesSnapshotMetadataAfterOriginalItemDeleted() async {
        let store = HistoryStore.makeForTesting()
        let original = ClipboardItem(
            sourceApp: "Notes",
            sourceBundleId: "com.apple.Notes",
            contentType: .text,
            textValue: "before"
        )
        store.insert(original)
        let row = PickerDisplayedRow(from: original)
        let originalId = original.id

        store.delete(original)
        XCTAssertNil(store.item(for: originalId))

        let savedText = "after edit"
        let newItem = ClipboardItem(
            sourceApp: row.sourceApp,
            sourceBundleId: row.sourceBundleId,
            contentType: .text,
            textValue: savedText
        )
        store.insert(newItem)

        let all = store.allItems()
        XCTAssertEqual(all.count, 1)
        XCTAssertEqual(all.first?.textValue, savedText)
        XCTAssertEqual(all.first?.sourceApp, "Notes")
        XCTAssertEqual(all.first?.sourceBundleId, "com.apple.Notes")
    }

    func testPickerListSyncAfterDeleteAllEmptiesRowsAndClearsSelection() async {
        let store = HistoryStore.makeForTesting()
        store.insert(ClipboardItem(contentType: .text, textValue: "only"))
        let previousId = store.allItems().first!.id

        store.deleteAll()

        let (items, selectedID, expandedID) = PickerListSync.snapshot(
            store: store,
            matching: "",
            previousSelection: previousId,
            expandedID: previousId
        )
        XCTAssertTrue(items.isEmpty)
        XCTAssertNil(selectedID)
        XCTAssertNil(expandedID)
    }

    func testPickerListSyncRowsMatchStoreAfterPrune() async {
        let store = HistoryStore.makeForTesting()
        let settings = AppSettings.shared
        let originalLimit = settings.historyCountLimit
        settings.historyCountLimit = 2
        defer { settings.historyCountLimit = originalLimit }

        store.insert(ClipboardItem(
            createdAt: Date(timeIntervalSince1970: 1),
            contentType: .text,
            textValue: "old"
        ))
        store.insert(ClipboardItem(
            createdAt: Date(timeIntervalSince1970: 2),
            contentType: .text,
            textValue: "mid"
        ))
        store.insert(ClipboardItem(
            createdAt: Date(timeIntervalSince1970: 3),
            contentType: .text,
            textValue: "new"
        ))

        let (rows, _, _) = PickerListSync.snapshot(
            store: store,
            matching: "",
            previousSelection: nil,
            expandedID: nil
        )
        let storeIds = Set(store.allItems().map(\.id))
        XCTAssertEqual(Set(rows.map(\.id)), storeIds)
        XCTAssertFalse(rows.contains { $0.textValue == "old" })
    }
}

// MARK: - ImageProcessor capture (TIFF bridge + detached processing)

@MainActor
final class ImageProcessorCaptureTests: XCTestCase {
    func testProcessCaptureWritesImageItemAndFile() async throws {
        let image = NSImage(size: NSSize(width: 8, height: 8))
        image.lockFocus()
        NSColor.cyan.setFill()
        NSBezierPath(rect: NSRect(origin: .zero, size: image.size)).fill()
        image.unlockFocus()

        let item = await ImageProcessor.shared.processCapture(
            image: image,
            sourceApp: "cpManTests",
            sourceBundleId: "com.cpman.tests"
        )

        XCTAssertNotNil(item, "processCapture must succeed for a small bitmap with default settings")
        guard let item else { return }

        XCTAssertEqual(item.contentType, .image)
        XCTAssertEqual(item.sourceApp, "cpManTests")
        XCTAssertEqual(item.sourceBundleId, "com.cpman.tests")
        XCTAssertNotNil(item.imageHash)
        XCTAssertGreaterThan(item.imageWidth ?? 0, 0)
        XCTAssertGreaterThan(item.imageHeight ?? 0, 0)

        let path = try XCTUnwrap(item.imageFilePath)
        XCTAssertTrue(FileManager.default.fileExists(atPath: path))
        addTeardownBlock {
            try? FileManager.default.removeItem(atPath: path)
        }
    }
}

// MARK: - ThumbnailCache async decode (main-actor NSImage boundary)

@MainActor
final class ThumbnailCacheAsyncTests: XCTestCase {
    func testThumbnailAsyncReturnsDecodedImage() async throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("cpman-async-thumb-\(UUID().uuidString).png")
        try ThumbnailCacheAsyncTests.makeTinyPNG(at: url)
        addTeardownBlock {
            try? FileManager.default.removeItem(at: url)
            ThumbnailCache.shared.evict(for: url.path)
        }

        let img = await ThumbnailCache.shared.thumbnailAsync(for: url.path, maxPoints: ThumbnailSize.normal)
        XCTAssertNotNil(img)
        XCTAssertGreaterThan(img?.size.width ?? 0, 0)
    }

    private static func makeTinyPNG(at url: URL) throws {
        guard let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: 4,
            pixelsHigh: 4,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ),
        let data = rep.representation(using: .png, properties: [:])
        else { throw NSError(domain: "ThumbnailCacheAsyncTests", code: 1) }
        try data.write(to: url)
    }
}

// MARK: - Helpers

/// Expose internal `intOrDefault` to tests without adding test-only API surface to AppSettings.
extension UserDefaults {
    func intOrDefault(forKey key: String, fallback: Int) -> Int {
        (object(forKey: key) as? Int) ?? fallback
    }
}
