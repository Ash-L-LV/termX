# AGENT.md

Working guide for **TermX** — a native macOS SSH / local terminal
(Swift + AppKit + SwiftTerm). Its job: get a fresh agent up to speed on the
architecture, the layout, and the pitfalls that were only learned by
debugging them — so they don't get re-learned the hard way.

## 1. Overview

- macOS 13+, **Apple Silicon (arm64)** for release builds.
- Current version: **0.9**.
- No Electron, no X11; SSH via the system OpenSSH (`/usr/bin/ssh`); terminal
  emulation via [SwiftTerm](https://github.com/migueldeicaza/SwiftTerm).
- Repo: `github.com/Ash-L-LV/termX` (main branch, tag `v0.9`).

## 2. Build / test / run

```bash
./Scripts/build_app.sh     # release build → dist/TermX.app (ad-hoc signed)
swift run TermXTests       # unit tests (lightweight runner, 25 assertions)
swift build -c release --arch arm64   # Apple Silicon only
```

Notes:
- `swift test` / XCTest does **not** run on this machine — the macOS Xcode
  install is missing the XCTest runtime frameworks (XCTestCore is absent).
  Tests therefore live in a lightweight runner (`Sources/TermXTests`).
- Multi-arch builds (`--arch arm64 --arch x86_64`) fail here because SwiftPM
  needs the broken `xcbuild`. Releases are arm64-only.
- App data: `~/Library/Application Support/TermX/sessions.json` (+ `.bak`).

## 3. Architecture

### Targets

| Target | Kind | Role |
| --- | --- | --- |
| `CPTY` | C | `forkpty` / `pty_spawn` / `winsize` bridge |
| `TermXCore` | library (public API) | Models, SSHAuth, Localization, SessionStore, KeychainHelper — all testable logic |
| `TermX` | executable | the app |
| `TermXTests` | executable | test runner |

### Code map (`Sources/TermX`)

| File | Role |
| --- | --- |
| `main.swift` / `AppDelegate.swift` | Entry, menu, lifecycle, menu actions |
| `TerminalManager.swift` | Central coordinator: windows, tabs, sessions, tunnels, popover |
| `MainWindowController.swift` | Main window; closing it closes **all** windows |
| `TerminalTabViewController.swift` / `TabBarView.swift` | Tab strip, tab lifecycle, drop-target highlight |
| `TerminalViewController.swift` | One terminal tab: SwiftTerm view + PTY + auth prompt strip + theme/opacity |
| `PTYProcess.swift` | PTY child, bounded-backpressure reader, termination |
| `DetachedWindowController.swift` | Dragged-out window + drag-to-dock tracking |
| `TunnelProcess.swift` | Background `ssh -N` tunnel with auth injection |
| `TunnelsWindowController.swift` | Tunnels window + "New Tunnel" sheet |
| `SessionEditorViewController.swift` | Session edit sheet (auth, colors, forwards) |
| `PortForwardEditorViewController.swift` | Forwarding-rule editor (standalone window) |
| `SessionManagerWindowController.swift` / `SessionListViewController.swift` | Session manager window / reusable server list |
| `MenuBuilder.swift` | Programmatic localized menu |
| `Theme.swift` | Theme store + built-in schemes |
| `TermXTerminalView.swift` | Right-click copies selection |

## 4. UI & layout notes

- Setting `window.contentViewController` resizes the window to the VC view's
  initial frame — always follow with `window.setContentSize(...)`.
- A single-column `NSTableView` does not stretch automatically: call
  `tableView.sizeLastColumnToFit()` from `viewDidLayout` (or a layout hook).
- **Do not override `hitTest` on tab items** — an old override claimed clicks
  outside its bounds and broke tab switching (and the ＋ button).
- Tab items must be **added as subviews** — storing them in an array alone
  leaves them invisible.
- Avoid sheet-on-sheet: presenting a sheet from inside a sheet is unreliable.
  Use standalone windows instead (e.g. the port-forwarding editor).
- Main window title follows the active tab's alias.

## 5. Known pitfalls & technical points

| Symptom | Root cause | Rule |
| --- | --- | --- |
| App crashes when releasing a tab/pty | `DispatchSemaphore` deallocated while a thread waits | Gate the reader with `NSCondition` |
| Cursor stuck at top-left | feeding `terminal.feed` directly skips `feedFinish()` | Always feed via `terminalView.feed(...)` |
| tmux crashes | SwiftTerm view callbacks mutate views off-main | Parse on the main thread; reader paces itself |
| `ssh -N` survives stop | authenticated ssh swallows SIGHUP | SIGHUP, then SIGKILL after 1.5 s |
| Ghost tab left in main window | tab not removed from the strip before detaching | `detach(vc)` first, then open the window |
| Drag over tab strip merges instantly | dock decided on every `windowDidMove` | Merge only on mouse release (`pressedMouseButtons`); highlight while hovering |
| Tunnel state stuck "Running" | reader blocked after 2 chunks (no slot release) | Call `pty.processedChunk()` after each chunk |
| Table text clipped | fixed column width | `sizeLastColumnToFit` + autoresizing |
| Window opens at the wrong size | `contentViewController` resizes the window | `setContentSize` after assignment |
| Old `sessions.json` fails to decode | new non-optional Codable field | Keep new fields optional (`forwards: [PortForward]?`) |
| Dock icon won't refresh | icon cache | `killall iconservicesagent`, restart Dock / logout |

## 6. Localization

- Every user-facing string goes through `L.t("key")`
  (`Sources/TermXCore/Localization.swift`); default English, plus 简体中文.
- Menus are rebuilt when the language changes — keep all titles localized.
- New keys must be added in **both** languages to `L.table`.
- System panels (Save/Open) can only have their action button retitled at
  runtime via `panel.prompt` (+ `nameFieldLabel`); the Cancel button lives in
  a separate XPC process and can't be retitled — it follows the launch-time
  `AppleLanguages` we keep in sync with the in-app language.

## 7. Data & privacy

- Passwords are obfuscated (XOR + base64, not encryption) inside
  `sessions.json`; a `.bak` backup is rotated before each save.
- Keychain is used only for one-time migration from older builds.
- **Never commit real user data** (server names, IPs, passwords, machine
  names); README screenshots use fictional data.

## 8. Release process

1. Bump version: `Resources/Info.plist` (`CFBundleShortVersionString`) and the
   About text in `Localization.swift`.
2. Build arm64 → assemble with `build_app.sh` → zip:
   `ditto -c -k --sequesterRsrc --keepParent dist/TermX.app dist/TermX-<ver>-macOS-arm64.zip`
3. `gh release create <tag> <zip> --notes "…"` — **notes in English**.

The build is ad-hoc signed and **not notarized** — recipients may need
right-click → Open once. Developer ID + notarization would require a paid
Apple Developer account (not configured).
