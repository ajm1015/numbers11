# ============================================================================
# Zsh Profile - Runs on login shell
# ============================================================================

# Homebrew (Apple Silicon) - needs to be early
if [[ -f "/opt/homebrew/bin/brew" ]]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
fi

# Homebrew (Intel)
if [[ -f "/usr/local/bin/brew" ]]; then
    eval "$(/usr/local/bin/brew shellenv)"
fi

# Silence macOS zsh warning
export BASH_SILENCE_DEPRECATION_WARNING=1
