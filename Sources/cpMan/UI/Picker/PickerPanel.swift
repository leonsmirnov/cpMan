import AppKit
import Combine
import SwiftUI
import os.log

private let logger = Logger(subsystem: "com.cpman.app", category: "PickerPanel")

// MARK: - Custom hosting view

/// `NSHostingView` doesn't override `acceptsFirstMouse(for:)`, so the very first click
/// on the panel (while another app has keyboard focus) is consumed by the window system
/// as an "activation" gesture and never reaches SwiftUI. Subclassing lets us claim it.
private final class FirstMouseHostingView<Content: View>: NSHostingView<Content> {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}

// MARK: - Panel

/// Non-activating floating panel that hosts the clipboard history picker.
///
/// Lifecycle:
///   • Hotkey opens the panel above the active app, with no focus stealing.
///   • Selecting an item writes its text to `NSPasteboard.general` and closes
///     the panel; the user pastes with ⌘V into the previously active app.
///   • The panel auto-dismisses when the user clicks another window or
///     activates another app.
@MainActor
final class PickerPanel: NSPanel {
    private var typedHostingView: FirstMouseHostingView<PickerRootView>?

    /// Hotkey pressed while the picker is already open → move selection one down.
    private let navigateDownSubject = PassthroughSubject<Void, Never>()

    /// Fired on every `show()` so PickerView reloads its list and resets selection.
    /// `onAppear` is unreliable for an NSHostingView attached to a panel that is
    /// hidden/shown repeatedly, hence the explicit refresh signal.
    private let refreshSubject = PassthroughSubject<Void, Never>()

    /// Removed in `deinit` — stored as `nonisolated(unsafe)` so `deinit` can run without MainActor.
    nonisolated(unsafe) private var resignKeyObserver: NSObjectProtocol?
    nonisolated(unsafe) private var workspaceActivateObserver: NSObjectProtocol?

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

        let root = PickerRootView(
            onSelect:             { [weak self] item in self?.handleSelection(item) },
            onDismiss:            { [weak self] in self?.close() },
            navigateDownPublisher: navigatePublisher,
            refreshPublisher:      refreshPublisher
        )
        let hv = FirstMouseHostingView(rootView: root)
        typedHostingView = hv
        contentView = hv

        resignKeyObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.didResignKeyNotification,
            object: self,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, self.isVisible else { return }
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
                guard let self, self.isVisible else { return }
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
    /// - If already open: moves the selection down by one (so the hotkey acts as
    ///   a "tap to navigate" while the panel stays up).
    func toggle() {
        if isVisible {
            navigateDownSubject.send()
            logger.debug("Navigate-down signal sent to picker")
        } else {
            show()
        }
    }

    func show() {
        center()
        makeKeyAndOrderFront(nil)
        refreshSubject.send()
        focusSearchTextField()
        logger.debug("Picker panel shown")
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

    private func firstDescendant<T: NSView>(_ type: T.Type, in view: NSView) -> T? {
        if let match = view as? T { return match }
        for sub in view.subviews {
            if let found = firstDescendant(type, in: sub) { return found }
        }
        return nil
    }

    /// Writes the selected text to the system pasteboard, bumps the item to
    /// the top of history (MRU), and closes the panel. The user then pastes
    /// into the previously active app with ⌘V.
    private func handleSelection(_ item: ClipboardItem) {
        logger.debug("Item selected from \(item.sourceApp ?? "unknown")")

        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(item.textValue, forType: .string)
        ClipboardMonitor.shared.acknowledgeCurrentPasteboard()

        HistoryStore.shared.touch(id: item.id)
        close()
    }
}

// MARK: - Hosting root

/// Concrete root view for `NSHostingView`. SwiftUI propagates environment objects
/// far more reliably through a typed wrapper than through `AnyView`, so we always
/// thread the picker's dependencies through this wrapper instead of erasing.
struct PickerRootView: View {
    let onSelect:  (ClipboardItem) -> Void
    let onDismiss: () -> Void
    let navigateDownPublisher: AnyPublisher<Void, Never>
    let refreshPublisher: AnyPublisher<Void, Never>

    var body: some View {
        PickerView(
            onSelect: onSelect,
            onDismiss: onDismiss,
            navigateDownPublisher: navigateDownPublisher,
            refreshPublisher: refreshPublisher
        )
        .environmentObject(HistoryStore.shared)
    }
}
