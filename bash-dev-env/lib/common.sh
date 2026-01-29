#!/usr/bin/env bash
# Shared bash library — source from scripts: source "$(dirname "$0")/../lib/common.sh"

set -euo pipefail

# --- Logging ---
log_info() { printf '\033[0;36m[INFO]\033[0m %s\n' "$*" >&2; }
log_warn() { printf '\033[0;33m[WARN]\033[0m %s\n' "$*" >&2; }
log_err() { printf '\033[0;31m[ERROR]\033[0m %s\n' "$*" >&2; }

# --- Script root (repo root when run from scripts/) ---
SCRIPT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")/.." && pwd)"
export SCRIPT_ROOT

# --- Safe exit ---
abort() {
  log_err "$*"
  exit 1
}
