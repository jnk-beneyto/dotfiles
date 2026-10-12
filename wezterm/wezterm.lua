-- Helper function:
-- returns color scheme dependant on operating system theme setting (dark/light)
local function color_scheme_for_appearance(appearance)
  if appearance:find "Dark" then
    return "Tokyo Night"          -- ghostty: theme = dark:TokyoNight
  else
    return "Tokyo Night Day"      -- ghostty: theme = light:TokyoNight Day
  end
end

-- Color palette shared with p10k/welearncode.zsh. Tokyo Night stays as the base
-- scheme (so ANSI colors for ls/git/etc. keep working); this palette drives the
-- UI chrome WezTerm owns — cursor, selection, splits, scrollbar, QuickSelect and
-- the tab bar — so the terminal and the shell prompt read as one design.
local function palette_for_appearance(appearance)
  local dark = appearance:find 'Dark'
  return {
    -- Accents (same hex as p10k/welearncode.zsh)
    cyan   = '#62e0fd', -- paths · QuickSelect matches
    lilac  = '#ab75f8', -- branches · pane splits
    salmon = '#f07155', -- dirty · QuickSelect labels
    green  = '#8af46b', -- clean · cursor
    gray   = '#9ca1a1', -- muted text · scrollbar
    -- Tokyo Night (dark) · Tokyo Night Day (light) neutrals
    bg           = dark and '#1a1b26' or '#e1e2e7',
    surface      = dark and '#24263a' or '#d0d3de',
    fg           = dark and '#c0caf5' or '#3760bf',
    cursor_fg    = dark and '#1a1b26' or '#e1e2e7',
    selection_bg = dark and '#33467c' or '#b7c1e3',
  }
end

-- Pull in WezTerm API
local wezterm = require 'wezterm'

-- Initialize actual config
local config = {}
if wezterm.config_builder then
  config = wezterm.config_builder()
end

-- Appearance
-- Font: families in order of preference. The exact name varies by
-- Nerd Fonts version and platform (NF v3: "JetBrainsMono Nerd Font",
-- NF v2/Windows: "JetBrains Mono Nerd Font"); if the first is missing, WezTerm
-- uses the next one. "Symbols Nerd Font Mono" ships with WezTerm and covers
-- p10k icons even if the main font fails.
config.font = wezterm.font_with_fallback {
  'JetBrainsMono Nerd Font',
  'JetBrains Mono Nerd Font',
  'JetBrains Mono',
  'Menlo',
}
config.font_size = 14.0

local appearance = wezterm.gui.get_appearance()
local palette = palette_for_appearance(appearance)
config.color_scheme = color_scheme_for_appearance(appearance)
-- p10k accents on the pieces WezTerm controls (cursor, selection, scrollbar,
-- split, tab bar). The palette mirrors p10k/welearncode.zsh so the terminal and
-- the shell prompt look like the same design.
config.colors = {
  -- Cursor: same green as the p10k prompt char (❯)
  cursor_bg = palette.green,
  cursor_border = palette.green,
  cursor_fg = palette.cursor_fg,
  -- Selection and split panes
  selection_bg = palette.selection_bg,
  selection_fg = palette.fg,
  split = palette.lilac,
  -- Chrome
  scrollbar_thumb = palette.gray,
  compose_cursor = palette.salmon,
  visual_bell = palette.salmon,
  -- QuickSelect (CTRL-SHIFT-A): salmon labels, cyan matches
  quick_select_label_bg = palette.salmon,
  quick_select_label_fg = palette.bg,
  quick_select_match_bg = palette.cyan,
  quick_select_match_fg = palette.bg,
  -- Tab bar (only shows with more than one tab)
  tab_bar = {
    background = palette.bg,
    active_tab = { bg_color = palette.cyan, fg_color = palette.bg, intensity = 'Bold' },
    inactive_tab = { bg_color = palette.bg, fg_color = palette.gray },
    inactive_tab_hover = { bg_color = palette.surface, fg_color = palette.lilac },
    new_tab = { bg_color = palette.bg, fg_color = palette.gray },
    new_tab_hover = { bg_color = palette.surface, fg_color = palette.lilac },
  },
}
config.default_cursor_style = 'BlinkingBlock' -- ghostty: cursor-style = block + blink

-- Same as ghostty/config: background-opacity = 0.96 · background-blur = true.
-- NOTE: macos_window_background_blur is a RADIUS (number), not a boolean; it
-- only takes effect on macOS and requires opacity < 1.
config.window_background_opacity = 0.96
config.macos_window_background_blur = 20
-- Same padding as ghostty/config (x = 12 · y = 10).
config.window_padding = { left = 12, right = 12, top = 10, bottom = 10 }
config.window_decorations = "RESIZE"
config.hide_tab_bar_if_only_one_tab = true
config.native_macos_fullscreen_mode = false

-- Keybindings
config.keys = {
  -- Default QuickSelect keybind (CTRL-SHIFT-Space) gets captured by something
  -- else on my system
  {
    key = 'A',
    mods = 'CTRL|SHIFT',
    action = wezterm.action.QuickSelect,
  },
}

-- Return config to WezTerm
return config

