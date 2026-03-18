# BrewManager

A native macOS app for managing Homebrew packages — install, uninstall, upgrade, search, and version-control your entire package list from a single UI.

![macOS 14+](https://img.shields.io/badge/macOS-14%2B-blue) ![Swift 5.9](https://img.shields.io/badge/Swift-5.9-orange) ![License](https://img.shields.io/badge/license-MIT-green)

## Features

- **Package management** — Install, uninstall, upgrade, pin/unpin formulae and casks
- **Search** — Find packages via the Homebrew API with debounced search
- **Version history** — Every change auto-commits to a local git repo (`~/.brew-manager/`), with diff viewer and one-click restore
- **Brewfile import/export** — Import existing Brewfiles or export your current system state
- **6 color themes** — Midnight, Nord, Synthwave, Dracula, Solarized, Monochrome
- **Keyboard shortcuts** — Cmd+R refresh, Cmd+Shift+E export, Cmd+Shift+I import, Cmd+/- zoom

## Requirements

- **macOS 14.0** (Sonoma) or later
- **Homebrew** installed ([brew.sh](https://brew.sh))
- **Xcode 15+** or Xcode Command Line Tools (for building from source)

## Install from DMG

1. Download the latest `.dmg` from [Releases](../../releases)
2. Open the DMG and drag **BrewManager** to Applications
3. First launch: **Right-click > Open** (required for ad-hoc signed apps — macOS Gatekeeper blocks unsigned double-click)

## Build from Source

```bash
# Clone
git clone https://github.com/ajm1015/GitHub.git
cd GitHub/brew-manager

# Build and run (debug)
make run

# Or build release binary only
make build
```

### Build .app Bundle + DMG

```bash
make package
```

This produces:
- `dist/BrewManager.app` — Ad-hoc signed application bundle
- `dist/BrewManager-0.1.0.dmg` — Distributable disk image with Applications symlink

### Run Tests

```bash
make test
```

Runs 52 unit tests covering JSON decoding, Brewfile parsing, model behavior, and input validation.

## How It Works

BrewManager wraps the `brew` CLI — it calls `brew install`, `brew info --json=v2`, `brew outdated`, etc. under the hood. Your Homebrew installation does all the real work; BrewManager provides the UI and version tracking.

Every install/uninstall/upgrade automatically snapshots your Brewfile to a local git repo at `~/.brew-manager/`. You can browse the full history, view diffs, and restore any previous state from the Version History tab.

## Project Structure

```
Sources/BrewManager/
  App.swift              # Entry point, menus, window management
  Models/                # BrewPackage, BrewfileEntry, VersionEntry
  Services/              # BrewService (CLI), BrewAPIService (HTTP), GitService (versioning)
  ViewModels/            # PackageList, Search, VersionHistory state management
  Views/                 # SwiftUI views — list, detail, search, history, themes
  Utilities/             # ProcessRunner (subprocess), BrewfileParser, Theme system
```

## License

MIT
