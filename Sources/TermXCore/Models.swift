import Foundation
import AppKit
import SwiftTerm

/// Core data models: sessions, port-forwarding rules, tab colors, and themes.

/// A single SSH port-forwarding rule (local / remote / dynamic tunnel).
public struct PortForward: Codable, Identifiable, Equatable {
    public enum Kind: String, Codable, CaseIterable {
        case local
        case remote
        case dynamic

        public var displayName: String {
            switch self {
            case .local: return L.t("dirLocal")
            case .remote: return L.t("dirRemote")
            case .dynamic: return L.t("dirDynamic")
            }
        }
    }

    public var id: UUID
    public var kind: Kind
    public var bindPort: Int
    public var remoteHost: String
    public var remotePort: Int

    public init(id: UUID = UUID(), kind: Kind = .local, bindPort: Int = 8080,
                remoteHost: String = "", remotePort: Int = 80) {
        self.id = id
        self.kind = kind
        self.bindPort = bindPort
        self.remoteHost = remoteHost
        self.remotePort = remotePort
    }

    public var displayName: String {
        switch kind {
        case .local: return "L \(bindPort) → \(remoteHost):\(remotePort)"
        case .remote: return "R \(bindPort) → \(remoteHost):\(remotePort)"
        case .dynamic: return "D \(bindPort)"
        }
    }
}

/// A saved SSH or local terminal session.
public struct Session: Codable, Identifiable, Equatable {
    public enum Kind: String, Codable {
        case local
        case ssh
    }

    public enum AuthMethod: String, Codable, CaseIterable {
        case password
        case key

        public var displayName: String {
            switch self {
            case .password: return L.t("authPassword")
            case .key: return L.t("authKey")
            }
        }
    }

    public var id: UUID
    public var name: String
    public var kind: Kind
    public var host: String
    public var port: Int
    public var username: String
    public var authMethod: AuthMethod
    public var keyPath: String?
    public var savePassword: Bool
    public var password: String?
    public var tabColor: String?
    public var forwards: [PortForward]?
    public var createdAt: Date

    public init(id: UUID = UUID(),
                name: String,
                kind: Kind,
                host: String = "",
                port: Int = 22,
                username: String = "",
                authMethod: AuthMethod = .password,
                keyPath: String? = nil,
                savePassword: Bool = true,
                password: String? = nil,
                tabColor: String? = nil,
                forwards: [PortForward]? = nil,
                createdAt: Date = Date()) {
        self.id = id
        self.name = name
        self.kind = kind
        self.host = host
        self.port = port
        self.username = username
        self.authMethod = authMethod
        self.keyPath = keyPath
        self.savePassword = savePassword
        self.password = password
        self.tabColor = tabColor
        self.forwards = forwards
        self.createdAt = createdAt
    }

    public var displayHost: String {
        kind == .ssh ? "\(username)@\(host):\(port)" : L.t("localShell")
    }

    public var portForwards: [PortForward] {
        forwards ?? []
    }

    public static func newLocal(name: String) -> Session {
        Session(name: name, kind: .local)
    }

    public static func newSSH(name: String = "", host: String = "", port: Int = 22, username: String = "") -> Session {
        Session(name: name, kind: .ssh, host: host, port: port, username: username)
    }

    /// Parses "#RRGGBB" into an NSColor (nil when unset or malformed).
    public var tabColorNSColor: NSColor? {
        guard let tabColor, tabColor.hasPrefix("#"), tabColor.count == 7 else { return nil }
        var value: UInt64 = 0
        guard Scanner(string: String(tabColor.dropFirst())).scanHexInt64(&value) else { return nil }
        return NSColor(srgbRed: CGFloat((value >> 16) & 0xFF) / 255.0,
                       green: CGFloat((value >> 8) & 0xFF) / 255.0,
                       blue: CGFloat(value & 0xFF) / 255.0,
                       alpha: 1.0)
    }
}

/// Simple sRGB color stored as 8-bit components.
public struct RGBColor: Codable, Equatable {
    public var r: UInt8
    public var g: UInt8
    public var b: UInt8

    public init(r: UInt8, g: UInt8, b: UInt8) {
        self.r = r
        self.g = g
        self.b = b
    }

    public init(hex: UInt32) {
        r = UInt8((hex >> 16) & 0xFF)
        g = UInt8((hex >> 8) & 0xFF)
        b = UInt8(hex & 0xFF)
    }

    public var nsColor: NSColor {
        NSColor(srgbRed: CGFloat(r) / 255.0,
                green: CGFloat(g) / 255.0,
                blue: CGFloat(b) / 255.0,
                alpha: 1.0)
    }

    public var swiftTermColor: SwiftTerm.Color {
        SwiftTerm.Color(red: UInt16(r) * 257, green: UInt16(g) * 257, blue: UInt16(b) * 257)
    }
}

/// A terminal color scheme.
public struct TermTheme: Codable, Equatable, Identifiable {
    public var id: String { name }
    public var name: String
    public var fg: RGBColor
    public var bg: RGBColor
    public var cursor: RGBColor
    public var selection: RGBColor
    public var ansi: [RGBColor]

    public init(name: String, fg: RGBColor, bg: RGBColor, cursor: RGBColor,
                selection: RGBColor, ansi: [RGBColor]) {
        self.name = name
        self.fg = fg
        self.bg = bg
        self.cursor = cursor
        self.selection = selection
        self.ansi = ansi
    }
}
