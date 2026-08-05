import AppKit
import TermXCore

/// A window that hosts a single terminal after it has been dragged out
/// of the main window's tab strip.
final class DetachedWindowController: NSWindowController, NSWindowDelegate {
    let terminal: TerminalViewController
    weak var manager: TerminalManager?
    var onCloseRequested: (() -> Void)?
    /// Set to true when the terminal is being docked back rather than closed.
    var skipTerminationOnClose = false
    /// True while we are polling for the end of a title-bar drag.
    private var dragPollPending = false

    init(terminal: TerminalViewController) {
        self.terminal = terminal
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 980, height: 640),
                              styleMask: [.titled, .closable, .miniaturizable, .resizable],
                              backing: .buffered,
                              defer: false)
        window.title = terminal.displayTitle
        window.minSize = NSSize(width: 600, height: 400)
        window.tabbingMode = .disallowed
        window.setFrameAutosaveName("TermX.Detached")
        window.center()
        super.init(window: window)
        window.delegate = self

        terminal.view.removeFromSuperview()
        terminal.view.frame = window.contentView?.bounds ?? .zero
        terminal.view.autoresizingMask = [.width, .height]
        window.contentView?.addSubview(terminal.view)
        terminal.applyAppearance()

        DispatchQueue.main.async { [weak self] in
            self?.window?.makeFirstResponder(terminal.terminalView)
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func windowWillClose(_ notification: Notification) {
        if !skipTerminationOnClose {
            terminal.terminateSession()
        }
        onCloseRequested?()
    }

    /// Called repeatedly while the user drags this window by its title bar.
    /// Starts a lightweight poll that detects when the drag ENDS (mouse
    /// released); only then is the merge decision made — passing over the tab
    /// strip while dragging never merges.
    func windowDidMove(_ notification: Notification) {
        guard !skipTerminationOnClose, let manager else { return }
        if NSEvent.pressedMouseButtons & 0x1 != 0 {
            beginDragPolling(manager)
        }
    }

    private func beginDragPolling(_ manager: TerminalManager) {
        guard !dragPollPending else { return }
        dragPollPending = true
        pollDrag(manager)
    }

    private func pollDrag(_ manager: TerminalManager) {
        let isPressed = NSEvent.pressedMouseButtons & 0x1 != 0
        if isPressed {
            // While dragging, highlight the strip when hovering over it.
            let over = manager.detachedWindowOverTabStrip(self)
            manager.setTabStripDropHighlight(over)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self, weak manager] in
                guard let self, let manager else { return }
                self.pollDrag(manager)
            }
        } else {
            // Drag ended: make the merge decision now.
            dragPollPending = false
            manager.setTabStripDropHighlight(false)
            manager.dockDetachedIfOverTabStrip(self)
        }
    }
}
