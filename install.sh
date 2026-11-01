#!/bin/bash
# Installs macOS Charge Limiter.
# Usage: ./install.sh [--swiftbar] [--limit N]
#   --swiftbar  also install SwiftBar (via Homebrew) and the menu bar plugin
#   --limit N   initial charge limit, 50-95 (default 80)
set -euo pipefail

cd "$(dirname "$0")"

BIN=/usr/local/bin
CONFIG_DIR="$HOME/.charge-limit"
LABEL=io.github.xxanderwp.charge-limiter
PLIST=/Library/LaunchDaemons/$LABEL.plist
LEGACY_PLIST=/Library/LaunchDaemons/local.charge-limit.plist
SMC_APP=/Applications/smcFanControl.app/Contents/Resources/smc
SWIFTBAR_DIR="$HOME/.swiftbar"

WITH_SWIFTBAR=0
LIMIT=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --swiftbar) WITH_SWIFTBAR=1 ;;
    --limit) LIMIT="${2:-}"; shift ;;
    -h|--help) sed -n '2,5p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
  shift
done

step() { printf '\n==> %s\n' "$*"; }
die() { printf 'Error: %s\n' "$*" >&2; exit 1; }

[[ "$(uname)" == "Darwin" ]] || die "macOS only."
[[ "$(uname -m)" == "arm64" ]] || die "Apple Silicon Mac required."
[[ $EUID -ne 0 ]] || die "Run as your normal user, not with sudo (it will ask for the password)."
if [[ -n "$LIMIT" ]]; then
  [[ "$LIMIT" =~ ^[0-9]+$ ]] && (( LIMIT >= 50 && LIMIT <= 95 )) || die "--limit must be 50-95."
fi

# smc ships as an x86_64 binary and needs Rosetta
if ! arch -x86_64 /usr/bin/true 2>/dev/null; then
  die "Rosetta 2 is required for smc. Install it with: softwareupdate --install-rosetta --agree-to-license"
fi

step "Getting smc"
if [[ ! -x "$SMC_APP" ]]; then
  command -v brew >/dev/null || die "Homebrew not found. Install smcFanControl manually or install Homebrew first."
  brew install --cask smcfancontrol
fi
"$SMC_APP" -k CHTE -r | grep -q bytes || die "This Mac has no CHTE SMC key, charge control is not supported."

step "Installing files to $BIN (sudo)"
sudo mkdir -p "$BIN"
sudo install -m 755 "$SMC_APP" "$BIN/smc"
for f in charge-limit-daemon charge-limit-on charge-limit-off charge-limit-status charge-limit-discharge; do
  sed -e "s|@BIN@|$BIN|g" -e "s|@CONFIG_DIR@|$CONFIG_DIR|g" "src/$f" | sudo tee "$BIN/$f" >/dev/null
  sudo chmod 755 "$BIN/$f"
done

step "Installing launch daemon"
mkdir -p "$CONFIG_DIR"
if [[ -f "$LEGACY_PLIST" ]]; then
  sudo launchctl bootout system "$LEGACY_PLIST" 2>/dev/null || true
  sudo rm -f "$LEGACY_PLIST"
fi
sed -e "s|@BIN@|$BIN|g" -e "s|@CONFIG_DIR@|$CONFIG_DIR|g" -e "s|@LABEL@|$LABEL|g" \
  src/charge-limiter.plist | sudo tee "$PLIST" >/dev/null
sudo chown root:wheel "$PLIST"
sudo chmod 644 "$PLIST"
sudo launchctl bootout system "$PLIST" 2>/dev/null || true
sudo launchctl bootstrap system "$PLIST"

step "Enabling limit"
if [[ -n "$LIMIT" ]]; then
  "$BIN/charge-limit-on" "$LIMIT"
else
  "$BIN/charge-limit-on"
fi

if [[ $WITH_SWIFTBAR -eq 1 ]]; then
  step "Installing SwiftBar plugin"
  if [[ ! -d /Applications/SwiftBar.app ]]; then
    command -v brew >/dev/null || die "Homebrew not found, install SwiftBar manually."
    brew install --cask swiftbar
  fi
  current=$(defaults read com.ameba.SwiftBar PluginDirectory 2>/dev/null || true)
  if [[ -n "$current" ]]; then
    SWIFTBAR_DIR="${current/#\~/$HOME}"
  else
    defaults write com.ameba.SwiftBar PluginDirectory "$SWIFTBAR_DIR"
  fi
  mkdir -p "$SWIFTBAR_DIR"
  install -m 755 swiftbar/charge-limit.30s.sh "$SWIFTBAR_DIR/"
  open -g -a SwiftBar
  open -g "swiftbar://refreshallplugins" 2>/dev/null || true
  echo "Plugin installed to $SWIFTBAR_DIR. Enable 'Launch at Login' in SwiftBar preferences."
fi

sleep 2
step "Status"
"$BIN/charge-limit-status"
echo
echo "Done. Commands: charge-limit-on [N], charge-limit-off, charge-limit-discharge on|off, charge-limit-status"
