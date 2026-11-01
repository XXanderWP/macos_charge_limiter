#!/bin/bash
# Installs macOS Charge Limiter.
# Usage: ./install.sh [--limit N] [--build] [--no-app]
#   --limit N   initial charge limit, 50-95 (default 80)
#   --build     build the menu bar app from source instead of downloading the release
#   --no-app    only install the daemon and terminal commands
# One-line install (downloads the latest version from GitHub):
#   bash -c "$(curl -fsSL https://raw.githubusercontent.com/XXanderWP/macos_charge_limiter/main/install.sh)"
set -euo pipefail

TARBALL="${CHARGE_LIMITER_TARBALL:-https://github.com/XXanderWP/macos_charge_limiter/archive/refs/heads/main.tar.gz}"

# Run through curl: no repo next to the script, so fetch it and re-run from there
SCRIPT_DIR=""
[[ -f "${BASH_SOURCE[0]:-}" ]] && SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
if [[ ! -f "$SCRIPT_DIR/src/charge-limit-daemon" ]]; then
  tmp=$(mktemp -d)
  trap 'rm -rf "$tmp"' EXIT
  echo "==> Downloading macOS Charge Limiter"
  curl -fsSL "$TARBALL" | tar -xz -C "$tmp" --strip-components 1
  bash "$tmp/install.sh" "$@"
  exit $?
fi
cd "$SCRIPT_DIR"

BIN=/usr/local/bin
CONFIG_DIR="$HOME/.charge-limit"
LABEL=io.github.xxanderwp.charge-limiter
PLIST=/Library/LaunchDaemons/$LABEL.plist
LEGACY_PLIST=/Library/LaunchDaemons/local.charge-limit.plist
SMC_APP=/Applications/smcFanControl.app/Contents/Resources/smc
APP=/Applications/ChargeLimiter.app
APP_LABEL=io.github.xxanderwp.charge-limiter.app
AGENT="$HOME/Library/LaunchAgents/$APP_LABEL.plist"
RELEASE_ZIP=https://github.com/XXanderWP/macos_charge_limiter/releases/latest/download/ChargeLimiter.zip

WITH_APP=1
BUILD=0
LIMIT=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --limit) LIMIT="${2:-}"; shift ;;
    --build) BUILD=1 ;;
    --no-app) WITH_APP=0 ;;
    --swiftbar) ;;  # obsolete, the menu bar app replaced the SwiftBar plugin
    -h|--help) sed -n '2,8p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
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

# Leftovers of the SwiftBar plugin from older versions
swiftbar_dir=$(defaults read com.ameba.SwiftBar PluginDirectory 2>/dev/null || echo "$HOME/.swiftbar")
rm -f "${swiftbar_dir/#\~/$HOME}"/charge-limit*.sh

if [[ $WITH_APP -eq 1 ]]; then
  step "Installing menu bar app"
  stage=$(mktemp -d)
  if [[ $BUILD -eq 0 ]] && curl -fsSL -o "$stage/app.zip" "$RELEASE_ZIP" 2>/dev/null; then
    ditto -x -k "$stage/app.zip" "$stage"
    echo "Downloaded the latest release."
  else
    [[ $BUILD -eq 1 ]] || echo "No release available, building from source."
    version=$(git describe --tags --always 2>/dev/null || echo dev)
    app/build.sh "${version#v}" "$stage"
  fi
  [[ -d "$stage/ChargeLimiter.app" ]] || die "App bundle not found after download/build."

  pkill -x ChargeLimiter 2>/dev/null || true
  if [[ -w /Applications ]]; then
    rm -rf "$APP" && ditto "$stage/ChargeLimiter.app" "$APP"
  else
    sudo rm -rf "$APP" && sudo ditto "$stage/ChargeLimiter.app" "$APP"
  fi
  rm -rf "$stage"
  # Builds are ad-hoc signed; drop the quarantine flag in case the zip came through a browser
  xattr -dr com.apple.quarantine "$APP" 2>/dev/null || true

  # Start at login
  mkdir -p "$(dirname "$AGENT")"
  sed -e "s|@LABEL@|$APP_LABEL|g" -e "s|@APP@|$APP|g" src/charge-limiter-app.plist > "$AGENT"
  launchctl bootout "gui/$UID" "$AGENT" 2>/dev/null || true
  launchctl bootstrap "gui/$UID" "$AGENT"
  echo "Charge Limiter is in the menu bar and starts at login."
fi

sleep 2
step "Status"
"$BIN/charge-limit-status"
echo
echo "Done. Commands: charge-limit-on [N], charge-limit-off, charge-limit-discharge on|off, charge-limit-status"
