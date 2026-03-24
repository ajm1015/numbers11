#!/bin/bash
# Preflight checks: macOS, Homebrew, stow

source "$(dirname "$0")/lib.sh"

log_info "Running preflight checks..."

# Check for macOS
if [[ "$(uname)" != "Darwin" ]]; then
  log_error "This setup is designed for macOS only."
  exit 1
fi
log_success "macOS detected"

# Install Homebrew if missing
if ! command -v brew &>/dev/null; then
  log_info "Installing Homebrew..."
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

  if [[ -f "/opt/homebrew/bin/brew" ]]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
  fi
fi
log_success "Homebrew ready"

# Install stow first (needed for 02-stow.sh)
if ! command -v stow &>/dev/null; then
  log_info "Installing GNU Stow..."
  brew install stow
fi
log_success "GNU Stow ready"

log_success "Preflight complete"
