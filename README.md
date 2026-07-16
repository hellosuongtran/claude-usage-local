# Claude Usage (local)

Real-time **Claude Code** usage in your macOS menu bar — **100% local, no API calls, never rate-limited.**

Reads your local `~/.claude` logs via [ccusage](https://github.com/ryoppippi/ccusage) and renders them through [SwiftBar](https://swiftbar.app). Design inspired by [hohieuu/ai-usage-bar](https://github.com/hohieuu/ai-usage-bar), but rebuilt on local logs so it never hits Anthropic's rate-limited usage endpoint.

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

Menu bar: `⛁ 23% · 2h09m`

```
Claude Usage · Plenty left
  5h  ██░░░░░░░░  23%      ← usage this 5h block
  ⏱   ██████░░░░  57%      ← time elapsed through the window
  10.0M / 43.5M tok
  Reset 2h09m · 14:00
  7d  ███░░░░░░░  26%      ← rolling 7-day usage
  89.9M / 339.2M tok · rolling
──────────
Models · 7d
  fable-5    52.0M · $132
  opus-4-8   36.7M · $45
Models · today
  fable-5     5.2M · $11.07
  opus-4-8    4.7M · $5.44
```

**Read the two bars together:** if the `⏱` (time) bar is longer than the `5h` (usage) bar, you're under pace — plenty left. If usage pulls ahead of time, the header flips to **Burning fast** / **Slow down** / **Hold**.

## How limits are estimated

There's no public token cap for a subscription, so the "ceiling" is derived from **your own history**:

- **5h cap** = your heaviest completed 5-hour block ever.
- **7d cap** = your heaviest rolling 7-day span ever.

Since Anthropic cuts you off around your heaviest block, this is a close proxy for the real limit — and it self-corrects as you use more.

## Features

- **Dual bars** — usage vs. time-through-window, so you see pace at a glance.
- **Per-model breakdown** — tokens + cost for last 7 days and today.
- **Reset notification** — a macOS alert fires when a new 5-hour block starts (fresh quota).
- **Light/dark aware** — colors adapt to your menu bar appearance.
- **Never rate-limited** — all data comes from local logs, zero network.

## Requirements

macOS · [Homebrew](https://brew.sh) · Node · [Claude Code](https://claude.ai/download)

The installer handles SwiftBar, ccusage, the plugin, and launch-at-login for you.

## Uninstall

```bash
bash claude-usage-local/install/uninstall.sh
```

## License

MIT
