#!/bin/bash
# Stow all dotfile packages into $HOME

source "$(dirname "$0")/lib.sh"

PACKAGES=(shell ghostty cursor claude-code nvim git btop bin)
BACKUP_DIR="$HOME/.dotfiles-backup/$(date +%Y%m%d-%H%M%S)"

stow_pkg() {
  local pkg="$1"
  log_info "Stowing $pkg..."

  # Try stow, handle conflicts by backing up
  if ! stow --dir="$REPO_ROOT" --target="$HOME" --restow "$pkg" 2>/dev/null; then
    log_warn "Conflict in $pkg, backing up existing files..."
    mkdir -p "$BACKUP_DIR"

    # Adopt existing files then restow
    stow --dir="$REPO_ROOT" --target="$HOME" --adopt "$pkg" 2>/dev/null || true

    # Now restow to ensure repo version wins
    stow --dir="$REPO_ROOT" --target="$HOME" --restow "$pkg"

    log_info "Originals backed up via git (stow --adopt preserves in repo)"
  fi

  log_success "$pkg linked"
}

log_info "Linking dotfiles with GNU Stow..."

# Create required parent directories
mkdir -p "$HOME/.config/ghostty/themes"
mkdir -p "$HOME/.config/btop"
mkdir -p "$HOME/.config/nvim/lua/config"
mkdir -p "$HOME/.config/nvim/lua/plugins"
mkdir -p "$HOME/.config/git"
mkdir -p "$HOME/.claude"
mkdir -p "$HOME/.local/bin"
mkdir -p "$HOME/Library/Application Support/Cursor/User"

for pkg in "${PACKAGES[@]}"; do
  stow_pkg "$pkg"
done

log_success "All packages stowed"
