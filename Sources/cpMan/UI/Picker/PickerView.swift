import AppKit
import Combine
import SwiftUI

struct PickerView: View {
    let onSelect:  (ClipboardItem) -> Void
    let onDismiss: () -> Void

    /// Fired by the hotkey handler when the picker is already visible.
    /// Each emission moves the selection one step down.
    var navigateDownPublisher: AnyPublisher<Void, Never>? = nil

    /// Fired by PickerPanel.show() on every open so the list and selection are
    /// always fresh — do NOT rely on onAppear alone for this because SwiftUI
    /// does not re-fire onAppear for views inside a hidden/shown NSPanel.
    var refreshPublisher: AnyPublisher<Void, Never>? = nil

    @EnvironmentObject private var store:     HistoryStore
    @EnvironmentObject private var settings:  AppSettings
    @EnvironmentObject private var axService: AccessibilityService

    @AppStorage("hasAutoOpenedAccessibilitySettings") private var hasAutoOpenedAXSettings = false

    @State private var searchText    = ""
    @State private var debouncedQuery = ""
    @State private var debounceTask:  Task<Void, Never>?
    @State private var showPinnedOnly = false

    /// Snapshot of the history list for the current picker session.
    /// Refreshes when the picker opens, the search query changes, or the store
    /// changes (new copies while the picker is visible). Selection is kept on
    /// the same item by id when possible so the list does not jump under the user.
    @State private var displayedItems: [ClipboardItem] = []

    /// Identity-based selection. UUID never goes stale when the list reorders,
    /// unlike an integer index which silently points at a different item after
    /// any insert / sort change.
    @State private var selectedID: UUID? = nil
    @State private var editingItem: ClipboardItem? = nil
    @State private var editingText: String = ""
    @State private var expandedID: UUID? = nil

    var body: some View {
        VStack(spacing: 0) {
            if settings.autoPasteEnabled && !axService.isGranted {
                axPermissionBanner
                Divider()
            }
            searchBar
            Divider()
            filterTabs
            Divider()
            if displayedItems.isEmpty {
                emptyState
            } else {
                itemList
            }
        }
        .frame(width: 440, height: 520)
        .background(.ultraThinMaterial)
        .sheet(item: $editingItem) { item in
            EditTextView(
                originalText: item.textValue ?? "",
                editingText: $editingText
            ) { savedText in
                let newItem = ClipboardItem(
                    sourceApp: item.sourceApp,
                    sourceBundleId: item.sourceBundleId,
                    contentType: .text,
                    textValue: savedText
                )
                store.insert(newItem)
                reload()
                editingItem = nil
            } onCancel: {
                editingItem = nil
            }
        }
        // Reset state every time the picker opens.
        // onAppear fires on first show; refreshPublisher fires on every subsequent show.
        .onAppear { reload() }
        .onReceive(refreshPublisher ?? Empty().eraseToAnyPublisher()) { _ in reload() }
        .onReceive(store.objectWillChange) { _ in
            // Sync immediately — a delay would leave stale SwiftData references
            // in displayedItems; accessing properties on a deleted model object
            // (e.g. one removed by pruning) causes a fatal SwiftData assertion.
            syncDisplayedItemsFromStore()
        }
        .onDisappear {
            debounceTask?.cancel()
        }
        // Refresh displayed list whenever the debounced query or filter settles.
        .onChange(of: debouncedQuery) { _, _ in updateDisplayedItems() }
        .onChange(of: showPinnedOnly) { _, _ in updateDisplayedItems() }
        // Hotkey pressed while the picker is already open → move selection down.
        .onReceive(navigateDownPublisher ?? Empty().eraseToAnyPublisher()) { _ in
            moveSelection(+1)
        }
        .background {
            Button("Pin") {
                if let id = selectedID, let item = displayedItems.first(where: { $0.id == id }) {
                    store.togglePin(item)
                    updateDisplayedItems()
                }
            }
            .keyboardShortcut("p", modifiers: .command)
            .hidden()
        }
    }

    // MARK: - AX permission banner

    private var axPermissionBanner: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: "hand.raised.fill")
                    .foregroundStyle(.orange)
                Text("Accessibility access needed for auto-paste")
                    .font(.system(size: 12, weight: .semibold))
                Spacer()
                Button("Open Settings") {
                    hasAutoOpenedAXSettings = true
                    axService.openAccessibilitySettings()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .tint(.orange)
            }

            if hasAutoOpenedAXSettings {
                VStack(alignment: .leading, spacing: 3) {
                    Text("In System Settings → Privacy & Security → Accessibility:")
                        .font(.system(size: 11, weight: .medium))
                    Text("• If cpMan is in the list → toggle it **ON**")
                        .font(.system(size: 11))
                    Text("• If cpMan is **not** in the list → click **+** at the bottom, open your Applications folder, and add cpMan")
                        .font(.system(size: 11))
                }
                .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color.orange.opacity(0.08))
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
                onPlainTextReturn: { commitSelectionAsPlainText() },
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

    // MARK: - Filter Tabs

    private var filterTabs: some View {
        Picker("Filter", selection: $showPinnedOnly) {
            Text("All Items").tag(false)
            Text("Pinned").tag(true)
        }
        .pickerStyle(.segmented)
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
    }

    // MARK: - Item list

    private var itemList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(Array(displayedItems.enumerated()), id: \.1.id) { index, item in
                        Button {
                            onSelect(item)
                        } label: {
                            ClipboardItemRow(
                                item: item,
                                shortcutNumber: index < 9 ? index + 1 : nil,
                                isSelected: item.id == selectedID,
                                isExpanded: item.id == expandedID
                            )
                        }
                        .buttonStyle(.plain)
                        .id(item.id)
                        .overlay(alignment: .topTrailing) {
                            expandChevron(for: item)
                        }
                        .contextMenu {
                            Button {
                                store.togglePin(item)
                                updateDisplayedItems()
                            } label: {
                                Label(item.isPinned ? "Unpin" : "Pin", systemImage: item.isPinned ? "pin.slash" : "pin")
                            }
                            
                            Divider()

                            Button {
                                onSelect(item)
                            } label: {
                                Label("Paste", systemImage: "doc.on.clipboard")
                            }

                            if item.contentType == .text {
                                Button {
                                    editingText = item.textValue ?? ""
                                    editingItem = item
                                } label: {
                                    Label("Edit", systemImage: "pencil")
                                }
                                Button {
                                    let targetApp = NSWorkspace.shared.frontmostApplication
                                    store.touch(item)
                                    onDismiss()
                                    PasteService.shared.pasteAsPlainText(item: item, into: targetApp)
                                } label: {
                                    Label("Paste as Plain Text", systemImage: "doc.plaintext")
                                }
                            }

                            if item.contentType == .image {
                                Button {
                                    let targetApp = NSWorkspace.shared.frontmostApplication
                                    store.touch(item)
                                    onDismiss()
                                    PasteService.shared.pasteAsFile(item: item, into: targetApp)
                                } label: {
                                    Label("Paste as File", systemImage: "doc.badge.arrow.up")
                                }
                                Button {
                                    let targetApp = NSWorkspace.shared.frontmostApplication
                                    store.touch(item)
                                    onDismiss()
                                    PasteService.shared.pasteAsPlainText(item: item, into: targetApp)
                                } label: {
                                    Label("Paste OCR Text", systemImage: "text.viewfinder")
                                }
                                .disabled((item.ocrText ?? "").isEmpty)
                            }

                            if let text = item.ocrText, !text.isEmpty, item.contentType == .image {
                                Button {
                                    NSPasteboard.general.clearContents()
                                    NSPasteboard.general.setString(text, forType: .string)
                                    ClipboardMonitor.shared.acknowledgeCurrentPasteboard()
                                } label: {
                                    Label("Copy OCR Text", systemImage: "text.viewfinder")
                                }
                            }

                            Divider()

                            Button {
                                previewItem(item)
                            } label: {
                                Label("Open Preview", systemImage: "eye")
                            }

                            Divider()

                            Button(role: .destructive) {
                                store.delete(item)
                                reload()
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
                withAnimation(.easeInOut(duration: 0.1)) {
                    proxy.scrollTo(newID, anchor: .center)
                }
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

    // MARK: - Keyboard actions

    private func updateDisplayedItems() {
        var items = store.allItems(matching: debouncedQuery)
        if showPinnedOnly {
            items = items.filter { $0.isPinned }
        }
        displayedItems = items
        if !displayedItems.contains(where: { $0.id == selectedID }) {
            selectedID = displayedItems.first?.id
        }
    }

    private func reload() {
        searchText     = ""
        debouncedQuery = ""
        updateDisplayedItems()

        // First time the picker opens and auto-paste is on but AX not granted:
        // automatically open System Settings so the user only has to flip one toggle.
        if settings.autoPasteEnabled && !axService.isGranted && !hasAutoOpenedAXSettings {
            hasAutoOpenedAXSettings = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                axService.openAccessibilitySettings()
            }
        }
    }

    /// Re-fetch from the store while keeping the current selection when it still exists.
    private func syncDisplayedItemsFromStore() {
        let snap = PickerListSync.snapshot(
            store: store,
            matching: debouncedQuery,
            previousSelection: selectedID,
            expandedID: expandedID,
            pinnedOnly: showPinnedOnly
        )
        displayedItems = snap.items
        selectedID     = snap.selectedID
        expandedID     = snap.expandedID
    }

    private func moveSelection(_ delta: Int) {
        guard !displayedItems.isEmpty else { return }
        let currentIndex = displayedItems.firstIndex(where: { $0.id == selectedID }) ?? 0
        let newIndex = (currentIndex + delta + displayedItems.count) % displayedItems.count
        selectedID = displayedItems[newIndex].id
    }

    private func commitSelection() {
        guard let id = selectedID,
              let item = displayedItems.first(where: { $0.id == id }) else { return }
        onSelect(item)
    }

    private func commitSelectionAsPlainText() {
        guard let id = selectedID,
              let item = displayedItems.first(where: { $0.id == id }) else { return }
        let targetApp = NSWorkspace.shared.frontmostApplication
        store.touch(item)
        onDismiss()
        PasteService.shared.pasteAsPlainText(item: item, into: targetApp)
    }

    private func previewSelection() {
        guard let id = selectedID,
              let item = displayedItems.first(where: { $0.id == id }) else { return }
        previewItem(item)
    }

    private func previewItem(_ item: ClipboardItem) {
        switch item.contentType {
        case .image:
            if let path = item.imageFilePath {
                NSWorkspace.shared.open(URL(fileURLWithPath: path))
            }
        case .text:
            guard let text = item.textValue else { return }
            let previewDir = Self.previewDirectory()
            let tempURL = previewDir.appendingPathComponent(UUID().uuidString + ".txt")
            do {
                try text.write(to: tempURL, atomically: true, encoding: .utf8)
                // Restrict to owner-only so other users can't read clipboard content.
                try FileManager.default.setAttributes(
                    [.posixPermissions: 0o600], ofItemAtPath: tempURL.path
                )
            } catch {
                return
            }
            NSWorkspace.shared.open(tempURL)
        }
    }

    /// Returns a dedicated preview directory under Application Support with
    /// owner-only permissions. Cleans up files older than 5 minutes on each call.
    /// Internal (not private) so unit tests can verify directory permissions
    /// and the stale-file cleanup contract on the real production code path.
    static func previewDirectory() -> URL {
        let support = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let dir = support.appendingPathComponent("cpMan/Previews", isDirectory: true)
        let fm = FileManager.default
        try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        try? fm.setAttributes([.posixPermissions: 0o700], ofItemAtPath: dir.path)

        // Clean up stale preview files (older than 5 minutes).
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

    @ViewBuilder
    private func expandChevron(for item: ClipboardItem) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.15)) {
                expandedID = expandedID == item.id ? nil : item.id
            }
        } label: {
            Image(systemName: expandedID == item.id ? "chevron.up" : "chevron.down")
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(.tertiary)
                .padding(6)
        }
        .buttonStyle(.plain)
    }

    private func selectByNumber(_ n: Int) {
        let index = n - 1
        guard displayedItems.indices.contains(index) else { return }
        onSelect(displayedItems[index])
    }
}

// MARK: - Picker list sync (also unit-tested)

/// Refreshes displayed rows when `HistoryStore` changes while the picker is open.
enum PickerListSync {
    @MainActor
    static func snapshot(
        store: HistoryStore,
        matching query: String,
        previousSelection: UUID?,
        expandedID: UUID?,
        pinnedOnly: Bool = false
    ) -> (items: [ClipboardItem], selectedID: UUID?, expandedID: UUID?) {
        var fresh = store.allItems(matching: query)
        if pinnedOnly {
            fresh = fresh.filter { $0.isPinned }
        }

        let selectedID: UUID?
        if let id = previousSelection, fresh.contains(where: { $0.id == id }) {
            selectedID = id
        } else {
            selectedID = fresh.first?.id
        }

        let newExpanded: UUID?
        if let e = expandedID, fresh.contains(where: { $0.id == e }) {
            newExpanded = e
        } else {
            newExpanded = nil
        }

        return (fresh, selectedID, newExpanded)
    }
}

// MARK: - Edit text sheet

private struct EditTextView: View {
    let originalText: String
    @Binding var editingText: String
    let onSave:   (String) -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Edit Clipboard Item")
                .font(.headline)

            TextEditor(text: $editingText)
                .font(.system(size: 13))
                .scrollContentBackground(.hidden)
                .background(.quaternary.opacity(0.5))
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .frame(minHeight: 160)

            if editingText != originalText {
                Text("A new history entry will be created with your changes.")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }

            HStack {
                Button("Cancel", role: .cancel) { onCancel() }
                    .keyboardShortcut(.escape, modifiers: [])
                Spacer()
                Button("Save") {
                    let trimmed = editingText.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !trimmed.isEmpty else { return }
                    onSave(trimmed)
                }
                .keyboardShortcut(.return, modifiers: .command)
                .buttonStyle(.borderedProminent)
                .disabled(editingText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                          editingText == originalText)
            }
        }
        .padding(20)
        .frame(width: 440)
    }
}

// MARK: - Row

struct ClipboardItemRow: View {
    let item: ClipboardItem
    var shortcutNumber: Int?
    var isSelected: Bool = false
    var isExpanded: Bool = false
    @State private var thumbnail: NSImage? = nil

    var body: some View {
        HStack(spacing: 10) {
            shortcutBadge
            typeIcon
            contentPreview
            Spacer(minLength: 0)
            metaInfo
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

    private var typeIcon: some View {
        Image(systemName: item.contentType == .text ? "doc.text" : "photo")
            .font(.system(size: 13))
            .foregroundStyle(.secondary)
            .frame(width: 18)
    }

    @ViewBuilder
    private var contentPreview: some View {
        if item.contentType == .text, let text = item.textValue {
            Text(text)
                .font(.system(size: 13))
                .lineLimit(isExpanded ? nil : 2)
                .frame(maxWidth: .infinity, alignment: .leading)
                .animation(.easeInOut(duration: 0.15), value: isExpanded)
        } else if item.contentType == .image, let path = item.imageFilePath {
            let maxPts: CGFloat = isExpanded ? ThumbnailSize.expanded : ThumbnailSize.normal
            // Display height is independent of the source thumbnail size; keep
            // it linked to `maxPts` so the row geometry tracks the cache key.
            let displayHeight: CGFloat = isExpanded ? 160 : 48
            HStack(spacing: 8) {
                if let thumb = thumbnail {
                    Image(nsImage: thumb)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: maxPts, maxHeight: displayHeight)
                        .cornerRadius(4)
                        .animation(.easeInOut(duration: 0.15), value: isExpanded)
                } else {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(.secondary.opacity(0.15))
                        .frame(width: maxPts, height: displayHeight)
                }
                if let ocrText = item.ocrText, !ocrText.isEmpty {
                    Text(ocrText)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .lineLimit(isExpanded ? nil : 2)
                }
            }
            .task(id: "\(path)-\(isExpanded)") {
                thumbnail = await ThumbnailCache.shared.thumbnailAsync(for: path, maxPoints: maxPts)
            }
        }
    }

    private var metaInfo: some View {
        VStack(alignment: .trailing, spacing: 2) {
            HStack(spacing: 4) {
                if item.isPinned {
                    Image(systemName: "pin.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(.orange)
                }
                if let app = item.sourceApp {
                    Text(app)
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }
            }
            Text(item.createdAt, style: .relative)
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)
        }
        .frame(width: 72, alignment: .trailing)
    }
}
