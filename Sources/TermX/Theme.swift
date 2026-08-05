import Foundation
import SwiftTerm
import TermXCore

/// Built-in terminal color schemes plus the user's default-theme preference.
final class ThemeStore {
    static let shared = ThemeStore()

    static let defaultThemeKey = "TermX.defaultTheme"
    static let fontSizeKey = "TermX.fontSize"

    let themes: [TermTheme]

    private init() {
        themes = TermTheme.builtins
    }

    var defaultThemeName: String {
        get { UserDefaults.standard.string(forKey: Self.defaultThemeKey) ?? "Dracula" }
        set { UserDefaults.standard.set(newValue, forKey: Self.defaultThemeKey) }
    }

    var defaultTheme: TermTheme {
        theme(named: defaultThemeName) ?? themes[0]
    }

    func theme(named name: String) -> TermTheme? {
        themes.first { $0.name == name }
    }

    static var fontSize: CGFloat {
        get {
            let size = UserDefaults.standard.double(forKey: fontSizeKey)
            return size > 0 ? CGFloat(size) : 13
        }
        set {
            UserDefaults.standard.set(Double(newValue), forKey: fontSizeKey)
        }
    }
}

/// Terminal background appearance: translucency.
enum TerminalAppearance {
    static let opacityKey = "TermX.bgOpacity"

    static var backgroundOpacity: CGFloat {
        get {
            let value = UserDefaults.standard.double(forKey: opacityKey)
            return value > 0 ? CGFloat(value) : 1.0
        }
        set {
            UserDefaults.standard.set(Double(newValue), forKey: opacityKey)
        }
    }

}

extension TermTheme {
    static let builtins: [TermTheme] = [
        TermTheme(name: "Dracula",
                  fg: RGBColor(hex: 0xF8F8F2), bg: RGBColor(hex: 0x282A36),
                  cursor: RGBColor(hex: 0xF8F8F2), selection: RGBColor(hex: 0x44475A),
                  ansi: [
                      RGBColor(hex: 0x21222C), RGBColor(hex: 0xFF5555), RGBColor(hex: 0x50FA7B), RGBColor(hex: 0xF1FA8C),
                      RGBColor(hex: 0xBD93F9), RGBColor(hex: 0xFF79C6), RGBColor(hex: 0x8BE9FD), RGBColor(hex: 0xF8F8F2),
                      RGBColor(hex: 0x6272A4), RGBColor(hex: 0xFF6E6E), RGBColor(hex: 0x69FF94), RGBColor(hex: 0xFFFFA5),
                      RGBColor(hex: 0xD6ACFF), RGBColor(hex: 0xFF92DF), RGBColor(hex: 0xA4FFFF), RGBColor(hex: 0xFFFFFF),
                  ]),

        TermTheme(name: "Solarized Dark",
                  fg: RGBColor(hex: 0x839496), bg: RGBColor(hex: 0x002B36),
                  cursor: RGBColor(hex: 0x839496), selection: RGBColor(hex: 0x073642),
                  ansi: [
                      RGBColor(hex: 0x073642), RGBColor(hex: 0xDC322F), RGBColor(hex: 0x859900), RGBColor(hex: 0xB58900),
                      RGBColor(hex: 0x268BD2), RGBColor(hex: 0xD33682), RGBColor(hex: 0x2AA198), RGBColor(hex: 0xEEE8D5),
                      RGBColor(hex: 0x002B36), RGBColor(hex: 0xCB4B16), RGBColor(hex: 0x586E75), RGBColor(hex: 0x657B83),
                      RGBColor(hex: 0x839496), RGBColor(hex: 0x6C71C4), RGBColor(hex: 0x93A1A1), RGBColor(hex: 0xFDF6E3),
                  ]),

        TermTheme(name: "Solarized Light",
                  fg: RGBColor(hex: 0x657B83), bg: RGBColor(hex: 0xFDF6E3),
                  cursor: RGBColor(hex: 0x657B83), selection: RGBColor(hex: 0xEEE8D5),
                  ansi: [
                      RGBColor(hex: 0x073642), RGBColor(hex: 0xDC322F), RGBColor(hex: 0x859900), RGBColor(hex: 0xB58900),
                      RGBColor(hex: 0x268BD2), RGBColor(hex: 0xD33682), RGBColor(hex: 0x2AA198), RGBColor(hex: 0xEEE8D5),
                      RGBColor(hex: 0x002B36), RGBColor(hex: 0xCB4B16), RGBColor(hex: 0x586E75), RGBColor(hex: 0x657B83),
                      RGBColor(hex: 0x839496), RGBColor(hex: 0x6C71C4), RGBColor(hex: 0x93A1A1), RGBColor(hex: 0xFDF6E3),
                  ]),

        TermTheme(name: "One Dark",
                  fg: RGBColor(hex: 0xABB2BF), bg: RGBColor(hex: 0x282C34),
                  cursor: RGBColor(hex: 0x528BFF), selection: RGBColor(hex: 0x3E4451),
                  ansi: [
                      RGBColor(hex: 0x1E2127), RGBColor(hex: 0xE06C75), RGBColor(hex: 0x98C379), RGBColor(hex: 0xD19A66),
                      RGBColor(hex: 0x61AFEF), RGBColor(hex: 0xC678DD), RGBColor(hex: 0x56B6C2), RGBColor(hex: 0xABB2BF),
                      RGBColor(hex: 0x5C6370), RGBColor(hex: 0xE06C75), RGBColor(hex: 0x98C379), RGBColor(hex: 0xD19A66),
                      RGBColor(hex: 0x61AFEF), RGBColor(hex: 0xC678DD), RGBColor(hex: 0x56B6C2), RGBColor(hex: 0xFFFFFF),
                  ]),

        TermTheme(name: "Gruvbox Dark",
                  fg: RGBColor(hex: 0xEBDBB2), bg: RGBColor(hex: 0x282828),
                  cursor: RGBColor(hex: 0xEBDBB2), selection: RGBColor(hex: 0x3C3836),
                  ansi: [
                      RGBColor(hex: 0x282828), RGBColor(hex: 0xCC241D), RGBColor(hex: 0x98971A), RGBColor(hex: 0xD79921),
                      RGBColor(hex: 0x458588), RGBColor(hex: 0xB16286), RGBColor(hex: 0x689D6A), RGBColor(hex: 0xA89984),
                      RGBColor(hex: 0x928374), RGBColor(hex: 0xFB4934), RGBColor(hex: 0xB8BB26), RGBColor(hex: 0xFABD2F),
                      RGBColor(hex: 0x83A598), RGBColor(hex: 0xD3869B), RGBColor(hex: 0x8EC07C), RGBColor(hex: 0xEBDBB2),
                  ]),

        TermTheme(name: "Nord",
                  fg: RGBColor(hex: 0xD8DEE9), bg: RGBColor(hex: 0x2E3440),
                  cursor: RGBColor(hex: 0xD8DEE9), selection: RGBColor(hex: 0x434C5E),
                  ansi: [
                      RGBColor(hex: 0x3B4252), RGBColor(hex: 0xBF616A), RGBColor(hex: 0xA3BE8C), RGBColor(hex: 0xEBCB8B),
                      RGBColor(hex: 0x81A1C1), RGBColor(hex: 0xB48EAD), RGBColor(hex: 0x88C0D0), RGBColor(hex: 0xE5E9F0),
                      RGBColor(hex: 0x4C566A), RGBColor(hex: 0xBF616A), RGBColor(hex: 0xA3BE8C), RGBColor(hex: 0xEBCB8B),
                      RGBColor(hex: 0x81A1C1), RGBColor(hex: 0xB48EAD), RGBColor(hex: 0x8FBCBB), RGBColor(hex: 0xECEFF4),
                  ]),

        TermTheme(name: "Tomorrow Night",
                  fg: RGBColor(hex: 0xC5C8C6), bg: RGBColor(hex: 0x1D1F21),
                  cursor: RGBColor(hex: 0xC5C8C6), selection: RGBColor(hex: 0x373B41),
                  ansi: [
                      RGBColor(hex: 0x1D1F21), RGBColor(hex: 0xCC6666), RGBColor(hex: 0xB5BD68), RGBColor(hex: 0xF0C674),
                      RGBColor(hex: 0x81A2BE), RGBColor(hex: 0xB294BB), RGBColor(hex: 0x8ABEB7), RGBColor(hex: 0xFFFFFF),
                      RGBColor(hex: 0x666666), RGBColor(hex: 0xCC6666), RGBColor(hex: 0xB5BD68), RGBColor(hex: 0xF0C674),
                      RGBColor(hex: 0x81A2BE), RGBColor(hex: 0xB294BB), RGBColor(hex: 0x8ABEB7), RGBColor(hex: 0xFFFFFF),
                  ]),

        TermTheme(name: "Monokai",
                  fg: RGBColor(hex: 0xF8F8F2), bg: RGBColor(hex: 0x272822),
                  cursor: RGBColor(hex: 0xF8F8F2), selection: RGBColor(hex: 0x49483E),
                  ansi: [
                      RGBColor(hex: 0x272822), RGBColor(hex: 0xF92672), RGBColor(hex: 0xA6E22E), RGBColor(hex: 0xF4BF75),
                      RGBColor(hex: 0x66D9EF), RGBColor(hex: 0xAE81FF), RGBColor(hex: 0xA1EFE4), RGBColor(hex: 0xF8F8F2),
                      RGBColor(hex: 0x75715E), RGBColor(hex: 0xF92672), RGBColor(hex: 0xA6E22E), RGBColor(hex: 0xF4BF75),
                      RGBColor(hex: 0x66D9EF), RGBColor(hex: 0xAE81FF), RGBColor(hex: 0xA1EFE4), RGBColor(hex: 0xF9F8F5),
                  ]),

        TermTheme(name: "Tango Dark",
                  fg: RGBColor(hex: 0xFFFFFF), bg: RGBColor(hex: 0x000000),
                  cursor: RGBColor(hex: 0xFFFFFF), selection: RGBColor(hex: 0x4A4A4A),
                  ansi: [
                      RGBColor(hex: 0x000000), RGBColor(hex: 0xCC0000), RGBColor(hex: 0x4E9A06), RGBColor(hex: 0xC4A000),
                      RGBColor(hex: 0x3465A4), RGBColor(hex: 0x75507B), RGBColor(hex: 0x06989A), RGBColor(hex: 0xD3D7CF),
                      RGBColor(hex: 0x555753), RGBColor(hex: 0xEF2929), RGBColor(hex: 0x8AE234), RGBColor(hex: 0xFCE94F),
                      RGBColor(hex: 0x729FCF), RGBColor(hex: 0xAD7FA8), RGBColor(hex: 0x34E2E2), RGBColor(hex: 0xEEEEEC),
                  ]),

        TermTheme(name: "Basic Light",
                  fg: RGBColor(hex: 0x000000), bg: RGBColor(hex: 0xFFFFFF),
                  cursor: RGBColor(hex: 0x000000), selection: RGBColor(hex: 0xB5D5FF),
                  ansi: [
                      RGBColor(hex: 0x000000), RGBColor(hex: 0xBB0000), RGBColor(hex: 0x00BB00), RGBColor(hex: 0xBBBB00),
                      RGBColor(hex: 0x0000BB), RGBColor(hex: 0xBB00BB), RGBColor(hex: 0x00BBBB), RGBColor(hex: 0xBBBBBB),
                      RGBColor(hex: 0x555555), RGBColor(hex: 0xFF5555), RGBColor(hex: 0x55FF55), RGBColor(hex: 0xFFFF55),
                      RGBColor(hex: 0x5555FF), RGBColor(hex: 0xFF55FF), RGBColor(hex: 0x55FFFF), RGBColor(hex: 0xFFFFFF),
                  ]),
    ]
}
