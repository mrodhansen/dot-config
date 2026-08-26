local wezterm = require 'wezterm'

local config = wezterm.config_builder()

config.harfbuzz_features = { 'calt=0', 'clig=0', 'liga=0' }

config.initial_cols = 120
config.initial_rows = 28

config.font_size = 12
config.color_scheme = 'Vs Code Dark+ (Gogh)'

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

return config
