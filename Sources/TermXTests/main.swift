import Foundation
import TermXCore

// ── Minimal test harness (runs without XCTest, since some macOS installs
//    lack the XCTest runtime frameworks). ──

private var passed = 0
private var failed = 0
private var failures: [String] = []

private func check(_ condition: @autoclosure () -> Bool, _ name: String) {
    if condition() {
        passed += 1
    } else {
        failed += 1
        failures.append(name)
    }
}

private func checkEqual<T: Equatable>(_ actual: T, _ expected: T, _ name: String) {
    if actual == expected {
        passed += 1
    } else {
        failed += 1
        failures.append("\(name): expected \(expected), got \(actual)")
    }
}

private func checkNil<T>(_ value: T?, _ name: String) {
    if value == nil {
        passed += 1
    } else {
        failed += 1
        failures.append("\(name): expected nil")
    }
}

private func checkNotNil<T>(_ value: T?, _ name: String) {
    if value != nil {
        passed += 1
    } else {
        failed += 1
        failures.append("\(name): expected non-nil")
    }
}

// ── SSHAuth ──

func testPromptMatcherDetectsPromptInOneChunk() {
    var matcher = SSHAuth.PromptMatcher()
    checkNotNil(matcher.scan(Data("ash@host's password: ".utf8)), "prompt in one chunk")
    check(matcher.isMatched, "isMatched after match")
}

func testPromptMatcherDetectsPromptAcrossChunks() {
    var matcher = SSHAuth.PromptMatcher()
    checkNil(matcher.scan(Data("ash@host's pass".utf8)), "no match in partial chunk")
    let range = matcher.scan(Data("word: ".utf8))
    checkEqual(range?.lowerBound, 11, "match lower bound")
    checkEqual(range?.upperBound, 20, "match upper bound")
}

func testPromptMatcherIgnoresBannerText() {
    var matcher = SSHAuth.PromptMatcher()
    checkNil(matcher.scan(Data("Welcome to Ubuntu 22.04 LTS\r\n".utf8)), "no false positive on banner")
    check(!matcher.isMatched, "not matched on banner")
}

func testPromptMatcherMatchesOnlyOnce() {
    var matcher = SSHAuth.PromptMatcher()
    checkNotNil(matcher.scan(Data("password: ".utf8)), "first match")
    checkNil(matcher.scan(Data("password: ".utf8)), "second scan ignored")
}

func testPromptMatcherMatchesPassphrase() {
    var matcher = SSHAuth.PromptMatcher()
    checkNotNil(matcher.scan(Data("Enter passphrase for key '/tmp/key': ".utf8)), "passphrase prompt")
}

func testAuthArgumentsPassword() {
    let args = SSHAuth.authArguments(authMethod: .password, keyPath: nil)
    check(args.contains("PubkeyAuthentication=no"), "password disables pubkey")
    check(args.contains("PreferredAuthentications=password,keyboard-interactive"), "password prefer auths")
}

func testAuthArgumentsKey() {
    let args = SSHAuth.authArguments(authMethod: .key, keyPath: "/tmp/id_ed25519")
    checkEqual(args, ["-i", "/tmp/id_ed25519", "-o", "IdentitiesOnly=yes"], "key args")
}

func testAuthArgumentsKeyWithoutPath() {
    checkEqual(SSHAuth.authArguments(authMethod: .key, keyPath: nil), [], "key without path")
}

// ── Models ──

func testPortForwardDisplayName() {
    let local = PortForward(kind: .local, bindPort: 8080, remoteHost: "10.0.0.1", remotePort: 80)
    checkEqual(local.displayName, "L 8080 → 10.0.0.1:80", "local display name")

    let remote = PortForward(kind: .remote, bindPort: 3306, remoteHost: "db.internal", remotePort: 3306)
    checkEqual(remote.displayName, "R 3306 → db.internal:3306", "remote display name")

    let dynamic = PortForward(kind: .dynamic, bindPort: 1080, remoteHost: "", remotePort: 0)
    checkEqual(dynamic.displayName, "D 1080", "dynamic display name")
}

func testSessionPortForwardsDefaultEmpty() {
    let session = Session.newLocal(name: "local")
    checkEqual(session.portForwards, [], "portForwards default empty")
    checkNil(session.forwards, "forwards nil by default")
}

func testSessionKindDisplayHost() {
    L.current = .english
    let ssh = Session.newSSH(name: "web", host: "example.com", port: 22, username: "root")
    checkEqual(ssh.displayHost, "root@example.com:22", "ssh display host")
    checkEqual(Session.newLocal(name: "local").displayHost, "Local shell", "local display host")
}

// ── SessionStore obfuscation ──

func testObfuscationRoundTrip() {
    let plain = "s3cr3t-passw0rd!"
    let obfuscated = SessionStore.obfuscate(plain)
    check(obfuscated != plain, "obfuscated differs from plaintext")
    checkEqual(SessionStore.deobfuscate(obfuscated), plain, "round trip")
}

func testObfuscationIsDeterministic() {
    checkEqual(SessionStore.obfuscate("abc"), SessionStore.obfuscate("abc"), "deterministic")
}

func testDeobfuscateInvalidBase64ReturnsNil() {
    checkNil(SessionStore.deobfuscate("not-valid-base64!!!"), "invalid base64 -> nil")
}

// ── Localization ──

func testLocalizationTableComplete() {
    let incomplete = L.missingTranslations()
    check(incomplete.isEmpty, "every key has en + zh (missing: \(incomplete))")
}

func testLanguageDefaultsToEnglish() {
    UserDefaults.standard.removeObject(forKey: L.languageKey)
    checkEqual(L.current, .english, "default language is English")
}

func testLanguageSwitchSyncsSystemLanguage() {
    let oldLanguage = UserDefaults.standard.string(forKey: L.languageKey)
    let oldAppleLanguages = UserDefaults.standard.array(forKey: L.systemLanguageKey)

    L.current = .simplifiedChinese
    checkEqual(UserDefaults.standard.string(forKey: L.languageKey), "zh-Hans", "language preference persisted")
    checkEqual(UserDefaults.standard.array(forKey: L.systemLanguageKey) as? [String],
               ["zh-Hans"], "AppleLanguages kept in sync")

    if let oldLanguage {
        UserDefaults.standard.set(oldLanguage, forKey: L.languageKey)
    } else {
        UserDefaults.standard.removeObject(forKey: L.languageKey)
    }
    if let oldAppleLanguages {
        UserDefaults.standard.set(oldAppleLanguages, forKey: L.systemLanguageKey)
    } else {
        UserDefaults.standard.removeObject(forKey: L.systemLanguageKey)
    }
}

// ── Runner ──

let tests: [(String, () -> Void)] = [
    ("SSHAuth.prompt one chunk", testPromptMatcherDetectsPromptInOneChunk),
    ("SSHAuth.prompt across chunks", testPromptMatcherDetectsPromptAcrossChunks),
    ("SSHAuth.prompt ignores banner", testPromptMatcherIgnoresBannerText),
    ("SSHAuth.prompt matches once", testPromptMatcherMatchesOnlyOnce),
    ("SSHAuth.prompt passphrase", testPromptMatcherMatchesPassphrase),
    ("SSHAuth.args password", testAuthArgumentsPassword),
    ("SSHAuth.args key", testAuthArgumentsKey),
    ("SSHAuth.args key no path", testAuthArgumentsKeyWithoutPath),
    ("Models.port forward display name", testPortForwardDisplayName),
    ("Models.session forwards default", testSessionPortForwardsDefaultEmpty),
    ("Models.session display host", testSessionKindDisplayHost),
    ("SessionStore.obfuscation round trip", testObfuscationRoundTrip),
    ("SessionStore.obfuscation deterministic", testObfuscationIsDeterministic),
    ("SessionStore.deobfuscate invalid", testDeobfuscateInvalidBase64ReturnsNil),
    ("L.table complete en+zh", testLocalizationTableComplete),
    ("L.default English", testLanguageDefaultsToEnglish),
    ("L.switch syncs system", testLanguageSwitchSyncsSystemLanguage),
]

for (_, test) in tests {
    test()
}

print("TermXTests: \(passed) passed, \(failed) failed")
for failure in failures {
    print("FAIL: \(failure)")
}
exit(failed == 0 ? 0 : 1)
