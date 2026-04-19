# CLAUDE.md — copilot-chat-mcp project brain

This file is the persistent source of truth for this project. Read it at
the start of every task. Update it in the same commit whenever you change
something meaningful. Keep it concise and scannable.

---

## What this project is

An MCP (Model Context Protocol) server called **copilot-chat** that lets an
AI coding agent never "stop" a turn — it calls an `ask_question` tool that
blocks until the user replies. The same server also exposes:

- A **web chat UI** at http://127.0.0.1:8765 (dark theme, WebSocket-powered).
- A **Telegram bot** bridge so the user can reply from anywhere.
- A native **macOS menu-bar app** (SwiftUI + AppKit, Liquid Glass on macOS 26)
  for a first-class desktop experience with banner notifications.

Public repo: https://github.com/Levi-Smokrovic/copilot-chat-mcp (MIT).

Not affiliated with GitHub, Microsoft, or any AI provider. See DISCLAIMER.md.

## Repo layout

```
~/.local/share/copilot-chat-mcp/
├── server.py                 # single-process MCP + aiohttp web + Telegram poller
├── static/
│   └── index.html            # web chat UI
├── requirements.txt
├── .venv/                    # python venv (gitignored)
├── menubar/                  # Swift 6 / SwiftPM macOS menu-bar app
│   ├── Package.swift         # tools 6.2, .macOS(.v26)
│   ├── Info.plist            # LSUIElement=true, bundle id io.github.copilot-chat-mcp.menubar
│   ├── build.sh              # swift build -c release + package .app
│   ├── install.sh            # build → ~/Applications/CopilotChat.app → LaunchAgent
│   └── Sources/CopilotChatBar/
│       ├── App.swift         # AppKit entrypoint (NSStatusItem + NSPopover + NSWindow)
│       ├── ChatModel.swift   # WebSocket + UNUserNotificationCenter + unread badge
│       ├── ChatView.swift    # SwiftUI chat UI (messages + composer)
│       ├── RootView.swift    # tabbed chat ↔ settings with header
│       └── Settings.swift    # @AppStorage-backed preferences
├── README.md
├── LICENSE                   # MIT
├── DISCLAIMER.md
└── CLAUDE.md                 # ← this file
```

## Architecture

**One Python process** (`server.py`) runs asyncio and hosts:

1. `FastMCP` over stdio → three tools:
   - `ask_question(question)` — creates a future, broadcasts the question to
     web/menubar/Telegram, resolves when any surface replies.
   - `send_update(message)` — non-blocking progress push, returns any queued
     "btw" messages the user typed while you worked.
   - `check_messages()` — drains the inbox (non-blocking poll).
2. `aiohttp` web server at 127.0.0.1:8765 with `/ws` WebSocket for the web UI
   and for the Swift menubar app.
3. Telegram long-poller using the bot token from the user's VS Code mcp.json.
   First incoming chat auto-locks as `TG_CHAT_ID`.

All surfaces share state via dicts and a single asyncio loop. Stdout is
reserved for MCP protocol; all logging goes to stderr.

**Menu-bar app** (`menubar/`) connects to the same `/ws` endpoint:

- AppKit `NSStatusItem` hosts the icon.
- Left-click the icon → compact `NSPopover` with the chat UI.
- Banner notification click → opens a standalone `NSWindow` (floating,
  titled) because anchoring a popover to a just-activated status button
  is unreliable.
- Uses modern `UNUserNotificationCenter` (legacy `NSUserNotification` is
  finally gutted on macOS 26).
- All preferences (`Settings.swift`) stored via `@AppStorage` / UserDefaults.

## Build & install

### Python server
```bash
cd ~/.local/share/copilot-chat-mcp
python3 -m venv .venv
.venv/bin/pip install -r requirements.txt
```
Registered in the user's VS Code mcp.json (never commit the TG token).

### macOS menu-bar app
```bash
cd ~/.local/share/copilot-chat-mcp/menubar
swift build -c release --arch arm64
bash install.sh                                   # packages .app + LaunchAgent
pkill -f CopilotChatBar
/usr/bin/open /Users/levi/Applications/CopilotChat.app   # re-register with LaunchServices
```

LaunchAgent: `~/Library/LaunchAgents/io.github.copilot-chat-mcp.menubar.plist`
(RunAtLoad=true).

Kickstart after plist changes:
```bash
launchctl kickstart -k "gui/$(id -u)/io.github.copilot-chat-mcp.menubar"
```

## Known gotchas (learned the hard way)

- **NSUserNotification silently dropped on macOS 26.** Must use
  `UNUserNotificationCenter` with `requestAuthorization`. Ad-hoc signed
  LSUIElement apps can still register if launched via `/usr/bin/open`
  from a proper .app bundle.
- **Popover positioning breaks after notification click.** When the app
  activates from background, the status button's frame isn't settled;
  a popover anchored to it lands at screen top-left. Fix: open a
  standalone `NSWindow` from the notification handler instead.
- **SwiftUI `MenuBarExtra` click handling is fragile** after the app
  loses focus. We switched to plain AppKit `NSStatusItem`.
- **Sendable / main-actor conformance.** For
  `UNUserNotificationCenterDelegate` on a `@MainActor` class, mark the
  conformance `@preconcurrency` to silence crossing-isolation errors.
- **Bundle-ID caching in Notification Center.** After renaming the
  bundle id, remove the old LaunchAgent plist and `launchctl bootout`
  the old label before installing the new one.
- **Never commit the Telegram bot token.** It lives only in the VS Code
  `mcp.json`. `.env.example` must have the token value blank.
- **Port 8765 conflicts.** If an older `server.py` is running from a
  different path (e.g. the old Desktop copy), kill it:
  `pkill -f "/Users/levi/Desktop/Copilot MCP/server.py"`.
- **`tools-version: 6.0` is too old for `.macOS(.v26)`.** Use 6.2+.

## Recent changes (reverse chronological)

- URLs in chat messages are now auto-linkified via `NSDataDetector`
  + `AttributedString` so they render clickable + underlined.
- Banner clicks now open a standalone floating `NSWindow` instead of
  trying to anchor a popover to the status button. Added "Chat bubbles"
  settings section: per-role hue sliders (you / assistant / questions),
  bubble opacity, corner radius.
- Added "Appearance" settings: theme (auto/light/dark), menu-bar icon
  style (bubbles/sparkles/message), accent hue slider.
- Switched notifications to `UNUserNotificationCenter` from the
  deprecated `NSUserNotification` API (macOS 26 silently drops the old
  one).
- Rewrote the menu-bar shell from SwiftUI `MenuBarExtra` to AppKit
  `NSStatusItem` + `NSPopover` for reliable click handling.
- Added a Settings tab in the popover header (gear icon) + Quit button.
- Initial public GitHub push with MIT license, disclaimers, .env.example.

## Open TODOs

- Maybe: font / font-size setting.
- Maybe: "open at login" toggle that manages the LaunchAgent.
- Maybe: Option to mute notifications during focus / Do Not Disturb only.
- Consider moving away from ad-hoc signing so notifications work without
  the LaunchServices-reregistration dance.
