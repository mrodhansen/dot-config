local wezterm = require 'wezterm'

local config = wezterm.config_builder()

config.harfbuzz_features = { 'calt=0', 'clig=0', 'liga=0' }

config.initial_cols = 120
config.initial_rows = 28

config.font_size = 12
-- Color scheme follows macOS appearance. WezTerm reloads config on appearance change,
-- so this re-evaluates automatically when the system switches light/dark.
local DARK_SCHEME = 'Vs Code Dark+ (Gogh)'
local LIGHT_SCHEME = 'rose-pine-dawn'

local function is_dark_appearance()
  if wezterm.gui then
    return wezterm.gui.get_appearance():find 'Dark' ~= nil
  end
  return true
end

-- Per-scheme color overrides. Both Rosé Pine built-ins ship selection_bg equal
-- to the background (selections invisible), and the retro tab bar ignores the
-- scheme entirely. Schemes without an entry keep WezTerm defaults.
local COLORS = {
  ['rose-pine-dawn'] = {
    selection_bg = '#cecacd',
    selection_fg = '#575279',
    tab_bar = {
      background = '#dfdad9',
      active_tab = { bg_color = '#faf4ed', fg_color = '#575279', intensity = 'Bold' },
      inactive_tab = { bg_color = '#dfdad9', fg_color = '#575279', intensity = 'Bold' },
      inactive_tab_hover = { bg_color = '#cecacd', fg_color = '#575279', intensity = 'Bold' },
      new_tab = { bg_color = '#dfdad9', fg_color = '#575279' },
      new_tab_hover = { bg_color = '#cecacd', fg_color = '#575279' },
    },
  },
  ['rose-pine'] = {
    selection_bg = '#524f67',
    selection_fg = '#e0def4',
    tab_bar = {
      background = '#1f1d2e',
      active_tab = { bg_color = '#191724', fg_color = '#e0def4' },
      inactive_tab = { bg_color = '#1f1d2e', fg_color = '#6e6a86' },
      inactive_tab_hover = { bg_color = '#26233a', fg_color = '#908caa' },
      new_tab = { bg_color = '#1f1d2e', fg_color = '#6e6a86' },
      new_tab_hover = { bg_color = '#26233a', fg_color = '#908caa' },
    },
  },
}

local is_dark = is_dark_appearance()
local scheme = is_dark and DARK_SCHEME or LIGHT_SCHEME
config.color_scheme = scheme
config.colors = COLORS[scheme] or {}

-- Heavier font on the light background for legibility; dark keeps Regular.
if not is_dark then
  config.font = wezterm.font('JetBrains Mono', { weight = 'DemiBold' })
end

-- Power optimization
config.max_fps = 30
config.default_cursor_style = 'SteadyBlock'
config.animation_fps = 1
config.cursor_blink_rate = 0
config.front_end = 'WebGpu'
config.scrollback_lines = 5000
macos_window_background_blur = 0

-- Enable kitty keyboard protocol so Shift+Enter can insert newlines
config.enable_kitty_keyboard = true

-- Use retro tab bar (no close buttons on tabs)
config.use_fancy_tab_bar = false

wezterm.on('toggle-tabbar', function(window, _)
  local overrides = window:get_config_overrides() or {}
  if overrides.enable_tab_bar == false then
    overrides.enable_tab_bar = true
  else
    overrides.enable_tab_bar = false
  end
  window:set_config_overrides(overrides)
end)

-- Keybinding to close the current tab: CTRL+SHIFT+W
config.keys = {
  {
    key = 'w',
    mods = 'CTRL|SHIFT',
    action = wezterm.action.CloseCurrentTab { confirm = true },
  },
  {
    key = 'f',
    mods = 'CTRL|SHIFT',
    action = wezterm.action.EmitEvent 'toggle-tabbar',
  },
  {
    key = 'r',
    mods = 'CTRL|SHIFT',
    action = wezterm.action.PromptInputLine {
      description = 'Tab name',
      action = wezterm.action_callback(function(window, pane, line)
        if line then window:active_tab():set_title(line) end
      end),
    },
  },
}

-- Links. Apps that enable mouse reporting (Claude Code fullscreen TUI, nvim,
-- tmux with mouse on) receive every click, so a plain click on a URL does
-- nothing there. Cmd+click opens the link under the cursor regardless, matching
-- the macOS convention; plain click keeps working in normal shell output and
-- Shift+click remains WezTerm's default bypass.
config.mouse_bindings = {
  -- App has mouse reporting on: swallow the press, open on release.
  {
    event = { Down = { streak = 1, button = 'Left' } },
    mods = 'SUPER',
    mouse_reporting = true,
    action = wezterm.action.Nop,
  },
  {
    event = { Up = { streak = 1, button = 'Left' } },
    mods = 'SUPER',
    mouse_reporting = true,
    action = wezterm.action.OpenLinkAtMouseCursor,
  },
  -- No mouse reporting: Cmd+click opens too, so the gesture is consistent.
  {
    event = { Up = { streak = 1, button = 'Left' } },
    mods = 'SUPER',
    action = wezterm.action.OpenLinkAtMouseCursor,
  },
}

return config
