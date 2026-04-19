"""Copilot Chat MCP server.

Exposes MCP tools (ask_question / send_update / check_messages) over stdio
AND simultaneously serves:
  - a local web chat UI (http://127.0.0.1:$PORT)
  - an optional Telegram bot bridge (long-polling)

All three surfaces share the same conversation state so the user can answer
from whichever one is convenient.

Design:
  * `ask_question` blocks the Copilot turn until the user replies.
  * Messages the user sends while no question is pending are queued as "btw"
    and delivered piggy-backed on the next tool return.
"""
from __future__ import annotations

import asyncio
import json
import os
import sys
import time
import uuid
from pathlib import Path

from aiohttp import ClientSession, WSMsgType, web
from mcp.server.fastmcp import FastMCP

# ---------------------------------------------------------------------------
# Config
# ---------------------------------------------------------------------------
ROOT = Path(__file__).parent
STATIC = ROOT / "static"
PORT = int(os.environ.get("PORT", "8765"))
HOST = os.environ.get("HOST", "127.0.0.1")
TG_TOKEN = os.environ.get("TELEGRAM_BOT_TOKEN", "").strip()
TG_CHAT_ID = os.environ.get("TELEGRAM_CHAT_ID", "").strip()


def log(*a: object) -> None:
    # MUST go to stderr — stdout is reserved for the MCP protocol.
    print("[copilot-chat]", *a, file=sys.stderr, flush=True)


# ---------------------------------------------------------------------------
# Shared state
# ---------------------------------------------------------------------------
history: list[dict] = []                 # full message log (for UI replay)
websockets: set[web.WebSocketResponse] = set()
inbox: list[dict] = []                   # unread "btw" user messages
pending_questions: dict[str, dict] = {}  # qid -> {question, future}
_loop: asyncio.AbstractEventLoop | None = None


async def broadcast(msg: dict) -> None:
    history.append(msg)
    if len(history) > 500:
        del history[:-500]
    dead = []
    for ws in list(websockets):
        try:
            await ws.send_json(msg)
        except Exception:
            dead.append(ws)
    for ws in dead:
        websockets.discard(ws)


async def tg_send(text: str) -> None:
    if not (TG_TOKEN and TG_CHAT_ID):
        return
    try:
        async with ClientSession() as s:
            await s.post(
                f"https://api.telegram.org/bot{TG_TOKEN}/sendMessage",
                json={"chat_id": TG_CHAT_ID, "text": text},
                timeout=10,
            )
    except Exception as e:
        log("telegram send failed:", e)


async def deliver_user_message(text: str, source: str) -> None:
    """Route an incoming user message: either resolve a pending question or
    queue it as a btw message."""
    msg = {
        "role": "user",
        "text": text,
        "ts": time.time(),
        "source": source,
    }
    await broadcast(msg)

    if pending_questions:
        # Resolve the oldest pending question.
        qid = next(iter(pending_questions))
        entry = pending_questions.pop(qid)
        if not entry["future"].done():
            entry["future"].set_result(text)
    else:
        inbox.append(msg)


def drain_inbox() -> str:
    if not inbox:
        return ""
    parts = [f"[{m['source']}] {m['text']}" for m in inbox]
    inbox.clear()
    return " | ".join(parts)


# ---------------------------------------------------------------------------
# MCP tools
# ---------------------------------------------------------------------------
mcp = FastMCP("copilot-chat")


@mcp.tool()
async def ask_question(question: str) -> str:
    """Ask the user a question and WAIT for their reply.

    ALWAYS call this at the end of every turn instead of stopping — that way
    Copilot never has to be re-invoked. Whatever the user types in the web UI
    or Telegram will be returned as this tool's result. Any "btw" messages the
    user already sent while you were working are appended in brackets.
    """
    qid = uuid.uuid4().hex
    loop = asyncio.get_running_loop()
    fut: asyncio.Future[str] = loop.create_future()
    pending_questions[qid] = {"question": question, "future": fut}

    await broadcast({
        "role": "assistant",
        "text": question,
        "ts": time.time(),
        "kind": "question",
    })
    await tg_send(f"❓ {question}")

    reply = await fut
    extra = drain_inbox()
    if extra:
        return f"{reply}\n\n[earlier btw: {extra}]"
    return reply


@mcp.tool()
async def send_update(message: str) -> str:
    """Send a progress update / thinking-aloud message to the user WITHOUT
    blocking. Returns any pending 'btw' messages the user sent while you
    worked, or "(no new messages)"."""
    await broadcast({
        "role": "assistant",
        "text": message,
        "ts": time.time(),
        "kind": "update",
    })
    await tg_send(f"ℹ️ {message}")
    extra = drain_inbox()
    return f"btw: {extra}" if extra else "(no new messages)"


@mcp.tool()
async def check_messages() -> str:
    """Non-blocking: return any queued 'btw' messages from the user, or
    "(no new messages)"."""
    extra = drain_inbox()
    return f"btw: {extra}" if extra else "(no new messages)"


# ---------------------------------------------------------------------------
# Web UI
# ---------------------------------------------------------------------------
async def index_handler(_: web.Request) -> web.Response:
    return web.FileResponse(STATIC / "index.html")


async def ws_handler(request: web.Request) -> web.WebSocketResponse:
    ws = web.WebSocketResponse(heartbeat=30)
    await ws.prepare(request)
    websockets.add(ws)
    try:
        # Replay recent history so a newly-opened tab sees context.
        for m in history[-100:]:
            await ws.send_json(m)
        async for raw in ws:
            if raw.type != WSMsgType.TEXT:
                continue
            try:
                data = json.loads(raw.data)
            except Exception:
                continue
            text = (data.get("text") or "").strip()
            source = data.get("source") or "web"
            if text:
                await deliver_user_message(text, source=source)
    finally:
        websockets.discard(ws)
    return ws


# ---------------------------------------------------------------------------
# Telegram long-polling
# ---------------------------------------------------------------------------
async def telegram_poller() -> None:
    if not TG_TOKEN:
        log("telegram disabled (no TELEGRAM_BOT_TOKEN)")
        return
    log("telegram poller starting")
    offset = 0
    while True:
        try:
            async with ClientSession() as s:
                async with s.get(
                    f"https://api.telegram.org/bot{TG_TOKEN}/getUpdates",
                    params={"timeout": 30, "offset": offset},
                    timeout=60,
                ) as r:
                    data = await r.json()
            if not data.get("ok"):
                log("telegram getUpdates error:", data)
                await asyncio.sleep(3)
                continue
            for upd in data.get("result", []):
                offset = upd["update_id"] + 1
                msg = upd.get("message") or upd.get("edited_message") or {}
                text = msg.get("text")
                chat_id = str(msg.get("chat", {}).get("id", ""))
                if not text:
                    continue
                # If TG_CHAT_ID not configured, auto-lock to first chat that writes.
                global TG_CHAT_ID
                if not TG_CHAT_ID:
                    TG_CHAT_ID = chat_id
                    log(f"telegram locked to chat_id={chat_id}")
                if chat_id != TG_CHAT_ID:
                    continue
                await deliver_user_message(text, source="telegram")
        except Exception as e:
            log("telegram poll error:", e)
            await asyncio.sleep(3)


# ---------------------------------------------------------------------------
# Entrypoint
# ---------------------------------------------------------------------------
async def main() -> None:
    global _loop
    _loop = asyncio.get_running_loop()

    app = web.Application()
    app.router.add_get("/", index_handler)
    app.router.add_get("/ws", ws_handler)
    app.router.add_static("/static/", STATIC)

    runner = web.AppRunner(app)
    await runner.setup()
    site = web.TCPSite(runner, HOST, PORT)
    await site.start()
    log(f"web UI:   http://{HOST}:{PORT}")
    log(f"telegram: {'enabled' if TG_TOKEN else 'disabled'}")

    asyncio.create_task(telegram_poller())

    # Run MCP on stdio — this blocks for the lifetime of the process.
    await mcp.run_stdio_async()


if __name__ == "__main__":
    try:
        asyncio.run(main())
    except KeyboardInterrupt:
        pass
