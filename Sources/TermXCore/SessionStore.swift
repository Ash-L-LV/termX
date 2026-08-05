import Foundation

public extension Notification.Name {
    static let sessionsDidChange = Notification.Name("TermX.sessionsDidChange")
}

/// Persists the session list as JSON in Application Support. Passwords are
/// stored inside the same file with basic obfuscation (per user preference);
/// older Keychain entries are migrated once on first launch.
public final class SessionStore {
    public static let directoryURL: URL = {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("TermX", isDirectory: true)
    }()

    public static let fileURL = directoryURL.appendingPathComponent("sessions.json")
    /// Backup of the previous sessions file, rotated before every save.
    public static let backupURL = directoryURL.appendingPathComponent("sessions.json.bak")

    public private(set) var sessions: [Session] = []

    public init() {
        load()
    }

    public func load() {
        do {
            let data = try Data(contentsOf: Self.fileURL)
            var decoded = try JSONDecoder().decode([Session].self, from: data)
            // De-obfuscate locally stored passwords.
            for index in decoded.indices {
                if let obfuscated = decoded[index].password {
                    decoded[index].password = Self.deobfuscate(obfuscated)
                }
            }
            // One-time migration from the old Keychain storage.
            for index in decoded.indices where decoded[index].password == nil {
                if let legacy = KeychainHelper.getPassword(account: decoded[index].id.uuidString) {
                    decoded[index].password = legacy
                    KeychainHelper.deletePassword(account: decoded[index].id.uuidString)
                }
            }
            sessions = decoded.sorted { $0.createdAt > $1.createdAt }
        } catch {
            sessions = []
        }
        if !sessions.isEmpty {
            save()
        }
    }

    public func save() {
        do {
            try FileManager.default.createDirectory(at: Self.directoryURL, withIntermediateDirectories: true)
            // Keep a backup of the previous file so data can be recovered if
            // the store is ever cleared or written badly.
            if FileManager.default.fileExists(atPath: Self.fileURL.path) {
                try? FileManager.default.removeItem(at: Self.backupURL)
                try? FileManager.default.copyItem(at: Self.fileURL, to: Self.backupURL)
            }
            var encodable = sessions
            for index in encodable.indices {
                if let plain = encodable[index].password {
                    encodable[index].password = Self.obfuscate(plain)
                }
            }
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(encodable)
            try data.write(to: Self.fileURL, options: .atomic)
        } catch {
            NSLog("TermX: failed to save sessions: \(error)")
        }
    }

    public func upsert(_ session: Session) {
        if let index = sessions.firstIndex(where: { $0.id == session.id }) {
            sessions[index] = session
        } else {
            sessions.insert(session, at: 0)
        }
        save()
        NotificationCenter.default.post(name: .sessionsDidChange, object: self)
    }

    public func delete(_ session: Session) {
        sessions.removeAll { $0.id == session.id }
        save()
        NotificationCenter.default.post(name: .sessionsDidChange, object: self)
    }

    public func password(for session: Session) -> String? {
        session.savePassword ? session.password : nil
    }

    public func session(withID id: UUID) -> Session? {
        sessions.first { $0.id == id }
    }

    // MARK: - Basic local obfuscation (not real encryption; per user request)

    private static let obfuscationKey = Array("TermX.local.2026".utf8)

    public static func obfuscate(_ text: String) -> String {
        var bytes = Array(text.utf8)
        for index in bytes.indices {
            bytes[index] ^= obfuscationKey[index % obfuscationKey.count]
        }
        return Data(bytes).base64EncodedString()
    }

    public static func deobfuscate(_ text: String) -> String? {
        guard let data = Data(base64Encoded: text) else { return nil }
        var bytes = Array(data)
        for index in bytes.indices {
            bytes[index] ^= obfuscationKey[index % obfuscationKey.count]
        }
        return String(bytes: bytes, encoding: .utf8)
    }
}
