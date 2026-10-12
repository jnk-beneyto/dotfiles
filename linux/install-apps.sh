#!/usr/bin/env bash
# linux/install-apps.sh — installs the apps from linux/apps.txt on the detected distro.
#
# Usage:   ./linux/install-apps.sh        (install.sh calls it on its own, at the end)
#
# Automatic detection (lib/platform.sh): OS + distro (/etc/os-release) + package
# manager (apt · dnf · pacman · zypper · apk). Each id in the list is mapped
# to whichever method applies on that distro:
#   · distro package            · official repo (1Password, TablePlus…)
#   · flatpak (Flathub)         · AppImage from GitHub Releases
#   · official script           · AUR (with yay/paru; if no helper, installs yay)
# Idempotent: only installs what's missing. Never aborts on a one-off failure:
# each app that fails ends up as a WARNING and the rest continue.
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LISTA="$REPO/linux/apps.txt"

# shellcheck source=../lib/platform.sh
source "$REPO/lib/platform.sh"
detect_platform

if [[ "$OS" != "Linux" ]]; then
  echo "WARNING: this script is for Linux (on macOS: macos/install-apps.sh)" >&2
  exit 1
fi
if [[ ! -f "$LISTA" ]]; then
  echo "error: can't find $LISTA" >&2
  exit 1
fi

# Distro package manager (not brew): apt/dnf/pacman/zypper/apk.
PM_D="${PM_NATIVE:-$PM}"
ARCH="$(uname -m)"
APPIMG_DIR="$HOME/.local/share/appimages"
IMG_ICON_DIR="$APPIMG_DIR/icons"
BIN_DIR="$HOME/.local/bin"
DESK_DIR="$HOME/.local/share/applications"
_APT_UPDATED=0
AUR_BOOTSTRAPPED=0   # 1 after trying to install yay (only attempted once)

info() { echo "→ $*"; }
ok()   { echo "ok    $*"; }
warn() { echo "WARNING: $*"; }
have() { command -v "$1" >/dev/null 2>&1; }

ENTORNO="${DISTRO_NAME:-Linux${DISTRO_ID:+ ($DISTRO_ID)}}"
info "Linux apps · $ENTORNO · manager: ${PM_D:-none} · list: $LISTA"

# System-wide unattended installs (apt/needrestart/debconf);
# idempotent, install.sh also calls it. See lib/platform.sh.
autoconfirm_linux

# ── Helpers ──────────────────────────────────────────────────────────────────

dl() { # <url> <destination>
  if have curl; then curl -fL --max-time 300 --retry 2 -o "$2" "$1"
  elif have wget; then wget -qO "$2" "$1"
  else warn "neither curl nor wget"; return 1
  fi
}

apt_update_once() {
  [[ "$PM_D" == "apt" && "$_APT_UPDATED" -eq 0 ]] || return 0
  _APT_UPDATED=1
  $SUDO apt-get update -qq || warn "apt-get update failed (no network?)"
}

# Call after adding a new repo: forces an `apt-get update` before installing
# (otherwise apt can't yet see the packages just added).
apt_repo_added() { _APT_UPDATED=0; }

have_pkg() { # <package>
  case "$PM_D" in
    apt)    dpkg-query -W -f='${Status}' "$1" 2>/dev/null | grep -q "install ok installed" ;;
    dnf)    rpm -q "$1" >/dev/null 2>&1 ;;
    pacman) pacman -Q "$1" >/dev/null 2>&1 ;;
    zypper) rpm -q "$1" >/dev/null 2>&1 ;;
    apk)    apk info -e "$1" >/dev/null 2>&1 ;;
    *)      have "${1%%-*}" ;;   # no known manager: better a wild guess than nothing
  esac
}

pkg_available() { # <package> — does it exist in the repos?
  case "$PM_D" in
    apt)    apt_update_once; apt-cache show "$1" 2>/dev/null | grep -q '^Package: ' ;;
    dnf)    dnf list --available "$1" >/dev/null 2>&1 ;;
    pacman) pacman -Si "$1" >/dev/null 2>&1 ;;
    zypper) zypper info "$1" >/dev/null 2>&1 ;;
    apk)    apk search -e "$1" >/dev/null 2>&1 ;;
    *)      false ;;
  esac
}

pkg_install() { # <packages…> — installs the missing ones; never aborts the script
  local need=() p
  for p in "$@"; do have_pkg "$p" || need+=("$p"); done
  ((${#need[@]} == 0)) && return 0
  info "installing ${need[*]}"
  case "$PM_D" in
    apt)    apt_update_once; $SUDO apt-get install -y "${need[@]}" ;;
    dnf)    $SUDO dnf install -y "${need[@]}" ;;
    pacman) $SUDO pacman -S --noconfirm --needed "${need[@]}" ;;
    zypper) $SUDO zypper --non-interactive install "${need[@]}" ;;
    apk)    $SUDO apk add --no-cache "${need[@]}" ;;
    *) warn "no compatible package manager; install by hand: ${need[*]}"; return 1 ;;
  esac || { warn "could not install: ${need[*]}"; return 1; }
}

install_first() { # <candidate-packages…> — installs the first available one
  local p
  for p in "$@"; do have_pkg "$p" && { pkg_install "$p"; return 0; }; done
  for p in "$@"; do pkg_available "$p" && { pkg_install "$p"; return $?; }; done
  warn "none of these packages exist on the distro: $*"
  return 1
}

# aur_helper — prints yay|paru|pikaur if present; exits with 1 if there's none.
aur_helper() {
  local h
  for h in yay paru pikaur; do
    if have "$h"; then echo "$h"; return 0; fi
  done
  return 1
}

# ensure_aur_helper — if there's no AUR helper, installs yay-bin (the
# binary AUR PKGBUILD: packages the official binary, without compiling Go). Only
# attempted ONCE per run. makepkg refuses to run as root: if the script
# runs as root but was invoked with sudo (SUDO_USER), it builds as
# that user and root installs the resulting .pkg.
ensure_aur_helper() {
  aur_helper && return 0
  [[ "$PM_D" == "pacman" && "$AUR_BOOTSTRAPPED" -eq 0 ]] || return 1
  AUR_BOOTSTRAPPED=1

  info "no AUR helper; installing yay (AUR package 'yay-bin')"
  pkg_install git base-devel || true
  local tmp asuser rc=1
  tmp="$(mktemp -d)"
  if git clone --depth=1 https://aur.archlinux.org/yay-bin.git "$tmp/yay-bin" >/dev/null 2>&1; then
    if [[ "$(id -u)" -ne 0 ]]; then
      # Normal case: the script runs as a user and makepkg uses sudo for -i.
      if (cd "$tmp/yay-bin" && makepkg -si --noconfirm); then rc=0; fi
    elif [[ -n "${SUDO_USER:-}" && "$SUDO_USER" != "root" ]]; then
      # Script as root via sudo: it builds as the user who invoked it…
      chown -R "$SUDO_USER:" "$tmp" 2>/dev/null || true
      asuser="runuser -u $SUDO_USER --"
      have sudo && asuser="sudo -u $SUDO_USER -H"
      # …and root installs the compiled package (makepkg can't use sudo here).
      if $asuser bash -c "cd '$tmp/yay-bin' && makepkg --noconfirm" &&
         $SUDO pacman -U --noconfirm "$tmp/yay-bin"/*.pkg.tar.zst; then
        rc=0
      fi
    else
      warn "yay: makepkg can't build as root; run this script as a normal user"
    fi
  fi
  rm -rf "$tmp"

  if [[ "$rc" -eq 0 ]] && aur_helper >/dev/null; then
    ok "yay installed"
    return 0
  fi
  warn "could not install yay; install it by hand: https://github.com/Jguer/yay#installation"
  return 1
}

aur_install() { # <aur-package> — uses yay/paru/pikaur; if none, installs yay
  local h
  h="$(aur_helper || true)"
  if [[ -z "$h" ]]; then
    ensure_aur_helper || return 1
    h="$(aur_helper || true)"
  fi
  if [[ -z "$h" ]]; then
    warn "no AUR helper; install '$1' by hand (yay/paru) or from its website"
    return 1
  fi
  info "installing $1 from AUR ($h)"
  "$h" -S --noconfirm --needed "$1" || { warn "AUR: could not install $1"; return 1; }
}

ensure_fuse() { # AppImage needs libfuse2 (Ubuntu 24.04: libfuse2t64)
  case "$PM_D" in
    apt)    pkg_available libfuse2t64 && pkg_install libfuse2t64 ||
              pkg_install libfuse2 || true ;;
    dnf)    pkg_install fuse-libs || true ;;
    pacman) pkg_install fuse2 || true ;;
    *)      true ;;
  esac
}

# An AppImage carries its own icon AND its own .desktop. The icon is what puts
# the real logo in the menu (installing the AppImage alone doesn't); the
# StartupWMClass of that .desktop is what ties the RUNNING window to the menu
# entry, so the dock and Alt+Tab show the same logo instead of a generic icon.
# Both are unpacked once and cached in $IMG_ICON_DIR ($cmd.meta holds the keys),
# so a re-run never has to touch the AppImage again. Fills: APPICON ·
# APPWMCLASS · APPCATEGORIES · APPCOMMENT · APPKEYWORDS · APPMIMETYPE.

desktop_key() { # <file> <key> — value of a key in a .desktop file
  sed -n "s/^$2=//p" "$1" 2>/dev/null | head -1
}

desktop_list() { # <a;b> — freedesktop's list values must end in ';'
  [[ -z "$1" || "$1" == *';' ]] && printf '%s' "$1" || printf '%s;' "$1"
}

appimage_read_desktop() { # <file> — reads the keys we forward to our entry
  APPWMCLASS="$(desktop_key "$1" StartupWMClass)"
  APPCATEGORIES="$(desktop_key "$1" Categories)"
  APPCOMMENT="$(desktop_key "$1" Comment)"
  APPKEYWORDS="$(desktop_key "$1" Keywords)"
  APPMIMETYPE="$(desktop_key "$1" MimeType)"
}

appimage_desktop_data() { # <appimage> <command> — icon → $APPICON, keys → $APP*
  local appimg="$1" cmd="$2"
  local dest="$IMG_ICON_DIR/$cmd" cached="$IMG_ICON_DIR/$cmd.meta"
  APPICON="" APPWMCLASS="" APPCATEGORIES="" APPCOMMENT="" APPKEYWORDS="" APPMIMETYPE=""

  # Cached by a previous run: the icon and the keys are already there.
  if [[ -f "$cached" && ( -f "$dest.png" || -f "$dest.svg" ) ]]; then
    [[ -f "$dest.png" ]] && APPICON="$dest.png"
    [[ -f "$dest.svg" ]] && APPICON="$dest.svg"
    appimage_read_desktop "$cached"
    return 0
  fi

  # `--appimage-extract` unpacks the payload with the runtime's own extractor
  # (no FUSE needed); it writes ./squashfs-root in the current directory.
  local tmp; tmp="$(mktemp -d)" || return 1
  if ! ( cd "$tmp" && "$appimg" --appimage-extract >/dev/null 2>&1 ); then
    rm -rf "$tmp"; return 1
  fi
  local root="$tmp/squashfs-root"
  if [[ ! -d "$root" ]]; then rm -rf "$tmp"; return 1; fi

  # The embedded .desktop names the icon (Icon=obsidian → obsidian.png/svg).
  local emb="" f name=""
  for f in "$root"/*.desktop; do
    [[ -f "$f" ]] || continue
    emb="$f"
    name="$(desktop_key "$f" Icon)"
    [[ -n "$name" ]] && break
  done
  name="${name##*/}"; name="${name%.png}"; name="${name%.svg}"; name="${name%.xpm}"

  local src="" ext=""
  # 1) .DirIcon: the standard embedded icon (usually a PNG).
  if [[ -f "$root/.DirIcon" ]]; then
    if [[ "$(head -c4 "$root/.DirIcon" 2>/dev/null | od -An -tx1 | tr -d ' \n')" == "89504e47" ]]; then
      src="$root/.DirIcon"; ext="png"
    elif grep -qi '<svg' "$root/.DirIcon" 2>/dev/null; then
      src="$root/.DirIcon"; ext="svg"
    fi
  fi
  # 2) the file the .desktop points to (biggest PNG first, then any SVG).
  if [[ -z "$src" && -n "$name" ]]; then
    src="$(find "$root" -type f -ipath '*/icons/*' -iname "$name.png" -printf '%s %p\n' 2>/dev/null \
      | sort -n | tail -1 | cut -d' ' -f2- || true)"
    if [[ -n "$src" ]]; then ext="png"
    else
      src="$(find "$root" -type f -ipath '*/icons/*' -iname "$name.svg" 2>/dev/null | head -1 || true)"
      [[ -n "$src" ]] && ext="svg"
    fi
  fi

  mkdir -p "$IMG_ICON_DIR"
  if [[ -n "$src" && -n "$ext" ]]; then
    cp -f "$src" "$dest.$ext" 2>/dev/null && APPICON="$dest.$ext"
  fi
  if [[ -n "$emb" ]]; then
    cp -f "$emb" "$cached" 2>/dev/null && appimage_read_desktop "$cached"
  fi
  rm -rf "$tmp"
  return 0
}

# install_desktop_entry <appimage> <command> <Visible name> — writes the menu
# entry. The icon is an ABSOLUTE path (freedesktop allows it) so it shows up on
# any DE/theme without needing an icon-cache refresh; StartupWMClass is what
# makes the dock match the window with this entry.
install_desktop_entry() {
  local target="$1" cmd="$2" pretty="$3"
  appimage_desktop_data "$target" "$cmd" || true
  local cats="${APPCATEGORIES:-Utility;}"
  mkdir -p "$DESK_DIR"
  {
    echo "[Desktop Entry]"
    echo "Type=Application"
    echo "Name=$pretty"
    [[ -n "$APPCOMMENT" && "$APPCOMMENT" != "$pretty" ]] && echo "Comment=$APPCOMMENT"
    echo "Exec=$target %U"
    echo "Icon=${APPICON:-$cmd}"
    [[ -n "$APPWMCLASS" ]] && echo "StartupWMClass=$APPWMCLASS"
    echo "Categories=$(desktop_list "$cats")"
    [[ -n "$APPKEYWORDS" ]] && echo "Keywords=$(desktop_list "$APPKEYWORDS")"
    [[ -n "$APPMIMETYPE" ]] && echo "MimeType=$(desktop_list "$APPMIMETYPE")"
    echo "Terminal=false"
  } > "$DESK_DIR/$cmd.desktop"
  have update-desktop-database && update-desktop-database "$DESK_DIR" >/dev/null 2>&1 || true
}

# install_appimage <url> <file-name> <command> <Visible name>
install_appimage() {
  local url="$1" name="$2" cmd="$3" pretty="$4"
  local target="$APPIMG_DIR/$name.AppImage"
  if [[ -x "$target" ]]; then
    ok "$pretty: already there ($target)"
  else
    ensure_fuse
    mkdir -p "$APPIMG_DIR" "$BIN_DIR" "$DESK_DIR"
    info "downloading $pretty → $target"
    if dl "$url" "$target.tmp"; then
      mv "$target.tmp" "$target" && chmod +x "$target"
      ok "$pretty installed → $BIN_DIR/$cmd"
    else
      rm -f "$target.tmp"
      warn "could not download $pretty ($url)"
      return 1
    fi
  fi
  # Refresh the symlink and the menu entry (also for an AppImage that was
  # installed by an older version that created the entry without an icon).
  ln -sf "$target" "$BIN_DIR/$cmd"
  install_desktop_entry "$target" "$cmd" "$pretty"
}

# github_appimage_url <owner/repo> — latest AppImage for the current architecture
github_appimage_url() {
  local assets
  assets="$(curl -fsSL --max-time 20 "https://api.github.com/repos/$1/releases/latest" 2>/dev/null \
    | grep -o '"browser_download_url": *"[^"]*"' | cut -d'"' -f4 || true)"
  if [[ "$ARCH" == "aarch64" || "$ARCH" == "arm64" ]]; then
    printf '%s\n' "$assets" | grep -Ei 'aarch64|arm64' | grep -Ei '\.appimage$' | head -1 || true
  else
    printf '%s\n' "$assets" | grep -Ei '\.appimage$' | grep -Evi 'arm64|aarch64' | head -1 || true
  fi
}

# github_asset_url <owner/repo> <regex> — any asset from the latest release
github_asset_url() {
  curl -fsSL --max-time 20 "https://api.github.com/repos/$1/releases/latest" 2>/dev/null \
    | grep -o '"browser_download_url": *"[^"]*"' | cut -d'"' -f4 \
    | grep -E "$2" | head -1 || true
}

flatpak_app() { # <flatpak-id> <Visible name>
  if have flatpak && flatpak list --app --columns=application 2>/dev/null | grep -qx "$1"; then
    ok "$2: already there (flatpak)"; return 0
  fi
  if ! have flatpak; then
    pkg_install flatpak || { warn "no flatpak; install $2 by hand"; return 1; }
  fi
  $SUDO flatpak remote-add --if-not-exists flathub \
    https://dl.flathub.org/repo/flathub.flatpakrepo || true
  info "installing $2 (flatpak $1)"
  $SUDO flatpak install -y --noninteractive flathub "$1" \
    || { warn "could not install $2 from Flathub"; return 1; }
  ok "$2 installed (flatpak)"
}

# ── The apps ─────────────────────────────────────────────────────────────────
# One id from linux/apps.txt → its installation on this distro.
install_app() {
  case "$1" in

  1password)
    case "$PM_D" in
      apt)
        # 1Password retired its apt repo (old versions' .list files already
        # 404 and break `apt-get update`): remove whatever exists and
        # install the official .deb, which is what 1password.com offers today.
        if [[ -f /etc/apt/sources.list.d/1password.list ]]; then
          info "removing obsolete 1Password apt repo (no longer exists)"
          $SUDO rm -f /etc/apt/sources.list.d/1password.list
          apt_repo_added
        fi
        if have_pkg 1password; then ok "1Password: already there"
        else
          info "installing 1Password (official .deb)"
          dl "https://downloads.1password.com/linux/debian/amd64/stable/1password-latest.deb" /tmp/1password.deb \
            && $SUDO apt-get install -y /tmp/1password.deb && ok "1Password installed" \
            || warn "1Password: could not install → https://1password.com/downloads/linux"
        fi ;;
      dnf)
        # The RPM repo is still alive; the .repo is written by hand (the one
        # they published at downloads.1password.com/linux/fedora is no longer served).
        if [[ ! -f /etc/yum.repos.d/1password.repo ]]; then
          info "configuring the official 1Password repo (RPM channel)"
          cat > /tmp/1password.repo <<'EOF'
[1password]
name=1Password Stable Channel
baseurl=https://downloads.1password.com/linux/rpm/stable/$basearch
enabled=1
gpgcheck=1
repo_gpgcheck=1
gpgkey=https://downloads.1password.com/linux/keys/1password.asc
EOF
          $SUDO cp /tmp/1password.repo /etc/yum.repos.d/1password.repo
        fi
        pkg_install 1password ;;
      pacman) aur_install 1password ;;
      *)      warn "1Password: install by hand → https://1password.com/downloads/linux" ;;
    esac ;;

  obsidian)
    local u; u="$(github_appimage_url obsidianmd/obsidian-releases)"
    [[ -n "$u" ]] && install_appimage "$u" Obsidian obsidian "Obsidian" \
      || warn "Obsidian: couldn't find the AppImage for $ARCH" ;;

  spotify)
    flatpak_app com.spotify.Client Spotify ;;

  telegram)
    # Only Arch (and Debian sid) package the client; Ubuntu, Debian stable and
    # Fedora don't → if it's not in the repos, the same official client is
    # installed from Flathub.
    if have_pkg telegram-desktop || pkg_available telegram-desktop; then
      pkg_install telegram-desktop || flatpak_app org.telegram.desktop Telegram
    else
      flatpak_app org.telegram.desktop Telegram
    fi ;;

  google-chrome)
    case "$PM_D" in
      apt)    if ! have google-chrome; then
                dl "https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb" /tmp/chrome.deb \
                  && $SUDO apt-get install -y /tmp/chrome.deb && ok "Google Chrome installed" \
                  || warn "Google Chrome: could not install the .deb"
              else ok "Google Chrome: already there"; fi ;;
      dnf)    if ! have google-chrome; then
                dl "https://dl.google.com/linux/direct/google-chrome-stable_current_x86_64.rpm" /tmp/chrome.rpm \
                  && $SUDO dnf install -y /tmp/chrome.rpm && ok "Google Chrome installed" \
                  || warn "Google Chrome: could not install the .rpm"
              else ok "Google Chrome: already there"; fi ;;
      pacman) aur_install google-chrome || aur_install google-chrome-stable || true ;;
      *)      warn "Google Chrome: https://google.com/chrome" ;;
    esac ;;

  docker)
    if ! have docker; then
      case "$PM_D" in
        apt|dnf)
          info "installing Docker Engine (official get.docker.com script)"
          curl -fsSL https://get.docker.com | $SUDO sh \
            || warn "get.docker.com failed; try: https://docs.docker.com/engine/install" ;;
        pacman) pkg_install docker docker-compose || true ;;
        zypper) pkg_install docker || true ;;
        *)      warn "Docker: https://docs.docker.com/engine/install" ;;
      esac
    fi
    if have docker; then
      have systemctl && { $SUDO systemctl enable --now docker >/dev/null 2>&1 || true; }
      $SUDO groupadd -f docker 2>/dev/null || true
      id -nG "$USER" 2>/dev/null | grep -qw docker || {
        $SUDO usermod -aG docker "$USER" 2>/dev/null || true
        warn "Docker: added '$USER' to the 'docker' group → log out and back in to use it without sudo"
      }
      ok "Docker $(docker --version 2>/dev/null | awk '{print $3}' | tr -d ',')"
    fi ;;

  gh)
    # GitHub CLI: the package is 'gh' (apt/dnf/apk) or 'github-cli' (Arch).
    if [[ "$PM_D" == "pacman" ]]; then
      pkg_install github-cli || warn "GitHub CLI: https://github.com/cli/cli#installation"
    else
      # Older distro without 'gh' in its repos → official repo (apt only).
      if [[ "$PM_D" == "apt" ]] && ! pkg_available gh; then
        info "'gh' isn't in your repos → adding the official GitHub repo"
        $SUDO curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
          -o /usr/share/keyrings/githubcli-archive-keyring.gpg || true
        $SUDO chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg 2>/dev/null || true
        echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
          | $SUDO tee /etc/apt/sources.list.d/github-cli.list >/dev/null
        apt_repo_added
      fi
      pkg_install gh || warn "GitHub CLI: https://github.com/cli/cli#installation"
    fi ;;

  tableplus)
    case "$PM_D" in
      apt)
        if [[ ! -f /etc/apt/sources.list.d/tableplus.list ]]; then
          info "configuring the official TablePlus repo"
          have gpg || pkg_install gnupg || true   # gpg --dearmor of the key
          curl -fsSL https://deb.tableplus.com/apt.tableplus.com.gpg.key \
            | $SUDO gpg --dearmor -o /etc/apt/trusted.gpg.d/tableplus-archive.gpg \
            || { warn "TablePlus: key not imported"; return 1; }
          echo "deb https://deb.tableplus.com/debian tableplus main" \
            | $SUDO tee /etc/apt/sources.list.d/tableplus.list >/dev/null
          apt_repo_added
        fi
        pkg_install tableplus ;;
      dnf)
        if [[ ! -f /etc/yum.repos.d/tableplus.repo ]]; then
          info "configuring the official TablePlus repo"
          dl "https://yum.tableplus.com/rpm/x86_64/tableplus.repo" /tmp/tableplus.repo \
            && $SUDO cp /tmp/tableplus.repo /etc/yum.repos.d/tableplus.repo \
            || { warn "TablePlus: could not add the repo → https://www.tableplus.com/download/linux"; return 1; }
        fi
        pkg_install tableplus ;;
      pacman) aur_install tableplus || warn "TablePlus: https://www.tableplus.com/download/linux" ;;
      *)      warn "TablePlus: https://www.tableplus.com/download/linux" ;;
    esac ;;

  ghostty)
    case "$PM_D" in
      apt)
        apt_update_once   # needed so apt-cache sees the new packages
        if apt-cache show ghostty 2>/dev/null | grep -q '^Package: ghostty'; then
          pkg_install ghostty
        elif [[ "$DISTRO_ID" == "ubuntu" || "$DISTRO_LIKE" == *ubuntu* ]]; then
          info "Ghostty isn't in your repos → adding community PPA"
          pkg_install software-properties-common || return 1
          $SUDO add-apt-repository -y ppa:mkasberg/ghostty-ubuntu \
            && pkg_install ghostty \
            || warn "Ghostty: PPA failed → https://ghostty.org/docs/install/binary"
        else
          # Debian: the project doesn't publish an official .deb; the method
          # documented by ghostty.org for Debian is the community .deb from
          # mkasberg/ghostty-ubuntu (the same installer works for Ubuntu).
          info "Ghostty (Debian): installing the community .deb (mkasberg/ghostty-ubuntu)"
          curl -fsSL https://raw.githubusercontent.com/mkasberg/ghostty-ubuntu/HEAD/install.sh \
            | ${SUDO:-} env DEBIAN_FRONTEND=noninteractive bash \
            && ok "Ghostty installed (community package)" \
            || warn "Ghostty: the community .deb failed → https://ghostty.org/docs/install/binary"
        fi ;;
      dnf)
        # The COPR .repo is downloaded directly: it doesn't depend on the
        # 'copr' plugin (which with dnf5 may not be installed). If the URL for
        # this Fedora version doesn't exist yet, it falls back to 'dnf copr enable'.
        local copr_repo="/etc/yum.repos.d/scottames-ghostty-copr.repo"
        if [[ ! -f "$copr_repo" && ! -f "/etc/yum.repos.d/_copr:copr.fedorainfracloud.org:scottames:ghostty.repo" ]]; then
          info "adding COPR scottames/ghostty"
          dl "https://copr.fedorainfracloud.org/coprs/scottames/ghostty/repo/fedora-${DISTRO_VERSION}/scottames-ghostty-fedora-${DISTRO_VERSION}.repo" \
             /tmp/ghostty-copr.repo \
            && $SUDO cp /tmp/ghostty-copr.repo "$copr_repo" \
            || $SUDO dnf copr enable -y scottames/ghostty 2>/dev/null || true
        fi
        pkg_install ghostty || warn "Ghostty: COPR failed → https://ghostty.org/docs/install/binary" ;;
      pacman|apk|zypper) pkg_install ghostty ;;
      *) warn "Ghostty: https://ghostty.org/docs/install/binary" ;;
    esac ;;

  wezterm)
    local u; u="$(github_appimage_url wez/wezterm)"
    [[ -n "$u" ]] && install_appimage "$u" WezTerm wezterm "WezTerm" \
      || warn "WezTerm: no AppImage for $ARCH → https://wezterm.org/install" ;;

  balenaetcher)
    case "$PM_D" in
      apt)
        if have balena-etcher || have balenaEtcher; then ok "Etcher: already there"
        else
          local u; u="$(github_asset_url balena-io/etcher 'amd64\.deb$')"
          [[ -n "$u" ]] && dl "$u" /tmp/etcher.deb \
            && $SUDO apt-get install -y /tmp/etcher.deb && ok "Etcher installed" \
            || warn "Etcher: could not install → https://etcher.balena.io"
        fi ;;
      dnf)
        if have balena-etcher || have balenaEtcher; then ok "Etcher: already there"
        else
          local u; u="$(github_asset_url balena-io/etcher 'x86_64\.rpm$')"
          [[ -n "$u" ]] && dl "$u" /tmp/etcher.rpm \
            && $SUDO dnf install -y /tmp/etcher.rpm && ok "Etcher installed" \
            || warn "Etcher: could not install → https://etcher.balena.io"
        fi ;;
      pacman) aur_install balena-etcher || warn "Etcher: https://etcher.balena.io" ;;
      *)      warn "Etcher: https://etcher.balena.io" ;;
    esac ;;

  htop)   pkg_install htop   || true ;;
  tree)   pkg_install tree   || true ;;
  # Fedora doesn't build 'ffmpeg' (it lives in RPM Fusion): there the package
  # is 'ffmpeg-free', which is what ships the ffmpeg binary in the repos.
  ffmpeg) install_first ffmpeg ffmpeg-free || true ;;

  yt-dlp)
    if pkg_available pipx; then
      pkg_install pipx || true
      if have pipx; then
        if pipx list 2>/dev/null | grep -q yt-dlp; then pipx upgrade yt-dlp || true
        else pipx install yt-dlp || true; fi
      fi
    fi
    if ! have yt-dlp; then pkg_install yt-dlp || true; fi
    if have yt-dlp; then ok "yt-dlp $(yt-dlp --version 2>/dev/null)"
    else warn "yt-dlp: could not install → https://github.com/yt-dlp/yt-dlp#installation"; fi ;;

  *)
    warn "unknown id in linux/apps.txt: '$1'"
    return 1 ;;
  esac
}

# ── Main loop ────────────────────────────────────────────────────────────────
# Each app runs isolated: if one fails, the rest continue (install.sh style).
INSTALADAS=0; FALLOS=0
while IFS= read -r linea; do
  id="$linea"; id="${id%%#*}"               # cut off the comment
  id="$(printf '%s' "$id" | tr -d '[:space:]')"
  [[ -z "$id" ]] && continue
  if install_app "$id"; then
    INSTALADAS=$((INSTALADAS + 1))
  else
    FALLOS=$((FALLOS + 1))
    warn "$id: incomplete installation (re-run this script to retry)"
  fi
done < <(grep -vE '^\s*(#|$)' "$LISTA")

echo
if [[ "$FALLOS" -gt 0 ]]; then
  warn "apps: $INSTALADAS ok · $FALLOS with failures (details above)"
else
  ok "apps: $INSTALADAS processed, no failures"
fi
echo "AppImages and menus: $APPIMG_DIR · reachable from $BIN_DIR"
