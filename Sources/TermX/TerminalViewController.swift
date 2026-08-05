import AppKit
import SwiftTerm
import TermXCore

/// One terminal tab: owns a SwiftTerm view plus the PTY-backed session.
final class TerminalViewController: NSViewController {
    let session: Session
    private let store: SessionStore

    private(set) var terminalView: TerminalView!
    private var pty: PTYProcess?
    private var currentTheme: TermTheme

    private var pendingPassword: String?
    private var authInjected = false
    private var authMatcher = SSHAuth.PromptMatcher()
    private var authStartedAt = Date()
    /// After auto-filling the password, ssh emits a newline before the login
    /// banner; absorb that single leading line break so no blank line follows
    /// the (hidden) password prompt.
    private var suppressLeadingNewline = false

    private(set) var ended = false
    private var usesMetal = false

    var onServerTitleChange: ((String?) -> Void)?
    var onSessionEnded: (() -> Void)?

    /// The tab/window title is the session's alias, so a server-side OSC
    /// title never replaces the name the user chose.
    var displayTitle: String { session.name }

    /// Full buffer content (scrollback + visible screen) as UTF-8 data.
    func exportTerminalLog() -> Data {
        terminalView.terminal.getBufferAsData(kind: .active, encoding: .utf8)
    }

    init(session: Session, store: SessionStore) {
        self.session = session
        self.store = store
        self.currentTheme = ThemeStore.shared.defaultTheme
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        let container = NSView(frame: NSRect(x: 0, y: 0, width: 800, height: 600))
        view = container

        let font = NSFont.monospacedSystemFont(ofSize: ThemeStore.fontSize, weight: .regular)
        let termView = TermXTerminalView(frame: container.bounds, font: font)
        termView.autoresizingMask = [.width, .height]
        termView.terminalDelegate = self
        container.addSubview(termView)
        terminalView = termView

        termView.changeScrollback(10_000)
        apply(theme: ThemeStore.shared.defaultTheme)
        applyAppearance()
    }

    override func viewDidAppear() {
        super.viewDidAppear()
        applyAppearance()
        view.window?.makeFirstResponder(terminalView)
    }

    func start() {
        let process = PTYProcess()
        process.onData = { [weak self, weak process] data in
            DispatchQueue.main.async {
                self?.handleOutput(data)
                process?.processedChunk()
            }
        }
        process.onExit = { [weak self] in
            self?.handleExit()
        }

        do {
            switch session.kind {
            case .local:
                try process.spawn(path: Self.shellPath,
                                  arguments: ["-l"],
                                  environment: Self.terminalEnvironment,
                                  workingDirectory: NSHomeDirectory())
            case .ssh:
                try process.spawn(path: "/usr/bin/ssh", arguments: sshArguments, environment: Self.terminalEnvironment)
            }
            if session.kind == .ssh,
               session.authMethod == .password,
               let password = store.password(for: session) {
                pendingPassword = password
                authStartedAt = Date()
            }
            pty = process
        } catch {
            handleSpawnError(error)
        }
    }

    func terminateSession() {
        pty?.terminate()
        pty = nil
    }

    func apply(theme: TermTheme) {
        currentTheme = theme
        guard let view = terminalView else { return }
        view.nativeForegroundColor = theme.fg.nsColor
        view.caretColor = theme.cursor.nsColor
        view.selectedTextBackgroundColor = theme.selection.nsColor
        view.selectedTextForegroundColor = theme.bg.nsColor
        view.installColors(theme.ansi.map { $0.swiftTermColor })
        applyAppearance()
    }

    /// Applies the current background opacity + frosted-glass setting.
    func applyAppearance() {
        guard let view = terminalView else { return }
        let opacity = TerminalAppearance.backgroundOpacity
        let transparency = opacity < 1.0

        let background = currentTheme.bg.nsColor.withAlphaComponent(opacity)
        view.nativeBackgroundColor = background
        // SwiftTerm only sets the layer background once at startup; keep the
        // full-area background (with alpha) in sync ourselves.
        view.layer?.backgroundColor = background.cgColor
        view.needsDisplay = true

        // A transparent window costs extra compositing; stay opaque unless
        // the user actually uses translucency.
        if let window = view.window {
            window.isOpaque = !transparency
            window.backgroundColor = transparency ? .clear : .windowBackgroundColor
        }
        updateRenderer(wantsMetal: !transparency)
    }

    /// Metal rendering is much faster but requires an opaque surface, so it
    /// is only used when translucency is off.
    private func updateRenderer(wantsMetal: Bool) {
        let canUseMetal = wantsMetal && terminalView.window != nil
        guard canUseMetal != usesMetal else { return }
        do {
            try terminalView.setUseMetal(canUseMetal)
            usesMetal = canUseMetal
        } catch {
            usesMetal = false
        }
    }

    func setFontSize(_ size: CGFloat) {
        guard let view = terminalView else { return }
        view.font = NSFont.monospacedSystemFont(ofSize: size, weight: .regular)
        view.needsDisplay = true
    }

    // MARK: - Internals

    private static var shellPath: String {
        ProcessInfo.processInfo.environment["SHELL"] ?? "/bin/zsh"
    }

    private static var terminalEnvironment: [String: String] {
        [
            "TERM": "xterm-256color",
            "COLORTERM": "truecolor",
            "TERM_PROGRAM": "TermX",
        ]
    }

    private var sshArguments: [String] {
        var args = [
            "-tt",
            "-o", "StrictHostKeyChecking=accept-new",
            "-o", "ForwardX11=no",
            "-o", "GSSAPIAuthentication=no",
            "-o", "ForwardAgent=no",
            "-o", "ServerAliveInterval=15",
            "-o", "ServerAliveCountMax=3",
            "-p", "\(session.port)",
        ]
        args += SSHAuth.authArguments(authMethod: session.authMethod, keyPath: session.keyPath)
        args.append("\(session.username)@\(session.host)")
        return args
    }

    /// Runs on the main thread. SwiftTerm's view callbacks mutate the view
    /// hierarchy (e.g. cursor hide), so parsing must stay on the main thread;
    /// the reader is throttled to a bounded queue instead, which still gives
    /// backpressure without flooding the main queue.
    private func handleOutput(_ data: Data) {
        var dataToFeed = data
        if suppressLeadingNewline {
            if dataToFeed.starts(with: [0x0D, 0x0A]) {
                dataToFeed.removeFirst(2)
                suppressLeadingNewline = false
            } else if dataToFeed.starts(with: [0x0A]) || dataToFeed.starts(with: [0x0D]) {
                dataToFeed.removeFirst(1)
                suppressLeadingNewline = false
            }
        }
        if let password = pendingPassword, !authInjected {
            if Date().timeIntervalSince(authStartedAt) > 25 {
                pendingPassword = nil
            } else if let match = authMatcher.scan(data) {
                // The prompt is auto-answered, so strip it from the visible
                // output instead of leaving a lingering "host's password:"
                // line in the terminal.
                let chunkStart = authMatcher.buffer.count - data.count
                if match.upperBound > chunkStart {
                    // Extend back to the start of the prompt line so the whole
                    // "user@host's password: " line is hidden, not just the
                    // "password:" part.
                    var start = max(chunkStart, match.lowerBound)
                    var cursor = start
                    while cursor > chunkStart {
                        let previous = authMatcher.buffer[cursor - 1]
                        if previous == 0x0A || previous == 0x0D {
                            break
                        }
                        cursor -= 1
                    }
                    start = cursor
                    var end = match.upperBound
                    // Drop one trailing space after the colon if present.
                    if end < authMatcher.buffer.count, authMatcher.buffer[end] == 0x20 {
                        end += 1
                    }
                    if start < end, end <= authMatcher.buffer.count {
                        let startInChunk = start - chunkStart
                        let endInChunk = end - chunkStart
                        if startInChunk >= 0, endInChunk <= dataToFeed.count, startInChunk < endInChunk {
                            dataToFeed = Data(dataToFeed.prefix(startInChunk)) + Data(dataToFeed.suffix(from: endInChunk))
                        }
                    }
                }
                authInjected = true
                pendingPassword = nil
                suppressLeadingNewline = true
                pty?.write(Data((password + "\n").utf8))
            }
        }
        // Feed through the view wrapper: it runs feedPrepare()/feedFinish(),
        // which schedule the display pass that moves the terminal caret.
        terminalView.feed(byteArray: [UInt8](dataToFeed)[...])
    }

    private func handleExit() {
        guard !ended else { return }
        ended = true
        pty = nil
        terminalView.feed(text: "\u{1b}[0m" + L.t("sessionEnded"))
        onSessionEnded?()
    }

    private func handleSpawnError(_ error: Error) {
        ended = true
        terminalView.feed(text: String(format: L.t("spawnFailed"), error.localizedDescription))
        onSessionEnded?()
    }
}

extension TerminalViewController: TerminalViewDelegate {
    func send(source: TerminalView, data: ArraySlice<UInt8>) {
        pty?.write(Data(data))
    }

    func setTerminalTitle(source: TerminalView, title: String) {
        onServerTitleChange?(title)
    }

    func sizeChanged(source: TerminalView, newCols: Int, newRows: Int) {
        pty?.resize(rows: newRows, cols: newCols)
    }

    func bell(source: TerminalView) {
        NSSound.beep()
    }

    func hostCurrentDirectoryUpdate(source: TerminalView, directory: String?) {}

    func scrolled(source: TerminalView, position: Double) {}

    func clipboardCopy(source: TerminalView, content: Data) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setData(content, forType: .string)
    }

    func clipboardRead(source: TerminalView) -> Data? {
        NSPasteboard.general.data(forType: .string)
    }

    func iTermContent(source: TerminalView, content: ArraySlice<UInt8>) {}

    func rangeChanged(source: TerminalView, startY: Int, endY: Int) {}

    func requestOpenLink(source: TerminalView, link: String, params: [String: String]) {
        guard let url = URL(string: link) else { return }
        NSWorkspace.shared.open(url)
    }
}
