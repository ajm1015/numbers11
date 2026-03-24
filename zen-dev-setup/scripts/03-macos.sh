#!/bin/bash
# Apply macOS system preferences

source "$(dirname "$0")/lib.sh"

log_info "Applying macOS preferences..."

bash "$REPO_ROOT/macos/defaults.sh"

log_success "macOS preferences applied"
