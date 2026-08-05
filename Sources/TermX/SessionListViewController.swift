import AppKit
import TermXCore

/// Reusable saved-server list. Used by the ＋ popover (single-click connect)
/// and the Session Manager window (double-click connect + management).
final class SessionCellView: NSTableCellView {
    private let nameLabel = NSTextField(labelWithString: "")
    private let hostLabel = NSTextField(labelWithString: "")

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        nameLabel.font = .systemFont(ofSize: 13, weight: .medium)
        nameLabel.lineBreakMode = .byTruncatingTail
        hostLabel.font = .systemFont(ofSize: 11)
        hostLabel.textColor = .secondaryLabelColor
        hostLabel.lineBreakMode = .byTruncatingTail
        addSubview(nameLabel)
        addSubview(hostLabel)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(_ session: Session) {
        nameLabel.stringValue = session.name.isEmpty ? session.displayHost : session.name
        hostLabel.stringValue = session.displayHost
        nameLabel.textColor = session.kind == .local ? .secondaryLabelColor : .labelColor
    }

    override func layout() {
        super.layout()
        nameLabel.frame = NSRect(x: 8, y: bounds.height - 24, width: bounds.width - 16, height: 18)
        hostLabel.frame = NSRect(x: 8, y: 5, width: bounds.width - 16, height: 15)
    }
}

final class SessionListViewController: NSViewController, NSTableViewDataSource, NSTableViewDelegate {
    private let store: SessionStore
    private let tableView = NSTableView()
    private let emptyLabel = NSTextField(labelWithString: "")

    var onConnect: ((Session) -> Void)?
    var onNewSSH: (() -> Void)?
    var onEdit: ((Session) -> Void)?
    var onDelete: ((Session) -> Void)?
    /// When true, a single click connects (used by the ＋ popover);
    /// otherwise double-click connects (Session Manager window).
    var connectOnSingleClick = false
    /// When false, the add/edit/delete button bar is hidden (＋ popover is a
    /// pure connection picker; management lives in the Server menu).
    var showManagementBar = true

    private var sessions: [Session] { store.sessions }

    init(store: SessionStore) {
        self.store = store
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    override func loadView() {
        let container = NSView(frame: NSRect(x: 0, y: 0, width: 250, height: 600))
        view = container

        let header = NSTextField(labelWithString: L.t("servers"))
        header.font = .systemFont(ofSize: 13, weight: .semibold)
        header.frame = NSRect(x: 12, y: container.bounds.height - 30, width: 180, height: 20)
        header.autoresizingMask = [.width, .minYMargin]
        container.addSubview(header)

        let scroll = NSScrollView(frame: NSRect(x: 0, y: 44, width: container.bounds.width, height: container.bounds.height - 80))
        scroll.autoresizingMask = [.width, .height]
        scroll.hasVerticalScroller = true
        scroll.hasHorizontalScroller = false
        scroll.borderType = .noBorder

        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("Session"))
        column.resizingMask = .autoresizingMask
        tableView.addTableColumn(column)
        tableView.columnAutoresizingStyle = .lastColumnOnlyAutoresizingStyle
        tableView.headerView = nil
        tableView.rowHeight = 44
        tableView.style = .inset
        tableView.dataSource = self
        tableView.delegate = self
        tableView.target = self
        tableView.action = #selector(clicked)
        tableView.doubleAction = #selector(connectSelected)
        tableView.allowsEmptySelection = true

        let menu = NSMenu()
        let connectItem = NSMenuItem(title: L.t("connect"), action: #selector(connectSelected), keyEquivalent: "")
        let editItem = NSMenuItem(title: L.t("editEllipsis"), action: #selector(editSelected), keyEquivalent: "")
        let deleteItem = NSMenuItem(title: L.t("deleteEllipsis"), action: #selector(deleteSelected), keyEquivalent: "")
        menu.addItem(connectItem)
        menu.addItem(editItem)
        menu.addItem(.separator())
        menu.addItem(deleteItem)
        for item in menu.items { item.target = self }
        tableView.menu = menu

        scroll.documentView = tableView
        tableView.frame = NSRect(x: 0, y: 0, width: scroll.contentSize.width, height: 600)
        tableView.autoresizingMask = [.width]
        container.addSubview(scroll)

        let newSSH = NSButton(title: L.t("addSSH"), target: self, action: #selector(newSSHTapped))
        let edit = NSButton(title: L.t("edit"), target: self, action: #selector(editSelected))
        let delete = NSButton(title: L.t("delete"), target: self, action: #selector(deleteSelected))
        for button in [newSSH, edit, delete] {
            button.bezelStyle = .rounded
            button.controlSize = .small
        }
        let stack = NSStackView(views: [newSSH, edit, delete])
        stack.orientation = .horizontal
        stack.spacing = 6
        stack.distribution = .fillEqually
        stack.frame = NSRect(x: 10, y: 8, width: container.bounds.width - 20, height: 26)
        stack.autoresizingMask = [.width, .maxYMargin]
        container.addSubview(stack)
        stack.isHidden = !showManagementBar

        emptyLabel.stringValue = L.t("emptySessions")
        emptyLabel.alignment = .center
        emptyLabel.textColor = .tertiaryLabelColor
        emptyLabel.font = .systemFont(ofSize: 12)
        emptyLabel.isHidden = true
        container.addSubview(emptyLabel)

        NotificationCenter.default.addObserver(self,
                                               selector: #selector(reload),
                                               name: .sessionsDidChange,
                                               object: nil)
        reload()
    }

    override func viewDidLayout() {
        super.viewDidLayout()
        tableView.sizeLastColumnToFit()
        emptyLabel.sizeToFit()
        emptyLabel.frame = NSRect(x: (view.bounds.width - emptyLabel.frame.width) / 2,
                                  y: (view.bounds.height - emptyLabel.frame.height) / 2 - 20,
                                  width: emptyLabel.frame.width,
                                  height: emptyLabel.frame.height)
    }

    @objc private func reload() {
        tableView.reloadData()
        emptyLabel.isHidden = !sessions.isEmpty
    }

    // MARK: - NSTableViewDataSource / Delegate

    func numberOfRows(in tableView: NSTableView) -> Int {
        sessions.count
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let identifier = NSUserInterfaceItemIdentifier("SessionCell")
        let cell: SessionCellView
        if let reused = tableView.makeView(withIdentifier: identifier, owner: nil) as? SessionCellView {
            cell = reused
        } else {
            cell = SessionCellView(frame: .zero)
            cell.identifier = identifier
        }
        cell.configure(sessions[row])
        return cell
    }

    // MARK: - Actions

    private var selectedSession: Session? {
        let row = tableView.clickedRow >= 0 ? tableView.clickedRow : tableView.selectedRow
        guard row >= 0, row < sessions.count else { return nil }
        return sessions[row]
    }

    @objc private func connectSelected() {
        guard let session = selectedSession else { return }
        onConnect?(session)
    }

    @objc private func clicked() {
        if connectOnSingleClick {
            connectSelected()
        }
    }

    @objc private func editSelected() {
        guard let session = selectedSession else { return }
        onEdit?(session)
    }

    @objc private func deleteSelected() {
        guard let session = selectedSession else { return }
        onDelete?(session)
    }

    @objc private func newSSHTapped() {
        onNewSSH?()
    }

}
