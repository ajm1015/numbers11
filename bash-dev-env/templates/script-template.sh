#!/usr/bin/env bash
# Description: <one-line summary>
# Usage: ./script-template.sh [options]

set -euo pipefail

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# source "${SCRIPT_DIR}/../lib/common.sh"

main() {
  # ...
  echo "Hello from $(basename "$0")"
}

main "$@"
