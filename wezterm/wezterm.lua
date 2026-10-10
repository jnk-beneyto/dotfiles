-- Helper function:
-- returns color scheme dependant on operating system theme setting (dark/light)
local function color_scheme_for_appearance(appearance)
  if appearance:find "Dark" then
    return "Tokyo Night"          -- ghostty: theme = dark:TokyoNight
  else
    return "Tokyo Night Day"      -- ghostty: theme = light:TokyoNight Day
  end
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
config.color_scheme = color_scheme_for_appearance(wezterm.gui.get_appearance())
-- Same as ghostty/config: background-opacity = 0.96 · background-blur = true.
-- NOTE: macos_window_background_blur is a RADIUS (number), not a boolean; it
-- only takes effect on macOS and requires opacity < 1.
config.window_background_opacity = 0.96
config.macos_window_background_blur = 20
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

