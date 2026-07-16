# Claude Usage

Real-time **Claude Code** usage in your macOS menu bar — the **exact 5h / 7d percentages that `/usage` shows.**

Pulls the official `/api/oauth/usage` endpoint (same numbers as Claude Code's `/usage`) through [SwiftBar](https://swiftbar.app). The OAuth token is **self-refreshing** — you log in once and it keeps itself alive. Responses are cached 15 min so it never gets rate-limited. Falls back to a local [ccusage](https://github.com/ryoppippi/ccusage) estimate if you're not logged in. Design inspired by [hohieuu/ai-usage-bar](https://github.com/hohieuu/ai-usage-bar).

## Install

```bash
curl -fsSL https://raw.githubusercontent.com/hellosuongtran/claude-usage-local/main/install/install.sh | bash
```

or

```bash
git clone https://github.com/hellosuongtran/claude-usage-local
bash claude-usage-local/install/install.sh
```

## What you see

Menu bar: `⛁ 52% · 3h16m`

```
Claude Usage · ⚡ Burning fast
  5h  █████░░░░░  52%      ← real session usage (matches /usage)
  ⏱   ███░░░░░░░  34%      ← time elapsed through the 5h window
  Resets 3h16m · 16:10
  7d  █░░░░░░░░░   6%      ← real weekly usage
  ⏱   ████████░░  76%
  Resets 1d 16h · Sat 05:00
──────────
Weekly by model
  Fable    ░░░░░░░░░░   2%
```

**Read the two bars together:** if the `⏱` (time) bar is longer than the usage bar, you're under pace. If usage pulls ahead of time, the header flips to **⚡ Burning fast** → **⚠️ Slow down** → **🛑 Hold**.

## How it works

- Reads the OAuth token from your macOS Keychain (`Claude Code-credentials`).
- Calls `GET /api/oauth/usage` — the **same source as `/usage`**, so `five_hour` / `seven_day` percentages match exactly.
- When the access token nears expiry, it **refreshes automatically** (rotating refresh token, written back to the Keychain) — so you only `claude login` once.
- Caches the response for **15 minutes**, so polling never triggers a rate limit.
- If you're not logged in, it falls back to a local ccusage token estimate and prompts you to log in.

## Features

- **Exact numbers** — matches `/usage` (real 5h/7d limits, not an estimate).
- **Self-refreshing auth** — log in once, runs indefinitely.
- **Dual bars** — usage vs. time-through-window, so you see pace at a glance.
- **Per-model weekly** — scoped limits (e.g. Fable) straight from the API.
- **Reset notification** — a macOS alert fires when the 5-hour window resets.
- **Light/dark aware** — colors adapt to your menu bar appearance.
- **Rate-limit safe** — 15-min cache, so it never hammers the endpoint.

## Requirements

macOS · [Homebrew](https://brew.sh) · Node · [Claude Code](https://claude.ai/download) — logged in (`claude login`).

The installer handles SwiftBar, ccusage, the plugin, and launch-at-login for you.

## Uninstall

```bash
bash claude-usage-local/install/uninstall.sh
```

## License

MIT
