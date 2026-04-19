# Disclaimers

Please read before using.

## Not affiliated

This is an independent, third-party project. It is **not** affiliated
with, endorsed by, or sponsored by:

- GitHub, Inc.
- Microsoft Corporation
- OpenAI
- Anthropic
- Telegram FZ-LLC
- any other company or product referenced in this repository

All trademarks are the property of their respective owners. The word
"Copilot" in this project's name refers generically to the class of
"AI coding assistant" tools and is not a claim of affiliation with
GitHub Copilot™.

## Terms-of-service risk

Most commercial AI coding assistants have acceptable-use policies.
Using a server that lets an assistant:

- keep running past the point it would normally stop
- interact with external chat surfaces (web, Telegram, etc.) that the
  assistant was not designed to talk to
- be driven/steered through a side channel

**may violate those policies and lead to rate limiting, account
suspension, or permanent bans**. The authors and contributors of this
project:

- make **no warranty** that using this project is compatible with any
  provider's terms;
- have performed no legal review of any provider's terms;
- cannot and do not guarantee that your account will not be affected.

It is **your** responsibility to review the terms of service for
whichever AI provider you use and decide whether this project is
compatible with them. **You use it entirely at your own risk.**

## No data collection by this project

The server runs entirely on your machine. It makes outbound network
connections **only** to:

- `https://api.telegram.org` — **only** if you configure a Telegram bot
  token; used for `getUpdates` long-polling and `sendMessage`.
- whichever MCP client (over stdio) launched the server.

It does not send telemetry to the authors or any third party. It does
not persist conversation history to disk — state is kept in-memory and
lost when the process exits.

## Security

- The web UI binds to `127.0.0.1` by default and has **no
  authentication**. Anyone with access to your loopback interface
  (including other processes on your machine) can read and send
  messages. Do not change `HOST` to bind publicly without adding your
  own auth layer.
- The Telegram bot auto-locks to the first chat id that messages it,
  but until that happens **any chat that finds your bot** can become
  the locked chat. Either set `TELEGRAM_CHAT_ID` explicitly, or message
  the bot yourself immediately after starting the server.
- The server accepts arbitrary text from the front-end surfaces and
  forwards it to the MCP client as the return value of the tool calls.
  Treat agent tool-return values with the same skepticism you'd treat
  any user input.

## No warranty

This software is provided "AS IS", without warranty of any kind. See
[LICENSE](./LICENSE) for the full MIT license text.
