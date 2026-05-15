import AppKit
import Combine
import SwiftUI

/// Floating picker that lists the most recent text clips.
///
/// Interaction contract:
///   • Selecting a row writes its text to `NSPasteboard.general` and closes
///     the panel. The user then pastes with ⌘V into the previously active app.
///   • Search filters the list as the user types.
///   • Arrow keys navigate, Return commits, Space opens the row in TextEdit,
///     digits 1–9 quick-select, Esc dismisses.
struct PickerView: View {
    let onSelect:  (ClipboardItem) -> Void
    let onDismiss: () -> Void

    /// Fired by the hotkey handler when the picker is already visible.
    /// Each emission moves the selection one step down.
    var navigateDownPublisher: AnyPublisher<Void, Never>? = nil

    /// Fired on every panel `show()` so the list resets — `onAppear` is not
    /// reliable for a `NSHostingView` that's repeatedly hidden and shown.
    var refreshPublisher: AnyPublisher<Void, Never>? = nil

    @EnvironmentObject private var store: HistoryStore

    @State private var searchText     = ""
    @State private var debouncedQuery = ""
    @State private var debounceTask:  Task<Void, Never>?

    @State private var displayedItems: [PickerDisplayedRow] = []

    /// UUID-keyed selection — never goes stale when the list reorders, unlike
    /// an integer index which would silently point at a different item after
    /// any insert / sort change.
    @State private var selectedID: UUID? = nil

    /// Bumped on every `reload()` so we re-scroll the list to `selectedID` even
    /// when the id is unchanged (SwiftUI skips `onChange(of:)` for equal values).
    @State private var scrollSelectionToVisibleTick: UInt = 0

    var body: some View {
        VStack(spacing: 0) {
            searchBar
            Divider()
            if displayedItems.isEmpty {
                emptyState
            } else {
                itemList
            }
        }
        .frame(width: 440, height: 520)
        .background(.ultraThinMaterial)
        .onAppear { reload() }
        .onReceive(refreshPublisher ?? Empty().eraseToAnyPublisher()) { _ in reload() }
        .onReceive(store.objectWillChange) { _ in
            // Sync immediately so the visible list reflects the new top item the moment a
            // copy happens while the picker is open.
            updateDisplayedItems(preservingSelection: true)
        }
        .onDisappear {
            debounceTask?.cancel()
        }
        .onChange(of: debouncedQuery) { _, _ in
            updateDisplayedItems(preservingSelection: false)
        }
        .onReceive(navigateDownPublisher ?? Empty().eraseToAnyPublisher()) { _ in
            moveSelection(+1)
        }
    }

    // MARK: - Search bar

    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)

            SearchTextField(
                text: $searchText,
                onArrowUp:         { moveSelection(-1) },
                onArrowDown:       { moveSelection(+1) },
                onReturn:          { commitSelection() },
                onPlainTextReturn: { commitSelection() },
                onEscape:          { onDismiss() },
                onSpace:           { previewSelection() },
                onNumericShortcut: { n in selectByNumber(n) }
            )
            .frame(height: 20)
            .onChange(of: searchText) { _, new in
                debounceTask?.cancel()
                debounceTask = Task {
                    try? await Task.sleep(for: .milliseconds(150))
                    guard !Task.isCancelled else { return }
                    debouncedQuery = new
                }
            }

            if !displayedItems.isEmpty {
                Text("\(displayedItems.count)")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 2)
                    .background(.secondary.opacity(0.12))
                    .clipShape(Capsule())
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    // MARK: - List

    private var itemList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(Array(displayedItems.enumerated()), id: \.1.id) { index, row in
                        Button {
                            if let live = store.item(for: row.id) { onSelect(live) }
                        } label: {
                            ClipboardItemRow(
                                row: row,
                                shortcutNumber: index < 9 ? index + 1 : nil,
                                isSelected: row.id == selectedID
                            )
                        }
                        .buttonStyle(.plain)
                        .id(row.id)
                        .contextMenu {
                            Button {
                                if let live = store.item(for: row.id) { onSelect(live) }
                            } label: {
                                Label("Copy", systemImage: "doc.on.clipboard")
                            }
                            Button {
                                previewRow(row)
                            } label: {
                                Label("Open Preview", systemImage: "eye")
                            }
                            Divider()
                            Button(role: .destructive) {
                                store.delete(id: row.id)
                                updateDisplayedItems(preservingSelection: false)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                        Divider()
                    }
                }
                if displayedItems.count > 20 {
                    Text("\(displayedItems.count) items — type to filter")
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                        .padding(.vertical, 10)
                }
            }
            .onChange(of: selectedID) { _, newID in
                guard let newID else { return }
                Self.scrollRowIntoView(id: newID, proxy: proxy, anchor: .center)
            }
            .onChange(of: scrollSelectionToVisibleTick) { _, _ in
                guard let id = selectedID else { return }
                Self.scrollRowIntoView(id: id, proxy: proxy, anchor: .center)
            }
        }
    }

    private static func scrollRowIntoView(id: UUID, proxy: ScrollViewProxy, anchor: UnitPoint) {
        DispatchQueue.main.async {
            withAnimation(.easeInOut(duration: 0.12)) {
                proxy.scrollTo(id, anchor: anchor)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "doc.on.clipboard")
                .font(.system(size: 32))
                .foregroundStyle(.tertiary)
            Text(searchText.isEmpty ? "Nothing copied yet" : "No results for \"\(searchText)\"")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - State management

    private func updateDisplayedItems(preservingSelection: Bool) {
        let snapshot = PickerListSync.snapshot(
            store: store,
            matching: debouncedQuery,
            previousSelection: preservingSelection ? selectedID : nil
        )
        displayedItems = snapshot.items
        selectedID     = snapshot.selectedID
    }

    private func reload() {
        searchText     = ""
        debouncedQuery = ""
        // Always start a fresh open with the most-recent (top) row highlighted, even
        // if the previous selection is still present in history.
        selectedID = nil
        updateDisplayedItems(preservingSelection: false)
        scrollSelectionToVisibleTick &+= 1
    }

    // MARK: - Keyboard actions

    private func moveSelection(_ delta: Int) {
        guard !displayedItems.isEmpty else { return }
        let currentIndex = displayedItems.firstIndex(where: { $0.id == selectedID }) ?? 0
        guard let newIndex = PickerKeyboardNavigation.clampedIndex(
            currentIndex: currentIndex,
            delta: delta,
            itemCount: displayedItems.count
        ) else { return }
        selectedID = displayedItems[newIndex].id
    }

    private func commitSelection() {
        guard let id = selectedID,
              let live = store.item(for: id) else { return }
        onSelect(live)
    }

    private func previewSelection() {
        guard let id = selectedID,
              let row = displayedItems.first(where: { $0.id == id }) else { return }
        previewRow(row)
    }

    private func previewRow(_ row: PickerDisplayedRow) {
        let previewDir = Self.previewDirectory()
        let tempURL = previewDir.appendingPathComponent(UUID().uuidString + ".txt")
        do {
            try row.textValue.write(to: tempURL, atomically: true, encoding: .utf8)
            // Restrict to owner-only so other users on the machine can't read clipboard content.
            try FileManager.default.setAttributes(
                [.posixPermissions: 0o600], ofItemAtPath: tempURL.path
            )
        } catch {
            return
        }
        NSWorkspace.shared.open(tempURL)
    }

    private func selectByNumber(_ n: Int) {
        let index = n - 1
        guard displayedItems.indices.contains(index) else { return }
        let id = displayedItems[index].id
        if let live = store.item(for: id) { onSelect(live) }
    }

    /// Owner-only preview directory used for `Open Preview`. Cleans up files older
    /// than 5 minutes on each call so the sandbox container does not accumulate
    /// snippets of clipboard contents. Internal so tests can exercise the contract.
    static func previewDirectory() -> URL {
        let support = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let dir = support.appendingPathComponent("cpMan/Previews", isDirectory: true)
        let fm = FileManager.default
        try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        try? fm.setAttributes([.posixPermissions: 0o700], ofItemAtPath: dir.path)

        let cutoff = Date().addingTimeInterval(-300)
        if let files = try? fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: [.creationDateKey]) {
            for file in files {
                if let created = (try? file.resourceValues(forKeys: [.creationDateKey]))?.creationDate,
                   created < cutoff {
                    try? fm.removeItem(at: file)
                }
            }
        }
        return dir
    }
}

// MARK: - Keyboard navigation (unit-tested)

/// Arrow-key movement in the history list: **clamped** indices only (no wrap from
/// first row up to the last row, which is confusing on long lists).
enum PickerKeyboardNavigation {
    static func clampedIndex(currentIndex: Int, delta: Int, itemCount: Int) -> Int? {
        guard itemCount > 0 else { return nil }
        let raw = currentIndex + delta
        return min(max(0, raw), itemCount - 1)
    }
}

// MARK: - Displayed row (value type, unit-testable)

/// Value-type snapshot taken from `ClipboardItem` when the row is rendered.
/// Decouples the SwiftUI view hierarchy from the store so that a deletion
/// (or a history-replace from `HistoryStore.touch`) between fetch and render
/// cannot produce a row that references an item the store no longer holds.
struct PickerDisplayedRow: Identifiable, Equatable {
    let id: UUID
    let textValue: String
    let sourceApp: String?
    let sourceBundleId: String?

    init(from item: ClipboardItem) {
        id = item.id
        textValue = item.textValue
        sourceApp = item.sourceApp
        sourceBundleId = item.sourceBundleId
    }
}

/// Refreshes the displayed list when the store changes while the picker is open.
enum PickerListSync {
    @MainActor
    static func snapshot(
        store: HistoryStore,
        matching query: String,
        previousSelection: UUID?
    ) -> (items: [PickerDisplayedRow], selectedID: UUID?) {
        let fresh = store.all(matching: query)
        let rows = fresh.map { PickerDisplayedRow(from: $0) }
        let selectedID: UUID?
        if let id = previousSelection, fresh.contains(where: { $0.id == id }) {
            selectedID = id
        } else {
            selectedID = fresh.first?.id
        }
        return (rows, selectedID)
    }
}

// MARK: - Row

struct ClipboardItemRow: View {
    let row: PickerDisplayedRow
    var shortcutNumber: Int?
    var isSelected: Bool = false

    var body: some View {
        HStack(spacing: 10) {
            shortcutBadge
            Image(systemName: "doc.text")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .frame(width: 18)
            Text(row.textValue)
                .font(.system(size: 13))
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)
            Spacer(minLength: 0)
            if let app = row.sourceApp {
                Text(app)
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
                    .frame(width: 88, alignment: .trailing)
            } else {
                Color.clear.frame(width: 88)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(isSelected ? Color.accentColor.opacity(0.15) : Color.clear)
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private var shortcutBadge: some View {
        if let n = shortcutNumber {
            Text("\(n)")
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundStyle(.tertiary)
                .frame(width: 14, alignment: .center)
        } else {
            Color.clear.frame(width: 14)
        }
    }
}
