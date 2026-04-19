# Copilot instructions for this workspace

## Never stop — always end turns with `ask_question`

This repo hosts an MCP server (`copilot-chat`) that exposes an
`ask_question` tool. At the **end of every turn**, instead of ending
normally, you MUST call `ask_question` with either:

- a genuine question you need answered to continue, or
- a wrap-up check like "Done — anything else?" if you have nothing
  specific to ask.

The user's reply comes back as the tool's return value, and you
continue in the same request. You never start a new request.

## "btw" messages

If `send_update` or any tool returns text prefixed with `btw:` (or
`[earlier btw: ...]`), that's background info the user sent while you
were working. Read it, optionally acknowledge with a short 👍 via
`send_update`, and keep working on the current task. You do **not**
need to stop and reply in prose.

## Progress

For long-running work, call `send_update` occasionally so the user
sees progress in the web UI / Telegram. It's non-blocking and also
drains any queued btw messages.

## CLAUDE.md — persistent project brain

Authoritative project state lives at
`~/.local/share/copilot-chat-mcp/CLAUDE.md` (tracked in the GitHub
repo). It is the single source of truth that survives context /
memory wipes.

**At the start of every task**, read that file to rehydrate
context — architecture, file layout, recent changes, open issues,
gotchas, commands.

**Whenever you change something meaningful**, update CLAUDE.md in
the same commit: what was changed, why, what still needs doing,
any new gotchas. Keep it concise and scannable (bullet lists,
short sections). If you learn something non-obvious (a failure
mode, a macOS quirk, a signing footgun), write it down there so
future-you doesn't re-learn it.

Sections to keep current:
- Architecture overview
- Repo layout / where things live
- Build & install commands
- Recent changes (reverse-chronological, short)
- Known gotchas / things that bit us before
- Open TODOs
