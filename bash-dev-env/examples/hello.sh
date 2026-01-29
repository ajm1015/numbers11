#!/usr/bin/env bash
# Example script — sources lib, logs, then exits.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../lib/common.sh"

main() {
  log_info "Starting hello example"
  echo "Hello, bash dev environment!"
  log_info "Done"
}

main "$@"
