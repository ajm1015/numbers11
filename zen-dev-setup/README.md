# Zen Development Environment

A focused, AI-powered development setup for macOS. Manages dotfiles with GNU Stow and packages with Homebrew for clean replication across machines.

## What's Included

| Component | Tool | Config |
|-----------|------|--------|
| Terminal | Ghostty (GPU-accelerated) | Catppuccin Mocha, splits, JetBrains Mono |
| Editor | Cursor (AI-first) | Zen mode, minimal UI, format on save |
| Shell | Zsh + Starship | Modern CLI aliases, fzf, zoxide |
| Neovim | Lazy plugin manager | LSP, Telescope, Treesitter, Catppuccin |
| AI | Claude Code | Autonomous coding agent |
| Productivity | Raycast, focus mode | Quick launchers, `zen` toggle |

## Quick Start

```bash
git clone https://github.com/YOUR_USERNAME/zen-dev-setup.git ~/.dotfiles
cd ~/.dotfiles
./install.sh
```

The installer runs these steps:
1. **Preflight** — checks macOS, installs Homebrew + Stow
2. **Brew** — installs all packages from `Brewfile`
3. **Stow** — symlinks all dotfiles into `$HOME`
4. **macOS** — applies system preferences (Dock, Finder, keyboard)
5. **Verify** — runs `zen-doctor` health check

### Flags

```bash
./install.sh --skip-macos    # Skip system preferences
./install.sh --skip-verify   # Skip health check
```

## Post-Install

```bash
# Authenticate Claude Code
claude login

# Import Raycast scripts
# Raycast → Extensions → Script Commands → Add Script Directory → ~/.dotfiles/raycast/scripts

# Restart terminal
source ~/.zshrc
```

## How It Works

### GNU Stow

Each top-level directory is a "stow package" whose contents mirror `$HOME`:

```
shell/.zshrc                                    → ~/.zshrc
shell/.zprofile                                 → ~/.zprofile
shell/.config/starship.toml                     → ~/.config/starship.toml
ghostty/.config/ghostty/config                  → ~/.config/ghostty/config
cursor/Library/Application Support/Cursor/User/ → ~/Library/.../Cursor/User/
claude-code/.claude/settings.json               → ~/.claude/settings.json
nvim/.config/nvim/                              → ~/.config/nvim/
git/.gitconfig                                  → ~/.gitconfig
btop/.config/btop/btop.conf                     → ~/.config/btop/btop.conf
bin/.local/bin/                                 → ~/.local/bin/
```

### Managing Dotfiles

```bash
# Add a new config
mkdir -p <package>/.config/<app>
cp ~/.config/<app>/config <package>/.config/<app>/config
stow --dir=~/.dotfiles --target=$HOME --restow <package>

# Remove a package
stow --dir=~/.dotfiles --target=$HOME -D <package>

# Re-link everything
for pkg in shell ghostty cursor claude-code nvim git btop bin; do
  stow --dir=~/.dotfiles --target=$HOME --restow "$pkg"
done
```

## Shell Commands

| Command | Description |
|---------|-------------|
| `cc` | Start Claude Code |
| `ccc` | Continue last Claude Code session |
| `ccr` | Resume a previous session |
| `zen` | Toggle focus mode |
| `zen-doctor` | Check environment health |
| `j` | Fuzzy jump to directory |
| `fe` | Fuzzy find and open file in Cursor |
| `mkproject <name>` | Create project with CLAUDE.md template |

## Keyboard Shortcuts

### Ghostty

| Shortcut | Action |
|----------|--------|
| `Cmd+D` | Split right |
| `Cmd+Shift+D` | Split down |
| `Cmd+Shift+H/J/K/L` | Navigate splits |
| `Cmd+W` | Close split |
| `Cmd+K` | Clear screen |

### Cursor

| Shortcut | Action |
|----------|--------|
| `Cmd+K` | AI inline edit |
| `Cmd+L` | AI chat |
| `Cmd+K Z` | Toggle Zen mode |
| `Cmd+B` | Toggle sidebar |
| `Cmd+J` | Toggle terminal |

## Replicating to New Macs

1. Clone the repo
2. Run `./install.sh`
3. Run `claude login`
4. Log out and back in

## Troubleshooting

```bash
# Check environment health
zen-doctor

# Re-stow a single package
stow --dir=~/.dotfiles --target=$HOME --restow shell

# Check Brewfile status
brew bundle check --file=Brewfile
```

## License

MIT
