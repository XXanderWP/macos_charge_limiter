#!/bin/bash
# Removes macOS Charge Limiter and restores normal charging.
# Usage: ./uninstall.sh [--keep-config]
set -euo pipefail

BIN=/usr/local/bin
CONFIG_DIR="$HOME/.charge-limit"
LABEL=io.github.xxanderwp.charge-limiter
KEEP_CONFIG=0
[[ "${1:-}" == "--keep-config" ]] && KEEP_CONFIG=1

[[ $EUID -ne 0 ]] || { echo "Run as your normal user, not with sudo." >&2; exit 1; }

for plist in /Library/LaunchDaemons/$LABEL.plist /Library/LaunchDaemons/local.charge-limit.plist; do
  if [[ -f "$plist" ]]; then
    sudo launchctl bootout system "$plist" 2>/dev/null || true
    sudo rm -f "$plist"
  fi
done

# Restore normal charging before removing smc
if [[ -x "$BIN/smc" ]]; then
  sudo "$BIN/smc" -k CHTE -w 00000000
  sudo "$BIN/smc" -k CHIE -w 00
fi

sudo rm -f "$BIN"/charge-limit-{daemon,on,off,status,discharge} "$BIN/smc" /var/run/charge-limit.max

# Menu bar app
APP_AGENT="$HOME/Library/LaunchAgents/io.github.xxanderwp.charge-limiter.app.plist"
launchctl bootout "gui/$UID" "$APP_AGENT" 2>/dev/null || true
rm -f "$APP_AGENT"
pkill -x ChargeLimiter 2>/dev/null || true
if [[ -d /Applications/ChargeLimiter.app ]]; then
  rm -rf /Applications/ChargeLimiter.app 2>/dev/null || sudo rm -rf /Applications/ChargeLimiter.app
fi

# SwiftBar plugin from older versions
plugin_dir=$(defaults read com.ameba.SwiftBar PluginDirectory 2>/dev/null || echo "$HOME/.swiftbar")
rm -f "${plugin_dir/#\~/$HOME}"/charge-limit*.sh

[[ $KEEP_CONFIG -eq 1 ]] || rm -rf "$CONFIG_DIR"

echo "Charge limiter removed, charging restored to normal."
echo "smcFanControl was left installed; remove it with: brew uninstall --cask smcfancontrol"
