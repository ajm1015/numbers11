# ============================================================================
# Zen Development Environment - Zsh Configuration
# ============================================================================

# ============================================================================
# PATH Configuration
# ============================================================================

# Homebrew (Apple Silicon)
if [[ -f "/opt/homebrew/bin/brew" ]]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
fi

# Local bin
export PATH="$HOME/.local/bin:$PATH"

# Node global packages
export PATH="$HOME/.npm-global/bin:$PATH"

# ============================================================================
# Environment Variables
# ============================================================================

export EDITOR="cursor"
export VISUAL="cursor"
export PAGER="less"
export LANG="en_US.UTF-8"

# Less configuration
export LESS="-R -F -X"

# FZF configuration
export FZF_DEFAULT_COMMAND='fd --type f --hidden --follow --exclude .git'
export FZF_DEFAULT_OPTS='
    --height 40%
    --layout=reverse
    --border
    --color=bg+:#313244,bg:#1e1e2e,spinner:#f5e0dc,hl:#f38ba8
    --color=fg:#cdd6f4,header:#f38ba8,info:#cba6f7,pointer:#f5e0dc
    --color=marker:#f5e0dc,fg+:#cdd6f4,prompt:#cba6f7,hl+:#f38ba8
'

# ============================================================================
# History Configuration
# ============================================================================

HISTFILE=~/.zsh_history
HISTSIZE=50000
SAVEHIST=50000

setopt EXTENDED_HISTORY          # Write timestamp to history
setopt HIST_EXPIRE_DUPS_FIRST    # Expire duplicates first
setopt HIST_IGNORE_DUPS          # Don't record duplicates
setopt HIST_IGNORE_SPACE         # Don't record commands starting with space
setopt HIST_VERIFY               # Show command before executing from history
setopt SHARE_HISTORY             # Share history between sessions

# ============================================================================
# Shell Options
# ============================================================================

setopt AUTO_CD                   # cd by just typing directory name
setopt AUTO_PUSHD                # Push directories onto stack
setopt PUSHD_IGNORE_DUPS         # Don't push duplicates
setopt CORRECT                   # Command correction
setopt NO_BEEP                   # No beeping

# ============================================================================
# Completion System
# ============================================================================

autoload -Uz compinit
compinit

# Case-insensitive completion
zstyle ':completion:*' matcher-list 'm:{a-z}={A-Z}'

# Menu selection
zstyle ':completion:*' menu select

# Colors in completion
zstyle ':completion:*' list-colors "${(s.:.)LS_COLORS}"

# ============================================================================
# Key Bindings
# ============================================================================

bindkey -e  # Emacs mode

# History search
bindkey '^[[A' history-search-backward
bindkey '^[[B' history-search-forward

# Word navigation
bindkey '^[[1;3C' forward-word      # Alt+Right
bindkey '^[[1;3D' backward-word     # Alt+Left

# ============================================================================
# Prompt - Starship
# ============================================================================

if command -v starship &> /dev/null; then
    eval "$(starship init zsh)"
fi

# ============================================================================
# Tool Integrations
# ============================================================================

# Zoxide (smart cd)
if command -v zoxide &> /dev/null; then
    eval "$(zoxide init zsh)"
fi

# FZF keybindings
if [[ -f ~/.fzf.zsh ]]; then
    source ~/.fzf.zsh
elif [[ -f /opt/homebrew/opt/fzf/shell/key-bindings.zsh ]]; then
    source /opt/homebrew/opt/fzf/shell/key-bindings.zsh
    source /opt/homebrew/opt/fzf/shell/completion.zsh
fi

# ============================================================================
# Aliases - Core
# ============================================================================

# Modern replacements
alias ls='eza --icons'
alias ll='eza -la --icons --git'
alias la='eza -a --icons'
alias lt='eza --tree --level=2 --icons'
alias cat='bat --paging=never'
alias grep='rg'
alias find='fd'

# Navigation
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'

# Safety
alias rm='rm -i'
alias mv='mv -i'
alias cp='cp -i'

# Git
alias g='git'
alias gs='git status'
alias ga='git add'
alias gc='git commit'
alias gp='git push'
alias gl='git log --oneline -20'
alias gd='git diff'
alias gco='git checkout'
alias gb='git branch'

# Editors
alias c='cursor'
alias c.='cursor .'

# ============================================================================
# Aliases - AI Workflow
# ============================================================================

# Claude Code
alias cc='claude'
alias ccc='claude --continue'
alias ccr='claude --resume'

# Claude Code with specific context
ccx() {
    # Start Claude Code with specific files pre-loaded
    if [[ $# -eq 0 ]]; then
        echo "Usage: ccx <file1> [file2] ..."
        return 1
    fi
    claude "$@"
}

# Claude Code for autonomous operations (careful with this)
alias cc-auto='claude --dangerously-skip-permissions'

# Local AI quick query
ai() {
    local query="$*"
    curl -s http://localhost:8080/v1/chat/completions \
        -H "Content-Type: application/json" \
        -d "{
            \"model\": \"local\",
            \"messages\": [{\"role\": \"user\", \"content\": \"$query\"}],
            \"max_tokens\": 500
        }" 2>/dev/null | jq -r '.choices[0].message.content // "Error: AI router not running"'
}

# Explain clipboard content
ai-explain() {
    local content=$(pbpaste)
    curl -s http://localhost:8080/v1/chat/completions \
        -H "Content-Type: application/json" \
        -d "{
            \"model\": \"auto\",
            \"messages\": [{\"role\": \"user\", \"content\": \"Explain this concisely:\n\n$content\"}],
            \"max_tokens\": 1000
        }" 2>/dev/null | jq -r '.choices[0].message.content // "Error: AI router not running"'
}

# ============================================================================
# Aliases - Intune/Kandji Workflow
# ============================================================================

# Quick Intune log check (when testing detection scripts)
alias intune-logs='tail -f /Library/Logs/Microsoft/Intune/*.log 2>/dev/null || echo "No Intune logs found"'

# Test PowerShell detection script locally
test-detection() {
    if [[ $# -eq 0 ]]; then
        echo "Usage: test-detection <script.ps1>"
        return 1
    fi
    pwsh -File "$1"
    echo "Exit code: $?"
}

# ============================================================================
# Functions - Development
# ============================================================================

# Create new project with CLAUDE.md
mkproject() {
    local name="$1"
    if [[ -z "$name" ]]; then
        echo "Usage: mkproject <name>"
        return 1
    fi
    
    mkdir -p "$name"
    cd "$name"
    git init
    
    cat > CLAUDE.md << 'EOF'
# Project Context

## Overview
[Describe what this project does]

## Code Standards
- [Add your standards here]

## File Structure
- `/src/` - Source code
- `/tests/` - Tests

## When Making Changes
1. Run tests before committing
2. Update changelog if applicable
EOF
    
    echo "Created project: $name"
    echo "Edit CLAUDE.md to add project context for Claude Code"
}

# Quick git commit with AI-generated message
gcommit() {
    local diff=$(git diff --cached)
    if [[ -z "$diff" ]]; then
        echo "No staged changes"
        return 1
    fi
    
    echo "Generating commit message..."
    local message=$(echo "$diff" | head -c 3000 | curl -s http://localhost:8080/v1/chat/completions \
        -H "Content-Type: application/json" \
        -d "{
            \"model\": \"local\",
            \"messages\": [{\"role\": \"user\", \"content\": \"Generate a concise git commit message (max 72 chars first line) for this diff. Only output the message, no explanation:\n\n$diff\"}],
            \"max_tokens\": 100
        }" 2>/dev/null | jq -r '.choices[0].message.content')
    
    if [[ -z "$message" || "$message" == "null" ]]; then
        echo "Failed to generate message. AI router may not be running."
        return 1
    fi
    
    echo "Suggested message:"
    echo "$message"
    echo ""
    read "confirm?Use this message? [y/N] "
    if [[ "$confirm" =~ ^[Yy]$ ]]; then
        git commit -m "$message"
    else
        echo "Aborted"
    fi
}

# ============================================================================
# Functions - System
# ============================================================================

# Toggle focus mode
zen() {
    local focus_file="$HOME/.zen-focus-active"
    
    if [[ -f "$focus_file" ]]; then
        # Deactivate
        osascript -e 'tell application "System Events" to set visible of every process to true' 2>/dev/null
        rm -f "$focus_file"
        echo "🌅 Focus mode deactivated"
    else
        # Activate
        osascript << 'EOF' 2>/dev/null
tell application "System Events"
    set visible of every process whose name is not "Cursor" and name is not "Ghostty" and name is not "Terminal" to false
end tell
EOF
        touch "$focus_file"
        echo "🧘 Focus mode activated"
    fi
}

# Quick directory jump with fzf
j() {
    local dir
    dir=$(fd --type d --hidden --follow --exclude .git . "${1:-.}" | fzf --preview 'eza --tree --level=1 {}')
    [[ -n "$dir" ]] && cd "$dir"
}

# Search and open file in editor
fe() {
    local file
    file=$(fzf --preview 'bat --color=always --line-range=:500 {}')
    [[ -n "$file" ]] && cursor "$file"
}

# ============================================================================
# Startup
# ============================================================================

# Suppress login message
export BASH_SILENCE_DEPRECATION_WARNING=1

# Welcome message (minimal)
if [[ -o interactive ]]; then
    echo "🧘 $(date +%H:%M) | $(pwd)"
fi
