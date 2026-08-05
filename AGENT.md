# AGENT.md

Working guide for **TermX** — a native macOS SSH / local terminal app
(Swift + AppKit + SwiftTerm). This file distills the architecture and the
hard-won constraints so future work doesn't re-trigger old bugs.

## Project layout

```text
Package.swift                 SwiftPM manifest
Sources/CPTY/                 C bridge: forkpty / pty_spawn / winsize
Sources/TermXCore/            Testable core (public API): Models, SSHAuth,
                              Localization (L), SessionStore, KeychainHelper
Sources/TermX/                The app: windows, terminals, tunnels, menus, editors
Sources/TermXTests/           Unit tests (lightweight runner, no XCTest)
Scripts/build_app.sh          Release build → .app bundle → ad-hoc sign
Resources/                    Info.plist, AppIcon.icns
dist/                         Built app output (gitignored)
```

## Build & test

- Build the app: `./Scripts/build_app.sh` → `dist/TermX.app`
- Run unit tests: `swift run TermXTests`
- Standard `swift test`/XCTest does **not** work on this machine (the macOS
  Xcode install is missing the XCTest runtime frameworks, e.g. XCTestCore).
  Keep tests in the lightweight runner; the tested logic lives in `TermXCore`.
- Release binaries are **Apple Silicon (arm64) only**: build with
  `swift build -c release --arch arm64`. (Multi-arch `--arch arm64 --arch x86_64`
  fails here because SwiftPM needs the broken `xcbuild`.)

## Architecture constraints (learned the hard way — don't "improve" these)

- **PTY backpressure**: `PTYProcess` gates the reader with an `NSCondition` +
  an `inFlightChunks` counter (max 2). Do **not** switch to
  `DispatchSemaphore` — GCD traps when a semaphore is deallocated while a
  thread is waiting on it (this crashed the app).
- **Main-thread parsing**: feed terminal output through the SwiftTerm view on
  the main thread (SwiftTerm's view callbacks mutate the view hierarchy, e.g.
  cursor hide). The reader paces itself instead of flooding the main queue.
- **Feed via the view wrapper**: always call `terminalView.feed(...)`, never
  `terminal.feed` directly — `feedFinish()` schedules the display pass that
  moves the caret (bypassing it left the cursor stuck).
- **Auto-login**: shared `SSHAuth.PromptMatcher` detects password/passphrase
  prompts across chunks. The terminal strips the prompt from the display and
  absorbs the following newline; tunnels just inject the password.
- **Termination**: SIGHUP first, SIGKILL after 1.5s if still alive — an
  authenticated `ssh -N` can survive SIGHUP.
- **Window close**: closing the main window closes *all* windows and quits
  (last-window-closed policy). Closing the last tab closes the main window.
- **Tab detach/dock**: when dragging a tab out, remove it from the strip first
  (the old path left a ghost tab). Dock-back is **release-based**: dragging a
  detached window over the tab strip highlights it, but merging only happens
  when the mouse is released there — never while just passing over.
- **Session storage**: JSON at
  `~/Library/Application Support/TermX/sessions.json`; passwords are obfuscated
  (XOR+base64, not encryption); a `.bak` backup is rotated before each save.
  Keychain is used only for one-time migration from older builds.

## Localization

- All user-facing strings go through `L.t("key")`
  (`Sources/TermXCore/Localization.swift`), English default + Simplified Chinese.
- Menus are rebuilt when the language changes — keep every title localized.
- New keys must be added to the `L.table` dictionary in **both** languages.

## Conventions

- Every file has a doc comment explaining its role; tricky concurrency/signaling
  code requires comments (they encode the debugging history).
- Testable logic stays in `TermXCore` with `public` API (shared by app + tests).
- App icon: `image.png` is the source; `Resources/AppIcon.icns` is generated
  (iconutil) and **must remain committed** — the build script copies it.
- Never commit real user data (server names, IPs, passwords, machine names);
  README screenshots use fictional data.

## Release process

1. Bump the version: `Resources/Info.plist` (`CFBundleShortVersionString`) and
   the About text in `Localization.swift`.
2. Build arm64, assemble with `build_app.sh`, zip:
   `ditto -c -k --sequesterRsrc --keepParent dist/TermX.app dist/TermX-<ver>-macOS-arm64.zip`
3. Publish: `gh release create <tag> <zip> --notes "…"` — **release notes in English**.

The build is ad-hoc signed and **not notarized** — recipients may need to
right-click → Open once. Developer ID signing + notarization requires a paid
Apple Developer account (not configured).
