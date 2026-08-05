# Changelog

All notable changes to TermX are documented here.

## [0.9] - 2026-08-05

### English

#### Added

- System panels now follow the in-app language: the Save/Open panel action
  button and the "Save As:" field label are localized (English default,
  Simplified Chinese when switched). The Cancel button of those panels runs in
  a separate macOS XPC process and follows the launch-time language, so it is
  kept in sync via `AppleLanguages`.
- The About dialog now shows the project repository as a clickable link.

#### Changed

- Language handling unified across menus, dialogs, panels and terminal
  messages — no more mixed English/Chinese UI.

#### Testing

- 29 unit-test assertions pass (SSH prompt detection, auth arguments,
  session models, password obfuscation, and the new localization checks:
  every key complete in both languages, English default, system-language sync).

### 中文

#### 新增

- 系统面板跟随应用语言：保存/打开面板的动作按钮和“存储为”字段标签会随界面语言变化（默认英文，切换到简体中文时变为中文）。取消按钮运行在 macOS 独立的 XPC 进程中，只跟随启动时的语言，因此通过 `AppleLanguages` 保持同步。
- “关于”对话框新增项目仓库地址，可点击跳转。

#### 变更

- 菜单、对话框、面板和终端消息的语言统一，不再中英文混杂。

#### 测试

- 29 条单元测试断言全部通过（SSH 密码提示识别、认证参数、会话模型、密码混淆，以及新增的本地化检查：双语键完整性、默认英文、系统语言同步）。

## [0.8 Beta] - 2026-08-05

### English

#### Added

- Native macOS SSH / local terminal built with Swift + AppKit + SwiftTerm
  (no Electron, no X11; system OpenSSH for SSH).
- Tabbed interface: local shells and SSH sessions side by side; the same
  server can have multiple tabs; per-server tab colors.
- Drag a tab out into its own window (⇧⌘D) and merge it back (⌥⌘D).
- Server management from a single **Server** menu: new SSH session, session
  manager, edit/delete current session.
- Auto-login: passwords stored locally with simple obfuscation, filled
  automatically; the `user@host's password:` prompt is hidden.
- Port forwarding: per-session local / remote / dynamic SSH tunnels,
  standalone tunnels, and a Tunnels window to monitor and stop them.
- 10 built-in color themes (Dracula, Solarized, One Dark, Gruvbox, Nord,
  Monokai, …) and terminal background opacity 30–100%.
- Export terminal log (⌘S), right-click copies the selection, bounded
  backpressure keeps heavy output from freezing the UI.

### 中文

#### 新增

- 原生 macOS SSH / 本地终端，基于 Swift + AppKit + SwiftTerm（无 Electron、无 X11，SSH 使用系统 OpenSSH）。
- 标签页界面：本地 shell 与 SSH 会话并存；同一服务器可开多个标签页；支持按服务器配置标签颜色。
- 标签页可拖出为独立窗口（⇧⌘D），也可合并回主窗口（⌥⌘D）。
- 通过“服务器”菜单统一管理：新建 SSH 会话、会话管理器、编辑/删除当前会话。
- 自动登录：密码以简单混淆方式保存在本地并自动填充，隐藏 `user@host's password:` 提示。
- 端口转发：每个会话可配置本地/远程/动态 SSH 隧道，支持独立隧道，并有隧道窗口可监控和停止。
- 内置 10 套配色主题（Dracula、Solarized、One Dark、Gruvbox、Nord、Monokai 等），终端背景透明度 30–100%。
- 导出终端日志（⌘S）、右键复制选中文本，以及有界背压机制避免大量输出卡死界面。
