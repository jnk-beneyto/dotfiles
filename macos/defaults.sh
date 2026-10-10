#!/usr/bin/env bash
# macos/defaults.sh — macOS system preferences (Finder, Dock, keyboard…).
#
# Usage:
#   ./macos/defaults.sh                 # applies
#   DOTFILES_DRY_RUN=1 ./macos/defaults.sh   # only shows the `defaults write`
#
# Writes settings with `defaults write`. It is idempotent: you can rerun it.
# install.sh does NOT run it on its own (it touches system settings); run it manually.
# Some changes need the app to be closed/reopened or a reboot to take effect.
set -euo pipefail

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "this script is only for macOS" >&2
  exit 1
fi

DRY="${DOTFILES_DRY_RUN:-0}"
set_pref() {
  if [[ "$DRY" == "1" ]]; then
    echo "defaults write $*"
  else
    defaults write "$@"
  fi
}
# Restarts an app to apply the changes (if it was open).
restart() { killall "$@" >/dev/null 2>&1 || true; }

echo "→ applying macOS preferences${DRY:+ (dry-run=$DRY)}"

# ── Finder ───────────────────────────────────────────────────────────────────
set_pref com.apple.finder AppleShowAllFiles -bool true          # show hidden files
set_pref com.apple.finder ShowPathbar -bool true                # path bar
set_pref com.apple.finder ShowStatusBar -bool true              # status bar
set_pref com.apple.finder _FXShowPosixPathInTitle -bool true    # full path in the title
set_pref com.apple.finder FXDefaultSearchScope -string "SCcf"   # search in the current folder
set_pref com.apple.finder FXEnableExtensionChangeWarning -bool false
set_pref com.apple.finder FXPreferredViewStyle -string "Nlsv"   # list view
set_pref com.apple.finder WarnOnEmptyTrash -bool false

# ── Save / print dialogs (expanded by default) ───────────────────────────────
set_pref NSGlobalDomain NSNavPanelExpandedStateForSaveMode -bool true
set_pref NSGlobalDomain NSNavPanelExpandedStateForSaveMode2 -bool true
set_pref NSGlobalDomain PMPrintingExpandedStateForPrint -bool true

# ── Keyboard and text ────────────────────────────────────────────────────────
set_pref NSGlobalDomain KeyRepeat -int 2                        # fast key repeat
set_pref NSGlobalDomain InitialKeyRepeat -int 15
set_pref NSGlobalDomain ApplePressAndHoldEnabled -bool false    # accents OFF: held key repeats
set_pref NSGlobalDomain NSAutomaticCapitalizationEnabled -bool false
set_pref NSGlobalDomain NSAutomaticDashSubstitutionEnabled -bool false
set_pref NSGlobalDomain NSAutomaticPeriodSubstitutionEnabled -bool false
set_pref NSGlobalDomain NSAutomaticQuoteSubstitutionEnabled -bool false
set_pref NSGlobalDomain NSAutomaticSpellingCorrectionEnabled -bool false
set_pref NSGlobalDomain AppleShowScrollBars -string "WhenScrolling"

# ── Dock ─────────────────────────────────────────────────────────────────────
set_pref com.apple.dock autohide -bool true
set_pref com.apple.dock autohide-delay -float 0
set_pref com.apple.dock show-recents -bool false
set_pref com.apple.dock mineffect -string "scale"
set_pref com.apple.dock minimize-to-application -bool true
set_pref com.apple.dock tilesize -int 48

# ── Screenshots ──────────────────────────────────────────────────────────────
mkdir -p "$HOME/Pictures/Screenshots"
set_pref com.apple.screencapture location -string "$HOME/Pictures/Screenshots"
set_pref com.apple.screencapture disable-shadow -bool true
set_pref com.apple.screencapture type -string "png"

# ── Miscellaneous ────────────────────────────────────────────────────────────
set_pref com.apple.desktopservices DSDontWriteNetworkStores -bool true

# Apply what needs a restart.
restart Finder
restart Dock
restart SystemUIServer

echo "Done. Some changes show up after logging out or rebooting."
