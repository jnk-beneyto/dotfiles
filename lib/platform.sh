# lib/platform.sh — shared environment detection.
#
# Used from install.sh, macos/install-apps.sh and linux/install-apps.sh:
# a single source of truth to know what machine we're on.
#
#   source "…/lib/platform.sh"
#   detect_platform
#
# Fills in:
#   OS             Darwin | Linux            (uname -s)
#   DISTRO_ID      ubuntu, debian, fedora, arch…   (Linux; '' if it can't be read)
#   DISTRO_NAME    readable name, e.g. "Ubuntu 24.04.2 LTS" (PRETTY_NAME)
#   DISTRO_VERSION VERSION_ID, e.g. "24.04"
#   DISTRO_LIKE    families, e.g. "debian" or "rhel fedora" (ID_LIKE)
#   PM             package manager: brew | apt | dnf | pacman | zypper | apk | ''
#                  (for generic installs; brew first if it exists, as
#                   install.sh always did — supports Linuxbrew)
#   PM_NATIVE      like PM but without brew: the distro's own manager
#                  (apt/dnf/pacman/zypper/apk); '' if none
#   SUDO           "sudo" if needed (we're not root and there's a PM that requires it)
#
# Test overrides (do not use in production):
#   DOTFILES_TEST_OS        fakes uname -s (e.g. "Linux")
#   DOTFILES_OS_RELEASE     alternative path to /etc/os-release

# Idempotent when sourced twice.
if [[ -z "${_DOTFILES_PLATFORM_LOADED:-}" ]]; then
  _DOTFILES_PLATFORM_LOADED=1

  have() { command -v "$1" >/dev/null 2>&1; }
fi

detect_platform() {
  OS="${DOTFILES_TEST_OS:-$(uname -s)}"

  DISTRO_ID=""; DISTRO_NAME=""; DISTRO_VERSION=""; DISTRO_LIKE=""
  if [[ "$OS" == "Linux" ]]; then
    local os_release="${DOTFILES_OS_RELEASE:-/etc/os-release}"
    if [[ -r "$os_release" ]]; then
      # Read in a subshell so the script isn't polluted with the variables
      # (NAME, ID, HOME_URL…) that os-release defines.
      DISTRO_ID="$(. "$os_release" && echo "${ID:-}")"
      DISTRO_NAME="$(. "$os_release" && echo "${PRETTY_NAME:-}")"
      DISTRO_VERSION="$(. "$os_release" && echo "${VERSION_ID:-}")"
      DISTRO_LIKE="$(. "$os_release" && echo "${ID_LIKE:-}")"
    fi
  fi

  # PM: generic manager (brew first, to support Linuxbrew as always).
  # PM_NATIVE: the distro's own, which is what installs the apps from
  # linux/apps.txt (the 1Password, Brave, TablePlus… repos are the distro's).
  PM=""; PM_NATIVE=""
  local c
  for c in brew apt-get dnf pacman zypper apk; do
    if have "$c"; then
      [[ -z "$PM" ]] && PM="$c"
      if [[ "$c" != "brew" && -z "$PM_NATIVE" ]]; then PM_NATIVE="$c"; fi
    fi
  done
  # The command is apt-get; the internal name is apt (that's what the case statements use).
  [[ "$PM" == "apt-get" ]] && PM="apt"
  [[ "$PM_NATIVE" == "apt-get" ]] && PM_NATIVE="apt"

  # Debian/Fedora/Arch/openSUSE/Alpine need root; we use sudo if it exists.
  SUDO=""
  if [[ "$(id -u)" -ne 0 ]]; then
    if { [[ -n "$PM" && "$PM" != "brew" ]] || [[ -n "$PM_NATIVE" ]]; } && have sudo; then
      SUDO="sudo"
    fi
  fi

  return 0
}

# autoconfirm_linux — unattended installs on Linux (the equivalent of
# macOS's HOMEBREW_NO_ASK=1). The scripts already pass -y/--noconfirm; this covers
# what those flags do NOT control:
#   · modified dpkg conffiles → confdef/confold (doesn't ask what to do)
#   · apt → Assume-Yes also on manual user calls
#   · needrestart (Ubuntu) → automatic service restart
#   · debconf → keeps DEBIAN_FRONTEND=noninteractive in sudo (sudo strips
#     the environment; zprofile exports the rest)
# All at system level (survives sudo). Idempotent and non-fatal: if there are no
# permissions, it warns and moves on. To ask again: delete the files.
autoconfirm_linux() {
  [[ "$OS" == "Linux" ]] || return 0

  if have apt-get; then
    local aptconf=/etc/apt/apt.conf.d/90-dotfiles
    if ! $SUDO grep -q "Assume-Yes" "$aptconf" 2>/dev/null; then
      printf '%s\n' \
        '# dotfiles — installs without confirmation (delete this file to be asked again)' \
        'APT::Get::Assume-Yes "true";' \
        'Dpkg::Options { "--force-confdef"; "--force-confold"; };' |
        $SUDO tee "$aptconf" >/dev/null &&
        ok "apt: automatic confirmation ($aptconf)" ||
        warn "could not write $aptconf (sudo?); dpkg may end up asking"
    fi
  fi

  # needrestart (Ubuntu ≥22.04): "Restart services…?" dialog after upgrades.
  if [[ -d /etc/needrestart/conf.d ]]; then
    local nrconf=/etc/needrestart/conf.d/90-dotfiles.conf
    if ! $SUDO test -f "$nrconf"; then
      printf '%s\n' '# dotfiles — restart services without asking' "\$nrconf{restart} = 'a';" |
        $SUDO tee "$nrconf" >/dev/null &&
        ok "needrestart: automatic restart ($nrconf)" ||
        warn "could not write $nrconf; needrestart may end up asking"
    fi
  fi

  # sudoers: make sudo keep DEBIAN_FRONTEND for apt-get calls run with sudo.
  if have visudo; then
    local sod=/etc/sudoers.d/dotfiles-debconf tmp
    if ! $SUDO test -f "$sod"; then
      tmp="$(mktemp)" || return 0
      echo 'Defaults env_keep += "DEBIAN_FRONTEND"' > "$tmp"
      if visudo -cf "$tmp" >/dev/null 2>&1; then
        $SUDO install -m 0440 "$tmp" "$sod" &&
          ok "sudoers: sudo keeps DEBIAN_FRONTEND ($sod)" ||
          warn "could not write $sod; debconf may end up asking"
      else
        warn "visudo rejected the rule; skipping $sod"
      fi
      rm -f "$tmp"
    fi
  fi
  return 0
}
