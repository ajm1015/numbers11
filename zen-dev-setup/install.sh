#!/bin/bash
set -e

# ============================================================================
# Zen Development Environment Installer
# For macOS with Cursor Pro, Claude Pro, Claude Code, and Local Models
# ============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES="$SCRIPT_DIR"

echo ""
echo "╔══════════════════════════════════════════════════════════════════════╗"
echo "║           🧘 Zen Development Environment Setup                        ║"
echo "╚══════════════════════════════════════════════════════════════════════╝"
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[OK]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Check for macOS
if [[ "$(uname)" != "Darwin" ]]; then
    log_error "This script is designed for macOS only."
    exit 1
fi

# Check for Homebrew
if ! command -v brew &> /dev/null; then
    log_info "Installing Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    
    # Add Homebrew to PATH for Apple Silicon
    if [[ -f "/opt/homebrew/bin/brew" ]]; then
        eval "$(/opt/homebrew/bin/brew shellenv)"
    fi
fi

log_success "Homebrew ready"

# ============================================================================
# Install Core Packages
# ============================================================================
log_info "Installing packages via Homebrew..."

brew bundle --file=- <<EOF
# Core CLI Tools
brew "jq"                    # JSON processing
brew "ripgrep"               # Fast search
brew "fd"                    # Fast find
brew "fzf"                   # Fuzzy finder
brew "eza"                   # Modern ls
brew "bat"                   # Better cat
brew "delta"                 # Better git diff
brew "zoxide"                # Smart cd
brew "starship"              # Prompt

# AI Infrastructure
brew "ollama"                # Local LLM runtime
brew "python@3.11"           # For AI router

# Node (for Claude Code)
brew "node@20"

# Terminal
cask "ghostty"

# Editor
cask "cursor"

# Productivity
cask "raycast"

# Fonts (no tap needed, fonts are in homebrew/cask now)
cask "font-jetbrains-mono"
cask "font-jetbrains-mono-nerd-font"
EOF

log_success "Packages installed"

# ============================================================================
# Install Claude Code
# ============================================================================
log_info "Installing Claude Code..."

if ! command -v claude &> /dev/null; then
    npm install -g @anthropic-ai/claude-code
    log_success "Claude Code installed"
else
    log_success "Claude Code already installed"
fi

# ============================================================================
# Python Dependencies for AI Router
# ============================================================================
log_info "Installing Python dependencies..."
pip3 install --break-system-packages fastapi uvicorn httpx 2>/dev/null || \
    pip3 install fastapi uvicorn httpx
log_success "Python dependencies installed"

# ============================================================================
# Create Directory Structure
# ============================================================================
log_info "Creating directory structure..."

mkdir -p ~/.config/ghostty
mkdir -p ~/.config/starship
mkdir -p ~/.local/bin
mkdir -p ~/.claude
mkdir -p ~/Library/LaunchAgents

# Cursor settings directory (macOS)
CURSOR_USER_DIR="$HOME/Library/Application Support/Cursor/User"
mkdir -p "$CURSOR_USER_DIR"

log_success "Directories created"

# ============================================================================
# Symlink Configuration Files
# ============================================================================
log_info "Linking configuration files..."

# Ghostty
ln -sf "$DOTFILES/ghostty/config" ~/.config/ghostty/config

# Starship prompt
ln -sf "$DOTFILES/shell/starship.toml" ~/.config/starship.toml

# Cursor
ln -sf "$DOTFILES/cursor/settings.json" "$CURSOR_USER_DIR/settings.json"
ln -sf "$DOTFILES/cursor/keybindings.json" "$CURSOR_USER_DIR/keybindings.json"

# Claude Code
ln -sf "$DOTFILES/claude-code/settings.json" ~/.claude/settings.json

# Shell
ln -sf "$DOTFILES/shell/.zshrc" ~/.zshrc
ln -sf "$DOTFILES/shell/.zprofile" ~/.zprofile

# AI Router
ln -sf "$DOTFILES/ai/ai-router.py" ~/.local/bin/ai-router
chmod +x ~/.local/bin/ai-router

# Bin scripts
for script in "$DOTFILES/bin/"*; do
    if [[ -f "$script" ]]; then
        script_name=$(basename "$script")
        ln -sf "$script" ~/.local/bin/"$script_name"
        chmod +x ~/.local/bin/"$script_name"
    fi
done

log_success "Configuration files linked"

# ============================================================================
# Setup LaunchAgent for AI Router
# ============================================================================
log_info "Setting up AI Router service..."

# Update username in plist
sed "s|YOUR_USERNAME|$USER|g" "$DOTFILES/ai/com.local.ai-router.plist" > ~/Library/LaunchAgents/com.local.ai-router.plist

log_success "AI Router service configured"

# ============================================================================
# Apply macOS Defaults
# ============================================================================
log_info "Applying macOS preferences..."
bash "$DOTFILES/macos/defaults.sh"
log_success "macOS preferences applied"

# ============================================================================
# Start Services
# ============================================================================
log_info "Starting services..."

# Ollama
brew services start ollama 2>/dev/null || true
sleep 2  # Give Ollama time to start

log_success "Ollama service started"

# ============================================================================
# Pull Ollama Models
# ============================================================================
echo ""
log_info "Pulling AI models (this may take a while)..."
echo "    These are optimized for your workflow:"
echo "    - deepseek-coder-v2:16b (fast autocomplete)"
echo "    - qwen2.5-coder:32b (strong local reasoning)"
echo ""

read -p "Pull models now? [y/N] " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    ollama pull deepseek-coder-v2:16b
    ollama pull qwen2.5-coder:32b
    log_success "Models pulled"
else
    log_warn "Skipped model pull. Run manually later:"
    echo "    ollama pull deepseek-coder-v2:16b"
    echo "    ollama pull qwen2.5-coder:32b"
fi

# ============================================================================
# Final Setup Instructions
# ============================================================================
echo ""
echo "╔══════════════════════════════════════════════════════════════════════╗"
echo "║                    ✅ Installation Complete!                          ║"
echo "╚══════════════════════════════════════════════════════════════════════╝"
echo ""
echo "Required manual steps:"
echo ""
echo "  1. Set your Anthropic API key for the AI router:"
echo "     Edit: ~/Library/LaunchAgents/com.local.ai-router.plist"
echo "     Replace YOUR_ANTHROPIC_API_KEY with your actual key"
echo "     Then run: launchctl load ~/Library/LaunchAgents/com.local.ai-router.plist"
echo ""
echo "  2. Authenticate Claude Code:"
echo "     Run: claude login"
echo ""
echo "  3. Import Raycast scripts:"
echo "     Open Raycast → Extensions → Script Commands → Add Script Directory"
echo "     Select: $DOTFILES/raycast/scripts"
echo ""
echo "  4. Restart your terminal or run:"
echo "     source ~/.zshrc"
echo ""
echo "  5. Log out and back in for all macOS changes to take effect"
echo ""
echo "Quick commands now available:"
echo "  cc          - Start Claude Code"
echo "  ccc         - Continue last Claude Code session"
echo "  zen         - Toggle focus mode"
echo "  ai          - Query local AI"
echo ""
