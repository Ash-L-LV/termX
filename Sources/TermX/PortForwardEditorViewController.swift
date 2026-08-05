import AppKit
import TermXCore

/// Table + inline form for editing a session's port-forwarding rules.
/// Can be presented as a sheet or embedded as a child view controller.
final class PortForwardEditorViewController: NSViewController, NSTableViewDataSource, NSTableViewDelegate {
    private let tableView = NSTableView()
    private let formView = NSView()
    private let kindPopup = NSPopUpButton()
    private let portField = NSTextField()
    private let hostField = NSTextField()
    private let remotePortField = NSTextField()
    private var editingIndex: Int?
    private var hostColumn: NSGridColumn!
    private var remotePortColumn: NSGridColumn!

    var forwards: [PortForward] = []
    var showsDoneButton = true
    var onChange: (([PortForward]) -> Void)?
    var onDone: (() -> Void)?

    override func loadView() {
        let container = NSView(frame: NSRect(x: 0, y: 0, width: 640, height: 420))
        view = container

        let scroll = NSScrollView(frame: NSRect(x: 0, y: 120,
                                                width: container.bounds.width,
                                                height: container.bounds.height - 156))
        scroll.autoresizingMask = [.width, .height]
        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("Forward"))
        column.resizingMask = .autoresizingMask
        tableView.addTableColumn(column)
        tableView.headerView = nil
        tableView.rowHeight = 26
        tableView.style = .plain
        tableView.dataSource = self
        tableView.delegate = self
        tableView.allowsEmptySelection = true
        scroll.documentView = tableView
        container.addSubview(scroll)

        let addButton = NSButton(title: L.t("add"), target: self, action: #selector(addTapped))
        let editButton = NSButton(title: L.t("edit"), target: self, action: #selector(editTapped))
        let removeButton = NSButton(title: L.t("delete"), target: self, action: #selector(removeTapped))
        for button in [addButton, editButton, removeButton] {
            button.bezelStyle = .rounded
            button.controlSize = .small
        }
        let buttons = NSStackView(views: [addButton, editButton, removeButton])
        buttons.orientation = .horizontal
        buttons.spacing = 8
        buttons.frame = NSRect(x: 10, y: 92, width: 280, height: 26)
        buttons.autoresizingMask = [.maxXMargin]
        container.addSubview(buttons)

        if showsDoneButton {
            let doneButton = NSButton(title: L.t("done"), target: self, action: #selector(doneTapped))
            doneButton.bezelStyle = .rounded
            doneButton.keyEquivalent = "\r"
            doneButton.frame = NSRect(x: container.bounds.width - 92, y: 92, width: 82, height: 26)
            doneButton.autoresizingMask = [.minXMargin]
            container.addSubview(doneButton)
        }

        formView.frame = NSRect(x: 10, y: 4, width: container.bounds.width - 20, height: 84)
        formView.autoresizingMask = [.width]
        formView.isHidden = true
        container.addSubview(formView)
        setupForm()
    }

    private func setupForm() {
        kindPopup.addItems(withTitles: PortForward.Kind.allCases.map { $0.displayName })
        kindPopup.target = self
        kindPopup.action = #selector(kindChanged)
        portField.placeholderString = "8080"
        hostField.placeholderString = "127.0.0.1"
        remotePortField.placeholderString = "80"

        let dirLabel = makeFormLabel(L.t("direction"))
        let portLabel = makeFormLabel(L.t("port"))
        let hostLabel = makeFormLabel(L.t("targetHost"))
        let remotePortLabel = makeFormLabel(L.t("targetPort"))
        let saveButton = NSButton(title: L.t("save"), target: self, action: #selector(formSaveTapped))
        let cancelButton = NSButton(title: L.t("cancel"), target: self, action: #selector(formCancelTapped))
        saveButton.bezelStyle = .rounded
        saveButton.keyEquivalent = "\r"
        cancelButton.bezelStyle = .rounded

        let grid = NSGridView(views: [
            [dirLabel, portLabel, hostLabel, remotePortLabel],
            [kindPopup, portField, hostField, remotePortField],
            [cancelButton, saveButton, NSView(), NSView()],
        ])
        grid.rowSpacing = 4
        grid.columnSpacing = 10
        grid.translatesAutoresizingMaskIntoConstraints = false
        formView.addSubview(grid)
        NSLayoutConstraint.activate([
            grid.leadingAnchor.constraint(equalTo: formView.leadingAnchor),
            grid.topAnchor.constraint(equalTo: formView.topAnchor),
            grid.trailingAnchor.constraint(lessThanOrEqualTo: formView.trailingAnchor),
            grid.bottomAnchor.constraint(lessThanOrEqualTo: formView.bottomAnchor),
        ])
        hostColumn = grid.column(at: 2)
        remotePortColumn = grid.column(at: 3)
        kindChanged()
    }

    private func makeFormLabel(_ text: String) -> NSTextField {
        let label = NSTextField(labelWithString: text)
        label.font = .systemFont(ofSize: 10)
        label.textColor = .secondaryLabelColor
        return label
    }

    // MARK: - Table

    func numberOfRows(in tableView: NSTableView) -> Int {
        forwards.count
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let identifier = NSUserInterfaceItemIdentifier("ForwardCell")
        let label: NSTextField
        if let reused = tableView.makeView(withIdentifier: identifier, owner: nil) as? NSTextField {
            label = reused
        } else {
            label = NSTextField(labelWithString: "")
            label.identifier = identifier
            label.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
        }
        label.stringValue = forwards[row].displayName
        return label
    }

    // MARK: - Actions

    private func notifyChange() {
        onChange?(forwards)
        tableView.reloadData()
    }

    @objc private func addTapped() {
        editingIndex = nil
        resetForm()
        formView.isHidden = false
        view.window?.makeFirstResponder(portField)
    }


    @objc private func editTapped() {
        let row = tableView.selectedRow
        guard row >= 0, row < forwards.count else { return }
        editingIndex = row
        let forward = forwards[row]
        kindPopup.selectItem(at: PortForward.Kind.allCases.firstIndex(of: forward.kind) ?? 0)
        portField.stringValue = "\(forward.bindPort)"
        hostField.stringValue = forward.remoteHost
        remotePortField.stringValue = forward.remotePort > 0 ? "\(forward.remotePort)" : ""
        kindChanged()
        formView.isHidden = false
        view.window?.makeFirstResponder(portField)
    }

    @objc private func removeTapped() {
        let row = tableView.selectedRow
        guard row >= 0, row < forwards.count else { return }
        forwards.remove(at: row)
        notifyChange()
    }

    @objc private func doneTapped() {
        formView.isHidden = true
        onDone?()
    }

    @objc private func kindChanged() {
        let isDynamic = kindPopup.indexOfSelectedItem == 2
        hostColumn?.isHidden = isDynamic
        remotePortColumn?.isHidden = isDynamic
    }

    @objc private func formSaveTapped() {
        let kind = PortForward.Kind.allCases[kindPopup.indexOfSelectedItem]
        guard let bindPort = Int(portField.stringValue.trimmingCharacters(in: .whitespaces)),
              bindPort > 0, bindPort < 65536 else { return }
        let host = hostField.stringValue.trimmingCharacters(in: .whitespaces)
        if kind != .dynamic && host.isEmpty { return }
        let remotePort = kind == .dynamic ? 0
            : Int(remotePortField.stringValue.trimmingCharacters(in: .whitespaces)) ?? 0
        if kind != .dynamic, remotePort <= 0 { return }

        let forward = PortForward(kind: kind, bindPort: bindPort,
                                  remoteHost: host, remotePort: remotePort)
        if let index = editingIndex, index < forwards.count {
            forwards[index] = forward
        } else {
            forwards.append(forward)
        }
        formView.isHidden = true
        notifyChange()
    }

    @objc private func formCancelTapped() {
        formView.isHidden = true
    }

    private func resetForm() {
        kindPopup.selectItem(at: 0)
        portField.stringValue = "8080"
        hostField.stringValue = ""
        remotePortField.stringValue = "80"
        kindChanged()
    }
}
