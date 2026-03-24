#!/bin/bash
set -euo pipefail

# ============================================================================
# Zen Development Environment Installer
# ============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo ""
echo "  Zen Development Environment Setup"
echo "  =================================="
echo ""

# Parse flags
SKIP_MACOS=false
SKIP_VERIFY=false

for arg in "$@"; do
  case "$arg" in
    --skip-macos)  SKIP_MACOS=true ;;
    --skip-verify) SKIP_VERIFY=true ;;
    --help|-h)
      echo "Usage: ./install.sh [--skip-macos] [--skip-verify]"
      echo ""
      echo "  --skip-macos   Skip macOS defaults (Dock, Finder, etc.)"
      echo "  --skip-verify  Skip post-install health check"
      exit 0
      ;;
  esac
done

# Run each step
bash "$SCRIPT_DIR/scripts/00-preflight.sh"
bash "$SCRIPT_DIR/scripts/01-brew.sh"
bash "$SCRIPT_DIR/scripts/02-stow.sh"

if [[ "$SKIP_MACOS" == false ]]; then
  bash "$SCRIPT_DIR/scripts/03-macos.sh"
else
  echo "[SKIP] macOS defaults"
fi

if [[ "$SKIP_VERIFY" == false ]]; then
  bash "$SCRIPT_DIR/scripts/04-verify.sh"
else
  echo "[SKIP] Verification"
fi

echo ""
echo "  Installation complete!"
echo ""
echo "  Next steps:"
echo "    1. Restart your terminal or run: source ~/.zshrc"
echo "    2. Run 'claude login' to authenticate Claude Code"
echo "    3. Import Raycast scripts from: $SCRIPT_DIR/raycast/scripts"
echo "    4. Log out and back in for macOS changes to take effect"
echo ""
echo "  Quick commands:"
echo "    cc          Start Claude Code"
echo "    ccc         Continue last session"
echo "    zen         Toggle focus mode"
echo "    zen-doctor  Check environment health"
echo ""
