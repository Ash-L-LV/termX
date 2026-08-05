import AppKit
import SwiftTerm
import TermXCore

/// Builds the application main menu programmatically (no nib). All titles are
/// localized through `L`, so the menu is rebuilt when the language changes.
enum MenuBuilder {
    static func makeMainMenu(delegate: AppDelegate) -> NSMenu {
        let mainMenu = NSMenu()

        // ── App menu ──
        let appMenuItem = NSMenuItem()
        mainMenu.addItem(appMenuItem)
        let appMenu = NSMenu(title: "TermX")
        appMenu.addItem(withTitle: L.t("about"), action: #selector(AppDelegate.showAbout(_:)), keyEquivalent: "")

        let languageItem = NSMenuItem(title: L.t("language"), action: nil, keyEquivalent: "")
        let languageMenu = NSMenu(title: L.t("language"))
        for language in Language.allCases {
            let menuItem = NSMenuItem(title: language.displayName,
                                      action: #selector(AppDelegate.setLanguage(_:)),
                                      keyEquivalent: "")
            menuItem.representedObject = language.rawValue
            languageMenu.addItem(menuItem)
        }
        languageItem.submenu = languageMenu
        appMenu.addItem(languageItem)

        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: L.t("hide"), action: #selector(NSApplication.hide(_:)), keyEquivalent: "h")
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: L.t("quit"), action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        appMenuItem.submenu = appMenu

        // ── File menu ──
        let fileItem = NSMenuItem()
        mainMenu.addItem(fileItem)
        let fileMenu = NSMenu(title: L.t("file"))
        fileMenu.addItem(item(L.t("newLocal"), #selector(AppDelegate.newLocalTerminal(_:)), "t"))
        fileMenu.addItem(item(L.t("exportLog"), #selector(AppDelegate.exportTerminalLog(_:)), "s"))
        fileMenu.addItem(.separator())
        fileMenu.addItem(item(L.t("closeTab"), #selector(AppDelegate.closeActiveTab(_:)), "w"))
        fileMenu.addItem(item(L.t("detachTab"), #selector(AppDelegate.detachActiveTab(_:)), "d", [.command, .shift]))
        fileMenu.addItem(item(L.t("dockTab"), #selector(AppDelegate.dockActiveTab(_:)), "d", [.command, .option]))
        fileItem.submenu = fileMenu

        // ── Server menu ──
        let serverItem = NSMenuItem()
        mainMenu.addItem(serverItem)
        let serverMenu = NSMenu(title: L.t("server"))
        serverMenu.addItem(item(L.t("newSSH"), #selector(AppDelegate.newSSHSession(_:)), "n"))
        serverMenu.addItem(item(L.t("sessionManager"), #selector(AppDelegate.showSessionManager(_:)), "o"))
        serverMenu.addItem(.separator())
        serverMenu.addItem(item(L.t("editCurrent"), #selector(AppDelegate.editActiveSession(_:)), ""))
        serverMenu.addItem(item(L.t("deleteCurrent"), #selector(AppDelegate.deleteActiveSession(_:)), ""))
        serverMenu.addItem(.separator())
        serverMenu.addItem(item(L.t("tunnels"), #selector(AppDelegate.showTunnels(_:)), "t", [.command, .shift]))
        serverItem.submenu = serverMenu

        // ── Edit menu ──
        let editItem = NSMenuItem()
        mainMenu.addItem(editItem)
        let editMenu = NSMenu(title: L.t("edit"))
        editMenu.addItem(item(L.t("copy"), #selector(NSText.copy(_:)), "c"))
        editMenu.addItem(item(L.t("paste"), #selector(NSText.paste(_:)), "v"))
        editMenu.addItem(.separator())
        editMenu.addItem(item(L.t("selectAll"), #selector(NSText.selectAll(_:)), "a"))
        editMenu.addItem(item(L.t("find"), #selector(TerminalView.performFindPanelAction(_:)), "f"))
        editItem.submenu = editMenu

        // ── View menu ──
        let viewItem = NSMenuItem()
        mainMenu.addItem(viewItem)
        let viewMenu = NSMenu(title: L.t("view"))

        let themeMenu = NSMenu(title: L.t("themes"))
        for theme in ThemeStore.shared.themes {
            let menuItem = NSMenuItem(title: theme.name,
                                      action: #selector(AppDelegate.applyThemeFromMenu(_:)),
                                      keyEquivalent: "")
            menuItem.representedObject = theme.name
            themeMenu.addItem(menuItem)
        }
        let themeSubmenuItem = NSMenuItem(title: L.t("themes"), action: nil, keyEquivalent: "")
        themeSubmenuItem.submenu = themeMenu
        viewMenu.addItem(themeSubmenuItem)

        let backgroundSubmenu = NSMenu(title: L.t("background"))
        let opacityMenu = NSMenu(title: L.t("opacity"))
        let opacityPresets: [(String, String)] = [
            (L.t("opacity100"), "1.0"),
            (L.t("opacity85"), "0.85"),
            (L.t("opacity70"), "0.70"),
            (L.t("opacity50"), "0.50"),
            (L.t("opacity30"), "0.30"),
        ]
        for (label, value) in opacityPresets {
            let opacityItem = NSMenuItem(title: label,
                                         action: #selector(AppDelegate.setBackgroundOpacity(_:)),
                                         keyEquivalent: "")
            opacityItem.representedObject = Double(value)
            opacityMenu.addItem(opacityItem)
        }
        let opacitySubmenuItem = NSMenuItem(title: L.t("opacity"), action: nil, keyEquivalent: "")
        opacitySubmenuItem.submenu = opacityMenu
        backgroundSubmenu.addItem(opacitySubmenuItem)
        let backgroundSubmenuItem = NSMenuItem(title: L.t("background"), action: nil, keyEquivalent: "")
        backgroundSubmenuItem.submenu = backgroundSubmenu
        viewMenu.addItem(backgroundSubmenuItem)

        viewMenu.addItem(.separator())
        viewMenu.addItem(item(L.t("fontIncrease"), #selector(AppDelegate.increaseFontSize(_:)), "+"))
        viewMenu.addItem(item(L.t("fontDecrease"), #selector(AppDelegate.decreaseFontSize(_:)), "-"))
        viewMenu.addItem(item(L.t("fontReset"), #selector(AppDelegate.resetFontSize(_:)), "0"))
        viewItem.submenu = viewMenu

        // ── Window menu ──
        let windowItem = NSMenuItem()
        mainMenu.addItem(windowItem)
        let windowMenu = NSMenu(title: L.t("window"))
        windowMenu.addItem(item(L.t("minimize"), #selector(NSWindow.performMiniaturize(_:)), "m"))
        windowMenu.addItem(item(L.t("zoom"), #selector(NSWindow.performZoom(_:)), ""))
        windowMenu.addItem(.separator())
        windowMenu.addItem(item(L.t("bringAllToFront"), #selector(NSApplication.arrangeInFront(_:)), ""))
        windowItem.submenu = windowMenu

        setTarget(delegate, in: mainMenu)
        return mainMenu
    }

    private static func item(_ title: String, _ action: Selector, _ key: String, _ modifiers: NSEvent.ModifierFlags = .command) -> NSMenuItem {
        let menuItem = NSMenuItem(title: title, action: action, keyEquivalent: key)
        menuItem.keyEquivalentModifierMask = modifiers
        return menuItem
    }

    /// Assigns the target only to menu items whose action the delegate
    /// actually implements; everything else keeps the responder chain.
    private static func setTarget(_ target: AnyObject, in menu: NSMenu) {
        for menuItem in menu.items {
            if let action = menuItem.action, target.responds(to: action) {
                menuItem.target = target
            }
            if let submenu = menuItem.submenu {
                setTarget(target, in: submenu)
            }
        }
    }
}
