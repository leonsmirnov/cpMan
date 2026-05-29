import AppKit
import XCTest
@testable import cpMan

// MARK: - ClipboardItem model

final class ClipboardItemModelTests: XCTestCase {
    func testTextItemCreation() {
        let item = ClipboardItem(textValue: "hello")
        XCTAssertEqual(item.textValue, "hello")
        XCTAssertNil(item.sourceApp)
        XCTAssertNil(item.sourceBundleId)
    }

    func testUUIDIsUnique() {
        let a = ClipboardItem(textValue: "a")
        let b = ClipboardItem(textValue: "b")
        XCTAssertNotEqual(a.id, b.id)
    }

    func testCreatedAtIsRecentlyNow() {
        let before = Date()
        let item   = ClipboardItem(textValue: "time")
        let after  = Date()
        XCTAssert(item.createdAt >= before)
        XCTAssert(item.createdAt <= after)
    }

    func testCodableRoundTrip() throws {
        let original = ClipboardItem(
            sourceApp: "Notes",
            sourceBundleId: "com.apple.Notes",
            textValue: "round trip"
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(original)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(ClipboardItem.self, from: data)

        XCTAssertEqual(decoded.id, original.id)
        XCTAssertEqual(decoded.sourceApp, original.sourceApp)
        XCTAssertEqual(decoded.sourceBundleId, original.sourceBundleId)
        XCTAssertEqual(decoded.textValue, original.textValue)
    }
}

// MARK: - HistoryStore (in-memory)

@MainActor
final class HistoryStoreTests: XCTestCase {
    func testInsertPutsItemAtTop() {
        let store = HistoryStore.makeForTesting()
        store.insert(ClipboardItem(textValue: "one"))
        store.insert(ClipboardItem(textValue: "two"))
        XCTAssertEqual(store.items.map(\.textValue), ["two", "one"])
    }

    func testInsertOfDuplicateTopItemIsIgnored() {
        let store = HistoryStore.makeForTesting()
        store.insert(ClipboardItem(textValue: "same"))
        store.insert(ClipboardItem(textValue: "same"))
        XCTAssertEqual(store.items.count, 1,
                       "Repeating the top item must not create a new entry")
    }

    func testInsertOfDuplicateNonTopItemAddsNewEntry() {
        let store = HistoryStore.makeForTesting()
        store.insert(ClipboardItem(textValue: "a"))
        store.insert(ClipboardItem(textValue: "b"))
        store.insert(ClipboardItem(textValue: "a"))
        XCTAssertEqual(store.items.map(\.textValue), ["a", "b", "a"],
                       "Re-copying an older value moves to the top as a new entry")
    }

    func testHardCapTrimsOldestFirst() {
        let store = HistoryStore.makeForTesting()
        for i in 0..<(HistoryStore.maxItems + 25) {
            store.insert(ClipboardItem(textValue: "item-\(i)"))
        }
        XCTAssertEqual(store.items.count, HistoryStore.maxItems)
        XCTAssertEqual(store.items.first?.textValue, "item-\(HistoryStore.maxItems + 24)")
        XCTAssertEqual(store.items.last?.textValue, "item-25",
                       "Anything older than the top \(HistoryStore.maxItems) must be discarded")
    }

    func testDeleteRemovesItem() {
        let store = HistoryStore.makeForTesting()
        let drop = ClipboardItem(textValue: "drop")
        store.insert(ClipboardItem(textValue: "keep"))
        store.insert(drop)
        store.delete(id: drop.id)
        XCTAssertEqual(store.items.map(\.textValue), ["keep"])
    }

    func testTouchMovesItemToTop() {
        let store = HistoryStore.makeForTesting()
        let older = ClipboardItem(textValue: "older")
        store.insert(older)
        store.insert(ClipboardItem(textValue: "newer"))
        XCTAssertEqual(store.items.first?.textValue, "newer")
        store.touch(id: older.id)
        XCTAssertEqual(store.items.first?.textValue, "older")
    }

    func testSearchIsCaseAndDiacriticInsensitive() {
        let store = HistoryStore.makeForTesting()
        store.insert(ClipboardItem(textValue: "Café au lait"))
        XCTAssertEqual(store.all(matching: "CAFÉ").count, 1)
        XCTAssertEqual(store.all(matching: "cafe").count, 1)
    }

    func testEmptyQueryReturnsAllNewestFirst() {
        let store = HistoryStore.makeForTesting()
        store.insert(ClipboardItem(textValue: "old"))
        store.insert(ClipboardItem(textValue: "new"))
        XCTAssertEqual(store.all().map(\.textValue), ["new", "old"])
    }

    func testItemForIdReturnsLiveValue() {
        let store = HistoryStore.makeForTesting()
        let item = ClipboardItem(textValue: "lookup")
        store.insert(item)
        XCTAssertEqual(store.item(for: item.id)?.textValue, "lookup")
        store.delete(id: item.id)
        XCTAssertNil(store.item(for: item.id))
    }

    func testReplaceAllReplacesHistory() {
        let store = HistoryStore.makeForTesting()
        store.insert(ClipboardItem(textValue: "before"))
        store.replaceAll(with: [
            ClipboardItem(textValue: "after-1"),
            ClipboardItem(textValue: "after-2")
        ])
        XCTAssertEqual(store.items.map(\.textValue), ["after-1", "after-2"])
    }

    func testLoadDemoContentSeedsMultipleItems() {
        let store = HistoryStore.makeForTesting()
        store.loadDemoContent()
        XCTAssertGreaterThanOrEqual(store.items.count, 10)
        XCTAssertTrue(store.all(matching: "meeting").contains { $0.textValue.localizedStandardContains("meeting") })
    }
}

// MARK: - Demo mode

@MainActor
final class DemoModeTests: XCTestCase {
    override func setUp() {
        super.setUp()
        DemoMode.deactivate()
    }

    override func tearDown() {
        DemoMode.deactivate()
        super.tearDown()
    }

    func testApplyOnLaunchWithoutFlagDoesNotSeed() {
        let store = HistoryStore.makeForTesting()
        DemoMode.applyOnLaunch(to: store)
        XCTAssertTrue(store.items.isEmpty)
        XCTAssertFalse(DemoMode.isActive)
    }

    func testLoadDemoContentViaMenuPath() {
        let store = HistoryStore.makeForTesting()
        DemoMode.reloadDemoContent(in: store)
        XCTAssertGreaterThanOrEqual(store.items.count, 10)
        XCTAssertTrue(DemoMode.isActive)
    }

    func testClearDemoContentEmptiesStore() {
        let store = HistoryStore.makeForTesting()
        DemoMode.reloadDemoContent(in: store)
        DemoMode.clearDemoContent(in: store)
        XCTAssertTrue(store.items.isEmpty)
        XCTAssertFalse(DemoMode.isActive)
    }
}

// MARK: - Demo seed data

final class DemoSeedDataTests: XCTestCase {
    func testSeedItemsAreNonEmptyText() {
        for item in DemoSeedData.makeItems() {
            XCTAssertFalse(item.textValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
    }

    func testSeedItemsIncludeMultipleSourceApps() {
        let apps = Set(DemoSeedData.makeItems().compactMap(\.sourceApp))
        XCTAssertGreaterThanOrEqual(apps.count, 4)
    }
}

// MARK: - ClipboardMonitor predicates

final class ClipboardMonitorPredicateTests: XCTestCase {
    func testSkipsFinderFileURLPasteboardType() {
        XCTAssertTrue(
            ClipboardMonitor.shouldSkipForFileReferencePasteboardTypes([.fileURL])
        )
    }

    func testSkipsLegacyFilenamesPasteboardType() {
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
        let latest = ClipboardItem(textValue: "hello")
        let incoming = ClipboardItem(textValue: "hello")
        XCTAssertTrue(ClipboardMonitor.isDuplicateIncoming(incoming, latest: latest))
    }

    func testTextNotDuplicateWhenDifferentString() {
        let latest = ClipboardItem(textValue: "hello")
        let incoming = ClipboardItem(textValue: "world")
        XCTAssertFalse(ClipboardMonitor.isDuplicateIncoming(incoming, latest: latest))
    }

    func testNoLatestMeansNotDuplicate() {
        let incoming = ClipboardItem(textValue: "x")
        XCTAssertFalse(ClipboardMonitor.isDuplicateIncoming(incoming, latest: nil))
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

// MARK: - PickerListSync (live history while picker is open)

@MainActor
final class PickerListSyncTests: XCTestCase {
    /// When a newer copy lands at the top, selection must stay on the same item id (no jump to row 1).
    func testNewInsertAtTopKeepsSelectionOnSameItem() {
        let store = HistoryStore.makeForTesting()
        let a = ClipboardItem(textValue: "a")
        let b = ClipboardItem(textValue: "b")
        store.insert(a)
        store.insert(b)
        XCTAssertEqual(store.items.map(\.textValue), ["b", "a"])

        store.insert(ClipboardItem(textValue: "c"))

        let snapshot = PickerListSync.snapshot(
            store: store,
            matching: "",
            previousSelection: a.id
        )
        XCTAssertEqual(snapshot.items.map(\.textValue), ["c", "b", "a"])
        XCTAssertEqual(snapshot.selectedID, a.id,
                       "Highlight must remain on the previously selected row")
    }

    func testSelectionResetsToFirstWhenPreviousRowRemoved() {
        let store = HistoryStore.makeForTesting()
        let gone = UUID()
        let keep = ClipboardItem(textValue: "only")
        store.insert(keep)

        let snapshot = PickerListSync.snapshot(
            store: store,
            matching: "",
            previousSelection: gone
        )
        XCTAssertEqual(snapshot.items.count, 1)
        XCTAssertEqual(snapshot.selectedID, keep.id)
    }

    func testSearchQueryReflectedInSnapshot() {
        let store = HistoryStore.makeForTesting()
        store.insert(ClipboardItem(textValue: "alpha"))
        store.insert(ClipboardItem(textValue: "beta"))

        let snapshot = PickerListSync.snapshot(
            store: store,
            matching: "alp",
            previousSelection: nil
        )
        XCTAssertEqual(snapshot.items.count, 1)
        XCTAssertEqual(snapshot.items.first?.textValue, "alpha")
    }

    func testEmptyStoreYieldsNoSelection() {
        let store = HistoryStore.makeForTesting()
        let snapshot = PickerListSync.snapshot(
            store: store,
            matching: "",
            previousSelection: UUID()
        )
        XCTAssertTrue(snapshot.items.isEmpty)
        XCTAssertNil(snapshot.selectedID)
    }
}

// MARK: - Preview directory (PickerView.previewDirectory) — exercises real code

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
