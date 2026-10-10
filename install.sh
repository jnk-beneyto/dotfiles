#!/usr/bin/env bash
# dotfiles — installer for macOS and Linux.
#
# Install without cloning (curl | bash):
#   curl -sSL https://raw.githubusercontent.com/jnk-beneyto/dotfiles/main/install.sh | bash
# It downloads the repo to $DOTFILES_DIR (default ~/dotfiles) and runs itself
# from there: that copy is what the symlinks point to. Override the destination
# with DOTFILES_DIR=/path (or clone the repo yourself and run ./install.sh).
#
# Overwrite: the dotfile is the single source of truth. Whatever it finds is
# replaced by the state of the repo (idempotent: you can run it as many times
# as you like, it always leaves the same result):
#  - Files → symlink into the repo; if the destination has other content, it is
#    backed up first to <file>.bak.<timestamp>.
#  - oh-my-zsh, powerlevel10k and plugins → restored to their upstream state
#    (if they are not a valid clone, they are backed up and cloned from scratch).
#  - Offline nothing is destroyed: what's there is kept and you are warned.
#
# It also prepares the system: installs what the config needs in order not to fail
# (git, zsh, eza, git-delta, fzf, oh-my-zsh, powerlevel10k, plugins, node/nvm)
# and warns —without aborting the install— about any missing optional pieces
# (Homebrew, JetBrains Mono font, VS Code). All via a package manager:
# brew, apt, dnf or pacman.
#
# Detects the environment on its own (OS, distro and manager — see lib/platform.sh)
# and at the end installs the platform apps: macOS → macos/Brewfile ·
# Linux → linux/apps.txt (adapted to the distro). To skip the apps:
#   DOTFILES_SKIP_APPS=1 ./install.sh
set -euo pipefail

# ── Repo location: from a clone, or downloaded when run via `curl … | bash` ───
# `BASH_SOURCE[0]` is the clone when run as ./install.sh, but `/dev/fd/63` when
# the script arrives through a pipe, so there's no clone on disk. In that case
# the dotfiles are fetched into DOTFILES_DIR (default ~/dotfiles) and the
# installer is relaunched from there — that copy is what the symlinks point to.
DOTFILES_DIR="${DOTFILES_DIR:-$HOME/dotfiles}"
DOTFILES_GIT_URL="${DOTFILES_GIT_URL:-https://github.com/jnk-beneyto/dotfiles.git}"
DOTFILES_TARBALL_URL="${DOTFILES_TARBALL_URL:-https://codeload.github.com/jnk-beneyto/dotfiles/tar.gz/refs/heads/main}"

_have() { command -v "$1" >/dev/null 2>&1; }
_is_repo() { [[ -f "$1/lib/platform.sh" && -f "$1/zsh/zshrc" ]]; }

REPO=""
if [[ -n "${BASH_SOURCE[0]:-}" ]]; then
  REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd)" || REPO=""
fi

if ! _is_repo "$REPO"; then
  if [[ "${DOTFILES_BOOTSTRAPPED:-0}" == "1" ]]; then
    echo "error: the dotfiles could not be downloaded; see the messages above." >&2
    exit 1
  fi

  if _is_repo "$DOTFILES_DIR"; then
    echo "→ using existing dotfiles in $DOTFILES_DIR"
    if [[ -d "$DOTFILES_DIR/.git" ]] && _have git; then
      git -C "$DOTFILES_DIR" pull --ff-only --quiet >/dev/null 2>&1 || true
    fi
  else
    echo "→ installing dotfiles in $DOTFILES_DIR"
    if [[ -e "$DOTFILES_DIR" ]]; then
      _backup="$DOTFILES_DIR.bak.$(date +%Y%m%d%H%M%S)"
      mv -- "$DOTFILES_DIR" "$_backup"
      echo "backup of $DOTFILES_DIR → $_backup"
    fi
    mkdir -p "$(dirname -- "$DOTFILES_DIR")"

    # Preferred: a real clone (updatable with `git pull`). Fallback: tarball
    # with curl/wget when git is missing (the copy then isn't a git repo).
    _have git && git clone --depth=1 "$DOTFILES_GIT_URL" "$DOTFILES_DIR" >/dev/null 2>&1 || true

    if ! _is_repo "$DOTFILES_DIR"; then
      rm -rf -- "$DOTFILES_DIR"
      if _have curl || _have wget; then
        _tmp="$(mktemp -d)"
        echo "→ downloading $DOTFILES_TARBALL_URL"
        if _have curl; then
          curl -fsSL "$DOTFILES_TARBALL_URL" -o "$_tmp/repo.tgz" || true
        else
          wget -qO "$_tmp/repo.tgz" "$DOTFILES_TARBALL_URL" || true
        fi
        if [[ -s "$_tmp/repo.tgz" ]]; then
          tar -xzf "$_tmp/repo.tgz" -C "$_tmp" || true
          for _d in "$_tmp"/*/; do
            [[ -d "$_d" ]] || continue
            mv -- "${_d%/}" "$DOTFILES_DIR" && break
          done
        fi
        rm -rf -- "$_tmp"
      fi
    fi
  fi

  if ! _is_repo "$DOTFILES_DIR"; then
    echo "error: could not download the dotfiles to $DOTFILES_DIR." >&2
    echo "  install git or curl and retry, or clone it yourself:" >&2
    echo "    git clone $DOTFILES_GIT_URL $DOTFILES_DIR && $DOTFILES_DIR/install.sh" >&2
    exit 1
  fi

  export DOTFILES_BOOTSTRAPPED=1
  exec bash "$DOTFILES_DIR/install.sh" "$@"
fi

export NVM_DIR="$HOME/.nvm"
# Node version used by this dotfile (see zsh/zshrc). Override:
#   DOTFILES_NODE_VERSION=v20.12.2 ./install.sh
NODE_VERSION="${DOTFILES_NODE_VERSION:-v22.17.1}"

# Automatic environment detection: OS (Darwin/Linux), distro (/etc/os-release),
# PM (brew/apt/dnf/pacman/zypper/apk), PM_NATIVE and SUDO.
# shellcheck source=lib/platform.sh
source "$REPO/lib/platform.sh"
detect_platform

case "$OS" in
  Darwin|Linux) ;;
  *)
    echo "error: unsupported system ($OS). For Windows see the windows/ folder." >&2
    exit 1
    ;;
esac

info() { echo "→ $*"; }
ok()   { echo "ok    $*"; }
warn() { echo "WARNING: $*"; }

# link <src-in-repo> <absolute-dest>
link() {
  local src="$1" dest="$2"
  mkdir -p "$(dirname "$dest")"

  if [[ -L "$dest" ]]; then
    [[ "$(readlink "$dest")" == "$src" ]] && { echo "ok    $dest"; return 0; }
    rm -f -- "$dest"
  elif [[ -e "$dest" ]]; then
    if cmp -s -- "$src" "$dest"; then
      rm -f -- "$dest" # same content: replaced by the symlink with no backup
    else
      local backup="${dest}.bak.$(date +%Y%m%d%H%M%S)"
      mv -- "$dest" "$backup"
      echo "backup of $dest → $backup"
    fi
  fi

  ln -s -- "$src" "$dest"
  echo "ok    $dest → $src"
}

# reset_clone <dir> <url> <name> — leaves <dir> as upstream installs it,
# so the result always matches the dotfile:
#  · if it's already a clone → back to its original state (local changes and
#    untracked files are discarded: caches, old themes/plugins… — the double -ff
#    also removes nested clones, such as third-party themes)
#  · if it exists but is NOT a clone → it is backed up and cloned from scratch
#  · if it doesn't exist → it is cloned
#  Offline NOTHING is destroyed: what's there is kept and you are warned.
reset_clone() {
  local dir="$1" url="$2" name="$3" backup
  if [[ -d "$dir/.git" ]]; then
    info "$name: restoring to its original state ($dir)"
    git -C "$dir" remote set-url origin "$url" >/dev/null 2>&1 ||
      git -C "$dir" remote add origin "$url" >/dev/null 2>&1 || true
    if ! git -C "$dir" fetch --quiet origin HEAD >/dev/null 2>&1; then
      warn "$name: offline; keeping $dir as-is"
      return 0
    fi
    git -C "$dir" reset --hard FETCH_HEAD >/dev/null 2>&1 &&
      git -C "$dir" clean -ffdx >/dev/null 2>&1 &&
      ok "$name restored" ||
      warn "could not restore $name in $dir"
    return 0
  fi
  if [[ -e "$dir" ]]; then
    backup="$dir.bak.$(date +%Y%m%d%H%M%S)"
    mv -- "$dir" "$backup"
    echo "backup of $dir → $backup"
  fi
  mkdir -p "$(dirname "$dir")"
  info "installing $name"
  git clone --depth=1 "$url" "$dir" >/dev/null 2>&1 ||
    warn "could not clone $name (offline?); install it manually: $url"
}

# ── Package manager ───────────────────────────────────────────────────────────
# PM (brew · apt · dnf · pacman · zypper · apk), PM_NATIVE (the distro's own) and
# SUDO are defined by detect_platform (lib/platform.sh). All that's left here is
# the apt cache state so we don't repeat `apt-get update` on every pkg().
APT_UPDATED=0
# pkg <missing-command> <package> — installs it if needed.
# Never aborts the installer: if it can't, it ends in a WARNING.
pkg() {
  local cmd="$1" pkgname="$2"
  if have "$cmd"; then return 0; fi
  if [[ -z "$PM" ]]; then
    warn "'$cmd' is missing and there is no package manager (brew/apt/dnf/pacman/zypper/apk); install it manually"
    return 0
  fi
  if [[ "$PM" != "brew" && -z "$SUDO" && "$(id -u)" -ne 0 ]]; then
    warn "'$cmd' is missing and there is no sudo to install '$pkgname'; run the script as root"
    return 0
  fi
  info "installing $pkgname (command '$cmd' is missing)"
  case "$PM" in
    brew)   brew install "$pkgname" || true ;;
    apt)
      if [[ "$APT_UPDATED" -eq 0 ]]; then
        $SUDO apt-get update -qq || true
        APT_UPDATED=1
      fi
      $SUDO apt-get install -y "$pkgname" || true ;;
    dnf)    $SUDO dnf install -y "$pkgname" || true ;;
    pacman) $SUDO pacman -S --noconfirm --needed "$pkgname" || true ;;
    zypper) $SUDO zypper --non-interactive install "$pkgname" || true ;;
    apk)    $SUDO apk add --no-cache "$pkgname" || true ;;
  esac
  if have "$cmd"; then
    ok "$cmd installed"
  else
    warn "could not install '$cmd' ($pkgname); install it manually and run again"
  fi
}

if [[ "$OS" == "Darwin" ]]; then
  ENTORNO="macOS"
else
  ENTORNO="${DISTRO_NAME:-Linux${DISTRO_ID:+ ($DISTRO_ID)}}"
fi
echo "→ dotfiles from $REPO  ($ENTORNO · manager: ${PM:-none})"

# Unattended installs on Linux (apt/needrestart/debconf); on macOS it's covered
# by HOMEBREW_NO_ASK in the zprofile. See lib/platform.sh.
autoconfirm_linux

# ── 1) System base ────────────────────────────────────────────────────────────
pkg git  git   # clone the repo and the plugins (oh-my-zsh, p10k…)
pkg zsh  zsh   # the shell the whole stack uses
pkg eza  eza   # all the zsh/aliases aliases (ls, ll, la, lt…)
pkg delta git-delta # git's diff pager (gitconfig: core.pager = delta)
pkg fzf  fzf   # oh-my-zsh's fzf plugin (CTRL-T/CTRL-R/ALT-C and completion)

# Homebrew: the zshrc uses it (nvm and mysql-client prefixes) and on macOS it's
# the usual manager. We don't autoinstall it because its install asks for sudo.
if [[ "$OS" == "Darwin" && "$PM" != "brew" ]]; then
  warn "Homebrew is not installed and the zshrc assumes 'brew' (nvm, mysql-client)."
  warn "  install it: /bin/bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\""
fi

# ── 2) oh-my-zsh + theme and plugins: overwritten with the canonical state ────
# If something already exists, it is restored to its original (upstream) state;
# anything that isn't a valid clone is backed up and cloned from scratch. That
# way, every run leaves the shell exactly as the dotfile says.
reset_clone "$HOME/.oh-my-zsh" \
  "https://github.com/ohmyzsh/ohmyzsh.git" "oh-my-zsh"

if [[ ! -d "$HOME/.oh-my-zsh" ]]; then
  echo "error: without oh-my-zsh I won't link the config (the zshrc would source something that doesn't exist)." >&2
  echo "  git clone --depth=1 https://github.com/ohmyzsh/ohmyzsh.git ~/.oh-my-zsh" >&2
  exit 1
fi

# p10k: lives in custom/themes/ (the cleanup above removes loose copies in
# themes/ or old versions). oh-my-zsh loads custom/themes before themes/.
reset_clone "$HOME/.oh-my-zsh/custom/themes/powerlevel10k" \
  "https://github.com/romkatv/powerlevel10k.git" "powerlevel10k"
for plugin in zsh-autosuggestions zsh-syntax-highlighting; do
  reset_clone "$HOME/.oh-my-zsh/custom/plugins/$plugin" \
    "https://github.com/zsh-users/$plugin.git" "$plugin"
done

# ── 3) node + nvm — the zshrc puts node on the PATH and the `nrd` alias uses npm ──
locate_nvm() {
  if [[ -s "$NVM_DIR/nvm.sh" ]]; then echo "$NVM_DIR/nvm.sh"; return 0; fi
  if have brew; then
    local p
    p="$(brew --prefix nvm 2>/dev/null)/nvm.sh"
    if [[ -s "$p" ]]; then echo "$p"; return 0; fi
  fi
  return 1
}
NVM_SH="$(locate_nvm || true)"
if [[ -z "$NVM_SH" ]] && have git; then
  info "installing nvm in $NVM_DIR"
  git clone --depth=1 https://github.com/nvm-sh/nvm.git "$NVM_DIR" || true
  NVM_SH="$(locate_nvm || true)"
fi
if [[ -z "$NVM_SH" ]]; then
  warn "nvm not found; without it there will be no node/npm (alias 'nrd'). git clone https://github.com/nvm-sh/nvm.git ~/.nvm"
elif [[ ! -x "$NVM_DIR/versions/node/$NODE_VERSION/bin/node" ]]; then
  info "installing node $NODE_VERSION with nvm"
  # set +eu: nvm.sh isn't meant to be run with set -e.
  ( set +eu; export NVM_DIR="$NVM_DIR"; source "$NVM_SH"; nvm install "$NODE_VERSION" ) \
    || warn "could not install node $NODE_VERSION; do it manually: nvm install $NODE_VERSION"
else
  ok "node $NODE_VERSION"
fi

# ── 4) pnpm — package manager of the front-end projects (Next.js/React) ───────
# On macOS the Brewfile installs it; here it covers Linux and any case where
# it's missing. It's installed with npm (it lands in the same nvm prefix as
# node, so it survives version changes with `nvm install`).
if have pnpm; then
  ok "pnpm $(pnpm --version 2>/dev/null | head -1)"
elif have npm; then
  info "installing pnpm (npm i -g pnpm)"
  if npm install -g pnpm >/dev/null 2>&1 && have pnpm; then
    ok "pnpm $(pnpm --version 2>/dev/null | head -1)"
  else
    warn "could not install pnpm; do it manually: npm i -g pnpm  (or: corepack enable pnpm)"
  fi
else
  warn "no npm means no pnpm; install it manually: npm i -g pnpm  ·  https://pnpm.io/installation"
fi

# ── 5) JetBrains Mono font — used by ghostty/config (and p10k's icons) ────────
have_font_jb() {
  if have fc-list; then
    if fc-list 2>/dev/null | grep -qi "jetbrains"; then return 0; fi
  fi
  local d
  for d in "$HOME/Library/Fonts" /Library/Fonts /System/Library/Fonts \
           "$HOME/.local/share/fonts" "$HOME/.fonts" \
           /usr/local/share/fonts /usr/share/fonts; do
    if [[ -d "$d" ]] && find "$d" -maxdepth 3 -iname "*jetbrains*" 2>/dev/null | grep -q .; then
      return 0
    fi
  done
  return 1
}
# On Linux there is no cask: download the Nerd Font (patched, with the icons
# p10k needs) straight from the upstream release. The distro packages don't ship
# the "Nerd Font" variant, hence the manual download. WezTerm/Ghostty need this.
NF_URL="https://github.com/ryanoasis/nerd-fonts/releases/latest/download/JetBrainsMono.zip"
install_font_jb_linux() {
  local dest="$HOME/.local/share/fonts/JetBrainsMono" tmp
  if ! have curl && ! have wget; then
    warn "no curl/wget to download the font; get it at $NF_URL"
    return 1
  fi
  if ! have unzip; then
    pkg unzip unzip || true
    have unzip || { warn "no unzip to extract the font; get it at $NF_URL"; return 1; }
  fi
  info "downloading JetBrains Mono Nerd Font"
  tmp="$(mktemp -d)"
  if have curl; then
    curl -fsSL "$NF_URL" -o "$tmp/JetBrainsMono.zip" || { rm -rf "$tmp"; return 1; }
  else
    wget -qO "$tmp/JetBrainsMono.zip" "$NF_URL" || { rm -rf "$tmp"; return 1; }
  fi
  mkdir -p "$dest"
  unzip -oq "$tmp/JetBrainsMono.zip" -d "$dest" || { rm -rf "$tmp"; return 1; }
  rm -rf "$tmp"
  have fc-cache && fc-cache -f "$dest" >/dev/null 2>&1 || true
  return 0
}
if ! have_font_jb; then
  if [[ "$OS" == "Darwin" ]] && have brew; then
    info "installing JetBrains Mono font (Nerd Font)"
    brew install --cask font-jetbrains-mono-nerd-font \
      || warn "could not install the font; https://www.nerdfonts.com/font-downloads"
  elif [[ "$OS" == "Linux" ]]; then
    if install_font_jb_linux && have_font_jb; then
      ok "JetBrains Mono Nerd Font installed"
    else
      warn "JetBrains Mono font is missing (WezTerm/Ghostty will fall back)."
      warn "  download it from $NF_URL → ~/.local/share/fonts and run: fc-cache -f"
    fi
  else
    warn "JetBrains Mono font is missing (WezTerm/Ghostty will fall back)."
    warn "  download it from $NF_URL → ~/.local/share/fonts and run: fc-cache -f"
  fi
fi

# ── 6) Terminals — warnings only: linking their config without the app is harmless ─
ghostty_present=0
if have ghostty || [[ -x "/Applications/Ghostty.app/Contents/MacOS/ghostty" ]]; then
  ghostty_present=1
elif have flatpak && flatpak list 2>/dev/null | grep -qi ghostty; then
  ghostty_present=1
fi
if [[ "$ghostty_present" -eq 0 ]]; then
  warn "Ghostty is not installed (its config will be linked with no effect)."
  if [[ "$OS" == "Darwin" ]]; then
    echo "        brew install --cask ghostty"
  else
    case "${PM_NATIVE:-$PM}" in
      apt)    echo "        sudo apt install ghostty   # Ubuntu 26.04+ · otherwise: add-apt-repository ppa:mkasberg/ghostty-ubuntu" ;;
      dnf)    echo "        sudo dnf copr enable scottames/ghostty && sudo dnf install ghostty" ;;
      pacman) echo "        sudo pacman -S ghostty" ;;
      zypper) echo "        sudo zypper in ghostty" ;;
      *)      echo "        https://ghostty.org/docs/install/binary" ;;
    esac
  fi
fi

wezterm_present=0
if have wezterm || [[ -x "/Applications/WezTerm.app/Contents/MacOS/wezterm" ]]; then
  wezterm_present=1
fi
if [[ "$wezterm_present" -eq 0 ]]; then
  warn "WezTerm is not installed (its config will be linked with no effect)."
  if [[ "$OS" == "Darwin" ]]; then
    echo "        brew install --cask wezterm"
  else
    echo "        it's downloaded as an AppImage with the apps (linux/apps.txt → 'wezterm')"
    echo "        or manually: https://wezterm.org/install"
  fi
fi

# ── Files ─────────────────────────────────────────────────────────────────────
# ── Files ─────────────────────────────────────────────────────────────────────
# Login shell / environment (zshenv is loaded in EVERY zsh; zprofile, in login ones).
link "$REPO/zsh/zshenv"             "$HOME/.zshenv"
link "$REPO/zsh/zprofile"           "$HOME/.zprofile"
link "$REPO/zsh/zshrc"              "$HOME/.zshrc"
link "$REPO/git/gitconfig"          "$HOME/.gitconfig"
# Global git ignores (read by core.excludesFile of the gitconfig).
link "$REPO/git/ignore"             "$HOME/.config/git/ignore"
# Identity of this machine: ~/.gitconfig.local (included by the gitconfig).
# NOT in the repo; if it doesn't exist, it's created from the example so you can edit it.
if [[ ! -e "$HOME/.gitconfig.local" ]]; then
  cp "$REPO/git/gitconfig.local.example" "$HOME/.gitconfig.local"
  warn "created ~/.gitconfig.local — edit it with your git name and email"
fi
link "$REPO/ghostty/config"         "$HOME/.config/ghostty/config"
link "$REPO/wezterm/wezterm.lua"    "$HOME/.config/wezterm/wezterm.lua"
# GitHub CLI — only the shared config; hosts.yml (the tokens from
# `gh auth login`) is left out, gh creates it. Without gh installed the link is
# harmless (like the ghostty/wezterm one).
link "$REPO/gh/config.yml"          "$HOME/.config/gh/config.yml"
link "$REPO/p10k/welearncode.zsh"   "$HOME/.config/p10k/welearncode.zsh"
link "$REPO/p10k/classic.zsh"       "$HOME/.config/p10k/classic.zsh"
# Active p10k theme (standard path: ~/.p10k.zsh). Change with `p10kopt`.
link "$HOME/.config/p10k/welearncode.zsh" "$HOME/.p10k.zsh"

# opencode — user config only. Note: service.json (authentication
# token) and the runtime files (node_modules/, opencode-quota/)
# are NOT in the repo and are not touched.
link "$REPO/opencode/opencode.jsonc" "$HOME/.config/opencode/opencode.jsonc"
link "$REPO/opencode/cli.json"       "$HOME/.config/opencode/cli.json"
# tui.json was the V1 format: in V2 TUI plugins go in cli.json. The old
# symlink is removed (only if it points to the repo) so we don't leave a broken link.
if [[ -L "$HOME/.config/opencode/tui.json" ]]; then
  case "$(readlink "$HOME/.config/opencode/tui.json")" in
    "$REPO"/opencode/tui.json)
      rm -f "$HOME/.config/opencode/tui.json"
      echo "ok    removed $HOME/.config/opencode/tui.json (V1)"
      ;;
  esac
fi
link "$REPO/opencode/agents/security-auditor.md" \
  "$HOME/.config/opencode/agents/security-auditor.md"

# ── VS Code ──────────────────────────────────────────────────────────────────
# Keybindings via symlink; extensions are machine-specific binaries, so they
# are installed from vscode/extensions.txt (only the missing ones).
case "$OS" in
  Darwin) vscode_user_dir="$HOME/Library/Application Support/Code/User" ;;
  *)      vscode_user_dir="$HOME/.config/Code/User" ;;
esac
if [[ -d "$(dirname "$vscode_user_dir")" ]]; then
  link "$REPO/vscode/keybindings.json" "$vscode_user_dir/keybindings.json"

  code_cmd="$(command -v code || true)"
  [[ -z "$code_cmd" && -x "/Applications/Visual Studio Code.app/Contents/Resources/app/bin/code" ]] &&
    code_cmd="/Applications/Visual Studio Code.app/Contents/Resources/app/bin/code"
  if [[ -n "$code_cmd" ]]; then
    installed="$("$code_cmd" --list-extensions 2>/dev/null || true)"
    while read -r ext _comentario; do   # 2nd field: optional comment (# …)
      [[ -z "$ext" || "$ext" == \#* ]] && continue
      if ! printf '%s\n' "$installed" | grep -qx -- "$ext"; then
        echo "→ installing extension $ext"
        "$code_cmd" --install-extension "$ext" \
          || echo "WARNING: could not install $ext"
      fi
    done < "$REPO/vscode/extensions.txt"
  else
    echo "WARNING: 'code' command not found; install the extensions from vscode/extensions.txt manually"
  fi
else
  echo "WARNING: VS Code doesn't appear to be installed; skipping its config"
fi

# ── Default shell ────────────────────────────────────────────────────────────
# Point the login shell to zsh so the config is really loaded (without it bash
# keeps coming up and the aliases — `c`, `l`… — don't exist). chsh only accepts
# shells listed in /etc/shells, so zsh is added first if missing. It never
# aborts: if it can't (no sudo, password…), it warns and you can do it by hand.
zsh_path="$(command -v zsh || true)"
if [[ -z "$zsh_path" ]]; then
  warn "'zsh' is missing; cannot set it as the default shell"
elif [[ "$(basename "${SHELL:-}")" == "zsh" ]]; then
  ok "default shell is already zsh"
elif ! have chsh; then
  warn "no 'chsh'; set zsh as the default shell manually:  chsh -s $zsh_path"
else
  if ! grep -qx "$zsh_path" /etc/shells 2>/dev/null; then
    printf '%s\n' "$zsh_path" | $SUDO tee -a /etc/shells >/dev/null 2>&1 ||
      warn "could not add $zsh_path to /etc/shells"
  fi
  if $SUDO chsh -s "$zsh_path" "$(id -un 2>/dev/null)" 2>/dev/null ||
     chsh -s "$zsh_path" 2>/dev/null; then
    ok "default shell set to zsh (open a new terminal or log in again)"
  else
    warn "could not set zsh as the default shell; run:  chsh -s \"$zsh_path\""
  fi
fi

# ── Platform apps ────────────────────────────────────────────────────────────
# Delegates to the installer that matches the detected OS; each one re-detects
# distro/manager on its own (idempotent, like everything else):
#   macOS → macos/Brewfile (brew bundle)  ·  Linux → linux/apps.txt (per distro)
if [[ "${DOTFILES_SKIP_APPS:-0}" == "1" ]]; then
  info "apps skipped (DOTFILES_SKIP_APPS=1)"
else
  if [[ "$OS" == "Darwin" ]]; then
    APPS_SCRIPT="$REPO/macos/install-apps.sh"
  else
    APPS_SCRIPT="$REPO/linux/install-apps.sh"
  fi
  if [[ -x "$APPS_SCRIPT" ]]; then
    info "installing apps · $ENTORNO"
    "$APPS_SCRIPT" || warn "some app failed; run again to retry: $APPS_SCRIPT"
  else
    warn "apps installer not found: $APPS_SCRIPT"
  fi
fi

echo
echo "Done. Open a new terminal (or: source ~/.zshrc)."
echo "Switch p10k theme: p10kopt classic  |  p10kopt welearncode"
