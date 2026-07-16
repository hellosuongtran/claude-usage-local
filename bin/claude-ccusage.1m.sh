#!/bin/bash
# Claude Usage — SwiftBar plugin.
# Primary: official /api/oauth/usage (REAL 5h/7d % that matches `/usage`),
#   with self-refreshing OAuth token (login once) + 15-min response cache.
# Fallback: local ccusage estimate if not logged in.
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
FORCE=0; [ "${1:-}" = "--force" ] && FORCE=1

DAILY_JSON=$($CCUSAGE daily --json --breakdown 2>/dev/null)

FORCE="$FORCE" python3 - "$DAILY_JSON" "$0" <<'PY'
import sys, json, os, time, datetime, subprocess

DAILY = sys.argv[1]; SELF = sys.argv[2]
FORCE = os.environ.get("FORCE") == "1"
DIR   = os.path.expanduser("~/.claude-usage-bar"); os.makedirs(DIR, exist_ok=True)
CACHE = os.path.join(DIR, "usage-cache.json")
LOCK  = os.path.join(DIR, "refresh.lock")
NOTE  = os.path.join(DIR, "last_reset")
CLIENT_ID = "9d1c250a-e61b-44d9-88ed-5944d1962f5e"

GREEN="#007a29,#30d158"; YELLOW="#b25000,#ffb340"; RED="#c40000,#ff453a"
DIM="#6b6b6b,#9a9a9a"; BLUE="#0069c0,#5ac8fa"

def col(p): return GREEN if p < 65 else (YELLOW if p < 90 else RED)
def make_bar(p):
    p = max(0, min(100, int(round(p)))); f = int(round(p/10))
    return "█"*f + "░"*(10-f) + f" {p:>3}%"

# ---------- OAuth: read keychain, refresh if needed, write back ----------
def kc_read():
    try:
        raw = subprocess.run(["security","find-generic-password","-s","Claude Code-credentials","-w"],
                             capture_output=True, text=True, timeout=5).stdout.strip()
        return json.loads(raw).get("claudeAiOauth")
    except Exception:
        return None

def kc_write(o):
    try:
        creds = {"claudeAiOauth": o}
        subprocess.run(["security","add-generic-password","-U","-s","Claude Code-credentials",
                        "-a", os.environ.get("USER","")], input=json.dumps(creds),
                       capture_output=True, text=True, timeout=5, check=True)
        return True
    except Exception:
        return False

def refresh(o):
    # single-use refresh token → must persist the rotated one immediately
    body = json.dumps({"grant_type":"refresh_token","refresh_token":o["refreshToken"],
                       "client_id":CLIENT_ID})
    p = subprocess.run(["curl","-s","--max-time","12","-X","POST",
        "https://api.anthropic.com/v1/oauth/token",
        "-H","Content-Type: application/json","-d", body], capture_output=True, text=True)
    d = json.loads(p.stdout)
    if "access_token" not in d:
        raise RuntimeError("refresh failed: " + p.stdout[:200])
    o["accessToken"]  = d["access_token"]
    o["refreshToken"] = d.get("refresh_token", o["refreshToken"])
    o["expiresAt"]    = int((time.time() + d.get("expires_in", 28800)) * 1000)
    kc_write(o)
    return o

def get_token():
    o = kc_read()
    if not o or "accessToken" not in o:
        return None, "not_logged_in"
    if o.get("expiresAt", 0)/1000 > time.time() + 120:
        return o["accessToken"], "ok"
    # expired/near — refresh under a soft lock (avoid concurrent double-refresh)
    try:
        if os.path.exists(LOCK) and time.time() - os.path.getmtime(LOCK) < 30:
            return o["accessToken"], "ok"   # another run is refreshing; use current
        open(LOCK,"w").write("1")
        o = refresh(o)
        return o["accessToken"], "ok"
    except Exception:
        return o.get("accessToken"), "refresh_failed"

def fetch_usage(token):
    p = subprocess.run(["curl","-s","--max-time","10",
        "-H",f"Authorization: Bearer {token}","-H","anthropic-beta: oauth-2025-04-20",
        "-H","Content-Type: application/json",
        "https://api.anthropic.com/api/oauth/usage"], capture_output=True, text=True)
    d = json.loads(p.stdout)
    if "five_hour" not in d:
        raise RuntimeError("usage failed: " + p.stdout[:200])
    return d

def load_cache():
    try:
        c = json.load(open(CACHE))
        return c["data"], time.time() - c["ts"]
    except Exception:
        return None, 1e9

# ---------- get usage (cache 15 min) ----------
data = None; age = 1e9; state = "ok"
token, tstate = get_token()
if tstate == "ok" and token:
    data, age = load_cache()
    if FORCE or data is None or age > 900:
        try:
            data = fetch_usage(token)
            json.dump({"ts": time.time(), "data": data}, open(CACHE,"w"))
            age = 0
        except Exception:
            if data is None: state = "fetch_failed"
    else:
        state = "cached"
else:
    state = tstate

def fmt_reset(iso):
    try:
        dt = datetime.datetime.fromisoformat(iso)
        now = datetime.datetime.now(dt.tzinfo)
        secs = max(0, int((dt-now).total_seconds()))
        d,h,m = secs//86400, (secs%86400)//3600, (secs%3600)//60
        cd = (f"{d}d {h}h" if d else (f"{h}h{m:02d}m" if h else f"{m}m"))
        return cd, dt.astimezone().strftime("%a %H:%M" if d else "%H:%M"), secs
    except Exception:
        return "?", "?", 0
def time_pct(iso, window_h):
    _,_,secs = fmt_reset(iso)
    return max(0, min(100, 100*(window_h*3600 - secs)/(window_h*3600)))

# ================= OFFICIAL DATA PATH =================
if data and isinstance(data, dict) and data.get("five_hour"):
    five = data.get("five_hour") or {}
    week = data.get("seven_day") or {}
    fp = float(five.get("utilization") or 0)
    wp = float(week.get("utilization") or 0)
    f_cd, f_at, f_secs = fmt_reset(five.get("resets_at",""))
    w_cd, w_at, w_secs = fmt_reset(week.get("resets_at",""))
    ftp = time_pct(five.get("resets_at",""), 5)
    wtp = time_pct(week.get("resets_at",""), 168)

    # per-model weekly (scoped limits)
    scoped = []
    for lim in data.get("limits", []):
        if lim.get("kind") == "weekly_scoped" and lim.get("scope",{}).get("model",{}).get("display_name"):
            scoped.append((lim["scope"]["model"]["display_name"], float(lim.get("percent") or 0)))

    # reset notification when the 5h window rolls over
    try:
        prev = open(NOTE).read().strip()
    except Exception:
        prev = ""
    if five.get("resets_at") and prev and prev != five["resets_at"]:
        subprocess.run(["osascript","-e",
            'display notification "5-hour limit reset — fresh quota." with title "Claude Usage" sound name "Glass"'],
            timeout=5)
    if five.get("resets_at"):
        try: open(NOTE,"w").write(five["resets_at"])
        except Exception: pass

    burning = fp > ftp + 15
    head = ("🛑 Hold" if fp>=90 else "⚠️ Slow down" if fp>=65 else
            "⚡ Burning fast" if burning else "✅ Plenty left")
    hc = YELLOW if (burning and fp<65) else col(fp)

    print(f"⛁ {fp:.0f}% · {f_cd} | font=Menlo-Bold size=13 color={col(fp)}")
    print("---")
    tag = "" if state=="ok" else ("  · cached" if state=="cached" else "")
    print(f"Claude Usage · {head}{tag} | font=Menlo-Bold size=12 color={hc}")
    print(f"  5h  {make_bar(fp)} | font=Menlo size=12 color={col(fp)}")
    print(f"  ⏱   {make_bar(ftp)} | font=Menlo size=12 color={BLUE}")
    print(f"  Resets {f_cd} · {f_at} | font=Menlo size=11 color={DIM}")
    print(f"  7d  {make_bar(wp)} | font=Menlo size=12 color={col(wp)}")
    print(f"  ⏱   {make_bar(wtp)} | font=Menlo size=12 color={BLUE}")
    print(f"  Resets {w_cd} · {w_at} | font=Menlo size=11 color={DIM}")
    if scoped:
        print("---")
        print(f"Weekly by model | font=Menlo size=11 color={DIM}")
        for nm,p in sorted(scoped, key=lambda x:-x[1]):
            print(f"  {nm:<8} {make_bar(p)} | font=Menlo size=11 color={col(p)}")
    print("---")
    print(f"Real % from Anthropic · matches /usage | font=Menlo size=11 color={DIM}")
    print(f"Refresh | bash='{SELF}' param1=--force terminal=false refresh=true")
    print(f"Live tokens (Terminal) | bash='{SELF}' param1=--live terminal=true")
    sys.exit(0)

# ================= FALLBACK (ccusage local) =================
try: dd = json.loads(DAILY)
except Exception: dd = {}
msg = {"not_logged_in":"Not logged in — run: claude login",
       "refresh_failed":"Token refresh failed — run: claude login",
       "fetch_failed":"Usage fetch failed (offline?)"}.get(state, "Loading…")
daily = dd.get("daily", [])
def eff_day(d): return d.get("inputTokens",0)+d.get("outputTokens",0)+d.get("cacheCreationTokens",0)
wu = sum(eff_day(d) for d in daily[-7:])
print(f"⛁ local | font=Menlo-Bold size=13 color={DIM}")
print("---")
print(f"{msg} | font=Menlo size=12 color={YELLOW}")
print(f"Showing local estimate (7d eff): {wu/1e6:.1f}M tok | font=Menlo size=11 color={DIM}")
print("---")
print(f"Retry | bash='{SELF}' param1=--force terminal=false refresh=true")
PY
