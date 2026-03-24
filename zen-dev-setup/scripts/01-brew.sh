#!/bin/bash
# Install all packages from Brewfile

source "$(dirname "$0")/lib.sh"

log_info "Installing packages from Brewfile..."

brew bundle install --file="$REPO_ROOT/Brewfile" --no-lock

log_success "Packages installed"
