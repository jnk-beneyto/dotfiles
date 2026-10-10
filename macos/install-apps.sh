#!/usr/bin/env bash
# macos/install-apps.sh — installs the macOS apps listed in macos/Brewfile.
#
# Usage:   ./macos/install-apps.sh        (install.sh calls it on its own, at the end)
#
# Idempotent: only installs what is missing (brew bundle check → install).
#  · Formulas and apps  → Homebrew (`brew bundle`)
#  · App Store          → `mas` (if not signed in, warns and continues)
# Uninstalls nothing: anything extra in the Brewfile is ignored.
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BREWFILE="$REPO/macos/Brewfile"

# App Store apps (mas): <id> <name>
APPSTORE_APPS=(
  "1537056818 Unzip - RAR ZIP 7Z Unarchiver"
)

info() { echo "→ $*"; }
ok()   { echo "ok    $*"; }
warn() { echo "WARN: $*"; }

# Shared detection: OS, distro, PM, SUDO (lib/platform.sh).
# shellcheck source=../lib/platform.sh
source "$REPO/lib/platform.sh"
detect_platform

if [[ "$OS" != "Darwin" ]]; then
  warn "this script is only for macOS (on Linux: linux/install-apps.sh)"
  exit 1
fi

if [[ ! -f "$BREWFILE" ]]; then
  echo "error: cannot find $BREWFILE" >&2
  exit 1
fi

if ! have brew; then
  warn "Homebrew not found; install it first and run again:"
  warn '  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"'
  exit 1
fi

# ── 1) brew bundle: formulas and casks from the Brewfile ─────────────────────
info "checking $BREWFILE"
if brew bundle check --file="$BREWFILE" >/dev/null 2>&1; then
  ok "brew: everything installed"
else
  info "installing what is missing (brew bundle)"
  if brew bundle install --file="$BREWFILE"; then
    ok "brew: install complete"
  else
    warn "brew bundle finished with errors; check the message above and re-run"
  fi
fi

# ── 2) App Store (mas) ───────────────────────────────────────────────────────
if ((${#APPSTORE_APPS[@]} > 0)); then
  if have mas; then
    installed="$(mas list 2>/dev/null || true)"
    for entry in "${APPSTORE_APPS[@]}"; do
      id="${entry%% *}"
      name="${entry#* }"
      if printf '%s\n' "$installed" | grep -q "^$id "; then
        ok "App Store: $name"
      else
        info "installing from the App Store: $name ($id)"
        if mas install "$id" >/dev/null 2>&1; then
          ok "App Store: $name"
        else
          warn "could not install '$name'; open it from the App Store (not signed in?)"
        fi
      fi
    done
  else
    warn "cannot find 'mas' (brew install mas); install manually from the App Store:"
    for entry in "${APPSTORE_APPS[@]}"; do
      warn "  ${entry#* } → https://apps.apple.com/app/id${entry%% *}"
    done
  fi
fi

echo
echo "Done. New apps are in /Applications."
