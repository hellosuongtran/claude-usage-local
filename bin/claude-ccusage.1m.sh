#!/bin/bash
# Claude Usage (local) — SwiftBar plugin backed by ccusage.
# Reads local ~/.claude logs. No API call, so NEVER rate-limited.
# Design inspired by github.com/hohieuu/ai-usage-bar (dual usage/time bars).
# Fires a macOS notification when a new 5h block starts (usage reset).
# <swiftbar.title>Claude Usage</swiftbar.title>
# <swiftbar.hideAbout>true</swiftbar.hideAbout>
# <swiftbar.hideLastUpdated>true</swiftbar.hideLastUpdated>
# <swiftbar.hideDisablePlugin>true</swiftbar.hideDisablePlugin>

export PATH="$HOME/Library/pnpm:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin"

CCUSAGE="$HOME/Library/pnpm/ccusage"
[ -x "$CCUSAGE" ] || CCUSAGE="ccusage"
command -v "$CCUSAGE" >/dev/null 2>&1 || CCUSAGE="npx -y ccusage@latest"

if [ "${1:-}" = "--live" ]; then
  exec $CCUSAGE blocks --live
fi

BLOCKS_JSON=$($CCUSAGE blocks --json 2>/dev/null)
DAILY_JSON=$($CCUSAGE daily --json --breakdown 2>/dev/null)

python3 - "$BLOCKS_JSON" "$DAILY_JSON" "$0" <<'PY'
import sys, json, datetime, os, subprocess
from collections import defaultdict

def load(s):
    try: return json.loads(s)
    except Exception: return None

bdata = load(sys.argv[1]) or {}
ddata = load(sys.argv[2]) or {}
SELF  = sys.argv[3]

# light,dark
GREEN="#007a29,#30d158"; YELLOW="#b25000,#ffb340"; RED="#c40000,#ff453a"
DIM="#6b6b6b,#9a9a9a";   BLUE="#0069c0,#5ac8fa"

def fmt(n):
    if n >= 1_000_000: return f"{n/1_000_000:.1f}M"
    if n >= 1_000:     return f"{n/1_000:.0f}k"
    return str(int(n))

def make_bar(pct):
    p = max(0, min(100, int(round(pct))))
    f = int(round(p/10))
    return "█"*f + "░"*(10-f) + f" {p:>3}%"

def col(pct):
    return GREEN if pct < 65 else (YELLOW if pct < 90 else RED)

def short(name):
    return name.replace("claude-", "").split("-2025")[0]

# ── 5h BLOCK ──
blocks = bdata.get("blocks", [])
completed = [b["totalTokens"] for b in blocks
             if not b.get("isActive") and not b.get("isGap") and b.get("totalTokens")]
BLOCK_LIMIT = max(completed) if completed else 43_000_000
active = next((b for b in blocks if b.get("isActive")), None)

# ── notify on a NEW 5h block (usage reset) ──
STATE = os.path.expanduser("~/.claude-usage-bar/last_block_id")
cur_id = active.get("id") if active else None
if cur_id:
    prev = None
    try: prev = open(STATE).read().strip()
    except Exception: pass
    if prev and prev != cur_id:
        try:
            subprocess.run(["osascript","-e",
                'display notification "New 5-hour block started — your usage limit just reset." '
                'with title "Claude Usage" subtitle "Fresh quota available" sound name "Glass"'],
                timeout=5)
        except Exception: pass
    try:
        os.makedirs(os.path.dirname(STATE), exist_ok=True)
        open(STATE,"w").write(cur_id)
    except Exception: pass

# ── WEEK (rolling 7 days) ──
daily = ddata.get("daily", [])
day_tot = [d.get("totalTokens", 0) for d in daily]
week_used = sum(day_tot[-7:])
WEEK_LIMIT = max((sum(day_tot[i:i+7]) for i in range(max(1, len(day_tot)-6))), default=week_used) or week_used
week_pct = 100*week_used/WEEK_LIMIT if WEEK_LIMIT else 0

wm = defaultdict(lambda: [0, 0.0])
for d in daily[-7:]:
    for m in d.get("modelBreakdowns", []):
        t = m["inputTokens"]+m["outputTokens"]+m["cacheCreationTokens"]+m["cacheReadTokens"]
        wm[m["modelName"]][0] += t; wm[m["modelName"]][1] += m["cost"]
tm = defaultdict(lambda: [0, 0.0])
if daily:
    for m in daily[-1].get("modelBreakdowns", []):
        t = m["inputTokens"]+m["outputTokens"]+m["cacheCreationTokens"]+m["cacheReadTokens"]
        tm[m["modelName"]][0] += t; tm[m["modelName"]][1] += m["cost"]

# ── block figures + time-through-window ──
now = datetime.datetime.now(datetime.timezone.utc)
if active:
    used = active.get("totalTokens", 0)
    b_pct = 100*used/BLOCK_LIMIT if BLOCK_LIMIT else 0
    tpm = (active.get("burnRate") or {}).get("tokensPerMinute", 0) or 0
    try:
        st = datetime.datetime.fromisoformat(active["startTime"].replace("Z","+00:00"))
        en = datetime.datetime.fromisoformat(active["endTime"].replace("Z","+00:00"))
        span = (en-st).total_seconds()
        t_pct = 100*max(0,(now-st).total_seconds())/span if span else 0
        secs = max(0, int((en-now).total_seconds()))
        remaining = f"{secs//3600}h{(secs%3600)//60:02d}m"; local_end = en.astimezone().strftime("%H:%M")
    except Exception:
        t_pct=0; secs=0; remaining="?"; local_end="?"
    rem = max(0, BLOCK_LIMIT-used)
    hits = tpm>0 and (rem/tpm*60) < secs
    eta_min = int(rem/tpm) if tpm>0 else 0
else:
    used=b_pct=tpm=t_pct=secs=0; remaining="—"; local_end="—"; hits=False; eta_min=0

# ── header state ──
if not active:
    head, hc = "idle", DIM
elif b_pct>=90 or hits:
    head, hc = "Hold — near cap", RED
elif b_pct>=65:
    head, hc = "Slow down", YELLOW
elif b_pct > t_pct + 15:
    head, hc = "Burning fast", YELLOW
else:
    head, hc = "Plenty left", GREEN

# ===== menu bar =====
mb_col = RED if (b_pct>=90 or hits) else (YELLOW if max(b_pct,week_pct)>=65 else GREEN)
if active:
    print(f"⛁ {b_pct:.0f}% · {remaining} | font=Menlo-Bold size=13 color={mb_col}")
else:
    print(f"⛁ idle | font=Menlo-Bold size=13 color={DIM}")

# ===== dropdown =====
print("---")
print(f"Claude Usage · {head} | font=Menlo-Bold size=12 color={hc}")

if active:
    print(f"  5h  {make_bar(b_pct)} | font=Menlo size=12 color={col(b_pct)}")
    print(f"  ⏱   {make_bar(t_pct)} | font=Menlo size=12 color={BLUE}")
    print(f"  {fmt(used)} / {fmt(BLOCK_LIMIT)} tok | font=Menlo size=11 color={DIM}")
    if hits:
        eh,em = eta_min//60, eta_min%60
        print(f"  Reset {remaining} · {local_end}  ⚠️ cap in ~{eh}h{em:02d}m | font=Menlo size=11 color={RED}")
    else:
        print(f"  Reset {remaining} · {local_end} | font=Menlo size=11 color={DIM}")
else:
    print(f"  5h  no active session | font=Menlo size=12 color={DIM}")

print(f"  7d  {make_bar(week_pct)} | font=Menlo size=12 color={col(week_pct)}")
print(f"  {fmt(week_used)} / {fmt(WEEK_LIMIT)} tok · rolling | font=Menlo size=11 color={DIM}")

# ===== per-model =====
print("---")
print(f"Models · 7d | font=Menlo size=11 color={DIM}")
for name,(t,c) in sorted(wm.items(), key=lambda x:-x[1][0]):
    print(f"  {short(name):<9} {fmt(t):>6} · ${c:.0f} | font=Menlo size=11 color={DIM}")
if tm:
    print(f"Models · today | font=Menlo size=11 color={DIM}")
    for name,(t,c) in sorted(tm.items(), key=lambda x:-x[1][0]):
        print(f"  {short(name):<9} {fmt(t):>6} · ${c:.2f} | font=Menlo size=11 color={DIM}")

# ===== bars legend + actions =====
print("---")
print(f"█ used   ⏱ time through window | font=Menlo size=11 color={DIM}")
print(f"Live view (Terminal) | bash='{SELF}' param1=--live terminal=true")
print("Refresh | refresh=true")
PY
