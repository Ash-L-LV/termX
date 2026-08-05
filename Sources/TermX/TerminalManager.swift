import AppKit
import UniformTypeIdentifiers
import TermXCore

extension Notification.Name {
    static let tunnelsDidChange = Notification.Name("TermX.tunnelsDidChange")
}

/// Central coordinator: owns the session store, main window, detached
/// windows, session-manager/tunnels windows, active tunnels, and the server
/// picker popover.
final class TerminalManager: NSObject {
    let store = SessionStore()
    let themes = ThemeStore.shared

    private var mainWindow: MainWindowController?
    private var detachedWindows: [DetachedWindowController] = []
    private var sessionManagerWindow: SessionManagerWindowController?
    private var serverPickerPopover: NSPopover?
    private var tunnelsWindow: TunnelsWindowController?
    private(set) var tunnels: [TunnelProcess] = []

    var activeTerminal: TerminalViewController? {
        if let window = NSApp.keyWindow,
           let detached = detachedWindows.first(where: { $0.window === window }) {
            return detached.terminal
        }
        return mainWindow?.tabsVC.activeTab
    }

    var isKeyWindowDetached: Bool {
        guard let window = NSApp.keyWindow else { return false }
        return detachedWindows.contains { $0.window === window }
    }

    // MARK: - Windows

    func showMainWindow() {
        if mainWindow == nil {
            mainWindow = MainWindowController(manager: self)
        }
        mainWindow?.showWindow(nil)
        mainWindow?.window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func showSessionManager() {
        if sessionManagerWindow == nil {
            sessionManagerWindow = SessionManagerWindowController(manager: self)
        }
        sessionManagerWindow?.showWindow(nil)
        sessionManagerWindow?.window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func editActiveSession() {
        guard let session = activeTerminal?.session else { return }
        presentEditor(for: session)
    }

    func deleteActiveSession() {
        guard let session = activeTerminal?.session,
              store.session(withID: session.id) != nil else { return }
        deleteSession(session)
    }

    // MARK: - Tabs & sessions

    /// Always opens a brand-new tab, so the same server can have many tabs.
    func connect(session: Session) {
        showMainWindow()
        let vc = TerminalViewController(session: session, store: store)
        mainWindow?.tabsVC.addTab(vc)
        vc.start()
        if !session.portForwards.isEmpty {
            startTunnels(for: session, forwards: session.portForwards)
        }
    }

    // MARK: - Port forwarding

    func startTunnels(for session: Session, forwards: [PortForward]) {
        guard !forwards.isEmpty else { return }
        for forward in forwards {
            let tunnel = TunnelProcess(forward: forward, sourceName: session.name)
            tunnel.onStateChange = { _ in
                NotificationCenter.default.post(name: .tunnelsDidChange, object: nil)
            }
            tunnel.start(password: store.password(for: session),
                         host: session.host,
                         port: session.port,
                         username: session.username,
                         authMethod: session.authMethod,
                         keyPath: session.keyPath)
            tunnels.append(tunnel)
        }
        NotificationCenter.default.post(name: .tunnelsDidChange, object: nil)
    }

    func stopTunnel(id: UUID) {
        if let index = tunnels.firstIndex(where: { $0.id == id }) {
            tunnels[index].stop()
            tunnels.remove(at: index)
        }
        NotificationCenter.default.post(name: .tunnelsDidChange, object: nil)
    }

    func stopAllTunnels() {
        for tunnel in tunnels {
            tunnel.stop()
        }
        tunnels.removeAll()
        NotificationCenter.default.post(name: .tunnelsDidChange, object: nil)
    }

    /// Closes every window except the (already closing) main window.
    func closeAllWindows() {
        // Close everything except the main window: detached windows, the
        // tunnels window, the session manager, the port-forwarding editor,
        // and any other auxiliary windows.
        for window in NSApp.windows {
            if window === mainWindow?.window { continue }
            window.close()
        }
        detachedWindows.removeAll()
        serverPickerPopover?.close()
    }

    func showTunnelsWindow() {
        if tunnelsWindow == nil {
            tunnelsWindow = TunnelsWindowController(manager: self)
        }
        tunnelsWindow?.showWindow(nil)
        tunnelsWindow?.window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func newLocalTab() {
        connect(session: Session.newLocal(name: L.t("localSession")))
    }

    func presentServerPicker(from anchor: NSView) {
        serverPickerPopover?.close()
        let listVC = SessionListViewController(store: store)
        listVC.connectOnSingleClick = true
        listVC.showManagementBar = false
        let popover = NSPopover()
        popover.behavior = .transient
        popover.contentSize = NSSize(width: 280, height: 460)
        popover.contentViewController = listVC
        popover.delegate = self
        popover.show(relativeTo: anchor.bounds, of: anchor, preferredEdge: .maxY)
        serverPickerPopover = popover

        listVC.onConnect = { [weak self, weak popover] session in
            popover?.close()
            self?.connect(session: session)
        }
        listVC.onNewSSH = { [weak self, weak popover] in
            popover?.close()
            self?.presentNewSSHSession()
        }
        listVC.onEdit = { [weak self, weak popover] session in
            popover?.close()
            self?.presentEditor(for: session)
        }
        listVC.onDelete = { [weak self, weak popover] session in
            popover?.close()
            self?.deleteSession(session)
        }
    }

    func closeActiveTab() {
        if let window = NSApp.keyWindow,
           let detached = detachedWindows.first(where: { $0.window === window }) {
            detached.window?.close()
            return
        }
        guard let vc = mainWindow?.tabsVC.activeTab else { return }
        mainWindow?.tabsVC.close(vc)
    }

    func exportActiveTerminalLog() {
        guard let terminal = activeTerminal else { return }
        let data = terminal.exportTerminalLog()

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyyMMdd-HHmmss"
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.log, .plainText]
        panel.nameFieldStringValue = "TermX-\(dateFormatter.string(from: Date())).log"
        panel.title = L.t("exportTitle")
        panel.message = L.t("exportMsg")
        panel.prompt = L.t("save")
        panel.nameFieldLabel = L.t("saveAs")

        let window = NSApp.keyWindow ?? mainWindow?.window
        guard let window else { return }
        panel.beginSheetModal(for: window) { [weak self] response in
            guard response == .OK, let url = panel.url else { return }
            do {
                try data.write(to: url)
            } catch {
                let alert = NSAlert()
                alert.messageText = L.t("exportFail")
                alert.informativeText = error.localizedDescription
                alert.addButton(withTitle: L.t("ok"))
                if let target = self?.mainWindow?.window {
                    alert.beginSheetModal(for: target) { _ in }
                } else {
                    alert.runModal()
                }
            }
        }
    }

    func detachActiveTab() {
        guard let vc = mainWindow?.tabsVC.activeTab else { return }
        mainWindow?.tabsVC.detach(vc)
        openDetachedWindow(for: vc)
    }

    func openDetachedWindow(for vc: TerminalViewController) {
        let wc = DetachedWindowController(terminal: vc)
        wc.manager = self
        wc.onCloseRequested = { [weak self, weak wc] in
            guard let self, let wc else { return }
            self.detachedWindows.removeAll { $0 === wc }
        }
        detachedWindows.append(wc)
        wc.showWindow(nil)
        wc.window?.makeKeyAndOrderFront(nil)
    }

    func dockActiveTab() {
        guard let window = NSApp.keyWindow,
              let wc = detachedWindows.first(where: { $0.window === window }) else { return }
        dockDetached(wc)
    }

    /// Merges a detached window back into the main window as a tab.
    func dockDetached(_ wc: DetachedWindowController) {
        showMainWindow()
        wc.skipTerminationOnClose = true
        mainWindow?.tabsVC.addTab(wc.terminal)
        wc.window?.close()
        detachedWindows.removeAll { $0 === wc }
    }

    /// Docks a detached window when its title bar is dragged over the main
    /// window's tab strip (called when the drag is released).
    func dockDetachedIfOverTabStrip(_ wc: DetachedWindowController) {
        guard detachedWindowOverTabStrip(wc) else { return }
        dockDetached(wc)
    }

    /// Whether the detached window's title bar currently overlaps the main
    /// window's tab strip on screen.
    func detachedWindowOverTabStrip(_ wc: DetachedWindowController) -> Bool {
        guard let window = wc.window,
              let stripRect = mainWindow?.tabsVC.tabStripFrameInScreen else { return false }
        let frame = window.frame
        let titleBarRect = NSRect(x: frame.minX, y: frame.maxY - 28, width: frame.width, height: 28)
        let intersection = titleBarRect.intersection(stripRect)
        return !intersection.isNull && intersection.width >= 40 && intersection.height >= 8
    }

    func setTabStripDropHighlight(_ on: Bool) {
        mainWindow?.tabsVC.setDropHighlight(on)
    }

    // MARK: - Session editing

    func presentNewSSHSession() {
        showMainWindow()
        guard let window = mainWindow?.window else { return }
        SessionEditorViewController.present(from: window, session: nil) { [weak self] session in
            self?.store.upsert(session)
        }
    }

    func presentEditor(for session: Session) {
        showMainWindow()
        guard let window = mainWindow?.window else { return }
        SessionEditorViewController.present(from: window, session: session) { [weak self] updated in
            self?.store.upsert(updated)
        }
    }

    func deleteSession(_ session: Session) {
        let alert = NSAlert()
        alert.messageText = L.t("deleteTitle")
        alert.informativeText = String(format: L.t("deleteConfirm"), session.name)
        alert.alertStyle = .warning
        alert.addButton(withTitle: L.t("delete"))
        alert.addButton(withTitle: L.t("cancel"))

        let window = mainWindow?.window ?? detachedWindows.first?.window ?? sessionManagerWindow?.window
        guard let window else {
            store.delete(session)
            return
        }
        alert.beginSheetModal(for: window) { [weak self] response in
            if response == .alertFirstButtonReturn {
                self?.store.delete(session)
            }
        }
    }

    // MARK: - Theme & font

    func applyTheme(_ theme: TermTheme) {
        themes.defaultThemeName = theme.name
        activeTerminal?.apply(theme: theme)
    }

    func applyAppearanceToAll() {
        let all = (mainWindow?.tabsVC.allTabs ?? []) + detachedWindows.map { $0.terminal }
        for vc in all {
            vc.applyAppearance()
        }
    }

    func changeFontSize(by delta: CGFloat) {
        let size = min(28, max(9, ThemeStore.fontSize + delta))
        ThemeStore.fontSize = size
        activeTerminal?.setFontSize(size)
    }

    func resetFontSize() {
        ThemeStore.fontSize = 13
        activeTerminal?.setFontSize(13)
    }

    /// Kills every running session (main window tabs + detached windows) so
    /// shell/ssh children are not orphaned when the app quits.
    func terminateAllSessions() {
        let all = (mainWindow?.tabsVC.allTabs ?? []) + detachedWindows.map { $0.terminal }
        for vc in all {
            vc.terminateSession()
        }
        stopAllTunnels()
    }

}

extension TerminalManager: NSPopoverDelegate {
    func popoverDidClose(_ notification: Notification) {
        serverPickerPopover = nil
    }
}
