#!/bin/bash
# ============================================================================
# macOS Zen Defaults
# Run: bash defaults.sh
# ============================================================================

echo "Applying macOS zen defaults..."

# ============================================================================
# Dock
# ============================================================================

# Auto-hide dock with no delay
defaults write com.apple.dock autohide -bool true
defaults write com.apple.dock autohide-delay -float 0
defaults write com.apple.dock autohide-time-modifier -float 0.3

# Don't show recent apps
defaults write com.apple.dock show-recents -bool false

# Minimize to application
defaults write com.apple.dock minimize-to-application -bool true

# Dock size
defaults write com.apple.dock tilesize -int 48
defaults write com.apple.dock magnification -bool false

# Don't automatically rearrange Spaces
defaults write com.apple.dock mru-spaces -bool false

# ============================================================================
# Finder
# ============================================================================

# Show path bar
defaults write com.apple.finder ShowPathbar -bool true

# Show POSIX path in title
defaults write com.apple.finder _FXShowPosixPathInTitle -bool true

# Search current folder by default
defaults write com.apple.finder FXDefaultSearchScope -string "SCcf"

# Disable extension change warning
defaults write com.apple.finder FXEnableExtensionChangeWarning -bool false

# Show all extensions
defaults write NSGlobalDomain AppleShowAllExtensions -bool true

# ============================================================================
# Desktop
# ============================================================================

# Hide external drives on desktop
defaults write com.apple.finder ShowExternalHardDrivesOnDesktop -bool false
defaults write com.apple.finder ShowHardDrivesOnDesktop -bool false
defaults write com.apple.finder ShowMountedServersOnDesktop -bool false
defaults write com.apple.finder ShowRemovableMediaOnDesktop -bool false

# Option: Hide desktop icons entirely (uncomment if desired)
# defaults write com.apple.finder CreateDesktop -bool false

# ============================================================================
# Keyboard
# ============================================================================

# Fast key repeat
defaults write NSGlobalDomain KeyRepeat -int 2
defaults write NSGlobalDomain InitialKeyRepeat -int 15

# Disable press-and-hold for accent characters (enable key repeat instead)
defaults write NSGlobalDomain ApplePressAndHoldEnabled -bool false

# ============================================================================
# Sound
# ============================================================================

# Disable UI sounds
defaults write NSGlobalDomain com.apple.sound.uiaudio.enabled -int 0

# ============================================================================
# Hot Corners
# ============================================================================

# Bottom-right: Lock screen (modifier 0 = no modifier required)
defaults write com.apple.dock wvous-br-corner -int 13
defaults write com.apple.dock wvous-br-modifier -int 0

# Other corners disabled
defaults write com.apple.dock wvous-bl-corner -int 0
defaults write com.apple.dock wvous-tl-corner -int 0
defaults write com.apple.dock wvous-tr-corner -int 0

# ============================================================================
# Screenshots
# ============================================================================

# Save screenshots to ~/Screenshots
mkdir -p ~/Screenshots
defaults write com.apple.screencapture location -string "$HOME/Screenshots"

# Disable shadow in screenshots
defaults write com.apple.screencapture disable-shadow -bool true

# ============================================================================
# Trackpad
# ============================================================================

# Tap to click
defaults write com.apple.AppleMultitouchTrackpad Clicking -bool true
defaults write com.apple.driver.AppleBluetoothMultitouch.trackpad Clicking -bool true

# ============================================================================
# Safari (if used)
# ============================================================================

# Enable Develop menu
defaults write com.apple.Safari IncludeDevelopMenu -bool true
defaults write com.apple.Safari WebKitDeveloperExtrasEnabledPreferenceKey -bool true

# ============================================================================
# Activity Monitor
# ============================================================================

# Show all processes
defaults write com.apple.ActivityMonitor ShowCategory -int 0

# ============================================================================
# TextEdit
# ============================================================================

# Plain text by default
defaults write com.apple.TextEdit RichText -int 0

# ============================================================================
# Restart affected services
# ============================================================================

echo "Restarting Dock and Finder..."
killall Dock 2>/dev/null || true
killall Finder 2>/dev/null || true
killall SystemUIServer 2>/dev/null || true

echo "macOS defaults applied."
echo "Note: Some changes may require a logout/login to take full effect."
