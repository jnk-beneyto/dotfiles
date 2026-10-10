# Powerlevel10k config — "classic" look.
# p10k powerline style (colored ⯈ ⯆ separators) with a 256-color palette.
# NOTE: the powerline glyphs (and the system icon) are from a Nerd Font: to see
# this look correctly you need to install e.g. MesloLGS NF.
#
# Enable this look:  p10kopt classic
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
  typeset -g POWERLEVEL9K_LEFT_PROMPT_ELEMENTS=(os_icon dir vcs node_version)
  typeset -g POWERLEVEL9K_RIGHT_PROMPT_ELEMENTS=(time)

  typeset -g POWERLEVEL9K_MODE=nerdfont-complete
  typeset -g POWERLEVEL9K_INSTANT_PROMPT=quiet

  # ── Colors (256-color palette) ──────────────────────────────────────────────
  typeset -g POWERLEVEL9K_OS_ICON_FOREGROUND=215
  typeset -g POWERLEVEL9K_DIR_FOREGROUND=39
  typeset -g POWERLEVEL9K_VCS_CLEAN_FOREGROUND=84
  typeset -g POWERLEVEL9K_VCS_DIRTY_FOREGROUND=214
  typeset -g POWERLEVEL9K_VCS_UNTRACKED_FOREGROUND=214
  typeset -g POWERLEVEL9K_VCS_AHEAD_FOREGROUND=84
  typeset -g POWERLEVEL9K_VCS_BEHIND_FOREGROUND=214
  typeset -g POWERLEVEL9K_NODE_VERSION_FOREGROUND=148
  typeset -g POWERLEVEL9K_TIME_FOREGROUND=249
  typeset -g POWERLEVEL9K_PROMPT_CHAR_FOREGROUND=84

  # ⬢ (U+2B22) is standard Unicode: the Nerd Font glyph \ue718 does not exist in
  # JetBrains Mono and would be drawn as a white square.
  typeset -g POWERLEVEL9K_NODE_ICON='⬢ '

  # Show the segment only when typing the corresponding command (the wizard's default).
  typeset -g POWERLEVEL9K_VIRTUALENV_SHOW_WITH_PYTHON=false
  typeset -g POWERLEVEL9K_BUN_SHOW_WITH_UV=false
}

# Temporarily change options.
if (( ${#p10k_config_opts} )); then
  'builtin' 'setopt' "${p10k_config_opts[@]}"
  'builtin' 'unset' 'p10k_config_opts'
fi
