import Foundation

/// Supported UI languages.
public enum Language: String, CaseIterable {
    case english = "en"
    case simplifiedChinese = "zh-Hans"

    public var displayName: String {
        switch self {
        case .english: return "English"
        case .simplifiedChinese: return "简体中文"
        }
    }
}

/// Minimal in-app localization. Default is English; Simplified Chinese is
/// available and can be switched from the app menu.
public enum L {
    public static let languageKey = "TermX.language"

    public static var current: Language {
        get {
            let raw = UserDefaults.standard.string(forKey: languageKey)
            return Language(rawValue: raw ?? Language.english.rawValue) ?? .english
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: languageKey)
        }
    }

    public static func t(_ key: String) -> String {
        table[key]?[current] ?? key
    }

    private static let table: [String: [Language: String]] = [
        // App menu
        "about": [.english: "About TermX", .simplifiedChinese: "关于 TermX"],
        "language": [.english: "Language", .simplifiedChinese: "语言"],
        "hide": [.english: "Hide TermX", .simplifiedChinese: "隐藏 TermX"],
        "quit": [.english: "Quit TermX", .simplifiedChinese: "退出 TermX"],

        // File menu
        "file": [.english: "File", .simplifiedChinese: "文件"],
        "newLocal": [.english: "New Local Terminal", .simplifiedChinese: "新建本地终端"],
        "exportLog": [.english: "Export Terminal Log…", .simplifiedChinese: "导出终端日志…"],
        "closeTab": [.english: "Close Tab", .simplifiedChinese: "关闭标签页"],
        "detachTab": [.english: "Move Current Tab to Separate Window", .simplifiedChinese: "将当前标签页移到独立窗口"],
        "dockTab": [.english: "Move Back to Main Window", .simplifiedChinese: "移回主窗口"],

        // Server menu
        "server": [.english: "Server", .simplifiedChinese: "服务器"],
        "newSSH": [.english: "New SSH Session…", .simplifiedChinese: "新建 SSH 会话…"],
        "sessionManager": [.english: "Session Manager…", .simplifiedChinese: "会话管理器…"],
        "editCurrent": [.english: "Edit Current Session…", .simplifiedChinese: "编辑当前会话…"],
        "deleteCurrent": [.english: "Delete Current Session…", .simplifiedChinese: "删除当前会话…"],

        // Edit menu
        "edit": [.english: "Edit", .simplifiedChinese: "编辑"],
        "copy": [.english: "Copy", .simplifiedChinese: "复制"],
        "paste": [.english: "Paste", .simplifiedChinese: "粘贴"],
        "selectAll": [.english: "Select All", .simplifiedChinese: "全选"],
        "find": [.english: "Find…", .simplifiedChinese: "查找…"],

        // View menu
        "view": [.english: "View", .simplifiedChinese: "显示"],
        "themes": [.english: "Themes", .simplifiedChinese: "主题"],
        "background": [.english: "Terminal Background", .simplifiedChinese: "终端背景"],
        "opacity": [.english: "Opacity", .simplifiedChinese: "透明度"],
        "opacity100": [.english: "100% (Opaque)", .simplifiedChinese: "100%（不透明）"],
        "opacity85": [.english: "85%", .simplifiedChinese: "85%"],
        "opacity70": [.english: "70%", .simplifiedChinese: "70%"],
        "opacity50": [.english: "50%", .simplifiedChinese: "50%"],
        "opacity30": [.english: "30%", .simplifiedChinese: "30%"],
        "fontIncrease": [.english: "Increase Font Size", .simplifiedChinese: "增大字号"],
        "fontDecrease": [.english: "Decrease Font Size", .simplifiedChinese: "减小字号"],
        "fontReset": [.english: "Reset Font Size", .simplifiedChinese: "恢复默认字号"],

        // Window menu
        "window": [.english: "Window", .simplifiedChinese: "窗口"],
        "minimize": [.english: "Minimize", .simplifiedChinese: "最小化"],
        "zoom": [.english: "Zoom", .simplifiedChinese: "缩放"],
        "bringAllToFront": [.english: "Bring All to Front", .simplifiedChinese: "前置全部窗口"],

        // Tab strip
        "closeTabTip": [.english: "Close tab", .simplifiedChinese: "关闭标签页"],
        "plusTip": [.english: "Choose a saved server or create a session", .simplifiedChinese: "选择已存服务器或新建会话"],

        // Empty states
        "emptyTabs": [.english: "Press ⌘T for a local terminal\nor click ＋ to pick a saved server",
                      .simplifiedChinese: "按 ⌘T 新建本地终端\n或点击标签栏 ＋ 选择已存服务器"],
        "emptySessions": [.english: "No servers yet\nPress ⌘N to create an SSH session",
                          .simplifiedChinese: "还没有服务器\n⌘N 新建 SSH 会话"],

        // Session list
        "servers": [.english: "Servers", .simplifiedChinese: "服务器"],
        "addSSH": [.english: "+ SSH", .simplifiedChinese: "+ SSH"],
        "delete": [.english: "Delete", .simplifiedChinese: "删除"],
        "connect": [.english: "Connect", .simplifiedChinese: "连接"],
        "editEllipsis": [.english: "Edit…", .simplifiedChinese: "编辑…"],
        "deleteEllipsis": [.english: "Delete…", .simplifiedChinese: "删除…"],

        // Session editor
        "newSSHTitle": [.english: "New SSH Session", .simplifiedChinese: "新建 SSH 会话"],
        "editTitle": [.english: "Edit Session", .simplifiedChinese: "编辑会话"],
        "alias": [.english: "Alias (Display Name)", .simplifiedChinese: "别名（显示名）"],
        "type": [.english: "Type", .simplifiedChinese: "类型"],
        "sshType": [.english: "SSH", .simplifiedChinese: "SSH"],
        "localType": [.english: "Local", .simplifiedChinese: "本地"],
        "host": [.english: "Host", .simplifiedChinese: "主机"],
        "port": [.english: "Port", .simplifiedChinese: "端口"],
        "username": [.english: "Username", .simplifiedChinese: "用户名"],
        "auth": [.english: "Authentication", .simplifiedChinese: "认证方式"],
        "authPassword": [.english: "Password", .simplifiedChinese: "密码"],
        "authKey": [.english: "Key File", .simplifiedChinese: "密钥文件"],
        "password": [.english: "Password", .simplifiedChinese: "密码"],
        "keyFile": [.english: "Key File", .simplifiedChinese: "密钥文件"],
        "savePassword": [.english: "Save password", .simplifiedChinese: "保存密码"],
        "customTabColor": [.english: "Custom tab color", .simplifiedChinese: "自定义标签颜色"],
        "tabColor": [.english: "Tab Color", .simplifiedChinese: "标签颜色"],
        "placeholderHost": [.english: "e.g. 192.168.1.10 or myserver.com",
                            .simplifiedChinese: "例如 192.168.1.10 或 myserver.com"],
        "placeholderAlias": [.english: "Leave empty to use user@host",
                             .simplifiedChinese: "留空则自动使用 user@host"],
        "placeholderKey": [.english: "~/.ssh/id_ed25519", .simplifiedChinese: "~/.ssh/id_ed25519"],
        "placeholderPassword": [.english: "Login password", .simplifiedChinese: "登录密码"],
        "cancel": [.english: "Cancel", .simplifiedChinese: "取消"],
        "save": [.english: "Save", .simplifiedChinese: "保存"],
        "browse": [.english: "Choose…", .simplifiedChinese: "选择…"],
        "chooseKey": [.english: "Choose SSH private key file", .simplifiedChinese: "选择 SSH 私钥文件"],
        "incomplete": [.english: "Incomplete Information", .simplifiedChinese: "信息不完整"],
        "incompleteMsg": [.english: "SSH sessions require a host and username.",
                          .simplifiedChinese: "SSH 会话需要填写主机和用户名。"],
        "ok": [.english: "OK", .simplifiedChinese: "好"],

        // Alerts / dialogs
        "deleteTitle": [.english: "Delete Session", .simplifiedChinese: "删除会话"],
        "deleteConfirm": [.english: "Delete “%@”?", .simplifiedChinese: "确定要删除“%@”吗？"],
        "exportTitle": [.english: "Export Terminal Log", .simplifiedChinese: "导出终端日志"],
        "exportMsg": [.english: "Save the full terminal scrollback (including history) as a log file",
                      .simplifiedChinese: "保存当前终端完整滚动内容（含历史）为日志文件"],
        "exportFail": [.english: "Export Failed", .simplifiedChinese: "导出失败"],

        // Terminal messages
        "sessionEnded": [.english: "\r\n[Session ended — close this tab to release.]\r\n",
                         .simplifiedChinese: "\r\n[会话已结束，关闭此标签页可释放。]\r\n"],
        "spawnFailed": [.english: "\r\n[Failed to start session: %@]\r\n",
                        .simplifiedChinese: "\r\n[无法启动会话: %@]\r\n"],

        // Misc
        "localShell": [.english: "Local shell", .simplifiedChinese: "本地 shell"],
        "localSession": [.english: "Local", .simplifiedChinese: "本地"],
        "endedSuffix": [.english: " (ended)", .simplifiedChinese: " (已结束)"],
        "aboutText": [.english: "Native SSH / local terminal for macOS\nVersion 0.8 Beta\nSwift + SwiftTerm",
                      .simplifiedChinese: "macOS 原生 SSH / 本地终端\n版本 0.8 Beta\nSwift + SwiftTerm"],

        // Port forwarding
        "tunnels": [.english: "Tunnels", .simplifiedChinese: "隧道"],
        "newTunnel": [.english: "New Tunnel…", .simplifiedChinese: "新建隧道…"],
        "stop": [.english: "Stop", .simplifiedChinese: "停止"],
        "stopAll": [.english: "Stop All", .simplifiedChinese: "全部停止"],
        "portForwarding": [.english: "Port Forwarding", .simplifiedChinese: "端口转发"],
        "editForwards": [.english: "Edit…", .simplifiedChinese: "编辑…"],
        "dirLocal": [.english: "Local", .simplifiedChinese: "本地"],
        "dirRemote": [.english: "Remote", .simplifiedChinese: "远程"],
        "dirDynamic": [.english: "Dynamic", .simplifiedChinese: "动态"],
        "direction": [.english: "Direction", .simplifiedChinese: "方向"],
        "targetHost": [.english: "Target Host", .simplifiedChinese: "目标主机"],
        "targetPort": [.english: "Target Port", .simplifiedChinese: "目标端口"],
        "add": [.english: "Add", .simplifiedChinese: "添加"],
        "done": [.english: "Done", .simplifiedChinese: "完成"],
        "chooseServer": [.english: "Server", .simplifiedChinese: "服务器"],
        "start": [.english: "Start", .simplifiedChinese: "开始"],
        "starting": [.english: "Starting", .simplifiedChinese: "启动中"],
        "running": [.english: "Running", .simplifiedChinese: "运行中"],
        "stopped": [.english: "Stopped", .simplifiedChinese: "已停止"],
        "failed": [.english: "Failed", .simplifiedChinese: "失败"],
        "noForwards": [.english: "Add at least one forwarding rule.",
                       .simplifiedChinese: "请至少添加一条转发规则。"],
        "noTunnels": [.english: "No active tunnels — click New Tunnel… to create one.",
                      .simplifiedChinese: "暂无活动隧道——点击「新建隧道」创建一条。"],
        "noServersForTunnel": [.english: "No saved SSH servers yet — add one first (Server → New SSH Session…).",
                               .simplifiedChinese: "还没有已保存的 SSH 服务器——请先添加（Server → 新建 SSH 会话…）。"],
    ]
}
