# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Is

A macOS dotfiles repo using GNU Stow to manage dev environment configs: Ghostty terminal, Cursor editor, Zsh + Starship shell, Neovim, and Claude Code. Everything is symlinked from this repo into `$HOME` via `stow`.

## Architecture

**Stow-based dotfiles**: Each top-level directory is a stow package whose contents mirror `$HOME`. Running `stow --target=$HOME <package>` creates the symlinks. Editing files here directly changes the live environment.

**Stow packages**: `shell`, `ghostty`, `cursor`, `claude-code`, `nvim`, `git`, `btop`, `bin`

**Installer**: `install.sh` is a thin orchestrator that calls modular scripts in `scripts/`:
- `00-preflight.sh` — macOS check, Homebrew, Stow
- `01-brew.sh` — `brew bundle install` from `Brewfile`
- `02-stow.sh` — stow all packages with conflict handling
- `03-macos.sh` — system preferences via `macos/defaults.sh`
- `04-verify.sh` — health check (also available as `zen-doctor`)

Shared functions live in `scripts/lib.sh`.

## Symlink Map

| Package | Source | Target |
|---------|--------|--------|
| shell | `shell/.zshrc` | `~/.zshrc` |
| shell | `shell/.config/starship.toml` | `~/.config/starship.toml` |
| ghostty | `ghostty/.config/ghostty/config` | `~/.config/ghostty/config` |
| cursor | `cursor/Library/Application Support/Cursor/User/settings.json` | Same under `~/` |
| claude-code | `claude-code/.claude/settings.json` | `~/.claude/settings.json` |
| nvim | `nvim/.config/nvim/` | `~/.config/nvim/` |
| git | `git/.gitconfig` | `~/.gitconfig` |
| btop | `btop/.config/btop/btop.conf` | `~/.config/btop/btop.conf` |
| bin | `bin/.local/bin/*` | `~/.local/bin/*` |

## Commands

| Task | Command |
|------|---------|
| Full install | `./install.sh` |
| Install without macOS defaults | `./install.sh --skip-macos` |
| Re-stow a package | `stow --dir=. --target=$HOME --restow <package>` |
| Health check | `zen-doctor` or `bash scripts/04-verify.sh` |
| Check Brewfile | `brew bundle check --file=Brewfile` |

No test suite or build system — this is a configuration repo.

## Conventions

- **Bash scripts**: `set -euo pipefail`, shared logging via `scripts/lib.sh`
- **Stow packages**: directory contents must mirror the target path relative to `$HOME`
- **Theme**: Catppuccin Mocha everywhere (Ghostty, Cursor, Starship, Neovim, FZF)
- **Font**: JetBrains Mono / JetBrains Mono Nerd Font
- **Packages**: managed in `Brewfile` at repo root, annotated by category
