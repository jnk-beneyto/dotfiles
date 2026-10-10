# Powerlevel10k config — "welearncode" look.
# Single line, no powerline, standard Unicode/emoji icons (compatible with
# JetBrains Mono, no Nerd Font required). Palette taken from the reference
# image: cyan #62e0fd · lilac #ab75f8 · salmon #f07155 · green #8af46b ·
# gray #9ca1a1.
#
# Enable this look:  p10kopt welearncode
# Apply changes in the current session:  source ~/.p10k.zsh

# Temporarily change options.
'builtin' 'local' '-a' 'p10k_config_opts'
[[ ! -o 'aliases'         ]] || p10k_config_opts+=('aliases')
[[ ! -o 'sh_glob'         ]] || p10k_config_opts+=('sh_glob')
[[ ! -o 'no_brace_expand' ]] || p10k_config_opts+=('no_brace_expand')
'builtin' 'setopt' 'no_aliases' 'no_sh_glob' 'brace_expand'

() {
  emulate -L zsh -o extended_glob

  # Unset all configuration options. This allows you to apply configuration
  # changes without restarting zsh (edit this file and type `source ~/.p10k.zsh`).
  unset -m '(POWERLEVEL9K_*|DEFAULT_USER)~POWERLEVEL9K_GITSTATUS_DIR'

  # Zsh >= 5.1 is required.
  [[ $ZSH_VERSION == (5.<1->*|<6->.*) ]] || return

  # ── Segments ────────────────────────────────────────────────────────────────
  typeset -g POWERLEVEL9K_LEFT_PROMPT_ELEMENTS=(dir vcs package node_version)
  typeset -g POWERLEVEL9K_RIGHT_PROMPT_ELEMENTS=(time)

  typeset -g POWERLEVEL9K_MODE=nerdfont-complete
  typeset -g POWERLEVEL9K_INSTANT_PROMPT=quiet

  # Flat prompt: no background on segments (if unset, p10k uses the default
  # backgrounds — blue for dir, etc. — and the prompt looks powerline).
  typeset -g POWERLEVEL9K_BACKGROUND=

  # ── Separators and prompt character ────────────────────────────────────────
  # No powerline: gray `·` between segments, no space between icon and value
  # (⬢v22.17.1, not "⬢v 22.17.1").
  typeset -g POWERLEVEL9K_LEFT_SEGMENT_SEPARATOR=
  typeset -g POWERLEVEL9K_RIGHT_SEGMENT_SEPARATOR=
  typeset -g POWERLEVEL9K_LEFT_SEGMENT_END_SEPARATOR=
  typeset -g POWERLEVEL9K_RIGHT_SEGMENT_END_SEPARATOR=
  typeset -g POWERLEVEL9K_LEFT_MIDDLE_WHITESPACE=
  typeset -g POWERLEVEL9K_LEFT_SUBSEGMENT_SEPARATOR='%F{#9ca1a1}·%f'
  typeset -g POWERLEVEL9K_RIGHT_SUBSEGMENT_SEPARATOR='%F{#9ca1a1}·%f'

  typeset -g POWERLEVEL9K_PROMPT_CHAR='%F{#8af46b}❯%f '

  # ── Icons (standard Unicode, no Nerd Font required) ────────────────────────
  typeset -g POWERLEVEL9K_DIR_VISUAL_IDENTIFIER_EXPANSION=

  # No stashes: by removing `git-stash` from the hooks, gitstatusd neither
  # computes nor shows it (and the prompt is a tad faster).
  typeset -g POWERLEVEL9K_VCS_GIT_HOOKS=(vcs-detect-changes git-untracked git-aheadbehind git-remotebranch git-tagname)

  # "Host" icons (GitHub, GitLab, …): they are Nerd Font glyphs that would be
  # white squares in JetBrains Mono, and the image does not show them.
  typeset -g POWERLEVEL9K_VCS_GIT_ICON=
  typeset -g POWERLEVEL9K_VCS_GIT_GITHUB_ICON=
  typeset -g POWERLEVEL9K_VCS_GIT_GITLAB_ICON=
  typeset -g POWERLEVEL9K_VCS_GIT_BITBUCKET_ICON=
  typeset -g POWERLEVEL9K_VCS_GIT_AZURE_ICON=
  typeset -g POWERLEVEL9K_VCS_GIT_CODEBERG_ICON=
  typeset -g POWERLEVEL9K_VCS_HG_ICON=
  typeset -g POWERLEVEL9K_VCS_SVN_ICON=

  typeset -g POWERLEVEL9K_VCS_BRANCH_ICON='%F{#ab75f8}⎇%f '
  typeset -g POWERLEVEL9K_VCS_BRANCHFORMAT_FOREGROUND=#ab75f8   # branch name
  typeset -g POWERLEVEL9K_VCS_DIRTY_ICON='%F{#f07155} [!]%f'    # [!] salmon, as in the image
  typeset -g POWERLEVEL9K_VCS_STAGED_ICON='%F{#8af46b}✔%f'
  typeset -g POWERLEVEL9K_VCS_UNSTAGED_ICON='%F{#f07155}✚%f'
  typeset -g POWERLEVEL9K_VCS_UNTRACKED_ICON='%F{#f07155}?%f'
  typeset -g POWERLEVEL9K_VCS_INCOMING_CHANGES_ICON='%F{#f07155}↓%f'
  typeset -g POWERLEVEL9K_VCS_OUTGOING_CHANGES_ICON='%F{#8af46b}↑%f'
  typeset -g POWERLEVEL9K_VCS_TAG_ICON='%F{#9ca1a1}#%f'
  typeset -g POWERLEVEL9K_VCS_BOOKMARK_ICON='%F{#9ca1a1}@%f'
  typeset -g POWERLEVEL9K_VCS_LOCK_ICON='%F{#9ca1a1}🔒%f'

  # ⬢ (U+2B22) is standard Unicode: the Nerd Font glyph \ue718 does not exist in
  # JetBrains Mono and was drawn as a white square.
  typeset -g POWERLEVEL9K_NODE_ICON='%F{#8af46b}⬢v%f'

  # "is 📦v0.0.0" as in the image. 📦 (U+1F4E6) is a system emoji.
  # Only appears in projects with package.json.
  typeset -g POWERLEVEL9K_PACKAGE_ICON='%F{#9ca1a1} is %f📦%F{#f07155}v%f'
  typeset -g POWERLEVEL9K_PACKAGE_FOREGROUND=#f07155

  # The format goes inside %D{...} (prompt expansion), not strftime.
  typeset -g POWERLEVEL9K_TIME_ICON='%F{#9ca1a1}◷%f '
  typeset -g POWERLEVEL9K_TIME_FORMAT='%D{%H:%M}'
  typeset -g POWERLEVEL9K_TIME_ICON_POSITION=left

  # ── Path and colors ─────────────────────────────────────────────────────────
  # Only the last path element: the repo name in a repo, "~" at home.
  typeset -g POWERLEVEL9K_SHORTEN_STRATEGY=truncate_to_last
  typeset -g POWERLEVEL9K_SHORTEN_DIR_LENGTH=1

  typeset -g POWERLEVEL9K_DIR_FOREGROUND=#62e0fd             # cyan    → path
  typeset -g POWERLEVEL9K_DIR_PATH_HIGHLIGHT_BOLD=false

  typeset -g POWERLEVEL9K_VCS_CLEAN_FOREGROUND=#8af46b       # green   → clean branch
  typeset -g POWERLEVEL9K_VCS_DIRTY_FOREGROUND=#f07155       # salmon  → changes
  typeset -g POWERLEVEL9K_VCS_UNTRACKED_FOREGROUND=#f07155
  typeset -g POWERLEVEL9K_VCS_AHEAD_FOREGROUND=#8af46b
  typeset -g POWERLEVEL9K_VCS_BEHIND_FOREGROUND=#f07155

  typeset -g POWERLEVEL9K_NODE_VERSION_FOREGROUND=#8af46b    # green   → node version
  typeset -g POWERLEVEL9K_TIME_FOREGROUND=#9ca1a1            # gray    → time
}

# Temporarily change options.
if (( ${#p10k_config_opts} )); then
  'builtin' 'setopt' "${p10k_config_opts[@]}"
  'builtin' 'unset' 'p10k_config_opts'
fi
