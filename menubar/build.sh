#!/usr/bin/env bash
# Builds CopilotChatBar and packages it into ~/Applications/CopilotChat.app
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
cd "$HERE"

APP_NAME="CopilotChat"
BUNDLE_ID="io.github.copilot-chat-mcp.menubar"
DEST="$HOME/Applications/${APP_NAME}.app"
EXE_NAME="CopilotChatBar"

echo "==> swift build (release)"
swift build -c release --arch arm64

BIN=".build/release/${EXE_NAME}"
if [[ ! -x "$BIN" ]]; then
    echo "build failed: $BIN not found" >&2; exit 1
fi

echo "==> packaging .app at $DEST"
rm -rf "$DEST"
mkdir -p "$DEST/Contents/MacOS"
mkdir -p "$DEST/Contents/Resources"
cp "$BIN" "$DEST/Contents/MacOS/${EXE_NAME}"
cp "Info.plist" "$DEST/Contents/Info.plist"

# Ad-hoc code sign so macOS is happy to launch it.
codesign --force --sign - --deep "$DEST" >/dev/null 2>&1 || true

echo "==> done: $DEST"
