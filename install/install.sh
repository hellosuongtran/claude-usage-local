#!/bin/bash
# Claude Usage (local) — installer
# Menu-bar Claude Code usage via SwiftBar + ccusage. 100% local, no API, never rate-limited.
set -e

REPO_RAW="https://raw.githubusercontent.com/hellosuongtran/claude-usage-local/main"
PLUGIN_NAME="claude-ccusage.1m.sh"
DEFAULT_DIR="$HOME/Library/Application Support/SwiftBar/Plugins"

say(){ printf "\033[1;36m[•]\033[0m %s\n" "$1"; }
ok(){  printf "\033[1;32m[✓]\033[0m %s\n" "$1"; }
warn(){ printf "\033[1;33m[!]\033[0m %s\n" "$1"; }

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Claude Usage (local) — install"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

[ "$(uname)" = "Darwin" ] || { echo "macOS only."; exit 1; }

# 1) Homebrew
if ! command -v brew >/dev/null 2>&1; then
  warn "Homebrew not found. Install from https://brew.sh then re-run."; exit 1
fi

# 2) Node
if ! command -v node >/dev/null 2>&1; then
  say "Installing node..."; brew install node
fi
ok "node $(node -v)"

# 3) ccusage (global, via pnpm if present else npm)
if ! command -v ccusage >/dev/null 2>&1 && [ ! -x "$HOME/Library/pnpm/ccusage" ]; then
  say "Installing ccusage..."
  if command -v pnpm >/dev/null 2>&1; then
    export PNPM_HOME="$HOME/Library/pnpm"; mkdir -p "$PNPM_HOME"; export PATH="$PNPM_HOME:$PATH"
    pnpm add -g ccusage
  else
    npm install -g ccusage
  fi
fi
ok "ccusage installed"

# 4) SwiftBar
if [ ! -d "/Applications/SwiftBar.app" ]; then
  say "Installing SwiftBar..."
  brew install --cask swiftbar || brew reinstall --cask swiftbar --force
fi
# guard against broken caskroom (app registered but binary missing)
if [ ! -x "/Applications/SwiftBar.app/Contents/MacOS/SwiftBar" ]; then
  say "Repairing SwiftBar install..."; brew reinstall --cask swiftbar --force
fi
ok "SwiftBar present"

# 5) plugin dir
PLUGIN_DIR="$(defaults read com.ameba.SwiftBar PluginDirectory 2>/dev/null || true)"
[ -z "$PLUGIN_DIR" ] && PLUGIN_DIR="$DEFAULT_DIR"
mkdir -p "$PLUGIN_DIR"
defaults write com.ameba.SwiftBar PluginDirectory "$PLUGIN_DIR" 2>/dev/null || true
ok "Plugin dir: $PLUGIN_DIR"

# 6) install plugin (from local checkout if present, else download)
SRC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." 2>/dev/null && pwd)"
if [ -f "$SRC_DIR/bin/$PLUGIN_NAME" ]; then
  cp "$SRC_DIR/bin/$PLUGIN_NAME" "$PLUGIN_DIR/$PLUGIN_NAME"
else
  curl -fsSL "$REPO_RAW/bin/$PLUGIN_NAME" -o "$PLUGIN_DIR/$PLUGIN_NAME"
fi
chmod +x "$PLUGIN_DIR/$PLUGIN_NAME"
ok "Plugin installed → $PLUGIN_NAME"

# 7) launch at login
if ! osascript -e 'tell application "System Events" to get name of every login item' 2>/dev/null | grep -q SwiftBar; then
  osascript -e 'tell application "System Events" to make login item at end with properties {path:"/Applications/SwiftBar.app", hidden:false}' >/dev/null 2>&1 || true
fi
ok "SwiftBar set to launch at login"

# 8) launch + refresh
open -a SwiftBar 2>/dev/null || true
sleep 1
open "swiftbar://refreshallplugins" 2>/dev/null || true

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
ok "Done. Look at your menu bar → ⛁"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
