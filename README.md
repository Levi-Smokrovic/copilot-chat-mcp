# Copilot Chat MCP

A tiny MCP (Model Context Protocol) server that lets an AI coding agent
**ask you questions and wait for your answer** — from a local web UI, a
Telegram bot, or an optional macOS menu bar app — so a long-running task
can proceed without the agent having to end its turn and wait to be
re-invoked.

> [!WARNING]
> **Read the [Disclaimers](#disclaimers) section before using this.**
> This project is not affiliated with, endorsed by, or sponsored by
> GitHub, Microsoft, OpenAI, Anthropic, or any other company. Using it
> with any AI assistant may violate that assistant's terms of service.
> You use it entirely at your own risk.

## What it does

The server exposes three MCP tools:

| Tool             | Blocking | Purpose |
|------------------|----------|---------|
| `ask_question`   | yes      | Ask the user something and wait for a reply. |
| `send_update`    | no       | Send a progress update; returns any queued background messages. |
| `check_messages` | no       | Drain queued background messages from the user. |

Messages the user sends while no question is pending are queued as
"btw" (background info) and piggy-backed onto the next tool return —
so the agent can read them without interrupting its work.

The user can answer from any of three interchangeable surfaces:

- **Web UI** — `http://127.0.0.1:8765`
- **Telegram bot** — optional, via long-polling (no public webhook needed)
- **macOS menu bar app** — optional native SwiftUI popover (macOS 26+)

All three share the same conversation state.

## Requirements

- macOS, Linux, or Windows with **Python 3.10+**
- For the menu bar app: **macOS 26+** and **Xcode 16+** (uses the
  Liquid Glass SwiftUI APIs)
- For Telegram: a bot token from [@BotFather](https://t.me/BotFather)

## Install — server

```bash
git clone https://github.com/Levi-Smokrovic/copilot-chat-mcp.git
cd copilot-chat-mcp
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
```

Standalone smoke test (the web UI will be available at
`http://127.0.0.1:8765`):

```bash
python server.py
```

Stdin must stay attached (that's how MCP stdio works); if you just want
to test the web UI, `python server.py < /dev/tty` works.

## Register with an MCP-capable client

### VS Code / GitHub Copilot Chat

Open **Command Palette → "MCP: Open User Configuration"** and add:

```json
{
  "servers": {
    "copilot-chat": {
      "type": "stdio",
      "command": "${userHome}/path/to/copilot-chat-mcp/.venv/bin/python",
      "args": ["${userHome}/path/to/copilot-chat-mcp/server.py"],
      "env": {
        "HOST": "127.0.0.1",
        "PORT": "8765",
        "TELEGRAM_BOT_TOKEN": "",
        "TELEGRAM_CHAT_ID": ""
      }
    }
  }
}
```

Reload VS Code, then enable the `copilot-chat` tools in the agent tool
picker. See [`.env.example`](./.env.example) for the full list of env vars.

### Other clients (Claude Desktop, etc.)

Any client that speaks stdio MCP can use the same `command` / `args`.

## For AI agents: self-install prompt

If the user asks an AI agent to "install copilot-chat-mcp", the agent
can follow this script verbatim. Absolute paths use the current user's
home directory.

```markdown
# Goal
Install the copilot-chat MCP server so future turns end with `ask_question`
instead of ending the request.

# Steps

1. Clone into the user's data dir (kept out of their code repos):
   ```bash
   mkdir -p ~/.local/share
   git clone https://github.com/Levi-Smokrovic/copilot-chat-mcp.git \
       ~/.local/share/copilot-chat-mcp
   cd ~/.local/share/copilot-chat-mcp
   python3 -m venv .venv
   .venv/bin/pip install -r requirements.txt
   ```

2. Register the server with the user's MCP client. For VS Code, append
   (don't overwrite) to `~/Library/Application Support/Code/User/mcp.json`
   on macOS, or the OS-equivalent:
   ```json
   {
     "servers": {
       "copilot-chat": {
         "type": "stdio",
         "command": "${userHome}/.local/share/copilot-chat-mcp/.venv/bin/python",
         "args":    ["${userHome}/.local/share/copilot-chat-mcp/server.py"],
         "env": {
           "HOST": "127.0.0.1",
           "PORT": "8765",
           "TELEGRAM_BOT_TOKEN": "",
           "TELEGRAM_CHAT_ID": ""
         }
       }
     }
   }
   ```
   Ask the user for their Telegram bot token ONLY if they want the
   Telegram surface. Never commit that token anywhere.

3. Add the "never stop" instruction to the project's
   `.github/copilot-instructions.md` (create if missing). Copy the
   block from the root of this repo's
   [.github/copilot-instructions.md](./.github/copilot-instructions.md).

4. Optional macOS menu bar app — only on macOS 26+ with Xcode 16+:
   ```bash
   cd ~/.local/share/copilot-chat-mcp/menubar
   bash install.sh
   /usr/bin/open /Users/$USER/Applications/CopilotChat.app
   ```

5. Reload VS Code / restart the MCP client. Verify the `copilot-chat`
   tools (`ask_question`, `send_update`, `check_messages`) are listed.

6. Test: call `ask_question` with "Install complete — can you see this?".
   The user should get it in the web UI at http://127.0.0.1:8765 (and
   Telegram / menu bar if enabled).

# Rules while installing

- Never commit the Telegram bot token to git. It lives only in mcp.json.
- Don't touch the user's other mcp.json entries.
- If port 8765 is busy, pick another and update both `PORT` and the
  menu-bar app's server URL in its Settings pane.
- After install, read [CLAUDE.md](./CLAUDE.md) — it's the persistent
  project brain.
```

## The "never stop" prompt

For this to be useful you need to instruct your agent to actually call
`ask_question` at end of turn. A minimal instruction block (drop it in
`.github/copilot-instructions.md` or your client's system prompt):

```markdown
## Always end turns with `ask_question`

Instead of ending your turn normally, call the `ask_question` tool with
either a real question or a wrap-up check like "Done — anything else?".
The user's reply is returned by the tool and you keep working in the
same request.

## "btw" messages

Any text the user sends while you were working is returned to you
prefixed with `btw:` on the next tool call. Read it, optionally
acknowledge via `send_update`, and keep working.
```

See [`.github/copilot-instructions.md`](./.github/copilot-instructions.md)
for a complete example.

## Telegram

1. `/newbot` in [@BotFather](https://t.me/BotFather); copy the token.
2. Put the token in `TELEGRAM_BOT_TOKEN` in your MCP client's `env`.
3. Message your bot once (`/start`). The server auto-locks to the first
   chat id that sends it a message, so you don't need to look it up
   manually. If you prefer, set `TELEGRAM_CHAT_ID` explicitly.

## macOS menu bar app (optional)

A minimal SwiftUI menu bar popover that connects to the server's
WebSocket, shows Liquid Glass chat bubbles, and posts a native
notification every time the agent asks a question or sends an update.

```bash
cd menubar
./install.sh
```

This builds a Release binary, packages it as
`~/Applications/CopilotChat.app`, and installs a LaunchAgent so the app
starts at login. To uninstall:

```bash
launchctl bootout "gui/$(id -u)/io.github.copilot-chat-mcp.menubar" 2>/dev/null || true
rm -f "$HOME/Library/LaunchAgents/io.github.copilot-chat-mcp.menubar.plist"
rm -rf "$HOME/Applications/CopilotChat.app"
```

## How it works (architecture)

```
┌────────────┐     stdio      ┌──────────────┐
│ MCP client │ ─────────────► │  server.py   │
│ (IDE etc.) │ ◄───────────── │              │
└────────────┘   tool calls   │  shared      │
                              │  conversation│
                              │  state       │
 ┌──────────┐     WebSocket   │              │
 │ Web UI   │ ◄──────────────►│              │
 └──────────┘                 │              │
                              │              │
 ┌──────────┐   long-polling  │              │
 │ Telegram │ ◄──────────────►│              │
 └──────────┘                 └──────────────┘
```

A single asyncio process runs all three surfaces. Tool calls and
front-end messages are multiplexed onto the same message log and the
same pending-question queue.

## Disclaimers

**Not affiliated.** This project is a third-party experiment. "GitHub",
"Copilot", "Microsoft", "Claude", "ChatGPT", and any other product or
company name referenced are trademarks of their respective owners. This
project is not affiliated with, endorsed by, or sponsored by any of
them.

**Terms-of-service risk.** Many AI assistants (including GitHub Copilot)
have usage policies. Using a tool that effectively lets an agent run
indefinitely by answering its own stop-conditions, or using the agent to
interact with chat channels it was not designed for, **may violate those
policies and get your account suspended or banned**. The authors and
contributors make **no claim** that this project is compatible with any
such policies. Review your provider's terms yourself. Use at your own
risk.

**No warranty.** This software is provided "as is", without warranty of
any kind. See [LICENSE](./LICENSE).

**No data collection by this project.** The server runs entirely on
your machine. It makes outbound connections only to `api.telegram.org`
(when a Telegram token is configured) and whatever MCP client spawned
it. It does not send telemetry anywhere. Your conversation data lives
in memory on your own computer.

**Security.** The web UI binds to `127.0.0.1` by default and has no
authentication. Do not expose it on a public interface. If you change
`HOST`, add your own auth layer (reverse proxy, tunnel with auth,
etc.). The WebSocket accepts any local message as user input.

## License

MIT — see [LICENSE](./LICENSE).
