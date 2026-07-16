#!/bin/bash
# Claude Usage (local) — uninstaller
PLUGIN_NAME="claude-ccusage.1m.sh"
DEFAULT_DIR="$HOME/Library/Application Support/SwiftBar/Plugins"

PLUGIN_DIR="$(defaults read com.ameba.SwiftBar PluginDirectory 2>/dev/null || true)"
[ -z "$PLUGIN_DIR" ] && PLUGIN_DIR="$DEFAULT_DIR"

rm -f "$PLUGIN_DIR/$PLUGIN_NAME" && echo "[✓] Removed plugin"
rm -rf "$HOME/.claude-usage-bar/last_block_id" 2>/dev/null

open "swiftbar://refreshallplugins" 2>/dev/null || true
echo "[✓] Uninstalled. (SwiftBar, node, ccusage left installed — remove manually if desired.)"
