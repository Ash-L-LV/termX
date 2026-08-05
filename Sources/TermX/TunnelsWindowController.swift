import AppKit
import TermXCore

/// Content view that stretches the tunnel table's column whenever the
/// window is laid out.
private final class TunnelContentView: NSView {
    var onLayout: (() -> Void)?
    override func layout() {
        super.layout()
        onLayout?()
    }
}

/// Window listing all active port-forwarding tunnels.
final class TunnelsWindowController: NSWindowController, NSTableViewDataSource, NSTableViewDelegate {
    private let manager: TerminalManager
    private let tableView = NSTableView()
    private let emptyLabel = NSTextField(labelWithString: "")

    private var tunnels: [TunnelProcess] { manager.tunnels }

    init(manager: TerminalManager) {
        self.manager = manager
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 660, height: 420),
                              styleMask: [.titled, .closable, .miniaturizable, .resizable],
                              backing: .buffered,
                              defer: false)
        window.title = L.t("tunnels")
        window.minSize = NSSize(width: 560, height: 300)
        window.setFrameAutosaveName("TermX.Tunnels.v2")
        window.center()
        super.init(window: window)

        let container = TunnelContentView(frame: NSRect(x: 0, y: 0, width: 660, height: 420))
        window.contentView = container
        container.onLayout = { [weak self] in
            self?.tableView.sizeLastColumnToFit()
        }

        let scroll = NSScrollView(frame: NSRect(x: 0, y: 44, width: container.bounds.width,
                                                height: container.bounds.height - 40))
        scroll.autoresizingMask = [.width, .height]
        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("Tunnel"))
        column.resizingMask = .autoresizingMask
        tableView.addTableColumn(column)
        tableView.columnAutoresizingStyle = .lastColumnOnlyAutoresizingStyle
        tableView.headerView = nil
        tableView.rowHeight = 44
        tableView.style = .inset
        tableView.dataSource = self
        tableView.delegate = self
        tableView.allowsEmptySelection = true
        scroll.documentView = tableView
        tableView.frame = NSRect(x: 0, y: 0, width: scroll.contentSize.width, height: 400)
        tableView.autoresizingMask = [.width]
        container.addSubview(scroll)

        let newButton = NSButton(title: L.t("newTunnel"), target: self, action: #selector(newTunnelTapped))
        let stopButton = NSButton(title: L.t("stop"), target: self, action: #selector(stopSelected))
        let stopAllButton = NSButton(title: L.t("stopAll"), target: self, action: #selector(stopAll))
        for button in [newButton, stopButton, stopAllButton] {
            button.bezelStyle = .rounded
        }
        let buttons = NSStackView(views: [newButton, stopButton, stopAllButton])
        buttons.orientation = .horizontal
        buttons.spacing = 8
        buttons.frame = NSRect(x: 10, y: 8, width: 320, height: 30)
        container.addSubview(buttons)

        emptyLabel.alignment = .center
        emptyLabel.textColor = .tertiaryLabelColor
        emptyLabel.font = .systemFont(ofSize: 13)
        emptyLabel.stringValue = L.t("noTunnels")
        emptyLabel.frame = NSRect(x: 20, y: 160, width: container.bounds.width - 40, height: 60)
        emptyLabel.autoresizingMask = [.width, .minYMargin, .maxYMargin]
        container.addSubview(emptyLabel)

        NotificationCenter.default.addObserver(self, selector: #selector(reload),
                                               name: .tunnelsDidChange, object: nil)
        reload()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    @objc private func reload() {
        tableView.reloadData()
        emptyLabel.isHidden = !tunnels.isEmpty
    }

    // MARK: - Table

    func numberOfRows(in tableView: NSTableView) -> Int {
        tunnels.count
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let identifier = NSUserInterfaceItemIdentifier("TunnelCell")
        let cell: TunnelCellView
        if let reused = tableView.makeView(withIdentifier: identifier, owner: nil) as? TunnelCellView {
            cell = reused
        } else {
            cell = TunnelCellView(frame: .zero)
            cell.identifier = identifier
        }
        let tunnel = tunnels[row]
        cell.configure(name: tunnel.displayName, status: tunnel.state.displayText)
        return cell
    }

    // MARK: - Actions

    @objc private func newTunnelTapped() {
        let sessions = manager.store.sessions.filter { $0.kind == .ssh }
        let creator = NewTunnelViewController(sessions: sessions)
        let sheetWindow = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 660, height: 460),
                                   styleMask: [.titled], backing: .buffered, defer: false)
        sheetWindow.title = L.t("newTunnel")
        sheetWindow.contentViewController = creator
        creator.onStart = { [weak self, weak sheetWindow] forwards, session in
            guard let self, let sheetWindow else { return }
            self.manager.startTunnels(for: session, forwards: forwards)
            self.window?.endSheet(sheetWindow)
        }
        creator.onCancel = { [weak self, weak sheetWindow] in
            guard let self, let sheetWindow else { return }
            self.window?.endSheet(sheetWindow)
        }
        window?.beginSheet(sheetWindow)
    }

    @objc private func stopSelected() {
        let row = tableView.selectedRow
        guard row >= 0, row < tunnels.count else { return }
        manager.stopTunnel(id: tunnels[row].id)
    }

    @objc private func stopAll() {
        manager.stopAllTunnels()
    }
}

final class TunnelCellView: NSTableCellView {
    private let nameLabel = NSTextField(labelWithString: "")
    private let statusLabel = NSTextField(labelWithString: "")

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        nameLabel.font = .monospacedSystemFont(ofSize: 12, weight: .medium)
        nameLabel.lineBreakMode = .byTruncatingTail
        statusLabel.font = .systemFont(ofSize: 11)
        statusLabel.textColor = .secondaryLabelColor
        statusLabel.lineBreakMode = .byTruncatingTail
        addSubview(nameLabel)
        addSubview(statusLabel)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(name: String, status: String) {
        nameLabel.stringValue = name
        statusLabel.stringValue = status
        statusLabel.textColor = status.hasPrefix(L.t("failed"))
            ? .systemRed
            : (status == L.t("running") ? .systemGreen : .secondaryLabelColor)
    }

    override func layout() {
        super.layout()
        nameLabel.frame = NSRect(x: 8, y: bounds.height - 22, width: bounds.width - 16, height: 17)
        statusLabel.frame = NSRect(x: 8, y: 4, width: bounds.width - 16, height: 14)
    }
}

/// Sheet used to create tunnels without opening a terminal session.
final class NewTunnelViewController: NSViewController {
    private let serverPopup = NSPopUpButton()
    private let forwardsEditor = PortForwardEditorViewController()
    private let sessions: [Session]

    var onStart: (([PortForward], Session) -> Void)?
    var onCancel: (() -> Void)?

    init(sessions: [Session]) {
        self.sessions = sessions
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        let container = NSView(frame: NSRect(x: 0, y: 0, width: 660, height: 460))
        view = container

        let titleLabel = NSTextField(labelWithString: L.t("newTunnel"))
        titleLabel.font = .systemFont(ofSize: 15, weight: .semibold)
        titleLabel.frame = NSRect(x: 16, y: container.bounds.height - 34, width: 300, height: 22)
        container.addSubview(titleLabel)

        let serverLabel = NSTextField(labelWithString: L.t("chooseServer"))
        serverLabel.alignment = .right
        serverLabel.font = .systemFont(ofSize: 12)
        serverLabel.frame = NSRect(x: 16, y: container.bounds.height - 66, width: 90, height: 18)
        container.addSubview(serverLabel)

        if sessions.isEmpty {
            let message = NSTextField(labelWithString: L.t("noServersForTunnel"))
            message.textColor = .secondaryLabelColor
            message.font = .systemFont(ofSize: 12)
            message.lineBreakMode = .byWordWrapping
            message.maximumNumberOfLines = 2
            message.frame = NSRect(x: 114, y: container.bounds.height - 68, width: 380, height: 24)
            container.addSubview(message)
        } else {
            for session in sessions {
                serverPopup.addItem(withTitle: session.name.isEmpty ? session.displayHost : session.name)
                serverPopup.lastItem?.representedObject = session
            }
            serverPopup.frame = NSRect(x: 114, y: container.bounds.height - 68, width: 280, height: 24)
            container.addSubview(serverPopup)
        }

        forwardsEditor.showsDoneButton = false
        addChild(forwardsEditor)
        forwardsEditor.view.frame = NSRect(x: 0, y: 44, width: container.bounds.width,
                                           height: container.bounds.height - 116)
        forwardsEditor.view.autoresizingMask = [.width, .height]
        container.addSubview(forwardsEditor.view)

        let cancelButton = NSButton(title: L.t("cancel"), target: self, action: #selector(cancelTapped))
        let startButton = NSButton(title: L.t("start"), target: self, action: #selector(startTapped))
        startButton.keyEquivalent = "\r"
        cancelButton.bezelStyle = .rounded
        startButton.bezelStyle = .rounded
        cancelButton.frame = NSRect(x: container.bounds.width - 170, y: 8, width: 74, height: 26)
        startButton.frame = NSRect(x: container.bounds.width - 88, y: 8, width: 74, height: 26)
        cancelButton.autoresizingMask = [.minXMargin]
        startButton.autoresizingMask = [.minXMargin]
        startButton.isEnabled = !sessions.isEmpty
        container.addSubview(cancelButton)
        container.addSubview(startButton)
    }

    @objc private func cancelTapped() {
        onCancel?()
    }

    @objc private func startTapped() {
        guard serverPopup.indexOfSelectedItem >= 0,
              let session = serverPopup.selectedItem?.representedObject as? Session else { return }
        let forwards = forwardsEditor.forwards
        guard !forwards.isEmpty else {
            let alert = NSAlert()
            alert.messageText = L.t("portForwarding")
            alert.informativeText = L.t("noForwards")
            alert.addButton(withTitle: L.t("ok"))
            if let window = view.window {
                alert.beginSheetModal(for: window) { _ in }
            }
            return
        }
        onStart?(forwards, session)
    }
}
