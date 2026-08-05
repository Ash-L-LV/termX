import AppKit
import TermXCore

/// Standalone window listing saved sessions for management
/// (Server → Session Manager…).
final class SessionManagerWindowController: NSWindowController {
    init(manager: TerminalManager) {
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 480, height: 540),
                              styleMask: [.titled, .closable, .miniaturizable, .resizable],
                              backing: .buffered,
                              defer: false)
        window.title = L.t("sessionManager")
        window.minSize = NSSize(width: 400, height: 360)
        window.setFrameAutosaveName("TermX.SessionManager.v2")
        window.center()
        super.init(window: window)

        let listVC = SessionListViewController(store: manager.store)
        listVC.onConnect = { [weak manager, weak window] session in
            manager?.connect(session: session)
            window?.close()
        }
        listVC.onNewSSH = { [weak manager] in
            manager?.presentNewSSHSession()
        }
        listVC.onEdit = { [weak manager] session in
            manager?.presentEditor(for: session)
        }
        listVC.onDelete = { [weak manager] session in
            manager?.deleteSession(session)
        }
        window.contentViewController = listVC
        window.setContentSize(NSSize(width: 480, height: 540))
        window.center()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
