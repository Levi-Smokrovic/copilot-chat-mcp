#!/usr/bin/env bash
# Installs the menubar app + a LaunchAgent so it auto-starts at login.
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
bash "$HERE/build.sh"

APP="$HOME/Applications/CopilotChat.app"
LABEL="io.github.copilot-chat-mcp.menubar"
PLIST="$HOME/Library/LaunchAgents/${LABEL}.plist"

echo "==> writing LaunchAgent $PLIST"
mkdir -p "$(dirname "$PLIST")"
cat > "$PLIST" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key><string>${LABEL}</string>
    <key>ProgramArguments</key>
    <array>
        <string>/usr/bin/open</string>
        <string>-gj</string>
        <string>${APP}</string>
    </array>
    <key>RunAtLoad</key><true/>
    <key>KeepAlive</key><false/>
    <key>StandardOutPath</key><string>/tmp/copilot-chat-bar.out</string>
    <key>StandardErrorPath</key><string>/tmp/copilot-chat-bar.err</string>
</dict>
</plist>
PLIST

# (re)load it
launchctl bootout "gui/$(id -u)/${LABEL}" 2>/dev/null || true
launchctl bootstrap "gui/$(id -u)" "$PLIST"
launchctl kickstart -k "gui/$(id -u)/${LABEL}"

echo "==> installed and launched. Menu bar icon should appear shortly."
