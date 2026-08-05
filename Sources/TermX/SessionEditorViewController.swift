import AppKit
import TermXCore

/// Sheet for creating or editing a session (SSH or local), covering
/// authentication, saved passwords, tab colors, and port-forwarding rules.
final class SessionEditorViewController: NSViewController {
    private let original: Session?

    private let nameField = NSTextField()
    private let typePopup = NSPopUpButton()
    private let hostField = NSTextField()
    private let portField = NSTextField()
    private let userField = NSTextField()
    private let authPopup = NSPopUpButton()
    private let passwordField = NSSecureTextField()
    private let savePasswordCheck = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    private let keyPathField = NSTextField()
    private let browseButton = NSButton(title: "", target: nil, action: nil)
    private let colorCheck = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    private let colorWell = NSColorWell()
    private let forwardsButton = NSButton()
    private var pendingForwards: [PortForward] = []
    private var forwardsWindow: NSWindow?

    private var grid: NSGridView!
    private var hostRow: NSGridRow!
    private var portRow: NSGridRow!
    private var userRow: NSGridRow!
    private var authRow: NSGridRow!
    private var passwordRow: NSGridRow!
    private var saveRow: NSGridRow!
    private var keyRow: NSGridRow!
    private var colorRow: NSGridRow!
    private var forwardsRow: NSGridRow!

    var onSave: ((Session) -> Void)?
    var onCancel: (() -> Void)?

    init(session: Session?) {
        self.original = session
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    static func present(from window: NSWindow, session: Session?, onSave: @escaping (Session) -> Void) {
        let editor = SessionEditorViewController(session: session)
        editor.onSave = onSave
        editor.onCancel = {}
        window.contentViewController?.presentAsSheet(editor)
    }

    override func loadView() {
        let container = NSView(frame: NSRect(x: 0, y: 0, width: 500, height: 480))
        view = container

        let titleLabel = NSTextField(labelWithString: original == nil ? L.t("newSSHTitle") : L.t("editTitle"))
        titleLabel.font = .systemFont(ofSize: 15, weight: .semibold)
        titleLabel.frame = NSRect(x: 18, y: container.bounds.height - 36, width: 300, height: 24)
        container.addSubview(titleLabel)

        typePopup.addItems(withTitles: [L.t("sshType"), L.t("localType")])
        typePopup.target = self
        typePopup.action = #selector(typeChanged)

        authPopup.addItems(withTitles: Session.AuthMethod.allCases.map { $0.displayName })
        authPopup.target = self
        authPopup.action = #selector(authChanged)

        browseButton.title = L.t("browse")
        browseButton.bezelStyle = .rounded
        browseButton.target = self
        browseButton.action = #selector(browseKey)

        colorCheck.target = self
        colorCheck.action = #selector(colorCheckChanged)
        colorWell.color = .systemGray
        forwardsButton.title = L.t("editForwards")
        forwardsButton.bezelStyle = .rounded
        forwardsButton.target = self
        forwardsButton.action = #selector(editForwardsTapped)

        hostField.placeholderString = L.t("placeholderHost")
        nameField.placeholderString = L.t("placeholderAlias")
        portField.placeholderString = "22"
        userField.placeholderString = "root"
        keyPathField.placeholderString = L.t("placeholderKey")
        passwordField.placeholderString = L.t("placeholderPassword")
        savePasswordCheck.state = .on
        savePasswordCheck.title = L.t("savePassword")
        colorCheck.title = L.t("customTabColor")

        grid = NSGridView(views: [
            [makeLabel(L.t("alias")), nameField],
            [makeLabel(L.t("type")), typePopup],
            [makeLabel(L.t("host")), hostField],
            [makeLabel(L.t("port")), portField],
            [makeLabel(L.t("username")), userField],
            [makeLabel(L.t("auth")), authPopup],
            [NSView(), savePasswordCheck],
            [makeLabel(L.t("password")), passwordField],
            [makeLabel(L.t("keyFile")), keyPathField, browseButton],
            [makeLabel(L.t("tabColor")), NSStackView(views: [colorCheck, colorWell])],
            [makeLabel(L.t("portForwarding")), forwardsButton],
        ])
        grid.rowSpacing = 10
        grid.columnSpacing = 10
        grid.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(grid)

        NSLayoutConstraint.activate([
            grid.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 14),
            grid.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 18),
            grid.trailingAnchor.constraint(lessThanOrEqualTo: container.trailingAnchor, constant: -18),
        ])

        let cancelButton = NSButton(title: L.t("cancel"), target: self, action: #selector(cancelTapped))
        let saveButton = NSButton(title: L.t("save"), target: self, action: #selector(saveTapped))
        saveButton.keyEquivalent = "\r"
        cancelButton.bezelStyle = .rounded
        saveButton.bezelStyle = .rounded
        let buttons = NSStackView(views: [NSView(), cancelButton, saveButton])
        buttons.orientation = .horizontal
        buttons.spacing = 8
        buttons.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(buttons)

        NSLayoutConstraint.activate([
            buttons.topAnchor.constraint(equalTo: grid.bottomAnchor, constant: 18),
            buttons.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 18),
            buttons.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -18),
            buttons.bottomAnchor.constraint(lessThanOrEqualTo: container.bottomAnchor, constant: -14),
        ])

        hostRow = grid.row(at: 2)
        portRow = grid.row(at: 3)
        userRow = grid.row(at: 4)
        authRow = grid.row(at: 5)
        saveRow = grid.row(at: 6)
        passwordRow = grid.row(at: 7)
        keyRow = grid.row(at: 8)
        colorRow = grid.row(at: 9)
        forwardsRow = grid.row(at: 10)

        if let session = original {
            nameField.stringValue = session.name
            typePopup.selectItem(at: session.kind == .ssh ? 0 : 1)
            hostField.stringValue = session.host
            portField.stringValue = "\(session.port)"
            userField.stringValue = session.username
            authPopup.selectItem(at: session.authMethod == .password ? 0 : 1)
            keyPathField.stringValue = session.keyPath ?? ""
            savePasswordCheck.state = session.savePassword ? .on : .off
            if let color = session.tabColorNSColor {
                colorCheck.state = .on
                colorWell.color = color
            }
            pendingForwards = session.portForwards
        } else {
            typePopup.selectItem(at: 0)
            authPopup.selectItem(at: 0)
        }
        colorCheckChanged()
        typeChanged()
    }

    private func makeLabel(_ text: String) -> NSTextField {
        let label = NSTextField(labelWithString: text)
        label.alignment = .right
        label.font = .systemFont(ofSize: 12)
        return label
    }

    @objc private func typeChanged() {
        let isSSH = typePopup.indexOfSelectedItem == 0
        hostRow.isHidden = !isSSH
        portRow.isHidden = !isSSH
        userRow.isHidden = !isSSH
        authRow.isHidden = !isSSH
        saveRow.isHidden = !isSSH
        passwordRow.isHidden = !isSSH
        keyRow.isHidden = !isSSH
        forwardsRow.isHidden = !isSSH
        if isSSH {
            authChanged()
        }
    }

    @objc private func authChanged() {
        let isPassword = authPopup.indexOfSelectedItem == 0
        passwordRow.isHidden = !isPassword
        saveRow.isHidden = !isPassword
        keyRow.isHidden = isPassword
    }

    @objc private func browseKey() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.message = L.t("chooseKey")
        if panel.runModal() == .OK, let url = panel.url {
            keyPathField.stringValue = url.path
        }
    }

    @objc private func editForwardsTapped() {
        openForwardsEditor()
    }

    private func openForwardsEditor() {
        let editor = PortForwardEditorViewController()
        editor.forwards = pendingForwards
        editor.onChange = { [weak self] forwards in
            self?.pendingForwards = forwards
        }
        editor.onDone = { [weak self] in
            self?.forwardsWindow?.close()
        }
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 640, height: 420),
                              styleMask: [.titled, .closable],
                              backing: .buffered,
                              defer: false)
        window.title = L.t("portForwarding")
        window.contentViewController = editor
        window.isReleasedWhenClosed = false
        window.setFrameAutosaveName("TermX.ForwardsEditor")
        window.center()
        forwardsWindow = window
        window.makeKeyAndOrderFront(nil)
    }

    @objc private func colorCheckChanged() {
        colorWell.isEnabled = colorCheck.state == .on
    }

    @objc private func cancelTapped() {
        onCancel?()
        dismiss(nil)
    }

    @objc private func saveTapped() {
        let isSSH = typePopup.indexOfSelectedItem == 0
        var name = nameField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        let host = hostField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        let port = Int(portField.stringValue.trimmingCharacters(in: .whitespaces)) ?? 22
        let username = userField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        let authMethod: Session.AuthMethod = authPopup.indexOfSelectedItem == 0 ? .password : .key
        let keyPath = keyPathField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        let savePassword = savePasswordCheck.state == .on
        let tabColor: String?
        if colorCheck.state == .on, let hex = hexString(from: colorWell.color) {
            tabColor = hex
        } else {
            tabColor = nil
        }

        if isSSH {
            if host.isEmpty || username.isEmpty {
                let alert = NSAlert()
                alert.messageText = L.t("incomplete")
                alert.informativeText = L.t("incompleteMsg")
                alert.addButton(withTitle: L.t("ok"))
                if let window = view.window {
                    alert.beginSheetModal(for: window) { _ in }
                } else {
                    alert.runModal()
                }
                return
            }
            if name.isEmpty {
                name = "\(username)@\(host)"
            }
        } else if name.isEmpty {
            name = L.t("localSession")
        }

        let password: String?
        if isSSH, authMethod == .password, savePassword {
            password = passwordField.stringValue.isEmpty ? original?.password : passwordField.stringValue
        } else {
            password = nil
        }

        let session = Session(id: original?.id ?? UUID(),
                              name: name,
                              kind: isSSH ? .ssh : .local,
                              host: host,
                              port: port,
                              username: username,
                              authMethod: authMethod,
                              keyPath: keyPath.isEmpty ? nil : keyPath,
                              savePassword: savePassword,
                              password: password,
                              tabColor: tabColor,
                              forwards: pendingForwards.isEmpty ? nil : pendingForwards,
                              createdAt: original?.createdAt ?? Date())

        onSave?(session)
        dismiss(nil)
    }

    private func hexString(from color: NSColor) -> String? {
        guard let converted = color.usingColorSpace(.sRGB) else { return nil }
        let r = Int(round(converted.redComponent * 255))
        let g = Int(round(converted.greenComponent * 255))
        let b = Int(round(converted.blueComponent * 255))
        return String(format: "#%02X%02X%02X", r, g, b)
    }
}
