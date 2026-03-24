#!/bin/bash
# Verify installation health — also available as `zen-doctor`

source "$(dirname "$0")/lib.sh"

PASS=0
FAIL=0

check() {
  local desc="$1"
  shift
  if "$@" &>/dev/null; then
    log_success "$desc"
    ((PASS++)) || true
  else
    log_error "$desc"
    ((FAIL++)) || true
  fi
}

check_link() {
  local desc="$1"
  local path="$2"
  if [[ -L "$path" ]]; then
    log_success "$desc"
    ((PASS++)) || true
  else
    log_error "$desc (not a symlink)"
    ((FAIL++)) || true
  fi
}

echo ""
echo "Zen Doctor — Environment Health Check"
echo "======================================"
echo ""

# Symlinks
echo "Symlinks:"
check_link "  ~/.zshrc"                              "$HOME/.zshrc"
check_link "  ~/.zprofile"                           "$HOME/.zprofile"
check_link "  ~/.config/starship.toml"               "$HOME/.config/starship.toml"
check_link "  ~/.config/ghostty/config"              "$HOME/.config/ghostty/config"
check_link "  ~/.config/nvim/init.lua"               "$HOME/.config/nvim/init.lua"
check_link "  ~/.gitconfig"                          "$HOME/.gitconfig"
check_link "  ~/.config/btop/btop.conf"              "$HOME/.config/btop/btop.conf"
check_link "  ~/.claude/settings.json"               "$HOME/.claude/settings.json"
check_link "  ~/.local/bin/zen"                      "$HOME/.local/bin/zen"

echo ""
echo "Tools on PATH:"
check "  starship" command -v starship
check "  zoxide"   command -v zoxide
check "  eza"      command -v eza
check "  bat"      command -v bat
check "  fd"       command -v fd
check "  rg"       command -v rg
check "  fzf"      command -v fzf
check "  jq"       command -v jq
check "  stow"     command -v stow
check "  nvim"     command -v nvim
check "  claude"   command -v claude
check "  node"     command -v node

echo ""
echo "Brewfile:"
check "  All packages satisfied" brew bundle check --file="$REPO_ROOT/Brewfile"

echo ""
echo "Git config:"
check "  user.name set"  git config --global user.name
check "  user.email set" git config --global user.email

echo ""
echo "======================================"
echo "Results: $PASS passed, $FAIL failed"

if [[ $FAIL -gt 0 ]]; then
  exit 1
fi
