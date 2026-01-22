# Zen Development Environment

A focused, AI-powered development setup for macOS with intelligent model routing between Cursor Pro, Claude Pro, Claude Code, and local LLMs.

## What's Included

### Terminal: Ghostty
- Minimal, GPU-accelerated terminal
- Catppuccin Mocha theme
- Split panes with keyboard shortcuts
- Native macOS integration

### Editor: Cursor
- Zen mode optimized settings
- Minimal UI (no minimap, single tabs, hidden scrollbars)
- AI-first keybindings
- PowerShell/Python/Shell formatting

### AI Infrastructure
- **Claude Code**: CLI-based autonomous coding agent (Opus)
- **AI Router**: Intelligent routing between local and cloud models
- **Ollama**: Local LLM runtime for fast queries

### Shell: Zsh + Starship
- Fast, minimal prompt
- AI workflow aliases (`cc`, `ai`, `gcommit`)
- Modern CLI tools (eza, bat, ripgrep, fd, fzf)
- Zoxide for smart directory navigation

### Productivity
- Raycast scripts for quick AI queries
- Focus mode toggle
- macOS defaults for distraction-free work

## Installation

### Quick Start

```bash
# Clone the repo
git clone https://github.com/YOUR_USERNAME/zen-dev-setup.git ~/.dotfiles
cd ~/.dotfiles

# Run installer
./install.sh
```

### Manual Installation

1. Install Homebrew (if not already installed)
2. Run `./install.sh`
3. Set your Anthropic API key in `~/Library/LaunchAgents/com.local.ai-router.plist`
4. Run `claude login` to authenticate Claude Code
5. Restart your terminal

## Post-Install Setup

### 1. Configure API Key

Edit the LaunchAgent to add your Anthropic API key:

```bash
nano ~/Library/LaunchAgents/com.local.ai-router.plist
# Replace YOUR_ANTHROPIC_API_KEY with your actual key
```

Then load the service:

```bash
launchctl load ~/Library/LaunchAgents/com.local.ai-router.plist
```

### 2. Authenticate Claude Code

` ``bash
claude login
```

# ## 3. Pull AI Models

```bash
ollama pull deepseek-coder-v2:16b  # Fast autocomplete
ollama pull qwen2.5-coder:32b      # Strong local reasoning
```

### 4. Import Raycast Scripts

1. Open Raycast
2. Go to Extensions → Script Commands
3. Click "Add Script Directory"
4. Select `~/.dotfiles/raycast/scripts`

## Usage

### AI Commands

| Command | Description |
|---------|-------------|
| `cc` | Start Claude Code |
| `ccc` | Continue last Claude Code session |
| `ai "question"` | Quick query to local AI |
| `ai-explain` | Explain clipboard content |
| `gcommit` | Generate commit message with AI |

### Focus Mode

```bash
zen  # Toggle focus mode (hides all non-dev apps)
```

### Keyboard Shortcuts (Cursor)

| Shortcut | Action |
|----------|--------|
| `Cmd+K` | AI inline edit |
| `Cmd+L` | AI chat |
| `Cmd+K Z` | Toggle Zen mode |
| `Cmd+B` | Toggle sidebar |
| `Cmd+J` | Toggle terminal |
| `Cmd+P` | Quick file open |
| `Cmd+\` | Split editor |

### Keyboard Shortcuts (Ghostty)

| Shortcut | Action |
|----------|--------|
| `Cmd+D` | Split right |
| `Cmd+Shift+D` | Split down |
| `Cmd+Shift+H/J/K/L` | Navigate splits |
| `Cmd+W` | Close split |
| `Cmd+K` | Clear screen |

## Model Routing Strategy

The AI router automatically selects the best model based on task type:

| Task Type | Model | Rationale |
|-----------|-------|-----------|
| Quick questions | Local (DeepSeek) | Sub-second response |
| Autocomplete | Local (DeepSeek) | Speed critical |
| Explanations | Local (Qwen) | Adequate quality |
| Documentation | Local (Qwen) | Good enough |
| Debugging | Claude | Best reasoning |
| Refactoring | Claude | Architecture understanding |
| Complex generation | Claude | Multi-step tasks |

Override with explicit model:
```bash
# Force local
ai --model local "question"

# Force Claude
ai --model claude "question"
```

## Project Setup

For optimal Claude Code usage, add a `CLAUDE.md` file to each project root:

```bash
cp ~/.dotfiles/templates/CLAUDE.md ./CLAUDE.md
# Then customize for your project
```

## Directory Structure

```
~/.dotfiles/
├── install.sh              # Main installer
├── macos/
│   └── defaults.sh         # macOS preferences
├── ghostty/
│   └── config              # Terminal config
├── cursor/
│   ├── settings.json       # Editor settings
│   └── keybindings.json    # Keyboard shortcuts
├── claude-code/
│   └── settings.json       # Claude Code settings
├── shell/
│   ├── .zshrc              # Shell configuration
│   ├── .zprofile           # Login shell config
│   └── starship.toml       # Prompt config
├── ai/
│   ├── ai-router.py        # Model routing service
│   └── com.local.ai-router.plist  # LaunchAgent
├── raycast/
│   └── scripts/            # Raycast commands
├── bin/
│   └── zen                 # Focus mode toggle
└── templates/
    └── CLAUDE.md           # Project template
```

## Replicating to New Macs

1. Clone dotfiles repo
2. Run `./install.sh`
3. Add API key to LaunchAgent
4. Run `claude login`
5. Log out and back in

## Troubleshooting

### AI Router not responding

```bash
# Check if running
curl http://localhost:8080/health

# Check logs
tail -f /tmp/ai-router.log
tail -f /tmp/ai-router.error.log

# Restart
launchctl unload ~/Library/LaunchAgents/com.local.ai-router.plist
launchctl load ~/Library/LaunchAgents/com.local.ai-router.plist
```

### Ollama not available

```bash
# Start Ollama
brew services start ollama

# Verify
ollama list
```

### Claude Code authentication

```bash
# Re-authenticate
claude logout
claude login
```

## License

MIT
