# macOS Charge Limiter

Limit the maximum battery charge on Apple Silicon MacBooks (for example to 80%) to slow down battery wear. Optionally discharge down to the limit while the adapter is still plugged in. Comes with terminal commands and an optional [SwiftBar](https://github.com/swiftbar/SwiftBar) menu bar plugin.

No kernel extensions, no background app — just a tiny shell script run by `launchd`.

## Why another one?

On older firmware Apple Silicon Macs exposed a native 80% limit through the `CHWA` SMC key ([this gist](https://gist.github.com/geokal/b0a9c53f94e8751f7a911834e3b85382) describes it). Since macOS 15 the key is gone. This project uses the keys that still exist:

| SMC key | Value | Effect |
|---|---|---|
| `CHTE` | `01000000` / `00000000` | pause / allow charging |
| `CHIE` | `08` / `00` | run from battery with adapter attached / normal |

A root launch daemon checks the battery every 60 seconds (and right away when you change a setting). It pauses charging at the limit and resumes it 5% below.

## Requirements

- Apple Silicon Mac (tested on M1 MacBook Air, macOS 26.2)
- [Homebrew](https://brew.sh) (used to get `smc` from smcFanControl, and SwiftBar)
- Rosetta 2 (the `smc` binary is x86_64): `softwareupdate --install-rosetta --agree-to-license`
- An admin account (install asks for your password)

## Install

One line, with the menu bar plugin:

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/XXanderWP/macos_charge_limiter/main/install.sh)" -- --swiftbar
```

Without the plugin, drop `-- --swiftbar`. The script downloads the latest version of the repository to a temporary folder, installs it and cleans up.

Or from a clone:

```bash
git clone https://github.com/XXanderWP/macos_charge_limiter.git
cd macos_charge_limiter
./install.sh --swiftbar
```

Options:

- `--swiftbar` also installs SwiftBar and the menu bar plugin
- `--limit N` sets the initial limit (50–95, default 80)

The limit is enabled right after install and survives reboots. If you use the menu bar plugin, turn on **Launch at Login** in SwiftBar preferences (or add SwiftBar in System Settings → General → Login Items).

To update, run the one-line command again (or `git pull && ./install.sh`). Your settings are kept.

## Usage

### Terminal

```bash
charge-limit-on            # enable the limit (last used value, 80% by default)
charge-limit-on 85         # enable and set the limit to 85%
charge-limit-off           # disable, charge to 100%
charge-limit-discharge on  # discharge to the limit even when plugged in
charge-limit-discharge off
charge-limit-status
```

None of these need `sudo`.

### Menu bar (SwiftBar)

| Icon | Meaning |
|---|---|
| leaf | limit on |
| bolt | limit off |
| down arrow | discharging to the limit |

The menu shows the current state, an on/off toggle, a **Charge limit** submenu (50–95%) and a **Discharge to limit** toggle.

The menu is available in English, Russian and Ukrainian. It uses the first supported language from your system language list (System Settings → General → Language & Region) and falls back to English. To force a language:

```bash
echo uk > ~/.charge-limit/lang   # en, ru or uk
rm ~/.charge-limit/lang          # back to the system language
```

## How it works

```
~/.charge-limit/
├── on          # present = limit enabled
├── max         # limit in percent (default 80)
├── discharge   # present = discharge down to the limit
└── lang        # optional menu language override
```

| Path | What |
|---|---|
| `/usr/local/bin/smc` | SMC tool from smcFanControl |
| `/usr/local/bin/charge-limit-*` | daemon and commands |
| `/Library/LaunchDaemons/io.github.xxanderwp.charge-limiter.plist` | launchd job (root) |
| `~/.swiftbar/charge-limit.30s.sh` | menu bar plugin |

The commands only create or delete files in `~/.charge-limit`. The daemon watches this folder, runs as root and writes the SMC keys.

## Limitations

- **Sleep.** The daemon can't run while the Mac sleeps. If you plug in a sleeping Mac it may charge past the limit; charging stops again after it wakes. Likewise, discharging that started before sleep can continue below the limit until wake.
- **Lowering the limit** without *Discharge to limit* doesn't drain the battery: the Mac just runs from the adapter at the current level.
- **macOS Optimized Battery Charging** can interfere. Consider turning it off in System Settings → Battery → Battery Health.
- The SMC keys are undocumented and Apple may change them in a future firmware. The installer checks for `CHTE` and refuses to install if it's missing.

## Uninstall

```bash
./uninstall.sh                # add --keep-config to keep ~/.charge-limit
```

This removes the daemon, commands and plugin and restores normal charging. SwiftBar and smcFanControl stay installed. Remove them with `brew uninstall --cask swiftbar smcfancontrol`.

## Credits

- [geokal's gist](https://gist.github.com/geokal/b0a9c53f94e8751f7a911834e3b85382) for the original `CHWA` approach
- [actuallymentor/battery](https://github.com/actuallymentor/battery) for documenting `CHTE` / `CHIE`
- [smcFanControl](https://github.com/hholtmann/smcFanControl) for `smc`
- [SwiftBar](https://github.com/swiftbar/SwiftBar)

## License

[MIT](LICENSE)
