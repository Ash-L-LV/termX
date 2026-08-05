import Foundation

/// Shared OpenSSH helpers used by both terminal sessions and port-forwarding
/// tunnels: authentication option arguments and password-prompt detection.
public enum SSHAuth {
    /// `ssh` arguments for the given authentication method.
    public static func authArguments(authMethod: Session.AuthMethod, keyPath: String?) -> [String] {
        switch authMethod {
        case .password:
            return [
                "-o", "PubkeyAuthentication=no",
                "-o", "PreferredAuthentications=password,keyboard-interactive",
            ]
        case .key:
            if let keyPath, !keyPath.isEmpty {
                return ["-i", keyPath, "-o", "IdentitiesOnly=yes"]
            }
            return []
        }
    }

    /// Accumulates output and detects the `password:` / `passphrase:` prompt,
    /// reporting the match's byte range in the accumulated buffer. Only the
    /// first match is reported (subsequent calls return nil).
    public struct PromptMatcher {
        public private(set) var buffer = Data()
        public private(set) var matchedRange: Range<Data.Index>?

        public var isMatched: Bool { matchedRange != nil }

        public init() {}

        public mutating func scan(_ data: Data) -> Range<Data.Index>? {
            guard matchedRange == nil else { return nil }
            buffer.append(data)
            if buffer.count > 16_384 {
                buffer.removeFirst(buffer.count - 16_384)
            }
            guard let text = String(data: buffer, encoding: .utf8),
                  let range = text.range(of: "(?i)\\b(password|passphrase)\\s*(for\\s+[^:]+)?\\s*:",
                                         options: .regularExpression) else { return nil }
            let utf8 = text.utf8
            let start = utf8.distance(from: utf8.startIndex,
                                      to: range.lowerBound.samePosition(in: utf8)!)
            let end = utf8.distance(from: utf8.startIndex,
                                    to: range.upperBound.samePosition(in: utf8)!)
            matchedRange = start..<end
            return matchedRange
        }
    }
}
