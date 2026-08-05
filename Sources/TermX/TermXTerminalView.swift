import AppKit
import SwiftTerm
import TermXCore

/// Terminal view that copies the current selection to the clipboard when the
/// user right-clicks while text is selected.
final class TermXTerminalView: TerminalView {
    override func rightMouseDown(with event: NSEvent) {
        if selectionActive {
            copy(self)
            return
        }
        super.rightMouseDown(with: event)
    }
}
