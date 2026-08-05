import AppKit
import TermXCore

/// Application entry point: owns the `TerminalManager`, builds the main
/// menu, and forwards app-level menu actions to the manager.
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var manager: TerminalManager!

    var sharedManager: TerminalManager? { manager }

    func applicationDidFinishLaunching(_ notification: Notification) {
        L.applySystemLanguage()
        manager = TerminalManager()
        NSApp.mainMenu = MenuBuilder.makeMainMenu(delegate: self)
        manager.showMainWindow()
        manager.newLocalTab()
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        manager.showMainWindow()
        return true
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }

    func applicationWillTerminate(_ notification: Notification) {
        manager.terminateAllSessions()
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        true
    }

    // MARK: - Menu actions

    @objc func newSSHSession(_ sender: Any?) {
        manager.presentNewSSHSession()
    }

    @objc func newLocalTerminal(_ sender: Any?) {
        manager.newLocalTab()
    }

    @objc func exportTerminalLog(_ sender: Any?) {
        manager.exportActiveTerminalLog()
    }

    @objc func showSessionManager(_ sender: Any?) {
        manager.showSessionManager()
    }

    @objc func showTunnels(_ sender: Any?) {
        manager.showTunnelsWindow()
    }

    @objc func editActiveSession(_ sender: Any?) {
        manager.editActiveSession()
    }

    @objc func deleteActiveSession(_ sender: Any?) {
        manager.deleteActiveSession()
    }

    @objc func closeActiveTab(_ sender: Any?) {
        manager.closeActiveTab()
    }

    @objc func detachActiveTab(_ sender: Any?) {
        manager.detachActiveTab()
    }

    @objc func dockActiveTab(_ sender: Any?) {
        manager.dockActiveTab()
    }

    @objc func applyThemeFromMenu(_ sender: NSMenuItem) {
        guard let name = sender.representedObject as? String,
              let theme = manager.themes.theme(named: name) else { return }
        manager.applyTheme(theme)
    }

    @objc func increaseFontSize(_ sender: Any?) {
        manager.changeFontSize(by: 1)
    }

    @objc func decreaseFontSize(_ sender: Any?) {
        manager.changeFontSize(by: -1)
    }

    @objc func resetFontSize(_ sender: Any?) {
        manager.resetFontSize()
    }

    @objc func setLanguage(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String,
              let language = Language(rawValue: raw) else { return }
        L.current = language
        NSApp.mainMenu = MenuBuilder.makeMainMenu(delegate: self)
        // Refocus the key window so the new menu takes effect cleanly.
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc func setBackgroundOpacity(_ sender: NSMenuItem) {
        guard let value = sender.representedObject as? Double else { return }
        TerminalAppearance.backgroundOpacity = CGFloat(value)
        manager.applyAppearanceToAll()
    }

    @objc func showAbout(_ sender: Any?) {
        let alert = NSAlert()
        alert.messageText = "TermX"
        alert.informativeText = L.t("aboutText") + "\n" + L.t("aboutRepo")
        alert.accessoryView = AboutView.makeLinkField(text: L.t("aboutRepo"))
        alert.addButton(withTitle: L.t("ok"))
        alert.runModal()
    }

    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        let action = menuItem.action
        if action == #selector(dockActiveTab(_:)) {
            return manager.isKeyWindowDetached
        }
        if action == #selector(closeActiveTab(_:)) || action == #selector(detachActiveTab(_:)) {
            return manager.activeTerminal != nil
        }
        if action == #selector(exportTerminalLog(_:)) {
            return manager.activeTerminal != nil
        }
        if action == #selector(editActiveSession(_:)) {
            return manager.activeTerminal != nil
        }
        if action == #selector(deleteActiveSession(_:)) {
            guard let session = manager.activeTerminal?.session else { return false }
            return manager.store.session(withID: session.id) != nil
        }
        if action == #selector(applyThemeFromMenu(_:)) {
            let name = menuItem.representedObject as? String
            menuItem.state = name == manager.themes.defaultThemeName ? .on : .off
        }
        if action == #selector(setLanguage(_:)) {
            let raw = menuItem.representedObject as? String
            menuItem.state = raw == L.current.rawValue ? .on : .off
        }
        if action == #selector(setBackgroundOpacity(_:)) {
            let value = menuItem.representedObject as? Double ?? 1.0
            menuItem.state = abs(Double(TerminalAppearance.backgroundOpacity) - value) < 0.001 ? .on : .off
        }
        return true
    }
}
