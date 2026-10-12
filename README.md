# dotfiles

Repo: **[github.com/jnk-beneyto/dotfiles](https://github.com/jnk-beneyto/dotfiles)**

Minimalist terminal setup for **macOS and Linux**: zsh + oh-my-zsh +
powerlevel10k + Ghostty + WezTerm + git.

## Structure

| In the repo | Installs to |
|---|---|
| `zsh/zshenv` | `~/.zshenv` (minimal environment; always loaded) |
| `zsh/zprofile` | `~/.zprofile` (login: Homebrew on `PATH`; non-interactive — `HOMEBREW_NO_ASK=1` and, on Linux, `DEBIAN_FRONTEND=noninteractive`/`NEEDRESTART_MODE=a`) |
| `zsh/zshrc` | `~/.zshrc` |
| `zsh/path` | the whole `PATH` in one list (node via nvm · `~/.local/bin`, `~/.opencode/bin`, `~/.cargo/bin`… · mysql-client · flatpak) + `BUN_INSTALL`; loaded by `zprofile` **and** `zshrc` from the repo (not symlinked separately) → § [PATH and exports](#path-and-exports) |
| `zsh/aliases` | user aliases; loaded by `zsh/zshrc` from the repo (not symlinked separately) |
| `git/gitconfig` | `~/.gitconfig` (shared: settings, `core.excludesFile` and the **git-delta** pager; git aliases come from oh-my-zsh's `git` plugin) |
| `git/ignore` | `~/.config/git/ignore` (global git ignores) |
| `git/gitconfig.local.example` | identity template; the installer creates `~/.gitconfig.local` if missing |
| `ghostty/config` | `~/.config/ghostty/config` |
| `wezterm/wezterm.lua` | `~/.config/wezterm/wezterm.lua` |
| `gh/config.yml` | `~/.config/gh/config.yml` (GitHub CLI; tokens go in `hosts.yml`, outside the repo) |
| `p10k/welearncode.zsh` | `~/.config/p10k/welearncode.zsh` (active theme) |
| `p10k/classic.zsh` | `~/.config/p10k/classic.zsh` (alternate theme) |
| `opencode/opencode.jsonc` | `~/.config/opencode/opencode.jsonc` |
| `opencode/cli.json` | `~/.config/opencode/cli.json` |
| `opencode/agents/` | `~/.config/opencode/agents/` |
| `vscode/keybindings.json` | `~/Library/Application Support/Code/User/` (macOS) · `~/.config/Code/User/` (Linux) |
| `vscode/extensions.txt` | extension list; the installer installs any missing ones (`code --install-extension`) |
| _(created by the installer)_ | `~/.p10k.zsh` → symlink to the active theme |
| `install.sh` | installer (macOS / Linux); run directly or via `curl … \| bash`, which downloads the repo itself |
| `macos/Brewfile` | macOS app list (formulae, casks, and App Store entries) |
| `macos/install-apps.sh` | installs those apps with `brew bundle` (macOS only) |
| `macos/defaults.sh` | macOS system preferences (Finder, Dock, keyboard…) — run manually |
| `lib/platform.sh` | shared environment detection: OS, distro (`/etc/os-release`) and package manager; on Linux, `autoconfirm_linux` makes apt/needrestart/debconf non-interactive |
| `linux/apps.txt` | Linux app list (one id per line, editable) |
| `linux/install-apps.sh` | installs those apps, mapped to the detected distro |
| `windows/` | reserved for the future (PowerShell) |

Files are linked via **symlinks**: the repo is the single source of truth.
The installer **overwrites whatever it finds**: any previous state is
replaced by the dotfile's.

### Per-machine customization

To keep machine-specific stuff out of the repo, local files are
loaded at the end and **never versioned or overwritten**:

- `~/.zshenv.local`, `~/.zprofile.local`, `~/.zshrc.local` — environment, `PATH`,
  aliases or tokens for that machine.
- `~/.gitconfig.local` — your git identity. The installer creates it from
  `git/gitconfig.local.example` the first time; edit it and it stays out of
  version control.

Example `~/.gitconfig.local` (your identity; not versioned):

```ini
# ~/.gitconfig.local  (not versioned)
[user]
	name = Tu Nombre
	email = tu@email.com
```

### PATH and exports

Every export the config does lives in one of three versioned files, and all
of them load automatically in **every** zsh (login, interactive and scripts):

| File | What it exports |
|---|---|
| `zsh/zshenv` | `XDG_CONFIG_HOME` · `XDG_CACHE_HOME` · `XDG_DATA_HOME` · `XDG_STATE_HOME` |
| `zsh/zprofile` | Homebrew (`brew shellenv`: `PATH`, `MANPATH`, `INFOPATH`), `HOMEBREW_NO_ASK`, and on Linux `DEBIAN_FRONTEND`/`NEEDRESTART_MODE` |
| `zsh/path` | the whole `PATH` in order of precedence — node (nvm) · mysql-client · `~/.local/bin` · `~/bin` · `~/.opencode/bin` · `~/.bun/bin` · `~/.cargo/bin` · pnpm · flatpak… — and `BUN_INSTALL` |

`zsh/path` is sourced by **both** `zprofile` (login shells: new terminals,
SSH, scripts) and `zshrc` (interactive shells: tmux panes, a `zsh` inside a
session), and each directory is added only if it exists and only once — so
on a new terminal there's **nothing to export by hand**: just open it.

**To apply a change in an already-open shell** (after editing any of the
three files):

```sh
exec zsh -l    # re-runs zshenv → zprofile → zshrc in place
```

or, without leaving the session:

```sh
source ~/.zshenv; source ~/.zprofile; source ~/.zshrc
```

**To check that everything is exported**:

```zsh
echo $PATH | tr ':' '\n'                     # every dir, in order (first = wins)
whence -v node npm opencode eza fzf delta    # the tools the config needs resolve
```

**A new tool installs a binary somewhere else?** Add one line to the
`_path_dirs` list in `zsh/path`, at the position matching its precedence
(first listed = first on `PATH`), and it's exported in every shell from
then on — no other file to touch.

## Requirements

- `zsh`. `git` is recommended (the quick install clones with it, so `~/dotfiles`
  is updatable); without it the installer downloads a tarball instead
- A package manager: [Homebrew](https://brew.sh/) on macOS, or
  `apt` / `dnf` / `pacman` on Linux
- [Ghostty](https://ghostty.org/) with the **JetBrains Mono** font
- [oh-my-zsh](https://ohmyz.sh/), `eza`, `node` (via nvm) and the font:
  **if missing, `install.sh` installs them itself**

### What the installer sets up

Everything the config needs is installed automatically when you run it
(via the package manager, on both macOS and Linux):

| Tool | What the config needs it for | If unavailable |
|---|---|---|
| `git`, `zsh` | cloning the repo and plugins; the shell | warns and continues |
| `eza` | **all** the aliases in `zsh/aliases` (`ls`, `ll`, `la`, `lt`…) | warns and continues |
| `git-delta` | git pager (`git log`, `git diff`…) and interactive mode (`add -p`) | warns and continues (git runs without a pager) |
| `fzf` | oh-my-zsh's `fzf` plugin: CTRL-T / CTRL-R / ALT-C and completion | warns and continues |
| `oh-my-zsh` | `zshrc` runs `source $ZSH/oh-my-zsh.sh` | clones it; **if unavailable, errors and stops** before symlinking `~/.zshrc` |
| `powerlevel10k`, `zsh-autosuggestions`, `zsh-syntax-highlighting` | the `zshrc` theme and plugins | warns (offline?) |
| `nvm` + `node` | node PATH and the `nrd` alias (`npm run dev`) | warns and continues |
| JetBrains Mono (Nerd Font) | `ghostty/config` + p10k icons | warns (installed via brew on macOS) |
| VS Code extensions | from `vscode/extensions.txt` | warns with manual instructions |

Warned only (not auto-installed because its setup requires sudo):
**Homebrew** (on macOS) — in the § Installation flow, the new-machine block
installs it first. Platform apps —Ghostty,
WezTerm, VS Code…— are installed at the end, from their lists (see § Apps).

The default node version it installs is `v22.17.1`; you can change it
without editing the script:

```sh
DOTFILES_NODE_VERSION=v20.12.2 ./install.sh
```

## Installation

It's all copy and paste: nothing to type (only `sudo` prompts and OS
dialogs).

### Quick install (one command)

`install.sh` downloads the repo on its own and runs itself — **no manual
clone**. It puts the dotfiles in `~/dotfiles` (that copy is what the
symlinks point to) and then installs the config, the tools and the apps:

```sh
curl -sSL https://raw.githubusercontent.com/jnk-beneyto/dotfiles/main/install.sh | bash
```

It uses `git` when available (so `~/dotfiles` is a real clone you can
`git pull`); if `git` is missing it falls back to a tarball with
`curl`/`wget`. A different destination:

```sh
curl -sSL …/install.sh | DOTFILES_DIR=~/.dotfiles bash
```

### On a new machine

**macOS** — a single block. If CommandLineTools (git) are missing, the
dialog is launched and the block itself **waits for it to finish** before
continuing. Then Homebrew and the one-liner:

```sh
# CommandLineTools (git): if missing, launch the dialog and wait for it to finish
xcode-select -p >/dev/null 2>&1 || {
  xcode-select --install 2>/dev/null
  echo "→ Install CommandLineTools in the dialog; waiting here…"
  until xcode-select -p >/dev/null 2>&1; do sleep 10; done
}

# Homebrew + install EVERYTHING (config, tools and apps)
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
eval "$(/opt/homebrew/bin/brew shellenv 2>/dev/null || /usr/local/bin/brew shellenv)"
curl -sSL https://raw.githubusercontent.com/jnk-beneyto/dotfiles/main/install.sh | bash
```

**Linux** — a single block:

```sh
curl -sSL https://raw.githubusercontent.com/jnk-beneyto/dotfiles/main/install.sh | bash
```

Options go **after the pipe** (they are passed to `bash`, not to `curl`):

```sh
curl -sSL …/install.sh | DOTFILES_SKIP_APPS=1 bash          # config only, no apps
curl -sSL …/install.sh | DOTFILES_NODE_VERSION=v20.12.2 bash
```

<details>
<summary>Prefer cloning it yourself?</summary>

```sh
git clone https://github.com/jnk-beneyto/dotfiles.git ~/dotfiles
cd ~/dotfiles
./install.sh
```

</details>

### After the installer

Final block (`gh` and `opencode` are optional: comment out their lines if
you don't want them). The final `exec` drops you into zsh with everything
loaded —or open a new terminal—:

```sh
# Default shell zsh (no-op if already set; asks for your password)
[ "$(basename "${SHELL:-}")" = zsh ] || chsh -s "$(command -v zsh)"

# GitHub CLI (optional): link your account → creates ~/.config/gh/hosts.yml
command -v gh >/dev/null && gh auth login

# opencode (optional): binary at ~/.opencode/bin; config is already symlinked
[ -x "$HOME/.opencode/bin/opencode" ] || curl -fsSL https://opencode.ai/install | bash

# Drop into zsh with everything loaded
exec zsh -l
```

The only remaining manual steps (and only if you care):

- **Git identity** if this machine uses a different name/email:
  `nano ~/.gitconfig.local` (the template already ships with this machine's).
- **macOS** — system preferences (Finder, Dock…), run manually since they
  touch the system: `./macos/defaults.sh` (with `DOTFILES_DRY_RUN=1` first,
  it only shows what it would do; see § System preferences).
- **If something failed** (offline, an app): paste `./install.sh` —or the
  curl one-liner— again; it's idempotent and retries only what's missing.

### What it overwrites

The goal is for every run to leave the machine **exactly as the dotfile
describes**:

- **Files** (`~/.zshrc`, `~/.gitconfig`, configs…): replaced with a
  symlink to the repo. If the destination had other content, it's backed
  up first as `<file>.bak.<timestamp>`.
- **oh-my-zsh, powerlevel10k and plugins**: restored to their upstream
  state (`git reset --hard` + cleanup of untracked files —caches, old
  themes or plugins—). If what's there isn't a valid clone, it's backed
  up (`<folder>.bak.<timestamp>`) and cloned from scratch.
- **Offline, nothing is destroyed**: what's there is kept and a warning
  is shown.

It's idempotent: you can run it again at any time (e.g. after a
`git pull`).

## Apps (automatic)

`install.sh` detects the environment **on its own** (OS → distro via
`/etc/os-release` → package manager, all in `lib/platform.sh`) and at the
end installs the apps for each platform:

| Platform | List (what you edit) | Installer | How each app is mapped |
|---|---|---|---|
| macOS | `macos/Brewfile` | `macos/install-apps.sh` | `brew bundle` (formulae, casks, `mas`) |
| Linux | `linux/apps.txt` | `linux/install-apps.sh` | per distro: native package · official repo · flatpak · AppImage · official script · AUR |

```sh
./install.sh                 # config + apps (everything, one command)
DOTFILES_SKIP_APPS=1 ./install.sh   # config only, no apps
./linux/install-apps.sh      # retry only Linux apps
./macos/install-apps.sh      # retry only macOS apps
```

- **Idempotent**: only installs what's missing; never uninstalls. If an
  app fails, it warns and moves on (a second run retries).
- **Edit the selection**: in `macos/Brewfile` the `brew`/`cask` lines; in
  `linux/apps.txt` one id per line (`#` comments). Then, `./install.sh`.
- **Per-distro mapping** (Linux): the list only holds ids and the mapper is
  `linux/install-apps.sh`, e.g. `ghostty` → `apt install ghostty` (Ubuntu,
  with a PPA if needed), community `.deb` on Debian, COPR on Fedora,
  `pacman -S` on Arch; `tableplus` → TablePlus official repo; `obsidian` →
  GitHub AppImage…
- **Covered on Ubuntu/Debian, Fedora and Arch**: if something isn't in the
  repos, the next official source is used instead of just warning —
  `telegram` → Flathub, `1password` → direct `.deb` (apt) and RPM repo
  (dnf), `ffmpeg` → `ffmpeg-free` on Fedora, and on Arch, if no AUR helper
  is present, `yay` is installed the first time it's needed.
- **App Store (macOS)**: *Unzip* is installed via `mas` if you're signed
  in; otherwise it warns with a link.
- **Availability and config**: which OS installs each app → § Availability
  by system; each app's settings → § App configurations.

### Availability by system

All apps in `macos/Brewfile` and `linux/apps.txt` (plus `opencode`), which
OS installs them, and whether any need config:

| App | macOS | Linux | config? |
|---|:---:|:---:|---|
| **Productivity and communication** | | | |
| 1Password | ✓ | ✓ | — |
| Obsidian | ✓ | ✓ | — |
| Spotify | ✓ | ✓ | — |
| Telegram | ✓ | ✓ | — |
| Discord | ✓ | ✗ | — |
| Google Chrome | ✓ | ✓ | — |
| Brave Browser | ✓ | ✗ | — |
| Notion | ✓ | ✗ | — |
| WhatsApp | ✓ | ✗ | [yes](#whatsapp) |
| **Development** | | | |
| Docker (CLI + Desktop) | ✓ | ✓ | — |
| gh | ✓ | ✓ | [yes](#gh) |
| Ollama | ✓ | ✗ | — |
| opencode | ✓³ | ✓³ | [yes](#opencode) |
| TablePlus | ✓ | ✓ | — |
| VS Code | ✓ | ✗ | [yes](#vs-code) |
| Ghostty | ✓ | ✓ | [yes](#ghostty) |
| WezTerm | ✓ | ✓ | [yes](#wezterm) |
| **Utilities** | | | |
| Alfred | ✓ | ✗ | — |
| Rectangle | ✓ | ✗ | — |
| Balena Etcher | ✓ | ✓ | — |
| Unzip | ✓ | ✗ | — |
| JetBrains Mono (Nerd Font) | ✓ | ✗² | — |
| **CLI** | | | |
| htop | ✓ | ✓ | — |
| tree | ✓ | ✓ | — |
| yt-dlp | ✓ | ✓ | — |
| ffmpeg | ✓ | ✓ | — |
| eza | ✓ | ✓¹ | — |
| fzf | ✓ | ✓¹ | — |
| git-delta | ✓ | ✓¹ | — |
| pnpm | ✓ | ✓¹ | — |
| bat | ✓ | ✗ | — |
| fd | ✓ | ✗ | — |
| jq | ✓ | ✗ | — |
| ripgrep | ✓ | ✗ | — |
| shellcheck | ✓ | ✗ | — |
| shfmt | ✓ | ✗ | — |
| stylua | ✓ | ✗ | — |
| wget | ✓ | ✗ | — |
| yq | ✓ | ✗ | — |
| zoxide | ✓ | ✗ | — |
| mas | ✓ | ✗ | — |

- `✓` = the app is installed on that OS (`Brewfile` · `apps.txt` ·
  `install.sh`); `✗` = not in that OS's list.
- ¹ On Linux, `eza`, `fzf`, `git-delta` and `pnpm` are provided by
  `install.sh` (they're not in `linux/apps.txt`).
- ² On Linux the font isn't auto-installed: `install.sh` warns with a link
  to Nerd Fonts (on macOS the Brewfile provides it).
- ³ `opencode` isn't in the lists: it's installed via the final block in
  § After the installer (on both OSes).
- `config?`: `—` = no steps; the link jumps to that app's section in
  [App configurations](#app-configurations).

### App configurations

What this repo manages per app —everything is symlinked automatically when
you run `./install.sh`— and the remaining manual steps. The links in the
`config?` column of the table above point here.

#### Ghostty

- **In the repo**: [`ghostty/config`](ghostty/config) →
  `~/.config/ghostty/config`.
- **Defines**: Tokyo Night light/dark theme depending on the OS (same as
  WezTerm), JetBrains Mono 14 font, padding, cursor, scrollback, 0.96
  opacity + blur, and tabs in the titlebar.
- **Without the app** the symlink is harmless (§ What the installer sets
  up warns about it).

#### WezTerm

- **In the repo**: [`wezterm/wezterm.lua`](wezterm/wezterm.lua) →
  `~/.config/wezterm/wezterm.lua`.
- **Defines**: same Tokyo Night scheme by system appearance, Nerd font
  fallback, opacity/blur, decorations, and a minimal tab bar. Formatted
  with `stylua`.

#### VS Code

- **In the repo**: [`vscode/keybindings.json`](vscode/keybindings.json) →
  `~/Library/Application Support/Code/User/` (macOS) ·
  `~/.config/Code/User/` (Linux); and [`vscode/extensions.txt`](vscode/extensions.txt),
  which the installer turns into `code --install-extension` (only missing
  ones).
- **Defines**: git shortcuts (stage/unstage/stash/merge-abort), sort
  lines, etc.
- **Outside the repo**: `settings.json`, `mcp.json` and snippets (§ What's
  NOT in this repo).

#### gh

- **In the repo**: [`gh/config.yml`](gh/config.yml) → `~/.config/gh/config.yml`.
- **Defines**: `git_protocol: https`, aliases (`gh co` → `pr checkout`),
  prompts and spinner. Change with `gh config set <key> <value>`.
- **Outside the repo**: `hosts.yml` with the tokens from `gh auth login`
  (created by `gh`; the final install block launches that link).

#### opencode

- **In the repo**: `opencode/opencode.jsonc` →
  `~/.config/opencode/opencode.jsonc` (providers: local Ollama at
  `localhost:11434`, Copilot, OpenRouter; quota plugin),
  `opencode/cli.json` (TUI plugins) and
  `opencode/agents/security-auditor.md`.
- **Outside the repo**: `service.json` (auth token) and the runtime
  (`node_modules/`, `opencode-quota/`).

#### WhatsApp

- **macOS**: official cask, no config.

### System preferences (macOS)

`macos/defaults.sh` applies Finder, Dock, keyboard, screenshots, etc.
settings via `defaults write`. `install.sh` does **not** run it (it
touches the system); run it yourself:

```sh
./macos/defaults.sh                       # applies
DOTFILES_DRY_RUN=1 ./macos/defaults.sh    # only shows what it would do
```

## Daily use

- **Switch the prompt theme**: `p10kopt welearncode` · `p10kopt classic`
  (or `p10kopt` alone, to list what's available).
- **Edit**: edits happen in the repo.
  - p10k changes: `source ~/.p10k.zsh` applies them in the current
    session.
  - `.zshrc` changes: new terminal (or `source ~/.zshrc`).
- **Update on another machine**: `cd ~/dotfiles && git pull && ./install.sh`
  (or paste the curl one-liner again: it pulls and re-installs).

## Support by system

| OS | Status |
|---|---|
| macOS | ✅ |
| Linux | ✅ |
| Windows | 🚧 `windows/powershell/` folder reserved |

## What's NOT in this repo

Files that depend on the machine or may contain credentials are not
included: `~/.ssh/`, API keys, tokens…

- **opencode**: only the user config (`opencode.jsonc`, `cli.json`,
  `agents/`); `service.json` (auth token) and the runtime
  (`node_modules/`, `opencode-quota/`) stay out, also protected by
  `opencode/.gitignore` just in case.
- **VS Code**: only keybindings and the extension list; `settings.json`,
  `mcp.json` and snippets stay out (they contain local paths and more
  volatile preferences).
- **gh**: only `config.yml` (protocol, aliases…); `hosts.yml`, with the
  tokens from `gh auth login`, stays in `~/.config/gh/` outside the repo.
