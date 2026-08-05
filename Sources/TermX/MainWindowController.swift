import AppKit
import TermXCore

/// The main window: tabbed terminals only (server list lives in the
/// popover opened from the tab strip's ＋ button, or the Session Manager).
final class MainWindowController: NSWindowController, NSWindowDelegate {
    let tabsVC = TerminalTabViewController()

    init(manager: TerminalManager) {
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1240, height: 780),
                              styleMask: [.titled, .closable, .miniaturizable, .resizable],
                              backing: .buffered,
                              defer: false)
        window.title = "TermX"
        window.minSize = NSSize(width: 900, height: 560)
        window.tabbingMode = .disallowed
        window.setFrameAutosaveName("TermX.Main")
        window.center()

        super.init(window: window)
        window.delegate = self

        window.contentViewController = tabsVC
        // contentViewController resizes the window to the view's initial
        // frame; restore the intended window size afterwards.
        window.setContentSize(NSSize(width: 1240, height: 780))

        tabsVC.onDetach = { [weak manager] vc in
            manager?.openDetachedWindow(for: vc)
        }
        tabsVC.onAddRequested = { [weak manager] anchor in
            manager?.presentServerPicker(from: anchor)
        }
        tabsVC.onAllTabsClosed = { [weak self] in
            self?.window?.close()
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// Closing the main window closes every other open window too, so the
    /// app quits cleanly (last-window-closed → terminate).
    func windowWillClose(_ notification: Notification) {
        (NSApp.delegate as? AppDelegate)?.sharedManager?.closeAllWindows()
    }
}
