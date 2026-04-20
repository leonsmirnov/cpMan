import AppKit
import SwiftUI

// MARK: - NSViewRepresentable wrapper

/// Wraps NavigationAwareTextField so SwiftUI can host it.
///
/// KEY DESIGN NOTE: Do NOT try to intercept navigation keys in
/// NavigationAwareTextField.keyDown(with:). When makeFirstResponder() is called on
/// an NSTextField, macOS immediately installs a shared "field editor" (NSTextView) as
/// the actual first responder. The NSTextField.keyDown method is NEVER called while
/// the field editor is active — the field editor swallows every keystroke.
///
/// The correct intercept point is NSTextFieldDelegate.control(_:textView:doCommandBySelector:),
/// which the field editor calls before processing any navigation command. Returning true
/// from this method suppresses the default field-editor behaviour and fires our callbacks.
struct SearchTextField: NSViewRepresentable {
    @Binding var text: String
    var placeholder: String = "Search clipboard history…"

    var onArrowUp:          () -> Void      = {}
    var onArrowDown:        () -> Void      = {}
    var onReturn:           () -> Void      = {}
    var onPlainTextReturn:  () -> Void      = {}
    var onEscape:           () -> Void      = {}
    var onSpace:            () -> Void      = {}
    /// Fires when the user presses digit 1–9 while the field is empty (quick-select shortcut).
    var onNumericShortcut:  (Int) -> Void   = { _ in }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeNSView(context: Context) -> NavigationAwareTextField {
        let field = NavigationAwareTextField()
        field.delegate          = context.coordinator
        field.placeholderString = placeholder
        field.isBezeled         = false
        field.drawsBackground   = false
        field.focusRingType     = .none
        field.font              = .systemFont(ofSize: 14)
        field.cell?.wraps       = false
        field.cell?.isScrollable = true
        return field
    }

    func updateNSView(_ nsView: NavigationAwareTextField, context: Context) {
        if nsView.stringValue != text {
            nsView.stringValue = text
            // Keep coordinator's previousText in sync so digit-shortcut detection
            // doesn't misfire when the binding is reset externally (e.g. onAppear).
            context.coordinator.previousText = text
        }
        // Refresh all closures so they always capture the latest SwiftUI state.
        context.coordinator.parent = self
    }

    // MARK: - Coordinator

    final class Coordinator: NSObject, NSTextFieldDelegate {
        var parent: SearchTextField
        /// Tracks the text value before the latest edit — used to detect the
        /// "empty → single digit" transition that triggers a numeric shortcut.
        var previousText = ""

        init(_ parent: SearchTextField) { self.parent = parent }

        // MARK: Text change

        func controlTextDidChange(_ obj: Notification) {
            guard let field = obj.object as? NSTextField else { return }
            let newText = field.stringValue

            // Digit shortcut: user pressed 1-9 while the field was empty.
            // Treat as "select item N" rather than starting a search query.
            if previousText.isEmpty,
               newText.count == 1,
               let n = Int(newText),
               (1...9).contains(n) {
                field.stringValue = ""
                previousText      = ""
                parent.text       = ""
                parent.onNumericShortcut(n)
                return
            }

            // Space shortcut: Space while field is empty → preview selected item.
            if previousText.isEmpty, newText == " " {
                field.stringValue = ""
                previousText      = ""
                parent.text       = ""
                parent.onSpace()
                return
            }

            previousText = newText
            parent.text  = newText
        }

        // MARK: Command selector (↑ ↓ Return Escape)

        /// Called by the field editor for every navigation/action selector BEFORE
        /// the field editor handles it. Returning true consumes the event.
        ///
        /// This is the ONLY reliable intercept point for navigation keys when an
        /// NSTextField's field editor has focus — NSTextField.keyDown is never called.
        func control(
            _ control: NSControl,
            textView: NSTextView,
            doCommandBy commandSelector: Selector
        ) -> Bool {
            switch commandSelector {
            case #selector(NSResponder.moveUp(_:)):
                parent.onArrowUp()
                return true   // suppress field-editor default (cursor to start of text)
            case #selector(NSResponder.moveDown(_:)):
                parent.onArrowDown()
                return true   // suppress field-editor default (cursor to end of text)
            case #selector(NSResponder.insertNewline(_:)):
                parent.onReturn()
                return true   // suppress end-editing / commit behaviour
            case #selector(NSResponder.insertNewlineIgnoringFieldEditor(_:)):
                // ⌥Return — paste as plain text
                parent.onPlainTextReturn()
                return true
            case #selector(NSResponder.cancelOperation(_:)):
                parent.onEscape()
                return true   // suppress field clear
            default:
                return false  // let the field editor handle everything else normally
            }
        }
    }
}

// MARK: - NSTextField subclass

/// Exists solely so PickerPanel.firstDescendant<NavigationAwareTextField>() can locate
/// the search field in the AppKit view hierarchy and call makeFirstResponder() on it.
/// All key handling happens in the Coordinator via NSTextFieldDelegate — NOT here.
final class NavigationAwareTextField: NSTextField {
    override var focusRingType: NSFocusRingType {
        get { .none }
        set {}
    }
}
