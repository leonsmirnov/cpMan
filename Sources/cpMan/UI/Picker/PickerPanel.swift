import AppKit
import Combine
import SwiftUI
import os.log

private let logger = Logger(subsystem: "com.cpman.app", category: "PickerPanel")

// MARK: - Custom hosting view

/// Root cause 2 fix: stock NSHostingView doesn't override acceptsFirstMouse(for:),
/// so the very first click on the panel (while another app has keyboard focus) is
/// consumed by the window system as an "activation" gesture and never reaches SwiftUI.
private final class FirstMouseHostingView<Content: View>: NSHostingView<Content> {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}

// MARK: - Panel

/// Non-activating floating panel that hosts the clipboard history picker.
@MainActor
final class PickerPanel: NSPanel {
    private var typedHostingView: FirstMouseHostingView<AnyView>?

    /// Fired by the hotkey handler when the picker is already visible.
    /// PickerView subscribes via .onReceive and moves the selection down by one.
    private let navigateDownSubject = PassthroughSubject<Void, Never>()

    /// Fired on EVERY show() call so PickerView reloads its item list and resets
    /// selection even when onAppear does not re-fire (NSHostingView inside a hidden/
    /// shown NSPanel is never removed from the view hierarchy, so SwiftUI considers
    /// the view already-appeared and skips onAppear on subsequent shows).
    private let refreshSubject = PassthroughSubject<Void, Never>()

    /// Removed in `deinit` — stored as `nonisolated(unsafe)` so `deinit` can run without MainActor.
    nonisolated(unsafe) private var resignKeyObserver: NSObjectProtocol?
    nonisolated(unsafe) private var workspaceActivateObserver: NSObjectProtocol?

    /// The app that was frontmost when the picker opened. Captured once per show()
    /// so paste targets the correct app even after we activate cpMan for editing.
    private var sessionTargetApp: NSRunningApplication?

    /// True while the edit sheet is open. Suppresses the auto-close observers so
    /// activating cpMan (to give the editor keyboard focus) does not dismiss the picker.
    private var isEditing = false

    init() {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 440, height: 520),
            styleMask: [.nonactivatingPanel, .fullSizeContentView, .titled, .closable],
            backing: .buffered,
            defer: false
        )

        isMovableByWindowBackground = true
        level                        = .floating
        collectionBehavior           = [.canJoinAllSpaces, .fullScreenAuxiliary]
        titleVisibility              = .hidden
        titlebarAppearsTransparent   = true
        isReleasedWhenClosed         = false

        let navigatePublisher = navigateDownSubject.eraseToAnyPublisher()
        let refreshPublisher  = refreshSubject.eraseToAnyPublisher()

        let view = AnyView(
            PickerView(
                onSelect:             { [weak self] item in self?.handleSelection(item) },
                onDismiss:            { [weak self] in self?.close() },
                onBeginEdit:          { [weak self] in self?.beginEditing() },
                onCancelEdit:         { [weak self] in self?.cancelEditing() },
                onSaveEdit:           { [weak self] text, app, bundle in
                    self?.commitEditedText(text, sourceApp: app, sourceBundleId: bundle)
                },
                navigateDownPublisher: navigatePublisher,
                refreshPublisher:      refreshPublisher
            )
            .environmentObject(HistoryStore.shared)
            .environmentObject(AppSettings.shared)
            .environmentObject(AccessibilityService.shared)
        )
        let hv = FirstMouseHostingView(rootView: view)
        typedHostingView = hv
        contentView = hv

        // Close when the user clicks another window or switches apps (browse-only flow).
        resignKeyObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.didResignKeyNotification,
            object: self,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, self.isVisible, !self.isEditing else { return }
                self.close()
            }
        }

        workspaceActivateObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            let activatedBundle = (notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication)?
                .bundleIdentifier
            Task { @MainActor [weak self] in
                guard let self, self.isVisible, !self.isEditing else { return }
                if activatedBundle == Bundle.main.bundleIdentifier { return }
                self.close()
            }
        }
    }

    deinit {
        if let resignKeyObserver {
            NotificationCenter.default.removeObserver(resignKeyObserver)
        }
        if let workspaceActivateObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(workspaceActivateObserver)
        }
    }

    // MARK: - Show / hide

    /// Called by the hotkey handler.
    /// - If closed: opens the picker with the first item pre-selected.
    /// - If already open: moves the selection down by one (navigate instead of dismiss).
    func toggle() {
        if isVisible {
            // User pressed the hotkey again while the picker is open → navigate down.
            navigateDown()
        } else {
            show()
        }
    }

    func show() {
        // Capture the target app BEFORE the panel becomes key so editing (which
        // activates cpMan) can still paste into the app the user was working in.
        sessionTargetApp = NSWorkspace.shared.frontmostApplication
        isEditing = false
        center()
        makeKeyAndOrderFront(nil)
        // Explicitly tell PickerView to reload its item list and reset selection.
        // This fires every show() call, which is necessary because onAppear is
        // unreliable for NSHostingView inside a panel that is hidden/shown repeatedly.
        refreshSubject.send()
        focusSearchTextField()
        logger.debug("Picker panel shown")
    }

    /// Push a "navigate down" event into PickerView without closing the panel.
    func navigateDown() {
        navigateDownSubject.send()
        logger.debug("Navigate-down signal sent to picker")
    }

    // MARK: - Private

    /// Walks the AppKit subview tree to find `NavigationAwareTextField` and makes it
    /// first responder so keyboard events reach the field editor and our delegate
    /// callbacks fire. Retries up to 3 times at 80 ms intervals for the first show().
    private func focusSearchTextField(attempt: Int = 0) {
        guard let hv = typedHostingView else { return }

        if let field = firstDescendant(NavigationAwareTextField.self, in: hv) {
            makeFirstResponder(field)
            logger.debug("NavigationAwareTextField focused (attempt \(attempt))")
        } else if attempt < 3 {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) { [weak self] in
                guard self?.isVisible == true else { return }
                self?.focusSearchTextField(attempt: attempt + 1)
            }
        }
    }

    /// Depth-first search for the first descendant view of the given type.
    private func firstDescendant<T: NSView>(_ type: T.Type, in view: NSView) -> T? {
        if let match = view as? T { return match }
        for sub in view.subviews {
            if let found = firstDescendant(type, in: sub) { return found }
        }
        return nil
    }

    // MARK: - Editing

    /// User tapped "Edit". Activate cpMan so the edit sheet's text editor gets
    /// keyboard focus immediately (a non-activating panel otherwise leaves focus
    /// with the previous app). Auto-close is suppressed via `isEditing`.
    private func beginEditing() {
        isEditing = true
        NSApp.activate()
        makeKeyAndOrderFront(nil)
    }

    /// User cancelled editing. Restore the normal browse state: hand focus back to
    /// the original app and keep the picker open and key for continued browsing.
    private func cancelEditing() {
        guard isVisible else { isEditing = false; return }
        sessionTargetApp?.activate()
        makeKeyAndOrderFront(nil)
        focusSearchTextField()
        // Keep suppressing auto-close briefly so the focus handoff above (which
        // fires resign-key / activate notifications) does not dismiss the picker.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { [weak self] in
            self?.isEditing = false
        }
    }

    /// User saved an edit. The original entry is left untouched; the edited text
    /// is inserted as a new entry at the top, then pasted into the original app
    /// (respecting the auto-paste setting), and the picker closes.
    private func commitEditedText(_ text: String, sourceApp: String?, sourceBundleId: String?) {
        let newItem = ClipboardItem(
            sourceApp: sourceApp,
            sourceBundleId: sourceBundleId,
            contentType: .text,
            textValue: text
        )
        HistoryStore.shared.insert(newItem)

        let targetApp = sessionTargetApp
        isEditing = false
        close()

        // Return focus to the app the user was in before pasting the edited text.
        targetApp?.activate()
        if AppSettings.shared.autoPasteEnabled {
            PasteService.shared.paste(item: newItem, into: targetApp)
        } else {
            PasteService.shared.writeToPasteboardOnly(item: newItem)
        }
    }

    private func handleSelection(_ item: ClipboardItem) {
        logger.debug("Item selected: \(item.contentType.rawValue) from \(item.sourceApp ?? "unknown")")

        // Capture the target app NOW, before close() — after the panel closes there
        // is a brief window where frontmostApplication may flip to cpMan itself.
        let targetApp = NSWorkspace.shared.frontmostApplication

        // Bump createdAt so this item rises to the top of history (MRU order).
        HistoryStore.shared.touch(item)
        close()

        if AppSettings.shared.autoPasteEnabled {
            PasteService.shared.paste(item: item, into: targetApp)
        } else {
            PasteService.shared.writeToPasteboardOnly(item: item)
        }
    }
}
