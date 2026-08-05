import Foundation
import TermXCore

/// A background `ssh -N` port-forwarding tunnel.
final class TunnelProcess {
    enum State: Equatable {
        case starting
        case running
        case stopped
        case failed(String)

        var displayText: String {
            switch self {
            case .starting: return L.t("starting")
            case .running: return L.t("running")
            case .stopped: return L.t("stopped")
            case .failed(let message): return L.t("failed") + ": " + message
            }
        }
    }

    let id = UUID()
    let forward: PortForward
    let sourceName: String

    private let pty = PTYProcess()
    private var pendingPassword: String?
    private var authInjected = false
    private var authMatcher = SSHAuth.PromptMatcher()
    private var errorBuffer = Data()

    private(set) var state: State = .starting
    var onStateChange: ((TunnelProcess) -> Void)?

    var displayName: String {
        sourceName.isEmpty ? forward.displayName : "\(forward.displayName) · \(sourceName)"
    }

    init(forward: PortForward, sourceName: String) {
        self.forward = forward
        self.sourceName = sourceName
    }

    func start(password: String?, host: String, port: Int, username: String,
               authMethod: Session.AuthMethod, keyPath: String?) {
        pendingPassword = password
        let args = Self.sshArguments(forward: forward, host: host, port: port,
                                     username: username, authMethod: authMethod, keyPath: keyPath)
        pty.onData = { [weak self] data in self?.handleOutput(data) }
        pty.onExit = { [weak self] in
            guard let self else { return }
            if let error = self.lastError {
                self.setState(.failed(error))
            } else {
                self.setState(.stopped)
            }
        }
        do {
            try pty.spawn(path: "/usr/bin/ssh", arguments: args,
                          environment: ["TERM": "xterm-256color"])
            setState(.running)
        } catch {
            setState(.failed(error.localizedDescription))
        }
    }

    func stop() {
        pty.terminate()
    }

    private var lastError: String? {
        let text = String(data: errorBuffer, encoding: .utf8) ?? ""
        let markers = ["Permission denied", "Address already in use", "Could not resolve hostname",
                       "Connection refused", "Connection timed out", "No route to host",
                       "Cannot assign requested address", "Operation timed out",
                       "port is already in use", "ssh_askpass"]
        for marker in markers where text.contains(marker) {
            return marker
        }
        return nil
    }

    private func handleOutput(_ data: Data) {
        if let password = pendingPassword, !authInjected, authMatcher.scan(data) != nil {
            authInjected = true
            pendingPassword = nil
            pty.write(Data((password + "\n").utf8))
        }
        errorBuffer.append(data)
        if errorBuffer.count > 16_384 {
            errorBuffer.removeFirst(errorBuffer.count - 16_384)
        }
        // Release the reader's bounded-backpressure slot so it keeps draining
        // (and can notice EOF / error output) instead of stalling forever.
        pty.processedChunk()
    }

    private func setState(_ newState: State) {
        state = newState
        onStateChange?(self)
    }

    static func sshArguments(forward: PortForward, host: String, port: Int, username: String,
                             authMethod: Session.AuthMethod, keyPath: String?) -> [String] {
        var args = ["-N",
                    "-o", "StrictHostKeyChecking=accept-new",
                    "-o", "ForwardX11=no",
                    "-o", "GSSAPIAuthentication=no",
                    "-o", "ServerAliveInterval=15",
                    "-o", "ServerAliveCountMax=3",
                    "-p", "\(port)"]
        switch forward.kind {
        case .local:
            args += ["-L", "\(forward.bindPort):\(forward.remoteHost):\(forward.remotePort)"]
        case .remote:
            args += ["-R", "\(forward.bindPort):\(forward.remoteHost):\(forward.remotePort)"]
        case .dynamic:
            args += ["-D", "\(forward.bindPort)"]
        }
        args += SSHAuth.authArguments(authMethod: authMethod, keyPath: keyPath)
        args.append("\(username)@\(host)")
        return args
    }
}
