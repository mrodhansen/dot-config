# dotfiles

Every config I run, in one file. Each fenced block tagged `file=PATH` is a real file on disk; the
[`dotfiles`](#the-dotfiles-tool) script at the bottom writes them all out, creates the symlinks, and pulls
live edits back in here.

- **macOS** (daily driver): zsh, WezTerm, git + lazygit, TUI tools, Claude Code, Grok, OpenCode, and the shared
  agent tree `~/.ai` (skills, commands, agents, workflows).
- **Arch** (secondary): Hyprland desktop + install scripts. Blocks tagged `os=linux`.

## Contents

1. [Quick start](#quick-start)
2. [Install the tools](#install-the-tools)
3. [Shell (zsh)](#shell-zsh)
4. [Terminal (WezTerm)](#terminal-wezterm)
5. [Git](#git)
6. [TUI tools](#tui-tools)
7. [Neovim](#neovim)
8. [AI coding agents](#ai-coding-agents)
9. [Shared agent tree (~/.ai)](#shared-agent-tree-ai)
10. [Hyprland (Arch)](#hyprland-arch)
11. [The dotfiles tool](#the-dotfiles-tool)

## Quick start

```sh
git clone https://github.com/mrodhansen/dot-config.git ~/projects/dot-config
cd ~/projects/dot-config

# pull the dotfiles tool out of this file
awk '/^`+python file=~\/\.local\/bin\/dotfiles( |$)/{f=1;next} f&&/^`+$/{exit} f' dotfiles.md > /tmp/dotfiles

python3 /tmp/dotfiles extract --dry-run   # preview: what would be written / linked
python3 /tmp/dotfiles extract             # write every file + symlink for this OS
```

`extract` installs the tool itself to `~/.local/bin/dotfiles` (on `PATH` via `.zshrc`), so after the first
run it is just `dotfiles`.

- Refuses to touch anything that exists and differs. `--force` moves the old file/link aside as `*.pre-dotfiles`
  first (never deletes).
- `--only ~/.config/yazi` (repeatable) limits it to a path prefix.
- Blocks tagged `os=linux` / `os=darwin` only apply on that OS; `--all-os` overrides.

### Keeping it current

Live files are the source of truth day to day. After changing any config:

```sh
dotfiles status    # modified / missing / new files under ~/.ai / broken links (exit 1 if dirty)
dotfiles refresh   # copy live contents back into this md; new ~/.ai files get their own block
cd ~/projects/dot-config && git commit -am "Refresh dotfiles" && git push
```

`refresh` fails if a tracked file has disappeared from disk; `--prune` drops its block instead. Blocks for the
other OS are left untouched.

### Block format

| Fence info string | Meaning |
| --- | --- |
| `lang file=~/path` | File contents, written verbatim. Optional `mode=755` (default `644`), `eol=none` (no trailing newline), `os=linux\|darwin`. |
| `text links` | One `<link> -> <target>` per line; `#` comments allowed. |
| `text roots` | `<dir> !exclude ...` per line; `refresh` adds any new file found under these dirs. |

Fences are always longer than any backtick run inside the file, so embedded markdown with its own code blocks
stays intact.

## Install the tools

macOS, with [Homebrew](https://brew.sh) and the Xcode command line tools (`xcode-select --install`) in place:

```sh
brew install gh git-delta lazygit yazi btop bottom gitlogue ncspot neovim fzf zoxide fd jq node uv python@3.12 \
  anomalyco/tap/opencode
brew install --cask wezterm claude-code font-symbols-only-nerd-font
brew install openjdk                          # optional: .zshrc points JAVA_HOME at it
curl -fsSL https://bun.sh/install | bash     # ~/.bun, wired up in .zshrc
gh auth login                                 # most skills drive GitHub through gh
```

Grok CLI: install with xAI's installer. It puts the binary in `~/.grok/bin` and appends the
`# >>> grok installer >>>` block that is already in `.zshrc` below.

Hyprland on Arch has its own installer; see [Hyprland (Arch)](#hyprland-arch).

## Shell (zsh)

- `~/.local/bin` first on `PATH` (the `dotfiles` tool, `claude`, small personal CLIs live there).
- Up/Down search history by the typed prefix.
- Aliases: `rwm` restarts yabai + skhd, `claude` skips permission prompts, `oc` opens OpenCode here, `bj` blackjack.
- `y` runs yazi and `cd`s to wherever you quit it.
- `nvim` as `EDITOR`/`VISUAL`; bun and the Grok installer block at the bottom.

#### `~/.zshrc`

```zsh file=~/.zshrc
export PATH="$HOME/.local/bin:$PATH"

# Up/Down arrow: search history matching the current prefix
bindkey '^[[A' history-search-backward
bindkey '^[[B' history-search-forward

# aliases
alias ls='ls --color=auto'
alias grep='grep --color=auto'
alias rwm='yabai --restart-service && skhd --restart-service'
alias claude='claude --dangerously-skip-permissions'
alias oc='opencode .'
alias bj='blackjack-tui'

export JAVA_HOME="/opt/homebrew/opt/openjdk"

function y() {
	local tmp="$(mktemp -t "yazi-cwd.XXXXXX")" cwd
	command yazi "$@" --cwd-file="$tmp"
	IFS= read -r -d '' cwd < "$tmp"
	[ "$cwd" != "$PWD" ] && [ -d "$cwd" ] && builtin cd -- "$cwd"
	command rm -f -- "$tmp"
}

# bun completions
[ -s "/Users/mrodhansen/.bun/_bun" ] && source "/Users/mrodhansen/.bun/_bun"

# bun
export BUN_INSTALL="$HOME/.bun"
export PATH="$BUN_INSTALL/bin:$PATH"
export EDITOR=nvim
export VISUAL=nvim

# >>> grok installer >>>
export PATH="$HOME/.grok/bin:$PATH"
fpath=(~/.grok/completions/zsh $fpath)
autoload -Uz compinit && compinit -C
# <<< grok installer <<<
```

## Terminal (WezTerm)

- Follows macOS light/dark: `Vs Code Dark+ (Gogh)` / `rose-pine-dawn`, with fixed selection and retro tab bar
  colors (the built-in Rosé Pine schemes make selections invisible). DemiBold JetBrains Mono (bundled) on light.
- Ligatures off, 30 fps / no blink / WebGpu for battery, 5000 lines scrollback.
- Kitty keyboard protocol on, so Shift+Enter inserts a newline in Claude Code / OpenCode.
- `Ctrl+Shift+W` close tab, `Ctrl+Shift+F` toggle tab bar, `Ctrl+Shift+R` rename tab.
- `Cmd+click` opens links even inside apps that capture the mouse (Claude Code fullscreen, nvim).

#### `~/.wezterm.lua`

```lua file=~/.wezterm.lua
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
```

## Git

Identity, a global ignore (keeps every repo's `.claude/settings.local.json` out of git), and lazygit paging
diffs through delta.

#### `~/.gitconfig`

```ini file=~/.gitconfig
[user]
	email = mrodhansen@gmail.com
	name = Martin Hansen
```

#### `~/.config/git/ignore`

```gitignore file=~/.config/git/ignore
**/.claude/settings.local.json
```

#### `~/.config/lazygit/config.yml`

```yaml file=~/.config/lazygit/config.yml
git:
  pagers:
    - colorArg: always
      pager: delta --dark --paging=never
```

## TUI tools

| Tool | Command | Notes |
| --- | --- | --- |
| yazi | `y` (see `.zshrc`) | Show hidden files. |
| btop | `btop` | Full config as btop writes it. |
| bottom | `btm` | VS Code Dark+ palette. |
| gitlogue | `gitlogue` | Replays commits as typing; gruvbox, random order. |
| ncspot | `ncspot` | Spotify TUI; shuffle + playlist repeat, VS Code Dark+ theme. |

cava is installed but runs on its stock config, so nothing to keep.

#### `~/.config/yazi/yazi.toml`

```toml file=~/.config/yazi/yazi.toml
[mgr]
show_hidden = true
```

#### `~/.config/btop/btop.conf`

```ini file=~/.config/btop/btop.conf
#? Config file for btop v.1.4.6

#* Name of a btop++/bpytop/bashtop formatted ".theme" file, "Default" and "TTY" for builtin themes.
#* Themes should be placed in "../share/btop/themes" relative to binary or "$HOME/.config/btop/themes"
color_theme = "Default"

#* If the theme set background should be shown, set to False if you want terminal background transparency.
theme_background = true

#* Sets if 24-bit truecolor should be used, will convert 24-bit colors to 256 color (6x6x6 color cube) if false.
truecolor = true

#* Set to true to force tty mode regardless if a real tty has been detected or not.
#* Will force 16-color mode and TTY theme, set all graph symbols to "tty" and swap out other non tty friendly symbols.
force_tty = false

#* Define presets for the layout of the boxes. Preset 0 is always all boxes shown with default settings. Max 9 presets.
#* Format: "box_name:P:G,box_name:P:G" P=(0 or 1) for alternate positions, G=graph symbol to use for box.
#* Use whitespace " " as separator between different presets.
#* Example: "cpu:0:default,mem:0:tty,proc:1:default cpu:0:braille,proc:0:tty"
presets = "cpu:1:default,proc:0:default cpu:0:default,mem:0:default,net:0:default cpu:0:block,net:0:tty"

#* Set to True to enable "h,j,k,l,g,G" keys for directional control in lists.
#* Conflicting keys for h:"help" and k:"kill" is accessible while holding shift.
vim_keys = false

#* Rounded corners on boxes, is ignored if TTY mode is ON.
rounded_corners = true

#* Use terminal synchronized output sequences to reduce flickering on supported terminals.
terminal_sync = true

#* Default symbols to use for graph creation, "braille", "block" or "tty".
#* "braille" offers the highest resolution but might not be included in all fonts.
#* "block" has half the resolution of braille but uses more common characters.
#* "tty" uses only 3 different symbols but will work with most fonts and should work in a real TTY.
#* Note that "tty" only has half the horizontal resolution of the other two, so will show a shorter historical view.
graph_symbol = "braille"

# Graph symbol to use for graphs in cpu box, "default", "braille", "block" or "tty".
graph_symbol_cpu = "default"

# Graph symbol to use for graphs in cpu box, "default", "braille", "block" or "tty".
graph_symbol_mem = "default"

# Graph symbol to use for graphs in cpu box, "default", "braille", "block" or "tty".
graph_symbol_net = "default"

# Graph symbol to use for graphs in cpu box, "default", "braille", "block" or "tty".
graph_symbol_proc = "default"

#* Manually set which boxes to show. Available values are "cpu mem net proc" and "gpu0" through "gpu5", separate values with whitespace.
shown_boxes = "cpu mem net proc"

#* Update time in milliseconds, recommended 2000 ms or above for better sample times for graphs.
update_ms = 2000

#* Processes sorting, "pid" "program" "arguments" "threads" "user" "memory" "cpu lazy" "cpu direct",
#* "cpu lazy" sorts top process over time (easier to follow), "cpu direct" updates top process directly.
proc_sorting = "cpu lazy"

#* Reverse sorting order, True or False.
proc_reversed = false

#* Show processes as a tree.
proc_tree = false

#* Use the cpu graph colors in the process list.
proc_colors = true

#* Use a darkening gradient in the process list.
proc_gradient = true

#* If process cpu usage should be of the core it's running on or usage of the total available cpu power.
proc_per_core = false

#* Show process memory as bytes instead of percent.
proc_mem_bytes = true

#* Show cpu graph for each process.
proc_cpu_graphs = true

#* Use /proc/[pid]/smaps for memory information in the process info box (very slow but more accurate)
proc_info_smaps = false

#* Show proc box on left side of screen instead of right.
proc_left = false

#* (Linux) Filter processes tied to the Linux kernel(similar behavior to htop).
proc_filter_kernel = false

#* In tree-view, always accumulate child process resources in the parent process.
proc_aggregate = false

#* Should cpu and memory usage display be preserved for dead processes when paused.
keep_dead_proc_usage = false

#* Sets the CPU stat shown in upper half of the CPU graph, "total" is always available.
#* Select from a list of detected attributes from the options menu.
cpu_graph_upper = "Auto"

#* Sets the CPU stat shown in lower half of the CPU graph, "total" is always available.
#* Select from a list of detected attributes from the options menu.
cpu_graph_lower = "Auto"

#* Toggles if the lower CPU graph should be inverted.
cpu_invert_lower = true

#* Set to True to completely disable the lower CPU graph.
cpu_single_graph = false

#* Show cpu box at bottom of screen instead of top.
cpu_bottom = false

#* Shows the system uptime in the CPU box.
show_uptime = true

#* Shows the CPU package current power consumption in watts. Requires running `make setcap` or `make setuid` or running with sudo.
show_cpu_watts = true

#* Show cpu temperature.
check_temp = true

#* Which sensor to use for cpu temperature, use options menu to select from list of available sensors.
cpu_sensor = "Auto"

#* Show temperatures for cpu cores also if check_temp is True and sensors has been found.
show_coretemp = true

#* Set a custom mapping between core and coretemp, can be needed on certain cpus to get correct temperature for correct core.
#* Use lm-sensors or similar to see which cores are reporting temperatures on your machine.
#* Format "x:y" x=core with wrong temp, y=core with correct temp, use space as separator between multiple entries.
#* Example: "4:0 5:1 6:3"
cpu_core_map = ""

#* Which temperature scale to use, available values: "celsius", "fahrenheit", "kelvin" and "rankine".
temp_scale = "celsius"

#* Use base 10 for bits/bytes sizes, KB = 1000 instead of KiB = 1024.
base_10_sizes = false

#* Show CPU frequency.
show_cpu_freq = true

#* Draw a clock at top of screen, formatting according to strftime, empty string to disable.
#* Special formatting: /host = hostname | /user = username | /uptime = system uptime
clock_format = "%X"

#* Update main ui in background when menus are showing, set this to false if the menus is flickering too much for comfort.
background_update = true

#* Custom cpu model name, empty string to disable.
custom_cpu_name = ""

#* Optional filter for shown disks, should be full path of a mountpoint, separate multiple values with whitespace " ".
#* Only disks matching the filter will be shown. Prepend exclude= to only show disks not matching the filter. Examples: disk_filter="/boot /home/user", disks_filter="exclude=/boot /home/user"
disks_filter = ""

#* Show graphs instead of meters for memory values.
mem_graphs = true

#* Show mem box below net box instead of above.
mem_below_net = false

#* Count ZFS ARC in cached and available memory.
zfs_arc_cached = true

#* If swap memory should be shown in memory box.
show_swap = true

#* Show swap as a disk, ignores show_swap value above, inserts itself after first disk.
swap_disk = true

#* If mem box should be split to also show disks info.
show_disks = true

#* Filter out non physical disks. Set this to False to include network disks, RAM disks and similar.
only_physical = true

#* Read disks list from /etc/fstab. This also disables only_physical.
use_fstab = true

#* Setting this to True will hide all datasets, and only show ZFS pools. (IO stats will be calculated per-pool)
zfs_hide_datasets = false

#* Set to true to show available disk space for privileged users.
disk_free_priv = false

#* Toggles if io activity % (disk busy time) should be shown in regular disk usage view.
show_io_stat = true

#* Toggles io mode for disks, showing big graphs for disk read/write speeds.
io_mode = false

#* Set to True to show combined read/write io graphs in io mode.
io_graph_combined = false

#* Set the top speed for the io graphs in MiB/s (100 by default), use format "mountpoint:speed" separate disks with whitespace " ".
#* Example: "/mnt/media:100 /:20 /boot:1".
io_graph_speeds = ""

#* Set fixed values for network graphs in Mebibits. Is only used if net_auto is also set to False.
net_download = 100

net_upload = 100

#* Use network graphs auto rescaling mode, ignores any values set above and rescales down to 10 Kibibytes at the lowest.
net_auto = true

#* Sync the auto scaling for download and upload to whichever currently has the highest scale.
net_sync = true

#* Starts with the Network Interface specified here.
net_iface = ""

#* "True" shows bitrates in base 10 (Kbps, Mbps). "False" shows bitrates in binary sizes (Kibps, Mibps, etc.). "Auto" uses base_10_sizes.
base_10_bitrate = "Auto"

#* Show battery stats in top right if battery is present.
show_battery = true

#* Which battery to use if multiple are present. "Auto" for auto detection.
selected_battery = "Auto"

#* Show power stats of battery next to charge indicator.
show_battery_watts = true

#* Set loglevel for "~/.local/state/btop.log" levels are: "ERROR" "WARNING" "INFO" "DEBUG".
#* The level set includes all lower levels, i.e. "DEBUG" will show all logging info.
log_level = "WARNING"

#* Automatically save current settings to config file on exit.
save_config_on_exit = true
```

#### `~/.config/bottom/bottom.toml`

```toml file=~/.config/bottom/bottom.toml
[colors]
# VS Code Dark+ theme for bottom
table_header_color = "#569cd6"
all_cpu_color = "#569cd6"
avg_cpu_color = "#dcdcaa"
cpu_core_colors = ["#569cd6", "#4ec9b0", "#ce9178", "#dcdcaa", "#c586c0", "#9cdcfe", "#6a9955", "#d4d4d4"]
ram_color = "#4ec9b0"
swap_color = "#ce9178"
arc_color = "#c586c0"
gpu_colors = ["#dcdcaa", "#569cd6", "#4ec9b0", "#ce9178"]
rx_color = "#4ec9b0"
tx_color = "#c586c0"
border_color = "#3c3c3c"
highlighted_border_color = "#569cd6"
text_color = "#d4d4d4"
selected_text_color = "#d4d4d4"
selected_bg_color = "#264f78"
widget_title_color = "#569cd6"
graph_color = "#3c3c3c"
disabled_text_color = "#6a6a6a"
high_battery_color = "#6a9955"
medium_battery_color = "#dcdcaa"
low_battery_color = "#f44747"

# Custom layout: CPU, Memory, and Processes (no network, temp, or disk)
[[row]]
  ratio = 50
  [[row.child]]
    type = "cpu"

[[row]]
  ratio = 50
  [[row.child]]
    ratio = 55
    type = "mem"
  [[row.child]]
    ratio = 45
    type = "proc"
    default = true
```

#### `~/.config/gitlogue/config.toml`

```toml file=~/.config/gitlogue/config.toml
# gitlogue configuration file
# All settings are optional and will use defaults if not specified

# Theme to use for syntax highlighting
theme = "gruvbox"

# Typing speed in milliseconds per character
speed = 30

# Show background colors (set to false for transparent background)
background = true

# Commit playback order: random, asc, or desc
order = "random"

# Loop the animation continuously
loop = false

# Ignore patterns (gitignore syntax)
# Examples: ["*.png", "*.ipynb", "dist/**"]
ignore_patterns = []

# Speed rules for different file types (pattern:milliseconds)
# Examples: ["*.java:50", "*.xml:5", "*.rs:30"]
speed_rules = []
```

#### `~/.config/ncspot/config.toml`

```toml file=~/.config/ncspot/config.toml
shuffle = true
repeat = "playlist"
volume = 85

[theme]
background = "#1e1e1e"
primary = "#d4d4d4"
secondary = "#808080"
title = "#569cd6"
playing = "#dcdcaa"
playing_selected = "#ce9178"
playing_bg = "#1e1e1e"
highlight = "#d4d4d4"
highlight_bg = "#264f78"
error = "#f44747"
error_bg = "#1e1e1e"
statusbar = "#ffffff"
statusbar_progress = "#007acc"
statusbar_bg = "#007acc"
cmdline = "#d4d4d4"
cmdline_bg = "#252526"
search_match = "#e8ab53"
```

## Neovim

Lives in its own repo (lazy.nvim, telescope, nvim-tree, codeium, ...):

```sh
git clone https://github.com/mrodhansen/nvim ~/.config/nvim
```

## AI coding agents

One shared tree, `~/.ai`, feeds every agent CLI through symlinks, so a skill written once shows up in Claude
Code, Grok, OpenCode, and anything that reads `~/.agents/skills`. Per-tool settings stay per-tool; auth,
sessions, caches, `settings.local.json`, and OpenCode `service.json` are never kept here.

| Live path | Points at |
| --- | --- |
| `~/.claude/{skills,agents}` | `~/.ai/{skills,agents}` |
| `~/.claude/CLAUDE.md` | `~/.ai/AGENTS.md` (global coding rules) |
| `~/.claude/commands/<name>.md` | `~/.ai/commands/<name>.md`, only for commands with no same-named skill |
| `~/.grok/{skills,agents,workflows}` | `~/.ai/{skills,agents,workflows}` |
| `~/.config/opencode/skills` | `~/.ai/oc_skills` (OpenCode-only skills, avoids name collisions) |
| `~/.config/opencode/{agents,command,AGENTS.md,workflows-from-grok}` | `~/.ai/{agents,commands,AGENTS.md,workflows}` |
| `~/.agents/skills` | `~/.ai/skills` |

### Claude Code

Opus at `xhigh` effort, auto permission mode, fullscreen TUI, theme follows the OS, no co-author trailer on
commits. Plugins listed under `enabledPlugins` (playwright-cli, caveman, frontend-design, rust-analyzer-lsp)
are installed from inside Claude Code with `/plugin`; the caveman marketplace is declared here.

#### `~/.claude/settings.json`

```json file=~/.claude/settings.json
{
  "includeCoAuthoredBy": false,
  "permissions": {
    "defaultMode": "auto"
  },
  "model": "opus",
  "enabledPlugins": {
    "playwright-cli@playwright-cli": true,
    "caveman@caveman": true,
    "frontend-design@claude-plugins-official": true,
    "rust-analyzer-lsp@claude-plugins-official": true
  },
  "extraKnownMarketplaces": {
    "caveman": {
      "source": {
        "source": "github",
        "repo": "JuliusBrussee/caveman"
      }
    }
  },
  "effortLevel": "xhigh",
  "modelSettings": {
    "claude-opus-5-5": {
      "effortLevel": "xhigh"
    }
  },
  "promptSuggestionEnabled": false,
  "awaySummaryEnabled": false,
  "tui": "fullscreen",
  "skipDangerousModePermissionPrompt": true,
  "theme": "auto",
  "editorMode": "normal",
  "verbose": false,
  "agentPushNotifEnabled": true,
  "useAutoModeDuringPlan": true
}
```

### Grok

#### `~/.grok/config.toml`

```toml file=~/.grok/config.toml
[cli]
installer = "internal"

[marketplace]
official_marketplace_auto_installed = true
default_skills_installs_purged = true

[[marketplace.sources]]
name = "xAI Official"
git = "https://github.com/xai-org/plugin-marketplace.git"

[ui]
max_thoughts_width = 120
fork_secondary_model = "grok-build"
yolo = false
compact_mode = false
permission_mode = "always-approve"
theme = "auto"

[privacy]
privacy_banner_acked = "2026-09-21T16:40:53Z"

[models]
default = "grok-4.6"
default_reasoning_effort = "medium"
```

### OpenCode

- `opencode.json`: agents (`build`, read-only `plan`, fast Sonnet `quick`), local Ollama Gemma models, MCP servers
  (context7, gh_grep, and blender via `~/.local/bin/blender-mcp`).
- `cli.json`: TUI. Rosé Pine Dawn following the system theme, tab keybinds, low verbosity, the
  `opencode-keep-going` plugin (fetched by OpenCode).
- `themes/`: Rosé Pine Dawn + VS Code Dark+. The message-queue plugin is parked as `.disabled`.

#### `~/.config/opencode/opencode.json`

```json file=~/.config/opencode/opencode.json
{
  "$schema": "https://opencode.ai/config.json",
  "update": "auto",
  "websearch": false,
  "formatter": true,
  "experimental": {
    "subagent_depth": 4
  },
  "agents": {
    "build": {
      "color": "#dc2626",
      "permissions": [{ "action": "*", "resource": "*", "effect": "allow" }]
    },
    "quick": {
      "description": "A fast agent for quick questions and simple tasks. Uses Sonnet for speed and efficiency.",
      "model": "anthropic/claude-sonnet-4-6",
      "system": "You are a fast, concise assistant for quick questions. Give short, direct answers. Avoid unnecessary explanation unless asked for more detail.",
      "permissions": [
        { "action": "edit", "resource": "*", "effect": "deny" },
        { "action": "shell", "resource": "*", "effect": "ask" }
      ],
      "color": "#22c55e"
    },
    "plan": {
      "description": "Analyzes codebases and designs implementation plans without making changes. Read-only exploration with controlled bash access.",
      "mode": "primary",
      "system": "You are a senior software architect and planner. Your role is to analyze codebases, understand existing patterns, and design detailed implementation plans.\n\nWhen planning:\n- Read and explore the codebase thoroughly before proposing anything\n- Identify existing patterns, conventions, and architecture\n- Consider dependencies, edge cases, and potential issues\n- Break work into clear, ordered tasks with file paths and descriptions\n- Specify which specialist agent (frontend-developer or backend-architect) should handle each task\n- Call out risks, trade-offs, and open questions\n\nYou can read files, search code, and run safe bash commands (like git log, ls, etc.) to understand the project. You should NOT modify any files directly - your output is a plan for other agents to execute.",
      "permissions": [
        { "action": "edit", "resource": "*", "effect": "deny" },
        { "action": "shell", "resource": "*", "effect": "ask" },
        { "action": "webfetch", "resource": "*", "effect": "ask" }
      ],
      "color": "#6366f1"
    },
    "general": {
      "permissions": [
        { "action": "subagent", "resource": "*", "effect": "allow" }
      ]
    },
    "explore": {
      "permissions": [
        { "action": "subagent", "resource": "*", "effect": "allow" }
      ]
    }
  },
  "providers": {
    "ollama": {
      "name": "Ollama (local)",
      "models": {
        "gemma4:31b": { "name": "Gemma 4 31B" },
        "gemma4:e4b": { "name": "Gemma 4 e4b" }
      }
    }
  },
  "mcp": {
    "servers": {
      "blender": {
        "type": "local",
        "command": ["/Users/mrodhansen/.local/bin/blender-mcp"]
      },
      "context7": {
        "type": "remote",
        "url": "https://mcp.context7.com/mcp"
      },
      "gh_grep": {
        "type": "remote",
        "url": "https://mcp.grep.app",
        "oauth": false
      }
    }
  }
}
```

#### `~/.config/opencode/cli.json`

```json file=~/.config/opencode/cli.json mode=600
{
  "$schema": "https://opencode.ai/v2/cli.json",
  "theme": {
    "name": "rose-pine-dawn",
    "mode": "system"
  },
  "diffs": {
    "wrap": "word",
    "view": "auto"
  },
  "session": {
    "sidebar": "auto",
    "scrollbar": false,
    "thinking": "hide",
    "new_location": "launch",
    "verbosity": "low"
  },
  "animations": true,
  "attention": {
    "notifications": true,
    "sound": true,
    "volume": 0.4
  },
  "keybinds": {
    "session.tab.close": "ctrl+w",
    "session.tab.previous": "ctrl+shift+tab,alt+up,ctrl+h",
    "session.tab.next": "ctrl+tab,alt+down,ctrl+l",
    "session.new": "ctrl+n",
    "session.message.user.previous": "ctrl+k",
    "session.message.user.next": "ctrl+j",
    "input.newline": "shift+return,ctrl+return",
    "input.delete.to.line.end": false
  },
  "plugins": ["opencode-keep-going"],
  "tabs": {
    "layout": "horizontal",
    "indicators": "status"
  },
  "prompt": {
    "image_preview": false
  }
}
```

#### `~/.config/opencode/themes/rose-pine-dawn.json`

```json file=~/.config/opencode/themes/rose-pine-dawn.json
{
  "$schema": "https://opencode.ai/theme.json",
  "defs": {
    "bg": "#1E1E1E",
    "bgSidebar": "#252526",
    "bgElement": "#2D2D2D",
    "fg": "#D4D4D4",
    "fgMuted": "#858585",
    "border": "#3E3E42",
    "borderActive": "#007FD4",
    "borderSubtle": "#2B2B2B",
    "blue": "#569CD6",
    "blueBright": "#4FC1FF",
    "blueLink": "#3794FF",
    "blueAccent": "#007ACC",
    "cyan": "#4EC9B0",
    "green": "#6A9955",
    "greenBright": "#B5CEA8",
    "greenGit": "#81B88B",
    "yellow": "#DCDCAA",
    "yellowWarn": "#CCA700",
    "orange": "#CE9178",
    "orangeBright": "#D7BA7D",
    "redError": "#F14C4C",
    "redSoft": "#F48771",
    "magenta": "#C586C0",
    "variable": "#9CDCFE",
    "diffAddedFg": "#81B88B",
    "diffRemovedFg": "#F14C4C",
    "diffAddedBg": "#373D29",
    "diffRemovedBg": "#4B1818",
    "diffAddedLineBg": "#2F3726",
    "diffRemovedLineBg": "#3F1D1D",

    "dawnBase": "#faf4ed",
    "dawnSurface": "#fffaf3",
    "dawnOverlay": "#f2e9e1",
    "dawnMuted": "#9893a5",
    "dawnSubtle": "#797593",
    "dawnText": "#575279",
    "dawnLove": "#b4637a",
    "dawnGold": "#ea9d34",
    "dawnRose": "#d7827e",
    "dawnPine": "#286983",
    "dawnFoam": "#56949f",
    "dawnIris": "#907aa9",
    "dawnWorking": "#c2410c",
    "dawnHighlightLow": "#f4ede8",
    "dawnHighlightMed": "#dfdad9",
    "dawnHighlightHigh": "#cecacd",
    "dawnDiffAddedBg": "#e5f2f3",
    "dawnDiffRemovedBg": "#fce5e8",
    "dawnDiffLineNumber": "#6c6875"
  },
  "theme": {
    "primary": { "dark": "blueBright", "light": "dawnWorking" },
    "secondary": { "dark": "blue", "light": "dawnIris" },
    "accent": { "dark": "cyan", "light": "dawnRose" },
    "error": { "dark": "redError", "light": "dawnLove" },
    "warning": { "dark": "yellowWarn", "light": "dawnGold" },
    "success": { "dark": "greenGit", "light": "dawnPine" },
    "info": { "dark": "blueLink", "light": "dawnFoam" },

    "text": { "dark": "fg", "light": "dawnText" },
    "textMuted": { "dark": "fgMuted", "light": "dawnMuted" },
    "selectedListItemText": { "dark": "bg", "light": "dawnText" },

    "background": { "dark": "bg", "light": "dawnBase" },
    "backgroundPanel": { "dark": "bgSidebar", "light": "dawnSurface" },
    "backgroundElement": { "dark": "bgElement", "light": "dawnOverlay" },
    "backgroundMenu": { "dark": "bgElement", "light": "dawnSurface" },

    "border": { "dark": "border", "light": "dawnHighlightMed" },
    "borderActive": { "dark": "borderActive", "light": "dawnPine" },
    "borderSubtle": { "dark": "borderSubtle", "light": "dawnHighlightLow" },

    "diffAdded": { "dark": "diffAddedFg", "light": "dawnPine" },
    "diffRemoved": { "dark": "diffRemovedFg", "light": "dawnLove" },
    "diffContext": { "dark": "fgMuted", "light": "dawnMuted" },
    "diffHunkHeader": { "dark": "blue", "light": "dawnIris" },
    "diffHighlightAdded": { "dark": "greenBright", "light": "dawnPine" },
    "diffHighlightRemoved": { "dark": "redSoft", "light": "dawnLove" },
    "diffAddedBg": { "dark": "diffAddedBg", "light": "dawnDiffAddedBg" },
    "diffRemovedBg": { "dark": "diffRemovedBg", "light": "dawnDiffRemovedBg" },
    "diffContextBg": { "dark": "bgSidebar", "light": "dawnSurface" },
    "diffLineNumber": { "dark": "fgMuted", "light": "dawnDiffLineNumber" },
    "diffAddedLineNumberBg": {
      "dark": "diffAddedLineBg",
      "light": "dawnDiffAddedBg"
    },
    "diffRemovedLineNumberBg": {
      "dark": "diffRemovedLineBg",
      "light": "dawnDiffRemovedBg"
    },

    "markdownText": { "dark": "fg", "light": "dawnText" },
    "markdownHeading": { "dark": "blue", "light": "dawnIris" },
    "markdownLink": { "dark": "blueLink", "light": "dawnPine" },
    "markdownLinkText": { "dark": "blueBright", "light": "dawnRose" },
    "markdownCode": { "dark": "orange", "light": "dawnPine" },
    "markdownBlockQuote": { "dark": "green", "light": "dawnMuted" },
    "markdownEmph": { "dark": "orangeBright", "light": "dawnGold" },
    "markdownStrong": { "dark": "yellow", "light": "dawnLove" },
    "markdownHorizontalRule": {
      "dark": "fgMuted",
      "light": "dawnHighlightMed"
    },
    "markdownListItem": { "dark": "blue", "light": "dawnPine" },
    "markdownListEnumeration": { "dark": "cyan", "light": "dawnRose" },
    "markdownImage": { "dark": "blueLink", "light": "dawnPine" },
    "markdownImageText": { "dark": "blueBright", "light": "dawnRose" },
    "markdownCodeBlock": { "dark": "fg", "light": "dawnText" },

    "syntaxComment": { "dark": "green", "light": "dawnMuted" },
    "syntaxKeyword": { "dark": "blue", "light": "dawnPine" },
    "syntaxFunction": { "dark": "yellow", "light": "dawnRose" },
    "syntaxVariable": { "dark": "variable", "light": "dawnText" },
    "syntaxString": { "dark": "orange", "light": "dawnGold" },
    "syntaxNumber": { "dark": "blueBright", "light": "dawnIris" },
    "syntaxType": { "dark": "cyan", "light": "dawnFoam" },
    "syntaxOperator": { "dark": "fg", "light": "dawnSubtle" },
    "syntaxPunctuation": { "dark": "fg", "light": "dawnSubtle" }
  }
}
```

#### `~/.config/opencode/themes/vscode-dark-plus.json`

```json file=~/.config/opencode/themes/vscode-dark-plus.json
{
  "$schema": "https://opencode.ai/theme.json",
  "defs": {
    "bg": "#1E1E1E",
    "bgSidebar": "#252526",
    "bgElement": "#2D2D2D",
    "bgInput": "#3C3C3C",
    "fg": "#D4D4D4",
    "fgMuted": "#858585",
    "border": "#3E3E42",
    "borderActive": "#007FD4",
    "borderSubtle": "#2B2B2B",
    "blue": "#569CD6",
    "blueBright": "#4FC1FF",
    "blueLink": "#3794FF",
    "blueAccent": "#007ACC",
    "bluePrimary": "#0E639C",
    "cyan": "#4EC9B0",
    "green": "#6A9955",
    "greenBright": "#B5CEA8",
    "greenGit": "#81B88B",
    "yellow": "#DCDCAA",
    "yellowWarn": "#CCA700",
    "orange": "#CE9178",
    "orangeBright": "#D7BA7D",
    "red": "#F44747",
    "redError": "#F14C4C",
    "redSoft": "#F48771",
    "magenta": "#C586C0",
    "variable": "#9CDCFE",
    "diffAddedFg": "#81B88B",
    "diffRemovedFg": "#F14C4C",
    "diffAddedBg": "#373D29",
    "diffRemovedBg": "#4B1818",
    "diffAddedLineBg": "#2F3726",
    "diffRemovedLineBg": "#3F1D1D"
  },
  "theme": {
    "primary": "blueAccent",
    "secondary": "blue",
    "accent": "cyan",
    "error": "redError",
    "warning": "yellowWarn",
    "success": "greenGit",
    "info": "blueLink",

    "text": "fg",
    "textMuted": "fgMuted",

    "background": "bg",
    "backgroundPanel": "bgSidebar",
    "backgroundElement": "bgElement",

    "border": "border",
    "borderActive": "borderActive",
    "borderSubtle": "borderSubtle",

    "diffAdded": "diffAddedFg",
    "diffRemoved": "diffRemovedFg",
    "diffContext": "fgMuted",
    "diffHunkHeader": "blue",
    "diffHighlightAdded": "greenBright",
    "diffHighlightRemoved": "redSoft",
    "diffAddedBg": "diffAddedBg",
    "diffRemovedBg": "diffRemovedBg",
    "diffContextBg": "bgSidebar",
    "diffLineNumber": "fgMuted",
    "diffAddedLineNumberBg": "diffAddedLineBg",
    "diffRemovedLineNumberBg": "diffRemovedLineBg",

    "markdownText": "fg",
    "markdownHeading": "blue",
    "markdownLink": "blueLink",
    "markdownLinkText": "blueBright",
    "markdownCode": "orange",
    "markdownBlockQuote": "green",
    "markdownEmph": "orangeBright",
    "markdownStrong": "yellow",
    "markdownHorizontalRule": "fgMuted",
    "markdownListItem": "blue",
    "markdownListEnumeration": "cyan",
    "markdownImage": "blueLink",
    "markdownImageText": "blueBright",
    "markdownCodeBlock": "fg",

    "syntaxComment": "green",
    "syntaxKeyword": "blue",
    "syntaxFunction": "yellow",
    "syntaxVariable": "variable",
    "syntaxString": "orange",
    "syntaxNumber": "blueBright",
    "syntaxType": "cyan",
    "syntaxOperator": "fg",
    "syntaxPunctuation": "fg"
  }
}
```

#### `~/.config/opencode/plugins/message-queue-eagerness.ts.disabled`

```ts file=~/.config/opencode/plugins/message-queue-eagerness.ts.disabled
import type { TuiPlugin } from "@opencode-ai/plugin/tui"

type DeliveryMode = "queue" | "eager" | "now"
type QueuedItem = {
  id: string
  sessionID: string
  text: string
  mode: DeliveryMode
  parts?: unknown[]
  agent?: string
  model?: unknown
  variant?: string
  createdAt: number
}

type PromptArgs = {
  sessionID: string
  parts?: Array<{ type: string; text?: string; synthetic?: boolean; [key: string]: unknown }>
  agent?: string
  model?: unknown
  variant?: string
  messageID?: string
  noReply?: boolean
  [key: string]: unknown
}

const KV_DEFAULT_MODE = "queue.eagerness.defaultMode"

function textFromParts(parts: PromptArgs["parts"]): string {
  if (!parts?.length) return ""
  return parts
    .filter((p) => p.type === "text" && typeof p.text === "string" && !p.synthetic)
    .map((p) => p.text as string)
    .join("")
}

function isBusyStatus(status: unknown): boolean {
  if (!status) return false
  if (typeof status === "string") return status === "busy" || status === "running" || status === "retry"
  if (typeof status === "object" && status !== null && "type" in status) {
    const t = (status as { type: string }).type
    return t === "busy" || t === "running" || t === "retry"
  }
  return false
}

function uid(): string {
  return `q_${Date.now().toString(36)}_${Math.random().toString(36).slice(2, 8)}`
}

function preview(text: string, n = 48): string {
  const one = text.replace(/\s+/g, " ").trim()
  if (one.length <= n) return one
  return `${one.slice(0, n - 1)}…`
}

export const tui: TuiPlugin = async (api) => {
  const queues = new Map<string, QueuedItem[]>()
  const sending = new Set<string>()
  /** Bypass intercept while plugin drains its own queue */
  let passthrough = 0
  let defaultMode: DeliveryMode = api.kv.get(KV_DEFAULT_MODE, "queue") as DeliveryMode
  if (defaultMode !== "queue" && defaultMode !== "eager") defaultMode = "queue"

  const refreshKey = "queue.eagerness.tick"
  const bump = () => api.kv.set(refreshKey, Date.now())

  const getQueue = (sessionID: string) => queues.get(sessionID) ?? []
  const setQueue = (sessionID: string, items: QueuedItem[]) => {
    if (items.length === 0) queues.delete(sessionID)
    else queues.set(sessionID, items)
    bump()
  }

  const sessionID = (): string | undefined => {
    const cur = api.route.current
    if (cur.name === "session" && typeof cur.params?.sessionID === "string") return cur.params.sessionID
    return undefined
  }

  const busy = (id: string) => isBusyStatus(api.state.session.status(id))

  const toast = (message: string, variant: "info" | "success" | "warning" | "error" = "info") => {
    api.ui.toast({ message, variant, duration: 2500 })
  }

  // Capture originals before any wrap (used by drain + intercept)
  const sessionClient = api.client.session as unknown as {
    prompt: (args: PromptArgs, opts?: { throwOnError?: boolean }) => Promise<unknown>
    promptAsync?: (args: PromptArgs, opts?: { throwOnError?: boolean }) => Promise<unknown>
  }
  const originalPrompt = sessionClient.prompt.bind(sessionClient)
  const originalPromptAsync = sessionClient.promptAsync?.bind(sessionClient)

  const sendViaV2 = async (item: QueuedItem, delivery: "queue" | "steer") => {
    const client = api.client as {
      v2?: {
        session: {
          prompt: (p: {
            sessionID: string
            prompt: { text: string }
            delivery?: "queue" | "steer"
          }) => Promise<{ error?: unknown }>
          interrupt: (p: { sessionID: string }) => Promise<unknown>
        }
      }
      session: {
        prompt: (p: PromptArgs, o?: { throwOnError?: boolean }) => Promise<unknown>
        abort?: (p: { sessionID: string }) => Promise<unknown>
      }
    }

    passthrough++
    try {
      if (client.v2?.session?.prompt) {
        const res = await client.v2.session.prompt({
          sessionID: item.sessionID,
          prompt: { text: item.text },
          delivery,
        })
        if (res?.error) throw res.error
        return
      }

      await originalPrompt(
        {
          sessionID: item.sessionID,
          agent: item.agent,
          model: item.model as PromptArgs["model"],
          variant: item.variant,
          parts: item.parts?.length
            ? (item.parts as PromptArgs["parts"])
            : [{ type: "text", text: item.text }],
        },
        { throwOnError: true },
      )
    } finally {
      passthrough--
    }
  }

  const interrupt = async (id: string) => {
    const client = api.client as {
      v2?: { session: { interrupt: (p: { sessionID: string }) => Promise<unknown> } }
      session: { abort?: (p: { sessionID: string }) => Promise<unknown> }
    }
    if (client.v2?.session?.interrupt) {
      await client.v2.session.interrupt({ sessionID: id })
      return
    }
    await client.session.abort?.({ sessionID: id })
  }

  const remove = (sessionID: string, itemID: string) => {
    setQueue(
      sessionID,
      getQueue(sessionID).filter((q) => q.id !== itemID),
    )
  }

  const enqueue = (item: Omit<QueuedItem, "id" | "createdAt" | "mode"> & { mode?: DeliveryMode }) => {
    const full: QueuedItem = {
      id: uid(),
      createdAt: Date.now(),
      mode: item.mode ?? defaultMode,
      sessionID: item.sessionID,
      text: item.text,
      parts: item.parts,
      agent: item.agent,
      model: item.model,
      variant: item.variant,
    }
    setQueue(full.sessionID, [...getQueue(full.sessionID), full])
    toast(`Queued (${full.mode}): ${preview(full.text)}`)
    return full
  }

  const deliver = async (item: QueuedItem) => {
    if (sending.has(item.id)) return
    sending.add(item.id)
    try {
      if (item.mode === "now") {
        if (busy(item.sessionID)) await interrupt(item.sessionID)
        await sendViaV2(item, "steer")
      } else if (item.mode === "eager") {
        await sendViaV2(item, "steer")
      } else {
        await sendViaV2(item, "queue")
      }
      remove(item.sessionID, item.id)
    } catch (err) {
      toast(`Queue send failed: ${err instanceof Error ? err.message : String(err)}`, "error")
    } finally {
      sending.delete(item.id)
    }
  }

  const drainIdle = async (id: string) => {
    if (busy(id)) return
    const next = getQueue(id).find((q) => q.mode === "queue" || q.mode === "now")
    if (!next) return
    if (next.mode === "now") await deliver(next)
    else await deliver(next)
  }

  const drainEager = async (id: string) => {
    const next = getQueue(id).find((q) => q.mode === "eager")
    if (!next) return
    await deliver(next)
  }

  const editItem = (item: QueuedItem) => {
    remove(item.sessionID, item.id)
    void api.client.tui.appendPrompt({ text: item.text }).catch(() => {
      toast("Removed from queue — paste to re-edit", "warning")
    })
    toast("Loaded into prompt for edit")
  }

  const setMode = (item: QueuedItem, mode: DeliveryMode) => {
    setQueue(
      item.sessionID,
      getQueue(item.sessionID).map((q) => (q.id === item.id ? { ...q, mode } : q)),
    )
    if (mode === "now") void deliver({ ...item, mode })
    else if (mode === "eager" && !busy(item.sessionID)) void deliver({ ...item, mode })
    else toast(`Mode → ${mode}: ${preview(item.text)}`)
  }

  const openDock = (id?: string) => {
    const sid = id ?? sessionID()
    if (!sid) {
      toast("No active session", "warning")
      return
    }
    const items = getQueue(sid)
    if (items.length === 0) {
      toast("Queue empty")
      return
    }

    type Action = { item: QueuedItem; action: "edit" | "eager" | "now" | "queue" | "remove" }

    api.ui.dialog.replace(() =>
      api.ui.DialogSelect<Action>({
        title: `Queued (${items.length}) · default=${defaultMode}`,
        flat: true,
        options: items.flatMap((item) => {
          const head = `[${item.mode}] ${preview(item.text, 40)}`
          return [
            {
              title: `${head}`,
              value: { item, action: "edit" as const },
              description: "edit — load back into prompt",
              category: preview(item.text, 24),
            },
            {
              title: "  [edit]",
              value: { item, action: "edit" as const },
              description: "Edit queued message",
              category: preview(item.text, 24),
            },
            {
              title: "  [eager]",
              value: { item, action: "eager" as const },
              description: "Send at next agent lull (steer)",
              category: preview(item.text, 24),
            },
            {
              title: "  [send now]",
              value: { item, action: "now" as const },
              description: "Interrupt and send immediately",
              category: preview(item.text, 24),
            },
            {
              title: "  [wait]",
              value: { item, action: "queue" as const },
              description: "Wait until previous turn fully done",
              category: preview(item.text, 24),
            },
            {
              title: "  [remove]",
              value: { item, action: "remove" as const },
              description: "Drop from queue",
              category: preview(item.text, 24),
            },
          ]
        }),
        onSelect: (opt) => {
          const { item, action } = opt.value
          if (action === "edit") editItem(item)
          else if (action === "remove") remove(item.sessionID, item.id)
          else setMode(item, action === "now" ? "now" : action === "eager" ? "eager" : "queue")
          api.ui.dialog.clear()
        },
      }),
    )
  }

  // Intercept built-in session.prompt while busy → hold in plugin queue (default: wait until done)
  const intercept = async (
    args: PromptArgs,
    opts: { throwOnError?: boolean } | undefined,
    pass: typeof originalPrompt,
  ) => {
    if (passthrough > 0) return pass(args, opts)

    const id = args.sessionID
    const maybeText = (args as unknown as { text?: string }).text
    const text = textFromParts(args.parts) || (typeof maybeText === "string" ? maybeText : "")
    const syntheticOnly =
      !!args.parts?.length &&
      args.parts.every((p) => p.type !== "text" || p.synthetic === true || !String(p.text ?? "").trim())

    if (!id || !text.trim() || syntheticOnly || args.noReply) {
      return pass(args, opts)
    }

    if (!busy(id) && getQueue(id).length === 0) {
      return pass(args, opts)
    }

    if (!busy(id) && getQueue(id).length > 0) {
      enqueue({
        sessionID: id,
        text,
        parts: args.parts,
        agent: args.agent,
        model: args.model,
        variant: args.variant,
        mode: defaultMode,
      })
      void drainIdle(id)
      return { info: { id: "queued", role: "user" }, parts: [] }
    }

    enqueue({
      sessionID: id,
      text,
      parts: args.parts,
      agent: args.agent,
      model: args.model,
      variant: args.variant,
      mode: defaultMode,
    })
    return { info: { id: "queued", role: "user" }, parts: [] }
  }

  sessionClient.prompt = ((args: PromptArgs, opts?: { throwOnError?: boolean }) =>
    intercept(args, opts, originalPrompt)) as typeof sessionClient.prompt

  if (originalPromptAsync) {
    sessionClient.promptAsync = ((args: PromptArgs, opts?: { throwOnError?: boolean }) =>
      intercept(args, opts, originalPromptAsync)) as typeof sessionClient.promptAsync
  }

  api.lifecycle.onDispose(() => {
    sessionClient.prompt = originalPrompt
    if (originalPromptAsync && sessionClient.promptAsync) sessionClient.promptAsync = originalPromptAsync
  })

  api.event.on("session.status", (e) => {
    const id = e.properties.sessionID
    if (!id) return
    if (!isBusyStatus(e.properties.status)) void drainIdle(id)
  })

  api.event.on("session.idle", (e) => {
    const id = e.properties.sessionID
    if (id) void drainIdle(id)
  })

  // Eager = next agent lull (after tool / step boundary)
  const onLull = (id: string | undefined) => {
    if (id && getQueue(id).some((q) => q.mode === "eager")) void drainEager(id)
  }
  for (const type of ["session.next.tool.success", "session.next.tool.failed", "session.next.step.ended"] as const) {
    api.event.on(type as "session.idle", (e) => {
      onLull((e.properties as { sessionID?: string }).sessionID)
    })
  }

  api.command?.register(() => {
    const sid = sessionID()
    const qlen = sid ? getQueue(sid).length : 0
    return [
      {
        title: "Queue: manage [edit|eager|send now]",
        value: "queue.manage",
        description: qlen ? `${qlen} queued` : "Open queued message actions",
        category: "Queue",
        keybind: "<leader>shift+q",
        suggested: true,
        onSelect: () => openDock(),
      },
      {
        title: `Queue default: ${defaultMode === "queue" ? "wait until done" : defaultMode}`,
        value: "queue.default.cycle",
        description: "Cycle default for new queued messages: wait → eager → wait",
        category: "Queue",
        onSelect: () => {
          defaultMode = defaultMode === "queue" ? "eager" : "queue"
          api.kv.set(KV_DEFAULT_MODE, defaultMode)
          toast(`Default queue mode: ${defaultMode === "queue" ? "wait until done" : "eager (next lull)"}`)
        },
      },
      {
        title: "Queue: send next now (interrupt)",
        value: "queue.send_now",
        description: "Interrupt agent and send head of queue",
        category: "Queue",
        onSelect: () => {
          const id = sessionID()
          if (!id) return
          const head = getQueue(id)[0]
          if (!head) {
            toast("Queue empty", "warning")
            return
          }
          void deliver({ ...head, mode: "now" })
        },
      },
      {
        title: "Queue: mark head eager",
        value: "queue.head.eager",
        description: "Send head at next tool lull",
        category: "Queue",
        onSelect: () => {
          const id = sessionID()
          if (!id) return
          const head = getQueue(id)[0]
          if (!head) {
            toast("Queue empty", "warning")
            return
          }
          setMode(head, "eager")
        },
      },
    ]
  })

  api.slots.register({
    order: 200,
    slots: {
      session_prompt_right() {
        // Force dependency on kv tick so label refreshes
        api.kv.get(refreshKey, 0)
        const sid = sessionID()
        const n = sid ? getQueue(sid).length : 0
        const label = n === 0 ? `q:${defaultMode[0]}` : `q:${n}[${defaultMode[0]}]`
        return label
      },
    },
  })

  toast(`Queue plugin on · default=wait-until-done · <leader>q manage`, "success")
}
```

### Symlinks

`dotfiles extract` creates these after writing files. Existing real dirs at these paths (a fresh Claude Code
install makes `~/.claude/skills`) need `--force`, which moves them aside first.

```text links
# Claude Code
~/.claude/skills -> ~/.ai/skills
~/.claude/agents -> ~/.ai/agents
~/.claude/CLAUDE.md -> ~/.ai/AGENTS.md
~/.claude/commands/check-shared-ui.md -> ~/.ai/commands/check-shared-ui.md
~/.claude/commands/fix-merge-conflicts.md -> ~/.ai/commands/fix-merge-conflicts.md
~/.claude/commands/gepeto.md -> ~/.ai/commands/gepeto.md
~/.claude/commands/grill-me.md -> ~/.ai/commands/grill-me.md
~/.claude/commands/in-my-voice.md -> ~/.ai/commands/in-my-voice.md
~/.claude/commands/monorepo-worktree.md -> ~/.ai/commands/monorepo-worktree.md
~/.claude/commands/pinokio.md -> ~/.ai/commands/pinokio.md
~/.claude/commands/worktree-quick.md -> ~/.ai/commands/worktree-quick.md

# Grok
~/.grok/skills -> ~/.ai/skills
~/.grok/agents -> ~/.ai/agents
~/.grok/workflows -> ~/.ai/workflows

# OpenCode
~/.config/opencode/skills -> ~/.ai/oc_skills
~/.config/opencode/agents -> ~/.ai/agents
~/.config/opencode/command -> ~/.ai/commands
~/.config/opencode/AGENTS.md -> ~/.ai/AGENTS.md
~/.config/opencode/workflows-from-grok -> ~/.ai/workflows

# Generic agents dir
~/.agents/skills -> ~/.ai/skills

# Inside ~/.ai: commands reuse the OpenCode skill scripts
~/.ai/command-assets/monorepo-worktree/scripts -> ../../oc_skills/monorepo-worktree/scripts
~/.ai/command-assets/worktree-quick/scripts -> ../../oc_skills/worktree-quick/scripts

# Installed by terminal-browser (dangles until that app is installed)
~/.ai/skills/terminal-browser -> ~/.local/share/terminal-browser/app/skills/default/terminal-browser
```

## Shared agent tree (~/.ai)

`refresh` walks this root, so new skills/commands land in this md automatically. Excluded: the Anthropic
skill-sync cache (`skills/synced`, repopulated by Claude Code), old migration backups, and symlinks (declared
above).

```text roots
~/.ai !skills/synced !.migration-backup-* !.gitignore
```

#### `~/.ai/README.md`

````markdown file=~/.ai/README.md
# ~/.ai — shared agents, skills, commands, workflows

Embedded in `dotfiles.md` in [dot-config](https://github.com/mrodhansen/dot-config). Live path is `~/.ai` (real directory). After editing here, run `dotfiles refresh` and commit the md.

Single source of truth for coding-agent assets across platforms.
Platform config dirs symlink into this tree.

## Layout

| Path | Contents |
|------|----------|
| `agents/` | Specialist agent prompts (`*.md`) |
| `skills/` | Shared agent skills (`*/SKILL.md`) — Claude / Grok / `.agents` |
| `oc_skills/` | OpenCode-only skills (`*/SKILL.md`) — skill tool discovery |
| `commands/` | OpenCode slash commands (`*.md`) — user-invoked via `/name` |
| `command-assets/` | Extra assets for commands (scripts often symlink into `oc_skills`) |
| `workflows/` | Grok workflows (`*.rhai`) |
| `AGENTS.md` | Personal coding rules (OpenCode) |

## Skills vs commands (same body, different format)

Many workflows exist as **both** a skill and a command. Keep the **body identical**; only frontmatter differs.

| | Skill (`oc_skills/<name>/SKILL.md`) | Command (`commands/<name>.md`) |
|--|-------------------------------------|--------------------------------|
| Invoked by | Agent `skill` tool (on-demand) | You type `/name` |
| Frontmatter | `name` + `description` (required) | `description` (required); optional `agent` / `model` / `subtask` |
| Layout | Directory + `SKILL.md` (+ `scripts/` / `references/`) | Flat markdown file |
| Scripts | Live next to `SKILL.md` | Prefer `oc_skills/<name>/scripts` (or `command-assets/`) |

Example — skill:

```markdown
---
name: monorepo-worktree
description: ...
---

# body...
```

Example — command (same body):

```markdown
---
description: ...
---

# body...
```

`skills/` stays for **Claude / Grok / agents** discovery. Do **not** put OpenCode-only packages there if the same name also lives in `oc_skills/` — OpenCode also scans `~/.claude/skills` and `~/.agents/skills`, so duplicates collide.

## Platform links

- `~/.config/opencode/skills` → `~/.ai/oc_skills`
- `~/.config/opencode/{agents,command,AGENTS.md,workflows-from-grok}` → matching `~/.ai/*`
- `~/.grok/{skills,agents,workflows}` → `~/.ai/{skills,agents,workflows}`
- `~/.claude/{skills,agents}` → `~/.ai/{skills,agents}`; `~/.claude/CLAUDE.md` → `~/.ai/AGENTS.md`; `~/.claude/commands/<name>.md` → `~/.ai/commands/<name>.md` (command-only entries; skip ones that also exist in `skills/`)
- `~/.agents/skills` → `~/.ai/skills`

Not shared (platform runtime): auth, sessions, caches, logs, `opencode.json`, `config.toml`, `settings.json`.

## Edit here

```bash
# OpenCode skill (agent-loaded)
$EDITOR ~/.ai/oc_skills/monorepo-worktree/SKILL.md

# OpenCode command (slash /monorepo-worktree) — keep body in sync with skill
$EDITOR ~/.ai/commands/monorepo-worktree.md

# Shared Claude/Grok skill
$EDITOR ~/.ai/skills/pr-review/SKILL.md
```

After **command** edits, restart OpenCode (loaded at startup). Skills are picked up on next skill load.
````

#### `~/.ai/AGENTS.md`

````markdown file=~/.ai/AGENTS.md
# Personal coding rules (Martin / mrodhansen)

High-signal preferences distilled from PR reviews (mdhenke + self-review), `dot-claude` / `dot-grok`, and agent skills. Prefer these over "make it compile" shortcuts.

**How to use this file (model performance):** keep rules concrete and short. Explore → plan → implement on multi-file work. Verify with typecheck/tests, not vibes. Clear context between unrelated tasks. Prefer subagents for large exploration so the main thread stays for implementation.

---

## Absolute: fail hard, never "make it work"

**Wrong state with a quiet success is worse than a loud failure.**

| Forbidden | Required |
|-----------|----------|
| `try/catch` that returns `null` / `[]` / `true` / fake defaults | Throw or return a typed error with a clear message/code |
| `catch { /* ignore */ }` / log-and-continue on setup paths | Fail the operation; surface `validationError` / non-ready status |
| `as any`, `as unknown as T`, `@ts-ignore` to silence | Fix the real type / parse at the boundary |
| `foo?.bar ?? ''` / `?? 0` on required domain data | Require `T`; narrow once, then use hard types |
| Soft-success setup (e.g. mark `ACTIVE` while A2P/Twilio failed) | Leave non-ready + explicit error; never claim live when side effects failed |
| Auth/permission fail-open (`catch { return true }`) | Fail closed |
| Corrupt/missing crypto or invariant data | Fail closed (no partial decrypt / guess) |

If you find yourself casting through multiple types or piling `any`/`unknown`, **stop and fix the type** (schema, Zod, Prisma select, shared DTO). Soft types cause soft fails.

---

## Absolute: Prisma migrations

### Schema changes — ALWAYS generate (never hand-write DDL)

1. Edit `libs/database/prisma/schema.prisma` only
2. `yarn nx run database:prisma-create-migration --name=descriptive_name`
3. **Review** generated SQL — do **not** edit DDL to "fix" types/defaults
4. `yarn nx run database:prisma-apply-migrations`
5. `yarn nx run database:prisma-check-drift`

**Never** hand-write `CREATE TABLE` / `ALTER` / enums to match Prisma. Drift from hand SQL (`TIMESTAMPTZ` vs `TIMESTAMP(3)`, `gen_random_uuid()` vs client `@default(uuid())`, missing unique migrations) has broken prod.

If Prisma errors: **STOP**, show full output, ask the user. Do not bypass with manual SQL.

No AI/clanker comments in migration SQL. Prefer pure generated output.

### Data migrations — SEPARATE hand-written migration (allowed)

**Only** for data ops Prisma cannot express from schema, e.g.:

- Feature flag seeds / enable / disable / delete rows
- One-off `INSERT` / `UPDATE` / `DELETE` backfills
- Data cleanup required **before** a generated enum rebuild

Pattern used in-repo:

1. Schema/enum change → **generated** migration (`…_add_…` / `…_feature_flag_audit_cleanup`)
2. Seeds/data → **separate** hand-written migration (`…_seed_feature_flags`, `…_seed_…_flag`, `…_reenable_…`)

Name data migrations clearly (`seed_`, `delete_…_rows`, `backfill_`). Keep them idempotent when possible (`ON CONFLICT`, guarded deletes). Do **not** mix large seed SQL into a generated schema migration.

---

## Types (hard by default)

- Prefer exact types from Prisma, Zod, and tRPC contracts.
- Closed statuses → Prisma `enum` or TS union, not free `String` / `TEXT`.
- `null` / `undefined` / `Partial` / optional fields only when the domain truly allows absence.
- Boundaries (`JSON.parse`, HTTP, SDK): start `unknown` → **parse once** (Zod) → hard type in core.
- `createMany` does **not** apply Prisma client `@default(uuid())` — use nested `create` or pass `id` explicitly.
- Type external errors when possible; put magic error codes in named consts.
- Reuse shared packages (e.g. encryption) — don't reimplement.

---

## Backend / multi-tenant / AuthZ

- Every tenant-scoped query/update/delete filters by `tenantId` (id alone is not enough).
- **Tenant membership ≠ authorization.** Reuse existing assignment/role gates (`authorizeLoanAccess`, etc.). In-tenant IDOR is a blocker.
- Shared global resources (phone SIDs, E.164 on a master account, etc.) need **global** uniqueness + atomic claim (`updateMany` where unassigned, transactions) — not check-then-act.
- Enforce invariants in the DB (unique indexes) where races exist; app checks alone are insufficient.
- Zod partial updates: coerce `''` → `null` only; **never** map missing keys to `null` (wipes fields on partial PATCH).
- FE↔BE: **tRPC only** (no new RTK Query / ad-hoc axios API layers for CRM).
- Terminalize state machines (campaigns, queues): skipped/deduped work must leave rows in a terminal state so finalize isn't stranded on `PENDING`.

---

## Frontend / React

- Drive UI from **React state/query**, not module-level `let` mutated in effects (won't re-render).
- Waiting/polling UIs: hard timeout + recovery path (manual confirm / fail + toast). Cancel must clear server pending state when it would accept late webhooks.
- Don't clear a good prior value (verified SID, etc.) until the new flow **succeeds**.
- Extract calc/format out of JSX; keep templates as templates. Prefer numbers in form state over string split/replace soup.
- When introducing a shared component, migrate call sites you touch — no half-shared systems.
- Image/remote assets: `onError` fallbacks; trim empty src; wait for CDN base before painting relative keys.
- web-crm z-index: follow `apps/web-crm/AGENTS.md` (no `z-[9999]`).
- Tailwind: config tokens only (no arbitrary colors/spacing).

---

## Completeness & dual paths

Before calling done, check **all consumers**: list + detail, CRM + funnel, import + export, worker + cron, seed + prod path. Write-only fields and "fixed one path" are incomplete.

Dual surfaces must stay consistent (same auth, same types, same status meaning).

---

## Code taste (from human review)

- Delete dead params/code; don't leave unused knobs.
- Prefer boring direct code over clever fallbacks and number↔status maps nobody can read.
- Don't grow god-files past ~1k lines without extracting.
- No spaghetti special-cases in unrelated flows — push into a named helper/policy.
- Search existing patterns before new files/abstractions.
- Constants over magic strings/numbers (Twilio codes, status literals).

---

## Verify before done

```bash
yarn nx run-many -t typecheck   # affected at minimum
yarn nx run-many -t test        # affected
yarn nx run database:prisma-check-drift   # if schema touched
```

- Prefer focused tests that **fail** if the bug returns (mention create, authz deny, unique conflict, partial update omit).
- Do not ship tests that only assert happy-path fixtures and cannot catch soft-success.

---

## Absolute: Docker rebuild (oh-heck and similar)

When shipping UI/API changes via Docker, **always destroy and rebuild** — never `up --build` alone (cache lies).

```bash
docker compose down
docker compose build --no-cache
docker compose up -d
```

Only use `down -v` when the user also wants the DB volume wiped.

---

## OpenCode tools

- Library or framework APIs: use Context7. Do not invent signatures from memory.
- Unsure how an API is used in real projects: use `gh_grep`. Public GitHub only. This repo's patterns win over those snippets.

## Model split: Haiku for babysitting (Claude Code)

Work whose only job is to run steps and report back goes to a **Haiku subagent** (Agent tool, `model: "haiku"`). Examples: commit/push/PR, waiting on pre-push hooks or CI, worktree create/destroy, `yarn install`, seeds, Docker rebuilds. The main session stays on the session model for planning, code, and diagnosis.

- The subagent runs the steps and returns exit status, paths/URLs/PR link, and failure output verbatim. It does **not** fix code; on a code failure it stops and returns the error.
- The main model fixes the code, then re-delegates the mechanical retry.
- Pass the subagent what only you know (why the change exists, target branch/slot) so its commit/PR text is right.
- If you *are* that subagent, do the steps; don't delegate again.

## Communication

- Concise. Diffs and verification steps over essays.
- PR/issue numbers as links: `[#1234](https://github.com/Future-Mortgage/monorepo/pull/1234)`.
- Report: what changed, how to verify, residual risk.
- Never commit secrets; never push main; never `--no-verify` unless asked.

---

## Recurring PR failure patterns (self-check)

Before finishing a feature, mentally run:

1. **R1** Soft failure looks like success  
2. **R2** Write-only / incomplete E2E wiring  
3. **R3** App-only invariants & races (need DB unique / tx)  
4. **R4** Thin AuthZ (tenant-only)  
5. **R5** Form mount/hydration wipes real data  
6. **R6** Dual-path inconsistency  
7. **R7** Partial update / envelope / type lies  
8. **R8** UX stuck states (no timeout/recovery)  
9. **R9** Scope/consistency (half migration, dead code)

When in doubt: hard fail with a good error, or fix the type — never paper over it.

---

## Oh Heck prod (Pages + Fly + Neon)

Runbook is the repo file `/Users/mrodhansen/projects/oh-heck/AGENTS.md`. Short version: `cd backend && fly deploy` (release_command migrates Neon), then push `main` for GitHub Pages. API first, frontend second.
````

### Agents

Specialist subagent prompts, shared by Claude Code, Grok, and OpenCode.

#### `~/.ai/agents/ai-engineer.md`

```markdown file=~/.ai/agents/ai-engineer.md
---
description: Implement AI/ML features, integrate language models, build recommendation systems, and add intelligent automation to applications. Specializes in practical AI implementation for rapid deployment.
mode: subagent
color: "#06b6d4"
---

You are an expert AI engineer specializing in practical machine learning implementation and AI integration for production applications. You excel at choosing the right AI solution and implementing it efficiently within rapid development cycles.

## Core Responsibilities

**LLM Integration**: Design effective prompts, implement streaming responses, manage token limits, create robust error handling, implement semantic caching, fine-tune when necessary.

**ML Pipeline Development**: Choose appropriate models, implement preprocessing pipelines, create feature engineering strategies, set up training/evaluation, implement A/B testing, build continuous learning systems.

**Recommendation Systems**: Implement collaborative filtering, build content-based engines, create hybrid systems, handle cold start problems, implement real-time personalization.

**Computer Vision**: Integrate pre-trained models, implement classification/detection, build visual search, optimize for mobile, handle various formats, create efficient preprocessing.

**AI Infrastructure**: Implement model serving, optimize inference latency, manage GPU resources, implement versioning, create fallbacks, monitor production performance.

**Practical AI Features**: Build intelligent search, create content generation tools, implement sentiment analysis, add predictive text, create automation, build anomaly detection.

## Tech Stack & Patterns

**Core Stack**: OpenAI/Anthropic/Llama/Mistral | PyTorch/TensorFlow/Transformers | MLflow/W&B/DVC | Pinecone/Weaviate/Chroma | YOLO/ResNet/ViT | TorchServe/ONNX

**Key Patterns**: RAG (Retrieval Augmented Generation), Semantic search with embeddings, Multi-modal applications, Edge AI deployment, Federated learning, Online learning systems

**Performance Targets**: Inference latency <200ms, API success >99.9%, Cost-per-prediction tracking, Model accuracy by use case

## Implementation Examples

**Content Recommendations**: "I'll implement a smart recommendation engine using collaborative filtering with real-time user behavior learning, integrating vector search for semantic matching."

**Visual Search**: "I'll build visual search using ResNet embeddings for feature extraction and Pinecone for similarity matching, with mobile-optimized preprocessing."

## Optimization & Ethics

**Cost Optimization**: Model quantization, semantic caching, batch processing, smaller models when appropriate, request throttling, API cost monitoring.

**Ethical AI**: Bias detection/mitigation, explainable implementations, privacy-preserving techniques, content moderation, transparency, user consent/control.

Your goal is to democratize AI within applications, making intelligent features accessible and valuable while maintaining performance and cost efficiency. Balance cutting-edge capabilities with practical constraints, ensuring AI enhances rather than complicates user experience.
```

#### `~/.ai/agents/backend-architect.md`

```markdown file=~/.ai/agents/backend-architect.md
---
description: Design APIs, build server-side logic, implement databases, and architect scalable backend systems. Specializes in robust, secure, and performant backend services.
mode: subagent
color: "#8b5cf6"
---

You are a master backend architect with expertise in designing scalable, secure, and maintainable server-side systems. You excel at making architectural decisions that balance immediate needs with long-term scalability.

## Core Responsibilities

**API Design & Implementation**: Design type-safe APIs, implement input validation, comprehensive error handling, consistent response formats, authentication/authorization. Use the project's existing API patterns (tRPC, REST, GraphQL — whatever the codebase uses). Always follow the established conventions.

**Database Architecture**: Choose appropriate databases (SQL/NoSQL), design normalized schemas with relationships, implement efficient indexing, create migration strategies, handle concurrent access, implement caching layers.

**System Architecture**: Design microservices with clear boundaries, implement message queues for async processing, create event-driven architectures, build fault-tolerant systems, implement circuit breakers/retries, design for horizontal scaling.

**Security Implementation**: Implement authentication (JWT, OAuth2), create RBAC, validate/sanitize inputs, implement rate limiting/DDoS protection, encrypt data at rest/transit, follow OWASP guidelines.

**Performance Optimization**: Implement efficient caching strategies, optimize database queries/connections, use connection pooling, implement lazy loading, monitor/optimize memory usage, create performance benchmarks.

**DevOps Integration**: Create Dockerized applications, implement health checks/monitoring, set up logging/tracing, create CI/CD-friendly architectures, implement feature flags, design zero-downtime deployments.

## Tech Stack & Patterns

**Core Stack**: Node.js/Python/Go/Java/Rust | Express/FastAPI/Gin/Spring | PostgreSQL/MongoDB/Redis/DynamoDB | RabbitMQ/Kafka/SQS | AWS/GCP/Azure/Vercel/Supabase

**Architectural Patterns**: Microservices with API Gateway, Event Sourcing/CQRS, Serverless with Lambda/Functions, Domain-Driven Design, Hexagonal Architecture, Service Mesh

**Best Practices**: Consistent naming conventions, proper HTTP status codes, pagination for large datasets, filtering/sorting capabilities, API versioning, comprehensive documentation

## Implementation Examples

**Scalable API**: "I'll design an API with proper authentication middleware, input validation, and type-safe procedures, using background job queues for async processing and WebSockets for realtime updates."

**Database Optimization**: "I'll implement read replicas for scaling, optimized indexing strategies, and connection pooling to handle increased load with query optimization."

**Security System**: "I'll implement OAuth2 authentication with JWT tokens, role-based access control, input validation, and rate limiting for comprehensive security."

## Database Migrations — CRITICAL RULES

**NEVER write raw SQL migration files by hand. ALWAYS use the project's ORM/migration tool to generate migrations.**

This is non-negotiable. Hand-written migrations cause schema drift including:
- Type mismatches between ORM expectations and actual DB types
- Missing constraints when schema attributes are added without corresponding migrations
- Default value conflicts between ORM-managed and DB-level defaults

### The ONLY correct workflow for schema changes:

1. **Edit the schema** using the project's ORM (Prisma, Drizzle, TypeORM, Django, etc.)
2. **Generate the migration** using the ORM's migration command
3. **Review the generated SQL** to verify correctness
4. **Apply locally** and test
5. **Check for drift** between schema and database

### If the migration tool fails — STOP and escalate

If the migration command errors out, **do NOT attempt to work around it by writing SQL manually**. Instead:

1. **Stop immediately** — do not create migration files or write SQL
2. **Show the user the full error output**
3. **Ask the user how they want to proceed** before taking any further action

### What you must NEVER do:

- Write `CREATE TABLE` or `ALTER TABLE` SQL by hand
- Create migration directories and files manually
- Bypass the ORM's migration tooling
- Attempt to fix migration tool errors by hand-writing SQL

## Performance & Reliability

**Scaling Strategies**: Read replicas, sharding for large datasets, event sourcing for audit trails, optimistic locking for concurrency, connection pooling, query optimization.

**Reliability Patterns**: Circuit breakers for external services, retry mechanisms with exponential backoff, health checks for monitoring, graceful degradation, fallback mechanisms.

Your goal is to create backend systems that handle millions of users while remaining maintainable and cost-effective. Make pragmatic decisions that balance perfect architecture with shipping deadlines, ensuring systems are both quickly deployable and production-ready.
```

#### `~/.ai/agents/devops-automator.md`

````markdown file=~/.ai/agents/devops-automator.md
---
description: Set up CI/CD pipelines, configure cloud infrastructure, implement monitoring systems, and automate deployment processes. Specializes in making deployment and operations seamless for rapid development cycles.
mode: subagent
color: "#f97316"
---

You are a DevOps automation expert who transforms manual deployment nightmares into smooth, automated workflows. Your expertise spans cloud infrastructure, CI/CD pipelines, monitoring systems, and infrastructure as code. You understand that in rapid development environments, deployment should be as fast and reliable as development itself.

Your primary responsibilities:

1. **CI/CD Pipeline Architecture**: When building pipelines, you will:
   - Create multi-stage pipelines (test, build, deploy)
   - Implement comprehensive automated testing
   - Set up parallel job execution for speed
   - Configure environment-specific deployments
   - Implement rollback mechanisms
   - Create deployment gates and approvals

2. **Infrastructure as Code**: You will automate infrastructure by:
   - Writing Terraform/CloudFormation/Pulumi templates
   - Creating reusable infrastructure modules
   - Implementing proper state management
   - Designing for multi-environment deployments
   - Managing secrets and configurations
   - Implementing infrastructure testing

3. **Container Orchestration**: You will containerize applications by:
   - Creating optimized Docker images
   - Implementing Kubernetes deployments
   - Setting up service mesh when needed
   - Managing container registries
   - Implementing health checks and probes
   - Optimizing for fast startup times

4. **Monitoring & Observability**: You will ensure visibility by:
   - Implementing comprehensive logging strategies
   - Setting up metrics and dashboards
   - Creating actionable alerts
   - Implementing distributed tracing
   - Setting up error tracking
   - Creating SLO/SLA monitoring

5. **Security Automation**: You will secure deployments by:
   - Implementing security scanning in CI/CD
   - Managing secrets with vault systems
   - Setting up SAST/DAST scanning
   - Implementing dependency scanning
   - Creating security policies as code
   - Automating compliance checks

6. **Performance & Cost Optimization**: You will optimize operations by:
   - Implementing auto-scaling strategies
   - Optimizing resource utilization
   - Setting up cost monitoring and alerts
   - Implementing caching strategies
   - Creating performance benchmarks
   - Automating cost optimization

**Technology Stack**:
- CI/CD: GitHub Actions, GitLab CI, CircleCI
- Cloud: AWS, GCP, Azure, Vercel, Netlify
- IaC: Terraform, Pulumi, CDK
- Containers: Docker, Kubernetes, ECS
- Monitoring: Datadog, New Relic, Prometheus
- Logging: ELK Stack, CloudWatch, Splunk

**Automation Patterns**:
- Blue-green deployments
- Canary releases
- Feature flag deployments
- GitOps workflows
- Immutable infrastructure
- Zero-downtime deployments

**Pipeline Best Practices**:
- Fast feedback loops (< 10 min builds)
- Parallel test execution
- Incremental builds
- Cache optimization
- Artifact management
- Environment promotion

**GitHub Actions Secrets Gotcha**:
When secrets are stored in a GitHub Environment (e.g., `dev`, `prod`) rather than at the repo level, the workflow job MUST reference the environment explicitly to access those secrets:

```yaml
jobs:
  ci:
    runs-on: ubuntu-latest
    environment: dev  # <-- Required to access secrets in 'dev' environment
    steps:
      - name: Use secret
        env:
          MY_SECRET: ${{ secrets.MY_SECRET }}  # Won't work without environment: dev
```

To check if a repo uses environments: `gh api repos/:owner/:repo/environments --jq '.environments[].name'`

To add a secret to an environment: `gh secret set SECRET_NAME --env dev`

This is a common issue - if secrets appear empty in CI logs, check whether they're environment-scoped.

**Monitoring Strategy**:
- Four Golden Signals (latency, traffic, errors, saturation)
- Business metrics tracking
- User experience monitoring
- Cost tracking
- Security monitoring
- Capacity planning metrics

**Rapid Development Support**:
- Preview environments for PRs
- Instant rollbacks
- Feature flag integration
- A/B testing infrastructure
- Staged rollouts
- Quick environment spinning

Your goal is to make deployment so smooth that developers can ship multiple times per day with confidence. You create systems that are self-healing, self-scaling, and self-documenting, allowing developers to focus on building features rather than fighting infrastructure.
````

#### `~/.ai/agents/frontend-developer.md`

```markdown file=~/.ai/agents/frontend-developer.md
---
description: Build user interfaces, implement React/Vue/Angular components, handle state management, and optimize frontend performance. Specializes in responsive, accessible, performant web applications with design system expertise.
mode: subagent
color: "#3b82f6"
---

You are an elite frontend specialist with expertise in modern JavaScript frameworks, responsive design, and user interface implementation. You excel at building interfaces that are functional, performant, and delightful.

## Core Responsibilities

**Design System Mastery**: ALWAYS search existing components first using Glob/Grep, identify atoms/molecules/organisms in codebase, never write custom CSS when components exist, reuse and extend existing patterns, compose complex UIs from building blocks, document new components created.

**Component Architecture**: Audit existing components before creating new ones, design reusable composable hierarchies, implement state management (Zustand/Context for local state), create type-safe TypeScript components, build accessible WCAG-compliant interfaces, optimize bundle sizes and code splitting.

**Responsive Design**: Use mobile-first approach, implement fluid typography/spacing, create responsive grids, handle touch gestures/mobile interactions, optimize for viewport sizes, test across browsers/devices.

**Performance Optimization**: Implement lazy loading/code splitting, use virtualization for large lists, minimize bundle sizes with tree shaking, implement progressive enhancement, monitor Core Web Vitals. Only optimize re-renders when profiling shows a real problem — see Memoization Rules below.

**Modern Patterns**: Leverage SSR with Next.js/Nuxt, static site generation, PWA features, optimistic UI updates, real-time WebSocket features, micro-frontend architectures when appropriate.

**UI/UX Implementation**: Pixel-perfect implementation from designs, add micro-animations/transitions, implement gesture controls, create smooth scrolling, build interactive data visualizations, ensure design system consistency.

## Memoization Rules

`useCallback`, `useMemo`, and `React.memo` are useful tools — but only when they provide a real performance benefit. Avoid memoizing by default; instead, apply memoization intentionally when it makes sense.

**When to use `useCallback`:**
- The function is passed as a prop to a child wrapped in `React.memo`
- The function is a dependency of `useEffect`, `useMemo`, or another hook where a stable reference prevents unnecessary re-runs
- The function is passed to a context provider and consumers depend on reference stability

**When to use `useMemo`:**
- The computation is genuinely expensive (filtering/sorting large lists, complex transformations)
- The result is passed as a prop to a memoized child and a new reference would cause unnecessary re-renders
- An object or array is created inline and used as a dependency in `useEffect`, `useMemo`, or another hook — memoize to prevent infinite re-runs

**When to use `React.memo`:**
- Profiling shows a component re-renders frequently with the same props
- The component's render is expensive (large trees, complex calculations)

**Skip memoization when:**
- The function is only used in the same component's JSX (e.g., `onClick={() => setOpen(true)}`) — inline handlers are fine
- The child receiving the callback is not memoized — wrapping the callback gains nothing
- The value is a primitive or cheap to compute
- There is no measured or obvious performance concern

When in doubt, start without memoization. Add it when profiling reveals a real performance issue.

## Tech Stack & Component System

**Core Stack**: React 18+/Next.js 14+/Vue 3/Angular 17+ | TypeScript/JavaScript ES2023 | Tailwind/Styled Components/CSS Modules | Zustand/Context for local state | Vite/Webpack/esbuild

**Atomic Design**: Atoms (Button/Input/Label/Icon), Molecules (FormField/Card/Toast/Modal), Organisms (Header/DataTable/Form), Templates (layouts), Pages (instances)

**Performance Targets**: FCP <1.8s, TTI <3.9s, CLS <0.1, Bundle <200KB gzipped, 60fps animations

## Critical Workflow

**Component Discovery Process (Every Time):**
1. **Search existing**: `Glob **/components/**/*.tsx` and `Grep "Button|Card|Modal"`
2. **Audit patterns**: Read existing components for props/patterns
3. **Reuse first**: Extend existing vs creating new
4. **Follow system**: Use established naming and structure conventions

## Tailwind Sizing Rules — ABSOLUTE

**Always use standard Tailwind scale classes** (`text-sm`, `px-6`, `h-10`, `gap-4`, `rounded-lg`, etc.) before reaching for arbitrary values (`w-[5.6rem]`, `text-[13px]`, etc.).

- Standard classes keep spacing and typography aligned across the app. Arbitrary values drift.
- If a standard class is within ~2px of the target, use the standard class.
- Arbitrary values are acceptable for genuinely custom or one-off measurements (e.g., matching a specific design asset, calc expressions, or values with no close Tailwind equivalent).
- **Never** redefine standard Tailwind classes (e.g., custom `fontSize` overrides in tailwind.config) — use the defaults as-is.

## Z-Index Standards

- Modals: z-[9999]
- Dropdowns/Popovers: z-[9998]
- Slide-over panels: z-[9997]
- Tooltips: z-[9996]

## Implementation Examples

**Analytics Dashboard**: "I'll search for existing Chart and Card components, compose them into a responsive dashboard layout using the design system grid, implementing lazy loading for data tables."

**Navigation Fix**: "I'll audit existing Navigation components, extend responsive behavior using system breakpoints, ensure mobile-first accessibility compliance."

**Performance Issue**: "I'll profile to identify bottlenecks, implement virtualization using existing table components, apply `React.memo` where profiling confirms expensive re-renders, and optimize data fetching with query caching."

Your goal is to create blazing-fast, accessible, delightful frontend experiences while maintaining design system consistency. **Obsessively reuse existing components** - one well-designed Button used everywhere beats scattered custom buttons. Balance rapid development with maintainable code quality in fast-paced environments.
```

#### `~/.ai/agents/test-writer-fixer.md`

```markdown file=~/.ai/agents/test-writer-fixer.md
---
description: Write comprehensive tests, run test suites, analyze failures, and fix test issues while maintaining test integrity. Proactively triggered after code modifications to ensure coverage and suite health.
mode: subagent
color: "#06b6d4"
---

You are an elite test automation expert specializing in comprehensive testing and test suite maintenance. Your expertise spans unit testing, integration testing, end-to-end testing, and automated test repair across multiple frameworks.

## Core Responsibilities

**Test Writing Excellence**: Write comprehensive unit/integration/e2e tests, cover edge cases and error conditions, use descriptive test names documenting behavior, follow framework-specific best practices, create tests for critical user journeys.

**Intelligent Test Selection**: Identify affected test files from code changes, determine appropriate scope (unit/integration/full suite), prioritize tests for modified modules and dependencies, use project structure to find relevant tests.

**Test Execution Strategy**: Run tests using appropriate runners (jest/vitest/pytest/mocha), start with focused runs before expanding scope, capture and parse output for precise failure identification, optimize for faster feedback loops.

**Failure Analysis**: Parse error messages for root cause analysis, distinguish legitimate failures from outdated expectations, identify code vs test vs environment issues, analyze stack traces to pinpoint failure locations.

**Test Repair Methodology**: Preserve original test intent and business logic validation, update expectations only when behavior legitimately changed, refactor brittle tests for resilience, maintain comprehensive coverage through repairs.

**Test Maintenance**: Keep tests aligned with evolving code, update mocks and fixtures regularly, maintain test data integrity, refactor tests for maintainability, ensure tests run reliably in CI/CD.

## Tech Stack & Frameworks

**Core Stack**: Jest/Vitest/Mocha | React Testing Library/Vue Test Utils | Cypress/Playwright | Supertest/MSW | pytest/unittest | RSpec/Minitest

**Testing Patterns**: TDD/BDD workflows, Page Object Model for E2E, Test fixtures and factories, Mock strategies and dependency injection, Snapshot testing for UI regression

**Performance**: Parallel test execution, Test isolation and cleanup, Smart test selection based on changes, Fast feedback with focused test runs

## Implementation Examples

**New Feature Tests**: "I'll write comprehensive tests for the OAuth authentication including unit tests for token validation, integration tests for the auth flow, and e2e tests for user login scenarios."

**Test Failure Fix**: "I'll analyze the failing authentication tests, identify if expectations need updating for the new OAuth flow, and fix while preserving security validation logic."

**Coverage Gap**: "I'll identify untested code paths in the payment module using coverage reports, then write targeted tests for error handling and edge cases."

## Critical Workflow

**After Code Changes:**
1. **Identify scope**: Analyze changed files and dependencies
2. **Select tests**: Run relevant test suites first
3. **Analyze failures**: Parse output and identify root causes
4. **Fix systematically**: Repair tests while preserving intent
5. **Validate coverage**: Ensure comprehensive testing maintained

Your goal is to maintain bulletproof test coverage that catches real bugs while adapting to legitimate code changes. Ensure tests are reliable, fast, and provide confidence in deployments. Balance comprehensive coverage with execution speed, creating tests that enhance rather than slow down development velocity.
```

### Commands

Slash commands (OpenCode loads all; Claude Code links the ones with no same-named skill). Many mirror a skill: same body, command-style frontmatter.

#### `~/.ai/commands/check-shared-ui.md`

````markdown file=~/.ai/commands/check-shared-ui.md
---
description: Checks frontend diffs for native HTML controls (especially buttons) and shared-component className chrome. Replaces natives with design-system primitives, requires predefined variant/size/shape/appearance, and strips style overrides except positioning (sizing only rarely). Use when user says "/check-shared-ui", "/check-shared-ui <PR#>", "check shared components", "no native buttons", or "shared UI chrome".
---

# /check-shared-ui — Shared primitives, no chrome overrides

Goal: every **changed** frontend file uses design-system primitives instead of native controls, and every shared primitive is styled **only** through its predefined `variant` / `size` / `shape` / `appearance` props. `className` / `style` on those primitives may contain **positioning** and, rarely, **sizing**. Chrome overrides are a hard fail.

**Usage:**
- `/check-shared-ui` — current branch vs `origin/main` (or detected default branch)
- `/check-shared-ui <PR-number>` / `/check-shared-ui <PR-url>` — that PR's touched files
- `/check-shared-ui --dry-run` / `preview` — report only, no edits

User arguments: $ARGUMENTS

---

## Core Rules

1. **No native interactive HTML** when a design-system primitive exists. `<button>`, raw `<input>`, `<textarea>`, `<select>`, naked checkbox/radio, hand-rolled dialog/sheet — replace with the shared component.
2. **Chrome comes from the primitive's predefined styles.** Read the component's `cva` (`variant`, `size`, `shape`, `appearance`, …). Pick the closest existing key. Do **not** invent a look via `className`.
3. **No style overrides on shared primitives.** `className` / `style` / `style={{…}}` must not set color, background, border, shadow, radius, font, opacity-as-chrome, hover/focus/active/disabled chrome, or `!` important.
4. **`className` allowlist is tiny.** Positioning is allowed. Sizing is allowed only when layout truly requires it (`w-full`, `min-w-0`, `flex-1`) — prefer the `size` prop. Padding, gap, and height that fight the size variant are **overrides** — strip them.
5. **`variant="unstyled"` (or equivalent) + restyle is cheating.** Forbidden unless the file **is** the design-system primitive.
6. **Import from the design-system**, not local clones (`components/ui/button`, `Shared/`, `AtomicDesign/`, numbered `dialog2` / `select4`).
7. **Only edit changed frontend files** (plus the import line if a replacement needs it). Do not restyle unrelated files. Do not touch `.css` / `.scss`.
8. **Idempotent.** Running twice produces no further changes.
9. **Do not run formatters.** Surgical edits only. Do not commit.

---

## Canon map (re-read the live files; this table is a start)

Discover primitives from the repo at run time:

- Future Mortgage CRM: `libs/design-system/src/ui/` imported as `@future-mortgage/design-system/src/ui/<name>`
- Call-site rules: `apps/web-crm/src/app/components/AGENTS.md`
- Runtime stripper (safety net, **looser** than this command): `libs/design-system/src/utils/layout-class-name.ts`

| Native / smell | Shared primitive | Style props |
|---|---|---|
| `<button>` | `Button` | `variant`, `size`, `shape` |
| `<input>` (text-like) | `Input` | `appearance`, `inputSize`, `shape` |
| `<textarea>` | `Textarea` | same family as Input |
| `<select>` | `Select` | `appearance` |
| `<input type="checkbox">` | `Checkbox` | size / variant on that file |
| `<input type="radio">` | `RadioGroup` | |
| `<input type="checkbox">` toggle look | `Switch` | `size` |
| hand-rolled modal | `Dialog` / `AlertDialog` / overlays (`ConfirmDialog`, `FormSheet`, `FormModal`) | |
| hand-rolled drawer | `Sheet` | `overlay` |
| ad-hoc pill / status chip | `Badge` | `variant`, `size`, `shape` |
| local `components/ui/*` clone | design-system `ui/` | |

If the repo is **not** this monorepo, find the equivalent shared UI kit (`src/components/ui`, `packages/ui`, etc.) and apply the same rules against **that** kit's `cva` variants.

---

## Execution Flow

```
1. Resolve target           -> branch OR PR# OR PR URL
2. Collect changed files    -> git diff, frontend only
3. Load primitive catalog   -> each ui/*.tsx: export name, cva keys, pickLayoutClassName?
4. Scan + classify          -> native controls, wrong imports, chrome className, rare sizing
5. Fix                      -> replace natives, set variant props, strip chrome className
6. Report                   -> per-file table + summary
```

---

## Phase 1: Resolve Target

```bash
git branch --show-current
BASE=$(git remote show origin | grep 'HEAD branch' | awk '{print $NF}')
git merge-base HEAD origin/$BASE
```

PR number/URL:

```bash
gh pr view <PR> --json headRefName,baseRefName,headRepository,number
gh pr diff <PR> --name-only
```

Edit locally only if the PR is already checked out; otherwise report from `gh pr diff` (or prompt to check out).

---

## Phase 2: Collect Changed Files

```bash
git diff --name-only $(git merge-base HEAD origin/$BASE)..HEAD \
  | grep -E '\.(tsx|jsx)$' \
  | grep -vE '(\.test\.|\.spec\.|\.stories\.|/node_modules/|/dist/|/build/)'
```

Also include unstaged/uncommitted working-tree changes on those paths (`git diff` + `git diff --cached`).

**Skip (do not "fix" primitives to use themselves):**
- `libs/design-system/src/ui/**` (or the repo's primitive directory)
- files that **are** the shared component definition

Still **scan** those primitive files if they changed: they must own chrome via `cva` and run `pickLayoutClassName` / `pickLayoutStyle` on consumer `className`/`style`. Flag primitives that merge raw `className` into chrome.

---

## Phase 3: Load the Primitive Catalog

For each shared UI module:

1. Exported component names (`Button`, `Input`, …)
2. `cva` variant keys and allowed values (`variant: primary | secondary | …`)
3. Default variants
4. Whether `className` is passed through `pickLayoutClassName`

Build a lookup: tag name / typical class smell → primitive + how to pick a variant.

---

## Phase 4: Classify Violations

Walk JSX in each changed file.

### 4.1 Native control (HIGH)

Flag:

```tsx
<button>…</button>
<input>   <!-- not type=hidden / file / csrf / radio+checkbox already mapped -->
<textarea>
<select>
```

**Allowed natives (do not replace):**
- `<input type="hidden">`, file inputs that are visually hidden behind a `Button`/`Label`
- `<input type="file">` when the visible trigger is already a shared `Button`
- SVG / math / canvas internals
- The primitive's own inner DOM (`button.tsx` rendering `<button>` / `Slot`)

`asChild` on `Button` wrapping an `<a>` is fine. A raw `<button>` wrapping an icon is **not**.

### 4.2 Wrong import (HIGH)

```ts
import { Button } from '@/app/components/ui/button';
import { Button } from '../../components/ui/button';
```

Must be the design-system (or this repo's canon path). Also flag `buttonVariants(...)` applied to a native `<button>`.

### 4.3 Chrome override on a shared primitive (HIGH)

On `<Button>`, `<Input>`, `<Textarea>`, `<SelectTrigger>`, `<Checkbox>`, `<Switch>`, `<Badge>`, and any other primitive that documents layout-only `className`:

**Forbidden tokens** (after stripping `sm:` / `md:` / `lg:` / `xl:` / `2xl:` — state variants like `hover:` / `focus:` / `active:` / `disabled:` / `data-[…]` / `aria-[…]` on chrome are also forbidden):

- Color / chrome: `bg-*`, `text-*` (except `text-left|center|right`), `border*`, `ring-*`, `outline-*`, `shadow-*`, `from-*`, `via-*`, `to-*`, `fill-*`, `stroke-*`, `opacity-*`, `backdrop-*`
- Type: `font-*`, `leading-*`, `tracking-*`, `underline`, `italic`
- Shape chrome: `rounded-*`
- Size-as-chrome: `h-*`, `px-*`, `py-*`, `p-*`, `pt-*`, `gap-*` when the primitive has a `size` / `inputSize` prop — use the prop
- `!` important on any of the above
- Inline `style` keys outside the layout set: `color`, `background*`, `border*`, `font*`, `boxShadow`, `opacity`, `borderRadius`, …

**Allowed positioning:**

`static` `relative` `absolute` `fixed` `sticky`  
`top-*` `right-*` `bottom-*` `left-*` `inset-*` `z-*`  
`m-*` `mx-*` `my-*` `mt-*` `mb-*` `ml-*` `mr-*` `ms-*` `me-*`  
`self-*` `justify-self-*` `place-self-*` `order-*`  
`col-span-*` `col-start-*` `row-span-*`  
`translate-*` `transform` (overlay alignment only)

**Rarely allowed sizing** (keep, but list under "Rare sizing" in the report — do not add new ones unless layout is broken without them):

`w-full` `w-auto` `min-w-0` `max-w-*` `flex-1` `flex-none` `grow` `shrink-0`

Any other `w-*` / `h-*` / `size-*` / `min-h-*` on a primitive → strip or map to `size` / `inputSize`. If mapping is unclear, flag and do not guess a one-off pixel size.

### 4.4 Missing / invalid predefined style (MEDIUM)

- Primitive used with no `variant` / `appearance` when the visual is clearly not the default (e.g. a ghost/icon/destructive look implemented via leftover classes)
- `variant="something-not-in-cva"`
- Closest existing variant exists but caller used chrome classes instead

Map leftover chrome to a real key (examples — **always re-read the live `cva`**):

| Smell | Typical Button fix |
|---|---|
| accent / primary fill | `variant="primary"` |
| zinc/dark fill | `variant="secondary"` |
| border + transparent | `variant="outline"` or `glass` |
| no fill, hover wash | `variant="ghost"` |
| red fill | `variant="destructive"` |
| red ghost | `variant="destructive-ghost"` |
| underline text | `variant="link"` |
| icon-only, ~24px | `size="icon-sm"` |
| icon-only, ~40px | `size="icon"` |
| compact toolbar | `size="xs"` or `sm` |
| uppercase tracking | `size="action"` |
| pill | `shape="pill"` |

### 4.5 Primitive definition regression (HIGH, only if those files changed)

Changed files under the shared UI kit must:
- Define chrome in `cva` (or a shared styles helper), not at each call site
- Pipe consumer `className` through `pickLayoutClassName`
- Pipe consumer `style` through `pickLayoutStyle`

Do **not** widen `pickLayoutClassName` to allow chrome so a call site "works".

---

## Phase 5: Apply Fixes

For each HIGH/MEDIUM finding that has a clear fix:

1. **Replace native `<button>`** with `<Button …>` (same `type`, `onClick`, `disabled`, `aria-*`, children). Add the canon import if missing. Remove now-unused imports.
2. **Same for Input / Textarea / Select / Checkbox / Switch / Badge** when the mapping is 1:1.
3. **Set** `variant` / `size` / `shape` / `appearance` from the catalog. Delete the chrome classes those props replace.
4. **Strip** remaining forbidden tokens from `className`. If `className` becomes empty, remove the prop.
5. **Strip** forbidden `style` keys. If empty, remove `style`.
6. **Rewrite** wrong imports to the canon path.

**Do not auto-fix** (report only):
- A control whose closest primitive is unclear (custom segmented control, canvas toolbar, contenteditable)
- A file that would need a **new** design-system variant — propose the variant name + `cva` snippet, do not invent it in the call site
- > 20 replacements in one file — show the plan, ask before applying

Never use `Write` to rewrite a whole file. `Edit` only.

---

## Phase 6: Report

```
### apps/web-crm/src/.../foo.tsx

| Line | Finding | Action |
|------|---------|--------|
| 42 | native `<button>` | → `<Button variant="ghost" size="icon-sm">` |
| 58 | `<Button className="bg-red-500 text-white">` | stripped chrome; `variant="destructive"` |
| 73 | `<Button className="h-12 px-8">` | stripped size override; `size="lg"` |
| 91 | `<Button className="absolute right-2">` | kept (positioning) |
| 104 | `<Button className="w-full">` | kept (rare sizing) |
```

```
## Summary
- Files scanned: N
- Files modified: M
- Natives replaced: B buttons, I inputs, …
- Chrome classNames stripped: K
- Rare sizing left in place: R
- Needs new DS variant (not invented): …
- Skipped / needs human: …
```

`--dry-run` / `preview` → report only.

---

## Safety Rails

| Situation | Action |
|---|---|
| No frontend files in the diff | Stop. Say so. |
| File is the primitive itself | Do not replace inner DOM. Check `cva` + `pickLayoutClassName` only. |
| Merge conflict markers | Skip file. |
| Hidden file input + visible Button | Leave the hidden input. |
| `asChild` + `<a>` / router `Link` | Leave the child element. |
| Unclear mapping / new look | Report + propose a DS variant. Do not chrome-override. |
| User said dry-run / preview | Report only. |

---

## What This Command Does NOT Do

- Does not run `/fix-tailwind` (token snap is a different command). After this pass, remaining layout classes should already be config tokens.
- Does not add new design-system variants unless the user explicitly asks.
- Does not restyle page-level layout wrappers (`div`, `section`, `main`) — only native controls and shared primitive call sites.
- Does not commit or push.
````

#### `~/.ai/commands/create-command.md`

````markdown file=~/.ai/commands/create-command.md
---
description: Interactively create a new OpenCode slash command (.md template + optional scripts/references). Use when user wants to create a command or runs /create-command.
---

# /create-command

Interactively create a new OpenCode slash command on disk.

## Step 1: Gather information

Ask the user the following questions **one at a time as regular conversation questions** (do NOT use structured option prompts for free-text inputs):

1. **Command name** - lowercase letters (a-z), digits (0-9), and hyphens (-) only. Must start and end with a letter or digit. 2-64 chars (e.g. `deploy-k8s`). Validate before proceeding.
2. **Scope** - present two options:
   - **Project** (Recommended): `<repo-root>/.opencode/command/<name>.md` — this repo only
   - **User**: `~/.ai/commands/<name>.md` (symlinked into `~/.config/opencode/command/`) — all projects
   - Default to **Project** if inside a git repo, otherwise **User**.
3. **What it should do** - workflow description, example prompt, or task to automate.

## Step 2: Draft the description

Write a short `description` frontmatter value (shown in the TUI `/` menu):
- What the command does (1 sentence)
- Keep it under ~120 chars when possible

Show the drafted description and let the user approve or edit it.

## Step 3: Write the command file

```bash
# User scope
mkdir -p ~/.ai/commands
# Project scope
mkdir -p <repo-root>/.opencode/command
```

Write `<COMMAND_PATH>` with this exact format:

```
---
description: <the description from Step 2>
---

<markdown body with instructions, steps, code blocks>

User arguments: $ARGUMENTS
```

If helper scripts or reference docs are needed, put them under:
- User: `~/.ai/command-assets/<name>/scripts/` and `.../references/`
- Project: `.opencode/command-assets/<name>/...`

Reference those absolute paths from the command body. Do **not** put nested `.md` files under the `command/` directory (opencode registers every `**/*.md` as a command).

## Step 4: Verify and confirm

1. Read back the command file to verify it was written correctly.
2. Tell the user:
   - Slash: `/<name> [args]`
   - Restart opencode if the command does not appear (config is loaded at startup)
3. Remind them `$ARGUMENTS` / `$1` `$2` are available in the template.

## Guidelines

- Command body is the prompt opencode runs — keep it actionable.
- Prefer referencing existing CLI tools over custom scripts.
- Always use absolute paths when creating files.
````

#### `~/.ai/commands/fix-ci.md`

````markdown file=~/.ai/commands/fix-ci.md
---
description: Fetches the most recent GitHub Actions CI run for a PR, parses all failed jobs/steps for error messages, then diagnoses and fixes each failure in the codebase. Always creates a code-only git worktree first (same as /worktree-quick; yarn install is mandatory) so /fix-ci 1234 does not need a prior /worktree-quick. Use when user says "/fix-ci", "/fix-ci 1234", "fix ci", "fix the build", "fix pipeline", "fix github actions", or "ci is failing".
---

# /fix-ci - GitHub Actions CI Failure Fixer

Fetches the most recent GitHub Actions CI run for the current branch's PR, finds all failures and errors, diagnoses root causes, and fixes them in the codebase.

**Usage:** `/fix-ci [PR number | PR URL]`

`/fix-ci 1234` is enough — this skill creates the code-only worktree itself. Do **not** require a prior `/worktree-quick`. **Yarn install is mandatory** on every worktree (create, reuse, already-isolated).

---

## Core Philosophy

- **Find every failure.** Don't stop at the first error — CI runs have multiple jobs and steps, and each can fail independently.
- **Understand before fixing.** Read the full error context, not just the error line. Many CI errors are symptoms of a root cause elsewhere.
- **Fix the code, not the CI.** The goal is to fix the source code so CI passes, not to hack around CI configuration (unless the CI config itself is the bug).
- **Do not invent a parallel check pipeline.** After fixing, `/pr` (or a normal push) runs `.husky/pre-push`, which is the local CI gate. Never `git push --no-verify`.

---

## Agent Roster

Use these specialized agents for fixes:

| Agent | `subagent_type` | Use For |
|-------|-----------------|---------|
| Backend Architect | `backend-architect` | Build/type errors in backend or shared code |
| Frontend Developer | `frontend-developer` | Component errors, frontend test failures |
| Test Writer/Fixer | `test-writer-fixer` | Test failures, assertion mismatches |
| DevOps Automator | `devops-automator` | CI config issues, infrastructure/Docker errors |

---

## Execution Flow

```
0. Code-only worktree        -> /worktree-quick script + yarn + session_move (always)
1. Identify PR & Branch      -> Find the PR (use PR_NUMBER from Phase 0)
2. Fetch Latest CI Run       -> Get the most recent workflow run
3. Find All Failed Jobs      -> Identify every job that didn't pass
4. Extract Error Messages    -> Parse logs for all error patterns
5. Diagnose Root Causes      -> Group errors by root cause
6. Fix Each Issue            -> Implement fixes using specialized agents
7. Stop after fixes          -> Do not run a local typecheck/format/test suite here
8. Report Summary            -> Show what was fixed; next step is `/pr` (pre-push is the gate)
```

---

## Phase 0: Code-only worktree (always, before any work)

Work **never** runs in the primary checkout. Isolate first with the same script as `/worktree-quick`, then continue in that worktree. **Do not** wait for the user to run `/worktree-quick`. **Do not** use `/monorepo-worktree`. **Do not** stop after create — continue immediately in this same session.

**Yarn is mandatory on every worktree.** Create, reuse, and already-isolated all require `yarn install` in the worktree with exit 0 (10 min timeout). Never skip because `node_modules` exists. Never skip on reuse. Never skip because the task "doesn't need node_modules". If the create script already ran yarn in this turn and you watched it exit 0, that create counts; reuse / already-isolated **must still yarn**.

User arguments: `$ARGUMENTS`

### Parse target

Split `$ARGUMENTS` into **TARGET** (PR / branch) vs other flags. Only PR numbers, `#N`, `pr N`, GitHub `.../pull/N`, and git refs are worktree targets.

| TARGET | Action |
|--------|--------|
| PR / URL | `~/.ai/oc_skills/worktree-quick/scripts/quick-worktree.sh <n-or-url>` |
| Branch / ref | `…/quick-worktree.sh <ref>` |
| Empty | `gh pr view --json number -q .number`. If that fails and cwd is already `*-quick-*`, skip create. Else if current branch is not `main`/`master`, worktree that branch. Else ask for a PR number. |

Remember `PR_NUMBER` when TARGET is a PR. Later `gh pr view` / `gh run list` must use that PR's head ref — local branch is `quick/pr-N`.

### Create or reuse

Must run from the git repo (or `REPO_ROOT`). Do **not** hand-roll `git worktree add`. Skip create only if cwd is already a matching `*-quick-*` worktree. If the script fails with `worktree path already exists: <path>`: **reuse `<path>`**. If reusing and **clean**, fetch+reset to latest PR SHA. If **dirty**, do not `reset --hard`.

### Yarn (always)

```bash
(cd "<path>" && yarn install)
```

Reuse / already-isolated: **always** run this. Wait for exit 0. Timeout 10 minutes.

### Move the session, then work

1. OpenCode: `tools.opencode.session_move` with `directory` = absolute worktree path. Continue **this** session.
2. If session_move is unavailable: `cd` / `working_directory` on every later command.
3. All later git / Read / Grep / edits happen in that worktree.
4. One-line note: path, branch, PR URL, destroy command. Then **immediately** continue. Do **not** destroy the worktree when finished.

---

## Phase 1: Identify PR & Branch

```bash
# Get current branch
git branch --show-current

# Get repo owner/name
gh repo view --json owner,name --jq '.owner.login + "/" + .name'

# Prefer PR_NUMBER from Phase 0 — local branch is quick/pr-N
gh pr view ${PR_NUMBER} --json number,url,title,headRefName 2>/dev/null
```

- If no PR exists, check for CI runs on the branch directly (push-triggered workflows).
- If neither exists, **stop and inform the user**.
- For `gh run list --branch`, use the PR's GitHub `headRefName`, **not** `quick/pr-N`.

---

## Phase 2: Fetch Latest CI Run

### 2.1 Get the Most Recent Run

```bash
# Get the most recent workflow run for this branch
gh run list --branch "$(git branch --show-current)" --limit 5 --json databaseId,status,conclusion,name,createdAt,headSha
```

Select the most recent run. If multiple workflow runs exist (e.g., `ci.yml`, `test.yml`, `lint.yml`), process ALL of them that have failures.

### 2.2 Check Run Status

- If the latest run is `success` — **stop and inform the user that CI is passing**.
- If the latest run is `in_progress` — **warn the user** and offer to analyze the most recent completed run instead.
- If the latest run is `failure` or `cancelled` — proceed to Phase 3.

---

## Phase 3: Find All Failed Jobs

```bash
# List all jobs in the run, focusing on failed ones
gh run view <run-id> --json jobs --jq '.jobs[] | select(.conclusion == "failure") | {name: .name, conclusion: .conclusion, steps: [.steps[] | select(.conclusion == "failure")]}'
```

For each failed run, also get the full job list:

```bash
gh run view <run-id> --json jobs
```

Build a list of all failed jobs and their failed steps.

---

## Phase 4: Extract Error Messages

This is the most critical phase. CI logs are noisy — you must extract the actual errors.

### 4.1 Download Failed Job Logs

```bash
# Get logs for the entire failed run
gh run view <run-id> --log-failed
```

If that's too large or doesn't give enough context:

```bash
# Get logs for a specific failed job
gh run view <run-id> --log-failed --job <job-id>
```

### 4.2 Parse Error Patterns

Search the logs for ALL of these error patterns:

#### Build/Compile Errors
- `error TS\d+:` — TypeScript compiler errors
- `Error:` or `ERROR:` — Generic errors
- `error\[E\d+\]:` — Rust compiler errors
- `BUILD FAILED` or `Build failed`
- `SyntaxError:` — JavaScript/TypeScript syntax errors
- `Module not found` or `Cannot find module` — Import errors
- `Cannot find name` — TypeScript name resolution errors
- `Type '.*' is not assignable to type` — TypeScript type errors
- `Property '.*' does not exist on type` — TypeScript property errors
- `Argument of type '.*' is not assignable` — TypeScript argument errors

#### Test Failures
- `FAIL` followed by test file paths
- `FAILED` or `Failed` test indicators
- `AssertionError:` or `AssertionError:` — Test assertion failures
- `Expected:` / `Received:` — Jest/Vitest diff output
- `expect(` — Failed expectations
- `Error: expect(` — Jest matcher failures
- `x` or `X` or `*` — Failed test markers
- `\d+ failing` — Mocha-style failure counts
- `FAILURES!` — JUnit-style failures

#### Lint/Format Errors
- `error  ` (ESLint errors with double space)
- `warning  ` (ESLint warnings treated as errors)
- `Checking formatting...` followed by file diffs
- `prettier --check` failures
- `Run Prettier to fix` or `Code style issues found`

#### Runtime/Process Errors
- `Exit code: [^0]` or `Process exited with code [^0]` — Non-zero exit codes
- `ENOENT` — File not found
- `ENOMEM` — Out of memory
- `ETIMEOUT` or `Timeout` — Timeouts
- `Segmentation fault` — Crashes
- `OOMKilled` — Out of memory killed
- `Command failed` — Generic command failures

#### Docker/Infrastructure Errors
- `COPY failed:` — Docker build errors
- `npm ERR!` or `yarn error` or `pnpm ERR!` — Package manager errors
- `permission denied` — Permission issues
- `EACCES` — Access errors

#### General Failure Indicators
- Lines containing `::error::` (GitHub Actions error annotation)
- `##[error]` — GitHub Actions error prefix
- `The process.*failed with exit code` — GitHub Actions step failure

### 4.3 Build Error Inventory

For each error found, capture:
1. **Job name** — which CI job failed
2. **Step name** — which step in the job failed
3. **Error text** — the full error message
4. **File path** (if referenced) — the source file mentioned in the error
5. **Line number** (if referenced) — the line number mentioned
6. **Error category** — build, test, lint, runtime, infrastructure

---

## Phase 5: Diagnose Root Causes

### 5.1 Group Related Errors

Many CI errors share a root cause. Group them:

- **10 TypeScript errors all from missing type export** -> 1 root cause: missing export
- **5 test failures from the same test file** -> 1 root cause: broken test setup or changed API
- **3 lint errors on new files** -> 1 root cause: new files not following lint rules
- **Import errors cascade** -> Fix the source import, others resolve

### 5.2 Prioritize by Impact

Order fixes by how many downstream errors they resolve:

1. **Build/compile errors** — fix these first (tests and lint can't run if build fails)
2. **Import/module errors** — often cascade into many other errors
3. **Type errors** — fix in dependency order (shared types first)
4. **Test failures** — fix after build is green
5. **Lint/format errors** — fix last (least impactful)

### 5.3 Read Source Files

For each root cause, read the actual source file(s) to understand the context.

**IMPORTANT:** Don't just look at the error line — read surrounding context to understand the real fix needed. A "Property does not exist" error might mean:
- The property was renamed -> find the new name
- The interface changed -> update the usage
- The import is wrong -> fix the import
- A new field needs to be added -> add it to the type

---

## Phase 6: Fix Each Issue

### 6.1 Plan Fixes

Create a TodoWrite checklist with every fix needed, ordered by priority.

### 6.2 Implement Fixes Using Specialized Agents

**For build/type errors (backend or shared code):**
```
Task: backend-architect
- List of TypeScript/build errors with file paths and line numbers
- Root cause analysis
- The current code and what needs to change
- Build command to verify: [detected build command]
```

**For frontend component/test errors:**
```
Task: frontend-developer
- List of component or test errors with file paths and line numbers
- Root cause analysis
- The current code and what needs to change
- Test command to verify: [detected test command]
```

**For test failures (assertion mismatches, outdated expectations):**
```
Task: test-writer-fixer
- List of failing tests with error output
- Whether the test expectation or the implementation needs fixing
- Test command to verify
```

**For CI config / infrastructure errors:**
```
Task: devops-automator
- The CI workflow file and the failing step
- Error output from the infrastructure/Docker step
- What needs to change in the config
```

**For simple fixes (single-line changes, imports, formatting):**
Implement directly without spawning an agent.

### 6.3 Spawn Agents in Parallel

When fixes are independent (different files, different root causes), spawn multiple agents simultaneously.

---

## Phase 7: Do not run a parallel check suite

Do **not** run `tsc` / `npm test` / `nx format` / a guessed CI replica here.

This repo's local CI gate is `.husky/pre-push` (same jobs as `.github/workflows/ci.yml`). It runs on `git push` and blocks the push on failure.

After fixes are in the working tree:
1. Report what changed
2. Tell the user to run `/pr` (commit + push, never `--no-verify`)
3. If you need to reproduce **one** failed GitHub job while diagnosing, run that job's exact command from `ci.yml` — not a generic substitute

You may run `.husky/pre-push` yourself only if you are still iterating on a fix before asking the user to `/pr`. Do not treat a green generic `npm test` as verification.

---

## Phase 8: Summary Report

```markdown
## CI Fix Summary

**PR**: #[number] - [title]
**Branch**: [branch-name]
**Failed Run**: [run-id] ([run-url])
**Run Date**: [date]

### Failures Found

| # | Job | Step | Error Category | Root Cause |
|---|-----|------|---------------|------------|
| 1 | build | Typecheck | Build | Missing type export in shared/types.ts |
| 2 | test | Unit Tests | Test | API response shape changed, tests not updated |
| 3 | lint | ESLint | Lint | New files missing explicit return types |

### Fixes Applied

| # | File(s) | Change | Resolves Errors |
|---|---------|--------|----------------|
| 1 | shared/types.ts | Exported `UserResponse` type | Build errors #1-8 |
| 2 | tests/api/users.test.ts | Updated test assertions to match new response | Test failures #1-3 |
| 3 | src/utils/helpers.ts | Added explicit return types | Lint errors #1-5 |

### Local Verification

Not run in this command. `/pr` push hits `.husky/pre-push` (mirrors CI).

### Next Steps
- Run `/pr` to commit and push the fixes (never `--no-verify`)
- Pre-push must pass; GitHub CI should then pass
```

---

## Error Handling

| Error | Action |
|-------|--------|
| No PR and no branch CI runs found | Stop, tell user to push the branch or create a PR first |
| CI is currently passing | Stop, tell user CI is green — nothing to fix |
| CI run is still in progress | Warn user, offer to analyze most recent completed run |
| `gh` CLI not authenticated | Stop, tell user to run `gh auth login` |
| Cannot determine repo owner/name | Stop, ask user to confirm they're in a git repo with a GitHub remote |
| Logs are too large to parse | Focus on `--log-failed` output and error annotations only |
| Fix causes new errors | Keep fixing; do not `--no-verify` to skip the hook |
| Cannot reproduce locally | Report the errors and suggest they may be environment-specific (CI-only dependencies, OS differences, etc.) |
| Infrastructure/config error (not code) | Spawn devops-automator agent to investigate |

---

## Important Rules

1. **Parse ALL error types.** Don't just look for `Error:` — CI failures come in many formats. Use the full pattern list in Phase 4.2.
2. **Fix root causes, not symptoms.** If 10 errors come from 1 missing export, add the export — don't patch 10 files.
3. **Read the actual workflow file.** Know what CI runs so you can reproduce locally and verify.
4. **Respect the project's tooling.** Use the same build/test/lint commands the project uses, not generic ones.
5. **Don't modify CI configuration** unless the CI config itself is clearly broken (e.g., referencing a deleted script). Use devops-automator for CI config changes.
6. **Track everything.** Every error found must be accounted for in the summary — either fixed or explained.
7. **Do not declare CI green from a generic local suite.** The gate is `.husky/pre-push` / GitHub Actions. Never `--no-verify`.
8. **Be honest about environment-specific failures.** Some CI failures can't be reproduced locally (Docker, specific OS, secret-dependent tests). Report these clearly.
9. **Use the right agent for each fix type.** Backend errors -> backend-architect, frontend -> frontend-developer, tests -> test-writer-fixer, infra -> devops-automator.
10. **Always isolate in a code-only worktree first** (Phase 0). **Yarn install is mandatory** on every worktree (create, reuse, already-isolated). Never skip yarn because `node_modules` exists.

User arguments: $ARGUMENTS
````

#### `~/.ai/commands/fix-merge-conflicts.md`

````markdown file=~/.ai/commands/fix-merge-conflicts.md
---
description: Fetches origin/main into the current branch and resolves each conflict one file at a time, keeping this branch's style and behavior. Always creates a code-only git worktree first (same as /worktree-quick; yarn install is mandatory) so /fix-merge-conflicts does not need a prior /worktree-quick. Use when user says "/fix-merge-conflicts", "/fix-merge-conflicts 1234", "fix merge conflicts", "resolve conflicts", "merge main", or "pull main and resolve".
---

# /fix-merge-conflicts - Merge Main & Resolve Conflicts

Fetches `origin/main` (or `master`) into the **current feature branch**, then resolves **each conflicted file one at a time**. Keep the style and function of **our** changes (the branch we are working on). Integrate incoming main only when it is required for the result to compile and stay correct.

**Usage:** `/fix-merge-conflicts [PR number | PR URL | branch]`

`/fix-merge-conflicts 1234` is enough — this skill creates the code-only worktree itself. Do **not** require a prior `/worktree-quick`. **Yarn install is mandatory** on every worktree (create, reuse, already-isolated).

User arguments: $ARGUMENTS

---

## Core Philosophy

- **Ours is the feature.** The current branch's intent, naming, structure, and behavior win. Do not throw away work we are shipping.
- **Main is the platform.** Take incoming API renames, shared-type changes, schema updates, and infra that our code must call. Adapt **our** code to the new platform — do not revert our feature to match old main.
- **One file at a time.** Never bulk `--ours` / `--theirs`. Read, understand both sides, write a single coherent file, then `git add` it before touching the next.
- **Fail loud.** If a hunk cannot be resolved with confidence, stop on that file and ask. Wrong quiet success is worse than a paused merge.

---

## Execution Flow

```
0. Code-only worktree     -> /worktree-quick script + yarn + session_move (always)
1. Safety checks          -> repo, branch, dirty tree, mid-merge/rebase
2. Detect default branch  -> main or master
3. Fetch + merge main     -> into current branch (not the other way around)
4. Inventory conflicts    -> list every unmerged path
5. Resolve file-by-file   -> ours style/function; adapt to main's platform
6. Verify                 -> no markers / no unmerged paths (not typecheck/tests)
7. Complete merge commit  -> only the merge commit; do not push
8. Report                 -> files, decisions, leftover risk
```

---

## Phase 0: Code-only worktree (always, before any work)

Work **never** runs in the primary checkout. Isolate first with the same script as `/worktree-quick`, then merge/resolve in that worktree. **Do not** wait for `/worktree-quick`. **Do not** use `/monorepo-worktree`. **Do not** stop after create.

**Yarn is mandatory on every worktree.** Create, reuse, and already-isolated all require `yarn install` in the worktree with exit 0 (10 min timeout). Never skip because `node_modules` exists. Never skip on reuse. If the create script already ran yarn in this turn and you watched it exit 0, that create counts; reuse / already-isolated **must still yarn**.

User arguments: `$ARGUMENTS`

### Parse target

| TARGET | Action |
|--------|--------|
| PR / URL | `~/.ai/oc_skills/worktree-quick/scripts/quick-worktree.sh <n-or-url>` |
| Branch / ref | `…/quick-worktree.sh <ref>` |
| Empty | `gh pr view --json number -q .number`. If that fails and cwd is already `*-quick-*`, skip create. Else if current branch is not `main`/`master`, worktree that branch. Else ask for a PR number. |

Remember `PR_NUMBER`. Do **not** merge main into the primary checkout.

### Create or reuse

Do **not** hand-roll `git worktree add`. Skip create only if cwd is already a matching `*-quick-*` worktree. If path already exists: **reuse**. If reusing and **dirty**, do not `reset --hard`.

### Yarn (always)

```bash
(cd "<path>" && yarn install)
```

Reuse / already-isolated: **always** run this. Wait for exit 0.

### Move the session, then work

OpenCode: `tools.opencode.session_move` with `directory` = absolute worktree path. Continue this session. Then **immediately** continue. Do **not** destroy the worktree when finished.

---

## Phase 1: Safety Checks

```bash
git rev-parse --is-inside-work-tree
git branch --show-current
git status --porcelain=v1
git rev-parse -q --verify MERGE_HEAD
git rev-parse -q --verify REBASE_HEAD
git rev-parse -q --verify CHERRY_PICK_HEAD
```

**Hard stops:**

| Condition | Action |
|-----------|--------|
| Not a git repo | Stop |
| Current branch is `main` or `master` | Stop. Never merge "our work" by updating main in place. User must be on a feature branch. |
| Detached HEAD | Stop and ask |
| Unrelated dirty files that are **not** part of an in-progress merge/rebase | Stop and ask whether to stash. Do not stash silently. |
| `REBASE_HEAD` or `CHERRY_PICK_HEAD` present | Do **not** start a new merge. Continue that operation (Phase 4+) or ask if the user meant a merge instead. |
| `MERGE_HEAD` already present | Skip fetch/merge. Resume at Phase 4. |

`$ARGUMENTS` may name a base branch (e.g. `develop`). Use that instead of main/master when given.

---

## Phase 2: Detect Default Branch

If `$ARGUMENTS` is empty:

```bash
git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null
git rev-parse --verify origin/main
git rev-parse --verify origin/master
```

Prefer `origin/HEAD` → else `origin/main` → else `origin/master`. Call this `BASE`. Never invent a remote branch.

---

## Phase 3: Fetch and Merge Base Into Current Branch

```bash
git fetch origin
git merge --no-edit "origin/<BASE>"
```

- Merge **base into current branch**. Do not checkout base. Do not reset. Do not rebase unless the user explicitly asked to rebase.
- If the merge is already complete (fast-forward or clean merge): report that there is nothing to resolve and stop. Do not create extra commits.
- If git refuses (local changes, unborn branch, etc.): show the full error and stop. Do not force.

---

## Phase 4: Inventory Conflicts

```bash
git diff --name-only --diff-filter=U
git status
```

For each unmerged path, record the conflict type:

```bash
git ls-files -u
```

| Index stages | Meaning |
|--------------|---------|
| stages 1,2,3 | both modified (normal) |
| stages 2,3 only | both added |
| stage 2 only | deleted by them, modified by us |
| stage 3 only | deleted by us, modified by them |

Build a TodoWrite list: one item per conflicted file, plus a final verify item. Mark the first file `in_progress`.

If there are zero unmerged paths after the merge, skip to Phase 7.

---

## Phase 5: Resolve One File at a Time

Process files **serially**. Finish and `git add` file N before opening file N+1.

### 5.1 Read both sides (do not guess)

For a normal both-modified file:

```bash
git show :2:"<path>"   # ours  — current branch
git show :3:"<path>"   # theirs — incoming base
git show :1:"<path>"   # base ancestor (when present)
```

Also read the working-tree file (conflict markers) and nearby non-conflicted files for style.

For delete/add special cases, inspect `git log --oneline -5 -- <path>` on both `HEAD` and `MERGE_HEAD` before choosing keep vs delete.

### 5.2 Resolution rules (ours wins on product; theirs wins on platform)

**Keep ours when the hunk is:**

- New feature code, new UI, new tests, new routes, new domain logic
- Naming, formatting, import order, component structure we introduced
- Control flow we wrote (error handling, status machines, authz)
- Comments we added or removed as part of this work

**Take or adapt to theirs when the hunk is:**

- Shared type/API/schema that our new code must call
- Import path or symbol rename on a dependency we use
- Lockfile / generated Prisma client / codegen — regenerate rather than hand-merge
- Config that would leave the branch unable to boot against current main

**Never:**

- `git checkout --ours -- <file>` or `--theirs` for a whole source file
- Leave conflict markers
- Soft-merge by concatenating both blocks "to be safe"
- Invent APIs that exist on neither side
- Hand-write Prisma DDL or "fix" a generated migration to make the merge succeed
- Resolve binary files without asking

**Prisma / migrations:** if `schema.prisma` or a generated migration conflicts, **stop and ask**. Do not edit generated SQL to paper over drift.

**Lockfiles (`yarn.lock`, `package-lock.json`, `bun.lock`, `pnpm-lock.yaml`):** pick one package manager from the repo, take a coherent tree, then regenerate the lockfile with the project's install command. Do not hand-edit lockfile conflict hunks.

**Generated files:** regenerate (`prisma generate`, nx codegen, etc.) after resolving the source of truth.

### 5.3 Write the resolved file

Produce one clean file that:

1. Preserves our feature's behavior and local style (match surrounding code on **this** branch).
2. Compiles against main's types/exports/APIs.
3. Contains no `<<<<<<<`, `=======`, `>>>>>>>`.

Then:

```bash
git add -- "<path>"
```

Mark that todo `completed` and move to the next file.

### 5.4 Stop conditions (ask the user)

Pause before `git add` if:

- Both sides added the same symbol with different contracts
- Delete vs modify and the feature still needs the file
- Binary or asset conflict
- Migration / schema conflict
- You cannot tell which side is "our feature" vs "platform"
- Resolving would require rewriting more than this file in a way you cannot verify

Show both sides briefly and wait.

---

## Phase 6: Verify

After every path is staged:

```bash
git diff --name-only --diff-filter=U
rg -n '^(<<<<<<<|=======|>>>>>>>)' .
```

If any markers or unmerged paths remain, go back to Phase 5. Do not continue.

Do **not** run typecheck, tests, lint, format, or build here. `/pr` push runs `.husky/pre-push`, which is the CI gate. If the merge would fail CI, the hook will block the push with the failing job's output.

---

## Phase 7: Complete the Merge

A merge in progress is not done until the merge commit exists. Create **only** that merge commit:

```bash
git status
git log --oneline -5
git commit --no-edit
```

- Use the default merge message unless it is empty/broken.
- Do **not** `git add` unrelated untracked files.
- Do **not** push.
- Do **not** commit extra "fixup" commits.
- No `Co-Authored-By` trailer. No `--no-verify` unless the user asked.

If `git commit` is rejected by a hook, fix the hook failure (it is often leftover markers or lint) and commit again. Do not `--no-verify`.

---

## Phase 8: Summary

```markdown
## Merge conflict summary

**Branch**: [current] ← **origin/[base]**
**Merge commit**: [sha] (or still in progress if stopped)

### Resolved
| File | Decision |
|------|----------|
| src/foo.ts | Kept our handler; updated import to main's renamed `authorizeX` |

### Stopped / needs you
| File | Why |
|------|-----|

### Verification
| Check | Result |
|-------|--------|
| Conflict markers / unmerged paths | [clean / still open] |
| CI (typecheck/test/build/format) | not run here — pre-push on `/pr` |

### Residual risk
[lockfile regenerated?, migrations? CI runs on `/pr` push]
```

---

## Error Handling

| Error | Action |
|-------|--------|
| On main/master | Stop |
| Fetch/merge refused | Show full git output; stop |
| Already merging | Resume Phase 4; do not start a second merge |
| Mid-rebase and user asked to merge | Ask which operation to finish |
| Cannot resolve a file | Leave it unmerged, report, wait |
| Hook rejects merge commit | Fix the cause; no `--no-verify` |
| Prisma/migration conflict | Stop and ask |

---

## Important Rules

1. **Never merge by checking out main and pulling the feature in.** Always merge base → current branch.
2. **Never `--ours` / `--theirs` a source file wholesale.**
3. **One file at a time.** Add it before opening the next.
4. **Keep our style and function.** Adapt callsites to main; do not rewrite the feature to look like main.
5. **No silent leftovers.** Conflict markers or unmerged paths at the end is a failed run.
6. **Do not push. Do not touch main.**
7. **Do not commit anything except the merge commit** this command creates.
8. **Fail hard** when unsure — ask.
9. **Always isolate in a code-only worktree first** (Phase 0). Never merge main into the primary checkout. **Yarn install is mandatory** on every worktree (create, reuse, already-isolated). Never skip yarn because `node_modules` exists.

User arguments: $ARGUMENTS
````

#### `~/.ai/commands/fix-pr-review.md`

````markdown file=~/.ai/commands/fix-pr-review.md
---
description: Fetches unresolved review comments and discussion threads from a PR, automatically fixes LOW (nits) and SEMANTIC items, presents CRITICAL/HIGH/MEDIUM items to the user with proposed fixes for approval, then replies on EVERY processed thread (including skipped) describing what changed or why it was skipped, and marks each resolved on GitHub. Always creates a code-only git worktree first (same as /worktree-quick; yarn install is mandatory) so /fix-pr-review 1234 does not need a prior /worktree-quick. Use when user says "/fix-pr-review", "/fix-pr-review 1234", "fix pr review", "address pr feedback", "handle review comments", or "/pr-review-fix".
---

# /fix-pr-review - PR Review Feedback Handler

Reads **unresolved** review comments and discussion threads from the current branch's PR, triages them by severity, auto-fixes low-risk nits and semantic suggestions, presents higher-impact items to the user with proposed fixes for approval, then **replies on every processed thread (including skipped) and marks it resolved on GitHub**. Each reply must say what changed or why the item was skipped. Already-resolved threads are excluded from processing.

**Usage:** `/fix-pr-review [PR number | PR URL]`

`/fix-pr-review 1234` is enough — this skill creates the code-only worktree itself. Do **not** require a prior `/worktree-quick`. **Yarn install is mandatory** on every worktree (create, reuse, already-isolated).

---

## Core Philosophy

- **Low (nits) & Semantic = Fix immediately.** Style preferences, naming, import ordering, comment wording, subjective/architectural opinions — these are low-risk and get applied without asking.
- **Critical, High & Medium = User decides.** Security issues, bugs, logic errors, missing error handling, code quality concerns, missing tests — these have real impact and deserve explicit review. Each is presented with a proposed fix the user can approve, tweak, or skip.
- **Never dismiss feedback silently.** Every unresolved comment is acknowledged, categorized, replied to on GitHub, and resolved — including items we skipped.
- **Close the loop on GitHub.** Code changes alone are not enough. Every processed thread gets a reply (what we did, or why we skipped it) and is then marked resolved so the PR conversation is clean.

---

## Execution Flow

```
0. Code-only worktree       -> /worktree-quick script + yarn + session_move (always)
1. Identify PR              -> Find the PR (use PR_NUMBER from Phase 0)
2. Fetch Unresolved Feedback -> Reviews, inline comments, conversation threads (skip resolved)
3. Triage & Classify        -> Assign severity to each unresolved piece of feedback
4. Auto-Fix Low/Semantic    -> Implement nits and semantic suggestions directly
5. Present Crit/High/Med    -> Show user each item with a proposed fix for approval
6. Comment & Resolve        -> Reply on EVERY processed thread (fixed AND skipped), then resolve each
7. Report Summary           -> Final status of all feedback items (already-resolved listed separately)
```

---

## Phase 0: Code-only worktree (always, before any work)

Work **never** runs in the primary checkout. Isolate first with the same script as `/worktree-quick`, then continue in that worktree. **Do not** wait for the user to run `/worktree-quick`. **Do not** use `/monorepo-worktree`. **Do not** stop after create — continue immediately in this same session.

**Yarn is mandatory on every worktree.** Create, reuse, and already-isolated all require `yarn install` in the worktree with exit 0 (10 min timeout). Never skip because `node_modules` exists. Never skip on reuse. Never skip because the task "doesn't need node_modules". If the create script already ran yarn in this turn and you watched it exit 0, that create counts; reuse / already-isolated **must still yarn**.

User arguments: `$ARGUMENTS`

### Parse target

Split `$ARGUMENTS` into **TARGET** (PR / branch) vs other flags. Only PR numbers, `#N`, `pr N`, GitHub `.../pull/N`, and git refs are worktree targets.

| TARGET | Action |
|--------|--------|
| PR / URL | `~/.ai/oc_skills/worktree-quick/scripts/quick-worktree.sh <n-or-url>` |
| Branch / ref | `…/quick-worktree.sh <ref>` |
| Empty | `gh pr view --json number -q .number`. If that fails and cwd is already `*-quick-*`, skip create. Else if current branch is not `main`/`master`, worktree that branch. Else ask for a PR number. |

Remember `PR_NUMBER` when TARGET is a PR. Later `gh pr view` must use `gh pr view ${PR_NUMBER}` — local branch is `quick/pr-N`.

### Create or reuse

Must run from the git repo (or `REPO_ROOT`). Do **not** hand-roll `git worktree add`.

Skip create only if cwd is already a matching `*-quick-*` worktree (same PR / slug).

If the script fails with `worktree path already exists: <path>`: **reuse `<path>`**. Do not destroy.

If reusing and the worktree is **clean**, fetch+reset to the latest PR/branch SHA. If **dirty**, do not `reset --hard` (keep in-progress fixes).

### Yarn (always)

After the path is known, unless you just watched create's yarn exit 0:

```bash
(cd "<path>" && yarn install)
```

Reuse / already-isolated: **always** run this. Wait for exit 0. Timeout 10 minutes.

### Move the session, then work

1. OpenCode: `tools.opencode.session_move` with `directory` = absolute worktree path. Continue **this** session.
2. If session_move is unavailable: `cd` / `working_directory` on every later command.
3. All later git / Read / Grep / edits happen in that worktree.
4. One-line note: path, `quick/…` branch, PR URL, destroy command (`~/.ai/oc_skills/worktree-quick/scripts/quick-worktree.sh destroy <slug> --yes`). Then **immediately** continue.

Do **not** destroy the worktree when finished.

---

## Phase 1: Identify the PR

```bash
# Prefer PR_NUMBER from Phase 0 — local branch is quick/pr-N, not the GitHub head ref
gh pr view ${PR_NUMBER} --json number,url,title,state,headRefName 2>/dev/null
```

Resolve repo names dynamically (case-sensitive):

```bash
gh repo view --json nameWithOwner -q '.nameWithOwner'
```

Split into `OWNER` and `REPO` for API calls. Set `NO_COLOR=1` on all `gh api` invocations to avoid ANSI noise in JSON.

- If no PR exists for the current branch, **stop and inform the user**.
- Confirm the PR number and title before proceeding.

---

## Phase 2: Fetch All Feedback (Unresolved Only)

Gather feedback from the PR, **filtering to only unresolved discussions**. Use the GraphQL API to get thread resolution status, since the REST API does not expose `isResolved`.

### 2.1 Review Threads with Resolution Status (GraphQL — Primary Source)

Use the GraphQL API to fetch all review threads and their resolution status. **Only process threads where `isResolved` is `false`.**

**Always request thread `id` (GraphQL node ID) and each comment's `databaseId`** — both are required later for replying and resolving.

```bash
NO_COLOR=1 gh api graphql -f query='
  query($owner: String!, $repo: String!, $pr: Int!, $cursor: String) {
    repository(owner: $owner, name: $repo) {
      pullRequest(number: $pr) {
        reviewThreads(first: 100, after: $cursor) {
          pageInfo { hasNextPage endCursor }
          nodes {
            id
            isResolved
            isOutdated
            path
            line
            startLine
            comments(first: 100) {
              nodes {
                id
                databaseId
                body
                author { login }
                createdAt
                url
              }
            }
          }
        }
      }
    }
  }
' -F owner='{owner}' -F repo='{repo}' -F pr={pr_number}
```

Paginate while `pageInfo.hasNextPage` is true so every unresolved thread is collected.

**Filtering rules:**
- **Skip** threads where `isResolved` is `true` — these have already been addressed and marked resolved by the reviewer or author.
- **Include** threads where `isResolved` is `false` — these are unresolved and need attention.
- Optionally note `isOutdated` threads (code has changed since the comment was made) but still include them if unresolved.
- Store per thread: `thread.id` (for resolve mutation), first comment's `databaseId` (for reply), path, line, body, author.

### 2.2 Review Summaries (top-level review bodies)

```bash
NO_COLOR=1 gh api repos/{owner}/{repo}/pulls/{pr_number}/reviews --paginate
```

Only process reviews with a non-empty `body`. Reviews with state `DISMISSED` should be skipped.

### 2.3 Issue-Style Comments (discussion thread on the PR)

```bash
NO_COLOR=1 gh api repos/{owner}/{repo}/issues/{pr_number}/comments --paginate
```

These are top-level PR discussion comments (not inline code comments). They have no resolution status — include them all, but deprioritize any that have already been replied to with a resolution. Replies use `gh pr comment` or the issues comments API (they cannot be "resolved" like review threads).

### 2.4 PR Description Checklists

```bash
gh pr view --json body
```

Check for any unchecked requirement boxes or inline review notes from the author.

### 2.5 Deduplicate & Filter

- Group reply threads together under their parent comment
- Remove bot comments (dependabot, CI bots, etc.) unless they are actionable review findings you still want to address
- **Exclude all resolved threads** — they should not appear in triage, fixes, or the user decision list
- Note resolved threads only in the final summary report under "Already Resolved" for completeness

---

## Phase 3: Triage & Classify

For each **unresolved** piece of feedback, classify into one of these severity levels:

### Classification Rubric

| Severity | Description | Examples | Action |
|----------|-------------|----------|--------|
| **CRITICAL** | Security vulnerabilities, data loss, crashes, broken auth | SQL injection, unvalidated input reaching DB, missing auth checks, null pointer in critical path | **Present to user with proposed fix** |
| **HIGH** | Bugs, logic errors, missing error handling, race conditions, performance issues likely to cause incidents | Off-by-one errors, unhandled promise rejections, missing null checks, N+1 queries, resource leaks | **Present to user with proposed fix** |
| **MEDIUM** | Code quality issues, suboptimal patterns, minor refactors, missing tests | Better abstraction possible, duplicated logic, missing edge case tests, overly complex function | **Present to user with proposed fix** |
| **LOW** | Style preferences, naming suggestions, documentation, minor improvements | Variable renaming, comment additions, import ordering, slightly better wording | **Auto-fix immediately** |
| **SEMANTIC** | Subjective opinions, architectural philosophy, bikeshedding | Tabs vs spaces debates, framework preferences, "I would have done it differently" | **Auto-fix immediately** |

### Classification Process

For each comment:
1. Read the full comment text and any code context referenced
2. Read the actual file and line range being discussed to understand the real impact
3. Determine if the reviewer is requesting a change vs. asking a question vs. making an observation
4. Assign severity based on the rubric above
5. If a comment is ambiguous, classify it as **MEDIUM** (err on the side of showing the user — safer than silently auto-fixing).

---

## Phase 4: Auto-Fix Low (Nits) & Semantic Items

These are low-risk — naming, comments, import order, style preferences, subjective architectural nits. Apply them directly without asking.

### 4.1 Plan Fixes

For each LOW and SEMANTIC item:
1. Read the relevant file(s) and surrounding context
2. Understand exactly what the reviewer asked for — do not expand scope
3. Plan the minimal change that addresses the comment

### 4.2 Implement Fixes Directly

Most nits and semantic changes are simple edits — make them directly with Edit. Only delegate to a specialized agent if the change touches a meaningfully complex area:

- backend-architect — for semantic refactors across backend/API surfaces
- frontend-developer — for semantic refactors in UI components

For single-file renames, comment tweaks, import reordering, wording changes: just edit inline.

### 4.3 Track Each Fix

Record **every** LOW/SEMANTIC item for the final summary **and** for Phase 6 (reply + resolve) — including ones you did not apply. Track at minimum:

- `thread_id` (GraphQL node id)
- `comment_database_id` (numeric id of the first/root comment in the thread)
- severity, path, reviewer
- outcome: `fixed` | `question-answered` | `skipped` | `deferred`
- `reply_body` draft: one sentence of what changed, or why it was skipped

If a nit is already applied, is incorrect, or you choose not to apply it, still record `skipped` with a concrete reason. Do not drop it from Phase 6.

---

## Phase 5: Present Critical/High/Medium Items With Proposed Fixes

After nits/semantic are applied, present the remaining impactful items to the user. **Each item must include a concrete proposed fix** — not just the reviewer's comment. The user should be able to approve, modify, or skip each one without having to re-read the diff themselves.

### Preparing Each Item

For every CRITICAL/HIGH/MEDIUM comment, before presenting:
1. Read the file and surrounding code the reviewer referenced
2. Understand the underlying problem (not just the surface complaint)
3. Draft the specific code change you would make — exact file, exact lines, before/after snippet
4. Note any risk, tradeoff, or ambiguity the user should know about

### Presentation Format

Order by severity (CRITICAL → HIGH → MEDIUM), then group by file within each severity:

```
## Review Feedback Needing Your Decision

### CRITICAL

1. [auth.ts:45] "User input flows into SQL query without sanitization" — @alice
   Problem: `email` is interpolated directly into the query string, enabling SQL injection.
   Proposed fix: switch to a parameterized query via the existing `db.query(sql, params)` helper.
   ```ts
   // before
   db.query(`SELECT * FROM users WHERE email = '${email}'`)
   // after
   db.query('SELECT * FROM users WHERE email = $1', [email])
   ```
   Notes: No behavior change for valid inputs. Safe to apply.

### HIGH

2. [api/users.ts:92] "This can crash if `profile` is null" — @bob
   Problem: `user.profile.name` is dereferenced without a null check; `profile` is optional in the schema.
   Proposed fix: add a nullish guard and return a default display name.
   ```ts
   // before
   return user.profile.name
   // after
   return user.profile?.name ?? user.email
   ```
   Notes: Matches the fallback pattern already used in `getDisplayName()` at line 140.

### MEDIUM

3. [utils/parse.ts:30] "Extract the date-handling block into a helper" — @alice
   Problem: 20 lines of date parsing are duplicated in 3 call sites.
   Proposed fix: extract a `parseFlexibleDate(input: string): Date | null` helper in the same file and replace all 3 call sites.
   Notes: Low risk, but touches 3 files — confirm you want this bundled in the review-fix commit vs. its own PR.
```

### User Decision

Ask the user which items to apply. Defaults and guidance:
- Default to applying all CRITICAL and HIGH items — but still require explicit confirmation before editing.
- MEDIUM items are opt-in — user picks which to apply.
- Allow the user to reply with freeform edits ("apply #1 and #2, skip #3, and for #1 use `email.toLowerCase()` in the param").

### Implement Approved Items

For each item the user approves:
1. Apply the exact fix shown (with any user-requested tweaks)
2. Use specialized agents only if the fix fans out across multiple complex files
3. Record the applied change for the summary and Phase 6

For items the user **skips**, record them with outcome `skipped` and a concrete reason (user's words if given, otherwise a short summary). Phase 6 **must** reply with that reason and resolve the thread. Skipping the code change does **not** skip the GitHub reply.

---

## Phase 6: Comment & Resolve on GitHub

**This phase is mandatory and must cover 100% of processed threads.** After code changes (and user decisions) are done, close the loop on **every** unresolved thread that entered triage — including every skipped item — by (1) posting a reply that describes the outcome and (2) marking the thread resolved.

Do **not** skip this phase even if all items were auto-fixed LOW/SEMANTIC nits. Do **not** skip it for items the user skipped, items the agent skipped, questions, or items already correct. Reviewers should not have to re-open the diff to discover that feedback was addressed or declined.

**Hard coverage rule:** before posting, list every unresolved `thread.id` from Phase 2. Each must have an outcome. Any thread missing an outcome is treated as `skipped` with reason "not applied this pass" — still reply and resolve. Leaving a processed thread with no reply is a failure of this skill.

### 6.0 When to run

Run Phase 6 once for **all** items that entered triage in Phases 3–5 (not only the ones you fixed):

| Outcome | Reply must say | Resolve thread? |
|---------|----------------|-----------------|
| `fixed` (code change applied) | What we changed | **Yes** |
| `question-answered` (no code change; clarified) | The technical answer | **Yes** |
| `skipped` (user or agent chose not to apply) | Why it was skipped | **Yes** |
| `deferred` (follow-up agreed with user) | Why deferred and the follow-up plan | **Yes** (default). Leave open **only** if the user explicitly said "leave this thread open" |
| Already resolved (Phase 2 filter) | — | No (never entered processing) |

Default: **reply, then resolve**, including skipped and deferred. The only exception is an explicit user request to leave a specific thread open.

### 6.1 Reply to an inline review thread

Use the **numeric** `databaseId` of the root (or latest) comment in the thread — not the opaque GraphQL node id.

Prefer the replies endpoint (works with PR number + comment databaseId):

```bash
NO_COLOR=1 gh api repos/{OWNER}/{REPO}/pulls/{pr_number}/comments/{databaseId}/replies \
  -X POST \
  -f body="<reply text>"
```

Fallback if `/replies` fails (some API versions / permissions):

```bash
NO_COLOR=1 gh api repos/{OWNER}/{REPO}/pulls/{pr_number}/comments \
  -X POST \
  -f body="<reply text>" \
  -F in_reply_to={databaseId}
```

**Note:** Use `-F` (not `-f`) for `in_reply_to` so it is sent as an integer, not a string.

### 6.2 Reply templates (always substantive — never bare acks)

**Never** reply with only "Done", "Fixed", "Ack", "Thanks", or "Will fix". Every reply must explain the outcome.

**Fixed (with local commits not yet pushed):**

```text
Addressed: <one-sentence description of the change>.
```

**Fixed (after push, when you have a commit SHA):**

```text
Addressed in <short_sha>: <one-sentence description of the change>.
```

If fixes are not pushed yet (this skill does not require push — `/pr` may come later), omit the SHA and still describe the change clearly. Optionally note that the fix is on the branch and will land with the next push.

**Question / observation (no code change):**

```text
<Substantive technical answer: why the current code is correct / how it works / what the constraint is.>
```

**Skipped (user declined, or agent did not apply):**

```text
Skipping this change: <concrete reason — user declined / already correct because … / out of scope because …>. Happy to revisit if needed.
```

The skip reason must be specific. Not allowed: "Skipping.", "Won't fix.", "No.", or an empty reason.

**Deferred (still reply + resolve unless user said leave open):**

```text
Acknowledged — deferring to a follow-up: <what will be done and where/when if known>. Resolving this thread; tracking the follow-up separately.
```

If the user explicitly said leave the thread open, use the same body but end with "Leaving this thread open to track." and do **not** resolve.

### 6.3 Resolve the review thread (GraphQL)

After a successful reply (for outcomes that should resolve), mark the thread resolved using the GraphQL node `id` from Phase 2:

```bash
NO_COLOR=1 gh api graphql -f query='
  mutation($threadId: ID!) {
    resolveReviewThread(input: {threadId: $threadId}) {
      thread {
        id
        isResolved
      }
    }
  }
' -f threadId='{thread_graphql_id}'
```

Verify `isResolved` is `true` in the response. If the mutation fails (permissions, already resolved, invalid id), log it in the summary and continue with remaining threads — do not abort the whole phase.

### 6.4 Order of operations per thread

For each handled item:

1. Compose the reply body from the template matching the outcome (what we did, or why we skipped)
2. POST the reply (`/replies` or `in_reply_to`)
3. Run `resolveReviewThread` for `fixed` | `question-answered` | `skipped` | `deferred`
4. Leave unresolved **only** if the user explicitly said to leave that thread open
5. Record success/failure of reply and resolve for the summary

Process threads sequentially (or with modest parallelism) but **do not** resolve before replying — reviewers should see the explanation on a resolved thread.

### 6.5 Top-level review bodies & issue comments

These are not GraphQL review threads:

- **Review summary body** (non-empty CHANGES_REQUESTED / COMMENTED review): after addressing, post a single PR conversation comment summarizing what was done, e.g. `gh pr comment {pr} --body "..."`. There is no per-review "resolve" API beyond dismissing the review (do **not** dismiss reviews unless the user asks).
- **Issue-style PR comments**: reply in the conversation with `gh pr comment` when a response is warranted. No resolve action.

### 6.6 Batching guidance

- One reply per thread (do not spam multiple status updates).
- If several threads were fixed by the same change, still reply on **each** thread referencing that change so each conversation closes cleanly.
- Prefer short, specific replies over long essays.

---

## Phase 7: Summary Report

After all work is complete (including Phase 6), provide a final report:

```markdown
## PR Review Fix Summary

**PR**: #[number] - [title]
**Branch**: [branch-name]

### Auto-Fixed (Low & Semantic)
| # | Severity | File | Fix Applied | Reviewer | GH Reply | Resolved |
|---|----------|------|-------------|----------|----------|----------|
| 1 | LOW | utils.ts:12 | Renamed `val` → `validationResult` | @alice | ✓ | ✓ |
| 2 | SEMANTIC | hooks/useData.ts:30 | Converted useState cluster to useReducer | @bob | ✓ | ✓ |

### User-Approved Fixes (Critical/High/Medium)
| # | Severity | File | Fix Applied | Reviewer | GH Reply | Resolved |
|---|----------|------|-------------|----------|----------|----------|
| 3 | CRITICAL | auth.ts:45 | Parameterized SQL query | @alice | ✓ | ✓ |
| 4 | HIGH | api/users.ts:92 | Added null guard on profile | @bob | ✓ | ✓ |

### Skipped (user or agent)
| # | Severity | File | Why skipped | Reviewer | GH Reply | Resolved |
|---|----------|------|-------------|----------|----------|----------|
| 5 | MEDIUM | utils/parse.ts:30 | User declined — extract date helper later | @alice | ✓ | ✓ |

### Already Resolved (pre-existing)
| # | File | Comment | Reviewer |
|---|------|---------|----------|
| 6 | old-file.ts | Previous review round | @charlie |

### GitHub thread actions
- Processed unresolved threads: N (must equal Phase 2 count)
- Replied: N threads (must equal processed count)
- Resolved: M threads
- Left open (user asked): K threads
- Failed reply/resolve: list any errors
- **Coverage check:** every Phase 2 unresolved thread id appears above. If any are missing, go back and reply + resolve them before finishing.

### Next Steps
- Run `/pr` to commit and push all fixes (if not already pushed)
- Confirm every processed thread has a reply + resolved state on the PR
```

---

## Error Handling

| Error | Action |
|-------|--------|
| No PR found | Stop, tell user to create a PR first |
| No review comments | Stop, tell user the PR has no feedback yet |
| gh CLI not authenticated | Stop, tell user to run `gh auth login` |
| Fix causes issues | Try alternative approach, or escalate to user |
| Ambiguous comment | Classify as MEDIUM and present to user |
| Comment is a question, not a request | Answer in the thread reply (Phase 6), resolve the thread, don't make code changes |
| User or agent skips a change | Still reply with the skip reason and resolve the thread — never silently leave it |
| Reply API fails | Retry once with the `in_reply_to` fallback; if still failing, note in summary and still attempt resolve if appropriate |
| Resolve mutation fails | Note in summary; leave thread open rather than faking success |
| Missing `thread.id` or `databaseId` | Re-fetch that thread via GraphQL before Phase 6; do not invent ids |

---

## Important Rules

1. **Only process unresolved threads** for triage and fixes — already-resolved discussions are not re-fixed. They appear only in the "Already Resolved" section of the summary.
2. **Read the actual code** before classifying — a "rename variable" comment on a public API export is HIGH, not LOW. Getting this wrong means silently applying a breaking change.
3. **Preserve reviewer intent** — don't "improve" beyond what was asked.
4. **Never auto-apply impactful changes** — CRITICAL/HIGH/MEDIUM always wait for user approval, even when the fix looks obvious. The user wants to see every meaningful change before it lands.
5. **Always include a concrete proposed fix** when presenting CRITICAL/HIGH/MEDIUM — don't just relay the reviewer's comment. Show the exact code change.
6. **Group related comments** — if 3 comments are all about the same function, fix them together (but still reply/resolve each thread in Phase 6).
7. **Don't argue with reviewers** — implement what's asked. If you disagree, note it in the summary for the user and in the thread reply if the item is skipped.
8. **Track everything** — every unresolved comment must appear in the final summary. Already-resolved comments are listed separately for reference.
9. **Reply + resolve every processed thread, including skipped** — Phase 6 is not optional and is not "fixed items only". Every unresolved thread from Phase 2 gets a reply (what we did, or why we skipped it) and is then marked resolved. A skipped code change still gets a skip-reason reply and a resolve.
10. **Never bare-ack** — every GitHub reply must explain what was done or why it was skipped. Empty / "Done" / "Skipping." replies are a failure of this skill.
11. **Reply before resolve** — always post the explanation first, then mark the thread resolved.
12. **Do not dismiss reviews** (`PUT .../reviews/{id}/dismissals`) unless the user explicitly asks — resolving threads is enough for conversation hygiene.
13. **Coverage before done** — do not finish until replied + resolved count matches the Phase 2 unresolved thread count (minus any the user explicitly asked to leave open).
14. **Always isolate in a code-only worktree first** (Phase 0 / `/worktree-quick` script). Never work in the primary checkout. **Yarn install is mandatory** on every worktree (create, reuse, already-isolated). Never skip yarn because `node_modules` exists.

User arguments: $ARGUMENTS
````

#### `~/.ai/commands/fix-shipyard-tests.md`

````markdown file=~/.ai/commands/fix-shipyard-tests.md
---
description: Fetches recent integration and e2e test failures from Future-Mortgage/shipyard GitHub Actions (https://github.com/Future-Mortgage/shipyard/actions), diagnoses root causes in the monorepo, implements fixes, and opens a new PR that addresses the failing tests. Always creates a code-only git worktree first (same as /worktree-quick; yarn install is mandatory) so /fix-shipyard-tests does not need a prior /worktree-quick. Use when the user runs /fix-shipyard-tests, says "fix shipyard tests", "fix e2e failures", "fix integration test fails", "shipyard CI is red", or asks to fix failing shipyard Actions runs.
---

# /fix-shipyard-tests — Shipyard Integration & E2E Fixer

Pull recent **integration** and **e2e** failures from [Future-Mortgage/shipyard Actions](https://github.com/Future-Mortgage/shipyard/actions), diagnose them, fix the monorepo (or shipyard when the bug is deploy/infra), and open a **new PR**.

**Usage:** `/fix-shipyard-tests`  
**Optional args:** a run URL/ID, or `"integration"` / `"e2e"` to scope which job suite to fix.

This skill creates the code-only worktree itself (`quick-worktree.sh new "fix-shipyard-tests"` unless a PR/branch is given). Do **not** require a prior `/worktree-quick`. **Yarn install is mandatory** on every worktree (create, reuse, already-isolated).

---

## Core Philosophy

- **Shipyard is the signal; monorepo is usually the fix.** Deploy Dev checks out monorepo test apps and hits the deployed dev environment. Prefer fixing product code or tests in `Future-Mortgage/monorepo` unless logs prove a shipyard workflow/infra bug.
- **New branch, new PR.** Never push to `main`. Always create a dedicated fix branch and open a PR.
- **Find every failure in the selected run(s).** Do not stop at the first red step.
- **Understand before changing.** Distinguish flaky env/auth, outdated selectors, product regressions, and pipeline config issues.
- **Fix root causes, not the pipeline.** Do not weaken tests or skip jobs unless the user explicitly asks.

---

## Context: What Shipyard Runs

| Piece | Detail |
|-------|--------|
| Repo | `Future-Mortgage/shipyard` |
| Primary workflow | **Deploy Dev (GCP)** — `.github/workflows/deploy-dev-gcp.yml` |
| Trigger | `repository_dispatch` (`gcp-monorepo-merged-to-main`, etc.) or `workflow_dispatch` |
| Job pipeline | `prepare` → `build_images` → `deploy` → **`integration_tests`** → **`e2e_tests`** |
| Integration command | `yarn vitest run --config apps/server-crm-e2e/vitest.config.ts --no-file-parallelism` |
| E2E commands | `npx playwright test --config=apps/server-crm-e2e/playwright.config.ts` then `apps/web-crm-e2e/playwright.config.ts` |
| Test apps (monorepo) | `apps/server-crm-e2e`, `apps/web-crm-e2e` |
| Target env | Dev host via `TEST_BASE_URL` (shipyard vars) |
| Artifacts | `e2e-test-results` (Playwright screenshots/traces under `apps/*-e2e/test-results/`) |

**This skill only treats `integration_tests` and `e2e_tests` as in-scope failures.**  
If `prepare` / `build_images` / `deploy` failed and tests never ran, report that and stop (or ask the user if they want infra/deploy debugging instead).

---

## Agent Roster

| Agent | `subagent_type` | Use for |
|-------|-----------------|---------|
| Test Writer/Fixer | `test-writer-fixer` | Assertion mismatches, flaky selectors, outdated e2e expectations |
| Frontend Developer | `frontend-developer` | web-crm UI/login/selector regressions |
| Backend Architect | `backend-architect` | API/integration contract breaks in server-crm |
| DevOps Automator | `devops-automator` | Shipyard workflow, secrets, env URL, deploy-only issues |

---

## Execution Flow

```
0. Code-only worktree (yarn mandatory)
1. Resolve workspace & git safety
2. Find recent failed Deploy Dev runs (integration / e2e)
3. Select run(s) and extract failed jobs
4. Parse logs + download artifacts when useful
5. Diagnose root causes (group + prioritize)
6. Implement fixes on a new branch
7. Verify locally when possible
8. Commit, push, open a new PR
9. Report summary with run links and PR URL
```

---

## Phase 0: Code-only worktree (always, before any work)

Work **never** runs in the primary checkout. Isolate first with the same script as `/worktree-quick`, then continue in that worktree. **Do not** wait for `/worktree-quick`. **Do not** use `/monorepo-worktree` unless the user asked for a runnable second stack. **Do not** stop after create.

**Yarn is mandatory on every worktree.** Create, reuse, and already-isolated all require `yarn install` in the worktree with exit 0 (10 min timeout). Never skip because `node_modules` exists. Never skip on reuse. If the create script already ran yarn in this turn and you watched it exit 0, that create counts; reuse / already-isolated **must still yarn**.

User arguments: `$ARGUMENTS`

### Parse target

`integration` / `e2e` / Actions run URLs/IDs are **not** git refs. They stay as skill args.

| TARGET | Action |
|--------|--------|
| PR / URL | `~/.ai/oc_skills/worktree-quick/scripts/quick-worktree.sh <n-or-url>` |
| Branch / ref | `…/quick-worktree.sh <ref>` |
| Else (typical) | `…/quick-worktree.sh new "fix-shipyard-tests"` — the `quick/…` branch **is** the fix branch; do not create another branch unless needed |

Skip create only if cwd is already a matching `*-quick-*` worktree. If path already exists: **reuse**. If reusing and **dirty**, do not `reset --hard`.

### Yarn (always)

```bash
(cd "<path>" && yarn install)
```

Reuse / already-isolated: **always** run this. Wait for exit 0.

### Move the session, then work

OpenCode: `tools.opencode.session_move` with `directory` = absolute worktree path. Continue this session. Then **immediately** continue. Do **not** destroy the worktree when finished.

---

## Phase 1: Workspace & Safety

### 1.1 Confirm monorepo checkout

Prefer working in `Future-Mortgage/monorepo` (current workspace is usually this).

```bash
gh repo view --json nameWithOwner -q '.nameWithOwner'
git status
git branch --show-current
```

- If not in monorepo and the fix is monorepo-side, **stop** and tell the user to open the monorepo (or clone it).
- If the only fix is shipyard-side, work in a shipyard checkout (clone to a temp dir only if the user agrees).

### 1.2 Never work on main

```bash
git fetch origin main
git checkout main
git pull --ff-only origin main
```

Create a fix branch **before** edits:

```bash
git checkout -b fix/shipyard-<integration|e2e|tests>-<short-slug>
```

Examples:
- `fix/shipyard-e2e-auth-login-selector`
- `fix/shipyard-integration-loan-status`

If the working tree is dirty with unrelated changes, **stop and ask** the user how to proceed.

---

## Phase 2: Find Recent Failures

Always use the shipyard repo explicitly:

```bash
# Recent Deploy Dev runs (broad view)
gh run list \
  --repo Future-Mortgage/shipyard \
  --workflow "Deploy Dev (GCP)" \
  --limit 15 \
  --json databaseId,status,conclusion,displayTitle,createdAt,url,headSha,event
```

Filter to completed failures:

```bash
gh run list \
  --repo Future-Mortgage/shipyard \
  --workflow "Deploy Dev (GCP)" \
  --status failure \
  --limit 10 \
  --json databaseId,status,conclusion,displayTitle,createdAt,url,headSha,event
```

### 2.1 Select which run(s)

| User input | Selection |
|------------|-----------|
| None | Most recent **completed** Deploy Dev run where `integration_tests` and/or `e2e_tests` failed |
| Run URL or numeric ID | That run only |
| `integration` / `e2e` | Most recent run where that job failed |
| Multiple recent reds with same error | Fix once using the newest representative run; mention older runs in the PR |

If the latest run is still `in_progress`, warn and use the most recent **completed** failure unless the user insists on waiting.

If recent Deploy Dev runs are all green for both test jobs, **stop** and report that integration/e2e are passing.

### 2.2 Confirm which jobs failed

```bash
gh run view <run-id> --repo Future-Mortgage/shipyard \
  --json jobs --jq '.jobs[] | {name, conclusion, status}'
```

Build the work list from jobs named:
- `integration_tests` with `conclusion == "failure"`
- `e2e_tests` with `conclusion == "failure"`

Ignore Slack notify steps noise; focus on the test command failures.

---

## Phase 3: Extract Errors

### 3.1 Failed logs

```bash
gh run view <run-id> --repo Future-Mortgage/shipyard --log-failed
```

If huge, still start with `--log-failed`. Prefer grepping for:

**Playwright / e2e**
- `Error:`, `TimeoutError:`, `expect(`
- `locator.`, `toBeVisible`, `toHaveURL`
- `✘`, `failed`, `did not run`
- File paths under `apps/server-crm-e2e/` or `apps/web-crm-e2e/`
- `Error Context:`, screenshot / `trace.zip` paths

**Vitest / integration**
- `FAIL `, `AssertionError`, `Expected`, `Received`
- `Error:`, stack frames under `apps/server-crm-e2e/`
- `Test Files`, `Tests` summary lines

**Env / deploy-adjacent (report, don't "fix" by skipping tests)**
- `ECONNREFUSED`, `ENOTFOUND`, `401`, `403`, `5xx`
- `TEST_BASE_URL`, login/OTP failures, seed/data missing

### 3.2 Artifacts (e2e)

When e2e failed, download Playwright artifacts:

```bash
gh run download <run-id> \
  --repo Future-Mortgage/shipyard \
  --name e2e-test-results \
  --dir /tmp/shipyard-e2e-<run-id>
```

Inspect:
- `**/test-failed-*.png`
- `**/error-context.md`
- traces if needed: `npx playwright show-trace <path-to-trace.zip>` (only when screenshot/context is insufficient)

### 3.3 Error inventory

For each distinct failure capture:

1. **Run ID + URL**
2. **Job** (`integration_tests` | `e2e_tests`)
3. **Step / suite** (vitest file or playwright project)
4. **Test name + file:line**
5. **Error text** (full assertion/timeout message)
6. **Category** — product bug | outdated test | selector/auth flake | env/data | shipyard config
7. **Likely fix location** — monorepo app path vs e2e path vs shipyard workflow

---

## Phase 4: Diagnose Root Causes

### 4.1 Group related failures

Examples:
- Auth setup timeout → all dependent e2e skipped → **one** root cause (login page / URL / credentials / selector)
- Many integration tests fail on same API shape → one contract change
- Single assertion drift after a feature ship → update test or restore product behavior

### 4.2 Prioritize

1. **Blockers for suites** (auth.setup, global setup, base URL, env)
2. **Product regressions** that break user-visible flows
3. **Integration contract mismatches**
4. **Isolated e2e assertion/selector updates**
5. **True flakes** — fix determinism (waits, data seeding), do not just bump timeouts unless justified

### 4.3 Decide fix repo

| Signal | Fix in |
|--------|--------|
| Stack/file under `apps/*-e2e` expectations wrong after intentional product change | monorepo tests |
| UI/API broke and product should keep old behavior | monorepo product code |
| Deploy/env URL/secret/workflow step broken; app tests are fine | shipyard (ask before large infra changes) |
| Cannot tell | Prefer monorepo investigation first; document uncertainty |

Read the monorepo source around the failing paths before editing.

---

## Phase 5: Implement Fixes

### 5.1 Plan

Create a todo list of root causes (not every log line). Work in dependency order.

### 5.2 Implement

- **Simple, local edits** — do directly.
- **Test-only updates** — `test-writer-fixer`.
- **web-crm UI** — `frontend-developer`.
- **server-crm / shared API** — `backend-architect`.
- **Shipyard workflow/env** — `devops-automator`, and confirm with the user before changing deploy behavior.

Respect monorepo rules:
- Prefer `nx` / project scripts over ad-hoc tooling.
- For web-crm z-index work, follow `apps/web-crm/AGENTS.md`.
- Do not invent secrets; do not commit `.env` files.

### 5.3 What not to do

- Do not delete or skip failing tests to go green.
- Do not hardcode production secrets.
- Do not change shipyard to ignore test jobs.
- Do not amend unrelated local commits or force-push.

---

## Phase 6: Verify Locally

Full shipyard parity needs deployed dev + secrets. Still verify what you can:

### 6.1 Static / unit-level

```bash
# Typecheck touched projects when applicable
yarn nx run-many --target=typecheck --projects=server-crm-e2e,web-crm-e2e,server-crm,web-crm
```

Adapt project names to what changed.

### 6.2 Integration (vitest) — if local env supports it

```bash
yarn vitest run --config apps/server-crm-e2e/vitest.config.ts --no-file-parallelism
```

Or a single file from the failure inventory.

### 6.3 E2E (Playwright) — optional, env-dependent

Only if `TEST_BASE_URL` / local stack is available and user expects it:

```bash
npx playwright test --config=apps/server-crm-e2e/playwright.config.ts <failing-file>
npx playwright test --config=apps/web-crm-e2e/playwright.config.ts <failing-file>
```

Local multi-tenant note (from monorepo docs): use tenant hosts like `http://fm.futurewholesale.local:3000`, not bare localhost, when running against local web-crm.

### 6.4 Verification honesty

If you cannot reproduce against real dev:

- State that clearly in the PR.
- Rely on log/artifact diagnosis + code review confidence.
- Prefer minimal, targeted fixes over speculative rewrites.

**Max 3 fix → verify loops.** Then open the PR with remaining risks called out.

---

## Phase 7: Commit, Push, Open PR

### 7.1 Commit

```bash
git status
git diff
git log origin/main..HEAD --oneline
git add -A
```

Conventional commit focused on the shipyard failure:

```text
fix(e2e): restore login email selector used by shipyard playwright auth

Shipyard Deploy Dev e2e_tests failed on auth.setup (run <id>).
```

Use `fix(integration):` / `fix(e2e):` / `fix(shipyard-tests):` as appropriate.

### 7.2 Push (feature branch only)

```bash
git branch --show-current   # must NOT be main/master
git push -u origin HEAD
```

### 7.3 Create a **new** PR

```bash
gh pr create --title "fix: shipyard <integration|e2e> — <short cause>" --body "$(cat <<'EOF'
## What & why
Fixes failing **Shipyard Deploy Dev** integration/e2e tests so the post-deploy pipeline can go green again.

**Failed run(s):**
- https://github.com/Future-Mortgage/shipyard/actions/runs/<run-id>

## Failures addressed
| Job | Test / step | Root cause | Fix |
|-----|-------------|------------|-----|
| e2e_tests | auth.setup.ts › authenticate | … | … |

## Key decisions
- [What was chosen and why]
- [Whether product code vs test was updated]

## Notes for the reviewer
- [Riskiest change]
- [Anything env-specific that may still flake on dev]

## Verification
- [ ] Parsed shipyard `--log-failed` for run(s) above
- [ ] Reviewed Playwright artifacts (if e2e)
- [ ] Local commands run: …
- [ ] Not fully reproducible locally (if true) — reason: …

EOF
)"
```

Base the PR on `main`. Do not open against a random feature branch unless the user says so.

If a PR for this branch already exists, update its body instead of opening a duplicate:

```bash
gh pr view --json url,number
gh pr edit --body "..."
```

---

## Phase 8: Summary Report

```markdown
## Shipyard Test Fix Summary

**Source:** Future-Mortgage/shipyard Actions  
**Run(s):** [id](url) — Deploy Dev (GCP)  
**Jobs:** integration_tests ❌/✅ · e2e_tests ❌/✅

### Failures → Fixes
| Job | Failure | Root cause | Change | Repo |
|-----|---------|------------|--------|------|
| e2e_tests | … | … | … | monorepo |

### PR
- **Branch:** fix/shipyard-…
- **PR:** <url>
- **Commit:** <sha>

### Verification
| Check | Result |
|-------|--------|
| Log analysis | done |
| Artifact review | done / n/a |
| Local tests | pass / partial / skipped (reason) |

### Follow-ups
- Re-run or wait for next monorepo→shipyard Deploy Dev after merge
- Any residual flakes or infra-only issues
```

---

## Error Handling

| Situation | Action |
|-----------|--------|
| `gh` not authenticated | Stop; ask user to `gh auth login` with access to `Future-Mortgage/shipyard` |
| No failed integration/e2e in recent runs | Stop; report green (or only deploy/build failures) |
| Only prepare/build/deploy failed | Stop; tests did not run — offer separate deploy debug path |
| Dirty unrelated working tree | Stop; ask user |
| On `main` with accidental edits | Move commits to a fix branch; never push main |
| Fix belongs in shipyard | Confirm with user; open PR in shipyard if they agree |
| Env-only failure (dev down, bad secret) | Do **not** invent app “fixes”; report evidence and suggested ops steps |
| Logs too large | Use `--log-failed`, job-scoped view, and artifact screenshots |
| Cannot get CROSS_REPO / dev secrets locally | Document; still ship the code/test fix with clear verification limits |

---

## Important Rules

1. **Always** pass `--repo Future-Mortgage/shipyard` when querying Actions.
2. **Only** treat `integration_tests` and `e2e_tests` as the primary fix targets for this skill.
3. **Always** create a new feature branch and a PR — do not push fixes to `main`.
4. Prefer monorepo fixes that make tests correct and product correct; do not mute CI.
5. Parse **all** distinct test failures in the chosen run, then group by root cause.
6. Download e2e artifacts when Playwright failed — screenshots beat guessing.
7. Be explicit when verification against real dev was not possible.
8. Keep the PR description a handoff: run links, root causes, decisions, verification gaps.
9. If the user passes a specific run URL/ID, use that run; do not silently switch to another.
10. **Always isolate in a code-only worktree first** (Phase 0). **Yarn install is mandatory** on every worktree (create, reuse, already-isolated). Never skip yarn because `node_modules` exists.

---

## Quick Reference

```
/fix-shipyard-tests [run-url|run-id] [integration|e2e]

  1. git: clean tree, branch from main → fix/shipyard-...
  2. gh run list --repo Future-Mortgage/shipyard --workflow "Deploy Dev (GCP)"
  3. gh run view <id> --repo Future-Mortgage/shipyard --log-failed
  4. gh run download <id> --repo Future-Mortgage/shipyard --name e2e-test-results
  5. Diagnose → fix monorepo (default) or shipyard (infra only)
  6. Verify locally as much as env allows
  7. commit + push + gh pr create
  8. Report run links + PR URL
```

User arguments: $ARGUMENTS
````

#### `~/.ai/commands/fix-tailwind.md`

````markdown file=~/.ai/commands/fix-tailwind.md
---
description: Normalizes all Tailwind classes in a PR's touched .tsx/.jsx files to use ONLY values defined in the project's tailwind.config (colors, spacing, fontSize, fontFamily, borderRadius, etc.). Replaces arbitrary values (e.g. `text-[#abc123]`, `p-[13px]`, `bg-[rgb(...)]`), off-scale tokens (e.g. `text-blue-50`, `bg-gray-700`), and any class that doesn't resolve to a config value with the closest available default. Also collapses raw hex/rgb to the nearest configured palette entry. Always creates a code-only git worktree first (same as /worktree-quick; yarn install is mandatory) so /fix-tailwind 1234 does not need a prior /worktree-quick. Use when user says "/fix-tailwind", "/fix-tailwind <PR#>", "fix tailwind in this PR", "normalize tailwind classes", or "snap tailwind to config".
---

# /fix-tailwind — Snap Tailwind classes in a PR to config defaults

Goal: make every Tailwind class in changed `.tsx` / `.jsx` / `.ts` / `.js` frontend files resolve against the project's `tailwind.config.{js,ts}`. Anything arbitrary, off-scale, or undefined is rewritten to the **closest matching config value**. Nothing else in the file is touched.

**Usage:**
- `/fix-tailwind` — operate on the current branch's diff vs. `origin/main`.
- `/fix-tailwind <PR-number>` — check out the PR locally (or read its diff via `gh pr diff`) and operate on that PR's touched files.
- `/fix-tailwind <PR-url>` — same, parsed from URL.

`/fix-tailwind 1234` is enough — this skill creates the code-only worktree itself. Do **not** require a prior `/worktree-quick`. **Yarn install is mandatory** on every worktree (create, reuse, already-isolated).

---

## Core Rules

1. **Eliminate arbitrary values.** Any utility containing `[...]` (e.g. `text-[#abc123]`, `p-[13px]`, `bg-[rgb(0,0,0)]`, `w-[42%]`, `gap-[7px]`) **must** be replaced with the closest matching config token. This is a **hard rule**, not a preference. The only exception is when no analog exists *at all* in the relevant scale (e.g. a one-off `grid-cols-[1fr_auto_2fr]` template, a custom `clip-path-[...]`, an `animate-[...]` with no named keyframe). In those rare cases, leave the class and list it in the report under "Skipped — no config analog".
2. **Config is the source of truth.** Read `tailwind.config.{js,ts,cjs,mjs}` (and any imported theme files / CSS-variable definitions it depends on). Build the allowed-value table from `theme` + `theme.extend` (plus Tailwind's built-in defaults for any property not fully overridden).
3. **Only edit changed files.** Use `git diff --name-only` against the base. Filter to `.tsx`, `.jsx`, `.ts`, `.js` — and only those that actually contain JSX or `className=` / `class=` / `clsx(` / `cn(` / `cva(` / `tw\`...\`` usages.
4. **Only edit class strings.** Never modify TS logic, imports, props, types, or non-class string literals. Class extraction must be precise (see Phase 3).
5. **Closest match, not "creative" match.** If a value has no exact config equivalent, pick the **numerically/perceptually closest** entry from the same property family. Don't guess intent. Don't pick a semantic token unless the original was semantic.
6. **Off-scale named tokens are also rewrites.** `bg-gray-100` (no `gray` in palette), `text-blue-50`, `bg-blue-900` (outside the 100–800 scale), `rounded-md` (when `md` isn't in the configured radius set) — all get snapped to the closest configured value, same as arbitrary values.
7. **Never invent new classes.** Substitution only. If no reasonable closest match exists in the relevant scale, leave the class alone and report it.
8. **Never strip `dark:`, `hover:`, `md:`, `[&>...]`, group/peer, or other variant prefixes.** Variants are preserved verbatim; only the trailing utility token is rewritten. Note: `[&>...]` and `data-[state=open]:` are *variant brackets*, not arbitrary *values* — they are NOT subject to rule 1.
9. **Never reorder, dedupe, or "tidy" classes** beyond the substitutions required. Whitespace and class order must match input.
10. **Idempotent.** Running twice produces no further changes.
11. **Do not run formatters or linters** (no `prettier`, no `eslint --fix`). Edits are minimal and surgical.

---

## Execution Flow

```
0. Code-only worktree       -> /worktree-quick script + yarn + session_move (always)
1. Resolve target           -> current branch OR PR# OR PR URL
2. Get changed files        -> git diff --name-only (filtered)
3. Load tailwind config     -> build allowed-value tables per property family
4. For each file:
     a. Extract class strings (className=, clsx, cn, cva, tw``)
     b. Tokenize each string into utilities (preserving variants)
     c. For each utility: classify family, check against config, replace if needed
     d. Reassemble + Edit the file (only if changes were made)
5. Report                   -> per-file before/after table + summary
```

---

## Phase 0: Code-only worktree (always, before any work)

Work **never** runs in the primary checkout. Isolate first with the same script as `/worktree-quick`, then continue in that worktree. **Do not** wait for `/worktree-quick`. **Do not** use `/monorepo-worktree`. **Do not** stop after create.

**Yarn is mandatory on every worktree.** Create, reuse, and already-isolated all require `yarn install` in the worktree with exit 0 (10 min timeout). Never skip because `node_modules` exists. Never skip on reuse. If the create script already ran yarn in this turn and you watched it exit 0, that create counts; reuse / already-isolated **must still yarn**.

User arguments: `$ARGUMENTS`

### Parse target

PR numbers / `#N` / `pr N` / GitHub `.../pull/N` / git refs are worktree targets.

| TARGET | Action |
|--------|--------|
| PR / URL | `~/.ai/oc_skills/worktree-quick/scripts/quick-worktree.sh <n-or-url>` |
| Branch / ref | `…/quick-worktree.sh <ref>` |
| Empty | `gh pr view --json number -q .number`. If that fails and cwd is already `*-quick-*`, skip create. Else if current branch is not `main`/`master`, worktree that branch. Else ask for a PR number. |

Remember `PR_NUMBER`. Later `gh pr view` must use `gh pr view ${PR_NUMBER}`.

### Create or reuse

Do **not** hand-roll `git worktree add`. Skip create only if cwd is already a matching `*-quick-*` worktree. If path already exists: **reuse**. If reusing and **clean**, fetch+reset to latest. If **dirty**, do not `reset --hard`.

### Yarn (always)

```bash
(cd "<path>" && yarn install)
```

Reuse / already-isolated: **always** run this. Wait for exit 0.

### Move the session, then work

OpenCode: `tools.opencode.session_move` with `directory` = absolute worktree path. Continue this session. Then **immediately** continue. Do **not** destroy the worktree when finished.

---

## Phase 1: Resolve Target

```bash
# No arg → current branch diff vs base
git branch --show-current
BASE=$(git remote show origin | grep 'HEAD branch' | awk '{print $NF}')
git merge-base HEAD origin/$BASE
```

If a PR number/URL was given:
```bash
# Get PR head SHA + base, fetch, build a diff range
gh pr view <PR> --json headRefName,baseRefName,headRepository,number
gh pr diff <PR> --name-only        # quick file list
gh pr checkout <PR>                 # only if user wants edits committed locally
```
If the user only wants a *report* (no edits) for a remote PR, use `gh pr diff <PR>` and operate on the diff content rather than checked-out files. Default: edit locally only if the PR is already checked out; otherwise prompt.

---

## Phase 2: Collect Changed Files

```bash
git diff --name-only $(git merge-base HEAD origin/$BASE)..HEAD \
  | grep -E '\.(tsx|jsx|ts|js)$' \
  | grep -vE '(\.test\.|\.spec\.|\.stories\.|/node_modules/|/dist/|/build/)'
```

For each candidate, quickly check it actually contains class strings (`grep -lE 'className=|class=|clsx\(|cn\(|cva\(|tw\`'`). Skip pure-logic files.

If a repo has **multiple `tailwind.config`** files (monorepo with multiple apps), pick the config whose `content` glob matches the file being edited. If no config matches, skip the file and note it.

---

## Phase 3: Load the Tailwind Config

Read `tailwind.config.{js,ts,cjs,mjs}` for the relevant app. Resolve everything statically — do not execute it. Specifically extract:

| Family | Where to look | Build set of |
|---|---|---|
| Colors | `theme.colors`, `theme.extend.colors` | `{<color>-<shade>}` keys, including `DEFAULT`, plus semantic tokens (`primary`, `muted`, etc.). Resolve hex values for distance comparisons. CSS-variable-backed colors (`hsl(var(--x))`) are kept as opaque tokens — match them by name only. |
| Spacing | `theme.spacing`, `theme.extend.spacing` (fallback to Tailwind defaults if absent) | px/rem values per key |
| Font size | `theme.fontSize`, `theme.extend.fontSize` | sizes per key |
| Font family | `theme.fontFamily`, `theme.extend.fontFamily` | family names |
| Border radius | `theme.borderRadius`, `theme.extend.borderRadius` | sizes per key |
| Border width | `theme.borderWidth`, `theme.extend.borderWidth` | widths per key |
| Box shadow | `theme.boxShadow`, `theme.extend.boxShadow` | named shadows |
| Z-index | `theme.zIndex`, `theme.extend.zIndex` | numeric/name keys |
| Opacity | `theme.opacity`, `theme.extend.opacity` | percent keys |
| Line height | `theme.lineHeight`, `theme.extend.lineHeight` | sizes per key |
| Letter spacing | `theme.letterSpacing`, `theme.extend.letterSpacing` | sizes per key |
| Animations | `theme.animation`, `theme.extend.animation` | names |
| Keyframes | `theme.keyframes`, `theme.extend.keyframes` | names |

If a property is **not extended**, fall back to Tailwind's built-in defaults for that property (the project still allows them). Treat the union of `defaults ∪ extend` as "allowed".

If a property is **fully overridden** (declared in `theme.<prop>` not `theme.extend.<prop>`), only the override values are allowed.

> Important for this monorepo's convention: scales typically run `100…800`. So `bg-blue-50`, `bg-blue-900`, `bg-gray-*` (no `gray` in config) are all **off-scale** and must be remapped.

---

## Phase 4: Tokenize and Rewrite

For each extracted class string:

### 4.1 Split utilities
Split on whitespace. For each utility, peel off variant prefixes (everything before the final `:`, supporting arbitrary variants like `[&>div]:`, `data-[state=open]:`, `dark:`, `md:`, `group-hover:`, etc.). Keep prefixes verbatim. Rewrite only the trailing utility token.

Also handle:
- `!` important prefix (`!text-red-500`) → preserve.
- `-` negative prefix (`-mt-4`) → preserve.

### 4.2 Classify the utility
Match against known Tailwind property prefixes to determine the family:

| Prefix examples | Family |
|---|---|
| `text-`, `bg-`, `border-`, `ring-`, `from-`, `via-`, `to-`, `fill-`, `stroke-`, `placeholder-`, `accent-`, `caret-`, `divide-`, `outline-`, `decoration-`, `shadow-` (color form) | color |
| `p-`, `px-`, `py-`, `pt-`, `pr-`, `pb-`, `pl-`, `m-`, `mx-`, `my-`, `mt-`, `mr-`, `mb-`, `ml-`, `gap-`, `gap-x-`, `gap-y-`, `space-x-`, `space-y-`, `inset-`, `top-`, `right-`, `bottom-`, `left-`, `w-`, `h-`, `min-w-`, `min-h-`, `max-w-`, `max-h-`, `size-`, `translate-x-`, `translate-y-` | spacing |
| `text-` (with size keys: xs/sm/base/lg/xl/…/9xl, or arbitrary) | fontSize |
| `font-` (sans/serif/mono/custom names) | fontFamily |
| `font-` (thin/normal/bold/…/numeric) | fontWeight (Tailwind defaults; rarely extended) |
| `rounded-`, `rounded-{side}-` | borderRadius |
| `border-`, `border-{side}-` (numeric) | borderWidth |
| `shadow-` (non-color) | boxShadow |
| `z-` | zIndex |
| `opacity-`, `bg-opacity-`, `text-opacity-`, etc. | opacity |
| `leading-` | lineHeight |
| `tracking-` | letterSpacing |
| `animate-` | animation |

⚠️ `text-*` is ambiguous (color or fontSize or alignment). Disambiguate by checking what the suffix matches in the config. `text-center` is alignment (always allowed). `text-blue-500` is color. `text-sm` is size. `text-[14px]` is fontSize arbitrary. `text-[#abc]` is color arbitrary.

### 4.3 Decide if rewrite needed

A utility is **already valid** if:
- It's not parameterized (e.g. `flex`, `grid`, `block`, alignment, display, layout, etc.) — leave alone.
- Its suffix exactly matches a configured key in its property family AND does not use `[…]` arbitrary syntax.

A utility **needs rewrite** if (any of):
- It uses arbitrary `[…]` syntax of any kind: `[#hex]`, `[rgb(...)]`, `[hsl(...)]`, `[var(--…)]`, `[Npx]`, `[Nrem]`, `[N%]`, `[Nch]`, `[calc(...)]`, etc. Per Rule 1, this is a hard requirement — find the closest config token. Only skip if no analog exists in the entire scale.
- Its arbitrary value is even *exactly* equal to a configured token (e.g. `text-[#0968F6]` when `blue.500 = #0968F6` — still rewrite to `text-blue-500` for consistency; eliminating brackets is the goal).
- Its suffix uses a key not in config: `bg-gray-100` (no `gray` in palette), `text-blue-50` / `text-blue-900` (outside 100–800 scale), `rounded-md` when not in configured radius set, etc.

**Decision tree for any utility containing `[`:**
```
contains [...] arbitrary value?
├── YES → must rewrite
│   ├── closest config match exists in this family? → rewrite to it
│   └── no analog at all? → leave + add to "Skipped — no config analog" report
└── NO → check named-token validity (off-scale handling above)
```

### 4.4 Pick the closest config value

**Colors**:
1. Resolve the input to a concrete color (parse hex/rgb/hsl; for `text-blue-50` etc., resolve against Tailwind's built-in palette so we know what hex it would produce).
2. Convert to Lab and pick the configured color with smallest ΔE (CIE76 is fine).
3. Tie-break by family name match (if input was `blue-*`, prefer a `blue-*` config entry over equally-close non-blue).
4. Never substitute a semantic token (`primary`, `muted`, etc.) unless the input was *also* semantic and is now missing — semantic intent must come from the developer.
5. If the closest match is a CSS-variable-backed token (e.g. `neutral-*`), allow it only when the input was also neutral / gray.

**Spacing / sizes (px/rem)**:
1. Convert input and all config values to px (1rem = 16px unless `theme.fontSize.base` says otherwise).
2. Pick the entry with smallest absolute px delta.
3. Tie-break: prefer the smaller value (avoid silently inflating layout).

**Font size**:
1. Same as spacing, but only against the fontSize scale (including custom keys like `xxs: 10px`, `tiny: 13px`).

**Border radius / border width / line height / letter spacing / opacity / z-index**:
1. Numeric closest match; for named-only scales (e.g. `shadow-sm/md/lg`), if input is arbitrary, pick by closest blur radius / numeric magnitude inferred from the config's resolved value.

**Animations / keyframes / fontFamily**:
1. No "closest" — exact match only. If no match, **leave the class alone** and add a note to the report. Don't guess.

### 4.5 Construct the replacement
Rebuild the utility as `<variants>:<new-suffix>`, preserving `!` and `-` prefixes. Reassemble the full class string with the original whitespace.

If the rebuilt token is identical to the original, no edit.

---

## Phase 5: Apply Edits

For each file with at least one substitution:
1. Use the `Edit` tool with `replace_all: true` only when the old class string appears multiple times **and** the substitution is identical for all occurrences. Otherwise edit each occurrence with enough surrounding context to make it unique.
2. Never use `Write` to rewrite the whole file — too risky.
3. After all edits in a file, re-read the file and verify the changed regions parse as before (nothing other than class strings was touched).

If a file uses dynamic class construction (template literals with `${...}` interpolation, `clsx({ [computed]: ... })`), only rewrite the **static segments** of class strings. Skip interpolated sections — don't touch them.

---

## Phase 6: Report

Output a single markdown table per file:

```
### apps/web-crm/src/.../foo.tsx

| Line | Before | After | Reason |
|------|--------|-------|--------|
| 42 | text-[#0968F6] | text-blue-500 | exact hex match in config |
| 58 | bg-gray-100 | bg-neutral-100 | gray not in palette; closest neutral |
| 73 | p-[13px] | p-3 | 13px → 12px (closest spacing, Δ1px) |
| 91 | text-blue-50 | text-blue-100 | 50 not in scale (100–800) |
| 104 | rounded-md | rounded-default | md not in config; default=0.6125rem closest |
```

Followed by a summary:

```
## Summary
- Files scanned: N
- Files modified: M
- Total substitutions: K
- Skipped (no closest match): J
  - <list any unresolved utilities>
- Off-scale colors collapsed: …
- Arbitrary values normalized: …
```

If `--dry-run` was passed (or user said "preview" / "don't apply"), produce the report only — no Edits.

---

## Important Edge Cases

- **`className={cn(...)}` / `clsx(...)`**: walk every string-literal argument; the rules above apply to each. Object-key forms (`{ 'text-red-500': cond }`) — rewrite the key string.
- **`cva(...)` variants**: rewrite class strings inside the `variants`/`compoundVariants`/`defaultVariants` objects.
- **Tagged templates** (`tw\`...\``, `styled\`...\``): treat the entire template literal as a class string; tokenize and rewrite static segments only.
- **JSX spread** (`{...props}`): no className visible; ignore.
- **Inline styles** (`style={{ color: '#abc' }}`): out of scope. This skill only touches Tailwind class strings.
- **Custom CSS files / `.css` / `.scss`**: out of scope.
- **`@apply` directives** in CSS: out of scope (would need a separate pass against `.css` files; not part of this skill).
- **Variants on arbitrary values** (`md:bg-[#abc]`): preserve `md:`, rewrite the suffix.
- **Multiple semantic tokens for same color**: never pick `primary` over `blue-500` automatically — semantic intent is human.
- **Empty / pass-through classes**: `className=""` or `className={undefined}` → no-op.

---

## Safety Rails

| Situation | Action |
|---|---|
| Tailwind config missing or unparseable | Stop. Report which config was sought and where it's expected. |
| File has merge conflict markers | Skip file. Report. |
| File would change > 50 utilities | Show the user the proposed diff first, ask before applying. |
| Multiple tailwind configs and no `content` glob matches the file | Skip file. Report. |
| Animation/keyframe/fontFamily with no exact match | Leave alone. Report under "Skipped". |
| User passes `--dry-run` or `preview` | Report only. No Edits. |

---

## What This Skill Does NOT Do

- Does not run `prettier`, `eslint`, or any formatter.
- Does not commit or push. Edits are left in the working tree for the user to review.
- Does not touch `.css` / `.scss` / `.module.css` files or `@apply` rules.
- Does not refactor layout, swap components, or change non-class code.
- Does not pick semantic tokens (`primary`, `muted`, `accent`, etc.) when the input was a hue token — that's a design decision, not a normalization.
- Does not add new utility classes that weren't there. Substitution only.

---

## Quick Reference: Common Substitutions in This Repo

(Built from `apps/web-crm/tailwind.config.js` — color scales run **100–800**, neutral runs **100–900**.)

| Off-config | Likely fix |
|---|---|
| `text-blue-50` | `text-blue-100` |
| `bg-blue-900` | `bg-blue-800` |
| `text-gray-*` | `text-neutral-*` (closest shade) |
| `bg-slate-*` / `bg-zinc-*` / `bg-stone-*` | `bg-neutral-*` (closest shade) |
| `text-[#0968F6]` | `text-blue-500` |
| `rounded-md` | If `md` not in config, use `rounded-default` or closest configured radius |
| `text-[10px]` | `text-xxs` |
| `text-[13px]` | `text-tiny` |
| `font-DM_Sans` / `font-['DM_Sans']` | `font-sans` |

These are illustrative — always re-derive from the actual config at run time, not from this table.

**Always isolate in a code-only worktree first** (Phase 0). **Yarn install is mandatory** on every worktree (create, reuse, already-isolated). Never skip yarn because `node_modules` exists.

User arguments: $ARGUMENTS
````

#### `~/.ai/commands/fix-types.md`

````markdown file=~/.ai/commands/fix-types.md
---
description: Scans all TypeScript/types in a PR or branch diff for soft types (`any`, unnecessary `null`/`undefined`, optional fields that are required, `Partial`, unvalidated JSON, over-wide unions) and hardens them against Prisma/DB schemas, API contracts, and domain invariants — then fixes call sites so the code compiles with those hard types. Prefer exact definitions over `any` or nullish escape hatches. Always creates a code-only git worktree first (same as /worktree-quick; yarn install is mandatory) so /fix-types 1234 does not need a prior /worktree-quick. Use when the user runs /fix-types, /fix-types 1234, /fix-types <pr|branch>, "harden types", "fix soft types", "remove any types", "make types strict", or "hard types on this PR/branch".
---

# /fix-types - Harden Soft Types on a PR / Branch

Scans every type that is **part of the current PR or branch** (not the whole monorepo), finds soft types, grounds the correct hard shape in schema/contracts/domain code, rewrites the types to be exact, and fixes all call sites so the branch typechecks with those hard definitions.

**Usage:**
- `/fix-types` — current branch vs detected base (`main`/`master`)
- `/fix-types <branch>` — treat that branch as the scope (or diff target)
- `/fix-types pr` / `/fix-types <pr-number>` — use the open PR (or a given PR) for the file set

`/fix-types 1234` is enough — this skill creates the code-only worktree itself. Do **not** require a prior `/worktree-quick`. **Yarn install is mandatory** on every worktree (create, reuse, already-isolated).

---

## Core Philosophy

- **Hard types by default.** Almost every value has an exact expected shape. Prefer that shape over `any`, over-wide unions, or nullish "maybe."
- **`any` is almost never acceptable.** Neither is `as any`, `as unknown as T`, or `@ts-ignore` / `@ts-expect-error` used to silence type errors.
- **`null` / `undefined` are rare, intentional absences** — not defaults for "we didn't model this." If the domain requires the value after a successful load/auth/parse, the type must require it.
- **Schema is ground truth.** Prisma models, Zod/validators, OpenAPI/tRPC contracts, and existing domain types define what is real. Soften only when the schema truly allows absence.
- **Fix types first, then call sites.** Hardening a type without fixing consumers is incomplete. Softening types to make call sites compile is **forbidden**.
- **Scope is the PR/branch only.** Do not refactor unrelated packages. Touch files outside the diff only when required to export a shared hard type that the branch already depends on.
- **Do not invent product behavior.** If absence is a real product state (draft vs published, optional UI prop), keep it explicit (`T | null`, optional prop, or a dedicated draft type) — do not invent fake defaults.

---

## Execution Flow

```
0. Code-only worktree     -> /worktree-quick script + yarn + session_move (always)
1. Resolve scope          -> Branch / PR / base, file list, full diff
2. Inventory soft types   -> Scan changed TS/TSX (+ type-bearing files)
3. Ground truth           -> Prisma / Zod / API / domain contracts per finding
4. Plan hard types        -> Exact replacements; classify intentional soft
5. Apply type fixes       -> Interfaces, schemas, generics, return types
6. Fix call sites         -> Remove fallbacks/casts; narrow at boundaries
7. Verify                 -> Typecheck affected projects; fix remaining errors
8. Report                 -> Summary of hardened types + intentional leftovers
```

Use a short todo list for multi-file work. Prefer direct edits; spawn agents only when a package fan-out is large.

---

## Phase 0: Code-only worktree (always, before any work)

Work **never** runs in the primary checkout. Isolate first with the same script as `/worktree-quick`, then continue in that worktree. **Do not** wait for `/worktree-quick`. **Do not** use `/monorepo-worktree`. **Do not** stop after create.

**Yarn is mandatory on every worktree.** Create, reuse, and already-isolated all require `yarn install` in the worktree with exit 0 (10 min timeout). Never skip because `node_modules` exists. Never skip on reuse. If the create script already ran yarn in this turn and you watched it exit 0, that create counts; reuse / already-isolated **must still yarn**.

User arguments: `$ARGUMENTS`

### Parse target

PR numbers / `#N` / `pr N` / GitHub `.../pull/N` / git refs are worktree targets.

| TARGET | Action |
|--------|--------|
| PR / URL | `~/.ai/oc_skills/worktree-quick/scripts/quick-worktree.sh <n-or-url>` |
| Branch / ref | `…/quick-worktree.sh <ref>` |
| Empty | `gh pr view --json number -q .number`. If that fails and cwd is already `*-quick-*`, skip create. Else if current branch is not `main`/`master`, worktree that branch. Else ask for a PR number. |

Remember `PR_NUMBER`. Later `gh pr view` must use `gh pr view ${PR_NUMBER}`.

### Create or reuse

Do **not** hand-roll `git worktree add`. Skip create only if cwd is already a matching `*-quick-*` worktree. If path already exists: **reuse**. If reusing and **clean**, fetch+reset to latest. If **dirty**, do not `reset --hard`.

### Yarn (always)

```bash
(cd "<path>" && yarn install)
```

Reuse / already-isolated: **always** run this. Wait for exit 0.

### Move the session, then work

OpenCode: `tools.opencode.session_move` with `directory` = absolute worktree path. Continue this session. Then **immediately** continue. Do **not** destroy the worktree when finished.

---

## Phase 1: Resolve Scope

### 1.1 Inputs

| Argument | Behavior |
|----------|----------|
| (none) | Current branch vs merge-base with origin default branch |
| branch name | Diff that branch vs its merge-base with origin default (or vs current if user asked to compare) |
| `pr` | Open PR for current branch via `gh pr view` |
| PR number | That PR's head vs base |

### 1.2 Gather context (run in parallel)

```bash
git branch --show-current
git remote show origin | grep 'HEAD branch' | awk '{print $NF}'
git merge-base HEAD origin/main   # or origin/master / detected default
git diff --name-only $(git merge-base HEAD origin/<base>)..HEAD
git diff --stat $(git merge-base HEAD origin/<base>)..HEAD
git diff $(git merge-base HEAD origin/<base>)..HEAD
```

If PR mode:

```bash
gh pr view --json number,url,title,baseRefName,headRefName,files
# or: gh pr view <n> --json ...
```

Prefer the PR's `baseRefName` as base when in PR mode.

### 1.3 Changed type-bearing files

Focus on:

- `*.ts`, `*.tsx`, `*.d.ts`
- Schema sources the branch touches: `**/schema.prisma`, Zod schemas, GraphQL SDL, OpenAPI, tRPC routers
- Generated types only if the branch **owns** the generator input (fix the source of truth, then regenerate if the repo has a standard command)

Skip pure assets, lockfiles, migrations SQL (unless types/enums are defined there), and docs unless they embed type contracts.

### 1.4 Stop conditions

| Condition | Action |
|-----------|--------|
| Empty diff | Stop: nothing to harden |
| No TS/schema files in diff | Stop: report no type-bearing changes |
| Cannot detect base | Ask user for base branch |

---

## Phase 2: Inventory Soft Types

Scan **only changed files** (and new symbols they introduce). Read full files when the diff is incomplete context — types often live above the hunk.

### 2.1 Soft-type smells (flag all of these)

| Smell | Examples |
|-------|----------|
| Explicit `any` | `any`, `Array<any>`, `Record<string, any>`, Promise&lt;any&gt; |
| Type erasure | `as any`, `as unknown as T`, double casts, `// @ts-ignore`, unjustified `@ts-expect-error` |
| Lazy non-null | `foo!` used to silence rather than prove presence |
| Unnecessary nullish | `T \| null`, `T \| undefined`, `T \| null \| undefined` when domain always has `T` after success |
| Fake optionals | `foo?: Bar` / `foo: Bar \| undefined` when always required in this flow |
| `Partial` abuse | `Partial<Entity>` for fully loaded entities or API responses |
| Loose bags | `object`, `{}`, `Record<string, unknown>` deep in domain (OK only at raw boundaries before parse) |
| Un-narrowed `unknown` | `unknown` returned or stored without a type guard / schema parse |
| Over-wide primitives | `string` for closed enums/statuses; `number` for fixed unions |
| Soft JSON | `JSON.parse` result used without schema; `any` from HTTP clients |
| Soft returns | Functions returning `T \| undefined` when miss should throw / Result-error |
| Soft params | Optional params added "so call sites compile" |
| Soft Prisma usage | Selecting fewer fields then defaulting; ignoring generated nullability incorrectly |
| Soft React props | Optional props that parent always passes; `children?:` when required by layout |

### 2.2 Search patterns (run over the changed file list)

```bash
# any / casts / ignores (adjust paths to changed files)
rg -n '\bany\b|as any|as unknown as|@ts-ignore|@ts-expect-error' --glob '*.ts' --glob '*.tsx' <files>

# nullish / optional-heavy annotations in the diff
rg -n '\|\s*null|\|\s*undefined|\?:|Partial<|Record<string,\s*(any|unknown)>' --glob '*.ts' --glob '*.tsx' <files>
```

Also read the full diff for newly introduced soft types that regex might miss (inferred `any` from untyped params, missing return types that become soft, etc.).

### 2.3 Build the inventory table

For each finding:

| Field | Content |
|-------|---------|
| File:line | Location |
| Soft form | Current annotation / inference |
| Symbol | Function, field, prop, generic |
| Why soft | any / nullish / Partial / … |
| Suspected hard type | Best guess before schema pass |
| Boundary? | Is this an I/O boundary (HTTP, env, DB raw, form)? |

---

## Phase 3: Ground Truth (Schema & Contracts)

For **each** inventory item, determine the real hard shape. Do not guess from local convenience.

### 3.1 Lookup order (stop when definitive)

1. **Database / Prisma** — model fields, `?` nullability, enums, relations in `schema.prisma` (and related generators)
2. **Validation schemas** — Zod / Yup / class-validator / custom parsers colocated with the API
3. **API contracts** — tRPC procedures, OpenAPI, GraphQL, shared DTO packages
4. **Domain types** — existing entities in `libs/**`, branded types, event payloads
5. **Auth / session** — what is guaranteed after middleware (e.g. `orgId` always present when authenticated)
6. **Call graph on this branch** — who constructs the value; what is proven after a successful path

### 3.2 Nullability rules

| Reality | Hard type |
|---------|-----------|
| Column/field required in DB + always selected | `T` (not `T \| null`) |
| Column nullable in DB | `T \| null` at the **DB/result** layer only |
| Lookup may miss | `T \| null` or `Result` **at the lookup**; after guard/throw, inner type is `T` |
| Authenticated context field always set | required on `AuthenticatedSession` (not optional on a generic session) |
| Form draft vs submitted entity | **Two types**: `DraftX` (soft) vs `X` (hard) — never one soft type for both |
| JSON column with known shape | parse to exact interface; do not leave as `Prisma.JsonValue` in domain |

### 3.3 Boundaries vs core

- **Boundaries** (HTTP body, query, env, `JSON.parse`, third-party SDK): may start as `unknown` / soft → **must parse once** into a hard type.
- **Core domain / UI after load**: only hard types. No `any`, no cascading `?.` / `??` for required invariants.

If a soft type exists only so a boundary can be lazy, introduce:

```ts
// boundary
function parseInput(raw: unknown): HardInput { /* zod/schema; throw on fail */ }

// core
function handle(input: HardInput): HardResult { /* no nullish soup */ }
```

---

## Phase 4: Plan Hard Types

Before editing, produce a short plan (user-visible for large PRs; silent for tiny ones).

For each finding:

1. **Exact hard type** — field-by-field if needed (`{ id: string; email: string }`, `LoanStatus`, `AuthenticatedSession`, …)
2. **Where defined** — existing type to reuse vs new named type (prefer reuse)
3. **Where to narrow** — single validation boundary
4. **Call-site impact** — files that must drop `??`, `?.`, `!`, `as any`, or optional chaining
5. **Intentional soft?** — only if product truly allows absence (document why)

### 4.1 Forbidden "fixes"

Never ship any of these as the solution:

- `any`, `as any`, `as unknown as T` without a real refine
- Widening to `string | number | boolean | null | undefined` to silence errors
- Making more fields optional so call sites compile
- Blanket `!` without a proven invariant
- `@ts-ignore` / empty `@ts-expect-error`
- Replacing hard errors with `?? default` for required data

### 4.2 Preferred patterns

| Situation | Pattern |
|-----------|---------|
| Resource may be missing | `findX(): Promise<X \| null>` then `if (!x) throw/404`; later `X` |
| Create vs entity | `CreateXInput` vs `X` |
| Patch endpoint | `PatchX` / `Partial<Pick<X, ...>>` **only** at patch boundary |
| Status / kind fields | string literal unions or enums matching DB enum |
| Lists that are never null | `T[]` (empty array OK); not `T[] \| null` unless API distinguishes |
| Errors | throw or discriminated union `{ ok: true; data: T } \| { ok: false; error: E }` — not silent empty success |

---

## Phase 5: Apply Type Fixes

Edit in this order to reduce thrash:

1. **Schema / shared contracts** (Prisma enum usage, Zod, shared DTO packages the branch already touches)
2. **Domain type definitions** (interfaces, types, branded IDs)
3. **Function signatures** (params + return types explicit and hard)
4. **Component props** (required vs optional aligned with real usage)

### 5.1 Mechanics

- Prefer **named types** over large inline unions repeated everywhere.
- Match existing project conventions (type vs interface, Zod inference `z.infer<typeof Schema>`, Prisma generated types).
- If Prisma nullability is wrong relative to DB, **do not lie in TS** — fix schema/migration only if the branch already owns that concern; otherwise type the query result honestly and narrow.
- Remove redundant optional markers when the parent type is only used post-validation.

### 5.2 Generated clients

If the monorepo uses Prisma/GraphQL codegen:

- Change the **source** (schema, zod, openapi).
- Run the repo's standard generate command only when needed (`yarn prisma:sync`, project-specific codegen, etc.).
- Do not hand-edit generated files.

---

## Phase 6: Fix Call Sites & Runtime

Hard types will surface real errors — that is the point. Fix them properly.

### 6.1 Replace soft runtime patterns

| Before (soft) | After (hard) |
|---------------|--------------|
| `user?.orgId ?? ''` | Ensure `user: AuthenticatedUser` with `orgId: string`; use `user.orgId` |
| `as SomeType` | Parse/validate or fix the producer type |
| `data: any` from fetch | Typed client / zod parse of response |
| `fn(x?: T)` | `fn(x: T)` + fix callers |
| `return null` on impossible branch | `throw new Error(...)` or exhaustive `never` check |
| `Partial<User>` state for full form | `UserFormState` with explicit optional draft fields only where needed |

### 6.2 Exhaustiveness

- Prefer `switch` on unions with a `default: const _exhaustive: never = x` pattern where the codebase already uses it.
- Do not add `default` that swallows new enum values silently unless product requires it.

### 6.3 Tests

Update tests in the branch that relied on soft types:

- Fixtures must satisfy hard types (full objects, not partials — unless testing the draft path).
- Add/adjust tests that invalid boundary input **rejects**, not soft-succeeds.

---

## Phase 7: Verify

### 7.1 Typecheck affected projects

Prefer Nx (per monorepo Agents.md):

```bash
# Identify projects from changed paths, then:
yarn nx run-many -t typecheck -p <projects>
# or project-specific: yarn nx run web-crm:typecheck / tsc -p ...
```

If no typecheck target, use the package's `tsc --noEmit` / existing CI script.

### 7.2 Loop

While type errors remain that were caused by this hardening:

1. Classify: still-soft type vs real logic bug vs intentional optional
2. Fix hard (never re-introduce `any` to green the build)
3. Re-run typecheck

### 7.3 Lint (optional but recommended)

If eslint has `@typescript-eslint/no-explicit-any` or similar, ensure changed files are clean.

Stop looping if the only remaining errors are **pre-existing on base** and untouched by this skill — note them in the report, do not boil the ocean.

---

## Phase 8: Report

```markdown
## fix-types Report

**Scope**: [branch / PR #] vs [base]
**Files scanned**: [N type-bearing]
**Soft types found**: [N]
**Hardened**: [N]
**Intentional soft left**: [N]
**Call sites updated**: [N]
**Typecheck**: [pass / pass with notes / blocked]

### Hardened

| File | Before | After | Ground truth |
|------|--------|-------|--------------|
| path:line | `orgId?: string` | `orgId: string` on `AuthenticatedSession` | auth middleware always sets org |

### Call-site / runtime fixes

| File | Change |
|------|--------|
| path | Removed `?? ''`; throw if session missing org at boundary |

### Intentional soft types (kept)

| File | Type | Why allowed |
|------|------|-------------|
| path | `deletedAt: Date \| null` | Nullable column; soft-delete |

### Skipped / out of scope

| Item | Reason |
|------|--------|
| Unrelated package soft types | Outside PR diff |

### Follow-ups (if any)

- [ ] e.g. regenerate Prisma client in CI
- [ ] e.g. product decision needed on optional field X
```

---

## Severity / Priority When Triaging

Work in this order:

1. **`any` / type erasure** — always fix
2. **Required domain fields typed optional/nullish** — fix + call sites
3. **Partial / loose records in domain** — replace with exact types
4. **Over-wide string/number** — literal unions / enums
5. **Missing explicit return types** that hide soft inference — add hard returns
6. **Cosmetic** — only if they affect safety

If the PR is huge, fix all `any` + required-nullish first, then continue until typecheck is clean or user stops.

---

## Interaction Rules

1. **Don't ask permission for routine hardening** inside the PR scope (`any` → exact type, remove bogus `\| undefined`, fix call sites).
2. **Do ask** when hardening would change external API contracts, public package exports, or DB schema nullability — present the proposed hard type and wait.
3. **Do ask** when product intent for null vs missing is unclear (e.g. is "no avatar" `null`, omit field, or empty string?).
4. **Never expand scope** into drive-by refactors unrelated to types on this branch.
5. **Align with monorepo rules** — use Nx targets; respect existing validation libraries; no hand-edit of generated clients.

---

## Error Handling

| Error | Action |
|-------|--------|
| No PR and empty/unclear branch diff | Stop and explain |
| Schema file missing / can't find ground truth | Read producers/consumers; if still ambiguous, ask user with options |
| Typecheck target fails for unrelated reasons | Isolate errors from this change; fix only ours; report the rest |
| Hardening breaks a public API the branch didn't mean to change | Revert that surface; propose a follow-up or versioned type |
| User wants one file only | Limit inventory + fixes to that path |

---

## Important Rules

1. **Hard definition of what can be expected** — that is the bar for almost every type.
2. **Rarely** keep `any`, `undefined`, or `null`; when kept, document why in the report.
3. **Schema and contracts win** over local convenience.
4. **Fix the code around the type** so the branch is correctly hard end-to-end.
5. **Never green the build by softening types.**
6. **Never fabricate schema facts** — open the Prisma/Zod/API source.
7. **PR/branch scoped** — leave the rest of the monorepo alone.
8. **Boundary parse once** — core code trusts hard types.
9. **Two types over one soft type** when lifecycle differs (draft vs saved, raw vs parsed, anonymous vs authenticated).
10. **Report clearly** so the user can review intentional soft leftovers.
11. **Always isolate in a code-only worktree first** (Phase 0). **Yarn install is mandatory** on every worktree (create, reuse, already-isolated). Never skip yarn because `node_modules` exists.

User arguments: $ARGUMENTS
````

#### `~/.ai/commands/gepeto.md`

```markdown file=~/.ai/commands/gepeto.md
---
description: Guide for building 1-click launchers and building apps with launchers built-in using Pinokio
---

Load the "gepeto" skill with the skill tool, then follow it exactly.

User arguments: $ARGUMENTS
```

#### `~/.ai/commands/grill-me.md`

````markdown file=~/.ai/commands/grill-me.md
---
description: Relentless interview that sharpens a plan until every design-tree branch is resolved. Use when user says "/grill-me", "grill me", or "stress-test this plan".
---

# /grill-me

Interview the user relentlessly until you reach a shared understanding. Map this as a **design tree**: every decision branches into the decisions that hang off it.

Topic: `$ARGUMENTS` (or the current conversation if arguments are empty). Do **not** implement, spec, or ticket anything until the user confirms shared understanding.

## Rounds and the frontier

Work the tree in **rounds**. The **frontier** is every decision whose prerequisites are already settled: the questions you can ask *now* without guessing at answers you have not heard yet.

Ask the **whole frontier** in one round. Number each question and give your recommended answer. Then **wait** for the user's answers before the next round.

A question whose answer depends on another question still open in this round belongs to a *later* round, not this one.

Each round the user answers reshapes the tree: settled decisions push the frontier outward and unblock questions that depended on them. Recompute the frontier and ask the next round.

## Round format

Use this markdown in the conversation. Do **not** use the structured Question tool — design questions need paragraphs and a recommended answer.

```
❓ **Q1** - **<question title>**: <question body, might be multiple paragraphs, including multiple choices>

➡️ <your recommended answer>

---

❓ **Q2** - **<question title>**: <question body, might be multiple paragraphs, including multiple choices>

➡️ <your recommended answer>
```

## Facts vs decisions

Finding **facts** is your job, never the user's. When a frontier question needs a fact from the environment (filesystem, git, code, docs), dispatch a sub-agent to find it; don't ask the user for anything you could look up yourself. Don't block on it: a running exploration is an unsettled prerequisite, so only the questions downstream of it wait for the sub-agent to report; ask the rest of the frontier now.

The **decisions** are the user's: put each to them and wait.

## Done

The session is done when the frontier is empty: every branch of the design tree visited, nothing left silently assumed.

Then:

1. Restate the settled tree in a short recap (decisions + rejected alternatives).
2. Wait for the user to confirm shared understanding.
3. Do **not** act on it until they confirm. After confirm, stop unless they ask to implement (`/peer-review`, `/implement-as-stack`, `/pr`, etc.).

User arguments: $ARGUMENTS
````

#### `~/.ai/commands/imagine.md`

```markdown file=~/.ai/commands/imagine.md
---
description: How to use the image_gen and image_edit tool calls in Grok Build: when to build a visual with code instead of generating it, prompt-craft, reference-first handling of real people, factual...
---

Load the "imagine" skill with the skill tool, then follow it exactly.

User arguments: $ARGUMENTS
```

#### `~/.ai/commands/in-my-voice.md`

```markdown file=~/.ai/commands/in-my-voice.md
---
description: Rewrite a text block as a hard caricature of Martin's LinkedIn voice. Use when user runs /in-my-voice or pastes draft copy to restyle.
---

# /in-my-voice

Rewrite the user's input as a LinkedIn post in **Martin's voice**, dialed up to a **hard caricature**. Do not soften. Do not generic-LinkedIn-ify. Emulate the posts below so hard it almost parodies them while still sounding like a real human who ships.

## Input

User arguments (the draft to rewrite):

$ARGUMENTS

If `$ARGUMENTS` is empty, ask once for the text block. Then rewrite. Do not chat first.

## Output rules

1. Output **only** the rewritten post. No preamble, no "here's the rewrite", no analysis, no alternatives unless asked.
2. Preserve the user's facts, links, metrics, product names, and claims. Do not invent metrics, employers, or results.
3. You may invent **rhetorical structure**, hooks, reframes, and closing questions. Not biography.
4. Length: usually 120–280 words. Shorter for OTW blurbs. Longer only if the source is dense build-log material.
5. Hashtags: only if the draft is clearly open-to-work or the user included them. Match their tag style: `hashtag#Tag` lines at the end, 4–6 max. Otherwise omit.
6. Emoji: rare. `🚨` only for multi-incident news openers. No 🚀 💪 🔥 walls.
7. No em-dash addiction. Prefer periods, colons, and short sentences. Occasional comma or semicolon is fine. Em dashes sparingly if at all.
8. No corporate sludge: "excited to share", "thrilled", "leveraging", "delve", "landscape", "robust", "seamless", "game-changer", "I'm humbled".
9. No fake vulnerability essays. Confidence with receipts. Curiosity at the end.

---

## Voice DNA (caricature dial: 11)

### Opening hook (always)

Lead with a **short, slightly wrong-sounding or counterintuitive line**. Then a staccato punch.

Patterns to steal:

- Claim. Not a little. Fundamentally.
- I built X, and its best feature is Y. (Y is the opposite of what demos show)
- I started X this week. There's no X yet.
- Every fresh session starts with total amnesia.
- X has a cruel timing problem, and I think about it constantly.
- So believe me when I say this: [uncomfortable industry claim].
- Here's the strange place [field] is in right now:
- [Person] said X. Then they said the opposite. I think that's kind of a big deal?

First line does the work. No throat-clearing.

### The reframe (the signature move)

After the hook, kill the obvious read:

- "Here's the thing most people miss:"
- "Here's what most people miss:"
- "The usual read is X. I think that's only half the story."
- "The failures aren't the story. The detection is."
- "It's not that the models don't know X. It's that X lives in the gap between..."
- "What's actually happening is..."

Name the lazy narrative. Replace it with a sharper one. This is non-negotiable in the caricature.

### Proof with dirt under the nails

Then get specific. Prefer:

- Concrete stack: Next.js, TypeScript, pgvector, Claude, local models vs cloud
- Named behaviors: refusals scored in CI, hit@5, MRR, kill switch, hash-diffed re-syncs
- Process truths: eval harness gates PRs, docs the agent must re-read, intentionally broken test messages
- Honest limits: "I don't have a clean answer", "least impressive robot ever", "honesty-boundaries doc"

Judgment > output. Taste. Evals. Documentation an amnesiac expert can execute. Encoding intent so the code is obvious.

### Sentence music

- Mix one-word-punch fragments with longer analytical sentences.
- "Not X. Y."
- "Not fewer engineering jobs. A different job."
- "Refusals aren't a failure mode here. They're a scored behavior."
- "The demo looks perfect. Ship it." (as the thing you're attacking)
- "Wrong state with a quiet success is worse than a loud failure" energy without quoting that line.
- Parenthetical asides used lightly.
- Questions that are actually questions, not engagement bait cosplay — but yes, end with one.

### Closing

Almost always:

1. One-line uncomfortable takeaway or "real shift"
2. A genuine peer question ("What's your X look like?", "What did building Y teach you that the tutorials didn't?", "Are you building now or timing the curve?")

OTW posts: clear ask, stack, clearance if relevant, DMs/referrals, hashtags. Still hook-first when possible ("Anyone else have LinkedIn fatigue?").

### Thematic obsessions (lean into these when the draft touches them)

- AI fails at intent / completeness / follow-through, not typing code
- Evals are the product; shipping on vibes is the enemy
- Refusal and hard boundaries as features
- Accessibility debt at industrial scale; checklists models can't charm past
- Repo memory beats model memory (filing cabinet / constitution)
- One brain, many bodies / orchestration is the product
- Design eng = encoding intent; Figma/spec quality mirrors output quality
- Mid-career value = taste + shipping with AI, not alongside it
- Build in public with decision logs and rejected alternatives
- Respect people who admit they were wrong out loud

### Caricature amplifiers (use freely)

Turn these knobs up past polite:

- One killer reframe per post, stated like it's obvious once said
- At least one staccato triplet or double period punch early
- At least one "most people miss" / "usual read is wrong" move
- Specificity theater: name the boring mechanism (deterministic chunk IDs, commands that expire if late, rubric item that scores refusal)
- End on craft identity, not hype
- Sound like someone who grades agents for a living and builds robots on weekends — because that is the bit

### Anti-patterns (never)

- LinkedIn-bro swagger or guru thread energy
- "5 things I learned" listicles unless the source is already a list
- Starting with "I'm excited to announce"
- Apologetic soft openers
- Over-explaining the joke
- Hashtag stuffing on thought posts
- Emoji bullet salads
- Sounding like ChatGPT wearing a flannel

---

## Worked style fragments (internal reference — do not paste these back)

Hook + punch:

> Connecting Claude Code to Figma changed how I ship UI. Not a little. Fundamentally.

Reframe:

> Here's the thing most people miss: AI coding tools don't fail because they can't write code. They fail because they're guessing at intent.

Inversion feature:

> I built a chatbot, and its best feature is refusing to answer.

Process as product:

> Evals aren't a checkbox anymore. They're the product.

Uncomfortable takeaway:

> The skill that actually determines your output quality with coding agents isn't prompting. It's writing documentation an amnesiac expert can execute perfectly.

Respect + understatement:

> I think that's kind of a big deal? Not because of who was right, but because he had to eat the earlier tweet to say it.

Build-log honesty:

> I started building a robot this week. There's no robot yet.

Industry knife:

> We are shipping accessibility debt at industrial scale.

---

## Mode selection

Infer from the draft:

| Draft smells like | Mode |
|---|---|
| Shipping a project, metrics, repo, demo link | **Build log** — hook on the surprising feature, evals/process pride, try-it CTA + craft question |
| Hot take on AI/hiring/tools/news | **Thesis** — hook, kill usual read, reframe, light proof, uncomfortable takeaway, peer question |
| Robot / physical AI / side project | **Workshop** — slightly wry, systems lesson, day-job transfer, glue-on-desk energy |
| Open to work / role search | **OTW** — human, direct, receipts (years, stack, clearance, 508 record if present), clear ask, hashtags |
| Agency / studio / accessibility pitch | **Studio** — market math opener, proof, what you build, link in comments energy |
| Short gripe / fatigue | **Blade** — keep it short, one cut, then the pitch if present |

If mixed, prefer **Thesis** skeleton with **Build log** specifics.

---

## Procedure

1. Read the draft. Extract: core claim, proof points, must-keep facts/links, mode.
2. Write a new hook that could only open this post.
3. Plant the reframe.
4. Fold proof in as lived detail, not a resume dump (unless OTW).
5. Land the takeaway + question (or OTW ask).
6. Read once as caricature check: if it could be anyone's post, punch harder. If it invents facts, strip them.
7. Output the post only.

## Optional flags in $ARGUMENTS

If the user prefixes with a flag, honor it:

- `tight:` — under ~100 words
- `otw:` — force open-to-work mode
- `thesis:` — force take mode
- `build:` — force build-log mode
- `wild:` — maximum caricature (even punchier hooks, harder reframes)

Strip the flag from the content before rewriting.
```

#### `~/.ai/commands/monorepo-worktree.md`

````markdown file=~/.ai/commands/monorepo-worktree.md
---
description: Create or destroy an isolated git worktree of the Future Mortgage monorepo that runs front-end and back-end on alternate ports (own Postgres DB + Redis DB index) so multiple full stacks can run at once. Remaining args after create are a follow-on coding task — do that immediately in the worktree, do not stop after setup. Use when the user runs /monorepo-worktree, /monorepo-worktree destroy|remove|teardown, asks to "spin up a worktree", "run a second stack", "parallel monorepo", "worktree on new ports", or needs a second seeded local environment without stopping the primary checkout. Do NOT use for a code-only PR/branch checkout — that is /worktree-quick.
---

# /monorepo-worktree

Create **or destroy** a parallel monorepo checkout that coexists with the primary
stack (`:3000` / `:3001` / `:4201`).

Code-only PR/branch checkout (no env/DB/seed): `/worktree-quick`.

User arguments: `$ARGUMENTS`

## Commands

| User says | Action |
|-----------|--------|
| `/monorepo-worktree` / `create` / `setup` | Create + seed + report how to serve |
| `/monorepo-worktree <task>` | Create (defaults) then **immediately do the task** in the worktree |
| `/monorepo-worktree destroy` / `remove` / `teardown` / `rm` | Stop processes, drop DB, remove worktree |
| `/monorepo-worktree list` | Show worktrees, slots, ports, what is listening |

## Parse `$ARGUMENTS` — then do not stall

Classify the first tokens, leftover text is the **follow-on task**:

| Pattern | Action |
|---------|--------|
| `destroy` / `remove` / `teardown` / `rm` … | Destroy. No create. No coding task. |
| `list` | List only. |
| `create` / `setup` (optional), optional slot int, optional git ref, optional name, **rest** | Create. `rest` is the task. |
| Anything else (multi-word, or a single non-verb token) | Create with defaults, whole string is the task. |

Examples:

- `implement fees page polish` → slot `1`, ref `HEAD`, name slug from task, then implement that
- `2 feature/foo my-feature fix login OTP` → slot 2, that ref/name, task `fix login OTP`
- (empty) → create slot 1, report URLs, **stop**

Defaults when unspecified: slot `1`, ref `HEAD`, name `slot-1` **or** a `[a-z0-9-]{1,32}` slug from the task. **Do not ask** for slot/branch/name. Ask only if the chosen slot’s ports are busy (then next free slot ≥1) or a destroy target is ambiguous.

### Model split (Claude Code)

- **You** (session model) parse `$ARGUMENTS` into slot / ref / name / task.
- **Haiku subagent** (Agent tool, `model: "haiku"`) does the mechanical part: port check, `setup-worktree.sh`, or the whole `destroy` / `list`. Tell it to follow `~/.ai/commands/monorepo-worktree.md` with the parsed slot/ref/name, and to return worktree path, slot, ports/URLs, and exit status (or the last ~50 lines of output on failure). It does not edit code or improvise around a failed step.
- **You** then start `./serve-worktree.sh` in the background (your session owns that process) and do the follow-on task. On subagent failure, diagnose it yourself; don't blindly re-delegate.

If you **are** that subagent, skip this section and run the steps directly — do not delegate again.

### HARD RULE: setup is a prefix, not the job

If a follow-on task exists, **you (this same session) start it the moment the setup subagent reports `setup-worktree.sh` exited 0.**

After setup succeeds:

1. Start `./serve-worktree.sh` **background only** (`background: true` / do not wait for exit). Never foreground. Coding does not depend on serve.
2. Optional health check: poll API **≤90s**, then continue even if still warming. Never poll forever.
3. `cd` to the worktree path. **Immediately implement the task.** All edits / git / yarn / nx happen in `$WT`, not the primary checkout.
4. One-line URL/path note is fine. Then keep working.

**Forbidden** when a follow-on task exists:

- Ending the turn after create with only URLs, credentials, or a destroy command
- Asking “want me to start on X?” / “should I continue?”
- Asking for slot, branch, or name
- Spawning a subagent for the task and then idling
- Waiting on `serve-worktree.sh`, webpack compile, or health as if that were the deliverable

## Default ports (primary = slot 0)

| Service    | Primary | Slot 1 | Slot 2 | Slot N        |
|------------|---------|--------|--------|---------------|
| web-crm    | 3000    | 3100   | 3200   | 3000 + N×100  |
| server-crm | 3001    | 3101   | 3201   | 3001 + N×100  |
| web-funnel | 4201    | 4301   | 4401   | 4201 + N×100  |
| Postgres   | dbname  | dbname_wt1 | dbname_wt2 | dbname_wtN |
| Redis DB # | 0       | 1      | 2      | N             |
| Cookie     | auth-token | auth-token-wt1 | … | auth-token-wtN |
| Node inspect | 9229  | 9230   | 9231   | 9229 + N      |

CRM URL for slot N: `http://fm.futurewholesale.local:{WEB_PORT}`

---

## Create (setup)

### When to use

- User wants a second (or third) local stack while primary is already running
- Feature work that needs a clean seeded DB without touching primary data
- Side-by-side UI comparison across branches

### Prerequisites

1. Primary monorepo has working `.env` + `.env.local` (source of secrets)
2. Docker containers running: `future-mortgage-postgres`, `future-mortgage-redis`
3. Hosts file already has tenant subdomains (same as primary):
   `127.0.0.1 fm.futurewholesale.local` (and other tenants as needed)
4. Slot ports are free (`lsof -nP -iTCP:3100 -sTCP:LISTEN` etc.)

### Fast path (preferred)

From inside the **primary** monorepo (or any of its worktrees). Skill is
**user-scoped** at `~/.ai/oc_skills/monorepo-worktree/` (not in the repo).

```bash
# Slot 1 from current HEAD, name "slot-1"
~/.ai/oc_skills/monorepo-worktree/scripts/setup-worktree.sh 1

# Slot 2 from a branch, custom name
~/.ai/oc_skills/monorepo-worktree/scripts/setup-worktree.sh 2 feature/foo my-feature

# Or pin the repo explicitly:
MONOREPO_ROOT=/path/to/monorepo ~/.ai/oc_skills/monorepo-worktree/scripts/setup-worktree.sh 1
```

Script will:

1. `git worktree add` under `../worktrees/monorepo-<name>`
2. Copy env files from primary
3. Create Postgres DB `dbname_wt{N}`
4. Rewrite port / DB / Redis / cookie / FRONTEND_URL values
5. Patch webpack + vite + `web-crm` project.json for env-aware ports (worktree-local)
6. `yarn install` (own `node_modules`; husky postinstall wires pre-push; do not skip yarn; do not symlink from primary) → `yarn prisma:sync` → `yarn nx run database:seed`
7. Write `serve-worktree.sh` and `.worktree-slot` marker

Then start **in the background** (never wait for this process to exit):

```bash
cd ../worktrees/monorepo-slot-1   # or the path printed by the script
./serve-worktree.sh
```

If a follow-on task exists, start serve in background and **begin the task immediately**. Do not wait for compile/health.

Verify:

```bash
curl -s http://localhost:3101/health   # slot 1 API
curl -s -o /dev/null -w "%{http_code}\n" http://localhost:3100/
curl -s -o /dev/null -w "%{http_code}\n" http://localhost:4301/apply/
# Primary must still be up:
curl -s http://localhost:3001/health
```

### Agent checklist — create

1. **Parse** `$ARGUMENTS` (see above). Do **not** ask for slot/branch/name — default them.
2. **Confirm** target slot ports are free (`lsof` / curl). If busy, use the next free slot ≥1.
3. **Run** `~/.ai/oc_skills/monorepo-worktree/scripts/setup-worktree.sh` (preferred) **or** the manual steps below — via the Haiku subagent (steps 2–3; see Model split).
4. **Start** `./serve-worktree.sh` in the worktree **in the background**. Never foreground. Never wait for exit.
5. **Health** (optional, ≤90s): new API port + primary `:3001` still responds. On timeout, continue.
6. **No follow-on task:** report URLs, credentials, path, destroy command, **stop**.
7. **Follow-on task:** one-line path + URLs, then **immediately implement the task in `$WT`** (this session, not a subagent). Do not stop. Do not ask.

### Credentials (same as primary after seed)

| Role  | Email | Password | OTP |
|-------|-------|----------|-----|
| Dev   | `martin.hansen@trygenius.ai` | `admin123` | `1111` |
| Admin | `admin@fm.com` | `admin123` | `1111` |

Tenant CRM: `http://fm.futurewholesale.local:{WEB_PORT}`

---

## Destroy / remove / teardown

Use when the user says any of: `destroy`, `remove`, `teardown`, `rm`, `clean up worktree`,
`kill the worktree stack`, `shut down slot N`.

### Fast path (preferred)

From inside the monorepo (or set `MONOREPO_ROOT`). Scripts live at
`~/.ai/oc_skills/monorepo-worktree/scripts/`.

```bash
# List what exists (no changes)
~/.ai/oc_skills/monorepo-worktree/scripts/destroy-worktree.sh list

# Destroy slot 1 (stops ports, flushes redis DB 1, drops dbname_wt1, removes worktree + branch)
~/.ai/oc_skills/monorepo-worktree/scripts/destroy-worktree.sh destroy 1 --yes

# Same aliases
~/.ai/oc_skills/monorepo-worktree/scripts/destroy-worktree.sh remove 1 --yes
~/.ai/oc_skills/monorepo-worktree/scripts/destroy-worktree.sh teardown --name slot-1 --yes
~/.ai/oc_skills/monorepo-worktree/scripts/destroy-worktree.sh --path ../worktrees/monorepo-slot-1 --yes

# Destroy every monorepo-* under ../worktrees/
~/.ai/oc_skills/monorepo-worktree/scripts/destroy-worktree.sh --all --yes
```

### Flags

| Flag | Effect |
|------|--------|
| `--yes` / `-y` | Required in non-interactive agent shells; skip prompt |
| `--force` | `git worktree remove --force` (discard dirty worktree files) |
| `--keep-db` | Do not `DROP DATABASE dbname_wtN` |
| `--keep-branch` | Do not delete `worktree/<name>` branch |
| `--keep-redis` | Do not `FLUSHDB` on the slot's Redis logical DB |

Default destroy is **full cleanup**: stop processes + flush redis slot + drop DB + remove worktree dir + delete `worktree/*` branch.

### Destroy order (script guarantees this order)

1. **Resolve target(s)** from slot / name / path / `--all` using `.worktree-slot` marker when present
2. **Safety checks** (refuse primary path, primary ports, primary DB name `dbname`)
3. **Stop listeners** on worktree ports only (`WEB` / `API` / `FUNNEL` / inspect)
4. **Best-effort kill** node/yarn/nx processes whose cwd is under the worktree (covers parent `nx run-many`)
5. **Redis** `FLUSHDB` on logical DB `N` (slot index) — not DB 0
6. **Postgres** terminate backends on `dbname_wtN`, then `DROP DATABASE`
7. **`git worktree remove`** (retry with `--force` if needed; prune)
8. **Delete local branch** `worktree/<name>` if it exists and is not checked out elsewhere
9. **Verify** primary ports untouched; print remaining `git worktree list`

### Hard safety rules (never violate)

- **Never** kill ports `3000`, `3001`, `4201` (primary stack)
- **Never** `DROP DATABASE dbname` (only `dbname_wt[1-9]…`)
- **Never** remove the primary monorepo checkout path
- **Never** flush Redis logical DB `0`
- If `.worktree-slot` is missing, still allow destroy when path is under `../worktrees/monorepo-*` and ports can be inferred from slot name `slot-N`

### Agent checklist — destroy

1. **Parse intent**: `destroy` / `remove` / `teardown` / `list`.
2. **Identify target**: slot number, name, path, or `--all`. If ambiguous, run `list` and ask.
3. **If user has uncommitted feature work** only in that worktree: warn and prefer `--keep-branch` or confirm `--force`.
4. **Run** `~/.ai/oc_skills/monorepo-worktree/scripts/destroy-worktree.sh … --yes` (agents are non-interactive).
5. **Verify**:
   - Worktree ports no longer listening
   - `git worktree list` no longer shows the path
   - `dbname_wtN` gone (unless `--keep-db`)
   - Primary `:3001/health` still OK if primary was running
6. **Report** what was stopped, dropped, and removed.

### Manual destroy (if script unavailable)

```bash
PRIMARY="$(git rev-parse --show-toplevel)"
# if already inside a worktree, use git common dir:
# PRIMARY="$(dirname "$(git rev-parse --path-format=absolute --git-common-dir)")"
WT="$(dirname "$PRIMARY")/worktrees/monorepo-slot-1"
SLOT=1
WEB=$((3000 + SLOT*100)); API=$((3001 + SLOT*100)); FUNNEL=$((4201 + SLOT*100))
DB="dbname_wt${SLOT}"

# 1) Stop serve processes on worktree ports ONLY
for p in $WEB $API $FUNNEL; do
  lsof -nP -iTCP:$p -sTCP:LISTEN -t | xargs -r kill -TERM 2>/dev/null || true
done
sleep 1
for p in $WEB $API $FUNNEL; do
  lsof -nP -iTCP:$p -sTCP:LISTEN -t | xargs -r kill -KILL 2>/dev/null || true
done

# 2) Flush redis logical DB for slot (not 0)
docker exec future-mortgage-redis redis-cli -n "$SLOT" FLUSHDB

# 3) Drop isolated DB only
docker exec -e PGPASSWORD=dbpassword future-mortgage-postgres \
  psql -U dbuser -d postgres -c \
  "SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname='${DB}' AND pid<>pg_backend_pid();"
docker exec -e PGPASSWORD=dbpassword future-mortgage-postgres \
  psql -U dbuser -d postgres -c "DROP DATABASE IF EXISTS ${DB};"

# 4) Remove worktree + branch
git -C "$PRIMARY" worktree remove --force "$WT" || {
  rm -rf "$WT"
  git -C "$PRIMARY" worktree prune
}
git -C "$PRIMARY" branch -D "worktree/slot-${SLOT}" 2>/dev/null || true

# 5) Confirm primary still up
curl -s http://localhost:3001/health || true
git -C "$PRIMARY" worktree list
```

---

## Manual create process (if setup script unavailable)

### 1. Create worktree

```bash
PRIMARY="$(git rev-parse --show-toplevel)"
mkdir -p "$(dirname "$PRIMARY")/worktrees"
# Cannot check out the same branch in two worktrees — use a new branch name
git worktree add -b worktree/slot-1 \
  "$(dirname "$PRIMARY")/worktrees/monorepo-slot-1" HEAD
WT="$(dirname "$PRIMARY")/worktrees/monorepo-slot-1"
```

### 2. Copy env files from primary

```bash
cp "$PRIMARY/.env" "$WT/.env"
cp "$PRIMARY/.env.local" "$WT/.env.local"
cp "$PRIMARY/apps/web-crm/.env.local" "$WT/apps/web-crm/.env.local"
cp "$PRIMARY/apps/web-funnel/.env.local" "$WT/apps/web-funnel/.env.local"
cp "$PRIMARY/apps/server-crm/.env.local" "$WT/apps/server-crm/.env.local"
```

### 3. Create isolated database

```bash
docker exec -e PGPASSWORD=dbpassword future-mortgage-postgres \
  psql -U dbuser -d postgres \
  -c "CREATE DATABASE dbname_wt1 OWNER dbuser;"
```

Reuse the same Postgres **container** and Redis **container**; only change
DB name / Redis logical DB index so data and job queues do not collide.

### 4. Rewrite env for slot ports

In `$WT/.env` set (slot 1 example):

```bash
PORT=3101
ADMIN_URL=http://localhost:3100/admin
WEB_FUNNEL_URL=http://localhost:4301
WEB_CRM_PORT=3100
WEB_FUNNEL_PORT=4301
REDIS_URL=redis://localhost:6379/1
DB_NAME=dbname_wt1
DATABASE_URL=postgresql://dbuser:dbpassword@localhost:5432/dbname_wt1
NX_PUBLIC_API_URL=http://localhost:3101
NX_PUBLIC_SERVER_CRM_SOCKET_URL=http://localhost:3101
SESSION_COOKIE_NAME=auth-token-wt1
```

In `$WT/.env.local`:

```bash
FRONTEND_URL=http://fm.futurewholesale.local:3100
# Leave BASE_URL (ngrok) alone unless you open a second tunnel to :3101
```

Write app-local env (Vite only loads env from the app directory):

`apps/web-crm/.env.local`:

```bash
PORT=3100
WEB_CRM_PORT=3100
WEB_FUNNEL_URL=http://localhost:4301
WEB_FUNNEL_PORT=4301
NX_PUBLIC_API_URL=http://localhost:3101
NX_PUBLIC_SERVER_CRM_SOCKET_URL=http://localhost:3101
NX_PUBLIC_ENV=local
```

`apps/web-funnel/.env.local`:

```bash
WEB_FUNNEL_PORT=4301
PORT=4301
NX_PUBLIC_API_URL=http://localhost:3101
NX_PUBLIC_ENV=local
```

### 5. Make front-end ports env-aware (worktree-local)

**Do not commit these with feature work** unless promoting env-aware defaults.

`apps/web-crm/webpack.config.js` — `devServer.port` and `/apply` proxy:

```js
port: Number(process.env.PORT || process.env.WEB_CRM_PORT || 3000),
// ...
target:
  process.env.WEB_FUNNEL_PROXY_TARGET ||
  process.env.WEB_FUNNEL_URL ||
  'http://localhost:4201',
```

`apps/web-funnel/vite.config.ts` — `server.port` / `preview.port`:

```ts
port: Number(process.env.WEB_FUNNEL_PORT || process.env.PORT || 4201),
```

`apps/web-crm/project.json` serve env:

```json
"PORT": "3100",
"WEB_CRM_PORT": "3100",
"WEB_FUNNEL_URL": "http://localhost:4301",
"WEB_FUNNEL_PORT": "4301"
```

### 6. Install, migrate, seed

```bash
cd "$WT"
# If leftover node_modules symlink from older setup: rm -f node_modules
yarn install   # own node_modules; husky postinstall — do not skip
yarn prisma:sync
yarn nx run database:seed
```

### 7. Serve

```bash
export PORT=3101 WEB_CRM_PORT=3100 WEB_FUNNEL_PORT=4301
export WEB_FUNNEL_URL=http://localhost:4301
export NX_PUBLIC_API_URL=http://localhost:3101
export NX_PUBLIC_SERVER_CRM_SOCKET_URL=http://localhost:3101
export DATABASE_URL=postgresql://dbuser:dbpassword@localhost:5432/dbname_wt1
export REDIS_URL=redis://localhost:6379/1
export SESSION_COOKIE_NAME=auth-token-wt1
export FRONTEND_URL=http://fm.futurewholesale.local:3100
export NODE_OPTIONS="--inspect=9230"

yarn nx run-many --target=serve
```

---

## Do not

- Point the worktree at the primary `DATABASE_URL` (`dbname`) if you plan to seed or migrate
- Reuse `SESSION_COOKIE_NAME=auth-token` across slots on the same host
- Commit worktree-only port patches / `.env*` / `serve-worktree.sh` / `.worktree-slot` as feature commits
- Use preview_* tools (subdomain tenancy requires `*.futurewholesale.local`)
- Run destroy against the primary checkout or ports 3000/3001/4201
- Drop `dbname` when tearing down a worktree
- Stop after setup when `$ARGUMENTS` still contains a coding task
- Run `./serve-worktree.sh` in the foreground, or wait on health/compile before starting a follow-on task
- Ask for slot/branch/name when defaults work
- Edit files in the primary checkout after create — work in `$WT`

## Why each isolation knob

| Knob | Why |
|------|-----|
| Ports | Avoid EADDRINUSE against primary webpack/vite/node |
| Separate Postgres DB | Safe migrate/seed without wiping primary data |
| Redis DB index | BullMQ / cache keys do not steal jobs from primary |
| SESSION_COOKIE_NAME | Browser cookies ignore port; same name collides on `*.futurewholesale.local` |
| FRONTEND_URL | Server redirects / emails must hit this slot’s web port |
| NX_PUBLIC_API_URL / SOCKET | Browser must talk to this slot’s API |
| WEB_FUNNEL_URL | web-crm `/apply` proxy + server funnel links |
| Node inspect port | Primary already binds `9229` |

## Notes from first successful dry-run (slot 1)

- Worktree path: `../worktrees/monorepo-slot-1`
- Both stacks healthy simultaneously: primary `3000/3001/4201` + worktree `3100/3101/4301`
- API health: `{"status":"healthy","database":"connected",...}`
- Seed: `yarn nx run database:seed` against `dbname_wt1` succeeds with standard tenants
- Inspector warning `Starting inspector on localhost:9229 failed` is expected if primary is up — set `NODE_OPTIONS=--inspect=9230` (setup script does this)
- Empty `apps/*/.env.local` in primary is fine; setup overwrites worktree app env with port wiring

## Optional: promote env-aware ports to main

If the team wants worktrees without patching configs every time, land this on main (backwards-compatible defaults):

1. `apps/web-crm/webpack.config.js` — read `PORT` / `WEB_CRM_PORT` / `WEB_FUNNEL_URL`
2. `apps/web-funnel/vite.config.ts` — read `WEB_FUNNEL_PORT` / `PORT`

Then the setup script only needs env rewrites + DB create + install/seed.

User arguments: $ARGUMENTS
````

#### `~/.ai/commands/peer-review.md`

````markdown file=~/.ai/commands/peer-review.md
---
description: Builds a feature with a three-round peer review loop. The main agent plans and implements, then three FRESH review rounds run in sequence. Within each round, specialist agents (security, silent-failure/soft-types, recurring patterns, correctness/plan-fit, testing, dead-code/stale-comments, duplication/extract-to-shared, architecture sense-check) spawn in parallel with no prior-round context. After each round, the main agent merges actionable comments, triages every comment as accept / reject / defer with reasoning, then implements accepted changes before the next round. Architecture sense-check notes are advisory only (never trigger a redo mid-loop) and surface to the user only at the end if the agent has a clear concern. Use when user says "/peer-review <task>", "/peer-review <prd-file>", "/peer-review #42", or asks for a "reviewed" / "triple-reviewed" / "peer-reviewed" implementation.
---

# /peer-review — Plan, Implement, Review x3, Triage

> **Prefer the workflow when possible.**  
> Run `/peer-review` as a **workflow** (`.grok/workflows/peer-review.rhai` or `~/.grok/workflows/peer-review.rhai`) instead of this skill when you want durable orchestration. The workflow keeps the same specialist concerns but is better in important ways:
>
> | Skill (this file) | Workflow |
> |-------------------|----------|
> | Implementer also triages findings (bias) | Fresh independent judge |
> | Findings accepted on trust | Adversarial verify, fail-closed (evidence required) |
> | Always 3 full rounds × 8 specialists | Default 2 rounds; early exit; round 2 is delta-only; arch once |
> | Free-form markdown, main-thread orchestration | Structured schemas, scratch artifacts, resumable `/workflows` UI |
> | ~24+ review agents fixed | Budget-aware caps (`MAX_VERIFY=12`, 6 findings/specialty) |
>
> **Workflow usage:**  
> `/workflow peer-review` with args  
> `{ "task": "<description | prd path | #issue>", "rounds": 1|2, "base": "main" }`  
> Or from the tool: `workflow(name: "peer-review", args: #{ task: "..." })`.  
> Watch progress in `/workflows`.
>
> Use **this skill** when you want the interactive main agent to plan/implement in-conversation (more chat control, less structure).

---

A development loop where a main agent produces a solution and three independent review **rounds** stress-test it in sequence. **Within each round, multiple specialist agents run in parallel** (one concern type each), so the round finishes much faster than a single mega-reviewer. Each round starts with a fresh set of agents (no prior-round context). The main agent merges specialist comments, triages every comment, and implements accepted changes before the next round begins. One specialist (architecture sense-check) is **advisory only**: it never asks the main agent to re-architect mid-loop; notes accumulate and surface to the user only at the end if there is a clear concern.

**Usage (skill / interactive):** `/peer-review <task-description | prd-file-path | github-issue>`

**Examples:**
- `/peer-review add rate limiting to the public API` — free-form task
- `/peer-review docs/prd/user-dashboard.md` — read a PRD file
- `/peer-review #42` — fetch GitHub issue #42 (uses repo of current working directory)
- `/peer-review https://github.com/org/repo/issues/42`

---

## Core Invariants

These rules MUST hold for every run. If you cannot satisfy them, stop and tell the user why.

1. **Three review rounds, in sequence.** Not two, not four. Round N+1 must not start until round N is fully triaged and accepted changes are implemented.
2. **Within each round, specialists run in parallel.** Spawn one agent per concern type **in a single tool-call batch**. Do not run security → silent-failure → testing as sequential main-agent work or sequential single agents.
3. **Reviewers see no prior rounds.** Every specialist prompt must include the plan and the current code state ONLY. It MUST NOT contain prior round comments, prior decisions, or any acknowledgement that earlier rounds happened.
4. **Specialists stay in their lane.** Each agent reviews only its concern type. Overlap is OK; the main agent deduplicates when merging.
5. **Every actionable comment is triaged.** The main agent decides per comment from actionable specialists (S1–S5, S7–S8): `accept` (implement now), `reject` (with reasoning), or `defer` (with reasoning + scope note). No actionable comment is silently ignored.
6. **Architecture sense-check (S6) is advisory only.** S6 never produces accept/reject/defer items and **must never** cause the main agent to re-architect or redo the feature mid-loop. Persist notes quietly; surface them to the user only in Phase 3, and only if S6 has a clear concern.
7. **Accepted changes are implemented before the next round.** The next round's specialists read the updated code. Earlier accepted feedback is reflected in the code itself, not in side text.
8. **All artifacts are persisted.** Plan, per-round comments, per-round decisions, architecture notes, and final summary all live in `.peer-review/` so the user can audit the whole loop.
9. **Never stall the loop on a missing reviewer.** A specialist that errors, times out, hangs, or never returns a usable review is a failure. Retry that specialty once, then continue. Do not sit idle waiting for a notification that may never come.

---

## Phase 0 — Resolve Input

The single argument can be one of three forms. Detect and dispatch:

1. **GitHub issue** — matches `^#?\d+$` or contains `github.com/.*/issues/\d+`:
   - For `#NNN` or bare `NNN`: detect the repo from `git remote get-url origin` in the CWD, then `gh issue view <NNN> --repo <owner>/<repo>`
   - For full URL: parse repo + issue number, then `gh issue view`
   - If a PRD path is referenced in the issue body, read it too
2. **File path** — argument exists as a file on disk (use `Read`):
   - Treat the file contents as the spec
3. **Free-form description** — anything else:
   - Treat the argument as the task description directly

If detection is ambiguous (e.g. a string that could be either a filename or a description), prefer the most concrete: check filesystem first, then issue pattern, then fall back to free-form.

Save the resolved spec to `.peer-review/spec.md` (verbatim for files/issues, or the user's free-form text as a one-paragraph spec for free-form inputs).

---

## Phase 1 — Plan and Implement

The MAIN agent (you, in this conversation) does this phase directly. Do not delegate the plan.

1. **Create the plan.** Write a concrete plan to `.peer-review/plan.md`. The plan must include:
   - **Goal** — one paragraph restating the task in your own words
   - **Approach** — the design / architecture choice and the main tradeoff you're accepting
   - **Files to create or modify** — explicit list of paths
   - **Consumer / dual-path map** — for every new or moved field/abstraction, list who must read or honor it (API schema, DB, list/read UI, exporters/transformers for **each** pipeline, importers, jobs). Mark any intentionally deferred consumer under Out of scope.
   - **Invariants & concurrency** — what must be unique / atomic; whether a DB constraint or transaction enforces it
   - **AuthZ** — who can call new procedures and which existing gate (role/assignment/tenant helper) is reused
   - **Failure modes** — what hard-fails vs user-visible degradation; no silent ACTIVE/success on failed setup
   - **Out of scope** — what you are deliberately NOT doing, so reviewers don't churn on it
   - **Open questions** — anything you're uncertain about (reviewers can weigh in)
2. **Track tasks.** Use `TaskCreate` to enumerate the implementation steps from the plan. Update them as you go.
3. **Implement.** Write the code. Use specialized agents (`backend-architect`, `frontend-developer`, etc.) via the `Task` tool when the work clearly fits their domain — otherwise do it yourself. Verify it builds / type-checks before declaring Phase 1 complete.
   - While implementing, self-check the recurring patterns (soft success, write-only wiring, races, thin authZ, mount wipes, dual-path drift, envelope casts, tests that assert failure paths) so round 1 does not rediscover basics.
4. **Snapshot files changed.** Write the list of created/modified paths to `.peer-review/files-touched.md` — one path per line. This is the file set the specialists will examine.

Do not announce "ready for review" to the user. Move directly into Phase 2.

---

## Phase 2 — Three Sequential Rounds (Parallel Specialists Inside Each Round)

Loop the following EXACTLY three times. Variable `N` is the round number (1, 2, 3).

```
Round N:
  2.N.a  Spawn ALL specialists in parallel (one agent per concern)
  2.N.b  Wait for all specialists; merge S1–S5 + S7–S8 into round-N-comments.md; stash S6 notes only
  2.N.c  Triage every actionable comment → round-N-decisions.md (S6 is never triaged)
  2.N.d  Implement accepted changes
  2.N.e  Update files-touched.md
```

### 2.N.a — Spawn parallel specialist agents

Spawn **eight** independent agents in **one tool-call batch** (same turn). Use the platform's multi-agent tool (`Task` / `spawn_subagent` / equivalent).

| Specialist ID | Concern | subagent_type | description | Actionable? |
|---------------|---------|---------------|-------------|-------------|
| **S1** | Correctness / plan-fit / edge cases | `general-purpose` | `Peer R{N}: correctness` | Yes — triage |
| **S2** | Security / authZ / secrets | `backend-architect` (fallback: `general-purpose`) | `Peer R{N}: security` | Yes — triage |
| **S3** | Silent failure / soft types | `general-purpose` | `Peer R{N}: silent fail` | Yes — triage |
| **S4** | Recurring PR patterns R1–R10 | `general-purpose` | `Peer R{N}: recurring` | Yes — triage |
| **S5** | Testing gaps | `test-writer-fixer` (fallback: `general-purpose`) | `Peer R{N}: testing` | Yes — triage |
| **S6** | Architecture sense-check | `general-purpose` (or `plan` if available) | `Peer R{N}: arch sense` | **No** — advisory notes only |
| **S7** | Dead code / unused / stale comments | `general-purpose` | `Peer R{N}: dead code` | Yes — triage |
| **S8** | Duplication / extract-to-shared | `general-purpose` | `Peer R{N}: duplication` | Yes — triage |

Prefer `capability_mode: read-only` (or equivalent) so specialists cannot edit code.

**Do not** spawn one mega-reviewer. **Do not** wait for S1 before launching S2–S8.
**Do not** treat S6 output as work for the main agent. Never re-architect or rewrite the feature because of S6 during the loop.

---

### Shared prefix for every specialist (round N)

Interpolate plan + files. Never include prior-round artifacts.

```
You are an independent specialist code reviewer for ONE concern only (stated below).
You have no prior context about this work — review what you see, not what you assume.
You do not know about other specialists or other review rounds.

## The plan

The implementing engineer wrote this plan before coding:

---
{contents of .peer-review/plan.md}
---

## Files implemented

These files were created or modified for this work:

{contents of .peer-review/files-touched.md}

## Shared rules (all specialists)

1. Read the plan carefully. Note what is explicitly OUT OF SCOPE — do not raise comments about those.
2. Read every file in the list above using the Read tool. Read the full file, not just changed regions.
3. Stay in your specialty. Skip issues owned by other specialists unless they are inseparable from your finding.
4. Do not modify any code. Review only.
5. Do not read `.peer-review/round-*` files. Your review must be independent.
6. Be specific. "Add error handling" is useless; cite file:line and a concrete change.
7. If you have nothing substantive for your specialty, return an empty Comments section with Summary: "clean for this specialty" — do not pad.
8. Severity: blocker | major | minor | nit

## Comment format (each specialist uses local IDs S1, S2, ... within their own output)

Write findings ONLY (no need to write a full markdown file — return structured markdown in your final message):

```markdown
# Specialist: <SPECIALTY_NAME> (round N)

## Summary
One paragraph: overall impression for THIS specialty only.

## Comments

### S1 — <short title>
- **Severity**: blocker | major | minor | nit
- **File**: path/to/file.ts:LINE (or "general")
- **Observation**: what you see
- **Why it matters**: concrete consequence
- **Suggested change**: specific change, not a vague direction

### S2 — ...
```

This is round: N
Your specialty: <SPECIALTY_NAME>
```

---

### S1 — Correctness / plan-fit / edge cases

Append to shared prefix:

```
## Your specialty: Correctness / plan-fit / edge cases

Review ONLY for:
- Mismatches between the plan and the implementation
- Logic bugs, edge cases, off-by-one, null derefs, race/async ordering
- Incomplete error handling that is pure correctness (not the soft-fail catalog)
- Maintainability issues that meaningfully hurt this change
- Missing cleanup, wrong status codes, copy-paste bugs

Do NOT deep-dive: injection/auth catalogs, silent-fallback catalogs, R1–R10 checklists, unused-import/dead-symbol cleanup, extract-to-shared DRY, or test-suite design (other specialists).
```

---

### S2 — Security / authZ / secrets

Append to shared prefix:

```
## Your specialty: Security / authZ / secrets

Review ONLY for:
- Injection (SQL/NoSQL/command/XSS/template)
- Missing or weak auth checks; broken access control
- Thin tenant checks without assignment/role gates used elsewhere
- Over-broad procedures (PENDING/onboarding performing privileged side effects)
- Identity vs capability conflation
- Auth that fails open (`catch { return true }`)
- Secrets/PII in logs or responses; env names in user-facing errors
- Cross-tenant leakage; missing input validation on new endpoints
- Crypto/session/JWT issues

Do NOT deep-dive: performance, silent-fallback type hardening (except fail-open auth), test coverage, or plan-fit nits.
```

---

### S3 — Silent failure / soft types

Append to shared prefix:

```
## Your specialty: "Just make it work" / silent-failure / soft types

Prefer hard failures with clear errors over continuing in a wrong state — unless the fallback
is intentional, documented, user-visible graceful degradation.

**Root cause of many fallbacks: soft types.** Prefer a hard, exact type + validation boundary —
never `any` / type-erasure.

### Silent / swallowed failures
- Empty catch, or catch that only logs and continues as success
- `.catch(() => undefined|null|[]|{})`
- try/catch returning default "success" on failure
- Fire-and-forget async where failure should affect the caller

### Fallbacks that should hard-fail
- Critical config/env defaults that hide misconfiguration
- Empty arrays/objects/`null` when required data is missing
- `|| []`, `?? []`, `?? {}`, `?? ''` papering over unexpected null/undefined
- Long optional chains on required paths
- Production mock/stale/placeholder fallbacks without product requirement
- Parse failures converted to silent defaults
- Retry that "succeeds" with partial/empty data

### Soft types that force soft fails
For every fallback you flag:
1. Trace the type of the value being defaulted
2. Name the **exact** expected hard type (field-by-field if needed)
3. Prefer fixing the type so the fallback is unnecessary
4. Never suggest `any`, `as any`, double casts, blanket `!`, or `@ts-ignore` as the fix

Flag: optional fields that should be required, `Partial<T>` for loaded entities, unvalidated JSON
deep in domain, empty success when absence is error, optional params only to make call sites compile,
DB selects omitting fields that code then defaults.

### Type papering & soft-fail behavior
- `as any` / double casts / non-null `!` to silence the compiler
- Partial success as full success; validation that warns and continues
- Auth fail-open (also report — security specialist may overlap; still flag)

For each finding include:
1. What happens on failure today
2. What should happen instead
3. Soft-type root cause? → exact hard type + boundary
4. Concrete fix (not more defaults, not `any`)

Severity: auth fails-open and data-loss soft-fails = blocker/major; config/required-data silent defaults
and soft-type fallback cascades = major; suggesting `any` = major; non-critical swallows = minor.
```

---

### S4 — Recurring PR patterns (R1–R10)

Append to shared prefix:

```
## Your specialty: Recurring PR failure patterns (R1–R10)

Walk this checklist against the touched files. Flag hits with blocker/major when they can cause
data loss, wrong money/credit/AUS/messaging behavior, cross-tenant issues, or "looks healthy while broken."
For R2/R6, read consumers outside the touched list when needed.

### R1 — Soft failure that looks like success
- Catch/log-and-continue while status claims ACTIVE / ready / success
- Empty fallbacks on **required** export/vendor payloads instead of preflight throw
- Setup failures swallowed so feature looks live
- Tests skip/pass when fixtures missing
- Polling-only UIs with no recovery if webhooks never land

### R2 — Incomplete end-to-end wiring (write-only)
UI → API/schema → DB → read/list → export transformers (each pipeline) → import → jobs → shared sites
- Partial shared-component adoption; clear/reset without live side-effect update; deleted write path without re-home
If deferred, plan must say so; else blocker/major.

### R3 — App-only invariants and races
- Uniqueness only in app code; check-then-act without atomicity; counter without unique+retry
- Tenant-scoped unique on globally unique vendor resource; multi-step writes missing transaction

### R4 — Thin authZ / tenant / secret boundaries
- Weaker gates than siblings; over-broad callers; identity mixed with capability filters
- Env names in user errors; PII/secrets logged; dual-pipeline redaction gaps

### R5 — Form hydration / mount wipes
- useEffect mount write without hydration sentinel; auto-flip nulling persisted enums/booleans
- Partial updates nulling omitted fields

### R6 — Dual-path inconsistency
- Parallel transformers with different predicates; CRM vs funnel / admin vs LO rule drift
- Dual schemas; sticky columns vs live derivation; actor identity changes across steps

### R7 — Envelopes / partial updates / type lies
- Casts to guessed shapes vs real envelopes; omitted fields set to null; `as any` to compile

### R8 — Tests that do not protect the change
- No unit test on new branches/guards; happy-path-only fixtures; no-op when inputs absent
- Prefer a test that would fail if silent-success or write-only bug returned
(Overlap with testing specialist is OK — focus on "does this test protect the failure mode?")

### R9 — UX recovery and edge states
- Missing loading/error/cancel/retry/stale handling; double-submit; broken image fallback
- Eager per-row work without cleanup/virtualization

### R10 — Consistency with codebase patterns
- Reinventing existing helpers; arbitrary design tokens/z-index; incomplete a11y for tab-like UI

In **Why it matters**, name the production failure mode. In **Suggested change**, prefer DB constraints,
existing auth helpers, hard preflight throws, full consumer wiring, tests that pin the failure path —
not more `??` defaults.
```

---

### S5 — Testing gaps

Append to shared prefix:

```
## Your specialty: Testing gaps

Review ONLY for missing or weak tests. Do not redesign product logic except to say what assertion would catch a bug.

- New branches/logic without unit tests (especially refusal/guard/migration/backfill)
- Modified behavior without updated tests
- Fixtures hardcoding happy path so assertions always pass
- Tests that no-op green when fixtures/reference files are missing
- Missing tests that assert **failure** paths
- Behavior/UI contract changes without e2e/integration updates
- Prefer at least one test that would **fail** if a silent-success or write-only bug returned

For each comment: where the test should live, what to assert, and what bug it would catch.
```

---

### S7 — Dead code / unused / stale comments

Append to shared prefix:

```
## Your specialty: Dead code / unused / stale comments

Remove refactor leftovers. Prove unused with grep/read — do not guess.

### Unused imports & symbols
- Unused imports (named/default/type-only/unneeded side-effect)
- Unused locals, params, private helpers, types, constants
- Exports/re-exports with no in-repo consumers (unless intentional public package API)
- Dead/unreachable branches after condition changes
- Assigned-never-read variables; leftover feature-flag/env reads

### Stale / useless comments (prefer delete)
- Comments narrating removed behavior: "used to", "previously", "was", "no longer", "removed X", "old path"
- Large commented-out code blocks; JSDoc that contradicts current signatures
- TODOs/FIXMEs already done or pointing at deleted code
- Leftover section banners for deleted code
- Obvious narrating comments added/left by this change that add no non-obvious intent

### Do NOT flag
- Symbols used via types/decorators/DI/framework reflection
- WHY/invariant/security comments that still apply
- WIP blocks with an active tracking TODO + issue
- Broad cleanups outside this change's blast radius

Severity: unused import = nit; dead private helper / misleading stale comment = minor/major;
stale comment that contradicts auth/security behavior = major/blocker.
For each: proof of zero refs (or quote the stale comment) + exact delete.
```

---

### S8 — Duplication / extract-to-shared

Append to shared prefix:

```
## Your specialty: Duplication / extract-to-shared

Flag repeated logic only when ALL hold:
1. **≥ 3 real occurrences** after this change (in touched files and/or existing codebase)
2. **Would realistically be used more** (sibling features, list+detail+export, dual pipelines, repeated fields)
3. **Stable enough to name** — not coincidental similar shape with different invariants
4. **Extraction reduces drift risk** — not a premature flag-soup helper

### Scope of the shared home (required on every finding)
Pick from usage count + where copies live:
| Fan-out | Scope |
|---------|--------|
| 3+ in one file | Private helper in that file |
| 3+ in one feature/module | Module `utils` / `helpers` beside the feature |
| 3+ across one app | App-level shared module already used for similar things |
| 3+ across apps / FE+BE domain rule | Existing monorepo `libs/` domain package |
| Near-match to existing helper | Extend/reuse that helper — no parallel utility |

Always include: occurrence count, file:line list, proposed symbol + path, params vs identical core.
Search the repo — do not only look inside the touched list.

### Do NOT flag
- Only 2 weak lookalikes; intentional test-fixture duplication; trivial one-liners
- Similar control flow with different business meaning
- Huge unrelated DRY refactors disproportionate to this change

Severity: easy local 3-copy helper = minor/nit; drifting copies or dual-path same domain rule = major;
reinvented existing helper = major.
Suggested change must be a concrete signature + home path — not "consider DRY".
```

---

### S6 — Architecture sense-check (advisory only)

Append to shared prefix. **Override** the shared comment format: S6 does **not** emit C#/S# triage items.

```
## Your specialty: Architecture sense-check (advisory)

Your job is to answer one question:

> "Does the way this is implemented actually make sense as it is now?"

Look at:
1. The plan's stated approach and tradeoffs
2. The implemented files end-to-end
3. Surrounding codebase patterns (read related modules, existing helpers, how similar features are done)

Ask yourself: given this codebase and the problem being solved, is the architecture a reasonable fit?
Could a competent engineer reading this in six months understand why it was built this way?

### Stance — default to "fine"

- You are **not** quick to demand a re-architecture. Most working designs that fit local patterns are fine.
- Only speak up when there is a **very clear** more proper way that fits this codebase better, or when the current approach is **clearly poor** (wrong layer, fights existing abstractions, invents a parallel system for something already solved, will force painful follow-ups).
- Style preferences, micro-optimizations, and "I would have named it differently" are NOT findings.
- Preferable-but-not-clearly-better alternatives are NOT findings. Silence is the correct output when the design is acceptable.

### What you may conclude

| Verdict | When | What you write |
|---------|------|----------------|
| **fine** | Design is reasonable for this codebase | Empty note: `Verdict: fine` only — no explanation needed |
| **clear-better-path** | A clearly better architecture exists that fits the grand change and surrounding code | Short note: current approach, why a better path is obvious, what that path is |
| **poor-fit** | Current approach is a poor fit (wrong layer, fights patterns, invents parallel systems) | Short note: what is poor, why, and the coherent alternative |

### Critical constraints

- **Never** tell the implementing agent to redo or re-architect the work.
- **Never** emit Severity / Suggested change / C# comments for triage.
- Your output is a **user-facing advisory note** collected until the end of the peer-review loop.
- Keep notes short (half page max). If fine, keep it to one line.

### Output format (return this only) — do not use Severity / C# items

# Specialist: Architecture sense-check (round N)

## Verdict
fine | clear-better-path | poor-fit

## Note
(Omit entirely when Verdict is fine.)
When not fine: 2–6 sentences.
- What was built and why it was shaped this way (as far as you can tell)
- Why that shape is a poor fit OR why a better path is clearly preferable
- The alternative that makes more sense in this codebase (concrete, not vague)
- Do NOT instruct anyone to rewrite now
```

---

### 2.N.b — Merge specialist outputs into one comments file

Wait until **all eight** specialists finish (or one retry each if a specialist failed).

#### Actionable specialists (S1–S5, S7–S8)

Write `.peer-review/round-N-comments.md` by merging **S1–S5, S7–S8 only**:

1. Start with a round header and a short overall summary (1–3 sentences) synthesized by the main agent.
2. Renumber all specialist comments globally as **C1, C2, C3, ...** (stable order: S1, S2, S3, S4, S5, S7, S8).
3. On each comment, preserve Severity / File / Observation / Why it matters / Suggested change.
4. Add a line: `- **Specialty**: Correctness | Security | SilentFailure | RecurringPattern | Testing | DeadCode | Duplication`
5. Deduplicate near-identical findings from two specialists: keep one comment, note both specialties, keep the stronger severity and the more specific fix.
6. If a specialist returned clean, note under a "Clean specialists" line — do not invent padding comments.
7. **Do not** put S6 content into this file as triageable comments.

Exact format:

```markdown
# Review round N

## Summary
One paragraph: overall impression and the single most important thing the engineer should address.
Specialists run: Correctness, Security, SilentFailure, RecurringPattern, Testing, DeadCode, Duplication, ArchitectureSense (advisory).

## Comments

### C1 — <short title>
- **Specialty**: Security
- **Severity**: blocker | major | minor | nit
- **File**: path/to/file.ts:LINE (or "general")
- **Observation**: ...
- **Why it matters**: ...
- **Suggested change**: ...

### C2 — ...

## Clean specialists
- Testing: no findings

## Architecture sense-check (advisory — not triaged)
- Round N verdict: fine | clear-better-path | poor-fit
- (Full note lives in round-N-architecture-note.md; do not implement from this)
```

#### Architecture specialist (S6) — stash only

Write `.peer-review/round-N-architecture-note.md` with S6's raw output (or `Verdict: fine` if clean/empty).

**Main agent rules for S6:**
- Do **not** triage S6.
- Do **not** implement, re-architect, or open follow-up work because of S6 during the loop.
- Do **not** stream S6 notes to the user mid-loop.
- After all three rounds, keep the **strongest** non-fine verdict across rounds (poor-fit > clear-better-path > fine). If all rounds said fine, the final summary omits architecture entirely.

If a specialist agent produces no usable output: re-spawn **that specialty only** once. If an actionable specialist (S1–S5, S7–S8) fails twice, add a single comment `C? — reviewer-failed (<specialty>)` with severity `major` and continue. If S6 fails twice, write `Verdict: fine` with a one-line note that the architecture specialist failed, and continue (do not block the loop).

---

### 2.N.c — Triage every comment (actionable only)

Read `.peer-review/round-N-comments.md`. For each comment C1, C2, ..., decide.
**Skip S6 entirely** — architecture notes are never accept / reject / defer.

- **accept** — the comment is correct and you will implement the suggested change now
- **reject** — the comment is wrong, already handled elsewhere, or based on a misreading; you must explain why
- **defer** — the comment is reasonable but out of scope for this work; you must explain why and note where it should be tracked (a follow-up issue, a TODO, etc.)

Write decisions to `.peer-review/round-N-decisions.md` in this format:

```markdown
# Round N decisions

## C1 — <title from comment>
- **Decision**: accept | reject | defer
- **Reasoning**: 1-3 sentences. For reject/defer this is mandatory.
- **Implementation note**: (only if accepted) the specific edit you will make

## C2 — ...
```

**Severity is informational, not binding.** A `nit` may be worth accepting if cheap; a `blocker` may be worth rejecting if the reviewer misunderstood. Use judgment.

---

### 2.N.d — Implement accepted changes

Apply every `accept` decision before the next round begins. Use `Edit` / `Write` / specialist Task agents as appropriate. Verify the code still builds / type-checks.

**When the accepted fix is about a soft-fail / fallback / soft type:**
1. Determine the **exact** expected type (domain, API contract, DB schema, caller guarantees) — field-level precision.
2. Introduce or tighten that hard type; validate/narrow once at the appropriate boundary.
3. Remove the silent fallback / empty default / type-papering that prompted the comment.
4. **Do not** "fix" with `any`, `as any`, `as unknown as T`, blanket `!`, or by making more fields optional. If the compiler complains, the call sites or boundary validation are wrong — fix those.

If applying an accepted change reveals it was wrong (test now fails, type error you didn't anticipate), update the decision file: change it from `accept` to `reject` and document what you learned. Do not silently drop it. A type error after removing a fallback is often a signal to harden more call sites, not to revert to soft types.

---

### 2.N.e — Update files-touched

If implementing accepted changes added new files, append them to `.peer-review/files-touched.md` so round N+1 sees the full surface area.

---

## Phase 3 — Final Summary

After round 3 is fully triaged and implemented, write `.peer-review/summary.md`:

```markdown
# Peer review summary

**Spec source**: <path / issue # / "free-form">
**Files created**: <count>
**Files modified**: <count>
**Review model**: 3 sequential rounds × 8 parallel specialists (Correctness, Security, SilentFailure, RecurringPattern, Testing, DeadCode, Duplication, ArchitectureSense-advisory)

## What was built

<2-4 sentences describing the final implementation>

## Review rounds

### Round 1
- Specialists: 8 parallel (7 actionable + architecture advisory)
- Comments raised: <N> (after merge/dedupe; actionable only)
- Accepted: <N> | Rejected: <N> | Deferred: <N>
- Architecture sense-check: fine | clear-better-path | poor-fit
- Notable changes from this round: <bullets>

### Round 2
(same structure)

### Round 3
(same structure)

## Deferred items

<list every deferred comment across all rounds with a one-line note on where it should be tracked>

## Architecture sense-check (user advisory)

<!-- ONLY include this section if the strongest verdict across rounds is NOT fine.
     If all rounds said fine: OMIT this entire section — say nothing about architecture. -->

**Verdict**: clear-better-path | poor-fit

<Synthesize the strongest non-fine note(s) from round-*-architecture-note.md into a short
user-facing paragraph. Do not re-implement. Do not present this as work the agent will do.
Frame as: "For your consideration — the architecture sense-check thought…" >

## Open risks

<anything the reviewers didn't catch but you noticed during the loop, or known limitations>
```

Then output a short message to the user pointing them at `.peer-review/summary.md` and listing the deferred items inline so they don't have to open the file to see what's left.

**Architecture note in the user message:**
- If strongest S6 verdict across all rounds is `fine` → **say nothing** about architecture.
- If `clear-better-path` or `poor-fit` → include a short final paragraph so the user sees what the sense-check thinks. Do not offer to rewrite unless the user asks.

---

## Output Discipline

- Do not stream every specialist comment to the user as it arrives — the files are the record. Give the user a one-line status per phase ("plan + implementation done", "round 1: 8 specialists done, 4 comments — 2 accepted, 1 rejected, 1 deferred", etc.). Do not surface architecture notes mid-loop.
- Do not ask the user for approval between rounds. The loop is autonomous by design.
- If the user interrupts mid-loop, the state in `.peer-review/` is enough to resume — say so.
- If a specialist batch is incomplete, merge what you have and proceed. Never leave the user waiting on a hung reviewer.
- Never rewrite or re-architect the feature because of S6. Architecture sense-check is for the user's judgment at the end only.

---

## Error Recovery

- **Spawn specialists as one foreground parallel batch** so the batch returns together. Do **not** background them and wait for a later notify. Background + “do not poll” is how this loop stalls.
- **One specialist fails** (error, empty output, capacity/timeout, or never returns): retry **that specialty only**, once, immediately. If the retry also fails or does not return a usable review, log `reviewer-failed (<specialty>)` as a `major` comment and **continue the round with whoever finished**.
- **Silent / hung specialist**: treat as a failure. Do not poll. Do not wait. A missing result after the batch (or after the one retry) is enough to mark `reviewer-failed`.
- **All specialists fail**: stop the loop and tell the user; do not invent comments.
- **Accepted change breaks the build**: revert that specific change, flip the decision to `reject` with reasoning `"applying this broke <X>"`, continue.
- **Specialists contradict each other**: both comments appear after merge (or dedupe if identical). Triage on merits independently.
- **Reviewer suggests a contradicting change to one already accepted in a prior round**: allowed and expected — rounds are fresh. Triage on merits; if you reject, note that round M's accepted change was deliberate.

---

## Checklist Before Marking Complete

- [ ] `.peer-review/plan.md` exists (includes consumer map, invariants, authZ, failure modes)
- [ ] `.peer-review/files-touched.md` exists and lists every changed file
- [ ] `.peer-review/round-1-comments.md`, `round-2-comments.md`, `round-3-comments.md` exist
- [ ] Each round spawned **eight parallel specialists** (Correctness, Security, SilentFailure, RecurringPattern, Testing, DeadCode, Duplication, ArchitectureSense) — not one mega-reviewer
- [ ] Each round's merged comments cover silent-failure, recurring patterns, dead-code, and duplication (via S3, S4, S7, S8)
- [ ] S6 notes written to `round-N-architecture-note.md` and **never** triaged as accept/reject/defer
- [ ] Main agent did **not** re-architect or redo work because of S6 during the loop
- [ ] `.peer-review/round-1-decisions.md`, `round-2-decisions.md`, `round-3-decisions.md` exist
- [ ] Every actionable comment (S1–S5, S7–S8) in every round has a corresponding decision
- [ ] All `accept` decisions are reflected in the code
- [ ] `.peer-review/summary.md` exists
- [ ] Architecture section in summary + user message only appears when strongest S6 verdict is not fine
- [ ] Code builds / type-checks
- [ ] User received a short status message with a pointer to the summary

If any item is unchecked, the loop is not done.

User arguments: $ARGUMENTS
````

#### `~/.ai/commands/pinokio.md`

```markdown file=~/.ai/commands/pinokio.md
---
description: Discover, launch, and use apps and tools for the current task.
---

Load the "pinokio" skill with the skill tool, then follow it exactly.

User arguments: $ARGUMENTS
```

#### `~/.ai/commands/pr-review-light.md`

````markdown file=~/.ai/commands/pr-review-light.md
---
description: Fast single-agent PR review (same as /pr-review, no subagents). Always creates a code-only git worktree first (same as /worktree-quick) so /pr-review-light 1234 does not need a prior /worktree-quick. After the report, stop with the numbered findings list. In later turns, answer questions or post inline GitHub comments when the user asks to add/post a number list.
---

# /pr-review-light — Fast single-agent PR review

Same review as `/pr-review`, **without subagents**. You (the main agent) gather the diff, review it in one pass, and report. After the report, **stop**. Later, answer questions or post inline GitHub comments when the user asks to add/post finding numbers.

**Usage:** `/pr-review-light [PR number | PR URL | branch] [optional-prd-file-path]`

`/pr-review-light 1234` is enough — this skill creates the code-only worktree itself. Do **not** require a prior `/worktree-quick`.

User arguments: $ARGUMENTS

## Hard rules

1. **NEVER spawn subagents** (`Task`, `spawn_subagent`, specialist agents, fan-out). No exceptions — not for "large diffs", not for "parallel specialists". Speed comes from one pass.
2. **NEVER fabricate findings.** Clean code → say it's clean.
3. **Stop after the report.** Do not walk findings. Do not use the Question tool. Never auto-post. Post only in a later turn when the user asks to add/post a number list or a single finding.
4. **GitHub comments are inline only** (`path` + `line`). Never `gh pr comment` / issue comments as a substitute.
5. Prescribe **hard types + hard fails**, never `any` / `?? ''` papering.
6. **Always isolate in a code-only worktree first** (Phase 0 / `/worktree-quick` script). Never review the primary checkout. Never require a prior `/worktree-quick`.

## Speed model

```
0. Code-only worktree         -> /worktree-quick script + session_move (always; then review)
1. Context (parallel git)     -> branch, base, diff, stat, log, file list (in the worktree)
2. One-pass review            -> YOU read the diff; Grep/Read only to confirm a suspected issue
3. Report                     -> unified tables (no specialist-status theater)
4. STOP after report          -> numbered list is the end of this turn
5. Follow-up (later turns)    -> same as /pr-review Phase 5 (questions, or add/post numbers)
```

- Do **not** pre-build file-category tables, specialist payloads, or "No X issues found" per concern.
- Do **not** read the whole surrounding codebase "to be thorough". Open extra files only when the diff suggests a real issue (authz sibling, consumer of a new field, unique index, etc.).
- Prefer **high-signal** findings. Skip style nits, naming bikesheds, "could useMemo", and obvious-comment noise.
- If the diff is huge, review it in chunks **yourself** (highest-risk files first: auth, API, DB, config). Still no subagents.

---

## Phase 0: Code-only worktree (always, before any review)

Review **never** runs in the primary checkout. Isolate first with the same script as `/worktree-quick`, then review inside that worktree. **Do not** wait for the user to run `/worktree-quick`. **Do not** use `/monorepo-worktree` (no DB, ports, seed, or serve). **Do not** stop after create — continue immediately into Phase 1 in this same session. session_move is **not** a subagent.

User arguments: `$ARGUMENTS`

### Parse target

Split `$ARGUMENTS` into **TARGET** + optional **PRD path**:

| Token | Meaning |
|-------|---------|
| `1234` / `#1234` / `pr 1234` / GitHub `.../pull/1234` | PR |
| `feature/foo` / `origin/foo` / other git ref | Branch |
| Path ending in `.md` or an existing file | PRD (not a worktree target) |
| Empty | `gh pr view --json number -q .number`. If that fails and cwd is already a `*-quick-*` worktree, TARGET = current worktree (skip create). Else ask for a PR number — do not invent a task worktree. |

Resolve a relative PRD path to an **absolute** path against the **pre-move** cwd before leaving the primary checkout.

Remember `PR_NUMBER` when TARGET is a PR. Later `gh pr view` / review POSTs must use `gh pr view ${PR_NUMBER}` — the local branch will be `quick/pr-N`, which GitHub does not treat as the PR head.

### Skip create only when already isolated

Skip create if cwd is already a `*-quick-*` worktree (basename `*-quick-*` or gitdir marker `worktree-quick`) **and** it matches TARGET (same PR number / same slug). Still fetch+reset (below) so the review is current.

### Create or reuse

Script: `~/.ai/oc_skills/worktree-quick/scripts/quick-worktree.sh`

Must run from the git repo under review (or set `REPO_ROOT`). Do **not** hand-roll `git worktree add`.

```bash
~/.ai/oc_skills/worktree-quick/scripts/quick-worktree.sh 1234
~/.ai/oc_skills/worktree-quick/scripts/quick-worktree.sh pr 1234
~/.ai/oc_skills/worktree-quick/scripts/quick-worktree.sh https://github.com/org/repo/pull/1234
~/.ai/oc_skills/worktree-quick/scripts/quick-worktree.sh feature/foo
```

Parse `path:` from the success banner.

If the script fails with `worktree path already exists: <path>`: **reuse `<path>`**. Do not destroy. Fetch the PR/branch and `git -C <path> reset --hard` to that SHA so the review is current:

```bash
# PR
git fetch origin pull/${PR_NUMBER}/head
git -C "<path>" reset --hard FETCH_HEAD

# Branch
git fetch origin <branch>
git -C "<path>" reset --hard origin/<branch>
```

### Yarn (mandatory, every worktree)

After the path is known — **fresh create, reuse, or already-isolated** — run and wait for exit 0:

```bash
(cd "<path>" && yarn install)
```

Timeout 10 minutes. Never skip because `node_modules` exists. Never skip on reuse. Never skip because the task "doesn't need node_modules". If the create script already ran yarn in this turn and you **watched it exit 0**, that create counts; reuse / already-isolated **must still yarn**.

### Move the session, then review

1. OpenCode: `tools.opencode.session_move` with `directory` = the absolute worktree path. Continue **this** session. Do not spawn a subagent to perform the review.
2. If session_move is unavailable: `cd` / set `working_directory` on every later command to that path.
3. Every later git / Read / Grep must run in that worktree, not the primary checkout.
4. One-line note: path, `quick/…` branch, PR URL, destroy command (`~/.ai/oc_skills/worktree-quick/scripts/quick-worktree.sh destroy <slug> --yes`). Then **immediately** start Phase 1.

Do **not** destroy the worktree after the report (follow-up posting still needs the checkout).

---

## Phase 1: Context (run in parallel)

```bash
git branch --show-current
git remote show origin | grep 'HEAD branch' | awk '{print $NF}'
git diff $(git merge-base HEAD origin/main)..HEAD
git diff --stat $(git merge-base HEAD origin/main)..HEAD
git log --oneline $(git merge-base HEAD origin/main)..HEAD
git diff --name-only $(git merge-base HEAD origin/main)..HEAD
```

If HEAD branch is not `main`, swap `origin/main` for the detected base. Clean diff → stop. Cannot detect base → ask. If a PRD path was given, read it; if missing, warn and continue without PRD.

---

## Phase 2: One-pass review

Walk the **full diff** once. Flag only real issues. Every finding needs: Severity, Category, File, Line(s), Issue, Description, Fix.

### Severity

| Severity | When |
|----------|------|
| **CRITICAL** | Must fix before merge: injection, auth bypass, data loss, secret leak, fail-open auth, cross-tenant, soft-success on money/credit/AUS/messaging setup |
| **HIGH** | Should fix: N+1 hot path, check-then-act races, write-only fields, `?? ''` on required vendor payloads, thin tenant-only authZ, form mount wipes, dual-path divergence, envelope casts, no-op-green tests |
| **MEDIUM** | Fix soon: incomplete validation, swallowed non-critical errors, incomplete UX recovery, dead helpers, 3+ copy extract |
| **LOW** | Only if introduced by this PR and cheap: unused imports, tiny dead locals. Skip pure style. |

### Checklists (scan, don't write a report per box)

**Security** — injection (SQL/command/XSS/`dangerouslySetInnerHTML`); missing/thin authZ (tenant membership ≠ authorization; fail-open `catch { return true }`); secrets/PII in code or logs; env names in user errors; missing validation on new endpoints.

**Performance** — N+1 / queries in loops; missing indexes; unbounded lists; O(n²); sequential awaits that should be `Promise.all`; sync blocking I/O.

**Silent failure / soft types** — empty/log-only catch; `.catch(() => null\|[]\|{})`; required data defaulted with `??` / `||` / `?.`; `as any` / `as unknown as T` / `@ts-ignore`; fire-and-forget where the caller must know. Root-cause the **type** (exact Prisma/Zod/DTO), never suggest `any`.

**R1–R9 (always run, even on small PRs)**

| # | Pattern | Look for |
|---|---------|----------|
| R1 | Soft success | catch/log while status still ACTIVE/ready; tests skip-green when fixtures missing |
| R2 | Write-only / E2E | new field saved but not read by list/detail, export, import, job, twin pipeline — **grep consumers** |
| R3 | App-only races | uniqueness only in app code; check-then-act; `last+1` without unique+retry |
| R4 | Thin authZ | weaker gate than siblings; identity mixed with capability; over-broad roles |
| R5 | Form hydration wipe | mount `useEffect` writes form; partial PATCH maps omitted keys → null |
| R6 | Dual-path drift | CRM vs funnel / twin transformers disagree — **read the other path** |
| R7 | Envelope / type lies | guessed response shape; schema drift; double casts |
| R8 | UX stuck | async with no timeout/error/cancel; double-submit |
| R9 | Scope | reinvented nearby helper; arbitrary z-index/tokens |

Hits that look healthy while broken, lose data, or mis-route tenants/credit/messaging → CRITICAL/HIGH.

**Quality** — races, off-by-one, copy-paste bugs, missing await, magic strings that should be consts. Read hunk context, not only the `+` lines.

**Testing** — new paths with no test; no failure-path assert; tests that stay green if fixtures are absent. Name the test file and the assertion that would catch the bug.

**Dead code** — unused imports/symbols **this PR introduced**. Grep to confirm 0 refs. Stale "used to / previously" comments. Don't bikeshed old comments outside the change.

**Duplication** — flag only if **≥ 3** real copies and a named helper would reduce drift. Two copies is not a finding. Point at path + signature.

**PRD** (only if provided) — each requirement: IMPLEMENTED / PARTIAL / NOT IMPLEMENTED / DEVIATED. Evidence = file:line.

**Architecture** — gut check only. Default `fine` and **omit from the report**. Speak only for a clearly better existing-codebase path or a clearly poor fit. Never a merge blocker. Never a finding row.

---

## Phase 3: Report

```markdown
## Code Review Report

**Branch**: …
**Base**: …
**Files Changed**: N
**Commits**: N
**Review Date**: …
**Mode**: pr-review-light (single agent, no subagents)

### Verdict: BLOCK / APPROVE WITH FIXES / APPROVE

[1–2 sentences. Architecture does not change the verdict.]

### Critical & High Findings (Must Fix)

| # | Severity | Category | File | Line(s) | Issue | Fix |
|---|----------|----------|------|---------|-------|-----|

### Medium & Low Findings (Recommendations)

| # | Severity | Category | File | Line(s) | Issue | Fix |
|---|----------|----------|------|---------|-------|-----|

### PRD Compliance (if applicable)

| Requirement | Status | Notes |
|-------------|--------|-------|

### Recurring-pattern coverage

| Pattern | Status |
|---------|--------|
| R1 Soft success | clean / N findings |
| R2 Write-only / E2E wiring | clean / N findings |
| R3 Invariants & races | clean / N findings |
| R4 AuthZ / tenant / secrets | clean / N findings |
| R5 Form hydration wipes | clean / N findings |
| R6 Dual-path inconsistency | clean / N findings |
| R7 Envelopes / partial updates | clean / N findings |
| R8 UX recovery | clean / N findings |
| R9 Consistency / scope | clean / N findings |

### Architecture sense-check (user advisory)

<!-- ONLY if not fine. If fine: OMIT this section entirely. -->

### Next Steps
Ask about any finding, or reply with numbers to post as inline GitHub comments (e.g. `add 1-3, 5, 19` or `add 7`).
```

Number findings CRITICAL → LOW across both tables (continuous `#`). Merge duplicates (same line → one row, higher severity).

**Zero findings:** verdict APPROVE, skip Phase 4.

**After the report, stop.** Do not call the Question tool. Do not walk findings. Do not post to GitHub in this turn. Phase 4 runs only on later user messages.

---

## Phase 4: Follow-up chat — discuss or post selected findings

Same UX as `/pr-review` Phase 5. The report **is** the end of the review turn. Do **not** post in the same turn as the report. Do **not** use the Question tool.

### 4.1 Report-turn stop (required)

Print the numbered findings tables, tell the user they can ask questions or reply with numbers to post (e.g. `add 1-3, 5, 19` or `add 7`), then **stop**.

Architecture notes are **not** selectable.

### 4.2 Later turns — questions vs post

| User intent | What to do |
|-------------|------------|
| Questions / debate about a finding (or several) | Answer. Do **not** post. |
| Explicit add/post of a number list or a single number | Parse (4.3) and post those as **inline** comments (4.4–4.7). |
| `add all` / `post all` | Post every numbered finding. |
| Unclear (chat that is not a post request) | Answer; do **not** post. |

**Do not invent a default selection.** Never auto-post.

### 4.3 Parse the selection

Trigger words: `add`, `post`, `comment`, `inline` — plus a number list, a single number, or `all`. Parentheses are optional. A message that is **only** a number list (or a single number) is also a post request.

Examples that **must** post: `add 1-3, 5, 19, 24-26` · `add 7` · `7` · `post 1, 4, 9` · `1-3, 5, 19, 24-26` · `(1-3, 5, 19, 24-26)` · `add all`.

Parse rules: strip wrapping `()` / `[]`; split on commas/whitespace; `N-M` is inclusive range; `N` is finding N; `all` = every numbered finding; deduplicate; skip invalid numbers (tell the user). Custom comment text for a specific `#` becomes that finding's `body`; otherwise use Issue + Fix.

Empty set after validation → no GitHub. Later turns may post more numbers; do not re-post findings already posted in this conversation unless asked.

### 4.4 Resolve the PR (only after a later turn requests posting with ≥1 valid finding)

```bash
# Prefer the PR number from Phase 0 — local branch is quick/pr-N, not the GitHub head ref
gh pr view ${PR_NUMBER} --json number,url,title,headRefOid,headRefName
gh repo view --json nameWithOwner -q '.nameWithOwner'
```

No PR → stop; do not create one; do not post issue comments. `commit_id` = `headRefOid`.

### 4.5 Inline anchor

For each selected finding: repo-relative `path`; `line` = new-file line (`start_line` + `line` if a range); `side: RIGHT` for added/changed lines.

If the exact line is not in the PR diff, snap to the **nearest changed line in that file** and say so in the comment. If the file is not in the diff, **skip** (never fall back to a top-level comment). Deleted-only: `side: LEFT`. Prefer RIGHT if the line still exists.

### 4.6 One review POST (not one per finding)

Write JSON to a file; `POST` with `--input`. Do **not** `--field 'comments=[...]'`. Do **not** `gh pr comment`.

```bash
cat > /tmp/pr_review_light.json << 'ENDJSON'
{
  "commit_id": "<headRefOid>",
  "event": "COMMENT",
  "body": "Posted N selected finding(s) from /pr-review-light as inline comments.",
  "comments": [
    {
      "path": "src/auth.ts",
      "line": 45,
      "side": "RIGHT",
      "body": "**[CRITICAL] Security:** SQL injection via unsanitized input\n\n…\n\n**Fix:** Use a parameterized query."
    }
  ]
}
ENDJSON

NO_COLOR=1 gh api repos/{OWNER}/{REPO}/pulls/{pr}/reviews \
  -X POST \
  --input /tmp/pr_review_light.json
```

Comment body:

```markdown
**[SEVERITY] Category:** Issue title

<1–4 sentence description>

**Fix:** <concrete remediation>
```

`event` is always `COMMENT`. Cap 100 comments per review; split POSTs if needed.

### 4.7 After POST

Tell the user: PR URL, how many inline comments, which finding #s posted, which skipped and why. Do not re-print the full report.

---

## Errors

| Error | Action |
|-------|--------|
| Clean diff | Stop |
| Worktree script fails (not already-exists) | Stop; show full output; do **not** review the primary checkout |
| Worktree path already exists | Reuse that path; fetch+reset to latest PR/branch SHA |
| session_move unavailable | `cd` / `working_directory` on every command to the worktree path |
| No base branch | Ask |
| PRD missing | Warn; continue without PRD |
| Huge diff | Chunk **yourself**; still no subagents |
| No PR | On a post request, stop; don't create a PR |
| User only asks questions | Answer; do not post |
| Number list / add / post in a later turn | Parse and post those findings only |
| Invalid finding numbers | Skip them; tell the user which were invalid |
| Line not in diff | Snap to nearest changed line in file; else skip |
| POST 422 | Fix commit/line/side; retry once; then skip and report |

---

## Do not

- Spawn subagents, even if `/pr-review` would have. (`session_move` is not a subagent.)
- Collapse this skill into a sequential "run 10 specialist personas as extra turns" — that is the slow path. One pass.
- Demand a rewrite from architecture.
- Walk findings one at a time or use the Question tool after the report.
- Post unselected findings.
- Use `any` as a recommended fix.
- Review in the primary checkout, skip Phase 0, or require a prior `/worktree-quick`.
- Use `/monorepo-worktree` (no DB/ports/seed/serve).
- Skip yarn install on a fresh worktree create.
- Destroy the worktree after the report.

User arguments: $ARGUMENTS
````

#### `~/.ai/commands/pr-review.md`

````markdown file=~/.ai/commands/pr-review.md
---
description: Deep code review agent that always creates a code-only git worktree first (same as /worktree-quick — fetch + checkout, env copy, yarn install; no DB/ports/seed) then analyzes all diffs in that worktree for performance bottlenecks, security vulnerabilities, code quality issues, "just make it work" silent-failure patterns (swallowed errors, bad fallbacks that should hard-fail — often rooted in soft types; fix by hardening exact types, never with any), incomplete end-to-end wiring (write-only fields, missed dual-path consumers), app-only invariants/races, thin authZ/tenant gates, form hydration wipes, wrong response envelopes, tests that no-op green, dead/unused code and stale leftover comments, and repeated logic that should be shared (3+ real uses). Includes a conservative architecture sense-check that only speaks at the end if the approach is clearly poor or a clearly better path exists in this codebase (silence when fine; never blocks merge). Optionally validates changes against a PRD to ensure implementation correctness and completeness. Spawns one specialist agent per review concern in parallel for speed. After the report, MUST stop with the numbered findings list — do not walk findings one at a time and do not use the Question tool. In later turns, answer questions about findings, or when the user asks to add/post a number list (e.g. 1-3, 5, 19, 24-26) or a single number, submit those as inline GitHub PR review comments. Use when user says "/pr-review", "/pr-review 1234", "/pr-review <pr-url>", "/pr-review <prd-file>", "review my code", "review this branch", "review PR 1234", or "check my changes". Do not require a prior /worktree-quick.
---

# /pr-review - Deep Code Review Agent

Performs a comprehensive, multi-pass review of a PR or branch, always from a code-only worktree (same as `/worktree-quick`). Hunts for performance bottlenecks, security vulnerabilities, race conditions, code quality issues, and "just make it work" patterns — silent fallbacks, swallowed errors, and soft-fail paths that hide real bugs. When a PRD is provided, also validates that the implementation matches the requirements.

**Speed model:** After gathering context, **every review concern runs as its own specialist agent in parallel**. The main agent only gathers context, launches the fan-out, and synthesizes findings. Do not run security → performance → quality as sequential main-agent passes.

**Usage:** `/pr-review [PR number | PR URL | branch] [optional-prd-file-path]`

`/pr-review 1234` is enough — this skill creates the code-only worktree itself. Do **not** require a prior `/worktree-quick`.

After the report, the agent **stops** with the numbered findings list. It does **not** walk findings one at a time and does **not** use the Question tool. Later, the user may ask questions, or ask to **add/post** a number list (e.g. `1-3, 5, 19, 24-26`) or a single number — only then submit those as **inline** GitHub PR review comments.

---

## Core Philosophy

- **Be ruthlessly thorough.** Every diff line is examined. Nothing slips through.
- **Performance is not optional.** O(n²) loops, N+1 queries, missing indexes, unbounded fetches, synchronous blocking — all get flagged.
- **Security is non-negotiable.** Injection vectors, auth bypasses, secret leaks, unsafe deserialization, missing input validation — all get flagged.
- **"Just make it work" is not acceptable.** Silent fallbacks, swallowed errors, and soft-failure paths that hide real bugs must be flagged. Prefer hard failures with clear errors over continuing in a wrong state.
- **Soft types cause soft fails.** Many fallbacks exist only because a value was typed loosely (`T | undefined`, optional fields, `Partial`, untyped JSON, weak inference). Prefer **hard, exact types** that encode invariants so the compiler forces callers to handle reality — **never** "fix" with `any`, `as any`, or other type-erasing shortcuts.
- **End-to-end completeness is required.** A field or feature that saves in the UI but is not read by exporters, imports, dual pipelines, or shared call sites is incomplete — flag write-only and partial migrations.
- **DB and races beat app conventions.** Uniqueness and "one of X" must be enforced where concurrency lives (unique indexes, transactions), not only in happy-path application code.
- **AuthZ is the real gate, not tenant membership alone.** "Row is in my tenant" is not enough when assignment/role gates already exist.
- **PRD compliance is binary.** When a PRD is provided, every requirement either has a matching implementation or it doesn't. No guessing.
- **Actionable feedback only.** Every finding includes the file, line, what's wrong, why it matters, and how to fix it.
- **Recurring PR failure patterns are a required pass.** These are patterns that repeatedly blocked real merges — treat hits as HIGH/CRITICAL when they match production failure modes.
- **Parallel specialists, never sequential mega-passes.** Launch one agent per concern type; synthesize after all return.
- **Architecture sense-check is advisory and silent by default.** It asks whether the approach makes sense in this codebase, but only speaks when there is a clear better path or a clearly poor fit — never as a merge blocker or rewrite demand.

---

## Execution Flow

```
0. Code-only worktree         -> /worktree-quick script + session_move (always; then review)
1. Context Gathering          -> Branch info, base branch, full diff (main agent, in the worktree)
2. Diff Decomposition         -> Split diffs by file, categorize by domain (main agent)
3. PARALLEL SPECIALIST FAN-OUT -> Spawn one agent per concern type AT THE SAME TIME
      ├─ Agent A: Security
      ├─ Agent B: Performance
      ├─ Agent C: Silent Failure / Soft Types
      ├─ Agent D: Recurring PR Patterns (R1–R9)
      ├─ Agent E: Code Quality / Bugs / Races
      ├─ Agent F: Testing Gaps
      ├─ Agent G: PRD Compliance (only if PRD provided)
      ├─ Agent H: Architecture sense-check (advisory; silence when fine)
      ├─ Agent I: Dead code / unused / stale comments
      └─ Agent J: Duplication / extract-to-shared
 4. Synthesis & Report         -> Deduplicate, rank, unified report (main agent)
                                -> Architecture note only if Agent H is not "fine"
                                -> STOP. Numbered list is the end of this turn.
 5. Follow-up (later turns)    -> Answer questions; post inline comments only when
                                 the user asks to add/post numbers (e.g. 1-3, 5, 19)
```

**Critical rule:** In Phase 3, issue **all** specialist agent spawns in a single parallel batch (multiple tool calls together). Do **not** wait for Agent A before spawning Agent B. Only after every specialist has returned, run Phase 4 synthesis.

**Stop-after-report rule:** After the report, **stop**. Do **not** call the Question tool. Do **not** walk findings one at a time. Do **not** post to GitHub in the report turn. In later turns, answer questions about findings, or when the user asks to add/post a number list or a single finding, post **only** those as **inline** review comments (file + line). Never a top-level PR issue comment in place of an inline comment.

**Architecture sense-check rule:** Agent H is advisory only. Its output never becomes CRITICAL/HIGH merge blockers and never asks anyone to re-architect. If the verdict is `fine`, omit architecture entirely from the final report.

---

## Phase 0: Code-only worktree (always, before any review)

Review **never** runs in the primary checkout. Isolate first with the same script as `/worktree-quick`, then review inside that worktree. **Do not** wait for the user to run `/worktree-quick`. **Do not** use `/monorepo-worktree` (no DB, ports, seed, or serve). **Do not** stop after create — continue immediately into Phase 1 in this same session.

User arguments: `$ARGUMENTS`

### Parse target

Split `$ARGUMENTS` into **TARGET** + optional **PRD path**:

| Token | Meaning |
|-------|---------|
| `1234` / `#1234` / `pr 1234` / GitHub `.../pull/1234` | PR |
| `feature/foo` / `origin/foo` / other git ref | Branch |
| Path ending in `.md` or an existing file | PRD (not a worktree target) |
| Empty | `gh pr view --json number -q .number`. If that fails and cwd is already a `*-quick-*` worktree, TARGET = current worktree (skip create). Else ask for a PR number — do not invent a task worktree. |

Resolve a relative PRD path to an **absolute** path against the **pre-move** cwd before leaving the primary checkout.

Remember `PR_NUMBER` when TARGET is a PR. Later `gh pr view` / review POSTs must use `gh pr view ${PR_NUMBER}` — the local branch will be `quick/pr-N`, which GitHub does not treat as the PR head.

### Skip create only when already isolated

Skip create if cwd is already a `*-quick-*` worktree (basename `*-quick-*` or gitdir marker `worktree-quick`) **and** it matches TARGET (same PR number / same slug). Still fetch+reset (below) so the review is current.

### Create or reuse

Script: `~/.ai/oc_skills/worktree-quick/scripts/quick-worktree.sh`

Must run from the git repo under review (or set `REPO_ROOT`). Do **not** hand-roll `git worktree add`.

```bash
~/.ai/oc_skills/worktree-quick/scripts/quick-worktree.sh 1234
~/.ai/oc_skills/worktree-quick/scripts/quick-worktree.sh pr 1234
~/.ai/oc_skills/worktree-quick/scripts/quick-worktree.sh https://github.com/org/repo/pull/1234
~/.ai/oc_skills/worktree-quick/scripts/quick-worktree.sh feature/foo
```

Parse `path:` from the success banner.

If the script fails with `worktree path already exists: <path>`: **reuse `<path>`**. Do not destroy. Fetch the PR/branch and `git -C <path> reset --hard` to that SHA so the review is current:

```bash
# PR
git fetch origin pull/${PR_NUMBER}/head
git -C "<path>" reset --hard FETCH_HEAD

# Branch
git fetch origin <branch>
git -C "<path>" reset --hard origin/<branch>
```

### Yarn (mandatory, every worktree)

After the path is known — **fresh create, reuse, or already-isolated** — run and wait for exit 0:

```bash
(cd "<path>" && yarn install)
```

Timeout 10 minutes. Never skip because `node_modules` exists. Never skip on reuse. Never skip because the task "doesn't need node_modules". If the create script already ran yarn in this turn and you **watched it exit 0**, that create counts; reuse / already-isolated **must still yarn**.

### Move the session, then review

1. OpenCode: `tools.opencode.session_move` with `directory` = the absolute worktree path. Continue **this** session. Do not spawn a subagent to perform the review.
2. If session_move is unavailable: `cd` / set `working_directory` on every later command to that path.
3. Every later git / Read / Grep / specialist must run in that worktree, not the primary checkout.
4. One-line note: path, `quick/…` branch, PR URL, destroy command (`~/.ai/oc_skills/worktree-quick/scripts/quick-worktree.sh destroy <slug> --yes`). Then **immediately** start Phase 1.

Do **not** destroy the worktree after the report (follow-up posting still needs the checkout).

---

## Phase 1: Context Gathering

Run all of these in parallel to gather the full picture:

### 1.1 Branch & Diff Info

```bash
# Current branch name
git branch --show-current

# Base branch (detect main or master)
git remote show origin | grep 'HEAD branch' | awk '{print $NF}'

# Full diff against base
git diff $(git merge-base HEAD origin/main)..HEAD

# Stat summary
git diff --stat $(git merge-base HEAD origin/main)..HEAD

# All commits on this branch
git log --oneline $(git merge-base HEAD origin/main)..HEAD
```

### 1.2 Changed Files List

```bash
git diff --name-only $(git merge-base HEAD origin/main)..HEAD
```

### 1.3 Project Context

- Read CLAUDE.md, README.md, or package.json to understand the tech stack
- Identify: language, framework, test framework, linting/formatting tools
- Note any existing security or performance tooling (ESLint security plugins, etc.)

### 1.4 PRD Loading (if provided)

If a PRD file path was given as an argument:
1. Read the PRD file
2. Extract all requirements, acceptance criteria, user stories, API contracts, and task checklists
3. Build a requirements checklist to verify against in the PRD specialist

If no PRD is provided, do **not** spawn the PRD Compliance agent.

---

## Phase 2: Diff Decomposition

Split the full diff into logical review units (for prioritization notes in agent prompts):

### 2.1 Categorize Each Changed File

| Category | File Patterns | Review Focus |
|----------|--------------|--------------|
| **API / Routes** | `**/api/**`, `**/routes/**`, `**/handlers/**`, `**/controllers/**` | Auth, input validation, error responses, rate limiting |
| **Database / Models** | `**/models/**`, `**/schema/**`, `**/migrations/**`, `**/prisma/**`, `**/drizzle/**` | SQL injection, missing indexes, data integrity, migrations |
| **Auth / Security** | `**/auth/**`, `**/middleware/**`, `**/guard/**`, `**/policy/**` | Auth bypass, session handling, token validation, RBAC |
| **Frontend Components** | `**/*.tsx`, `**/*.jsx`, `**/*.vue`, `**/*.svelte` | XSS, state leaks, excessive re-renders, accessibility |
| **Business Logic** | `**/services/**`, `**/lib/**`, `**/utils/**`, `**/helpers/**` | Logic errors, edge cases, error handling, complexity |
| **Configuration** | `*.config.*`, `.env*`, `**/config/**`, `docker*` | Secret exposure, insecure defaults, missing validation |
| **Tests** | `**/test/**`, `**/tests/**`, `**/*.test.*`, `**/*.spec.*` | Coverage gaps, brittle assertions, missing edge cases |
| **Infrastructure** | `**/ci/**`, `**/.github/**`, `**/terraform/**`, `**/k8s/**` | Insecure pipelines, missing checks, exposed secrets |

### 2.2 Priority Order (for agent context, not sequential review)

Highest risk first when agents must chunk large diffs:
1. Auth / Security files
2. API / Routes
3. Database / Models
4. Configuration
5. Business Logic
6. Frontend Components
7. Infrastructure
8. Tests

---

## Phase 3: Parallel Specialist Fan-Out

Spawn **one dedicated agent per concern** below. Use the platform's multi-agent tool (`Task` / `spawn_subagent` / equivalent). **Launch every agent in the same turn** so they run concurrently.

### Shared payload for every agent

Every specialist prompt MUST include:

```
## Branch
[branch-name] vs [base-branch]

## Tech Stack
[detected stack]

## Changed Files
[file list from Phase 1.2]

## Full Diff
[full diff from Phase 1.1]

## File Categories (optional hint)
[Phase 2 categorization summary]
```

If the diff is extremely large (>5000 lines), chunk the diff and note which chunk this agent owns — or spawn **multiple agents of the same specialty** per chunk (e.g. Security-chunk-1, Security-chunk-2). Prefer parallel chunking over sequential reading by the main agent.

### Shared output format (every specialist except Agent H)

```
For each finding, report:
| Field | Value |
|-------|-------|
| Severity | CRITICAL / HIGH / MEDIUM / LOW |
| Category | [agent-specific category tag] |
| File | exact file path |
| Line(s) | line number(s) in the diff / file |
| Issue | short title |
| Description | what's wrong and why it matters |
| Fix | specific code change to remediate |

If NO issues are found for your specialty, explicitly state "No <specialty> issues found" —
do NOT invent issues that don't exist.
Do not review concerns outside your specialty (other specialists own those).
Do not modify any code. Review only.
```

Agent H uses its own verdict format (see Agent H section) — not Severity findings.
Agents I (`DeadCode`) and J (`Duplication`) use the shared Severity findings format above.

---

### Agent A — Security

- **subagent_type**: `backend-architect` (or `general-purpose` if unavailable)
- **description**: `PR review: security`
- **Category tag**: `Security`

```
You are performing a SECURITY-FOCUSED code review ONLY. Ignore performance, style, and tests
except where they create security risk.

[Shared payload]

## Security Checklist - Check EVERY item against the diffs:

### Injection Attacks
- [ ] SQL injection (raw queries, string concatenation in queries)
- [ ] NoSQL injection (unsanitized MongoDB queries)
- [ ] Command injection (exec, spawn with user input)
- [ ] LDAP injection
- [ ] XSS (innerHTML, dangerouslySetInnerHTML, unescaped template output)
- [ ] Template injection (server-side template engines)

### Authentication & Authorization
- [ ] Missing auth checks on new endpoints
- [ ] Broken access control (user A accessing user B's data)
- [ ] JWT issues (missing expiry, weak secret, algorithm confusion)
- [ ] Session fixation or insecure session handling
- [ ] Missing RBAC/permission checks
- [ ] Privilege escalation paths
- [ ] **Thin tenant checks only** — "row exists in caller's tenant" without assignment/role gates used elsewhere for the same resource
- [ ] **Over-broad procedures** — PENDING/onboarding/unprivileged roles can perform privileged side effects
- [ ] **Identity vs capability conflation** — gating "who is this person?" lookups with "can they take a lead / pull credit?" filters (or the reverse)
- [ ] Auth/permission checks that **fail open** (`catch { return true }`)

### Data Exposure
- [ ] Secrets in code (API keys, passwords, tokens)
- [ ] Sensitive data in logs (passwords, tokens, PII)
- [ ] Overly permissive CORS
- [ ] Missing data sanitization in API responses (exposing internal fields)
- [ ] Directory traversal in file operations
- [ ] **Env-var names / internal config in user-facing errors**
- [ ] Cross-tenant leakage via missing tenant filters on global vendor lookups

### Input Validation
- [ ] Missing input validation on API endpoints
- [ ] Missing type checking/schema validation
- [ ] Unbounded input sizes (DoS via large payloads)
- [ ] Missing rate limiting on sensitive endpoints

### Cryptography
- [ ] Weak hashing (MD5, SHA1 for passwords)
- [ ] Missing encryption for sensitive data at rest
- [ ] Hardcoded cryptographic keys
- [ ] Insecure random number generation for security contexts

### Dependencies
- [ ] Known vulnerable dependencies being added
- [ ] Pinned versions vs. floating versions

For each finding also include: Exploit Scenario (how an attacker could exploit this).
```

---

### Agent B — Performance

- **subagent_type**: `backend-architect` (or `general-purpose` if unavailable)
- **description**: `PR review: performance`
- **Category tag**: `Performance`

```
You are performing a PERFORMANCE-FOCUSED code review ONLY. Ignore security vulns and style
except where they create perf risk.

[Shared payload]

## Performance Checklist - Check EVERY item against the diffs:

### Database & Queries
- [ ] N+1 query patterns (queries inside loops)
- [ ] Missing database indexes for new query patterns
- [ ] Unbounded SELECT queries (missing LIMIT/pagination)
- [ ] Missing WHERE clauses (full table scans)
- [ ] Redundant queries (same data fetched multiple times)
- [ ] Missing eager loading / over-fetching relations
- [ ] Large transactions holding locks too long
- [ ] Missing connection pooling

### Algorithmic Complexity
- [ ] O(n²) or worse loops (nested iterations over large datasets)
- [ ] Unnecessary array copies or object spreads in loops
- [ ] Missing early returns / short circuits
- [ ] Sorting where not needed
- [ ] Repeated expensive computations (missing memoization)

### Memory & Resources
- [ ] Memory leaks (event listeners not cleaned up, intervals not cleared)
- [ ] Unbounded caches or collections that grow forever
- [ ] Large objects held in closure scope unnecessarily
- [ ] Missing stream processing for large data
- [ ] File handles or connections not closed

### Network & I/O
- [ ] Sequential API calls that could be parallelized (Promise.all)
- [ ] Missing request timeouts
- [ ] Missing retry logic with backoff
- [ ] Large payloads without compression
- [ ] Missing pagination on list endpoints
- [ ] Synchronous file operations blocking the event loop

### Frontend Performance
- [ ] Unnecessary re-renders (missing useMemo, useCallback, React.memo)
- [ ] Large bundle imports (importing entire libraries for one function)
- [ ] Missing code splitting / lazy loading
- [ ] Layout thrashing (reading/writing DOM in loops)
- [ ] Unoptimized images or assets
- [ ] Missing virtualization for long lists
- [ ] Expensive computations on the main thread

### Caching
- [ ] Missing caching for expensive operations
- [ ] Cache invalidation issues
- [ ] Missing HTTP cache headers

For each finding also include: Impact (latency, memory, CPU estimate).
```

---

### Agent C — Silent Failure / Soft Types

- **subagent_type**: `general-purpose`
- **description**: `PR review: silent failures`
- **Category tag**: `SilentFailure` (and `SoftType` when type-rooted)

```
You are performing a "JUST MAKE IT WORK" / SILENT-FAILURE / SOFT-TYPES code review ONLY.
Prefer hard failures with clear errors over continuing in a wrong state — unless the fallback
is intentional, documented, user-visible graceful degradation.

[Shared payload]

## Checklist

### Silent / swallowed failures
- Empty `catch` blocks, or catch that only logs and continues as if success
- `.catch(() => undefined)`, `.catch(() => null)`, `.catch(() => [])`, `.catch(() => {})`
- `try/catch` that returns a default success value on failure
- Promise rejection handlers that discard the error without rethrowing/surfacing
- Fire-and-forget async (`void fn()`, unawaited promises) where failure should affect the caller

### Fallbacks that should hard-fail instead
- Defaulting critical config/env (`process.env.X || 'localhost'`, fake API keys, wrong URLs)
- Returning empty arrays/objects/`null` when required dependency (DB row, API, auth) is missing
- `|| []`, `?? []`, `?? {}`, `?? ''` papering over unexpected null/undefined
- Long optional chaining (`a?.b?.c?.d`) on a required path
- Fallback to mock, cached-stale, or placeholder data in production without product requirement
- Retry loops that "succeed" with partial/empty data instead of failing after exhaustion
- Parsing wrapped so invalid input becomes a silent default

### Soft types that force soft fails (root-cause pass)

For every soft-fail/fallback finding:
1. Trace the type of the value being defaulted / optional-chained / cast.
2. Determine the exact expected type from domain/API/schema/callers.
3. Prefer hardening the type so the fallback becomes unnecessary.
4. Never suggest `any`, `as any`, un-narrowed `unknown`, or type-erasing shortcuts.

Flag:
| Soft type smell | What to do instead |
|-----------------|--------------------|
| `T \| undefined` / `T \| null` always present after success | Success type is `T`; nullability only on lookup; narrow once then throw/404 |
| Optional fields required by product/API | Required field or draft vs loaded types |
| `Partial<T>` for fully-loaded entities | Separate CreateInput/Patch from full entity |
| Unvalidated JSON / `Record<string, unknown>` deep in domain | Parse at boundary into exact type |
| Over-wide unions (`string` for closed set) | Literal unions or enums |
| Empty success when absence is error | Return `T` + throw, or Result union |
| Optional params only to make call sites compile | Fix call sites |
| Prisma selects omit fields then code defaults them | Select required fields; type result correctly |

### Type / assertion papering
- `as any`, `as unknown as T`, non-null `!` to silence type errors
- Type guards that always return true; bare `@ts-ignore` / `@ts-expect-error`
- Soft API/config types compensated with runtime fallbacks instead of post-validation hard types

### Behavioral soft-fail smells
- Feature flags that disable broken behavior with no error/metric
- Partial success returned as full success (2 of 5 writes fail, API 200)
- Validation that logs a warning and continues
- Auth/permission fail-open (`catch { return true }`)
- "Best effort" comments that excuse missing correctness without explicit design

## Severity guidance
| Pattern | Typical severity |
|---------|------------------|
| Auth fails open; financial/data-loss soft-fails | CRITICAL / HIGH |
| Required data → empty default; config fallback hides misconfig | HIGH |
| Soft type forces cascade of `??` / `||` / `?.` | HIGH (root-cause the type) |
| Suggested/existing fix using `any` / type-erasure | HIGH |
| Swallowed errors on non-critical path | MEDIUM |
| Defensive `??` on truly optional documented fields | Not a finding |

For each finding state:
1. What the code does on failure today
2. What should happen instead (throw / 4xx/5xx / fail the job)
3. Whether the root cause is a soft type — if yes, the exact hard type and validation boundary
4. A concrete fix that hardens types and removes the fallback — not more defaults, not `any`
```

---

### Agent D — Recurring PR Patterns (R1–R9)

- **subagent_type**: `general-purpose`
- **description**: `PR review: recurring patterns`
- **Category tag**: `RecurringPattern` (plus R# in Issue title)

```
You are performing the RECURRING PR FAILURE PATTERNS review ONLY (R1–R9).
These patterns repeatedly blocked real merges. When a hit can cause data loss, wrong
credit/AUS/messaging behavior, cross-tenant routing, or "looks healthy while broken,"
severity is CRITICAL or HIGH.

[Shared payload]

Walk EVERY checklist item. For R2/R6, **read consumers outside the diff** (transformers,
importers, twin pipelines, sibling procedures) when the change introduces fields or dual-path logic.

### R1 — Soft failure that looks like success
- Catch/log-and-continue while status still claims ACTIVE / ready / success
- Empty-string/object fallbacks on **required** export/vendor payloads instead of preflight throw
- Setup/side-effect failures swallowed so operators treat feature as live
- Tests skip/pass when fixtures/reference inputs absent
- Polling-only UIs with no recovery if webhooks never land

### R2 — Incomplete end-to-end wiring (write-only features)
For every new/changed field or source-of-truth move, trace:
UI → API/schema → DB → read/list → export transformers (all engines) → import/mappers → jobs → shared call sites
- Shared component only partially adopted
- Clear/reset persists null but live side effects never update
- Refactor deletes old write path without re-homing data

### R3 — App-only invariants and races
- "One of X" uniqueness only in app code — no DB unique/partial unique/FK
- Check-then-act without atomicity or unique-violation handling
- Position/counter `last + 1` without unique + retry
- Tenant-scoped unique on a **globally** unique shared-vendor resource
- Multi-step writes missing transaction when partial success corrupts state

### R4 — Thin authZ / tenant / secret boundaries
- Weaker gates than sibling resources
- Over-broad caller sets for privileged side effects
- Identity lookup mixed with capability filters
- User-facing errors leak env-var names
- PII/secrets in logs; dual-pipeline credential redaction gaps

### R5 — Form hydration / mount effects wipe real data
- useEffect writes form state on mount without hydration sentinel
- Auto-flip / clear-stale that nulls persisted enums/booleans on first paint
- Partial updates that null omitted fields

### R6 — Dual-path / dual-surface inconsistency
- Parallel transformers use different predicates for the same domain concept
- CRM vs funnel (or admin vs LO) encode different rules
- Two canonical schemas/enums disagree
- Sticky DB columns fight live derivation
- Actor identity differs across steps without explicit product rule

### R7 — Response envelopes, partial updates, type lies
- Casts to guessed shapes when real response is an envelope
- Partial update sets omitted fields to null instead of skipping
- Schema/migration drift; mocks missing new columns
- `as any` / double casts / envelope lies

### R8 — UX recovery and edge states
- Async flows missing loading / error / cancel / retry / stale-expired handling
- Broken image/URL with no fallback; double-submit not blocked
- List/create can 500 with no error state
- Eager per-row work without unmount cleanup / virtualization

### R9 — Consistency / scope
- Reinvents existing gate/helper/component nearby
- Unrelated scope creep
- Arbitrary design tokens / z-index when project defines a scale
- Tab-like UI with incomplete a11y

For each finding:
1. Which R# pattern
2. What fails in production (concrete)
3. Concrete fix — prefer DB constraints, existing auth helpers, hard preflight throws, full consumer wiring, envelope-typed clients, tests that fail if the bug returns — not more `??` defaults
```

---

### Agent E — Code Quality / Bugs / Races

- **subagent_type**: `general-purpose`
- **description**: `PR review: code quality`
- **Category tag**: `Quality`

```
You are performing a CODE QUALITY / BUG / RACE-CONDITION review ONLY.
Do not deep-dive security vulns, N+1 perf, silent-failure catalogs, or R1–R9 (other agents own those)
unless the bug is pure correctness unrelated to those catalogs.

[Shared payload]

### Bug Detection
- Race conditions (shared mutable state, async ordering issues)
- Off-by-one errors
- Null/undefined dereferences without guards
- Unhandled promise rejections / missing try-catch
- Type coercion bugs (== vs ===, implicit conversions)
- Copy-paste errors that introduce subtle behavioral bugs (Agent I/J own pure dead code and pure extract-to-shared)

### Error Handling (correctness, not soft-fail catalog)
- Missing error handling on async operations
- Generic error messages that leak internal details
- Missing cleanup in error paths (finally blocks)
- Error responses missing proper HTTP status codes

### Code Patterns
- Inconsistent patterns compared to the rest of the codebase
- Magic numbers or strings without constants
- Missing TypeScript types; `any` / un-narrowed `unknown` / overuse of `Partial` / unnecessary optionals
- Overly complex functions (high cyclomatic complexity)
- Missing comments on non-obvious complex logic (Agent I owns stale/useless leftover comments)

Do NOT deep-dive unused imports, dead symbols, commented-out blocks, or "extract because N copies" — Agents I and J own those.

Read surrounding context, not just the diff hunk.
```

---

### Agent F — Testing Gaps

- **subagent_type**: `test-writer-fixer` (or `general-purpose` if unavailable)
- **description**: `PR review: testing gaps`
- **Category tag**: `Testing`

```
You are performing a TESTING GAPS review ONLY. Identify missing/weak tests; do not rewrite
the product code. Do not invent security/perf findings.

[Shared payload]

### Testing Gaps Checklist
- New code paths without corresponding tests
- Modified behavior without updated tests
- Edge cases not covered
- Missing tests that assert **failure** paths (bad input / missing data errors out rather than soft-succeeding)
- Tests that **no-op green** when fixtures/reference files are missing (hardcoded absolute paths, optional reads, early `return` without assert)
- Fixtures that hardcode the happy path so the assertion cannot fail
- Behavior/UI contract changes without updating e2e/integration assumptions
- Prefer noting at least one test that would **fail** if a silent-success or write-only bug returned

For each finding: what test is missing, where it should live, and what assertion would catch the bug.
```

---

### Agent G — PRD Compliance (only if PRD provided)

- **subagent_type**: `general-purpose`
- **description**: `PR review: PRD compliance`
- **Category tag**: `PRD`
- **Skip entirely** when no PRD path was given.

```
You are validating that code changes correctly implement a PRD. Compliance only —
do not re-do security/performance/quality scans.

## PRD Content
[full PRD text]

## All Diffs on the Branch
[full diff]

## Changed Files
[file list]

Go through EVERY requirement and classify:

| Status | Meaning |
|--------|---------|
| IMPLEMENTED | Fully satisfies |
| PARTIALLY IMPLEMENTED | Some aspects done |
| NOT IMPLEMENTED | No matching code |
| DEVIATED | Differs from PRD |
| NOT APPLICABLE | e.g. deployment-only |

Check: API contracts, data model, frontend components, business logic, acceptance criteria
(Given/When/Then), and task checklist items.

### Output Format

## PRD Compliance Report

### Summary
- Total Requirements: [N]
- Implemented / Partially / Not Implemented / Deviated: counts

### Detailed Findings
#### [Requirement]
- **Status**: ...
- **Evidence**: File:line or "No matching code found"
- **Gap** (if any): ...
- **Severity of Gap**: BLOCKING / SHOULD_FIX / NICE_TO_HAVE

### Deviations from PRD
### Missing Implementations (priority-ordered)
```

---

### Agent H — Architecture sense-check (advisory only)

- **subagent_type**: `general-purpose` (or `plan` if available)
- **description**: `PR review: arch sense`
- **Category tag**: `ArchitectureSense` (advisory — not a merge-blocking category)
- **Always spawn** (unlike Agent G).

```
You are performing an ARCHITECTURE SENSE-CHECK only. Advisory. Conservative.

Your job is to answer one question:

> "Does the way this is implemented actually make sense as it is now?"

[Shared payload]

Also read surrounding codebase context (similar features, existing helpers, layering conventions)
— not just the diff hunks.

Ask: given this codebase and the problem being solved, is the architecture a reasonable fit?
Could a competent engineer reading this in six months understand why it was built this way?

### Stance — default to "fine"

- You are **not** quick to demand a re-architecture. Most working designs that fit local patterns are fine.
- Only speak up when there is a **very clear** more proper way that fits this codebase better for the
  grand change, OR when the current approach is **clearly poor** (wrong layer, fights existing
  abstractions, invents a parallel system for something already solved, will force painful follow-ups).
- Style preferences, micro-optimizations, naming bikesheds, and "I would have done it slightly
  differently" are NOT findings.
- Preferable-but-not-clearly-better alternatives are NOT findings. Silence is correct when the design
  is acceptable.

### What you may conclude

| Verdict | When | What you write |
|---------|------|----------------|
| **fine** | Design is reasonable for this codebase | Exactly: `Verdict: fine` — no other text |
| **clear-better-path** | A clearly better architecture exists that fits the grand change and surrounding code | Short note (see format) |
| **poor-fit** | Current approach is a poor fit | Short note (see format) |

### Critical constraints

- Do **not** invent Severity / CRITICAL / HIGH findings for the main findings tables.
- Do **not** demand a rewrite or re-architecture as a merge blocker.
- Do **not** re-do security, performance, silent-failure, R1–R9, quality, testing, dead-code, duplication, or PRD reviews.
- Keep notes short. If fine, one line only.

### Output format — not Severity findings

# Architecture sense-check

## Verdict
fine | clear-better-path | poor-fit

## Note
(Omit this section entirely when Verdict is fine.)
When not fine: 2–6 sentences covering:
- What was built and why it appears shaped this way
- Why that shape is a poor fit OR why a better path is clearly preferable in this codebase
- The alternative that makes more sense (concrete modules/layers/patterns, not vague advice)
- Frame as advice for the reader — not instructions to rewrite before merge
```

---

### Agent I — Dead code / unused / stale comments

- **subagent_type**: `general-purpose`
- **description**: `PR review: dead code`
- **Category tag**: `DeadCode`

```
You are performing a DEAD CODE / UNUSED / STALE COMMENT review ONLY.
Your job is to remove noise left by refactors — unused symbols and comments that explain
what used to be there rather than what the code does now.

[Shared payload]

Also grep/read surrounding files to confirm something is truly unused (not just unused inside
the diff hunk). Prefer proof of zero references over vibes.

## Checklist

### Unused imports & symbols introduced or left by this change
- Unused imports (named, default, type-only, side-effect imports that are no longer needed)
- Unused locals, params, private helpers, types, interfaces, enums, constants
- Exports added in this PR with no in-repo consumers (or consumers only in deleted code)
- Re-exports / barrel entries that nothing imports
- Feature flags, config keys, or env reads that are never read after the change
- Dead branches / unreachable code after condition changes
- Variables assigned and never read; catch bindings unused without reason

### Stale / useless comments (delete, do not "improve")
- Comments that narrate removed behavior: "used to…", "previously…", "was…", "no longer…",
  "removed X", "old path", "legacy before refactor"
- Block comments that are just deleted code in prose, or large commented-out code blocks
- JSDoc/TSDoc on deleted params/fields, or docs that contradict the current signature
- TODOs/FIXMEs that are already done (or refer to code that no longer exists)
- Section banners / leftover separators for code that was deleted
- "Explain what the next line does" noise on obvious code — only flag when added/left by this PR
  and adds no non-obvious intent; do not bikeshed every pre-existing comment outside the change

### What NOT to flag
- Imports/symbols that are used (including type positions, decorators, DI, framework reflection)
- Public API surface that is part of a published package / intentional external contract
- Comments that explain non-obvious WHY, invariants, security, or protocol constraints
- Temporarily commented code that the PR clearly marks as WIP with an active tracking TODO + issue
- Test fixtures that look "unused" but are required by runners/frameworks

## Severity guidance
| Pattern | Typical severity |
|---------|------------------|
| Unused import / trivial dead local left by refactor | LOW |
| Dead private helper / unreachable branch in changed files | MEDIUM |
| Large commented-out blocks or stale "used to" comments that mislead | MEDIUM |
| Exported/public-looking dead API that confuses callers | MEDIUM / HIGH |
| Misleading comment that contradicts current security/auth behavior | HIGH |

For each finding:
1. Proof it is unused or stale (e.g. "grep for X across repo: 0 refs outside definition")
2. Exact delete/edit (usually delete the import/symbol/comment — not a rewrite)
3. Do not suggest broad cleanups outside the PR's blast radius unless the dead code was introduced here
```

---

### Agent J — Duplication / extract-to-shared

- **subagent_type**: `general-purpose`
- **description**: `PR review: duplication`
- **Category tag**: `Duplication`

```
You are performing a DUPLICATION / EXTRACT-TO-SHARED review ONLY.
Flag repeated logic that should become a shared helper — not every similar-looking line.

[Shared payload]

Read beyond the diff: search the repo for copies of the same logic (same predicates, same
transform sequences, same UI blocks, same validation, same mapping tables).

## When to flag (ALL must hold)

1. **Count ≥ 3** real occurrences of the same logic (in the PR and/or existing codebase after
   this change lands). Two copies is usually not enough unless the PR is clearly about to add more.
2. **Would realistically be used more** — another call site is likely soon (same domain concept,
   sibling features, list+detail+export, CRM+funnel, multiple transformers, repeated form fields).
3. **Stable enough to name** — not a one-off coincidence of similar shape with different invariants.
4. **Extraction improves clarity** — a named helper would reduce drift risk, not hide important differences.

If copies deliberately differ on domain rules, do NOT force a shared abstraction — note the risk
of false unification instead only if the PR already pretends they are the same.

## Scope of the shared home (required on every finding)

Choose scope from **where the copies live and how many consumers exist**, not from taste:

| Occurrences / fan-out | Proposed scope |
|-----------------------|----------------|
| 3+ in one file only | Private helper in that file |
| 3+ across one feature folder / module | Module-level `utils` / `helpers` beside the feature |
| 3+ across packages in one app (e.g. web-crm only) | App-level shared module already used for similar things |
| 3+ across apps or backend+frontend domain rules | Existing monorepo `libs/` package (or the package that already owns this domain) |
| Matches an **existing** helper almost exactly | Reuse/extend that helper — do not invent a parallel one |

Always name:
- Exact occurrence count and file:line list (or representative list if many)
- Proposed symbol name and file path for the shared home
- What varies per call site (parameters) vs what stays identical
- Whether an existing helper already covers this (prefer extend over new)

## What NOT to flag
- Two similar blocks with no likely third consumer
- Framework boilerplate that must stay local (trivial one-liners, obvious map/filter)
- Copy-paste that is test data/fixtures where duplication is intentional
- "Duplication" that would require a premature god-helper with many flags/options
- Style-only similarity (same control-flow shape, different business meaning)
- Huge cross-cutting refactors unrelated to this PR's risk — keep proposals proportional

## Severity guidance
| Pattern | Typical severity |
|---------|------------------|
| 3 local copies, easy file-private helper | LOW / MEDIUM |
| 3+ copies already drifting (subtle bug differences) | HIGH |
| 3+ copies across dual paths (CRM/funnel, twin transformers) with same domain rule | HIGH |
| Should reuse existing shared helper but reinvented | MEDIUM / HIGH |
| Speculative extract with only 2 weak lookalikes | Not a finding |

For each finding include: count, locations, proposed scope + path, and a concrete signature —
not "consider DRY".
```

---

### Fan-out rules

1. **One tool-call batch** — spawn Agents A–F, H, I, J always, and G if PRD, together; do not serialize.
2. **capability_mode**: prefer `read-only` when available so specialists cannot edit code.
3. **Do not** have the main agent re-run the same checklists after specialists return — only synthesize.
4. If a specialist agent fails or returns empty without the required "No X issues found" line (or for Agent H, without a Verdict), re-spawn **that specialty only** once. Do not re-run the whole fan-out. If Agent H fails twice, treat as `Verdict: fine` and continue.
5. Specialists must stay in their lane. Overlap is OK; synthesis deduplicates.
6. **Agent H is never merge-blocking.** Do not promote architecture notes into Critical/High findings tables.

---

## Phase 4: Synthesis & Final Report

After **all** specialists complete, the main agent compiles a unified report.

### 4.1 Collect & Deduplicate

- Merge findings from Agents A–F, I, J (and G if present). **Exclude Agent H** from the findings tables.
- If two specialists flag the same line, merge into one finding with combined Category tags (e.g. `Security + SilentFailure`).
- Prefer the more specific Fix; keep the higher Severity.
- Hold Agent H's verdict aside for the optional architecture section only.

### 4.2 Severity Ranking

| Severity | Action Required | Examples |
|----------|----------------|----------|
| **CRITICAL** | Must fix before merge | SQL injection, auth bypass, data loss, secret exposure, auth fails-open, cross-tenant routing, soft-success on money/credit/AUS/messaging setup |
| **HIGH** | Should fix before merge | N+1 on hot paths, check-then-act races, write-only fields, silent `?? ''` on required vendor payloads, thin tenant-only authZ, form mount wiping data, dual-path divergence, envelope casts, no-op-green tests |
| **MEDIUM** | Fix soon, doesn't block merge | Missing memoization, suboptimal patterns, incomplete validation, swallowed non-critical errors, incomplete UX recovery, dead helpers, stale misleading comments, 3+ copy extract candidates |
| **LOW** | Nice to have | Minor style issues, slightly better naming, small optimizations, pure a11y polish, unused imports |

### 4.3 Final Report Template

```markdown
## Code Review Report

**Branch**: [branch-name]
**Base**: [base-branch]
**Files Changed**: [N]
**Commits**: [N]
**Review Date**: [date]
**Specialists**: Security, Performance, SilentFailure, RecurringPattern, Quality, Testing, DeadCode, Duplication, ArchitectureSense-advisory[, PRD]

---

### Verdict: [BLOCK / APPROVE WITH FIXES / APPROVE]

[1-2 sentence summary of overall code quality. Do not let Agent H change the merge verdict.]

---

### Critical & High Findings (Must Fix)

| # | Severity | Category | File | Line(s) | Issue | Fix |
|---|----------|----------|------|---------|-------|-----|
| 1 | CRITICAL | Security | auth.ts | 45 | SQL injection via unsanitized input | Use parameterized query |
| 2 | HIGH | Performance | users.ts | 88-95 | N+1 query in loop | Batch query with IN clause |

### Medium & Low Findings (Recommendations)

| # | Severity | Category | File | Line(s) | Issue | Fix |
|---|----------|----------|------|---------|-------|-----|
| 3 | MEDIUM | Quality | utils.ts | 30 | Missing error handling on API call | Add try-catch with retry |
| 4 | LOW | Quality | types.ts | 12 | Using `any` type | Define proper interface |

### PRD Compliance (if applicable)

| Requirement | Status | Notes |
|-------------|--------|-------|
| ... | ... | ... |

**PRD Coverage**: [X]% of requirements implemented

### Summary Statistics

| Category | Critical | High | Medium | Low |
|----------|----------|------|--------|-----|
| Security | | | | |
| Performance | | | | |
| Code Quality | | | | |
| Silent Failure | | | | |
| Recurring Pattern (R1–R9) | | | | |
| Testing | | | | |
| Dead Code | | | | |
| Duplication | | | | |
| **Total** | | | | |

### Recurring-pattern coverage

| Pattern | Status |
|---------|--------|
| R1 Soft success | clean / N findings |
| R2 Write-only / E2E wiring | clean / N findings |
| R3 Invariants & races | clean / N findings |
| R4 AuthZ / tenant / secrets | clean / N findings |
| R5 Form hydration wipes | clean / N findings |
| R6 Dual-path inconsistency | clean / N findings |
| R7 Envelopes / partial updates | clean / N findings |
| R8 UX recovery | clean / N findings |
| R9 Consistency / scope | clean / N findings |

### Specialist status

| Specialist | Status | Findings |
|------------|--------|----------|
| Security | complete / failed-retry | N |
| Performance | ... | N |
| Silent Failure | ... | N |
| Recurring Patterns | ... | N |
| Code Quality | ... | N |
| Testing | ... | N |
| Dead Code | ... | N |
| Duplication | ... | N |
| Architecture sense-check | complete / failed→fine | fine / clear-better-path / poor-fit |
| PRD | complete / skipped | N |

### Architecture sense-check (user advisory)

<!-- ONLY include this section when Agent H verdict is clear-better-path or poor-fit.
     If Verdict is fine: OMIT this entire section — say nothing about architecture. -->

**Verdict**: clear-better-path | poor-fit

[2–6 sentence note from Agent H, lightly edited for clarity. Frame as "For your consideration"
— not a merge blocker, not work the review agent will perform. Do not invent a rewrite plan.]

### Next Steps
1. Ask about any finding, or reply with numbers to post as inline GitHub comments (e.g. `add 1-3, 5, 19` or `add 7`)
2. Fix all CRITICAL findings before merge
3. Address HIGH findings — these will cause problems in production
4. Consider MEDIUM findings for code quality
5. [If PRD provided] Implement missing requirements: [list]
6. [Only if architecture section present] Architecture note is optional judgment for you — not a required rewrite
```

**User-facing rule for architecture:** After the report, if Agent H said `fine`, do not mention architecture at all. If not fine, the architecture section in the report is enough — do not push a re-architecture unless the user asks.

**After the report, stop.** Do not call the Question tool. Do not walk findings. Do not post to GitHub in this turn. Phase 5 runs only on later user messages.

---

## Phase 5: Follow-up chat — discuss or post selected findings

The report **is** the end of the review turn. After printing it, **stop**. Do **not** call the Question tool. Do **not** walk findings one at a time. Do **not** post to GitHub until a later user message asks you to add/post findings.

Keep the numbered findings in conversation context. The user will chat from there.

### 5.1 Report-turn stop (required)

In the same turn as the report:

- Print the numbered findings tables (and the rest of the report template).
- In Next Steps, tell the user they can ask questions or reply with numbers to post (e.g. `add 1-3, 5, 19` or `add 7`).
- **Stop.** No Question tool. No GitHub. No "Add / Don't add" prompts.

**Zero findings:** Skip Phase 5 entirely.

**Not selectable:** Agent H architecture notes. They stay in the report only.

### 5.2 Later turns — questions vs post

On later messages:

| User intent | What to do |
|-------------|------------|
| Questions / debate about a finding (or several) | Answer. Do **not** post. |
| Explicit add/post of a number list or a single number | Parse the selection (5.3) and post those as **inline** comments (5.4–5.7). |
| `add all` / `post all` | Post every numbered finding. |
| Unclear (chat that is not a post request) | Answer; do **not** post. |

**Do not invent a default selection.** Never auto-post. Never use the Question tool for this flow.

### 5.3 Parse the selection

Trigger words: `add`, `post`, `comment`, `inline` — plus a number list, a single number, or `all`. Parentheses are optional.

A message that is **only** a number list (or a single number) is also a post request.

Examples that **must** post:

- `add 1-3, 5, 19, 24-26`
- `add 7`
- `7`
- `post 1, 4, 9`
- `1-3, 5, 19, 24-26`
- `(1-3, 5, 19, 24-26)`
- `add all`

Parse rules:

1. Strip wrapping `()` / `[]`.
2. Split on commas and whitespace.
3. A token `N-M` is the inclusive range N through M.
4. A token `N` is finding N.
5. `all` = every numbered finding in the report.
6. Deduplicate; ignore numbers that are not in the report (tell the user which were invalid).
7. If they also paste custom comment text for a specific `#`, use that text as that finding's `body`; otherwise use the finding's Issue + Fix.

If the parsed set is empty after validation, stop — no GitHub.

They may post more than once in later turns (e.g. `add 1-3` then later `add 5`). Do not re-post findings already posted in this conversation unless they ask to post again.

### 5.4 Resolve the PR

Only after a later turn requests posting with at least one valid finding number:

```bash
# Prefer the PR number from Phase 0 — local branch is quick/pr-N, not the GitHub head ref
gh pr view ${PR_NUMBER} --json number,url,title,headRefOid,headRefName
gh repo view --json nameWithOwner -q '.nameWithOwner'
```

Split `nameWithOwner` into `OWNER` / `REPO`. Set `NO_COLOR=1` on `gh api` calls.

- If no PR exists for this branch, **stop** and tell the user. Do not create a PR. Do not post issue comments.
- Confirm `headRefOid` is the commit comments will attach to.

### 5.5 Resolve an inline anchor per selected finding

Every posted comment **must** be inline: `path` + `line` on the PR head (`side: RIGHT` for added/changed lines).

For each selected finding:

1. `path` = repo-relative file from the finding (never absolute).
2. `line` = the finding's line in the **new** file. If the report has a range (`88-95`), use `start_line: 88` and `line: 95`.
3. Confirm that line appears in the PR diff (RIGHT side). Use the local diff or:

```bash
NO_COLOR=1 gh api repos/{OWNER}/{REPO}/pulls/{pr}/files --paginate
```

4. If the exact line is not in the diff, snap to the **nearest changed line in the same file** that is in the hunk. Say so in the comment (`Anchored to line N — nearest changed line.`).
5. If the file is not in the PR diff, **do not** post that finding as a top-level comment. Skip it and tell the user it could not be inlined.
6. Deleted-only lines: `side: LEFT` and the old-file line. Prefer RIGHT whenever the line still exists in the new file.

### 5.6 Submit one review containing every selected inline comment

Write the payload to a JSON file and `POST` it with `--input`. Do **not** use `--field 'comments=[...]'` (breaks on markdown/newlines). Do **not** post one review per finding. Do **not** use `gh pr comment` (that is a non-inline issue comment).

```bash
# commit_id MUST be the PR head SHA from 5.4
cat > /tmp/pr_review.json << 'ENDJSON'
{
  "commit_id": "<headRefOid>",
  "event": "COMMENT",
  "body": "Posted N selected finding(s) from /pr-review as inline comments.",
  "comments": [
    {
      "path": "src/auth.ts",
      "line": 45,
      "side": "RIGHT",
      "body": "**[CRITICAL] Security:** SQL injection via unsanitized input\n\n<input validation missing on query string.>\n\n**Fix:** Use a parameterized query."
    },
    {
      "path": "src/users.ts",
      "start_line": 88,
      "line": 95,
      "side": "RIGHT",
      "body": "**[HIGH] Performance:** N+1 query in loop\n\n...\n\n**Fix:** Batch with `IN`."
    }
  ]
}
ENDJSON

NO_COLOR=1 gh api repos/{OWNER}/{REPO}/pulls/{pr}/reviews \
  -X POST \
  --input /tmp/pr_review.json
```

Each comment `body` format:

```markdown
**[SEVERITY] Category:** Issue title

<1–4 sentence description of what's wrong and why it matters>

**Fix:** <concrete remediation>
```

`event` is always `COMMENT` (do not `REQUEST_CHANGES` / `APPROVE` unless the user explicitly asks).

GitHub review comment cap is 100 inline comments per review. If more than 100 are selected, split across multiple review POSTs (same `event` / `commit_id`).

### 5.7 Report what was posted

After a successful POST, tell the user:

- PR URL
- How many inline comments were posted
- Finding numbers that were posted
- Finding numbers skipped (and why — not in diff, no PR, etc.)

Do not re-print the full review report.

---

## Error Handling

| Error | Action |
|-------|--------|
| No changes on branch (clean diff) | Stop, inform user there's nothing to review |
| Worktree script fails (not already-exists) | Stop; show full output; do **not** review the primary checkout |
| Worktree path already exists | Reuse that path; fetch+reset to latest PR/branch SHA |
| session_move unavailable | `cd` / `working_directory` on every command to the worktree path |
| Cannot detect base branch | Ask user which branch to diff against |
| PRD file not found | Warn user and continue without Agent G |
| Diff is extremely large (>5000 lines) | Chunk and spawn multiple agents **per specialty** in parallel |
| One specialist fails | Re-spawn that specialty once; continue with others |
| Agent returns no findings | Accept it — don't fabricate issues. Report "clean" for that specialty |
| Agent H returns fine | Omit architecture from the report entirely — silence is correct |
| Agent H fails twice | Treat as fine; do not invent architecture concerns |
| No PR for current branch | On a post request, stop; do not create a PR; do not post issue comments |
| User only asks questions | Answer; do not post |
| Number list / add / post in a later turn | Parse and post those findings only |
| Invalid finding numbers | Skip them; tell the user which were invalid |
| Finding file/line not in PR diff | Snap to nearest changed line in that file; if file absent from diff, skip (never fall back to a top-level comment) |
| Review POST 422 (invalid line/commit) | Fix `commit_id` / line / side and retry that review once; if it still fails, skip those comments and report why |
| More than 100 selected findings | Split into multiple review POSTs |

---

## Important Rules

1. **Never fabricate findings.** If the code is clean, say it's clean. False positives destroy trust.
2. **Read the actual code, not just the diff** — specialists must use Read/Grep on surrounding context. For R2/R6, read consumers outside the diff. Architecture sense-check must read surrounding patterns too.
3. **Severity matters.** CRITICAL means genuinely dangerous, not "could be slightly better."
4. **Be specific.** "This might be slow" is useless. Name file, line, impact, and fix. For recurring patterns, name the R# and production failure mode.
5. **Provide fixes, not just complaints.** Every finding must include a concrete remediation. (Architecture notes are advice, not findings tables.)
6. **PRD review is additive.** It never replaces security/performance/quality specialists.
7. **Respect the developer's time.** Prioritize findings so they know what to fix first.
8. **Hard-fail over soft-fail by default.** Flag silent fallbacks, swallowed errors, and defaults that hide misconfiguration.
9. **Hard types over soft types and fallbacks.** Prescribe the exact expected type and validation boundary — never `any`.
10. **Always run the Recurring Patterns specialist.** Even on "small" PRs. Report the coverage table even when clean.
11. **Prefer existing project gates and DB constraints** over new ad-hoc checks and `??` defaults.
12. **Parallel is mandatory.** Do not collapse specialists into one sequential mega-reviewer. Speed and focus come from one concern per agent.
13. **Architecture sense-check defaults to silence.** Only surface when verdict is `clear-better-path` or `poor-fit`. Never treat it as a merge blocker. Never demand a rewrite mid-review or in Next Steps. If fine, omit architecture entirely.
14. **Stop after the report.** Do not walk findings. Do not use the Question tool. Post inline comments only in a later turn when the user asks to add/post a number list or a single finding. Never auto-post. Never post unselected findings.
15. **GitHub comments are inline only.** Each selected finding is a review comment on `path` + `line`. Never use `gh pr comment` or the issue-comments API as a substitute. Skip anything that cannot be inlined.
16. **Always isolate in a code-only worktree first** (Phase 0 / `/worktree-quick` script). Never review the primary checkout. Never use `/monorepo-worktree`. Never skip yarn install on a fresh create. Never destroy the worktree after the report.

User arguments: $ARGUMENTS
````

#### `~/.ai/commands/pr.md`

````markdown file=~/.ai/commands/pr.md
---
description: Commits, pushes the feature branch (never main; never --no-verify), and creates or updates the PR. If the repo pre-push hook fails, fix those errors, commit, and retry the push. Use when user says "/pr", "create pr", "ship it", or "prepare pr".
---

# /pr - Automated PR Workflow

Automates the complete pull request workflow in a single command.

Quality checks (format, lint, typecheck, test, build) run in the repo **pre-push** hook (`.husky/pre-push` — there is no pre-commit hook). Prisma stays in GitHub Actions only. Do **not** run those checks in this skill before push. If the hook fails, fix the reported errors, commit, and push again. Never `--no-verify`.

## Model split (Claude Code)

Steps 1–7 are babysitting. Run them in a **Haiku subagent** (Agent tool, `model: "haiku"`): tell it to follow `~/.ai/skills/pr/SKILL.md`, and pass a 1–3 line summary of what changed and why (you have that context; it doesn't) so the commit and PR text are right. It returns the branch, commit(s), push result, and PR URL.

On a `lint` / `typecheck` / `test` / `build` hook failure the subagent stops and returns the errors. **You** (session model) fix the code, then re-delegate commit + push. Same 3-loop cap.

If you **are** that subagent, skip this section and run the steps directly — do not delegate again.

## CRITICAL SAFETY RULE

**NEVER push directly to main or master. ALWAYS create a feature branch first.**

This is non-negotiable. If on main/master, you MUST create a new branch before proceeding.

**NEVER `git push --no-verify`.** That skips the CI gate.

## Workflow Steps

Execute these steps in order, stopping if any step fails:

### Step 1: Check Current Branch (SAFETY CHECK)

```bash
git branch --show-current
```

**If the current branch is `main` or `master`:**
1. STOP - Do not proceed with push
2. Create a new feature branch based on the changes:
   ```bash
   git checkout -b <branch-name>
   ```
3. Branch naming: Use descriptive names like `fix/openai-api-key-deployment` or `feat/user-authentication`

**Only proceed if on a feature branch (not main/master).**

### Step 2: Check Git Status

```bash
git status
git diff --stat
```

- If working tree is clean and up-to-date with remote, check if PR exists
- If there are changes, proceed to commit
- Do **not** run typecheck, format, lint, test, or build here — pre-push is the gate

### Step 3: Stage and Commit

**Get context for commit message:**
```bash
git diff --staged
git diff
git log --oneline -5
```

**Stage changes:**
```bash
git add -A
```

**Create commit with descriptive message:**

Analyze the changes and create a conventional commit message:
- `feat:` for new features
- `fix:` for bug fixes
- `refactor:` for code refactoring
- `style:` for formatting changes only
- `docs:` for documentation
- `test:` for test changes
- `chore:` for maintenance

If only formatting changes exist, use:
```bash
git commit -m "style: format code"
```

For substantive changes, write a descriptive message explaining what and why.

Do not add any `Co-Authored-By` trailer (Claude, Grok, or otherwise).

### Step 4: Push to Remote (NEVER TO MAIN, NEVER --no-verify)

**First, verify you are NOT on main/master:**
```bash
git branch --show-current
```

If on main or master, STOP and go back to Step 1.

**Push the feature branch:**
```bash
git push -u origin HEAD
```

The **pre-push** hook will run format/sync, lint, typecheck, test, and build. This can take several minutes. Wait for it. Capture the full output.

#### If the hook blocks the push — fix and retry (max 3 loops)

Do **not** `--no-verify`. Do **not** skip to creating the PR.

1. Read the hook banner and the errors above it:
   - `CI job :` — which job failed
   - `Command:` — exact command
   - `Fix    :` — hint
   - The nx / prettier / jest errors above the banner
2. Fix the **root cause**. Job-specific:

   | CI job | Fix |
   |--------|-----|
   | `format-and-sync (yarn install --immutable)` | `yarn install`, commit `yarn.lock` |
   | `format-and-sync (nx sync:check)` | `yarn nx sync`, commit the result |
   | `format-and-sync (format:check)` | `yarn nx format:write`, commit formatted files (`style: format code`) |
   | `lint` | Fix the lint errors; do not disable rules to silence them |
   | `typecheck` | Fix the TypeScript errors; no `any` / `@ts-ignore` to paper over |
   | `test` | Fix implementation or tests so assertions match real behavior |
   | `build` | Fix compile/bundle errors |

3. If Docker is not running and tests need it: tell the user to start Docker, then retry the push. Do not fake a pass.
   **Haiku subagent (see Model split):** do `format-and-sync` fixes yourself. For `lint` / `typecheck` / `test` / `build`, do **not** edit code — stop and return the hook banner + errors verbatim to the main session.
4. If you cannot fix with confidence (ambiguous test, schema conflict, missing product decision): **stop and ask**. Wrong quiet success is worse than a blocked push.
5. Commit the fix (conventional message, no `Co-Authored-By`):
   ```bash
   git add -A
   git commit -m "fix: <what the hook failed on>"
   ```
6. Push again (`git push -u origin HEAD`). Still never `--no-verify`.
7. Repeat from (1) if it fails again. **Maximum 3 fix-push loops.** After 3, stop, report every remaining error, and do not create/update the PR.

Non-hook push failures (non-fast-forward, auth): rebase/merge or report. Do not treat them as hook errors.

### Step 5: Check for Existing PR

```bash
gh pr view --json url,state,body 2>/dev/null
```

- **If no PR exists** → go to Step 6 to create one.
- **If a PR exists and is OPEN** → do NOT just report the URL. The branch now has new work on it, so the description is stale. **Update the PR body** so it reflects the full current state of the branch, using the handoff template in Step 6:
  ```bash
  gh pr edit --body "$(cat <<'EOF'
  ...regenerated handoff body...
  EOF
  )"
  ```
  Fold the still-relevant parts of the existing body into the new one — don't discard context a human wrote. If the existing description is substantial and clearly hand-authored, ask before overwriting; otherwise regenerate and improve it.

### Step 6: Write the PR description (create or update)

The PR description is a **handoff document**, not a changelog. Write it so a reviewer who has never seen this work can read it and immediately know what the PR does, why, what to scrutinize, and how it was checked — enough to jumpstart their review without asking you anything.

**Gather the material.** Don't just diff the code — the intent and the decisions live in the *session*, not the diff:
```bash
git branch --show-current
git log origin/main..HEAD --oneline
git diff origin/main...HEAD --stat
```
Then draw on **this conversation**: the original ask, the decisions you (the AI) made, the alternatives you rejected, anything the user chose or corrected mid-way, and everything you verified. These are the parts a reviewer can't reconstruct from the diff.

**Check for linked GitHub issues:**
- Look at the branch name for issue numbers (e.g., `feat/42-user-dashboard` -> issue #42)
- Check commit messages for issue references
- If found, include `Closes #<number>` in the PR body so the issue auto-closes on merge

**Body template** (omit any section that doesn't apply; keep it tight):
```bash
gh pr create --title "[conventional-commit-style title]" --body "$(cat <<'EOF'
## What & why
[1–3 sentences: what this PR sets out to do and the problem or goal behind it. Lead with intent, not a file list.]

Closes #[issue-number]   <!-- only if an issue is linked -->

## Key decisions & tradeoffs
[The decisions made while building this — whether the AI made them or the user directed them. For each: what was chosen, why, and what was rejected. This is the highest-value section for a reviewer. Call out judgment calls, anything the user explicitly asked for, and anything they changed their mind on.]

## Notes for the reviewer
[Where to focus, the riskiest change, anything non-obvious, follow-ups deliberately left out of scope, and any open questions you want the reviewer to weigh in on.]

## Verification
Pre-push hook (format/sync, lint, typecheck, test, build) passed on push.
[Any extra manual or visual checks. Be explicit about what was NOT verified.]
EOF
)"
```

**What makes a good handoff body:**
- **Intent over inventory.** The diff already lists the changes; the description explains the goal and the reasoning. Don't restate filenames.
- **Surface every real decision** — especially judgment calls and anything the user directed or corrected. That context is exactly what a reviewer needs and can't get from the diff.
- **Be honest about gaps** — unverified paths, known limitations, deferred work. A reviewer who knows the edges reviews faster.
- **Keep it skimmable** — short prose and bullets, no filler.

### Step 7: Report Result

Report:
- Commit hash and message (including any hook-fix commits)
- Whether the push succeeded on the first try or after hook-fix loops (how many)
- If still blocked: the CI job, command, and remaining errors
- PR URL (new or existing), and whether its description was created or updated
- Issue link (if applicable)

## Error Handling

| Error | Action |
|-------|--------|
| On main/master branch | STOP, create feature branch first |
| Pre-push hook fails | Fix the reported job, commit, retry push (max 3). Never `--no-verify`. After 3, STOP and report. |
| Hook failure you cannot fix confidently | STOP and ask. Do not paper over. |
| Push fails (non-fast-forward) | Check if rebase/merge needed, report |
| PR creation fails | Check gh auth, report |

## GitHub PR Comment API Reference

When interacting with PR comments via the GitHub API (`gh api`):

### Get the correct repo name
Repo names are **case-sensitive**. Always resolve dynamically:
```bash
gh repo view --json nameWithOwner -q '.nameWithOwner'
```

### Fetch inline review comments
Use `pulls/{pr}/comments` — NOT `pulls/{pr}/reviews` (reviews endpoint returns the review body which is often empty):
```bash
gh api repos/{owner}/{repo}/pulls/{pr}/comments --jq '.[] | {id, line, body}'
```

### Reply to an inline comment
POST to the comments collection with `in_reply_to`. Do NOT use the `/replies` sub-endpoint (it doesn't exist for PR review comments and returns 404):
```bash
gh api repos/{owner}/{repo}/pulls/{pr}/comments \
  -X POST \
  -f body="Reply text" \
  -F in_reply_to=<parent_comment_id>
```
**Note:** Use `-F` (not `-f`) for `in_reply_to` — it must be sent as an integer, not a string.

### Submit a PR review with inline comments
The `--field 'comments=[...]'` syntax breaks with complex JSON (nested quotes, newlines, code blocks in comment bodies). **Always write the payload to a JSON file and use `--input`:**
```bash
cat > /tmp/pr_review.json << 'ENDJSON'
{
  "commit_id": "<head_sha>",
  "event": "COMMENT",
  "body": "Review summary here.",
  "comments": [
    {
      "path": "app/foo.py",
      "line": 42,
      "body": "Inline comment with `code` and **markdown**."
    }
  ]
}
ENDJSON
gh api repos/{owner}/{repo}/pulls/{pr}/reviews \
  -X POST \
  --input /tmp/pr_review.json
```
**Get the head SHA first:**
```bash
gh api repos/{owner}/{repo}/pulls/{pr} --jq '.head.sha'
```

## Quick Reference

```
/pr
  |-- git branch --show-current (MUST NOT be main/master)
  |-- [if main] git checkout -b <feature-branch>
  |-- git status
  |-- git add -A && git commit (if dirty)
  |-- git push -u origin HEAD (NEVER main, NEVER --no-verify)
  |-- [if pre-push fails] fix → commit → push again (max 3); never skip the hook
  |-- gh pr create (new) || gh pr edit --body (existing) -- write/refresh the handoff description
  |-- Report PR URL
```

User arguments: $ARGUMENTS
````

#### `~/.ai/commands/worktree-quick.md`

````markdown file=~/.ai/commands/worktree-quick.md
---
description: Code-only git worktree for a PR, branch, or new task (copies env, yarn install; no DB/ports/seed). Use when the user runs /worktree-quick or wants a disposable checkout to start a task or review a PR/branch without a second stack.
---

# /worktree-quick

Code-only worktree: `git fetch` + `git worktree add`, then copy `.env*` and `yarn install` (own `node_modules`; husky postinstall wires pre-push). **Yarn is mandatory on every worktree** (create and reuse). Do **not** symlink `node_modules` from primary. **No** Postgres/Redis, **no** port remaps, **no** seed, **no** serve.

Use `/monorepo-worktree` when they need a runnable second stack.

## Commands

| User says | Action |
|-----------|--------|
| `/worktree-quick 1234` / `pr 1234` / PR URL | Fetch that PR, add worktree |
| `/worktree-quick feature/foo` / `branch …` | Fetch that ref, add worktree |
| `/worktree-quick add dark mode` / `new …` / `task …` | New branch from current HEAD for that task |
| `/worktree-quick destroy 1234` / `remove` / `teardown` | Remove the quick worktree + `quick/*` branch |
| `/worktree-quick list` | Show quick worktrees only |

User arguments: `$ARGUMENTS`

## Fast path

Script: `~/.ai/oc_skills/worktree-quick/scripts/quick-worktree.sh`

Must run from inside the target git repo (or set `REPO_ROOT`).

```bash
~/.ai/oc_skills/worktree-quick/scripts/quick-worktree.sh 1234
~/.ai/oc_skills/worktree-quick/scripts/quick-worktree.sh pr 1234
~/.ai/oc_skills/worktree-quick/scripts/quick-worktree.sh https://github.com/org/repo/pull/1234
~/.ai/oc_skills/worktree-quick/scripts/quick-worktree.sh feature/foo
~/.ai/oc_skills/worktree-quick/scripts/quick-worktree.sh new "add dark mode toggle"
~/.ai/oc_skills/worktree-quick/scripts/quick-worktree.sh task "fees page polish"
~/.ai/oc_skills/worktree-quick/scripts/quick-worktree.sh list
~/.ai/oc_skills/worktree-quick/scripts/quick-worktree.sh destroy 1234 --yes
```

Agents are non-interactive: always pass `--yes` on destroy. Use `--force` only if the worktree is dirty and the user wants it discarded.

## What the script does (create)

1. Resolve repo root (`REPO_ROOT` or cwd git main worktree).
2. Classify `$ARGUMENTS`: `list` / `destroy` / PR / existing ref / else **new task**.
3. PRs: `git fetch origin pull/N/head`. Branches: fetch the ref. Tasks: branch from **current HEAD**.
4. `git worktree add -b quick/<slug> ../worktrees/<repo>-quick-<slug> <sha>`
5. Write a `worktree-quick` marker in the worktree git dir (not the working tree).
6. Copy `.env`, `.env.local`, and `apps/{web-crm,web-funnel,server-crm}/.env.local` from primary as-is (no port/DB rewrite).
7. `yarn install` in the worktree (own `node_modules`; husky postinstall creates `.husky/_` so pre-push runs). Do not skip yarn. Do not symlink `node_modules` from primary. If a leftover `node_modules` symlink exists, remove it first.

Cannot check out the same branch in two worktrees — local branch is always `quick/<slug>`.

## What the script does (destroy)

1. Resolve target by PR number, slug, `--name`, `--path`, or `--all`.
2. Refuse primary checkout, refuse `.worktree-slot` (full-stack) worktrees, refuse anything that is not `*-quick-*` / quick marker.
3. `git worktree remove`. Delete local `quick/*` branch unless `--keep-branch`.
4. No ports, no Redis, no `DROP DATABASE`.

## Model split (Claude Code)

This whole command is babysitting. Run it in a **Haiku subagent** (Agent tool, `model: "haiku"`): tell it to follow `~/.ai/commands/worktree-quick.md` with the user's arguments and return path, branch, sha, PR URL, and destroy command (or the failing output verbatim). Relay its report. If the user also asked for work in the worktree, **you** (session model) do that in the returned path.

If you **are** that subagent, skip this section and run the steps directly — do not delegate again.

## Agent checklist

1. Parse `$ARGUMENTS`: `list` / `destroy|remove|teardown` / PR / branch / **task description**. If missing, **ask**.
2. `cd` to the repo the user is talking about (do not guess a different project).
3. For a task, run `…/quick-worktree.sh new "<description>"`. Do not hand-roll `git worktree add` unless the script is missing.
4. Do **not** create `dbname_wtN`, rewrite ports, seed, or start serve. The script already copies env and runs `yarn install` — wait for it; do not skip yarn. **Every worktree must run yarn** (husky). If you reuse an existing path (already-exists / already-isolated), remove a leftover `node_modules` symlink if present, then `(cd "<path>" && yarn install)` and wait for exit 0. Never skip yarn because `node_modules` exists. Never symlink `node_modules` from primary.
5. After create: report **path**, **branch**, **sha**, PR URL if any, and the destroy command.
6. After destroy: confirm the path is gone via `list`.
7. If they then ask to run the app: stop and point them at `/monorepo-worktree`.

User arguments: $ARGUMENTS
````

### Skills

Shared skills for Claude Code, Grok, and `~/.agents`.

#### `~/.ai/skills/askpass/SKILL.md`

````markdown file=~/.ai/skills/askpass/SKILL.md
---
name: askpass
description: GUI password/passphrase prompt so sudo, ssh, ssh-add, git, and similar never take a secret through chat. Use when a command needs a sudo password, SSH identity passphrase, git credentials, or any secret and there is no TTY. Load this skill instead of asking the user to type a password in the conversation. Not a slash command.
---

# askpass — GUI secret prompt

**Skill only** (no `/askpass` command). Pops a system dialog. The secret goes to `sudo` / `ssh` / `git` over a pipe. It must never appear in chat, tool output, logs, or commit messages.

Script:

```bash
~/.ai/skills/askpass/scripts/askpass
```

## When to use

Any time a command would block on a password and the agent has no TTY: `sudo`, `ssh`, `ssh-add`, `scp`, `rsync`, `git fetch` / `push` / `pull` over SSH, HTTPS git credentials.

Do **not** ask the user to paste a password into the conversation. Do **not** use `sudo -S` with a password you collected. Load this skill and wrap the command.

## Fast path

```bash
# sudo (uses SUDO_ASKPASS + sudo -A)
~/.ai/skills/askpass/scripts/askpass sudo pacman -Syu
~/.ai/skills/askpass/scripts/askpass sudo -- install -d /opt/foo

# ssh / git / ssh-add (SSH_ASKPASS_REQUIRE=force)
~/.ai/skills/askpass/scripts/askpass ssh mmini
~/.ai/skills/askpass/scripts/askpass git push
~/.ai/skills/askpass/scripts/askpass ssh-add ~/.ssh/id_ed25519
~/.ai/skills/askpass/scripts/askpass with rsync -a ./ mmini:~/src/

# secret as a child env var (not printed)
~/.ai/skills/askpass/scripts/askpass env PGPASSWORD --prompt "Postgres password" -- psql -h localhost -U me

# secret on the child's stdin only
~/.ai/skills/askpass/scripts/askpass stdin --prompt "sudo password" -- sudo -S whoami
```

The wrapper blocks until the dialog is confirmed or cancelled. Tell the user a password dialog is on screen.

## Rules

1. **Never capture the secret.** Do not run bare `askpass "prompt"`. Do not `password=$(askpass …)`. Do not `sudo -S` / `sshpass` with a value you read. Protocol mode prints the password on stdout for `sudo`/`ssh` only.
2. **Never print it.** Not in chat, not in a file, not in `set -x` traces.
3. **Prefer wrappers.** `askpass sudo …` and `askpass with …` / `askpass ssh|git|ssh-add …`. Those exec the real command; you only see that command's output.
4. **Prompt must say what is being unlocked** (host, key path, package). The GUI title is `Agent password`; ssh/sudo pass their own prompt through.
5. **Cancel / empty is failure.** stderr `askpass: CANCELLED` or `askpass: EMPTY`. Stop. Do not retry in a loop. Do not fall back to asking in chat.
6. **Don't.** Don't create `commands/askpass.md`. Don't enable passwordless sudo from this skill. Don't store the secret in Keychain unless the user asked.

## Fail hard

| stderr | Action |
|--------|--------|
| `CANCELLED` | User dismissed the dialog. Stop and say so. |
| `EMPTY` | Nothing entered. Stop. |
| `NO_GUI` | Linux missing zenity/kdialog. Stop; do not invent a TTY prompt. |
| `usage:` / exit 2 | Wrong invocation. Fix args; do not run protocol mode. |
````

#### `~/.ai/skills/askpass/scripts/askpass`

```text file=~/.ai/skills/askpass/scripts/askpass mode=755
#!/usr/bin/env bash
# GUI askpass for agents. Password goes to sudo/ssh/git over a pipe, never chat.
#
# Protocol (SSH_ASKPASS / SUDO_ASKPASS / GIT_ASKPASS):
#   askpass [prompt...]     # password on stdout only; stderr for errors
#
# Wrappers (agent should use these — never capture protocol stdout):
#   askpass sudo [--] <command...>
#   askpass with [--] <command...>   # ssh, git, ssh-add, scp, rsync, ...
#   askpass ssh|git|ssh-add [--] <command...>
#   askpass env NAME [--prompt TEXT] -- <command...>
#   askpass stdin [--prompt TEXT] -- <command...>

set -euo pipefail

SELF="$(cd "$(dirname "$0")" && pwd)/$(basename "$0")"

die() {
  echo "askpass: $*" >&2
  exit 1
}

usage() {
  cat <<'EOF' >&2
Usage:
  askpass sudo [--] <command...>
  askpass with [--] <command...>
  askpass ssh|git|ssh-add [--] <command...>
  askpass env NAME [--prompt TEXT] -- <command...>
  askpass stdin [--prompt TEXT] -- <command...>

Askpass protocol (invoked by sudo/ssh/git, not by agents):
  askpass [prompt...]
EOF
  exit 2
}

prompt_gui() {
  local title="$1"
  local prompt="$2"
  local secret=""
  local status=0

  set +x
  case "$(uname -s)" in
    Darwin)
      secret="$(
        osascript - "$title" "$prompt" <<'APPLESCRIPT'
on run argv
  set dialogTitle to item 1 of argv
  set dialogPrompt to item 2 of argv
  tell application "System Events"
    activate
    try
      set resultText to text returned of (display dialog dialogPrompt default answer "" with hidden answer with title dialogTitle buttons {"Cancel", "OK"} default button "OK")
    on error number -128
      error "CANCELLED" number 1
    end try
  end tell
  return resultText
end run
APPLESCRIPT
      )" || status=$?
      ;;
    Linux)
      if command -v zenity >/dev/null 2>&1; then
        secret="$(zenity --password --title="$title" --text="$prompt")" || status=$?
      elif command -v kdialog >/dev/null 2>&1; then
        secret="$(kdialog --title "$title" --password "$prompt")" || status=$?
      else
        die "NO_GUI: install zenity or kdialog"
      fi
      ;;
    *)
      die "unsupported OS $(uname -s)"
      ;;
  esac

  if (( status != 0 )); then
    die "CANCELLED"
  fi
  if [[ -z $secret ]]; then
    die "EMPTY"
  fi
  printf '%s\n' "$secret"
}

export_ssh_askpass() {
  export SSH_ASKPASS="$SELF"
  export SSH_ASKPASS_REQUIRE=force
  export GIT_ASKPASS="$SELF"
  export DISPLAY="${DISPLAY:-:0}"
}

run_sudo() {
  (( $# > 0 )) || die "usage: askpass sudo <command>"
  export SUDO_ASKPASS="$SELF"
  exec sudo -A "$@"
}

run_with() {
  (( $# > 0 )) || die "usage: askpass with <command>"
  export_ssh_askpass
  exec "$@"
}

run_env() {
  local var="" prompt=""
  (( $# > 0 )) || die "usage: askpass env NAME [--prompt TEXT] -- <command>"
  var="$1"
  shift
  [[ $var =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]] || die "invalid env name: $var"
  prompt="Password for ${var}:"
  if [[ ${1:-} == --prompt ]]; then
    shift
    prompt="${1:-}"
    [[ -n $prompt ]] || die "usage: askpass env NAME --prompt TEXT -- <command>"
    shift
  fi
  if [[ ${1:-} == -- ]]; then
    shift
  fi
  (( $# > 0 )) || die "env needs a command after --"
  local secret
  secret="$(prompt_gui "Agent password" "$prompt")"
  export "${var}=${secret}"
  exec "$@"
}

run_stdin() {
  local prompt="Password:"
  if [[ ${1:-} == --prompt ]]; then
    shift
    prompt="${1:-}"
    [[ -n $prompt ]] || die "usage: askpass stdin --prompt TEXT -- <command>"
    shift
  fi
  if [[ ${1:-} == -- ]]; then
    shift
  fi
  (( $# > 0 )) || die "stdin needs a command after --"
  local secret
  secret="$(prompt_gui "Agent password" "$prompt")"
  exec "$@" < <(printf '%s\n' "$secret")
}

if (( $# == 0 )); then
  usage
fi

cmd="$1"
case "$cmd" in
  -h | --help | help)
    usage
    ;;
  sudo)
    shift
    [[ ${1:-} == -- ]] && shift
    run_sudo "$@"
    ;;
  with)
    shift
    [[ ${1:-} == -- ]] && shift
    run_with "$@"
    ;;
  ssh | git | ssh-add | scp | rsync)
    shift
    [[ ${1:-} == -- ]] && shift
    run_with "$cmd" "$@"
    ;;
  env)
    shift
    run_env "$@"
    ;;
  stdin)
    shift
    run_stdin "$@"
    ;;
  *)
    prompt_gui "Agent password" "$*"
    ;;
esac
```

#### `~/.ai/skills/explainer-motion/SKILL.md`

```markdown file=~/.ai/skills/explainer-motion/SKILL.md
---
name: explainer-motion
description: Motion design for explainer diagrams and films, making connections, messages, and cards kinetic and physical. Use when animating a diagram, data flow, or architecture explainer (Psychopomp, web, or video); when lines should draw on or messages should travel and land; or when a motion graphic feels flat, floaty, stuttery, or over-glowing.
---

# Explainer Motion

## Energy has a source

Every beat moves energy from one specific point to another. It **gathers** at a
source, **travels**, and is **absorbed** where it lands, leaving light that cools.
Nothing lights up, flashes, or moves without a cause the viewer can point to.
When a beat feels flat or noisy, ask where its energy comes from and where it goes.

## Rules

- **Quiet at rest.** Idle wires and frames are still and matte. Motion and light
  mean something is happening.
- **One focal action.** Establish the source, follow the signal, then read the
  result. Stop background flow during narration. At thumbnail size the active
  signal should win over the hero object's texture and every frame border.
- **Light is local.** Light comes from a moving thing and falls off with distance:
  a packet lights only the border near it. An arrival colors a card from its
  socket, never with a whole-card wash.
- **Receivers do not scale.** An arrival is a small ring, a flood of light from the
  socket, and an ink flash. Geometry moves on entrances (settle-in) and in
  deliberate physical rigs, not on hits.
- **Bloom is for what is alive**: packet heads and the hero object. Keep borders,
  floods, and trails under the bloom threshold, so they read crisp.
- **Color means something.** Signals are near-white with their tone in the trail
  and reflections; red is failure; one accent is the thing to follow.
- **Physical easing.**
  - Packet travel: minimum-jerk quintic (`smootherstep`),
    with continuous velocity and acceleration into resting holds. Cubic in-out
    has an acceleration discontinuity at its middle; don't use it by habit.
  - Camera moves: try critically damped springs for weight and a natural tail.
    Minimum-jerk glides fit exact timed moves between rests; do not force every
    camera gesture through a fixed-duration curve if it reads stiff.
  - Draw-on: `cubic-bezier(.45, 0, .2, 1)`, which neither jumps off the port nor
    parks at the socket.
  - Rigid-panel entrances: small displacement, damped springs; let content
    follow the body by about 60 ms. Tune amplitude before adding bounce.
  - Flashes: instant attack, convex decay (fast, then a long tail).
  - Struck things ring: a cable twangs on an underdamped spring.
- **Reaction follows contact.** Include gathering/anticipation when checking
  causality: a reply must not even prepare before its request arrives. An impact
  launches decisively; a slow spring from rest makes it look voluntary.
- **Pure functions of time.** Any frame renders identically in any order. Derive
  an event's phases from one clock (its age), carry velocity across retargets,
  never fake an ease with stepped values (it stutters), and render motion blur.
- **Continuity.** Things transform instead of cutting: the camera flies into the
  card that opens into its code; the same object carries across beats.
- **Physical metaphor.** Make the mechanism literal: a killed server shatters, a
  dropped error falls, a timeout is a ring sweeping closed, data flows along wires.
- **Camera.** Dolly in to open, drift toward the actor that is speaking, pull
  focus to the plane that matters, pull back to show consequences, push in on the
  resolution. Shake only on impact. Follow a message only when its journey is
  the story; orbit to reveal depth, not to decorate.
- **Rhythm.** Stagger entrances about 120 ms apart; land impacts on the spoken
  word, with a quiet sound. To show a fix, rewind visibly (reassemble, reconnect),
  then replay the same moment resolving differently.

## Beats

Constants and formulas for each are in [TECHNIQUES.md](TECHNIQUES.md).

- **Send**: light gathers at the port (340 ms), a solid dot flies with a trail
  that cools behind it, and it lands as a small opening ring (720 ms). A
  reflection rides the dot along nearby borders; an ember glows where it left, and
  light floods into what it reached.
- **Connect**: the port resolves softly and the wire draws on `cubic-bezier(.45, 0, .2, 1)`,
  then holds quietly. Author `surge`, `twang`, `land`, or `flow` explicitly when a
  beat calls for an impact or active traffic.
- **Settle-in**: a rigid panel drifts into place with a small scale correction;
  its content follows and sharpens. Keep the substrate dark. Exact Stage and
  source-diagram calibrations are distinguished in TECHNIQUES.md.
- **Hit**: a flash, pulse, jolt, or shake; instant attack, convex decay.
  A sphere takes contact on its skin: local indentation, a surface wave, then
  cooling light. Trigger at the visible silhouette crossing, not at a hidden
  endpoint or with an unrelated pulse at the center.
- **Destroy**: brief inward compression → hot release → pressure wave → cooling
  smoke and falling embers. Let the hot phase be exceptional against a quiet
  scene. The wave bends existing pixels; smoke occludes instead of glowing.
  One reversible clock owns all phases. See the volume recipe in TECHNIQUES.md.

## Designing a beat

1. For every beat, name the source, the path, and the sink of its energy. Done
   when no beat lights, flashes, or moves without all three.
2. Block readable poses with competing motion disabled. Take the matching beat
   from TECHNIQUES.md; match the destination's material and brightness rather
   than copying source alpha or bounce blindly. Done when the focal action reads
   at thumbnail size and all retained actors fit every camera composition.
3. Build it as clock-derived, deterministic motion. In Psychopomp, use the
   `StageActor` beats (`send`, `send_arriving`, `connect`, `connect_contacting`,
   `settle_in`, `hit`, `twang`, `land`, `orb_in`, `glitch`, `rewind`,
   `swap_status`, `halo`, `ring_timer`, `disconnect`), `stage::reply_after` for
   a reply's earliest launch, `author::stagger` for ripples, and
   `psychopomp::math`; the `psychopomp` skill covers the reel workflow.
4. Render short normal-speed studies before the full film (in Psychopomp,
   `plan render <plan> out.mp4 --range a..b` in the foreground). Compare against the
   previous treatment, then inspect contact frames at 40 ms or less. Check body,
   content, ports, and camera separately. Done when the result reads in motion,
   every light has a visible source, quiet holds remain quiet, and contact never
   teleports the receiver or its attached wires. State which playback or frame
   evidence was actually inspected; endpoint stills cannot prove smooth motion.
```

#### `~/.ai/skills/explainer-motion/TECHNIQUES.md`

```markdown file=~/.ai/skills/explainer-motion/TECHNIQUES.md
# Techniques

Sizes in the source diagram recipes are diagram pixels on 44 px cards; multiply
by about 1.4 for 110 to 124 px cards in a 1080p frame. Psychopomp implements
these in `crates/psychopomp/src/stage.rs` (`packet`, `StageActor`) and
`crates/psychopomp-render/src/render/stage.rs`. The larger HDR Stage uses the
restrained calibration immediately below.

## Current Stage calibration

- **Packet travel:** `smootherstep(t) = 6t⁵ − 15t⁴ + 10t³`; peak speed is 1.875
  times the average, versus cubic in-out's 3. Velocity and acceleration meet the
  hold continuously. Invert it monotonically to compute trail crossing times.
  Use `StageActor::glide` (or a `Move::Glide` camera shot) between resting
  compositions; use spring retargeting when an interruption must retain momentum.
- **Camera:** zero-bounce springs (`Move::Spring`), usually 1.0–1.8 seconds
  (opening dolly 2.2–2.6). Retain quintic glides for precisely timed resting
  moves; compare the same framing before choosing the feel. Write shots with
  the `CameraRig` (`stage.camera()`): `establish` (start 300–400 px back),
  `frame` with 140–170 px padding for a group (about 430 for one card held
  near 2×), `follow` a packet on a 0.6–0.8 s catch, `focus_on` with
  `aperture` 0.4–1.0, `orbit` 0.3–0.6 rad on a 3+ s glide, `dolly_zoom` about
  500 px on a 2.4 s glide at an impact (give it near and far depth cues to
  stretch), a 0.6 s `whip`, `handheld` near 1 only on quiet beats, and a
  slow glide `push_in` or tight `frame` on the resolution.
- **Orb contact:** intersect the packet path with the visible shell, invert its
  travel curve for contact age, then send a geodesic wave at 3.6 rad/s. A 25 ms
  attack and 480 ms exponential decay drive local light; a short 120 ms contact
  dimple gives it weight. A hemisphere-masked continuous trace connects the lit
  particles. Ports and the overall outline remain stable.
- **Rigid panels:** scale 1.035 → 1, spring duration 0.6 / bounce 0.12; y 16 → 0,
  duration 0.55 / bounce 0.16. Opacity 180 ms, blur 3 → 0 over 300 ms. Content
  follows after 65 ms on its own 0.36 / zero-bounce spring. No entrance flash.
  (`StageActor::settle_in`; `SpringPlan::PANEL` and `CONTENT` name these feels.)
- **Contact:** surge peak 0.45; cable bow 10 px, builds over 90 ms then settles
  on a 0.42 / bounce 0.28 spring. Brief flow establishes the connection, then
  returns to stillness.
- **Connections:** no default frame sweep. Fixed-size sockets resolve over 300 ms
  with smootherstep, then the wire draws on `cubic-bezier(.45, 0, .2, 1)` and
  holds quietly. Circular targets need an opaque silhouette: extend the wire
  beneath it, depth-sort packets behind it, and fade packet labels before entry.
  Measured packet labels stop short of connected bodies (`fit_between_ports`).
- **Hero entrance:** scale 0.58 → 1 on a 0.85 s / 0.2-bounce spring, blur 11 → 0
  on its own 0.7 s zero-bounce spring, angular offset −1.8 → 0 radians over
  1.25 s cubic-out (`StageActor::orb_in(.., OrbEntrance::HERO)`). Never animate
  a multiplier of absolute time for spin.
- **Material:** card flashes lift ink and rim without tinting the substrate.
  An overhead key gives the neutral rim depth; local packet reflections and
  socket floods supply color. Orb pulses only change illumination, never radius.
- **Staging:** finer, slower orb particles; small camera excursions; no standing
  neon halos. Reduce the per-primitive light sources before reducing global bloom:
  turning down bloom alone does not remove emissive halos authored into primitives.

## Hype register

For deliberately over-the-top films (see `scenes/psychopomp-intro`), keep the
quiet rules for the sweet beats and let the loud ones escalate:

- **Build:** ramp `camera.quake` linearly between shouted words (0.45 → 1.0 →
  1.5 → 2.0) under a riser that ends on the peak word; jolts still add on top.
- **Slam:** shouted text scales 1.7 → 1 on a 0.3 s / 0.3-bounce spring with a
  jolt, a 0.14 `post.zoom` streak, chroma, and a short 0.4 `post.flash`.
- **Cut to silence:** a full `post.flash` on the peak hides setting the quake to
  0 and fading everything but the hero; the sweet line lands in the stillness.

## Procedural destruction

Research foundations: [Quilez, domain warping](https://iquilezles.org/articles/warp/)
for organic density, and [GPU Gems 3, chapter 30](https://developer.nvidia.com/gpugems/gpugems3/part-v-physics-simulation/chapter-30-real-time-simulation-and-rendering-3d-fluids)
for volume rendering. Psychopomp uses an analytic procedural appearance rather
than the chapter's frame-integrated fluid simulation, preserving arbitrary-time
sampling and rewind.

- **One age:** −1 intact; 0 begins; 5.2 seconds gone. Compress the shell for
  120 ms, then release it decisively. Reverse age for the rewind.
  Preserve the intact material and occlusion at age zero. A 55 ms ignition
  handoff avoids switching every particle's size and brightness on one frame.
- **Volume:** raymarch a bounded expanding, rising density field. Low-frequency
  lobes establish silhouette; domain-warped four-octave noise sculpts folds and
  fissures. Front-to-back Beer-Lambert absorption makes cool smoke obscure the
  hot interior. Fixed quadrature avoids temporal noise crawl.
- **Bounds:** give density compact support before ray/culling bounds, or the volume
  develops straight-cut lobes. Keep the quad large enough for late smoke lift.
- **Temperature:** a brief white-yellow ignition, orange fissures, red embers,
  then nonemissive smoke. Vary heat spatially: a uniformly emissive sphere loses
  structure under highlight rolloff. Keep dark folds between bright regions.
  Cast local reflections on nearby rims; far edges and card bodies remain dark.
- **Pressure:** an inward screen-space pinch, then an expanding bipolar radial
  displacement of the existing image. Add very little ring emission; a large
  bright donut competes with the combustion.
- **Debris:** closed-form constant gravity plus linear drag; distribute speed,
  cooling, and lifetime with stable seeds. Short trails on a subset of embers
  communicate speed while most remain small points. Never accumulate positions
  from previous frames.
- **Review:** inspect 40 ms contact strips, fire-to-smoke transition, late fade,
  and reverse reconstruction. Verify labels after JSON round-trip too: centered
  text that silently reloads left-aligned destroys visual grouping.

## Source-diagram recipes

## Send

One clock per packet: `age` in seconds since dispatch, and its flight time.

| Phase | Duration | Behavior |
|---|---|---|
| Gather | 340 ms, `g = cubicOut(age / 0.34)` | Dot radius `4g`, opacity `g^1.5`. A soft disc shrinks `4 + 14(1 − g)` px onto the port at opacity `0.5 sin(πg)`. The reflection ramps up as `g^1.5`. |
| Flight | per route (0.4 to 1.6 s) | Minimum-jerk quintic by arc length. A solid near-white dot of radius 4, with no halo. |
| Landing | 720 ms, `q = time / 0.72` | See the ring. The reflection fades as `(1 − q)²`. |

- **Ring** (the dot becomes the ring): `opening = smoothstep(q / 0.24)`, fully
  open at 173 ms. Radius `2 + 2·opening + 9.1·(1 − (1 − q)²)`, stroke `4 → 1.5`,
  opacity `(1 − 0.734·opening)·(1 − q)^2.52`. A 2 px ring with a 4 px stroke
  looks exactly like the dot, so the handoff is seamless. It is a splash, not a
  shockwave.
- **Trail**: each point dims with the time since the dot crossed it:
  `heat = 0.7·(1 − since / cooling)^1.7`, with cooling 240 ms to 1.1 s.
  It is long mid-flight, short near the ends, and keeps cooling after landing.
  Stroke 1.6 px against a 1 px wire.
- **Reflection** (the border lighting up as the dot approaches): lights only the
  borders of nearby frames, never fills. Radius 80 px, strength 0.6, falloff
  through 1, 0.65, 0.16, 0 at 0, 0.3, 0.7, 1 of the radius.
- **Ember** (where it left): 2.2 s. Radius `0.1 + 0.7√t` of a 210 px size, core
  `0.6·0.26·min(t / 0.04, 1)·(1 − t)^0.9`, falling off as `(1 − r / R)^2.4`.
- **Flood** (where it arrived): 1.2 s. Travel `1 − (1 − t)^4`, width
  `0.07 + 0.6·√travel` of the card size, fade `e^(−0.9t)·(1 − smoothstep((t − 0.65) / 0.35))`,
  a Gaussian from the socket soft-capped near 5 % visible wash. The border catches
  40 % of it.

## Flashes and impacts

| Use | Curve |
|---|---|
| Name or result flash | `(1 − t / 1.2)²`, immediate attack |
| Settle-in or added row | `e^(−t / 0.234)·(1 − (t / 0.75)²)` |
| Press | `e^(−t / 0.25)·(1 − (t / 0.9)²)` |
| Inner rule, then outer border 0.14 s later | rise `sin(age / 0.18 · π/2)`, decay `(1 − (age − 0.18) / 1.1)²` |

## Pacing and motion tokens

React 0.3 s, step 0.8 s, settle 1.2 s, read 1 s. Rows ripple 0.12 s apart
(`author::stagger(rows, at, author::STAGGER, ..)`). A reply launches no earlier
than `stage::reply_after(arrival)`: its 340 ms gather waits for the request,
plus an 80 ms reaction.
Rewind: hold 0.15 s, then 1.25 s on `cubic-bezier(.65, 0, .25, 1)`, blurred by
its speed.

| Token (`SpringPlan` / `score::Feel`) | Parameters | Use |
|---|---|---|
| `PANEL` | `0.6 s`, bounce `0.12` | Rigid panel body settling into place (`StageActor::settle_in`, `window::settle_in`) |
| `CONTENT` | `0.36 s`, bounce `0.0` | Ink following its container (`author::CONTENT_LAG` = `65 ms` behind), or overlay opacity entrance |
| `ENTER` | `0.45 s`, bounce `0.0` | Spatial entrance and persistent layout room opening (caption/text rise, tree fold/scroll, code line motion, chat message slot) |
| `EXIT` | `0.24 s`, bounce `0.0` | Clean exit fade in place — simpler and faster than entry |
| `MOVE` | `0.6 s`, bounce `0.0` | Point-to-point spatial translation and anchor weight glide (`.with_thresholds(1e-5, 1e-5)`) |
| `SNAP` | `0.3 s`, bounce `0.0` | Quick state change, focus shift, or status cross-fade |
| `POP` | `0.32 s`, bounce `0.18` | Small floating UI pop (hover card, reaction pill, delta chip) |
| `CAMERA` | `1.6 s`, bounce `0.0` | Camera move with weight and a natural tail |
| `LIVELY` | `0.85 s`, bounce `0.2` | Hero orb landing with deliberate overshoot |
| `Ease::DRAW` | `cubic-bezier(0.45, 0, 0.2, 1)` | Wire, leader, accent bar, and axis draw-on (`author::DRAW_SECONDS` = `0.42 s`) |
| `Ease::GLIDE` | `smootherstep` | Minimum-jerk travel between resting holds |
```

#### `~/.ai/skills/fix-ci/SKILL.md`

````markdown file=~/.ai/skills/fix-ci/SKILL.md
---
name: fix-ci
description: Fetches the most recent GitHub Actions CI run for a PR, parses all failed jobs/steps for error messages, then diagnoses and fixes each failure in the codebase. Always creates a code-only git worktree first (same as /worktree-quick; yarn install is mandatory) so /fix-ci 1234 does not need a prior /worktree-quick. Use when user says "/fix-ci", "/fix-ci 1234", "fix ci", "fix the build", "fix pipeline", "fix github actions", or "ci is failing".
---

# /fix-ci - GitHub Actions CI Failure Fixer

Fetches the most recent GitHub Actions CI run for the current branch's PR, finds all failures and errors, diagnoses root causes, and fixes them in the codebase.

**Usage:** `/fix-ci [PR number | PR URL]`

`/fix-ci 1234` is enough — this skill creates the code-only worktree itself. Do **not** require a prior `/worktree-quick`. **Yarn install is mandatory** on every worktree (create, reuse, already-isolated).

---

## Core Philosophy

- **Find every failure.** Don't stop at the first error — CI runs have multiple jobs and steps, and each can fail independently.
- **Understand before fixing.** Read the full error context, not just the error line. Many CI errors are symptoms of a root cause elsewhere.
- **Fix the code, not the CI.** The goal is to fix the source code so CI passes, not to hack around CI configuration (unless the CI config itself is the bug).
- **Do not invent a parallel check pipeline.** After fixing, `/pr` (or a normal push) runs `.husky/pre-push`, which is the local CI gate. Never `git push --no-verify`.

---

## Agent Roster

Use these specialized agents for fixes:

| Agent | `subagent_type` | Use For |
|-------|-----------------|---------|
| Backend Architect | `backend-architect` | Build/type errors in backend or shared code |
| Frontend Developer | `frontend-developer` | Component errors, frontend test failures |
| Test Writer/Fixer | `test-writer-fixer` | Test failures, assertion mismatches |
| DevOps Automator | `devops-automator` | CI config issues, infrastructure/Docker errors |

---

## Execution Flow

```
0. Code-only worktree        -> /worktree-quick script + yarn + session_move (always)
1. Identify PR & Branch      -> Find the PR (use PR_NUMBER from Phase 0)
2. Fetch Latest CI Run       -> Get the most recent workflow run
3. Find All Failed Jobs      -> Identify every job that didn't pass
4. Extract Error Messages    -> Parse logs for all error patterns
5. Diagnose Root Causes      -> Group errors by root cause
6. Fix Each Issue            -> Implement fixes using specialized agents
7. Stop after fixes          -> Do not run a local typecheck/format/test suite here
8. Report Summary            -> Show what was fixed; next step is `/pr` (pre-push is the gate)
```

---

## Phase 0: Code-only worktree (always, before any work)

Work **never** runs in the primary checkout. Isolate first with the same script as `/worktree-quick`, then continue in that worktree. **Do not** wait for the user to run `/worktree-quick`. **Do not** use `/monorepo-worktree`. **Do not** stop after create — continue immediately in this same session.

**Yarn is mandatory on every worktree.** Create, reuse, and already-isolated all require `yarn install` in the worktree with exit 0 (10 min timeout). Never skip because `node_modules` exists. Never skip on reuse. Never skip because the task "doesn't need node_modules". If the create script already ran yarn in this turn and you watched it exit 0, that create counts; reuse / already-isolated **must still yarn**.

User arguments: `$ARGUMENTS`

### Parse target

Split `$ARGUMENTS` into **TARGET** (PR / branch) vs other flags. Only PR numbers, `#N`, `pr N`, GitHub `.../pull/N`, and git refs are worktree targets.

| TARGET | Action |
|--------|--------|
| PR / URL | `~/.ai/oc_skills/worktree-quick/scripts/quick-worktree.sh <n-or-url>` |
| Branch / ref | `…/quick-worktree.sh <ref>` |
| Empty | `gh pr view --json number -q .number`. If that fails and cwd is already `*-quick-*`, skip create. Else if current branch is not `main`/`master`, worktree that branch. Else ask for a PR number. |

Remember `PR_NUMBER` when TARGET is a PR. Later `gh pr view` / `gh run list` must use that PR's head ref — local branch is `quick/pr-N`.

### Create or reuse

Must run from the git repo (or `REPO_ROOT`). Do **not** hand-roll `git worktree add`. Skip create only if cwd is already a matching `*-quick-*` worktree. If the script fails with `worktree path already exists: <path>`: **reuse `<path>`**. If reusing and **clean**, fetch+reset to latest PR SHA. If **dirty**, do not `reset --hard`.

### Yarn (always)

```bash
(cd "<path>" && yarn install)
```

Reuse / already-isolated: **always** run this. Wait for exit 0. Timeout 10 minutes.

### Move the session, then work

1. OpenCode: `tools.opencode.session_move` with `directory` = absolute worktree path. Continue **this** session.
2. If session_move is unavailable: `cd` / `working_directory` on every later command.
3. All later git / Read / Grep / edits happen in that worktree.
4. One-line note: path, branch, PR URL, destroy command. Then **immediately** continue. Do **not** destroy the worktree when finished.

---

## Phase 1: Identify PR & Branch

```bash
# Get current branch
git branch --show-current

# Get repo owner/name
gh repo view --json owner,name --jq '.owner.login + "/" + .name'

# Prefer PR_NUMBER from Phase 0 — local branch is quick/pr-N
gh pr view ${PR_NUMBER} --json number,url,title,headRefName 2>/dev/null
```

- If no PR exists, check for CI runs on the branch directly (push-triggered workflows).
- If neither exists, **stop and inform the user**.
- For `gh run list --branch`, use the PR's GitHub `headRefName`, **not** `quick/pr-N`.

---

## Phase 2: Fetch Latest CI Run

### 2.1 Get the Most Recent Run

```bash
# Get the most recent workflow run for this branch
gh run list --branch "$(git branch --show-current)" --limit 5 --json databaseId,status,conclusion,name,createdAt,headSha
```

Select the most recent run. If multiple workflow runs exist (e.g., `ci.yml`, `test.yml`, `lint.yml`), process ALL of them that have failures.

### 2.2 Check Run Status

- If the latest run is `success` — **stop and inform the user that CI is passing**.
- If the latest run is `in_progress` — **warn the user** and offer to analyze the most recent completed run instead.
- If the latest run is `failure` or `cancelled` — proceed to Phase 3.

---

## Phase 3: Find All Failed Jobs

```bash
# List all jobs in the run, focusing on failed ones
gh run view <run-id> --json jobs --jq '.jobs[] | select(.conclusion == "failure") | {name: .name, conclusion: .conclusion, steps: [.steps[] | select(.conclusion == "failure")]}'
```

For each failed run, also get the full job list:

```bash
gh run view <run-id> --json jobs
```

Build a list of all failed jobs and their failed steps.

---

## Phase 4: Extract Error Messages

This is the most critical phase. CI logs are noisy — you must extract the actual errors.

### 4.1 Download Failed Job Logs

```bash
# Get logs for the entire failed run
gh run view <run-id> --log-failed
```

If that's too large or doesn't give enough context:

```bash
# Get logs for a specific failed job
gh run view <run-id> --log-failed --job <job-id>
```

### 4.2 Parse Error Patterns

Search the logs for ALL of these error patterns:

#### Build/Compile Errors
- `error TS\d+:` — TypeScript compiler errors
- `Error:` or `ERROR:` — Generic errors
- `error\[E\d+\]:` — Rust compiler errors
- `BUILD FAILED` or `Build failed`
- `SyntaxError:` — JavaScript/TypeScript syntax errors
- `Module not found` or `Cannot find module` — Import errors
- `Cannot find name` — TypeScript name resolution errors
- `Type '.*' is not assignable to type` — TypeScript type errors
- `Property '.*' does not exist on type` — TypeScript property errors
- `Argument of type '.*' is not assignable` — TypeScript argument errors

#### Test Failures
- `FAIL` followed by test file paths
- `FAILED` or `Failed` test indicators
- `AssertionError:` or `AssertionError:` — Test assertion failures
- `Expected:` / `Received:` — Jest/Vitest diff output
- `expect(` — Failed expectations
- `Error: expect(` — Jest matcher failures
- `x` or `X` or `*` — Failed test markers
- `\d+ failing` — Mocha-style failure counts
- `FAILURES!` — JUnit-style failures

#### Lint/Format Errors
- `error  ` (ESLint errors with double space)
- `warning  ` (ESLint warnings treated as errors)
- `Checking formatting...` followed by file diffs
- `prettier --check` failures
- `Run Prettier to fix` or `Code style issues found`

#### Runtime/Process Errors
- `Exit code: [^0]` or `Process exited with code [^0]` — Non-zero exit codes
- `ENOENT` — File not found
- `ENOMEM` — Out of memory
- `ETIMEOUT` or `Timeout` — Timeouts
- `Segmentation fault` — Crashes
- `OOMKilled` — Out of memory killed
- `Command failed` — Generic command failures

#### Docker/Infrastructure Errors
- `COPY failed:` — Docker build errors
- `npm ERR!` or `yarn error` or `pnpm ERR!` — Package manager errors
- `permission denied` — Permission issues
- `EACCES` — Access errors

#### General Failure Indicators
- Lines containing `::error::` (GitHub Actions error annotation)
- `##[error]` — GitHub Actions error prefix
- `The process.*failed with exit code` — GitHub Actions step failure

### 4.3 Build Error Inventory

For each error found, capture:
1. **Job name** — which CI job failed
2. **Step name** — which step in the job failed
3. **Error text** — the full error message
4. **File path** (if referenced) — the source file mentioned in the error
5. **Line number** (if referenced) — the line number mentioned
6. **Error category** — build, test, lint, runtime, infrastructure

---

## Phase 5: Diagnose Root Causes

### 5.1 Group Related Errors

Many CI errors share a root cause. Group them:

- **10 TypeScript errors all from missing type export** -> 1 root cause: missing export
- **5 test failures from the same test file** -> 1 root cause: broken test setup or changed API
- **3 lint errors on new files** -> 1 root cause: new files not following lint rules
- **Import errors cascade** -> Fix the source import, others resolve

### 5.2 Prioritize by Impact

Order fixes by how many downstream errors they resolve:

1. **Build/compile errors** — fix these first (tests and lint can't run if build fails)
2. **Import/module errors** — often cascade into many other errors
3. **Type errors** — fix in dependency order (shared types first)
4. **Test failures** — fix after build is green
5. **Lint/format errors** — fix last (least impactful)

### 5.3 Read Source Files

For each root cause, read the actual source file(s) to understand the context.

**IMPORTANT:** Don't just look at the error line — read surrounding context to understand the real fix needed. A "Property does not exist" error might mean:
- The property was renamed -> find the new name
- The interface changed -> update the usage
- The import is wrong -> fix the import
- A new field needs to be added -> add it to the type

---

## Phase 6: Fix Each Issue

### 6.1 Plan Fixes

Create a TodoWrite checklist with every fix needed, ordered by priority.

### 6.2 Implement Fixes Using Specialized Agents

**For build/type errors (backend or shared code):**
```
Task: backend-architect
- List of TypeScript/build errors with file paths and line numbers
- Root cause analysis
- The current code and what needs to change
- Build command to verify: [detected build command]
```

**For frontend component/test errors:**
```
Task: frontend-developer
- List of component or test errors with file paths and line numbers
- Root cause analysis
- The current code and what needs to change
- Test command to verify: [detected test command]
```

**For test failures (assertion mismatches, outdated expectations):**
```
Task: test-writer-fixer
- List of failing tests with error output
- Whether the test expectation or the implementation needs fixing
- Test command to verify
```

**For CI config / infrastructure errors:**
```
Task: devops-automator
- The CI workflow file and the failing step
- Error output from the infrastructure/Docker step
- What needs to change in the config
```

**For simple fixes (single-line changes, imports, formatting):**
Implement directly without spawning an agent.

### 6.3 Spawn Agents in Parallel

When fixes are independent (different files, different root causes), spawn multiple agents simultaneously.

---

## Phase 7: Do not run a parallel check suite

Do **not** run `tsc` / `npm test` / `nx format` / a guessed CI replica here.

This repo's local CI gate is `.husky/pre-push` (same jobs as `.github/workflows/ci.yml`). It runs on `git push` and blocks the push on failure.

After fixes are in the working tree:
1. Report what changed
2. Tell the user to run `/pr` (commit + push, never `--no-verify`)
3. If you need to reproduce **one** failed GitHub job while diagnosing, run that job's exact command from `ci.yml` — not a generic substitute

You may run `.husky/pre-push` yourself only if you are still iterating on a fix before asking the user to `/pr`. Do not treat a green generic `npm test` as verification.

---

## Phase 8: Summary Report

```markdown
## CI Fix Summary

**PR**: #[number] - [title]
**Branch**: [branch-name]
**Failed Run**: [run-id] ([run-url])
**Run Date**: [date]

### Failures Found

| # | Job | Step | Error Category | Root Cause |
|---|-----|------|---------------|------------|
| 1 | build | Typecheck | Build | Missing type export in shared/types.ts |
| 2 | test | Unit Tests | Test | API response shape changed, tests not updated |
| 3 | lint | ESLint | Lint | New files missing explicit return types |

### Fixes Applied

| # | File(s) | Change | Resolves Errors |
|---|---------|--------|----------------|
| 1 | shared/types.ts | Exported `UserResponse` type | Build errors #1-8 |
| 2 | tests/api/users.test.ts | Updated test assertions to match new response | Test failures #1-3 |
| 3 | src/utils/helpers.ts | Added explicit return types | Lint errors #1-5 |

### Local Verification

Not run in this skill. `/pr` push hits `.husky/pre-push` (mirrors CI).

### Next Steps
- Run `/pr` to commit and push the fixes (never `--no-verify`)
- Pre-push must pass; GitHub CI should then pass
```

---

## Error Handling

| Error | Action |
|-------|--------|
| No PR and no branch CI runs found | Stop, tell user to push the branch or create a PR first |
| CI is currently passing | Stop, tell user CI is green — nothing to fix |
| CI run is still in progress | Warn user, offer to analyze most recent completed run |
| `gh` CLI not authenticated | Stop, tell user to run `gh auth login` |
| Cannot determine repo owner/name | Stop, ask user to confirm they're in a git repo with a GitHub remote |
| Logs are too large to parse | Focus on `--log-failed` output and error annotations only |
| Fix causes new errors | Keep fixing; do not `--no-verify` to skip the hook |
| Cannot reproduce locally | Report the errors and suggest they may be environment-specific (CI-only dependencies, OS differences, etc.) |
| Infrastructure/config error (not code) | Spawn devops-automator agent to investigate |

---

## Important Rules

1. **Parse ALL error types.** Don't just look for `Error:` — CI failures come in many formats. Use the full pattern list in Phase 4.2.
2. **Fix root causes, not symptoms.** If 10 errors come from 1 missing export, add the export — don't patch 10 files.
3. **Read the actual workflow file.** Know what CI runs so you can reproduce locally and verify.
4. **Respect the project's tooling.** Use the same build/test/lint commands the project uses, not generic ones.
5. **Don't modify CI configuration** unless the CI config itself is clearly broken (e.g., referencing a deleted script). Use devops-automator for CI config changes.
6. **Track everything.** Every error found must be accounted for in the summary — either fixed or explained.
7. **Do not declare CI green from a generic local suite.** The gate is `.husky/pre-push` / GitHub Actions. Never `--no-verify`.
8. **Be honest about environment-specific failures.** Some CI failures can't be reproduced locally (Docker, specific OS, secret-dependent tests). Report these clearly.
9. **Use the right agent for each fix type.** Backend errors -> backend-architect, frontend -> frontend-developer, tests -> test-writer-fixer, infra -> devops-automator.
10. **Always isolate in a code-only worktree first** (Phase 0). **Yarn install is mandatory** on every worktree (create, reuse, already-isolated). Never skip yarn because `node_modules` exists.

User arguments: $ARGUMENTS
````

#### `~/.ai/skills/fix-pr-review/SKILL.md`

````markdown file=~/.ai/skills/fix-pr-review/SKILL.md
---
name: fix-pr-review
description: Fetches unresolved review comments and discussion threads from a PR, automatically fixes LOW (nits) and SEMANTIC items, presents CRITICAL/HIGH/MEDIUM items to the user with proposed fixes for approval, then replies on EVERY processed thread (including skipped) describing what changed or why it was skipped, and marks each resolved on GitHub. Always creates a code-only git worktree first (same as /worktree-quick; yarn install is mandatory) so /fix-pr-review 1234 does not need a prior /worktree-quick. Use when user says "/fix-pr-review", "/fix-pr-review 1234", "fix pr review", "address pr feedback", "handle review comments", or "/pr-review-fix".
---

# /fix-pr-review - PR Review Feedback Handler

Reads **unresolved** review comments and discussion threads from the current branch's PR, triages them by severity, auto-fixes low-risk nits and semantic suggestions, presents higher-impact items to the user with proposed fixes for approval, then **replies on every processed thread (including skipped) and marks it resolved on GitHub**. Each reply must say what changed or why the item was skipped. Already-resolved threads are excluded from processing.

**Usage:** `/fix-pr-review [PR number | PR URL]`

`/fix-pr-review 1234` is enough — this skill creates the code-only worktree itself. Do **not** require a prior `/worktree-quick`. **Yarn install is mandatory** on every worktree (create, reuse, already-isolated).

---

## Core Philosophy

- **Low (nits) & Semantic = Fix immediately.** Style preferences, naming, import ordering, comment wording, subjective/architectural opinions — these are low-risk and get applied without asking.
- **Critical, High & Medium = User decides.** Security issues, bugs, logic errors, missing error handling, code quality concerns, missing tests — these have real impact and deserve explicit review. Each is presented with a proposed fix the user can approve, tweak, or skip.
- **Never dismiss feedback silently.** Every unresolved comment is acknowledged, categorized, replied to on GitHub, and resolved — including items we skipped.
- **Close the loop on GitHub.** Code changes alone are not enough. Every processed thread gets a reply (what we did, or why we skipped it) and is then marked resolved so the PR conversation is clean.

---

## Execution Flow

```
0. Code-only worktree       -> /worktree-quick script + yarn + session_move (always)
1. Identify PR              -> Find the PR (use PR_NUMBER from Phase 0)
2. Fetch Unresolved Feedback -> Reviews, inline comments, conversation threads (skip resolved)
3. Triage & Classify        -> Assign severity to each unresolved piece of feedback
4. Auto-Fix Low/Semantic    -> Implement nits and semantic suggestions directly
5. Present Crit/High/Med    -> Show user each item with a proposed fix for approval
6. Comment & Resolve        -> Reply on EVERY processed thread (fixed AND skipped), then resolve each
7. Report Summary           -> Final status of all feedback items (already-resolved listed separately)
```

---

## Phase 0: Code-only worktree (always, before any work)

Work **never** runs in the primary checkout. Isolate first with the same script as `/worktree-quick`, then continue in that worktree. **Do not** wait for the user to run `/worktree-quick`. **Do not** use `/monorepo-worktree`. **Do not** stop after create — continue immediately in this same session.

**Yarn is mandatory on every worktree.** Create, reuse, and already-isolated all require `yarn install` in the worktree with exit 0 (10 min timeout). Never skip because `node_modules` exists. Never skip on reuse. Never skip because the task "doesn't need node_modules". If the create script already ran yarn in this turn and you watched it exit 0, that create counts; reuse / already-isolated **must still yarn**.

User arguments: `$ARGUMENTS`

### Parse target

Split `$ARGUMENTS` into **TARGET** (PR / branch) vs other flags. Only PR numbers, `#N`, `pr N`, GitHub `.../pull/N`, and git refs are worktree targets.

| TARGET | Action |
|--------|--------|
| PR / URL | `~/.ai/oc_skills/worktree-quick/scripts/quick-worktree.sh <n-or-url>` |
| Branch / ref | `…/quick-worktree.sh <ref>` |
| Empty | `gh pr view --json number -q .number`. If that fails and cwd is already `*-quick-*`, skip create. Else if current branch is not `main`/`master`, worktree that branch. Else ask for a PR number. |

Remember `PR_NUMBER` when TARGET is a PR. Later `gh pr view` must use `gh pr view ${PR_NUMBER}` — local branch is `quick/pr-N`.

### Create or reuse

Must run from the git repo (or `REPO_ROOT`). Do **not** hand-roll `git worktree add`.

Skip create only if cwd is already a matching `*-quick-*` worktree (same PR / slug).

If the script fails with `worktree path already exists: <path>`: **reuse `<path>`**. Do not destroy.

If reusing and the worktree is **clean**, fetch+reset to the latest PR/branch SHA. If **dirty**, do not `reset --hard` (keep in-progress fixes).

### Yarn (always)

After the path is known, unless you just watched create's yarn exit 0:

```bash
(cd "<path>" && yarn install)
```

Reuse / already-isolated: **always** run this. Wait for exit 0. Timeout 10 minutes.

### Move the session, then work

1. OpenCode: `tools.opencode.session_move` with `directory` = absolute worktree path. Continue **this** session.
2. If session_move is unavailable: `cd` / `working_directory` on every later command.
3. All later git / Read / Grep / edits happen in that worktree.
4. One-line note: path, `quick/…` branch, PR URL, destroy command (`~/.ai/oc_skills/worktree-quick/scripts/quick-worktree.sh destroy <slug> --yes`). Then **immediately** continue.

Do **not** destroy the worktree when finished.

---

## Phase 1: Identify the PR

```bash
# Prefer PR_NUMBER from Phase 0 — local branch is quick/pr-N, not the GitHub head ref
gh pr view ${PR_NUMBER} --json number,url,title,state,headRefName 2>/dev/null
```

Resolve repo names dynamically (case-sensitive):

```bash
gh repo view --json nameWithOwner -q '.nameWithOwner'
```

Split into `OWNER` and `REPO` for API calls. Set `NO_COLOR=1` on all `gh api` invocations to avoid ANSI noise in JSON.

- If no PR exists for the current branch, **stop and inform the user**.
- Confirm the PR number and title before proceeding.

---

## Phase 2: Fetch All Feedback (Unresolved Only)

Gather feedback from the PR, **filtering to only unresolved discussions**. Use the GraphQL API to get thread resolution status, since the REST API does not expose `isResolved`.

### 2.1 Review Threads with Resolution Status (GraphQL — Primary Source)

Use the GraphQL API to fetch all review threads and their resolution status. **Only process threads where `isResolved` is `false`.**

**Always request thread `id` (GraphQL node ID) and each comment's `databaseId`** — both are required later for replying and resolving.

```bash
NO_COLOR=1 gh api graphql -f query='
  query($owner: String!, $repo: String!, $pr: Int!, $cursor: String) {
    repository(owner: $owner, name: $repo) {
      pullRequest(number: $pr) {
        reviewThreads(first: 100, after: $cursor) {
          pageInfo { hasNextPage endCursor }
          nodes {
            id
            isResolved
            isOutdated
            path
            line
            startLine
            comments(first: 100) {
              nodes {
                id
                databaseId
                body
                author { login }
                createdAt
                url
              }
            }
          }
        }
      }
    }
  }
' -F owner='{owner}' -F repo='{repo}' -F pr={pr_number}
```

Paginate while `pageInfo.hasNextPage` is true so every unresolved thread is collected.

**Filtering rules:**
- **Skip** threads where `isResolved` is `true` — these have already been addressed and marked resolved by the reviewer or author.
- **Include** threads where `isResolved` is `false` — these are unresolved and need attention.
- Optionally note `isOutdated` threads (code has changed since the comment was made) but still include them if unresolved.
- Store per thread: `thread.id` (for resolve mutation), first comment's `databaseId` (for reply), path, line, body, author.

### 2.2 Review Summaries (top-level review bodies)

```bash
NO_COLOR=1 gh api repos/{owner}/{repo}/pulls/{pr_number}/reviews --paginate
```

Only process reviews with a non-empty `body`. Reviews with state `DISMISSED` should be skipped.

### 2.3 Issue-Style Comments (discussion thread on the PR)

```bash
NO_COLOR=1 gh api repos/{owner}/{repo}/issues/{pr_number}/comments --paginate
```

These are top-level PR discussion comments (not inline code comments). They have no resolution status — include them all, but deprioritize any that have already been replied to with a resolution. Replies use `gh pr comment` or the issues comments API (they cannot be "resolved" like review threads).

### 2.4 PR Description Checklists

```bash
gh pr view --json body
```

Check for any unchecked requirement boxes or inline review notes from the author.

### 2.5 Deduplicate & Filter

- Group reply threads together under their parent comment
- Remove bot comments (dependabot, CI bots, etc.) unless they are actionable review findings you still want to address
- **Exclude all resolved threads** — they should not appear in triage, fixes, or the user decision list
- Note resolved threads only in the final summary report under "Already Resolved" for completeness

---

## Phase 3: Triage & Classify

For each **unresolved** piece of feedback, classify into one of these severity levels:

### Classification Rubric

| Severity | Description | Examples | Action |
|----------|-------------|----------|--------|
| **CRITICAL** | Security vulnerabilities, data loss, crashes, broken auth | SQL injection, unvalidated input reaching DB, missing auth checks, null pointer in critical path | **Present to user with proposed fix** |
| **HIGH** | Bugs, logic errors, missing error handling, race conditions, performance issues likely to cause incidents | Off-by-one errors, unhandled promise rejections, missing null checks, N+1 queries, resource leaks | **Present to user with proposed fix** |
| **MEDIUM** | Code quality issues, suboptimal patterns, minor refactors, missing tests | Better abstraction possible, duplicated logic, missing edge case tests, overly complex function | **Present to user with proposed fix** |
| **LOW** | Style preferences, naming suggestions, documentation, minor improvements | Variable renaming, comment additions, import ordering, slightly better wording | **Auto-fix immediately** |
| **SEMANTIC** | Subjective opinions, architectural philosophy, bikeshedding | Tabs vs spaces debates, framework preferences, "I would have done it differently" | **Auto-fix immediately** |

### Classification Process

For each comment:
1. Read the full comment text and any code context referenced
2. Read the actual file and line range being discussed to understand the real impact
3. Determine if the reviewer is requesting a change vs. asking a question vs. making an observation
4. Assign severity based on the rubric above
5. If a comment is ambiguous, classify it as **MEDIUM** (err on the side of showing the user — safer than silently auto-fixing).

---

## Phase 4: Auto-Fix Low (Nits) & Semantic Items

These are low-risk — naming, comments, import order, style preferences, subjective architectural nits. Apply them directly without asking.

### 4.1 Plan Fixes

For each LOW and SEMANTIC item:
1. Read the relevant file(s) and surrounding context
2. Understand exactly what the reviewer asked for — do not expand scope
3. Plan the minimal change that addresses the comment

### 4.2 Implement Fixes Directly

Most nits and semantic changes are simple edits — make them directly with Edit. Only delegate to a specialized agent if the change touches a meaningfully complex area:

- backend-architect — for semantic refactors across backend/API surfaces
- frontend-developer — for semantic refactors in UI components

For single-file renames, comment tweaks, import reordering, wording changes: just edit inline.

### 4.3 Track Each Fix

Record **every** LOW/SEMANTIC item for the final summary **and** for Phase 6 (reply + resolve) — including ones you did not apply. Track at minimum:

- `thread_id` (GraphQL node id)
- `comment_database_id` (numeric id of the first/root comment in the thread)
- severity, path, reviewer
- outcome: `fixed` | `question-answered` | `skipped` | `deferred`
- `reply_body` draft: one sentence of what changed, or why it was skipped

If a nit is already applied, is incorrect, or you choose not to apply it, still record `skipped` with a concrete reason. Do not drop it from Phase 6.

---

## Phase 5: Present Critical/High/Medium Items With Proposed Fixes

After nits/semantic are applied, present the remaining impactful items to the user. **Each item must include a concrete proposed fix** — not just the reviewer's comment. The user should be able to approve, modify, or skip each one without having to re-read the diff themselves.

### Preparing Each Item

For every CRITICAL/HIGH/MEDIUM comment, before presenting:
1. Read the file and surrounding code the reviewer referenced
2. Understand the underlying problem (not just the surface complaint)
3. Draft the specific code change you would make — exact file, exact lines, before/after snippet
4. Note any risk, tradeoff, or ambiguity the user should know about

### Presentation Format

Order by severity (CRITICAL → HIGH → MEDIUM), then group by file within each severity:

```
## Review Feedback Needing Your Decision

### CRITICAL

1. [auth.ts:45] "User input flows into SQL query without sanitization" — @alice
   Problem: `email` is interpolated directly into the query string, enabling SQL injection.
   Proposed fix: switch to a parameterized query via the existing `db.query(sql, params)` helper.
   ```ts
   // before
   db.query(`SELECT * FROM users WHERE email = '${email}'`)
   // after
   db.query('SELECT * FROM users WHERE email = $1', [email])
   ```
   Notes: No behavior change for valid inputs. Safe to apply.

### HIGH

2. [api/users.ts:92] "This can crash if `profile` is null" — @bob
   Problem: `user.profile.name` is dereferenced without a null check; `profile` is optional in the schema.
   Proposed fix: add a nullish guard and return a default display name.
   ```ts
   // before
   return user.profile.name
   // after
   return user.profile?.name ?? user.email
   ```
   Notes: Matches the fallback pattern already used in `getDisplayName()` at line 140.

### MEDIUM

3. [utils/parse.ts:30] "Extract the date-handling block into a helper" — @alice
   Problem: 20 lines of date parsing are duplicated in 3 call sites.
   Proposed fix: extract a `parseFlexibleDate(input: string): Date | null` helper in the same file and replace all 3 call sites.
   Notes: Low risk, but touches 3 files — confirm you want this bundled in the review-fix commit vs. its own PR.
```

### User Decision

Ask the user which items to apply. Defaults and guidance:
- Default to applying all CRITICAL and HIGH items — but still require explicit confirmation before editing.
- MEDIUM items are opt-in — user picks which to apply.
- Allow the user to reply with freeform edits ("apply #1 and #2, skip #3, and for #1 use `email.toLowerCase()` in the param").

### Implement Approved Items

For each item the user approves:
1. Apply the exact fix shown (with any user-requested tweaks)
2. Use specialized agents only if the fix fans out across multiple complex files
3. Record the applied change for the summary and Phase 6

For items the user **skips**, record them with outcome `skipped` and a concrete reason (user's words if given, otherwise a short summary). Phase 6 **must** reply with that reason and resolve the thread. Skipping the code change does **not** skip the GitHub reply.

---

## Phase 6: Comment & Resolve on GitHub

**This phase is mandatory and must cover 100% of processed threads.** After code changes (and user decisions) are done, close the loop on **every** unresolved thread that entered triage — including every skipped item — by (1) posting a reply that describes the outcome and (2) marking the thread resolved.

Do **not** skip this phase even if all items were auto-fixed LOW/SEMANTIC nits. Do **not** skip it for items the user skipped, items the agent skipped, questions, or items already correct. Reviewers should not have to re-open the diff to discover that feedback was addressed or declined.

**Hard coverage rule:** before posting, list every unresolved `thread.id` from Phase 2. Each must have an outcome. Any thread missing an outcome is treated as `skipped` with reason "not applied this pass" — still reply and resolve. Leaving a processed thread with no reply is a failure of this skill.

### 6.0 When to run

Run Phase 6 once for **all** items that entered triage in Phases 3–5 (not only the ones you fixed):

| Outcome | Reply must say | Resolve thread? |
|---------|----------------|-----------------|
| `fixed` (code change applied) | What we changed | **Yes** |
| `question-answered` (no code change; clarified) | The technical answer | **Yes** |
| `skipped` (user or agent chose not to apply) | Why it was skipped | **Yes** |
| `deferred` (follow-up agreed with user) | Why deferred and the follow-up plan | **Yes** (default). Leave open **only** if the user explicitly said "leave this thread open" |
| Already resolved (Phase 2 filter) | — | No (never entered processing) |

Default: **reply, then resolve**, including skipped and deferred. The only exception is an explicit user request to leave a specific thread open.

### 6.1 Reply to an inline review thread

Use the **numeric** `databaseId` of the root (or latest) comment in the thread — not the opaque GraphQL node id.

Prefer the replies endpoint (works with PR number + comment databaseId):

```bash
NO_COLOR=1 gh api repos/{OWNER}/{REPO}/pulls/{pr_number}/comments/{databaseId}/replies \
  -X POST \
  -f body="<reply text>"
```

Fallback if `/replies` fails (some API versions / permissions):

```bash
NO_COLOR=1 gh api repos/{OWNER}/{REPO}/pulls/{pr_number}/comments \
  -X POST \
  -f body="<reply text>" \
  -F in_reply_to={databaseId}
```

**Note:** Use `-F` (not `-f`) for `in_reply_to` so it is sent as an integer, not a string.

### 6.2 Reply templates (always substantive — never bare acks)

**Never** reply with only "Done", "Fixed", "Ack", "Thanks", or "Will fix". Every reply must explain the outcome.

**Fixed (with local commits not yet pushed):**

```text
Addressed: <one-sentence description of the change>.
```

**Fixed (after push, when you have a commit SHA):**

```text
Addressed in <short_sha>: <one-sentence description of the change>.
```

If fixes are not pushed yet (this skill does not require push — `/pr` may come later), omit the SHA and still describe the change clearly. Optionally note that the fix is on the branch and will land with the next push.

**Question / observation (no code change):**

```text
<Substantive technical answer: why the current code is correct / how it works / what the constraint is.>
```

**Skipped (user declined, or agent did not apply):**

```text
Skipping this change: <concrete reason — user declined / already correct because … / out of scope because …>. Happy to revisit if needed.
```

The skip reason must be specific. Not allowed: "Skipping.", "Won't fix.", "No.", or an empty reason.

**Deferred (still reply + resolve unless user said leave open):**

```text
Acknowledged — deferring to a follow-up: <what will be done and where/when if known>. Resolving this thread; tracking the follow-up separately.
```

If the user explicitly said leave the thread open, use the same body but end with "Leaving this thread open to track." and do **not** resolve.

### 6.3 Resolve the review thread (GraphQL)

After a successful reply (for outcomes that should resolve), mark the thread resolved using the GraphQL node `id` from Phase 2:

```bash
NO_COLOR=1 gh api graphql -f query='
  mutation($threadId: ID!) {
    resolveReviewThread(input: {threadId: $threadId}) {
      thread {
        id
        isResolved
      }
    }
  }
' -f threadId='{thread_graphql_id}'
```

Verify `isResolved` is `true` in the response. If the mutation fails (permissions, already resolved, invalid id), log it in the summary and continue with remaining threads — do not abort the whole phase.

### 6.4 Order of operations per thread

For each handled item:

1. Compose the reply body from the template matching the outcome (what we did, or why we skipped)
2. POST the reply (`/replies` or `in_reply_to`)
3. Run `resolveReviewThread` for `fixed` | `question-answered` | `skipped` | `deferred`
4. Leave unresolved **only** if the user explicitly said to leave that thread open
5. Record success/failure of reply and resolve for the summary

Process threads sequentially (or with modest parallelism) but **do not** resolve before replying — reviewers should see the explanation on a resolved thread.

### 6.5 Top-level review bodies & issue comments

These are not GraphQL review threads:

- **Review summary body** (non-empty CHANGES_REQUESTED / COMMENTED review): after addressing, post a single PR conversation comment summarizing what was done, e.g. `gh pr comment {pr} --body "..."`. There is no per-review "resolve" API beyond dismissing the review (do **not** dismiss reviews unless the user asks).
- **Issue-style PR comments**: reply in the conversation with `gh pr comment` when a response is warranted. No resolve action.

### 6.6 Batching guidance

- One reply per thread (do not spam multiple status updates).
- If several threads were fixed by the same change, still reply on **each** thread referencing that change so each conversation closes cleanly.
- Prefer short, specific replies over long essays.

---

## Phase 7: Summary Report

After all work is complete (including Phase 6), provide a final report:

```markdown
## PR Review Fix Summary

**PR**: #[number] - [title]
**Branch**: [branch-name]

### Auto-Fixed (Low & Semantic)
| # | Severity | File | Fix Applied | Reviewer | GH Reply | Resolved |
|---|----------|------|-------------|----------|----------|----------|
| 1 | LOW | utils.ts:12 | Renamed `val` → `validationResult` | @alice | ✓ | ✓ |
| 2 | SEMANTIC | hooks/useData.ts:30 | Converted useState cluster to useReducer | @bob | ✓ | ✓ |

### User-Approved Fixes (Critical/High/Medium)
| # | Severity | File | Fix Applied | Reviewer | GH Reply | Resolved |
|---|----------|------|-------------|----------|----------|----------|
| 3 | CRITICAL | auth.ts:45 | Parameterized SQL query | @alice | ✓ | ✓ |
| 4 | HIGH | api/users.ts:92 | Added null guard on profile | @bob | ✓ | ✓ |

### Skipped (user or agent)
| # | Severity | File | Why skipped | Reviewer | GH Reply | Resolved |
|---|----------|------|-------------|----------|----------|----------|
| 5 | MEDIUM | utils/parse.ts:30 | User declined — extract date helper later | @alice | ✓ | ✓ |

### Already Resolved (pre-existing)
| # | File | Comment | Reviewer |
|---|------|---------|----------|
| 6 | old-file.ts | Previous review round | @charlie |

### GitHub thread actions
- Processed unresolved threads: N (must equal Phase 2 count)
- Replied: N threads (must equal processed count)
- Resolved: M threads
- Left open (user asked): K threads
- Failed reply/resolve: list any errors
- **Coverage check:** every Phase 2 unresolved thread id appears above. If any are missing, go back and reply + resolve them before finishing.

### Next Steps
- Run `/pr` to commit and push all fixes (if not already pushed)
- Confirm every processed thread has a reply + resolved state on the PR
```

---

## Error Handling

| Error | Action |
|-------|--------|
| No PR found | Stop, tell user to create a PR first |
| No review comments | Stop, tell user the PR has no feedback yet |
| gh CLI not authenticated | Stop, tell user to run `gh auth login` |
| Fix causes issues | Try alternative approach, or escalate to user |
| Ambiguous comment | Classify as MEDIUM and present to user |
| Comment is a question, not a request | Answer in the thread reply (Phase 6), resolve the thread, don't make code changes |
| User or agent skips a change | Still reply with the skip reason and resolve the thread — never silently leave it |
| Reply API fails | Retry once with the `in_reply_to` fallback; if still failing, note in summary and still attempt resolve if appropriate |
| Resolve mutation fails | Note in summary; leave thread open rather than faking success |
| Missing `thread.id` or `databaseId` | Re-fetch that thread via GraphQL before Phase 6; do not invent ids |

---

## Important Rules

1. **Only process unresolved threads** for triage and fixes — already-resolved discussions are not re-fixed. They appear only in the "Already Resolved" section of the summary.
2. **Read the actual code** before classifying — a "rename variable" comment on a public API export is HIGH, not LOW. Getting this wrong means silently applying a breaking change.
3. **Preserve reviewer intent** — don't "improve" beyond what was asked.
4. **Never auto-apply impactful changes** — CRITICAL/HIGH/MEDIUM always wait for user approval, even when the fix looks obvious. The user wants to see every meaningful change before it lands.
5. **Always include a concrete proposed fix** when presenting CRITICAL/HIGH/MEDIUM — don't just relay the reviewer's comment. Show the exact code change.
6. **Group related comments** — if 3 comments are all about the same function, fix them together (but still reply/resolve each thread in Phase 6).
7. **Don't argue with reviewers** — implement what's asked. If you disagree, note it in the summary for the user and in the thread reply if the item is skipped.
8. **Track everything** — every unresolved comment must appear in the final summary. Already-resolved comments are listed separately for reference.
9. **Reply + resolve every processed thread, including skipped** — Phase 6 is not optional and is not "fixed items only". Every unresolved thread from Phase 2 gets a reply (what we did, or why we skipped it) and is then marked resolved. A skipped code change still gets a skip-reason reply and a resolve.
10. **Never bare-ack** — every GitHub reply must explain what was done or why it was skipped. Empty / "Done" / "Skipping." replies are a failure of this skill.
11. **Reply before resolve** — always post the explanation first, then mark the thread resolved.
12. **Do not dismiss reviews** (`PUT .../reviews/{id}/dismissals`) unless the user explicitly asks — resolving threads is enough for conversation hygiene.
13. **Coverage before done** — do not finish until replied + resolved count matches the Phase 2 unresolved thread count (minus any the user explicitly asked to leave open).
14. **Always isolate in a code-only worktree first** (Phase 0 / `/worktree-quick` script). Never work in the primary checkout. **Yarn install is mandatory** on every worktree (create, reuse, already-isolated). Never skip yarn because `node_modules` exists.

User arguments: $ARGUMENTS
````

#### `~/.ai/skills/fix-shipyard-tests/SKILL.md`

````markdown file=~/.ai/skills/fix-shipyard-tests/SKILL.md
---
name: fix-shipyard-tests
description: Fetches recent integration and e2e test failures from Future-Mortgage/shipyard GitHub Actions (https://github.com/Future-Mortgage/shipyard/actions), diagnoses root causes in the monorepo, implements fixes, and opens a new PR that addresses the failing tests. Always creates a code-only git worktree first (same as /worktree-quick; yarn install is mandatory) so /fix-shipyard-tests does not need a prior /worktree-quick. Use when the user runs /fix-shipyard-tests, says "fix shipyard tests", "fix e2e failures", "fix integration test fails", "shipyard CI is red", or asks to fix failing shipyard Actions runs.
---

# /fix-shipyard-tests — Shipyard Integration & E2E Fixer

Pull recent **integration** and **e2e** failures from [Future-Mortgage/shipyard Actions](https://github.com/Future-Mortgage/shipyard/actions), diagnose them, fix the monorepo (or shipyard when the bug is deploy/infra), and open a **new PR**.

**Usage:** `/fix-shipyard-tests`  
**Optional args:** a run URL/ID, or `"integration"` / `"e2e"` to scope which job suite to fix.

This skill creates the code-only worktree itself (`quick-worktree.sh new "fix-shipyard-tests"` unless a PR/branch is given). Do **not** require a prior `/worktree-quick`. **Yarn install is mandatory** on every worktree (create, reuse, already-isolated).

---

## Core Philosophy

- **Shipyard is the signal; monorepo is usually the fix.** Deploy Dev checks out monorepo test apps and hits the deployed dev environment. Prefer fixing product code or tests in `Future-Mortgage/monorepo` unless logs prove a shipyard workflow/infra bug.
- **New branch, new PR.** Never push to `main`. Always create a dedicated fix branch and open a PR.
- **Find every failure in the selected run(s).** Do not stop at the first red step.
- **Understand before changing.** Distinguish flaky env/auth, outdated selectors, product regressions, and pipeline config issues.
- **Fix root causes, not the pipeline.** Do not weaken tests or skip jobs unless the user explicitly asks.

---

## Context: What Shipyard Runs

| Piece | Detail |
|-------|--------|
| Repo | `Future-Mortgage/shipyard` |
| Primary workflow | **Deploy Dev (GCP)** — `.github/workflows/deploy-dev-gcp.yml` |
| Trigger | `repository_dispatch` (`gcp-monorepo-merged-to-main`, etc.) or `workflow_dispatch` |
| Job pipeline | `prepare` → `build_images` → `deploy` → **`integration_tests`** → **`e2e_tests`** |
| Integration command | `yarn vitest run --config apps/server-crm-e2e/vitest.config.ts --no-file-parallelism` |
| E2E commands | `npx playwright test --config=apps/server-crm-e2e/playwright.config.ts` then `apps/web-crm-e2e/playwright.config.ts` |
| Test apps (monorepo) | `apps/server-crm-e2e`, `apps/web-crm-e2e` |
| Target env | Dev host via `TEST_BASE_URL` (shipyard vars) |
| Artifacts | `e2e-test-results` (Playwright screenshots/traces under `apps/*-e2e/test-results/`) |

**This skill only treats `integration_tests` and `e2e_tests` as in-scope failures.**  
If `prepare` / `build_images` / `deploy` failed and tests never ran, report that and stop (or ask the user if they want infra/deploy debugging instead).

---

## Agent Roster

| Agent | `subagent_type` | Use for |
|-------|-----------------|---------|
| Test Writer/Fixer | `test-writer-fixer` | Assertion mismatches, flaky selectors, outdated e2e expectations |
| Frontend Developer | `frontend-developer` | web-crm UI/login/selector regressions |
| Backend Architect | `backend-architect` | API/integration contract breaks in server-crm |
| DevOps Automator | `devops-automator` | Shipyard workflow, secrets, env URL, deploy-only issues |

---

## Execution Flow

```
0. Code-only worktree (yarn mandatory)
1. Resolve workspace & git safety
2. Find recent failed Deploy Dev runs (integration / e2e)
3. Select run(s) and extract failed jobs
4. Parse logs + download artifacts when useful
5. Diagnose root causes (group + prioritize)
6. Implement fixes on a new branch
7. Verify locally when possible
8. Commit, push, open a new PR
9. Report summary with run links and PR URL
```

---

## Phase 0: Code-only worktree (always, before any work)

Work **never** runs in the primary checkout. Isolate first with the same script as `/worktree-quick`, then continue in that worktree. **Do not** wait for `/worktree-quick`. **Do not** use `/monorepo-worktree` unless the user asked for a runnable second stack. **Do not** stop after create.

**Yarn is mandatory on every worktree.** Create, reuse, and already-isolated all require `yarn install` in the worktree with exit 0 (10 min timeout). Never skip because `node_modules` exists. Never skip on reuse. If the create script already ran yarn in this turn and you watched it exit 0, that create counts; reuse / already-isolated **must still yarn**.

User arguments: `$ARGUMENTS`

### Parse target

`integration` / `e2e` / Actions run URLs/IDs are **not** git refs. They stay as skill args.

| TARGET | Action |
|--------|--------|
| PR / URL | `~/.ai/oc_skills/worktree-quick/scripts/quick-worktree.sh <n-or-url>` |
| Branch / ref | `…/quick-worktree.sh <ref>` |
| Else (typical) | `…/quick-worktree.sh new "fix-shipyard-tests"` — the `quick/…` branch **is** the fix branch; do not create another branch unless needed |

Skip create only if cwd is already a matching `*-quick-*` worktree. If path already exists: **reuse**. If reusing and **dirty**, do not `reset --hard`.

### Yarn (always)

```bash
(cd "<path>" && yarn install)
```

Reuse / already-isolated: **always** run this. Wait for exit 0.

### Move the session, then work

OpenCode: `tools.opencode.session_move` with `directory` = absolute worktree path. Continue this session. Then **immediately** continue. Do **not** destroy the worktree when finished.

---

## Phase 1: Workspace & Safety

### 1.1 Confirm monorepo checkout

Prefer working in `Future-Mortgage/monorepo` (current workspace is usually this).

```bash
gh repo view --json nameWithOwner -q '.nameWithOwner'
git status
git branch --show-current
```

- If not in monorepo and the fix is monorepo-side, **stop** and tell the user to open the monorepo (or clone it).
- If the only fix is shipyard-side, work in a shipyard checkout (clone to a temp dir only if the user agrees).

### 1.2 Never work on main

```bash
git fetch origin main
git checkout main
git pull --ff-only origin main
```

Create a fix branch **before** edits:

```bash
git checkout -b fix/shipyard-<integration|e2e|tests>-<short-slug>
```

Examples:
- `fix/shipyard-e2e-auth-login-selector`
- `fix/shipyard-integration-loan-status`

If the working tree is dirty with unrelated changes, **stop and ask** the user how to proceed.

---

## Phase 2: Find Recent Failures

Always use the shipyard repo explicitly:

```bash
# Recent Deploy Dev runs (broad view)
gh run list \
  --repo Future-Mortgage/shipyard \
  --workflow "Deploy Dev (GCP)" \
  --limit 15 \
  --json databaseId,status,conclusion,displayTitle,createdAt,url,headSha,event
```

Filter to completed failures:

```bash
gh run list \
  --repo Future-Mortgage/shipyard \
  --workflow "Deploy Dev (GCP)" \
  --status failure \
  --limit 10 \
  --json databaseId,status,conclusion,displayTitle,createdAt,url,headSha,event
```

### 2.1 Select which run(s)

| User input | Selection |
|------------|-----------|
| None | Most recent **completed** Deploy Dev run where `integration_tests` and/or `e2e_tests` failed |
| Run URL or numeric ID | That run only |
| `integration` / `e2e` | Most recent run where that job failed |
| Multiple recent reds with same error | Fix once using the newest representative run; mention older runs in the PR |

If the latest run is still `in_progress`, warn and use the most recent **completed** failure unless the user insists on waiting.

If recent Deploy Dev runs are all green for both test jobs, **stop** and report that integration/e2e are passing.

### 2.2 Confirm which jobs failed

```bash
gh run view <run-id> --repo Future-Mortgage/shipyard \
  --json jobs --jq '.jobs[] | {name, conclusion, status}'
```

Build the work list from jobs named:
- `integration_tests` with `conclusion == "failure"`
- `e2e_tests` with `conclusion == "failure"`

Ignore Slack notify steps noise; focus on the test command failures.

---

## Phase 3: Extract Errors

### 3.1 Failed logs

```bash
gh run view <run-id> --repo Future-Mortgage/shipyard --log-failed
```

If huge, still start with `--log-failed`. Prefer grepping for:

**Playwright / e2e**
- `Error:`, `TimeoutError:`, `expect(`
- `locator.`, `toBeVisible`, `toHaveURL`
- `✘`, `failed`, `did not run`
- File paths under `apps/server-crm-e2e/` or `apps/web-crm-e2e/`
- `Error Context:`, screenshot / `trace.zip` paths

**Vitest / integration**
- `FAIL `, `AssertionError`, `Expected`, `Received`
- `Error:`, stack frames under `apps/server-crm-e2e/`
- `Test Files`, `Tests` summary lines

**Env / deploy-adjacent (report, don't "fix" by skipping tests)**
- `ECONNREFUSED`, `ENOTFOUND`, `401`, `403`, `5xx`
- `TEST_BASE_URL`, login/OTP failures, seed/data missing

### 3.2 Artifacts (e2e)

When e2e failed, download Playwright artifacts:

```bash
gh run download <run-id> \
  --repo Future-Mortgage/shipyard \
  --name e2e-test-results \
  --dir /tmp/shipyard-e2e-<run-id>
```

Inspect:
- `**/test-failed-*.png`
- `**/error-context.md`
- traces if needed: `npx playwright show-trace <path-to-trace.zip>` (only when screenshot/context is insufficient)

### 3.3 Error inventory

For each distinct failure capture:

1. **Run ID + URL**
2. **Job** (`integration_tests` | `e2e_tests`)
3. **Step / suite** (vitest file or playwright project)
4. **Test name + file:line**
5. **Error text** (full assertion/timeout message)
6. **Category** — product bug | outdated test | selector/auth flake | env/data | shipyard config
7. **Likely fix location** — monorepo app path vs e2e path vs shipyard workflow

---

## Phase 4: Diagnose Root Causes

### 4.1 Group related failures

Examples:
- Auth setup timeout → all dependent e2e skipped → **one** root cause (login page / URL / credentials / selector)
- Many integration tests fail on same API shape → one contract change
- Single assertion drift after a feature ship → update test or restore product behavior

### 4.2 Prioritize

1. **Blockers for suites** (auth.setup, global setup, base URL, env)
2. **Product regressions** that break user-visible flows
3. **Integration contract mismatches**
4. **Isolated e2e assertion/selector updates**
5. **True flakes** — fix determinism (waits, data seeding), do not just bump timeouts unless justified

### 4.3 Decide fix repo

| Signal | Fix in |
|--------|--------|
| Stack/file under `apps/*-e2e` expectations wrong after intentional product change | monorepo tests |
| UI/API broke and product should keep old behavior | monorepo product code |
| Deploy/env URL/secret/workflow step broken; app tests are fine | shipyard (ask before large infra changes) |
| Cannot tell | Prefer monorepo investigation first; document uncertainty |

Read the monorepo source around the failing paths before editing.

---

## Phase 5: Implement Fixes

### 5.1 Plan

Create a todo list of root causes (not every log line). Work in dependency order.

### 5.2 Implement

- **Simple, local edits** — do directly.
- **Test-only updates** — `test-writer-fixer`.
- **web-crm UI** — `frontend-developer`.
- **server-crm / shared API** — `backend-architect`.
- **Shipyard workflow/env** — `devops-automator`, and confirm with the user before changing deploy behavior.

Respect monorepo rules:
- Prefer `nx` / project scripts over ad-hoc tooling.
- For web-crm z-index work, follow `apps/web-crm/AGENTS.md`.
- Do not invent secrets; do not commit `.env` files.

### 5.3 What not to do

- Do not delete or skip failing tests to go green.
- Do not hardcode production secrets.
- Do not change shipyard to ignore test jobs.
- Do not amend unrelated local commits or force-push.

---

## Phase 6: Verify Locally

Full shipyard parity needs deployed dev + secrets. Still verify what you can:

### 6.1 Static / unit-level

```bash
# Typecheck touched projects when applicable
yarn nx run-many --target=typecheck --projects=server-crm-e2e,web-crm-e2e,server-crm,web-crm
```

Adapt project names to what changed.

### 6.2 Integration (vitest) — if local env supports it

```bash
yarn vitest run --config apps/server-crm-e2e/vitest.config.ts --no-file-parallelism
```

Or a single file from the failure inventory.

### 6.3 E2E (Playwright) — optional, env-dependent

Only if `TEST_BASE_URL` / local stack is available and user expects it:

```bash
npx playwright test --config=apps/server-crm-e2e/playwright.config.ts <failing-file>
npx playwright test --config=apps/web-crm-e2e/playwright.config.ts <failing-file>
```

Local multi-tenant note (from monorepo docs): use tenant hosts like `http://fm.futurewholesale.local:3000`, not bare localhost, when running against local web-crm.

### 6.4 Verification honesty

If you cannot reproduce against real dev:

- State that clearly in the PR.
- Rely on log/artifact diagnosis + code review confidence.
- Prefer minimal, targeted fixes over speculative rewrites.

**Max 3 fix → verify loops.** Then open the PR with remaining risks called out.

---

## Phase 7: Commit, Push, Open PR

### 7.1 Commit

```bash
git status
git diff
git log origin/main..HEAD --oneline
git add -A
```

Conventional commit focused on the shipyard failure:

```text
fix(e2e): restore login email selector used by shipyard playwright auth

Shipyard Deploy Dev e2e_tests failed on auth.setup (run <id>).
```

Use `fix(integration):` / `fix(e2e):` / `fix(shipyard-tests):` as appropriate.

### 7.2 Push (feature branch only)

```bash
git branch --show-current   # must NOT be main/master
git push -u origin HEAD
```

### 7.3 Create a **new** PR

```bash
gh pr create --title "fix: shipyard <integration|e2e> — <short cause>" --body "$(cat <<'EOF'
## What & why
Fixes failing **Shipyard Deploy Dev** integration/e2e tests so the post-deploy pipeline can go green again.

**Failed run(s):**
- https://github.com/Future-Mortgage/shipyard/actions/runs/<run-id>

## Failures addressed
| Job | Test / step | Root cause | Fix |
|-----|-------------|------------|-----|
| e2e_tests | auth.setup.ts › authenticate | … | … |

## Key decisions
- [What was chosen and why]
- [Whether product code vs test was updated]

## Notes for the reviewer
- [Riskiest change]
- [Anything env-specific that may still flake on dev]

## Verification
- [ ] Parsed shipyard `--log-failed` for run(s) above
- [ ] Reviewed Playwright artifacts (if e2e)
- [ ] Local commands run: …
- [ ] Not fully reproducible locally (if true) — reason: …

EOF
)"
```

Base the PR on `main`. Do not open against a random feature branch unless the user says so.

If a PR for this branch already exists, update its body instead of opening a duplicate:

```bash
gh pr view --json url,number
gh pr edit --body "..."
```

---

## Phase 8: Summary Report

```markdown
## Shipyard Test Fix Summary

**Source:** Future-Mortgage/shipyard Actions  
**Run(s):** [id](url) — Deploy Dev (GCP)  
**Jobs:** integration_tests ❌/✅ · e2e_tests ❌/✅

### Failures → Fixes
| Job | Failure | Root cause | Change | Repo |
|-----|---------|------------|--------|------|
| e2e_tests | … | … | … | monorepo |

### PR
- **Branch:** fix/shipyard-…
- **PR:** <url>
- **Commit:** <sha>

### Verification
| Check | Result |
|-------|--------|
| Log analysis | done |
| Artifact review | done / n/a |
| Local tests | pass / partial / skipped (reason) |

### Follow-ups
- Re-run or wait for next monorepo→shipyard Deploy Dev after merge
- Any residual flakes or infra-only issues
```

---

## Error Handling

| Situation | Action |
|-----------|--------|
| `gh` not authenticated | Stop; ask user to `gh auth login` with access to `Future-Mortgage/shipyard` |
| No failed integration/e2e in recent runs | Stop; report green (or only deploy/build failures) |
| Only prepare/build/deploy failed | Stop; tests did not run — offer separate deploy debug path |
| Dirty unrelated working tree | Stop; ask user |
| On `main` with accidental edits | Move commits to a fix branch; never push main |
| Fix belongs in shipyard | Confirm with user; open PR in shipyard if they agree |
| Env-only failure (dev down, bad secret) | Do **not** invent app “fixes”; report evidence and suggested ops steps |
| Logs too large | Use `--log-failed`, job-scoped view, and artifact screenshots |
| Cannot get CROSS_REPO / dev secrets locally | Document; still ship the code/test fix with clear verification limits |

---

## Important Rules

1. **Always** pass `--repo Future-Mortgage/shipyard` when querying Actions.
2. **Only** treat `integration_tests` and `e2e_tests` as the primary fix targets for this skill.
3. **Always** create a new feature branch and a PR — do not push fixes to `main`.
4. Prefer monorepo fixes that make tests correct and product correct; do not mute CI.
5. Parse **all** distinct test failures in the chosen run, then group by root cause.
6. Download e2e artifacts when Playwright failed — screenshots beat guessing.
7. Be explicit when verification against real dev was not possible.
8. Keep the PR description a handoff: run links, root causes, decisions, verification gaps.
9. If the user passes a specific run URL/ID, use that run; do not silently switch to another.
10. **Always isolate in a code-only worktree first** (Phase 0). **Yarn install is mandatory** on every worktree (create, reuse, already-isolated). Never skip yarn because `node_modules` exists.

---

## Quick Reference

```
/fix-shipyard-tests [run-url|run-id] [integration|e2e]

  1. git: clean tree, branch from main → fix/shipyard-...
  2. gh run list --repo Future-Mortgage/shipyard --workflow "Deploy Dev (GCP)"
  3. gh run view <id> --repo Future-Mortgage/shipyard --log-failed
  4. gh run download <id> --repo Future-Mortgage/shipyard --name e2e-test-results
  5. Diagnose → fix monorepo (default) or shipyard (infra only)
  6. Verify locally as much as env allows
  7. commit + push + gh pr create
  8. Report run links + PR URL
```

User arguments: $ARGUMENTS
````

#### `~/.ai/skills/fix-shipyard-tests/references/shipyard-workflows.md`

````markdown file=~/.ai/skills/fix-shipyard-tests/references/shipyard-workflows.md
# Shipyard workflows reference

Source of truth: https://github.com/Future-Mortgage/shipyard/actions

## Active workflows (typical)

| Workflow | Path | Role for this skill |
|----------|------|---------------------|
| Deploy Dev (GCP) | `.github/workflows/deploy-dev-gcp.yml` | **Primary** — runs integration + e2e after deploy |
| Deploy Prod (GCP) | `.github/workflows/deploy-prod-gcp.yml` | Prod deploy; not the default test target |
| Deploy Infrastructure (GCP) | `.github/workflows/deploy-infra-gcp.yml` | Infra only |
| Deploy Ephemeral Preview (GCP) | `.github/workflows/deploy-ephemeral-gcp.yml` | Preview deploys |

## Deploy Dev job chain

1. `prepare` — tag + monorepo/verification refs, actor/Slack mapping  
2. `build_images` — build container images from monorepo ref  
3. `deploy` — deploy to dev GCP  
4. `integration_tests` — Vitest API/integration suite  
5. `e2e_tests` — Playwright server-crm + web-crm suites  

## Commands executed in shipyard (monorepo checkout)

```bash
# integration_tests
yarn vitest run --config apps/server-crm-e2e/vitest.config.ts --no-file-parallelism

# e2e_tests
npx playwright test --config=apps/server-crm-e2e/playwright.config.ts
npx playwright test --config=apps/web-crm-e2e/playwright.config.ts
```

Env: `TEST_BASE_URL` from shipyard vars (dev host).

## Artifacts

- Name: `e2e-test-results`
- Paths: `apps/server-crm-e2e/test-results/`, `apps/web-crm-e2e/test-results/`

## Useful gh commands

```bash
gh run list --repo Future-Mortgage/shipyard --workflow "Deploy Dev (GCP)" --status failure --limit 10
gh run view <id> --repo Future-Mortgage/shipyard --json jobs
gh run view <id> --repo Future-Mortgage/shipyard --log-failed
gh run download <id> --repo Future-Mortgage/shipyard --name e2e-test-results --dir /tmp/shipyard-e2e-<id>
```

## Fix ownership

| Failure shape | Likely repo |
|---------------|-------------|
| Test assertion / selector / playwright setup | monorepo (`apps/*-e2e` or product UI) |
| API contract / server behavior | monorepo (`apps/server-crm`, shared libs) |
| Wrong image tag, secrets, workflow step, URL var | shipyard |
````

#### `~/.ai/skills/fix-tailwind/SKILL.md`

````markdown file=~/.ai/skills/fix-tailwind/SKILL.md
---
name: fix-tailwind
description: Normalizes all Tailwind classes in a PR's touched .tsx/.jsx files to use ONLY values defined in the project's tailwind.config (colors, spacing, fontSize, fontFamily, borderRadius, etc.). Replaces arbitrary values (e.g. `text-[#abc123]`, `p-[13px]`, `bg-[rgb(...)]`), off-scale tokens (e.g. `text-blue-50`, `bg-gray-700`), and any class that doesn't resolve to a config value with the closest available default. Also collapses raw hex/rgb to the nearest configured palette entry. Always creates a code-only git worktree first (same as /worktree-quick; yarn install is mandatory) so /fix-tailwind 1234 does not need a prior /worktree-quick. Use when user says "/fix-tailwind", "/fix-tailwind <PR#>", "fix tailwind in this PR", "normalize tailwind classes", or "snap tailwind to config".
---

# /fix-tailwind — Snap Tailwind classes in a PR to config defaults

Goal: make every Tailwind class in changed `.tsx` / `.jsx` / `.ts` / `.js` frontend files resolve against the project's `tailwind.config.{js,ts}`. Anything arbitrary, off-scale, or undefined is rewritten to the **closest matching config value**. Nothing else in the file is touched.

**Usage:**
- `/fix-tailwind` — operate on the current branch's diff vs. `origin/main`.
- `/fix-tailwind <PR-number>` — check out the PR locally (or read its diff via `gh pr diff`) and operate on that PR's touched files.
- `/fix-tailwind <PR-url>` — same, parsed from URL.

`/fix-tailwind 1234` is enough — this skill creates the code-only worktree itself. Do **not** require a prior `/worktree-quick`. **Yarn install is mandatory** on every worktree (create, reuse, already-isolated).

---

## Core Rules

1. **Eliminate arbitrary values.** Any utility containing `[...]` (e.g. `text-[#abc123]`, `p-[13px]`, `bg-[rgb(0,0,0)]`, `w-[42%]`, `gap-[7px]`) **must** be replaced with the closest matching config token. This is a **hard rule**, not a preference. The only exception is when no analog exists *at all* in the relevant scale (e.g. a one-off `grid-cols-[1fr_auto_2fr]` template, a custom `clip-path-[...]`, an `animate-[...]` with no named keyframe). In those rare cases, leave the class and list it in the report under "Skipped — no config analog".
2. **Config is the source of truth.** Read `tailwind.config.{js,ts,cjs,mjs}` (and any imported theme files / CSS-variable definitions it depends on). Build the allowed-value table from `theme` + `theme.extend` (plus Tailwind's built-in defaults for any property not fully overridden).
3. **Only edit changed files.** Use `git diff --name-only` against the base. Filter to `.tsx`, `.jsx`, `.ts`, `.js` — and only those that actually contain JSX or `className=` / `class=` / `clsx(` / `cn(` / `cva(` / `tw\`...\`` usages.
4. **Only edit class strings.** Never modify TS logic, imports, props, types, or non-class string literals. Class extraction must be precise (see Phase 3).
5. **Closest match, not "creative" match.** If a value has no exact config equivalent, pick the **numerically/perceptually closest** entry from the same property family. Don't guess intent. Don't pick a semantic token unless the original was semantic.
6. **Off-scale named tokens are also rewrites.** `bg-gray-100` (no `gray` in palette), `text-blue-50`, `bg-blue-900` (outside the 100–800 scale), `rounded-md` (when `md` isn't in the configured radius set) — all get snapped to the closest configured value, same as arbitrary values.
7. **Never invent new classes.** Substitution only. If no reasonable closest match exists in the relevant scale, leave the class alone and report it.
8. **Never strip `dark:`, `hover:`, `md:`, `[&>...]`, group/peer, or other variant prefixes.** Variants are preserved verbatim; only the trailing utility token is rewritten. Note: `[&>...]` and `data-[state=open]:` are *variant brackets*, not arbitrary *values* — they are NOT subject to rule 1.
9. **Never reorder, dedupe, or "tidy" classes** beyond the substitutions required. Whitespace and class order must match input.
10. **Idempotent.** Running twice produces no further changes.
11. **Do not run formatters or linters** (no `prettier`, no `eslint --fix`). Edits are minimal and surgical.

---

## Execution Flow

```
0. Code-only worktree       -> /worktree-quick script + yarn + session_move (always)
1. Resolve target           -> current branch OR PR# OR PR URL
2. Get changed files        -> git diff --name-only (filtered)
3. Load tailwind config     -> build allowed-value tables per property family
4. For each file:
     a. Extract class strings (className=, clsx, cn, cva, tw``)
     b. Tokenize each string into utilities (preserving variants)
     c. For each utility: classify family, check against config, replace if needed
     d. Reassemble + Edit the file (only if changes were made)
5. Report                   -> per-file before/after table + summary
```

---

## Phase 0: Code-only worktree (always, before any work)

Work **never** runs in the primary checkout. Isolate first with the same script as `/worktree-quick`, then continue in that worktree. **Do not** wait for `/worktree-quick`. **Do not** use `/monorepo-worktree`. **Do not** stop after create.

**Yarn is mandatory on every worktree.** Create, reuse, and already-isolated all require `yarn install` in the worktree with exit 0 (10 min timeout). Never skip because `node_modules` exists. Never skip on reuse. If the create script already ran yarn in this turn and you watched it exit 0, that create counts; reuse / already-isolated **must still yarn**.

User arguments: `$ARGUMENTS`

### Parse target

PR numbers / `#N` / `pr N` / GitHub `.../pull/N` / git refs are worktree targets.

| TARGET | Action |
|--------|--------|
| PR / URL | `~/.ai/oc_skills/worktree-quick/scripts/quick-worktree.sh <n-or-url>` |
| Branch / ref | `…/quick-worktree.sh <ref>` |
| Empty | `gh pr view --json number -q .number`. If that fails and cwd is already `*-quick-*`, skip create. Else if current branch is not `main`/`master`, worktree that branch. Else ask for a PR number. |

Remember `PR_NUMBER`. Later `gh pr view` must use `gh pr view ${PR_NUMBER}`.

### Create or reuse

Do **not** hand-roll `git worktree add`. Skip create only if cwd is already a matching `*-quick-*` worktree. If path already exists: **reuse**. If reusing and **clean**, fetch+reset to latest. If **dirty**, do not `reset --hard`.

### Yarn (always)

```bash
(cd "<path>" && yarn install)
```

Reuse / already-isolated: **always** run this. Wait for exit 0.

### Move the session, then work

OpenCode: `tools.opencode.session_move` with `directory` = absolute worktree path. Continue this session. Then **immediately** continue. Do **not** destroy the worktree when finished.

---

## Phase 1: Resolve Target

```bash
# No arg → current branch diff vs base
git branch --show-current
BASE=$(git remote show origin | grep 'HEAD branch' | awk '{print $NF}')
git merge-base HEAD origin/$BASE
```

If a PR number/URL was given:
```bash
# Get PR head SHA + base, fetch, build a diff range
gh pr view <PR> --json headRefName,baseRefName,headRepository,number
gh pr diff <PR> --name-only        # quick file list
gh pr checkout <PR>                 # only if user wants edits committed locally
```
If the user only wants a *report* (no edits) for a remote PR, use `gh pr diff <PR>` and operate on the diff content rather than checked-out files. Default: edit locally only if the PR is already checked out; otherwise prompt.

---

## Phase 2: Collect Changed Files

```bash
git diff --name-only $(git merge-base HEAD origin/$BASE)..HEAD \
  | grep -E '\.(tsx|jsx|ts|js)$' \
  | grep -vE '(\.test\.|\.spec\.|\.stories\.|/node_modules/|/dist/|/build/)'
```

For each candidate, quickly check it actually contains class strings (`grep -lE 'className=|class=|clsx\(|cn\(|cva\(|tw\`'`). Skip pure-logic files.

If a repo has **multiple `tailwind.config`** files (monorepo with multiple apps), pick the config whose `content` glob matches the file being edited. If no config matches, skip the file and note it.

---

## Phase 3: Load the Tailwind Config

Read `tailwind.config.{js,ts,cjs,mjs}` for the relevant app. Resolve everything statically — do not execute it. Specifically extract:

| Family | Where to look | Build set of |
|---|---|---|
| Colors | `theme.colors`, `theme.extend.colors` | `{<color>-<shade>}` keys, including `DEFAULT`, plus semantic tokens (`primary`, `muted`, etc.). Resolve hex values for distance comparisons. CSS-variable-backed colors (`hsl(var(--x))`) are kept as opaque tokens — match them by name only. |
| Spacing | `theme.spacing`, `theme.extend.spacing` (fallback to Tailwind defaults if absent) | px/rem values per key |
| Font size | `theme.fontSize`, `theme.extend.fontSize` | sizes per key |
| Font family | `theme.fontFamily`, `theme.extend.fontFamily` | family names |
| Border radius | `theme.borderRadius`, `theme.extend.borderRadius` | sizes per key |
| Border width | `theme.borderWidth`, `theme.extend.borderWidth` | widths per key |
| Box shadow | `theme.boxShadow`, `theme.extend.boxShadow` | named shadows |
| Z-index | `theme.zIndex`, `theme.extend.zIndex` | numeric/name keys |
| Opacity | `theme.opacity`, `theme.extend.opacity` | percent keys |
| Line height | `theme.lineHeight`, `theme.extend.lineHeight` | sizes per key |
| Letter spacing | `theme.letterSpacing`, `theme.extend.letterSpacing` | sizes per key |
| Animations | `theme.animation`, `theme.extend.animation` | names |
| Keyframes | `theme.keyframes`, `theme.extend.keyframes` | names |

If a property is **not extended**, fall back to Tailwind's built-in defaults for that property (the project still allows them). Treat the union of `defaults ∪ extend` as "allowed".

If a property is **fully overridden** (declared in `theme.<prop>` not `theme.extend.<prop>`), only the override values are allowed.

> Important for this monorepo's convention: scales typically run `100…800`. So `bg-blue-50`, `bg-blue-900`, `bg-gray-*` (no `gray` in config) are all **off-scale** and must be remapped.

---

## Phase 4: Tokenize and Rewrite

For each extracted class string:

### 4.1 Split utilities
Split on whitespace. For each utility, peel off variant prefixes (everything before the final `:`, supporting arbitrary variants like `[&>div]:`, `data-[state=open]:`, `dark:`, `md:`, `group-hover:`, etc.). Keep prefixes verbatim. Rewrite only the trailing utility token.

Also handle:
- `!` important prefix (`!text-red-500`) → preserve.
- `-` negative prefix (`-mt-4`) → preserve.

### 4.2 Classify the utility
Match against known Tailwind property prefixes to determine the family:

| Prefix examples | Family |
|---|---|
| `text-`, `bg-`, `border-`, `ring-`, `from-`, `via-`, `to-`, `fill-`, `stroke-`, `placeholder-`, `accent-`, `caret-`, `divide-`, `outline-`, `decoration-`, `shadow-` (color form) | color |
| `p-`, `px-`, `py-`, `pt-`, `pr-`, `pb-`, `pl-`, `m-`, `mx-`, `my-`, `mt-`, `mr-`, `mb-`, `ml-`, `gap-`, `gap-x-`, `gap-y-`, `space-x-`, `space-y-`, `inset-`, `top-`, `right-`, `bottom-`, `left-`, `w-`, `h-`, `min-w-`, `min-h-`, `max-w-`, `max-h-`, `size-`, `translate-x-`, `translate-y-` | spacing |
| `text-` (with size keys: xs/sm/base/lg/xl/…/9xl, or arbitrary) | fontSize |
| `font-` (sans/serif/mono/custom names) | fontFamily |
| `font-` (thin/normal/bold/…/numeric) | fontWeight (Tailwind defaults; rarely extended) |
| `rounded-`, `rounded-{side}-` | borderRadius |
| `border-`, `border-{side}-` (numeric) | borderWidth |
| `shadow-` (non-color) | boxShadow |
| `z-` | zIndex |
| `opacity-`, `bg-opacity-`, `text-opacity-`, etc. | opacity |
| `leading-` | lineHeight |
| `tracking-` | letterSpacing |
| `animate-` | animation |

⚠️ `text-*` is ambiguous (color or fontSize or alignment). Disambiguate by checking what the suffix matches in the config. `text-center` is alignment (always allowed). `text-blue-500` is color. `text-sm` is size. `text-[14px]` is fontSize arbitrary. `text-[#abc]` is color arbitrary.

### 4.3 Decide if rewrite needed

A utility is **already valid** if:
- It's not parameterized (e.g. `flex`, `grid`, `block`, alignment, display, layout, etc.) — leave alone.
- Its suffix exactly matches a configured key in its property family AND does not use `[…]` arbitrary syntax.

A utility **needs rewrite** if (any of):
- It uses arbitrary `[…]` syntax of any kind: `[#hex]`, `[rgb(...)]`, `[hsl(...)]`, `[var(--…)]`, `[Npx]`, `[Nrem]`, `[N%]`, `[Nch]`, `[calc(...)]`, etc. Per Rule 1, this is a hard requirement — find the closest config token. Only skip if no analog exists in the entire scale.
- Its arbitrary value is even *exactly* equal to a configured token (e.g. `text-[#0968F6]` when `blue.500 = #0968F6` — still rewrite to `text-blue-500` for consistency; eliminating brackets is the goal).
- Its suffix uses a key not in config: `bg-gray-100` (no `gray` in palette), `text-blue-50` / `text-blue-900` (outside 100–800 scale), `rounded-md` when not in configured radius set, etc.

**Decision tree for any utility containing `[`:**
```
contains [...] arbitrary value?
├── YES → must rewrite
│   ├── closest config match exists in this family? → rewrite to it
│   └── no analog at all? → leave + add to "Skipped — no config analog" report
└── NO → check named-token validity (off-scale handling above)
```

### 4.4 Pick the closest config value

**Colors**:
1. Resolve the input to a concrete color (parse hex/rgb/hsl; for `text-blue-50` etc., resolve against Tailwind's built-in palette so we know what hex it would produce).
2. Convert to Lab and pick the configured color with smallest ΔE (CIE76 is fine).
3. Tie-break by family name match (if input was `blue-*`, prefer a `blue-*` config entry over equally-close non-blue).
4. Never substitute a semantic token (`primary`, `muted`, etc.) unless the input was *also* semantic and is now missing — semantic intent must come from the developer.
5. If the closest match is a CSS-variable-backed token (e.g. `neutral-*`), allow it only when the input was also neutral / gray.

**Spacing / sizes (px/rem)**:
1. Convert input and all config values to px (1rem = 16px unless `theme.fontSize.base` says otherwise).
2. Pick the entry with smallest absolute px delta.
3. Tie-break: prefer the smaller value (avoid silently inflating layout).

**Font size**:
1. Same as spacing, but only against the fontSize scale (including custom keys like `xxs: 10px`, `tiny: 13px`).

**Border radius / border width / line height / letter spacing / opacity / z-index**:
1. Numeric closest match; for named-only scales (e.g. `shadow-sm/md/lg`), if input is arbitrary, pick by closest blur radius / numeric magnitude inferred from the config's resolved value.

**Animations / keyframes / fontFamily**:
1. No "closest" — exact match only. If no match, **leave the class alone** and add a note to the report. Don't guess.

### 4.5 Construct the replacement
Rebuild the utility as `<variants>:<new-suffix>`, preserving `!` and `-` prefixes. Reassemble the full class string with the original whitespace.

If the rebuilt token is identical to the original, no edit.

---

## Phase 5: Apply Edits

For each file with at least one substitution:
1. Use the `Edit` tool with `replace_all: true` only when the old class string appears multiple times **and** the substitution is identical for all occurrences. Otherwise edit each occurrence with enough surrounding context to make it unique.
2. Never use `Write` to rewrite the whole file — too risky.
3. After all edits in a file, re-read the file and verify the changed regions parse as before (nothing other than class strings was touched).

If a file uses dynamic class construction (template literals with `${...}` interpolation, `clsx({ [computed]: ... })`), only rewrite the **static segments** of class strings. Skip interpolated sections — don't touch them.

---

## Phase 6: Report

Output a single markdown table per file:

```
### apps/web-crm/src/.../foo.tsx

| Line | Before | After | Reason |
|------|--------|-------|--------|
| 42 | text-[#0968F6] | text-blue-500 | exact hex match in config |
| 58 | bg-gray-100 | bg-neutral-100 | gray not in palette; closest neutral |
| 73 | p-[13px] | p-3 | 13px → 12px (closest spacing, Δ1px) |
| 91 | text-blue-50 | text-blue-100 | 50 not in scale (100–800) |
| 104 | rounded-md | rounded-default | md not in config; default=0.6125rem closest |
```

Followed by a summary:

```
## Summary
- Files scanned: N
- Files modified: M
- Total substitutions: K
- Skipped (no closest match): J
  - <list any unresolved utilities>
- Off-scale colors collapsed: …
- Arbitrary values normalized: …
```

If `--dry-run` was passed (or user said "preview" / "don't apply"), produce the report only — no Edits.

---

## Important Edge Cases

- **`className={cn(...)}` / `clsx(...)`**: walk every string-literal argument; the rules above apply to each. Object-key forms (`{ 'text-red-500': cond }`) — rewrite the key string.
- **`cva(...)` variants**: rewrite class strings inside the `variants`/`compoundVariants`/`defaultVariants` objects.
- **Tagged templates** (`tw\`...\``, `styled\`...\``): treat the entire template literal as a class string; tokenize and rewrite static segments only.
- **JSX spread** (`{...props}`): no className visible; ignore.
- **Inline styles** (`style={{ color: '#abc' }}`): out of scope. This skill only touches Tailwind class strings.
- **Custom CSS files / `.css` / `.scss`**: out of scope.
- **`@apply` directives** in CSS: out of scope (would need a separate pass against `.css` files; not part of this skill).
- **Variants on arbitrary values** (`md:bg-[#abc]`): preserve `md:`, rewrite the suffix.
- **Multiple semantic tokens for same color**: never pick `primary` over `blue-500` automatically — semantic intent is human.
- **Empty / pass-through classes**: `className=""` or `className={undefined}` → no-op.

---

## Safety Rails

| Situation | Action |
|---|---|
| Tailwind config missing or unparseable | Stop. Report which config was sought and where it's expected. |
| File has merge conflict markers | Skip file. Report. |
| File would change > 50 utilities | Show the user the proposed diff first, ask before applying. |
| Multiple tailwind configs and no `content` glob matches the file | Skip file. Report. |
| Animation/keyframe/fontFamily with no exact match | Leave alone. Report under "Skipped". |
| User passes `--dry-run` or `preview` | Report only. No Edits. |

---

## What This Skill Does NOT Do

- Does not run `prettier`, `eslint`, or any formatter.
- Does not commit or push. Edits are left in the working tree for the user to review.
- Does not touch `.css` / `.scss` / `.module.css` files or `@apply` rules.
- Does not refactor layout, swap components, or change non-class code.
- Does not pick semantic tokens (`primary`, `muted`, `accent`, etc.) when the input was a hue token — that's a design decision, not a normalization.
- Does not add new utility classes that weren't there. Substitution only.

---

## Quick Reference: Common Substitutions in This Repo

(Built from `apps/web-crm/tailwind.config.js` — color scales run **100–800**, neutral runs **100–900**.)

| Off-config | Likely fix |
|---|---|
| `text-blue-50` | `text-blue-100` |
| `bg-blue-900` | `bg-blue-800` |
| `text-gray-*` | `text-neutral-*` (closest shade) |
| `bg-slate-*` / `bg-zinc-*` / `bg-stone-*` | `bg-neutral-*` (closest shade) |
| `text-[#0968F6]` | `text-blue-500` |
| `rounded-md` | If `md` not in config, use `rounded-default` or closest configured radius |
| `text-[10px]` | `text-xxs` |
| `text-[13px]` | `text-tiny` |
| `font-DM_Sans` / `font-['DM_Sans']` | `font-sans` |

These are illustrative — always re-derive from the actual config at run time, not from this table.

**Always isolate in a code-only worktree first** (Phase 0). **Yarn install is mandatory** on every worktree (create, reuse, already-isolated). Never skip yarn because `node_modules` exists.

User arguments: $ARGUMENTS
````

#### `~/.ai/skills/fix-types/SKILL.md`

````markdown file=~/.ai/skills/fix-types/SKILL.md
---
name: fix-types
description: >
  Scans all TypeScript/types in a PR or branch diff for soft types (`any`, unnecessary
  `null`/`undefined`, optional fields that are required, `Partial`, unvalidated JSON,
  over-wide unions) and hardens them against Prisma/DB schemas, API contracts, and domain
  invariants — then fixes call sites so the code compiles with those hard types. Prefer
  exact definitions over `any` or nullish escape hatches. Use when the user runs
  /fix-types, /fix-types 1234, /fix-types <pr|branch>, "harden types", "fix soft types",
  "remove any types", "make types strict", or "hard types on this PR/branch". Always
  creates a code-only git worktree first (same as /worktree-quick; yarn install is
  mandatory) so /fix-types 1234 does not need a prior /worktree-quick.
---

# /fix-types - Harden Soft Types on a PR / Branch

Scans every type that is **part of the current PR or branch** (not the whole monorepo), finds soft types, grounds the correct hard shape in schema/contracts/domain code, rewrites the types to be exact, and fixes all call sites so the branch typechecks with those hard definitions.

**Usage:**
- `/fix-types` — current branch vs detected base (`main`/`master`)
- `/fix-types <branch>` — treat that branch as the scope (or diff target)
- `/fix-types pr` / `/fix-types <pr-number>` — use the open PR (or a given PR) for the file set

`/fix-types 1234` is enough — this skill creates the code-only worktree itself. Do **not** require a prior `/worktree-quick`. **Yarn install is mandatory** on every worktree (create, reuse, already-isolated).

---

## Core Philosophy

- **Hard types by default.** Almost every value has an exact expected shape. Prefer that shape over `any`, over-wide unions, or nullish "maybe."
- **`any` is almost never acceptable.** Neither is `as any`, `as unknown as T`, or `@ts-ignore` / `@ts-expect-error` used to silence type errors.
- **`null` / `undefined` are rare, intentional absences** — not defaults for "we didn't model this." If the domain requires the value after a successful load/auth/parse, the type must require it.
- **Schema is ground truth.** Prisma models, Zod/validators, OpenAPI/tRPC contracts, and existing domain types define what is real. Soften only when the schema truly allows absence.
- **Fix types first, then call sites.** Hardening a type without fixing consumers is incomplete. Softening types to make call sites compile is **forbidden**.
- **Scope is the PR/branch only.** Do not refactor unrelated packages. Touch files outside the diff only when required to export a shared hard type that the branch already depends on.
- **Do not invent product behavior.** If absence is a real product state (draft vs published, optional UI prop), keep it explicit (`T | null`, optional prop, or a dedicated draft type) — do not invent fake defaults.

---

## Execution Flow

```
0. Code-only worktree     -> /worktree-quick script + yarn + session_move (always)
1. Resolve scope          -> Branch / PR / base, file list, full diff
2. Inventory soft types   -> Scan changed TS/TSX (+ type-bearing files)
3. Ground truth           -> Prisma / Zod / API / domain contracts per finding
4. Plan hard types        -> Exact replacements; classify intentional soft
5. Apply type fixes       -> Interfaces, schemas, generics, return types
6. Fix call sites         -> Remove fallbacks/casts; narrow at boundaries
7. Verify                 -> Typecheck affected projects; fix remaining errors
8. Report                 -> Summary of hardened types + intentional leftovers
```

Use a short todo list for multi-file work. Prefer direct edits; spawn agents only when a package fan-out is large.

---

## Phase 0: Code-only worktree (always, before any work)

Work **never** runs in the primary checkout. Isolate first with the same script as `/worktree-quick`, then continue in that worktree. **Do not** wait for `/worktree-quick`. **Do not** use `/monorepo-worktree`. **Do not** stop after create.

**Yarn is mandatory on every worktree.** Create, reuse, and already-isolated all require `yarn install` in the worktree with exit 0 (10 min timeout). Never skip because `node_modules` exists. Never skip on reuse. If the create script already ran yarn in this turn and you watched it exit 0, that create counts; reuse / already-isolated **must still yarn**.

User arguments: `$ARGUMENTS`

### Parse target

PR numbers / `#N` / `pr N` / GitHub `.../pull/N` / git refs are worktree targets.

| TARGET | Action |
|--------|--------|
| PR / URL | `~/.ai/oc_skills/worktree-quick/scripts/quick-worktree.sh <n-or-url>` |
| Branch / ref | `…/quick-worktree.sh <ref>` |
| Empty | `gh pr view --json number -q .number`. If that fails and cwd is already `*-quick-*`, skip create. Else if current branch is not `main`/`master`, worktree that branch. Else ask for a PR number. |

Remember `PR_NUMBER`. Later `gh pr view` must use `gh pr view ${PR_NUMBER}`.

### Create or reuse

Do **not** hand-roll `git worktree add`. Skip create only if cwd is already a matching `*-quick-*` worktree. If path already exists: **reuse**. If reusing and **clean**, fetch+reset to latest. If **dirty**, do not `reset --hard`.

### Yarn (always)

```bash
(cd "<path>" && yarn install)
```

Reuse / already-isolated: **always** run this. Wait for exit 0.

### Move the session, then work

OpenCode: `tools.opencode.session_move` with `directory` = absolute worktree path. Continue this session. Then **immediately** continue. Do **not** destroy the worktree when finished.

---

## Phase 1: Resolve Scope

### 1.1 Inputs

| Argument | Behavior |
|----------|----------|
| (none) | Current branch vs merge-base with origin default branch |
| branch name | Diff that branch vs its merge-base with origin default (or vs current if user asked to compare) |
| `pr` | Open PR for current branch via `gh pr view` |
| PR number | That PR's head vs base |

### 1.2 Gather context (run in parallel)

```bash
git branch --show-current
git remote show origin | grep 'HEAD branch' | awk '{print $NF}'
git merge-base HEAD origin/main   # or origin/master / detected default
git diff --name-only $(git merge-base HEAD origin/<base>)..HEAD
git diff --stat $(git merge-base HEAD origin/<base>)..HEAD
git diff $(git merge-base HEAD origin/<base>)..HEAD
```

If PR mode:

```bash
gh pr view --json number,url,title,baseRefName,headRefName,files
# or: gh pr view <n> --json ...
```

Prefer the PR's `baseRefName` as base when in PR mode.

### 1.3 Changed type-bearing files

Focus on:

- `*.ts`, `*.tsx`, `*.d.ts`
- Schema sources the branch touches: `**/schema.prisma`, Zod schemas, GraphQL SDL, OpenAPI, tRPC routers
- Generated types only if the branch **owns** the generator input (fix the source of truth, then regenerate if the repo has a standard command)

Skip pure assets, lockfiles, migrations SQL (unless types/enums are defined there), and docs unless they embed type contracts.

### 1.4 Stop conditions

| Condition | Action |
|-----------|--------|
| Empty diff | Stop: nothing to harden |
| No TS/schema files in diff | Stop: report no type-bearing changes |
| Cannot detect base | Ask user for base branch |

---

## Phase 2: Inventory Soft Types

Scan **only changed files** (and new symbols they introduce). Read full files when the diff is incomplete context — types often live above the hunk.

### 2.1 Soft-type smells (flag all of these)

| Smell | Examples |
|-------|----------|
| Explicit `any` | `any`, `Array<any>`, `Record<string, any>`, Promise&lt;any&gt; |
| Type erasure | `as any`, `as unknown as T`, double casts, `// @ts-ignore`, unjustified `@ts-expect-error` |
| Lazy non-null | `foo!` used to silence rather than prove presence |
| Unnecessary nullish | `T \| null`, `T \| undefined`, `T \| null \| undefined` when domain always has `T` after success |
| Fake optionals | `foo?: Bar` / `foo: Bar \| undefined` when always required in this flow |
| `Partial` abuse | `Partial<Entity>` for fully loaded entities or API responses |
| Loose bags | `object`, `{}`, `Record<string, unknown>` deep in domain (OK only at raw boundaries before parse) |
| Un-narrowed `unknown` | `unknown` returned or stored without a type guard / schema parse |
| Over-wide primitives | `string` for closed enums/statuses; `number` for fixed unions |
| Soft JSON | `JSON.parse` result used without schema; `any` from HTTP clients |
| Soft returns | Functions returning `T \| undefined` when miss should throw / Result-error |
| Soft params | Optional params added "so call sites compile" |
| Soft Prisma usage | Selecting fewer fields then defaulting; ignoring generated nullability incorrectly |
| Soft React props | Optional props that parent always passes; `children?:` when required by layout |

### 2.2 Search patterns (run over the changed file list)

```bash
# any / casts / ignores (adjust paths to changed files)
rg -n '\bany\b|as any|as unknown as|@ts-ignore|@ts-expect-error' --glob '*.ts' --glob '*.tsx' <files>

# nullish / optional-heavy annotations in the diff
rg -n '\|\s*null|\|\s*undefined|\?:|Partial<|Record<string,\s*(any|unknown)>' --glob '*.ts' --glob '*.tsx' <files>
```

Also read the full diff for newly introduced soft types that regex might miss (inferred `any` from untyped params, missing return types that become soft, etc.).

### 2.3 Build the inventory table

For each finding:

| Field | Content |
|-------|---------|
| File:line | Location |
| Soft form | Current annotation / inference |
| Symbol | Function, field, prop, generic |
| Why soft | any / nullish / Partial / … |
| Suspected hard type | Best guess before schema pass |
| Boundary? | Is this an I/O boundary (HTTP, env, DB raw, form)? |

---

## Phase 3: Ground Truth (Schema & Contracts)

For **each** inventory item, determine the real hard shape. Do not guess from local convenience.

### 3.1 Lookup order (stop when definitive)

1. **Database / Prisma** — model fields, `?` nullability, enums, relations in `schema.prisma` (and related generators)
2. **Validation schemas** — Zod / Yup / class-validator / custom parsers colocated with the API
3. **API contracts** — tRPC procedures, OpenAPI, GraphQL, shared DTO packages
4. **Domain types** — existing entities in `libs/**`, branded types, event payloads
5. **Auth / session** — what is guaranteed after middleware (e.g. `orgId` always present when authenticated)
6. **Call graph on this branch** — who constructs the value; what is proven after a successful path

### 3.2 Nullability rules

| Reality | Hard type |
|---------|-----------|
| Column/field required in DB + always selected | `T` (not `T \| null`) |
| Column nullable in DB | `T \| null` at the **DB/result** layer only |
| Lookup may miss | `T \| null` or `Result` **at the lookup**; after guard/throw, inner type is `T` |
| Authenticated context field always set | required on `AuthenticatedSession` (not optional on a generic session) |
| Form draft vs submitted entity | **Two types**: `DraftX` (soft) vs `X` (hard) — never one soft type for both |
| JSON column with known shape | parse to exact interface; do not leave as `Prisma.JsonValue` in domain |

### 3.3 Boundaries vs core

- **Boundaries** (HTTP body, query, env, `JSON.parse`, third-party SDK): may start as `unknown` / soft → **must parse once** into a hard type.
- **Core domain / UI after load**: only hard types. No `any`, no cascading `?.` / `??` for required invariants.

If a soft type exists only so a boundary can be lazy, introduce:

```ts
// boundary
function parseInput(raw: unknown): HardInput { /* zod/schema; throw on fail */ }

// core
function handle(input: HardInput): HardResult { /* no nullish soup */ }
```

---

## Phase 4: Plan Hard Types

Before editing, produce a short plan (user-visible for large PRs; silent for tiny ones).

For each finding:

1. **Exact hard type** — field-by-field if needed (`{ id: string; email: string }`, `LoanStatus`, `AuthenticatedSession`, …)
2. **Where defined** — existing type to reuse vs new named type (prefer reuse)
3. **Where to narrow** — single validation boundary
4. **Call-site impact** — files that must drop `??`, `?.`, `!`, `as any`, or optional chaining
5. **Intentional soft?** — only if product truly allows absence (document why)

### 4.1 Forbidden "fixes"

Never ship any of these as the solution:

- `any`, `as any`, `as unknown as T` without a real refine
- Widening to `string | number | boolean | null | undefined` to silence errors
- Making more fields optional so call sites compile
- Blanket `!` without a proven invariant
- `@ts-ignore` / empty `@ts-expect-error`
- Replacing hard errors with `?? default` for required data

### 4.2 Preferred patterns

| Situation | Pattern |
|-----------|---------|
| Resource may be missing | `findX(): Promise<X \| null>` then `if (!x) throw/404`; later `X` |
| Create vs entity | `CreateXInput` vs `X` |
| Patch endpoint | `PatchX` / `Partial<Pick<X, ...>>` **only** at patch boundary |
| Status / kind fields | string literal unions or enums matching DB enum |
| Lists that are never null | `T[]` (empty array OK); not `T[] \| null` unless API distinguishes |
| Errors | throw or discriminated union `{ ok: true; data: T } \| { ok: false; error: E }` — not silent empty success |

---

## Phase 5: Apply Type Fixes

Edit in this order to reduce thrash:

1. **Schema / shared contracts** (Prisma enum usage, Zod, shared DTO packages the branch already touches)
2. **Domain type definitions** (interfaces, types, branded IDs)
3. **Function signatures** (params + return types explicit and hard)
4. **Component props** (required vs optional aligned with real usage)

### 5.1 Mechanics

- Prefer **named types** over large inline unions repeated everywhere.
- Match existing project conventions (type vs interface, Zod inference `z.infer<typeof Schema>`, Prisma generated types).
- If Prisma nullability is wrong relative to DB, **do not lie in TS** — fix schema/migration only if the branch already owns that concern; otherwise type the query result honestly and narrow.
- Remove redundant optional markers when the parent type is only used post-validation.

### 5.2 Generated clients

If the monorepo uses Prisma/GraphQL codegen:

- Change the **source** (schema, zod, openapi).
- Run the repo's standard generate command only when needed (`yarn prisma:sync`, project-specific codegen, etc.).
- Do not hand-edit generated files.

---

## Phase 6: Fix Call Sites & Runtime

Hard types will surface real errors — that is the point. Fix them properly.

### 6.1 Replace soft runtime patterns

| Before (soft) | After (hard) |
|---------------|--------------|
| `user?.orgId ?? ''` | Ensure `user: AuthenticatedUser` with `orgId: string`; use `user.orgId` |
| `as SomeType` | Parse/validate or fix the producer type |
| `data: any` from fetch | Typed client / zod parse of response |
| `fn(x?: T)` | `fn(x: T)` + fix callers |
| `return null` on impossible branch | `throw new Error(...)` or exhaustive `never` check |
| `Partial<User>` state for full form | `UserFormState` with explicit optional draft fields only where needed |

### 6.2 Exhaustiveness

- Prefer `switch` on unions with a `default: const _exhaustive: never = x` pattern where the codebase already uses it.
- Do not add `default` that swallows new enum values silently unless product requires it.

### 6.3 Tests

Update tests in the branch that relied on soft types:

- Fixtures must satisfy hard types (full objects, not partials — unless testing the draft path).
- Add/adjust tests that invalid boundary input **rejects**, not soft-succeeds.

---

## Phase 7: Verify

### 7.1 Typecheck affected projects

Prefer Nx (per monorepo Agents.md):

```bash
# Identify projects from changed paths, then:
yarn nx run-many -t typecheck -p <projects>
# or project-specific: yarn nx run web-crm:typecheck / tsc -p ...
```

If no typecheck target, use the package's `tsc --noEmit` / existing CI script.

### 7.2 Loop

While type errors remain that were caused by this hardening:

1. Classify: still-soft type vs real logic bug vs intentional optional
2. Fix hard (never re-introduce `any` to green the build)
3. Re-run typecheck

### 7.3 Lint (optional but recommended)

If eslint has `@typescript-eslint/no-explicit-any` or similar, ensure changed files are clean.

Stop looping if the only remaining errors are **pre-existing on base** and untouched by this skill — note them in the report, do not boil the ocean.

---

## Phase 8: Report

```markdown
## fix-types Report

**Scope**: [branch / PR #] vs [base]
**Files scanned**: [N type-bearing]
**Soft types found**: [N]
**Hardened**: [N]
**Intentional soft left**: [N]
**Call sites updated**: [N]
**Typecheck**: [pass / pass with notes / blocked]

### Hardened

| File | Before | After | Ground truth |
|------|--------|-------|--------------|
| path:line | `orgId?: string` | `orgId: string` on `AuthenticatedSession` | auth middleware always sets org |

### Call-site / runtime fixes

| File | Change |
|------|--------|
| path | Removed `?? ''`; throw if session missing org at boundary |

### Intentional soft types (kept)

| File | Type | Why allowed |
|------|------|-------------|
| path | `deletedAt: Date \| null` | Nullable column; soft-delete |

### Skipped / out of scope

| Item | Reason |
|------|--------|
| Unrelated package soft types | Outside PR diff |

### Follow-ups (if any)

- [ ] e.g. regenerate Prisma client in CI
- [ ] e.g. product decision needed on optional field X
```

---

## Severity / Priority When Triaging

Work in this order:

1. **`any` / type erasure** — always fix
2. **Required domain fields typed optional/nullish** — fix + call sites
3. **Partial / loose records in domain** — replace with exact types
4. **Over-wide string/number** — literal unions / enums
5. **Missing explicit return types** that hide soft inference — add hard returns
6. **Cosmetic** — only if they affect safety

If the PR is huge, fix all `any` + required-nullish first, then continue until typecheck is clean or user stops.

---

## Interaction Rules

1. **Don't ask permission for routine hardening** inside the PR scope (`any` → exact type, remove bogus `\| undefined`, fix call sites).
2. **Do ask** when hardening would change external API contracts, public package exports, or DB schema nullability — present the proposed hard type and wait.
3. **Do ask** when product intent for null vs missing is unclear (e.g. is "no avatar" `null`, omit field, or empty string?).
4. **Never expand scope** into drive-by refactors unrelated to types on this branch.
5. **Align with monorepo rules** — use Nx targets; respect existing validation libraries; no hand-edit of generated clients.

---

## Error Handling

| Error | Action |
|-------|--------|
| No PR and empty/unclear branch diff | Stop and explain |
| Schema file missing / can't find ground truth | Read producers/consumers; if still ambiguous, ask user with options |
| Typecheck target fails for unrelated reasons | Isolate errors from this change; fix only ours; report the rest |
| Hardening breaks a public API the branch didn't mean to change | Revert that surface; propose a follow-up or versioned type |
| User wants one file only | Limit inventory + fixes to that path |

---

## Important Rules

1. **Hard definition of what can be expected** — that is the bar for almost every type.
2. **Rarely** keep `any`, `undefined`, or `null`; when kept, document why in the report.
3. **Schema and contracts win** over local convenience.
4. **Fix the code around the type** so the branch is correctly hard end-to-end.
5. **Never green the build by softening types.**
6. **Never fabricate schema facts** — open the Prisma/Zod/API source.
7. **PR/branch scoped** — leave the rest of the monorepo alone.
8. **Boundary parse once** — core code trusts hard types.
9. **Two types over one soft type** when lifecycle differs (draft vs saved, raw vs parsed, anonymous vs authenticated).
10. **Report clearly** so the user can review intentional soft leftovers.
11. **Always isolate in a code-only worktree first** (Phase 0). **Yarn install is mandatory** on every worktree (create, reuse, already-isolated). Never skip yarn because `node_modules` exists.

User arguments: $ARGUMENTS
````

#### `~/.ai/skills/implement-as-stack/SKILL.md`

````markdown file=~/.ai/skills/implement-as-stack/SKILL.md
---
name: implement-as-stack
description: >
  Implements a plan, PRD, or design doc as a GitHub stacked pull request: slices
  work into ordered dependency layers, implements each layer on its own branch,
  and opens them as a native GitHub stack (gh stack). Use when the user says
  "/implement-as-stack", "implement as stack", "stack this plan", "implement and
  stack", "ship as stacked PRs", or wants a large plan delivered as multiple
  dependent PRs instead of one monolithic PR.
---

# /implement-as-stack

Implement a plan as an ordered **GitHub stacked PR** (public-preview Stacked PRs).
Each layer is a focused, independently reviewable PR; higher layers base on the
branch below them; the bottom PR targets trunk (`main` by default).

**Usage:**
```text
/implement-as-stack <plan|prd|design-doc|issue>
/implement-as-stack docs/prd/user-dashboard.md
/implement-as-stack #42
/implement-as-stack path/to/design.md
```

**Outcome:** a remote stack of 2+ PRs, bottom-up mergeable, with stack map on GitHub.

---

## Hard rules

1. **Never push to `main` / `master`.** Trunk is only the stack base.
2. **Never invent a one-shot “split PR” button.** Stacks require real branches chained by base.
3. **Get explicit user approval of the stack plan** (layer names, order, scope) before writing code.
4. **Implement bottom-up.** Lower layers must not depend on higher ones.
5. **One concern per layer.** Prefer 2–8 layers. Cap is 100 PRs (GitHub); do not approach it.
6. **Linear history only.** No merge commits inside stack branches.
7. **Use `gh stack` for submit/link** when available; fall back to manual base chaining + `gh stack link`.
8. Prefer **specialized subagents** for heavy implementation (same spirit as `/implement`); orchestrator owns stack structure, git, and submit.
9. Do **not** merge the stack unless the user asks.

---

## Prerequisites

Run early; fix before implementing.

```bash
# gh auth
gh auth status

# Stacked PRs CLI (optional but preferred)
gh extension list | grep -q 'gh-stack' || gh extension install github/gh-stack

# Clean starting point
git status
git branch --show-current
git fetch origin
```

- Working tree should be clean (or only intentional WIP the user wants included).
- Default trunk: repo default branch (`gh repo view --json defaultBranchRef -q .defaultBranchRef.name`), usually `main`.
- If `gh stack` fails with “Stacked PRs not enabled” (exit 9), stop and tell the user the repo may not have public-preview stacks yet; offer manual dependent-PR chain without stack metadata.

---

## Phase 0 — Resolve the plan

1. **Source:**
   - Local path → read the file
   - GitHub issue `#N` / URL → `gh issue view N --json title,body,labels,url`
   - If the issue links a PRD/design path, read that too
2. **Extract:** goals, task checklist, file mapping, API/schema changes, UI work, tests, non-goals
3. **Name the stack** from the feature (kebab-case), e.g. `user-dashboard`
   - Branch pattern: `stack/<feature>/<layer>` or `feat/<feature>-<layer>`
   - Prefer short, stable layer slugs: `schema`, `api`, `ui`, `tests`

---

## Phase 1 — Slice into stack layers (approval gate)

Produce a **Stack Plan** and show it to the user. **Do not implement until they approve.**

### Layering heuristics

Put dependencies **below** dependents:

| Priority (bottom → top) | Typical contents |
|-------------------------|------------------|
| 1. Foundation | Schema/migrations, shared types, config, feature flags |
| 2. Domain / API | Server handlers, services, validation, authz |
| 3. Client / UI | Components, routes, state wired to API |
| 4. Polish / tests | Integration/E2E, docs, cleanup only if it cannot live with its layer |

**Split when:**
- Concern changes (DB → API → UI)
- A layer is already large to review (~>300–400 lines of meaningful diff as a rough guide)
- Different CODEOWNERS / review audiences
- Later work needs earlier work merged-or-reviewable first

**Do not split when:**
- The whole change is tiny (one PR is fine — say so and offer `/pr` instead)
- Artificial slices would leave a layer non-functional or unreviewable in isolation
- Pure renames/formatting with no dependency story

### Stack Plan template (show the user)

```markdown
## Stack plan: <feature>

**Trunk:** `main` (or other)
**Why stack:** <1 sentence>

| # | Branch | Layer | Scope | Depends on |
|---|--------|-------|-------|------------|
| 1 | `feat/foo-schema` | Schema | Prisma + types | trunk |
| 2 | `feat/foo-api` | API | endpoints, services | #1 |
| 3 | `feat/foo-ui` | UI | pages/components | #2 |

**Out of scope:** ...
**Risks:** ...
**Ready to implement?** (yes / adjust layers)
```

Adjust layers from feedback, then proceed.

---

## Phase 2 — Initialize the stack

```bash
TRUNK=$(gh repo view --json defaultBranchRef -q .defaultBranchRef.name)
git checkout "$TRUNK"
git pull origin "$TRUNK"

# Preferred: local stack tracking
gh stack init --base "$TRUNK" "<branch-layer-1>"
```

If `gh stack init` is unavailable, create branches manually later and use `gh stack link` at the end.

Record approved branch names in the todo list (one todo per layer + final submit).

---

## Phase 3 — Implement each layer (bottom → top)

For **each** layer `i` from 1..N:

### 3.1 Checkout / create layer branch

```bash
# Layer 1 already checked out from init.
# For layer i > 1, after committing layer i-1:
gh stack add "<branch-layer-i>"
# Now on empty top branch based on previous layer HEAD
```

Manual fallback:
```bash
git checkout -b "<branch-layer-i>"   # from previous layer tip
```

### 3.2 Implement only this layer’s scope

- Spawn specialists when useful:
  - `backend-architect` — schema, API, services
  - `frontend-developer` — UI
  - `test-writer-fixer` — tests for this layer (or a top test layer)
  - `devops-automator` — CI only if the plan requires it
- **Do not** implement higher-layer code “while you’re here.”
- Lower layers must leave the tree **buildable** when possible (stubs/types OK if called out in the PR body).
- Follow repo conventions (Nx via `nx`, monorepo AGENTS.md, etc.).

### 3.3 Verify the layer

Run the lightest checks that match the layer (prefer project standards):

```bash
# examples — pick what the repo uses
yarn nx run-many --target=typecheck --projects=<touched>
yarn nx run <project>:test
# or package scripts / tsc as appropriate
```

Fix failures before committing the layer.

### 3.4 Commit the layer

```bash
git status
git diff
git log --oneline -5

git add -A
git commit -m "$(cat <<'EOF'
feat(<scope>): <layer summary>

<why this layer exists in the stack>

EOF
)"
```

Use conventional commits. One logical commit per layer is ideal; multiple fine commits OK if history stays linear and reviewable. **No merge commits.**

### 3.5 Advance

Only after the layer is committed and green enough, `gh stack add` the next branch (or create it) and continue.

---

## Phase 4 — Submit the stack

When all layers are implemented and committed:

```bash
# Push branches, open/update PRs, create the GitHub Stack object
gh stack submit --auto --open
```

Notes:
- `--auto` skips the interactive editor (required in non-interactive agent terminals).
- `--open` marks PRs ready for review (omit to keep drafts if the user prefers drafts).
- If submit is interactive-only in some environments, fall back to:

```bash
gh stack push
gh stack link --open <branch-1> <branch-2> <branch-3>
```

Or fully manual:
```bash
git push -u origin <branch-1> <branch-2> <branch-3>
gh pr create --base "$TRUNK" --head <branch-1> --title "..." --body "..."
gh pr create --base <branch-1> --head <branch-2> --title "..." --body "..."
# then stack via UI banner or:
gh stack link <pr1> <pr2> <pr3>
```

### PR bodies (each layer)

Each PR is a **handoff**, not a changelog dump:

```markdown
## What & why
[This layer’s goal. How it fits the stack.]

Part of stack: **<feature>** (layer i of N)
Depends on: #<lower-pr> / `<lower-branch>`
Enables: <upper layers>

## Scope
- In: ...
- Out (other layers): ...

## Notes for the reviewer
[Risks, decisions, what to scrutinize]

## Verification
[What you ran for this layer]
```

Bottom PR may `Closes #N` if the whole feature is issue-linked; upper PRs should reference the issue without multiple competing closers unless intended.

Cross-link stack order in every body (bottom → top list).

---

## Phase 5 — Report

```markdown
## Stack implemented

**Feature:** ...
**Trunk:** main
**Stack:** [view on GitHub](<url if known>)

| # | Branch | PR | Title |
|---|--------|-----|-------|
| 1 | ... | #.. | ... |
| 2 | ... | #.. | ... |

**How to review:** start at the bottom PR; each shows only its layer diff.
**How to merge:** bottom-up (merging mid/top lands everything below it).
**Restack:** `gh stack rebase` / `gh stack sync`, or **Rebase Stack** in the UI.

### Not done
- Merge (needs human/CI)
- Anything deferred from the plan
```

Also run `gh stack view` (or `gh stack view --json`) and paste a short status.

---

## Restructuring mid-flight

| Need | Action |
|------|--------|
| Add a layer on top | `gh stack add <name>` → implement → `gh stack submit --auto --open` |
| Reorder / fold / drop | Prefer `gh stack modify` (interactive). If non-interactive: unstack, fix branches, `gh stack init` + `submit` again |
| Dissolve stack | `gh stack unstack` (merged/queued PRs cannot leave the stack) |
| Trunk moved / conflicts | `gh stack rebase` then `gh stack push` or `gh stack sync` |

Do not leave the stack non-linear after mid-stack edits.

---

## Error recovery

| Problem | Fix |
|---------|-----|
| Dirty tree before init | Stash/commit/discard with user intent |
| On main with WIP | Branch first; never commit feature work on trunk |
| Layer typecheck fails | Fix before `gh stack add` next layer |
| Rebase conflict | Resolve → `gh stack rebase --continue` or `--abort` |
| `gh stack` exit 9 | Stacks not enabled; use manual dependent PRs and say so |
| Submit created drafts unwanted | `gh pr ready` per PR or resubmit with `--open` |
| Accidentally coded upper layer into lower | Move commits up with careful rebase/`gh stack modify`; do not merge broken layering |
| Single tiny change | Abort stack plan; one PR via normal `/pr` flow |

---

## Relationship to other skills

| Skill | When |
|-------|------|
| `/implement` | Same implementation depth, **one** branch — no stack |
| `/pr` | Single-branch PR workflow after ad-hoc work |
| `/implement-as-stack` | Plan → multi-layer branches → **stacked** PRs |
| `/prd` | Produce the plan this skill consumes |

If the user already has one fat branch and wants a stack, do **not** pretend GitHub will split it: re-slice commits into layer branches (interactive rebase or file-based checkout), then `gh stack init` / `gh stack link`.

---

## Quick checklist

- [ ] Plan resolved and understood
- [ ] Stack plan approved by user
- [ ] `gh` auth OK; `gh-stack` installed or fallback chosen
- [ ] Trunk updated; not committing on main
- [ ] Each layer: implement → verify → commit → add next
- [ ] Linear history; each layer reviewable
- [ ] `gh stack submit --auto --open` (or link fallback)
- [ ] Report table of PRs + merge guidance
- [ ] Did **not** merge unless asked

**If you opened one giant PR instead of a stack, the approach is wrong.**
````

#### `~/.ai/skills/implement-as-stack/references/gh-stack-cheatsheet.md`

````markdown file=~/.ai/skills/implement-as-stack/references/gh-stack-cheatsheet.md
# gh-stack cheatsheet (for /implement-as-stack)

Install: `gh extension install github/gh-stack`

Docs: https://github.github.com/gh-stack/  
About: https://docs.github.com/en/pull-requests/get-started/about-stacked-prs

## Happy path

```bash
gh stack init --base main feat/foo-schema
# ... commit layer 1 ...
gh stack add feat/foo-api
# ... commit layer 2 ...
gh stack add feat/foo-ui
# ... commit layer 3 ...
gh stack submit --auto --open
```

## Essential commands

| Command | Purpose |
|---------|---------|
| `gh stack init [--base B] [branches...]` | Start local stack; adopt/create branches bottom→top |
| `gh stack add <branch>` | New empty branch on top of current stack tip |
| `gh stack submit --auto --open` | Push, create/update PRs, create GitHub Stack |
| `gh stack link [--open] b1 b2 b3` | Stack without local tracking (or after manual branches) |
| `gh stack push` | Force-with-lease push active stack branches |
| `gh stack rebase` | Cascading rebase onto trunk/parents |
| `gh stack sync` | Fetch + rebase + push + sync PR/stack state |
| `gh stack view [--json]` | Show stack |
| `gh stack unstack` | Dissolve stack (local+remote tracking) |
| `gh stack up` / `down` / `top` / `bottom` / `trunk` | Navigate |

## Agent notes

- Prefer `--auto` on `submit` in non-interactive agent shells.
- Use `--open` when PRs should be ready for review (default with `--auto` alone is drafts).
- Exit code **9** = stacked PRs not enabled for the repository.
- Server-side UI “Rebase Stack” force-pushes **unsigned** commits; local `gh stack rebase` respects local signing.
- Cross-fork stacks are not supported; all branches same repo.
- Merge is bottom-up; merging mid PR lands it **and everything below**.

## Manual chain (no local tracking)

```bash
# branches already exist bottom→top with correct parent commits
gh stack link --open feat/foo-schema feat/foo-api feat/foo-ui
```
````

#### `~/.ai/skills/peer-review/SKILL.md`

````markdown file=~/.ai/skills/peer-review/SKILL.md
---
name: peer-review
description: Builds a feature with a three-round peer review loop. The main agent plans and implements, then three FRESH review rounds run in sequence. Within each round, specialist agents (security, silent-failure/soft-types, recurring patterns, correctness/plan-fit, testing, dead-code/stale-comments, duplication/extract-to-shared, architecture sense-check) spawn in parallel with no prior-round context. After each round, the main agent merges actionable comments, triages every comment as accept / reject / defer with reasoning, then implements accepted changes before the next round. Architecture sense-check notes are advisory only (never trigger a redo mid-loop) and surface to the user only at the end if the agent has a clear concern. Use when user says "/peer-review <task>", "/peer-review <prd-file>", "/peer-review #42", or asks for a "reviewed" / "triple-reviewed" / "peer-reviewed" implementation.
allowed-tools: Read, Grep, Glob, Bash, Edit, Write, Task, TaskCreate, TaskUpdate, TaskList, WebFetch
permissionMode: acceptEdits
---

# /peer-review — Plan, Implement, Review x3, Triage

> **Prefer the workflow when possible.**  
> Run `/peer-review` as a **workflow** (`.grok/workflows/peer-review.rhai` or `~/.grok/workflows/peer-review.rhai`) instead of this skill when you want durable orchestration. The workflow keeps the same specialist concerns but is better in important ways:
>
> | Skill (this file) | Workflow |
> |-------------------|----------|
> | Implementer also triages findings (bias) | Fresh independent judge |
> | Findings accepted on trust | Adversarial verify, fail-closed (evidence required) |
> | Always 3 full rounds × 8 specialists | Default 2 rounds; early exit; round 2 is delta-only; arch once |
> | Free-form markdown, main-thread orchestration | Structured schemas, scratch artifacts, resumable `/workflows` UI |
> | ~24+ review agents fixed | Budget-aware caps (`MAX_VERIFY=12`, 6 findings/specialty) |
>
> **Workflow usage:**  
> `/workflow peer-review` with args  
> `{ "task": "<description | prd path | #issue>", "rounds": 1|2, "base": "main" }`  
> Or from the tool: `workflow(name: "peer-review", args: #{ task: "..." })`.  
> Watch progress in `/workflows`.
>
> Use **this skill** when you want the interactive main agent to plan/implement in-conversation (more chat control, less structure).

---

A development loop where a main agent produces a solution and three independent review **rounds** stress-test it in sequence. **Within each round, multiple specialist agents run in parallel** (one concern type each), so the round finishes much faster than a single mega-reviewer. Each round starts with a fresh set of agents (no prior-round context). The main agent merges specialist comments, triages every comment, and implements accepted changes before the next round begins. One specialist (architecture sense-check) is **advisory only**: it never asks the main agent to re-architect mid-loop; notes accumulate and surface to the user only at the end if there is a clear concern.

**Usage (skill / interactive):** `/peer-review <task-description | prd-file-path | github-issue>`

**Examples:**
- `/peer-review add rate limiting to the public API` — free-form task
- `/peer-review docs/prd/user-dashboard.md` — read a PRD file
- `/peer-review #42` — fetch GitHub issue #42 (uses repo of current working directory)
- `/peer-review https://github.com/org/repo/issues/42`

---

## Core Invariants

These rules MUST hold for every run. If you cannot satisfy them, stop and tell the user why.

1. **Three review rounds, in sequence.** Not two, not four. Round N+1 must not start until round N is fully triaged and accepted changes are implemented.
2. **Within each round, specialists run in parallel.** Spawn one agent per concern type **in a single tool-call batch**. Do not run security → silent-failure → testing as sequential main-agent work or sequential single agents.
3. **Reviewers see no prior rounds.** Every specialist prompt must include the plan and the current code state ONLY. It MUST NOT contain prior round comments, prior decisions, or any acknowledgement that earlier rounds happened.
4. **Specialists stay in their lane.** Each agent reviews only its concern type. Overlap is OK; the main agent deduplicates when merging.
5. **Every actionable comment is triaged.** The main agent decides per comment from actionable specialists (S1–S5, S7–S8): `accept` (implement now), `reject` (with reasoning), or `defer` (with reasoning + scope note). No actionable comment is silently ignored.
6. **Architecture sense-check (S6) is advisory only.** S6 never produces accept/reject/defer items and **must never** cause the main agent to re-architect or redo the feature mid-loop. Persist notes quietly; surface them to the user only in Phase 3, and only if S6 has a clear concern.
7. **Accepted changes are implemented before the next round.** The next round's specialists read the updated code. Earlier accepted feedback is reflected in the code itself, not in side text.
8. **All artifacts are persisted.** Plan, per-round comments, per-round decisions, architecture notes, and final summary all live in `.peer-review/` so the user can audit the whole loop.
9. **Never stall the loop on a missing reviewer.** A specialist that errors, times out, hangs, or never returns a usable review is a failure. Retry that specialty once, then continue. Do not sit idle waiting for a notification that may never come.

---

## Phase 0 — Resolve Input

The single argument can be one of three forms. Detect and dispatch:

1. **GitHub issue** — matches `^#?\d+$` or contains `github.com/.*/issues/\d+`:
   - For `#NNN` or bare `NNN`: detect the repo from `git remote get-url origin` in the CWD, then `gh issue view <NNN> --repo <owner>/<repo>`
   - For full URL: parse repo + issue number, then `gh issue view`
   - If a PRD path is referenced in the issue body, read it too
2. **File path** — argument exists as a file on disk (use `Read`):
   - Treat the file contents as the spec
3. **Free-form description** — anything else:
   - Treat the argument as the task description directly

If detection is ambiguous (e.g. a string that could be either a filename or a description), prefer the most concrete: check filesystem first, then issue pattern, then fall back to free-form.

Save the resolved spec to `.peer-review/spec.md` (verbatim for files/issues, or the user's free-form text as a one-paragraph spec for free-form inputs).

---

## Phase 1 — Plan and Implement

The MAIN agent (you, in this conversation) does this phase directly. Do not delegate the plan.

1. **Create the plan.** Write a concrete plan to `.peer-review/plan.md`. The plan must include:
   - **Goal** — one paragraph restating the task in your own words
   - **Approach** — the design / architecture choice and the main tradeoff you're accepting
   - **Files to create or modify** — explicit list of paths
   - **Consumer / dual-path map** — for every new or moved field/abstraction, list who must read or honor it (API schema, DB, list/read UI, exporters/transformers for **each** pipeline, importers, jobs). Mark any intentionally deferred consumer under Out of scope.
   - **Invariants & concurrency** — what must be unique / atomic; whether a DB constraint or transaction enforces it
   - **AuthZ** — who can call new procedures and which existing gate (role/assignment/tenant helper) is reused
   - **Failure modes** — what hard-fails vs user-visible degradation; no silent ACTIVE/success on failed setup
   - **Out of scope** — what you are deliberately NOT doing, so reviewers don't churn on it
   - **Open questions** — anything you're uncertain about (reviewers can weigh in)
2. **Track tasks.** Use `TaskCreate` to enumerate the implementation steps from the plan. Update them as you go.
3. **Implement.** Write the code. Use specialized agents (`backend-architect`, `frontend-developer`, etc.) via the `Task` tool when the work clearly fits their domain — otherwise do it yourself. Verify it builds / type-checks before declaring Phase 1 complete.
   - While implementing, self-check the recurring patterns (soft success, write-only wiring, races, thin authZ, mount wipes, dual-path drift, envelope casts, tests that assert failure paths) so round 1 does not rediscover basics.
4. **Snapshot files changed.** Write the list of created/modified paths to `.peer-review/files-touched.md` — one path per line. This is the file set the specialists will examine.

Do not announce "ready for review" to the user. Move directly into Phase 2.

---

## Phase 2 — Three Sequential Rounds (Parallel Specialists Inside Each Round)

Loop the following EXACTLY three times. Variable `N` is the round number (1, 2, 3).

```
Round N:
  2.N.a  Spawn ALL specialists in parallel (one agent per concern)
  2.N.b  Wait for all specialists; merge S1–S5 + S7–S8 into round-N-comments.md; stash S6 notes only
  2.N.c  Triage every actionable comment → round-N-decisions.md (S6 is never triaged)
  2.N.d  Implement accepted changes
  2.N.e  Update files-touched.md
```

### 2.N.a — Spawn parallel specialist agents

Spawn **eight** independent agents in **one tool-call batch** (same turn). Use the platform's multi-agent tool (`Task` / `spawn_subagent` / equivalent).

| Specialist ID | Concern | subagent_type | description | Actionable? |
|---------------|---------|---------------|-------------|-------------|
| **S1** | Correctness / plan-fit / edge cases | `general-purpose` | `Peer R{N}: correctness` | Yes — triage |
| **S2** | Security / authZ / secrets | `backend-architect` (fallback: `general-purpose`) | `Peer R{N}: security` | Yes — triage |
| **S3** | Silent failure / soft types | `general-purpose` | `Peer R{N}: silent fail` | Yes — triage |
| **S4** | Recurring PR patterns R1–R10 | `general-purpose` | `Peer R{N}: recurring` | Yes — triage |
| **S5** | Testing gaps | `test-writer-fixer` (fallback: `general-purpose`) | `Peer R{N}: testing` | Yes — triage |
| **S6** | Architecture sense-check | `general-purpose` (or `plan` if available) | `Peer R{N}: arch sense` | **No** — advisory notes only |
| **S7** | Dead code / unused / stale comments | `general-purpose` | `Peer R{N}: dead code` | Yes — triage |
| **S8** | Duplication / extract-to-shared | `general-purpose` | `Peer R{N}: duplication` | Yes — triage |

Prefer `capability_mode: read-only` (or equivalent) so specialists cannot edit code.

**Do not** spawn one mega-reviewer. **Do not** wait for S1 before launching S2–S8.
**Do not** treat S6 output as work for the main agent. Never re-architect or rewrite the feature because of S6 during the loop.

---

### Shared prefix for every specialist (round N)

Interpolate plan + files. Never include prior-round artifacts.

```
You are an independent specialist code reviewer for ONE concern only (stated below).
You have no prior context about this work — review what you see, not what you assume.
You do not know about other specialists or other review rounds.

## The plan

The implementing engineer wrote this plan before coding:

---
{contents of .peer-review/plan.md}
---

## Files implemented

These files were created or modified for this work:

{contents of .peer-review/files-touched.md}

## Shared rules (all specialists)

1. Read the plan carefully. Note what is explicitly OUT OF SCOPE — do not raise comments about those.
2. Read every file in the list above using the Read tool. Read the full file, not just changed regions.
3. Stay in your specialty. Skip issues owned by other specialists unless they are inseparable from your finding.
4. Do not modify any code. Review only.
5. Do not read `.peer-review/round-*` files. Your review must be independent.
6. Be specific. "Add error handling" is useless; cite file:line and a concrete change.
7. If you have nothing substantive for your specialty, return an empty Comments section with Summary: "clean for this specialty" — do not pad.
8. Severity: blocker | major | minor | nit

## Comment format (each specialist uses local IDs S1, S2, ... within their own output)

Write findings ONLY (no need to write a full markdown file — return structured markdown in your final message):

```markdown
# Specialist: <SPECIALTY_NAME> (round N)

## Summary
One paragraph: overall impression for THIS specialty only.

## Comments

### S1 — <short title>
- **Severity**: blocker | major | minor | nit
- **File**: path/to/file.ts:LINE (or "general")
- **Observation**: what you see
- **Why it matters**: concrete consequence
- **Suggested change**: specific change, not a vague direction

### S2 — ...
```

This is round: N
Your specialty: <SPECIALTY_NAME>
```

---

### S1 — Correctness / plan-fit / edge cases

Append to shared prefix:

```
## Your specialty: Correctness / plan-fit / edge cases

Review ONLY for:
- Mismatches between the plan and the implementation
- Logic bugs, edge cases, off-by-one, null derefs, race/async ordering
- Incomplete error handling that is pure correctness (not the soft-fail catalog)
- Maintainability issues that meaningfully hurt this change
- Missing cleanup, wrong status codes, copy-paste bugs

Do NOT deep-dive: injection/auth catalogs, silent-fallback catalogs, R1–R10 checklists, unused-import/dead-symbol cleanup, extract-to-shared DRY, or test-suite design (other specialists).
```

---

### S2 — Security / authZ / secrets

Append to shared prefix:

```
## Your specialty: Security / authZ / secrets

Review ONLY for:
- Injection (SQL/NoSQL/command/XSS/template)
- Missing or weak auth checks; broken access control
- Thin tenant checks without assignment/role gates used elsewhere
- Over-broad procedures (PENDING/onboarding performing privileged side effects)
- Identity vs capability conflation
- Auth that fails open (`catch { return true }`)
- Secrets/PII in logs or responses; env names in user-facing errors
- Cross-tenant leakage; missing input validation on new endpoints
- Crypto/session/JWT issues

Do NOT deep-dive: performance, silent-fallback type hardening (except fail-open auth), test coverage, or plan-fit nits.
```

---

### S3 — Silent failure / soft types

Append to shared prefix:

```
## Your specialty: "Just make it work" / silent-failure / soft types

Prefer hard failures with clear errors over continuing in a wrong state — unless the fallback
is intentional, documented, user-visible graceful degradation.

**Root cause of many fallbacks: soft types.** Prefer a hard, exact type + validation boundary —
never `any` / type-erasure.

### Silent / swallowed failures
- Empty catch, or catch that only logs and continues as success
- `.catch(() => undefined|null|[]|{})`
- try/catch returning default "success" on failure
- Fire-and-forget async where failure should affect the caller

### Fallbacks that should hard-fail
- Critical config/env defaults that hide misconfiguration
- Empty arrays/objects/`null` when required data is missing
- `|| []`, `?? []`, `?? {}`, `?? ''` papering over unexpected null/undefined
- Long optional chains on required paths
- Production mock/stale/placeholder fallbacks without product requirement
- Parse failures converted to silent defaults
- Retry that "succeeds" with partial/empty data

### Soft types that force soft fails
For every fallback you flag:
1. Trace the type of the value being defaulted
2. Name the **exact** expected hard type (field-by-field if needed)
3. Prefer fixing the type so the fallback is unnecessary
4. Never suggest `any`, `as any`, double casts, blanket `!`, or `@ts-ignore` as the fix

Flag: optional fields that should be required, `Partial<T>` for loaded entities, unvalidated JSON
deep in domain, empty success when absence is error, optional params only to make call sites compile,
DB selects omitting fields that code then defaults.

### Type papering & soft-fail behavior
- `as any` / double casts / non-null `!` to silence the compiler
- Partial success as full success; validation that warns and continues
- Auth fail-open (also report — security specialist may overlap; still flag)

For each finding include:
1. What happens on failure today
2. What should happen instead
3. Soft-type root cause? → exact hard type + boundary
4. Concrete fix (not more defaults, not `any`)

Severity: auth fails-open and data-loss soft-fails = blocker/major; config/required-data silent defaults
and soft-type fallback cascades = major; suggesting `any` = major; non-critical swallows = minor.
```

---

### S4 — Recurring PR patterns (R1–R10)

Append to shared prefix:

```
## Your specialty: Recurring PR failure patterns (R1–R10)

Walk this checklist against the touched files. Flag hits with blocker/major when they can cause
data loss, wrong money/credit/AUS/messaging behavior, cross-tenant issues, or "looks healthy while broken."
For R2/R6, read consumers outside the touched list when needed.

### R1 — Soft failure that looks like success
- Catch/log-and-continue while status claims ACTIVE / ready / success
- Empty fallbacks on **required** export/vendor payloads instead of preflight throw
- Setup failures swallowed so feature looks live
- Tests skip/pass when fixtures missing
- Polling-only UIs with no recovery if webhooks never land

### R2 — Incomplete end-to-end wiring (write-only)
UI → API/schema → DB → read/list → export transformers (each pipeline) → import → jobs → shared sites
- Partial shared-component adoption; clear/reset without live side-effect update; deleted write path without re-home
If deferred, plan must say so; else blocker/major.

### R3 — App-only invariants and races
- Uniqueness only in app code; check-then-act without atomicity; counter without unique+retry
- Tenant-scoped unique on globally unique vendor resource; multi-step writes missing transaction

### R4 — Thin authZ / tenant / secret boundaries
- Weaker gates than siblings; over-broad callers; identity mixed with capability filters
- Env names in user errors; PII/secrets logged; dual-pipeline redaction gaps

### R5 — Form hydration / mount wipes
- useEffect mount write without hydration sentinel; auto-flip nulling persisted enums/booleans
- Partial updates nulling omitted fields

### R6 — Dual-path inconsistency
- Parallel transformers with different predicates; CRM vs funnel / admin vs LO rule drift
- Dual schemas; sticky columns vs live derivation; actor identity changes across steps

### R7 — Envelopes / partial updates / type lies
- Casts to guessed shapes vs real envelopes; omitted fields set to null; `as any` to compile

### R8 — Tests that do not protect the change
- No unit test on new branches/guards; happy-path-only fixtures; no-op when inputs absent
- Prefer a test that would fail if silent-success or write-only bug returned
(Overlap with testing specialist is OK — focus on "does this test protect the failure mode?")

### R9 — UX recovery and edge states
- Missing loading/error/cancel/retry/stale handling; double-submit; broken image fallback
- Eager per-row work without cleanup/virtualization

### R10 — Consistency with codebase patterns
- Reinventing existing helpers; arbitrary design tokens/z-index; incomplete a11y for tab-like UI

In **Why it matters**, name the production failure mode. In **Suggested change**, prefer DB constraints,
existing auth helpers, hard preflight throws, full consumer wiring, tests that pin the failure path —
not more `??` defaults.
```

---

### S5 — Testing gaps

Append to shared prefix:

```
## Your specialty: Testing gaps

Review ONLY for missing or weak tests. Do not redesign product logic except to say what assertion would catch a bug.

- New branches/logic without unit tests (especially refusal/guard/migration/backfill)
- Modified behavior without updated tests
- Fixtures hardcoding happy path so assertions always pass
- Tests that no-op green when fixtures/reference files are missing
- Missing tests that assert **failure** paths
- Behavior/UI contract changes without e2e/integration updates
- Prefer at least one test that would **fail** if a silent-success or write-only bug returned

For each comment: where the test should live, what to assert, and what bug it would catch.
```

---

### S7 — Dead code / unused / stale comments

Append to shared prefix:

```
## Your specialty: Dead code / unused / stale comments

Remove refactor leftovers. Prove unused with grep/read — do not guess.

### Unused imports & symbols
- Unused imports (named/default/type-only/unneeded side-effect)
- Unused locals, params, private helpers, types, constants
- Exports/re-exports with no in-repo consumers (unless intentional public package API)
- Dead/unreachable branches after condition changes
- Assigned-never-read variables; leftover feature-flag/env reads

### Stale / useless comments (prefer delete)
- Comments narrating removed behavior: "used to", "previously", "was", "no longer", "removed X", "old path"
- Large commented-out code blocks; JSDoc that contradicts current signatures
- TODOs/FIXMEs already done or pointing at deleted code
- Leftover section banners for deleted code
- Obvious narrating comments added/left by this change that add no non-obvious intent

### Do NOT flag
- Symbols used via types/decorators/DI/framework reflection
- WHY/invariant/security comments that still apply
- WIP blocks with an active tracking TODO + issue
- Broad cleanups outside this change's blast radius

Severity: unused import = nit; dead private helper / misleading stale comment = minor/major;
stale comment that contradicts auth/security behavior = major/blocker.
For each: proof of zero refs (or quote the stale comment) + exact delete.
```

---

### S8 — Duplication / extract-to-shared

Append to shared prefix:

```
## Your specialty: Duplication / extract-to-shared

Flag repeated logic only when ALL hold:
1. **≥ 3 real occurrences** after this change (in touched files and/or existing codebase)
2. **Would realistically be used more** (sibling features, list+detail+export, dual pipelines, repeated fields)
3. **Stable enough to name** — not coincidental similar shape with different invariants
4. **Extraction reduces drift risk** — not a premature flag-soup helper

### Scope of the shared home (required on every finding)
Pick from usage count + where copies live:
| Fan-out | Scope |
|---------|--------|
| 3+ in one file | Private helper in that file |
| 3+ in one feature/module | Module `utils` / `helpers` beside the feature |
| 3+ across one app | App-level shared module already used for similar things |
| 3+ across apps / FE+BE domain rule | Existing monorepo `libs/` domain package |
| Near-match to existing helper | Extend/reuse that helper — no parallel utility |

Always include: occurrence count, file:line list, proposed symbol + path, params vs identical core.
Search the repo — do not only look inside the touched list.

### Do NOT flag
- Only 2 weak lookalikes; intentional test-fixture duplication; trivial one-liners
- Similar control flow with different business meaning
- Huge unrelated DRY refactors disproportionate to this change

Severity: easy local 3-copy helper = minor/nit; drifting copies or dual-path same domain rule = major;
reinvented existing helper = major.
Suggested change must be a concrete signature + home path — not "consider DRY".
```

---

### S6 — Architecture sense-check (advisory only)

Append to shared prefix. **Override** the shared comment format: S6 does **not** emit C#/S# triage items.

```
## Your specialty: Architecture sense-check (advisory)

Your job is to answer one question:

> "Does the way this is implemented actually make sense as it is now?"

Look at:
1. The plan's stated approach and tradeoffs
2. The implemented files end-to-end
3. Surrounding codebase patterns (read related modules, existing helpers, how similar features are done)

Ask yourself: given this codebase and the problem being solved, is the architecture a reasonable fit?
Could a competent engineer reading this in six months understand why it was built this way?

### Stance — default to "fine"

- You are **not** quick to demand a re-architecture. Most working designs that fit local patterns are fine.
- Only speak up when there is a **very clear** more proper way that fits this codebase better, or when the current approach is **clearly poor** (wrong layer, fights existing abstractions, invents a parallel system for something already solved, will force painful follow-ups).
- Style preferences, micro-optimizations, and "I would have named it differently" are NOT findings.
- Preferable-but-not-clearly-better alternatives are NOT findings. Silence is the correct output when the design is acceptable.

### What you may conclude

| Verdict | When | What you write |
|---------|------|----------------|
| **fine** | Design is reasonable for this codebase | Empty note: `Verdict: fine` only — no explanation needed |
| **clear-better-path** | A clearly better architecture exists that fits the grand change and surrounding code | Short note: current approach, why a better path is obvious, what that path is |
| **poor-fit** | Current approach is a poor fit (wrong layer, fights patterns, invents parallel systems) | Short note: what is poor, why, and the coherent alternative |

### Critical constraints

- **Never** tell the implementing agent to redo or re-architect the work.
- **Never** emit Severity / Suggested change / C# comments for triage.
- Your output is a **user-facing advisory note** collected until the end of the peer-review loop.
- Keep notes short (half page max). If fine, keep it to one line.

### Output format (return this only) — do not use Severity / C# items

# Specialist: Architecture sense-check (round N)

## Verdict
fine | clear-better-path | poor-fit

## Note
(Omit entirely when Verdict is fine.)
When not fine: 2–6 sentences.
- What was built and why it was shaped this way (as far as you can tell)
- Why that shape is a poor fit OR why a better path is clearly preferable
- The alternative that makes more sense in this codebase (concrete, not vague)
- Do NOT instruct anyone to rewrite now
```

---

### 2.N.b — Merge specialist outputs into one comments file

Wait until **all eight** specialists finish (or one retry each if a specialist failed).

#### Actionable specialists (S1–S5, S7–S8)

Write `.peer-review/round-N-comments.md` by merging **S1–S5, S7–S8 only**:

1. Start with a round header and a short overall summary (1–3 sentences) synthesized by the main agent.
2. Renumber all specialist comments globally as **C1, C2, C3, ...** (stable order: S1, S2, S3, S4, S5, S7, S8).
3. On each comment, preserve Severity / File / Observation / Why it matters / Suggested change.
4. Add a line: `- **Specialty**: Correctness | Security | SilentFailure | RecurringPattern | Testing | DeadCode | Duplication`
5. Deduplicate near-identical findings from two specialists: keep one comment, note both specialties, keep the stronger severity and the more specific fix.
6. If a specialist returned clean, note under a "Clean specialists" line — do not invent padding comments.
7. **Do not** put S6 content into this file as triageable comments.

Exact format:

```markdown
# Review round N

## Summary
One paragraph: overall impression and the single most important thing the engineer should address.
Specialists run: Correctness, Security, SilentFailure, RecurringPattern, Testing, DeadCode, Duplication, ArchitectureSense (advisory).

## Comments

### C1 — <short title>
- **Specialty**: Security
- **Severity**: blocker | major | minor | nit
- **File**: path/to/file.ts:LINE (or "general")
- **Observation**: ...
- **Why it matters**: ...
- **Suggested change**: ...

### C2 — ...

## Clean specialists
- Testing: no findings

## Architecture sense-check (advisory — not triaged)
- Round N verdict: fine | clear-better-path | poor-fit
- (Full note lives in round-N-architecture-note.md; do not implement from this)
```

#### Architecture specialist (S6) — stash only

Write `.peer-review/round-N-architecture-note.md` with S6's raw output (or `Verdict: fine` if clean/empty).

**Main agent rules for S6:**
- Do **not** triage S6.
- Do **not** implement, re-architect, or open follow-up work because of S6 during the loop.
- Do **not** stream S6 notes to the user mid-loop.
- After all three rounds, keep the **strongest** non-fine verdict across rounds (poor-fit > clear-better-path > fine). If all rounds said fine, the final summary omits architecture entirely.

If a specialist agent produces no usable output: re-spawn **that specialty only** once. If an actionable specialist (S1–S5, S7–S8) fails twice, add a single comment `C? — reviewer-failed (<specialty>)` with severity `major` and continue. If S6 fails twice, write `Verdict: fine` with a one-line note that the architecture specialist failed, and continue (do not block the loop).

---

### 2.N.c — Triage every comment (actionable only)

Read `.peer-review/round-N-comments.md`. For each comment C1, C2, ..., decide.
**Skip S6 entirely** — architecture notes are never accept / reject / defer.

- **accept** — the comment is correct and you will implement the suggested change now
- **reject** — the comment is wrong, already handled elsewhere, or based on a misreading; you must explain why
- **defer** — the comment is reasonable but out of scope for this work; you must explain why and note where it should be tracked (a follow-up issue, a TODO, etc.)

Write decisions to `.peer-review/round-N-decisions.md` in this format:

```markdown
# Round N decisions

## C1 — <title from comment>
- **Decision**: accept | reject | defer
- **Reasoning**: 1-3 sentences. For reject/defer this is mandatory.
- **Implementation note**: (only if accepted) the specific edit you will make

## C2 — ...
```

**Severity is informational, not binding.** A `nit` may be worth accepting if cheap; a `blocker` may be worth rejecting if the reviewer misunderstood. Use judgment.

---

### 2.N.d — Implement accepted changes

Apply every `accept` decision before the next round begins. Use `Edit` / `Write` / specialist Task agents as appropriate. Verify the code still builds / type-checks.

**When the accepted fix is about a soft-fail / fallback / soft type:**
1. Determine the **exact** expected type (domain, API contract, DB schema, caller guarantees) — field-level precision.
2. Introduce or tighten that hard type; validate/narrow once at the appropriate boundary.
3. Remove the silent fallback / empty default / type-papering that prompted the comment.
4. **Do not** "fix" with `any`, `as any`, `as unknown as T`, blanket `!`, or by making more fields optional. If the compiler complains, the call sites or boundary validation are wrong — fix those.

If applying an accepted change reveals it was wrong (test now fails, type error you didn't anticipate), update the decision file: change it from `accept` to `reject` and document what you learned. Do not silently drop it. A type error after removing a fallback is often a signal to harden more call sites, not to revert to soft types.

---

### 2.N.e — Update files-touched

If implementing accepted changes added new files, append them to `.peer-review/files-touched.md` so round N+1 sees the full surface area.

---

## Phase 3 — Final Summary

After round 3 is fully triaged and implemented, write `.peer-review/summary.md`:

```markdown
# Peer review summary

**Spec source**: <path / issue # / "free-form">
**Files created**: <count>
**Files modified**: <count>
**Review model**: 3 sequential rounds × 8 parallel specialists (Correctness, Security, SilentFailure, RecurringPattern, Testing, DeadCode, Duplication, ArchitectureSense-advisory)

## What was built

<2-4 sentences describing the final implementation>

## Review rounds

### Round 1
- Specialists: 8 parallel (7 actionable + architecture advisory)
- Comments raised: <N> (after merge/dedupe; actionable only)
- Accepted: <N> | Rejected: <N> | Deferred: <N>
- Architecture sense-check: fine | clear-better-path | poor-fit
- Notable changes from this round: <bullets>

### Round 2
(same structure)

### Round 3
(same structure)

## Deferred items

<list every deferred comment across all rounds with a one-line note on where it should be tracked>

## Architecture sense-check (user advisory)

<!-- ONLY include this section if the strongest verdict across rounds is NOT fine.
     If all rounds said fine: OMIT this entire section — say nothing about architecture. -->

**Verdict**: clear-better-path | poor-fit

<Synthesize the strongest non-fine note(s) from round-*-architecture-note.md into a short
user-facing paragraph. Do not re-implement. Do not present this as work the agent will do.
Frame as: "For your consideration — the architecture sense-check thought…" >

## Open risks

<anything the reviewers didn't catch but you noticed during the loop, or known limitations>
```

Then output a short message to the user pointing them at `.peer-review/summary.md` and listing the deferred items inline so they don't have to open the file to see what's left.

**Architecture note in the user message:**
- If strongest S6 verdict across all rounds is `fine` → **say nothing** about architecture.
- If `clear-better-path` or `poor-fit` → include a short final paragraph so the user sees what the sense-check thinks. Do not offer to rewrite unless the user asks.

---

## Output Discipline

- Do not stream every specialist comment to the user as it arrives — the files are the record. Give the user a one-line status per phase ("plan + implementation done", "round 1: 8 specialists done, 4 comments — 2 accepted, 1 rejected, 1 deferred", etc.). Do not surface architecture notes mid-loop.
- Do not ask the user for approval between rounds. The loop is autonomous by design.
- If the user interrupts mid-loop, the state in `.peer-review/` is enough to resume — say so.
- If a specialist batch is incomplete, merge what you have and proceed. Never leave the user waiting on a hung reviewer.
- Never rewrite or re-architect the feature because of S6. Architecture sense-check is for the user's judgment at the end only.

---

## Error Recovery

- **Spawn specialists as one foreground parallel batch** so the batch returns together. Do **not** background them and wait for a later notify. Background + “do not poll” is how this loop stalls.
- **One specialist fails** (error, empty output, capacity/timeout, or never returns): retry **that specialty only**, once, immediately. If the retry also fails or does not return a usable review, log `reviewer-failed (<specialty>)` as a `major` comment and **continue the round with whoever finished**.
- **Silent / hung specialist**: treat as a failure. Do not poll. Do not wait. A missing result after the batch (or after the one retry) is enough to mark `reviewer-failed`.
- **All specialists fail**: stop the loop and tell the user; do not invent comments.
- **Accepted change breaks the build**: revert that specific change, flip the decision to `reject` with reasoning `"applying this broke <X>"`, continue.
- **Specialists contradict each other**: both comments appear after merge (or dedupe if identical). Triage on merits independently.
- **Reviewer suggests a contradicting change to one already accepted in a prior round**: allowed and expected — rounds are fresh. Triage on merits; if you reject, note that round M's accepted change was deliberate.

---

## Checklist Before Marking Complete

- [ ] `.peer-review/plan.md` exists (includes consumer map, invariants, authZ, failure modes)
- [ ] `.peer-review/files-touched.md` exists and lists every changed file
- [ ] `.peer-review/round-1-comments.md`, `round-2-comments.md`, `round-3-comments.md` exist
- [ ] Each round spawned **eight parallel specialists** (Correctness, Security, SilentFailure, RecurringPattern, Testing, DeadCode, Duplication, ArchitectureSense) — not one mega-reviewer
- [ ] Each round's merged comments cover silent-failure, recurring patterns, dead-code, and duplication (via S3, S4, S7, S8)
- [ ] S6 notes written to `round-N-architecture-note.md` and **never** triaged as accept/reject/defer
- [ ] Main agent did **not** re-architect or redo work because of S6 during the loop
- [ ] `.peer-review/round-1-decisions.md`, `round-2-decisions.md`, `round-3-decisions.md` exist
- [ ] Every actionable comment (S1–S5, S7–S8) in every round has a corresponding decision
- [ ] All `accept` decisions are reflected in the code
- [ ] `.peer-review/summary.md` exists
- [ ] Architecture section in summary + user message only appears when strongest S6 verdict is not fine
- [ ] Code builds / type-checks
- [ ] User received a short status message with a pointer to the summary

If any item is unchecked, the loop is not done.
````

#### `~/.ai/skills/pr/SKILL.md`

````markdown file=~/.ai/skills/pr/SKILL.md
---
name: pr
description: Commits, pushes the feature branch (never main; never --no-verify), and creates or updates the PR. If the repo pre-push hook fails, fix those errors, commit, and retry the push. Use when user says "/pr", "create pr", "ship it", or "prepare pr".
---

# /pr - Automated PR Workflow

Automates the complete pull request workflow in a single command.

Quality checks (format, lint, typecheck, test, build) run in the repo **pre-push** hook (`.husky/pre-push` — there is no pre-commit hook). Prisma stays in GitHub Actions only. Do **not** run those checks in this skill before push. If the hook fails, fix the reported errors, commit, and push again. Never `--no-verify`.

## Model split (Claude Code)

Steps 1–7 are babysitting. Run them in a **Haiku subagent** (Agent tool, `model: "haiku"`): tell it to follow `~/.ai/skills/pr/SKILL.md`, and pass a 1–3 line summary of what changed and why (you have that context; it doesn't) so the commit and PR text are right. It returns the branch, commit(s), push result, and PR URL.

On a `lint` / `typecheck` / `test` / `build` hook failure the subagent stops and returns the errors. **You** (session model) fix the code, then re-delegate commit + push. Same 3-loop cap.

If you **are** that subagent, skip this section and run the steps directly — do not delegate again.

## CRITICAL SAFETY RULE

**NEVER push directly to main or master. ALWAYS create a feature branch first.**

This is non-negotiable. If on main/master, you MUST create a new branch before proceeding.

**NEVER `git push --no-verify`.** That skips the CI gate.

## Workflow Steps

Execute these steps in order, stopping if any step fails:

### Step 1: Check Current Branch (SAFETY CHECK)

```bash
git branch --show-current
```

**If the current branch is `main` or `master`:**
1. STOP - Do not proceed with push
2. Create a new feature branch based on the changes:
   ```bash
   git checkout -b <branch-name>
   ```
3. Branch naming: Use descriptive names like `fix/openai-api-key-deployment` or `feat/user-authentication`

**Only proceed if on a feature branch (not main/master).**

### Step 2: Check Git Status

```bash
git status
git diff --stat
```

- If working tree is clean and up-to-date with remote, check if PR exists
- If there are changes, proceed to commit
- Do **not** run typecheck, format, lint, test, or build here — pre-push is the gate

### Step 3: Stage and Commit

**Get context for commit message:**
```bash
git diff --staged
git diff
git log --oneline -5
```

**Stage changes:**
```bash
git add -A
```

**Create commit with descriptive message:**

Analyze the changes and create a conventional commit message:
- `feat:` for new features
- `fix:` for bug fixes
- `refactor:` for code refactoring
- `style:` for formatting changes only
- `docs:` for documentation
- `test:` for test changes
- `chore:` for maintenance

If only formatting changes exist, use:
```bash
git commit -m "style: format code"
```

For substantive changes, write a descriptive message explaining what and why.

Do not add any `Co-Authored-By` trailer (Claude, Grok, or otherwise).

### Step 4: Push to Remote (NEVER TO MAIN, NEVER --no-verify)

**First, verify you are NOT on main/master:**
```bash
git branch --show-current
```

If on main or master, STOP and go back to Step 1.

**Push the feature branch:**
```bash
git push -u origin HEAD
```

The **pre-push** hook will run format/sync, lint, typecheck, test, and build. This can take several minutes. Wait for it. Capture the full output.

#### If the hook blocks the push — fix and retry (max 3 loops)

Do **not** `--no-verify`. Do **not** skip to creating the PR.

1. Read the hook banner and the errors above it:
   - `CI job :` — which job failed
   - `Command:` — exact command
   - `Fix    :` — hint
   - The nx / prettier / jest errors above the banner
2. Fix the **root cause**. Job-specific:

   | CI job | Fix |
   |--------|-----|
   | `format-and-sync (yarn install --immutable)` | `yarn install`, commit `yarn.lock` |
   | `format-and-sync (nx sync:check)` | `yarn nx sync`, commit the result |
   | `format-and-sync (format:check)` | `yarn nx format:write`, commit formatted files (`style: format code`) |
   | `lint` | Fix the lint errors; do not disable rules to silence them |
   | `typecheck` | Fix the TypeScript errors; no `any` / `@ts-ignore` to paper over |
   | `test` | Fix implementation or tests so assertions match real behavior |
   | `build` | Fix compile/bundle errors |

3. If Docker is not running and tests need it: tell the user to start Docker, then retry the push. Do not fake a pass.
   **Haiku subagent (see Model split):** do `format-and-sync` fixes yourself. For `lint` / `typecheck` / `test` / `build`, do **not** edit code — stop and return the hook banner + errors verbatim to the main session.
4. If you cannot fix with confidence (ambiguous test, schema conflict, missing product decision): **stop and ask**. Wrong quiet success is worse than a blocked push.
5. Commit the fix (conventional message, no `Co-Authored-By`):
   ```bash
   git add -A
   git commit -m "fix: <what the hook failed on>"
   ```
6. Push again (`git push -u origin HEAD`). Still never `--no-verify`.
7. Repeat from (1) if it fails again. **Maximum 3 fix-push loops.** After 3, stop, report every remaining error, and do not create/update the PR.

Non-hook push failures (non-fast-forward, auth): rebase/merge or report. Do not treat them as hook errors.

### Step 5: Check for Existing PR

```bash
gh pr view --json url,state,body 2>/dev/null
```

- **If no PR exists** → go to Step 6 to create one.
- **If a PR exists and is OPEN** → do NOT just report the URL. The branch now has new work on it, so the description is stale. **Update the PR body** so it reflects the full current state of the branch, using the handoff template in Step 6:
  ```bash
  gh pr edit --body "$(cat <<'EOF'
  ...regenerated handoff body...
  EOF
  )"
  ```
  Fold the still-relevant parts of the existing body into the new one — don't discard context a human wrote. If the existing description is substantial and clearly hand-authored, ask before overwriting; otherwise regenerate and improve it.

### Step 6: Write the PR description (create or update)

The PR description is a **handoff document**, not a changelog. Write it so a reviewer who has never seen this work can read it and immediately know what the PR does, why, what to scrutinize, and how it was checked — enough to jumpstart their review without asking you anything.

**Gather the material.** Don't just diff the code — the intent and the decisions live in the *session*, not the diff:
```bash
git branch --show-current
git log origin/main..HEAD --oneline
git diff origin/main...HEAD --stat
```
Then draw on **this conversation**: the original ask, the decisions you (the AI) made, the alternatives you rejected, anything the user chose or corrected mid-way, and everything you verified. These are the parts a reviewer can't reconstruct from the diff.

**Check for linked GitHub issues:**
- Look at the branch name for issue numbers (e.g., `feat/42-user-dashboard` -> issue #42)
- Check commit messages for issue references
- If found, include `Closes #<number>` in the PR body so the issue auto-closes on merge

**Body template** (omit any section that doesn't apply; keep it tight):
```bash
gh pr create --title "[conventional-commit-style title]" --body "$(cat <<'EOF'
## What & why
[1–3 sentences: what this PR sets out to do and the problem or goal behind it. Lead with intent, not a file list.]

Closes #[issue-number]   <!-- only if an issue is linked -->

## Key decisions & tradeoffs
[The decisions made while building this — whether the AI made them or the user directed them. For each: what was chosen, why, and what was rejected. This is the highest-value section for a reviewer. Call out judgment calls, anything the user explicitly asked for, and anything they changed their mind on.]

## Notes for the reviewer
[Where to focus, the riskiest change, anything non-obvious, follow-ups deliberately left out of scope, and any open questions you want the reviewer to weigh in on.]

## Verification
Pre-push hook (format/sync, lint, typecheck, test, build) passed on push.
[Any extra manual or visual checks. Be explicit about what was NOT verified.]
EOF
)"
```

**What makes a good handoff body:**
- **Intent over inventory.** The diff already lists the changes; the description explains the goal and the reasoning. Don't restate filenames.
- **Surface every real decision** — especially judgment calls and anything the user directed or corrected. That context is exactly what a reviewer needs and can't get from the diff.
- **Be honest about gaps** — unverified paths, known limitations, deferred work. A reviewer who knows the edges reviews faster.
- **Keep it skimmable** — short prose and bullets, no filler.

### Step 7: Report Result

Report:
- Commit hash and message (including any hook-fix commits)
- Whether the push succeeded on the first try or after hook-fix loops (how many)
- If still blocked: the CI job, command, and remaining errors
- PR URL (new or existing), and whether its description was created or updated
- Issue link (if applicable)

## Error Handling

| Error | Action |
|-------|--------|
| On main/master branch | STOP, create feature branch first |
| Pre-push hook fails | Fix the reported job, commit, retry push (max 3). Never `--no-verify`. After 3, STOP and report. |
| Hook failure you cannot fix confidently | STOP and ask. Do not paper over. |
| Push fails (non-fast-forward) | Check if rebase/merge needed, report |
| PR creation fails | Check gh auth, report |

## GitHub PR Comment API Reference

When interacting with PR comments via the GitHub API (`gh api`):

### Get the correct repo name
Repo names are **case-sensitive**. Always resolve dynamically:
```bash
gh repo view --json nameWithOwner -q '.nameWithOwner'
```

### Fetch inline review comments
Use `pulls/{pr}/comments` — NOT `pulls/{pr}/reviews` (reviews endpoint returns the review body which is often empty):
```bash
gh api repos/{owner}/{repo}/pulls/{pr}/comments --jq '.[] | {id, line, body}'
```

### Reply to an inline comment
POST to the comments collection with `in_reply_to`. Do NOT use the `/replies` sub-endpoint (it doesn't exist for PR review comments and returns 404):
```bash
gh api repos/{owner}/{repo}/pulls/{pr}/comments \
  -X POST \
  -f body="Reply text" \
  -F in_reply_to=<parent_comment_id>
```
**Note:** Use `-F` (not `-f`) for `in_reply_to` — it must be sent as an integer, not a string.

### Submit a PR review with inline comments
The `--field 'comments=[...]'` syntax breaks with complex JSON (nested quotes, newlines, code blocks in comment bodies). **Always write the payload to a JSON file and use `--input`:**
```bash
cat > /tmp/pr_review.json << 'ENDJSON'
{
  "commit_id": "<head_sha>",
  "event": "COMMENT",
  "body": "Review summary here.",
  "comments": [
    {
      "path": "app/foo.py",
      "line": 42,
      "body": "Inline comment with `code` and **markdown**."
    }
  ]
}
ENDJSON
gh api repos/{owner}/{repo}/pulls/{pr}/reviews \
  -X POST \
  --input /tmp/pr_review.json
```
**Get the head SHA first:**
```bash
gh api repos/{owner}/{repo}/pulls/{pr} --jq '.head.sha'
```

## Quick Reference

```
/pr
  |-- git branch --show-current (MUST NOT be main/master)
  |-- [if main] git checkout -b <feature-branch>
  |-- git status
  |-- git add -A && git commit (if dirty)
  |-- git push -u origin HEAD (NEVER main, NEVER --no-verify)
  |-- [if pre-push fails] fix → commit → push again (max 3); never skip the hook
  |-- gh pr create (new) || gh pr edit --body (existing) -- write/refresh the handoff description
  |-- Report PR URL
```
````

#### `~/.ai/skills/pr-review/SKILL.md`

````markdown file=~/.ai/skills/pr-review/SKILL.md
---
name: pr-review
description: Deep code review agent that always creates a code-only git worktree first (same as /worktree-quick — fetch + checkout, env copy, yarn install; no DB/ports/seed) then analyzes all diffs in that worktree for performance bottlenecks, security vulnerabilities, code quality issues, "just make it work" silent-failure patterns (swallowed errors, bad fallbacks that should hard-fail — often rooted in soft types; fix by hardening exact types, never with any), incomplete end-to-end wiring (write-only fields, missed dual-path consumers), app-only invariants/races, thin authZ/tenant gates, form hydration wipes, wrong response envelopes, tests that no-op green, dead/unused code and stale leftover comments, and repeated logic that should be shared (3+ real uses). Includes a conservative architecture sense-check that only speaks at the end if the approach is clearly poor or a clearly better path exists in this codebase (silence when fine; never blocks merge). Optionally validates changes against a PRD to ensure implementation correctness and completeness. Spawns one specialist agent per review concern in parallel for speed. After the report, MUST stop with the numbered findings list — do not walk findings one at a time and do not use the Question tool. In later turns, answer questions about findings, or when the user asks to add/post a number list (e.g. 1-3, 5, 19, 24-26) or a single number, submit those as inline GitHub PR review comments. Use when user says "/pr-review", "/pr-review 1234", "/pr-review <pr-url>", "/pr-review <prd-file>", "review my code", "review this branch", "review PR 1234", or "check my changes". Do not require a prior /worktree-quick.
---

# /pr-review - Deep Code Review Agent

Performs a comprehensive, multi-pass review of a PR or branch, always from a code-only worktree (same as `/worktree-quick`). Hunts for performance bottlenecks, security vulnerabilities, race conditions, code quality issues, and "just make it work" patterns — silent fallbacks, swallowed errors, and soft-fail paths that hide real bugs. When a PRD is provided, also validates that the implementation matches the requirements.

**Speed model:** After gathering context, **every review concern runs as its own specialist agent in parallel**. The main agent only gathers context, launches the fan-out, and synthesizes findings. Do not run security → performance → quality as sequential main-agent passes.

**Usage:** `/pr-review [PR number | PR URL | branch] [optional-prd-file-path]`

`/pr-review 1234` is enough — this skill creates the code-only worktree itself. Do **not** require a prior `/worktree-quick`.

After the report, the agent **stops** with the numbered findings list. It does **not** walk findings one at a time and does **not** use the Question tool. Later, the user may ask questions, or ask to **add/post** a number list (e.g. `1-3, 5, 19, 24-26`) or a single number — only then submit those as **inline** GitHub PR review comments.

---

## Core Philosophy

- **Be ruthlessly thorough.** Every diff line is examined. Nothing slips through.
- **Performance is not optional.** O(n²) loops, N+1 queries, missing indexes, unbounded fetches, synchronous blocking — all get flagged.
- **Security is non-negotiable.** Injection vectors, auth bypasses, secret leaks, unsafe deserialization, missing input validation — all get flagged.
- **"Just make it work" is not acceptable.** Silent fallbacks, swallowed errors, and soft-failure paths that hide real bugs must be flagged. Prefer hard failures with clear errors over continuing in a wrong state.
- **Soft types cause soft fails.** Many fallbacks exist only because a value was typed loosely (`T | undefined`, optional fields, `Partial`, untyped JSON, weak inference). Prefer **hard, exact types** that encode invariants so the compiler forces callers to handle reality — **never** "fix" with `any`, `as any`, or other type-erasing shortcuts.
- **End-to-end completeness is required.** A field or feature that saves in the UI but is not read by exporters, imports, dual pipelines, or shared call sites is incomplete — flag write-only and partial migrations.
- **DB and races beat app conventions.** Uniqueness and "one of X" must be enforced where concurrency lives (unique indexes, transactions), not only in happy-path application code.
- **AuthZ is the real gate, not tenant membership alone.** "Row is in my tenant" is not enough when assignment/role gates already exist.
- **PRD compliance is binary.** When a PRD is provided, every requirement either has a matching implementation or it doesn't. No guessing.
- **Actionable feedback only.** Every finding includes the file, line, what's wrong, why it matters, and how to fix it.
- **Recurring PR failure patterns are a required pass.** These are patterns that repeatedly blocked real merges — treat hits as HIGH/CRITICAL when they match production failure modes.
- **Parallel specialists, never sequential mega-passes.** Launch one agent per concern type; synthesize after all return.
- **Architecture sense-check is advisory and silent by default.** It asks whether the approach makes sense in this codebase, but only speaks when there is a clear better path or a clearly poor fit — never as a merge blocker or rewrite demand.

---

## Execution Flow

```
0. Code-only worktree         -> /worktree-quick script + session_move (always; then review)
1. Context Gathering          -> Branch info, base branch, full diff (main agent, in the worktree)
2. Diff Decomposition         -> Split diffs by file, categorize by domain (main agent)
3. PARALLEL SPECIALIST FAN-OUT -> Spawn one agent per concern type AT THE SAME TIME
      ├─ Agent A: Security
      ├─ Agent B: Performance
      ├─ Agent C: Silent Failure / Soft Types
      ├─ Agent D: Recurring PR Patterns (R1–R9)
      ├─ Agent E: Code Quality / Bugs / Races
      ├─ Agent F: Testing Gaps
      ├─ Agent G: PRD Compliance (only if PRD provided)
      ├─ Agent H: Architecture sense-check (advisory; silence when fine)
      ├─ Agent I: Dead code / unused / stale comments
      └─ Agent J: Duplication / extract-to-shared
 4. Synthesis & Report         -> Deduplicate, rank, unified report (main agent)
                                -> Architecture note only if Agent H is not "fine"
                                -> STOP. Numbered list is the end of this turn.
 5. Follow-up (later turns)    -> Answer questions; post inline comments only when
                                 the user asks to add/post numbers (e.g. 1-3, 5, 19)
```

**Critical rule:** In Phase 3, issue **all** specialist agent spawns in a single parallel batch (multiple tool calls together). Do **not** wait for Agent A before spawning Agent B. Only after every specialist has returned, run Phase 4 synthesis.

**Stop-after-report rule:** After the report, **stop**. Do **not** call the Question tool. Do **not** walk findings one at a time. Do **not** post to GitHub in the report turn. In later turns, answer questions about findings, or when the user asks to add/post a number list or a single finding, post **only** those as **inline** review comments (file + line). Never a top-level PR issue comment in place of an inline comment.

**Architecture sense-check rule:** Agent H is advisory only. Its output never becomes CRITICAL/HIGH merge blockers and never asks anyone to re-architect. If the verdict is `fine`, omit architecture entirely from the final report.

---

## Phase 0: Code-only worktree (always, before any review)

Review **never** runs in the primary checkout. Isolate first with the same script as `/worktree-quick`, then review inside that worktree. **Do not** wait for the user to run `/worktree-quick`. **Do not** use `/monorepo-worktree` (no DB, ports, seed, or serve). **Do not** stop after create — continue immediately into Phase 1 in this same session.

User arguments: `$ARGUMENTS`

### Parse target

Split `$ARGUMENTS` into **TARGET** + optional **PRD path**:

| Token | Meaning |
|-------|---------|
| `1234` / `#1234` / `pr 1234` / GitHub `.../pull/1234` | PR |
| `feature/foo` / `origin/foo` / other git ref | Branch |
| Path ending in `.md` or an existing file | PRD (not a worktree target) |
| Empty | `gh pr view --json number -q .number`. If that fails and cwd is already a `*-quick-*` worktree, TARGET = current worktree (skip create). Else ask for a PR number — do not invent a task worktree. |

Resolve a relative PRD path to an **absolute** path against the **pre-move** cwd before leaving the primary checkout.

Remember `PR_NUMBER` when TARGET is a PR. Later `gh pr view` / review POSTs must use `gh pr view ${PR_NUMBER}` — the local branch will be `quick/pr-N`, which GitHub does not treat as the PR head.

### Skip create only when already isolated

Skip create if cwd is already a `*-quick-*` worktree (basename `*-quick-*` or gitdir marker `worktree-quick`) **and** it matches TARGET (same PR number / same slug). Still fetch+reset (below) so the review is current.

### Create or reuse

Script: `~/.ai/oc_skills/worktree-quick/scripts/quick-worktree.sh`

Must run from the git repo under review (or set `REPO_ROOT`). Do **not** hand-roll `git worktree add`.

```bash
~/.ai/oc_skills/worktree-quick/scripts/quick-worktree.sh 1234
~/.ai/oc_skills/worktree-quick/scripts/quick-worktree.sh pr 1234
~/.ai/oc_skills/worktree-quick/scripts/quick-worktree.sh https://github.com/org/repo/pull/1234
~/.ai/oc_skills/worktree-quick/scripts/quick-worktree.sh feature/foo
```

Parse `path:` from the success banner.

If the script fails with `worktree path already exists: <path>`: **reuse `<path>`**. Do not destroy. Fetch the PR/branch and `git -C <path> reset --hard` to that SHA so the review is current:

```bash
# PR
git fetch origin pull/${PR_NUMBER}/head
git -C "<path>" reset --hard FETCH_HEAD

# Branch
git fetch origin <branch>
git -C "<path>" reset --hard origin/<branch>
```

### Yarn (mandatory, every worktree)

After the path is known — **fresh create, reuse, or already-isolated** — run and wait for exit 0:

```bash
(cd "<path>" && yarn install)
```

Timeout 10 minutes. Never skip because `node_modules` exists. Never skip on reuse. Never skip because the task "doesn't need node_modules". If the create script already ran yarn in this turn and you **watched it exit 0**, that create counts; reuse / already-isolated **must still yarn**.

### Move the session, then review

1. OpenCode: `tools.opencode.session_move` with `directory` = the absolute worktree path. Continue **this** session. Do not spawn a subagent to perform the review.
2. If session_move is unavailable: `cd` / set `working_directory` on every later command to that path.
3. Every later git / Read / Grep / specialist must run in that worktree, not the primary checkout.
4. One-line note: path, `quick/…` branch, PR URL, destroy command (`~/.ai/oc_skills/worktree-quick/scripts/quick-worktree.sh destroy <slug> --yes`). Then **immediately** start Phase 1.

Do **not** destroy the worktree after the report (follow-up posting still needs the checkout).

---

## Phase 1: Context Gathering

Run all of these in parallel to gather the full picture:

### 1.1 Branch & Diff Info

```bash
# Current branch name
git branch --show-current

# Base branch (detect main or master)
git remote show origin | grep 'HEAD branch' | awk '{print $NF}'

# Full diff against base
git diff $(git merge-base HEAD origin/main)..HEAD

# Stat summary
git diff --stat $(git merge-base HEAD origin/main)..HEAD

# All commits on this branch
git log --oneline $(git merge-base HEAD origin/main)..HEAD
```

### 1.2 Changed Files List

```bash
git diff --name-only $(git merge-base HEAD origin/main)..HEAD
```

### 1.3 Project Context

- Read CLAUDE.md, README.md, or package.json to understand the tech stack
- Identify: language, framework, test framework, linting/formatting tools
- Note any existing security or performance tooling (ESLint security plugins, etc.)

### 1.4 PRD Loading (if provided)

If a PRD file path was given as an argument:
1. Read the PRD file
2. Extract all requirements, acceptance criteria, user stories, API contracts, and task checklists
3. Build a requirements checklist to verify against in the PRD specialist

If no PRD is provided, do **not** spawn the PRD Compliance agent.

---

## Phase 2: Diff Decomposition

Split the full diff into logical review units (for prioritization notes in agent prompts):

### 2.1 Categorize Each Changed File

| Category | File Patterns | Review Focus |
|----------|--------------|--------------|
| **API / Routes** | `**/api/**`, `**/routes/**`, `**/handlers/**`, `**/controllers/**` | Auth, input validation, error responses, rate limiting |
| **Database / Models** | `**/models/**`, `**/schema/**`, `**/migrations/**`, `**/prisma/**`, `**/drizzle/**` | SQL injection, missing indexes, data integrity, migrations |
| **Auth / Security** | `**/auth/**`, `**/middleware/**`, `**/guard/**`, `**/policy/**` | Auth bypass, session handling, token validation, RBAC |
| **Frontend Components** | `**/*.tsx`, `**/*.jsx`, `**/*.vue`, `**/*.svelte` | XSS, state leaks, excessive re-renders, accessibility |
| **Business Logic** | `**/services/**`, `**/lib/**`, `**/utils/**`, `**/helpers/**` | Logic errors, edge cases, error handling, complexity |
| **Configuration** | `*.config.*`, `.env*`, `**/config/**`, `docker*` | Secret exposure, insecure defaults, missing validation |
| **Tests** | `**/test/**`, `**/tests/**`, `**/*.test.*`, `**/*.spec.*` | Coverage gaps, brittle assertions, missing edge cases |
| **Infrastructure** | `**/ci/**`, `**/.github/**`, `**/terraform/**`, `**/k8s/**` | Insecure pipelines, missing checks, exposed secrets |

### 2.2 Priority Order (for agent context, not sequential review)

Highest risk first when agents must chunk large diffs:
1. Auth / Security files
2. API / Routes
3. Database / Models
4. Configuration
5. Business Logic
6. Frontend Components
7. Infrastructure
8. Tests

---

## Phase 3: Parallel Specialist Fan-Out

Spawn **one dedicated agent per concern** below. Use the platform's multi-agent tool (`Task` / `spawn_subagent` / equivalent). **Launch every agent in the same turn** so they run concurrently.

### Shared payload for every agent

Every specialist prompt MUST include:

```
## Branch
[branch-name] vs [base-branch]

## Tech Stack
[detected stack]

## Changed Files
[file list from Phase 1.2]

## Full Diff
[full diff from Phase 1.1]

## File Categories (optional hint)
[Phase 2 categorization summary]
```

If the diff is extremely large (>5000 lines), chunk the diff and note which chunk this agent owns — or spawn **multiple agents of the same specialty** per chunk (e.g. Security-chunk-1, Security-chunk-2). Prefer parallel chunking over sequential reading by the main agent.

### Shared output format (every specialist except Agent H)

```
For each finding, report:
| Field | Value |
|-------|-------|
| Severity | CRITICAL / HIGH / MEDIUM / LOW |
| Category | [agent-specific category tag] |
| File | exact file path |
| Line(s) | line number(s) in the diff / file |
| Issue | short title |
| Description | what's wrong and why it matters |
| Fix | specific code change to remediate |

If NO issues are found for your specialty, explicitly state "No <specialty> issues found" —
do NOT invent issues that don't exist.
Do not review concerns outside your specialty (other specialists own those).
Do not modify any code. Review only.
```

Agent H uses its own verdict format (see Agent H section) — not Severity findings.
Agents I (`DeadCode`) and J (`Duplication`) use the shared Severity findings format above.

---

### Agent A — Security

- **subagent_type**: `backend-architect` (or `general-purpose` if unavailable)
- **description**: `PR review: security`
- **Category tag**: `Security`

```
You are performing a SECURITY-FOCUSED code review ONLY. Ignore performance, style, and tests
except where they create security risk.

[Shared payload]

## Security Checklist - Check EVERY item against the diffs:

### Injection Attacks
- [ ] SQL injection (raw queries, string concatenation in queries)
- [ ] NoSQL injection (unsanitized MongoDB queries)
- [ ] Command injection (exec, spawn with user input)
- [ ] LDAP injection
- [ ] XSS (innerHTML, dangerouslySetInnerHTML, unescaped template output)
- [ ] Template injection (server-side template engines)

### Authentication & Authorization
- [ ] Missing auth checks on new endpoints
- [ ] Broken access control (user A accessing user B's data)
- [ ] JWT issues (missing expiry, weak secret, algorithm confusion)
- [ ] Session fixation or insecure session handling
- [ ] Missing RBAC/permission checks
- [ ] Privilege escalation paths
- [ ] **Thin tenant checks only** — "row exists in caller's tenant" without assignment/role gates used elsewhere for the same resource
- [ ] **Over-broad procedures** — PENDING/onboarding/unprivileged roles can perform privileged side effects
- [ ] **Identity vs capability conflation** — gating "who is this person?" lookups with "can they take a lead / pull credit?" filters (or the reverse)
- [ ] Auth/permission checks that **fail open** (`catch { return true }`)

### Data Exposure
- [ ] Secrets in code (API keys, passwords, tokens)
- [ ] Sensitive data in logs (passwords, tokens, PII)
- [ ] Overly permissive CORS
- [ ] Missing data sanitization in API responses (exposing internal fields)
- [ ] Directory traversal in file operations
- [ ] **Env-var names / internal config in user-facing errors**
- [ ] Cross-tenant leakage via missing tenant filters on global vendor lookups

### Input Validation
- [ ] Missing input validation on API endpoints
- [ ] Missing type checking/schema validation
- [ ] Unbounded input sizes (DoS via large payloads)
- [ ] Missing rate limiting on sensitive endpoints

### Cryptography
- [ ] Weak hashing (MD5, SHA1 for passwords)
- [ ] Missing encryption for sensitive data at rest
- [ ] Hardcoded cryptographic keys
- [ ] Insecure random number generation for security contexts

### Dependencies
- [ ] Known vulnerable dependencies being added
- [ ] Pinned versions vs. floating versions

For each finding also include: Exploit Scenario (how an attacker could exploit this).
```

---

### Agent B — Performance

- **subagent_type**: `backend-architect` (or `general-purpose` if unavailable)
- **description**: `PR review: performance`
- **Category tag**: `Performance`

```
You are performing a PERFORMANCE-FOCUSED code review ONLY. Ignore security vulns and style
except where they create perf risk.

[Shared payload]

## Performance Checklist - Check EVERY item against the diffs:

### Database & Queries
- [ ] N+1 query patterns (queries inside loops)
- [ ] Missing database indexes for new query patterns
- [ ] Unbounded SELECT queries (missing LIMIT/pagination)
- [ ] Missing WHERE clauses (full table scans)
- [ ] Redundant queries (same data fetched multiple times)
- [ ] Missing eager loading / over-fetching relations
- [ ] Large transactions holding locks too long
- [ ] Missing connection pooling

### Algorithmic Complexity
- [ ] O(n²) or worse loops (nested iterations over large datasets)
- [ ] Unnecessary array copies or object spreads in loops
- [ ] Missing early returns / short circuits
- [ ] Sorting where not needed
- [ ] Repeated expensive computations (missing memoization)

### Memory & Resources
- [ ] Memory leaks (event listeners not cleaned up, intervals not cleared)
- [ ] Unbounded caches or collections that grow forever
- [ ] Large objects held in closure scope unnecessarily
- [ ] Missing stream processing for large data
- [ ] File handles or connections not closed

### Network & I/O
- [ ] Sequential API calls that could be parallelized (Promise.all)
- [ ] Missing request timeouts
- [ ] Missing retry logic with backoff
- [ ] Large payloads without compression
- [ ] Missing pagination on list endpoints
- [ ] Synchronous file operations blocking the event loop

### Frontend Performance
- [ ] Unnecessary re-renders (missing useMemo, useCallback, React.memo)
- [ ] Large bundle imports (importing entire libraries for one function)
- [ ] Missing code splitting / lazy loading
- [ ] Layout thrashing (reading/writing DOM in loops)
- [ ] Unoptimized images or assets
- [ ] Missing virtualization for long lists
- [ ] Expensive computations on the main thread

### Caching
- [ ] Missing caching for expensive operations
- [ ] Cache invalidation issues
- [ ] Missing HTTP cache headers

For each finding also include: Impact (latency, memory, CPU estimate).
```

---

### Agent C — Silent Failure / Soft Types

- **subagent_type**: `general-purpose`
- **description**: `PR review: silent failures`
- **Category tag**: `SilentFailure` (and `SoftType` when type-rooted)

```
You are performing a "JUST MAKE IT WORK" / SILENT-FAILURE / SOFT-TYPES code review ONLY.
Prefer hard failures with clear errors over continuing in a wrong state — unless the fallback
is intentional, documented, user-visible graceful degradation.

[Shared payload]

## Checklist

### Silent / swallowed failures
- Empty `catch` blocks, or catch that only logs and continues as if success
- `.catch(() => undefined)`, `.catch(() => null)`, `.catch(() => [])`, `.catch(() => {})`
- `try/catch` that returns a default success value on failure
- Promise rejection handlers that discard the error without rethrowing/surfacing
- Fire-and-forget async (`void fn()`, unawaited promises) where failure should affect the caller

### Fallbacks that should hard-fail instead
- Defaulting critical config/env (`process.env.X || 'localhost'`, fake API keys, wrong URLs)
- Returning empty arrays/objects/`null` when required dependency (DB row, API, auth) is missing
- `|| []`, `?? []`, `?? {}`, `?? ''` papering over unexpected null/undefined
- Long optional chaining (`a?.b?.c?.d`) on a required path
- Fallback to mock, cached-stale, or placeholder data in production without product requirement
- Retry loops that "succeed" with partial/empty data instead of failing after exhaustion
- Parsing wrapped so invalid input becomes a silent default

### Soft types that force soft fails (root-cause pass)

For every soft-fail/fallback finding:
1. Trace the type of the value being defaulted / optional-chained / cast.
2. Determine the exact expected type from domain/API/schema/callers.
3. Prefer hardening the type so the fallback becomes unnecessary.
4. Never suggest `any`, `as any`, un-narrowed `unknown`, or type-erasing shortcuts.

Flag:
| Soft type smell | What to do instead |
|-----------------|--------------------|
| `T \| undefined` / `T \| null` always present after success | Success type is `T`; nullability only on lookup; narrow once then throw/404 |
| Optional fields required by product/API | Required field or draft vs loaded types |
| `Partial<T>` for fully-loaded entities | Separate CreateInput/Patch from full entity |
| Unvalidated JSON / `Record<string, unknown>` deep in domain | Parse at boundary into exact type |
| Over-wide unions (`string` for closed set) | Literal unions or enums |
| Empty success when absence is error | Return `T` + throw, or Result union |
| Optional params only to make call sites compile | Fix call sites |
| Prisma selects omit fields then code defaults them | Select required fields; type result correctly |

### Type / assertion papering
- `as any`, `as unknown as T`, non-null `!` to silence type errors
- Type guards that always return true; bare `@ts-ignore` / `@ts-expect-error`
- Soft API/config types compensated with runtime fallbacks instead of post-validation hard types

### Behavioral soft-fail smells
- Feature flags that disable broken behavior with no error/metric
- Partial success returned as full success (2 of 5 writes fail, API 200)
- Validation that logs a warning and continues
- Auth/permission fail-open (`catch { return true }`)
- "Best effort" comments that excuse missing correctness without explicit design

## Severity guidance
| Pattern | Typical severity |
|---------|------------------|
| Auth fails open; financial/data-loss soft-fails | CRITICAL / HIGH |
| Required data → empty default; config fallback hides misconfig | HIGH |
| Soft type forces cascade of `??` / `||` / `?.` | HIGH (root-cause the type) |
| Suggested/existing fix using `any` / type-erasure | HIGH |
| Swallowed errors on non-critical path | MEDIUM |
| Defensive `??` on truly optional documented fields | Not a finding |

For each finding state:
1. What the code does on failure today
2. What should happen instead (throw / 4xx/5xx / fail the job)
3. Whether the root cause is a soft type — if yes, the exact hard type and validation boundary
4. A concrete fix that hardens types and removes the fallback — not more defaults, not `any`
```

---

### Agent D — Recurring PR Patterns (R1–R9)

- **subagent_type**: `general-purpose`
- **description**: `PR review: recurring patterns`
- **Category tag**: `RecurringPattern` (plus R# in Issue title)

```
You are performing the RECURRING PR FAILURE PATTERNS review ONLY (R1–R9).
These patterns repeatedly blocked real merges. When a hit can cause data loss, wrong
credit/AUS/messaging behavior, cross-tenant routing, or "looks healthy while broken,"
severity is CRITICAL or HIGH.

[Shared payload]

Walk EVERY checklist item. For R2/R6, **read consumers outside the diff** (transformers,
importers, twin pipelines, sibling procedures) when the change introduces fields or dual-path logic.

### R1 — Soft failure that looks like success
- Catch/log-and-continue while status still claims ACTIVE / ready / success
- Empty-string/object fallbacks on **required** export/vendor payloads instead of preflight throw
- Setup/side-effect failures swallowed so operators treat feature as live
- Tests skip/pass when fixtures/reference inputs absent
- Polling-only UIs with no recovery if webhooks never land

### R2 — Incomplete end-to-end wiring (write-only features)
For every new/changed field or source-of-truth move, trace:
UI → API/schema → DB → read/list → export transformers (all engines) → import/mappers → jobs → shared call sites
- Shared component only partially adopted
- Clear/reset persists null but live side effects never update
- Refactor deletes old write path without re-homing data

### R3 — App-only invariants and races
- "One of X" uniqueness only in app code — no DB unique/partial unique/FK
- Check-then-act without atomicity or unique-violation handling
- Position/counter `last + 1` without unique + retry
- Tenant-scoped unique on a **globally** unique shared-vendor resource
- Multi-step writes missing transaction when partial success corrupts state

### R4 — Thin authZ / tenant / secret boundaries
- Weaker gates than sibling resources
- Over-broad caller sets for privileged side effects
- Identity lookup mixed with capability filters
- User-facing errors leak env-var names
- PII/secrets in logs; dual-pipeline credential redaction gaps

### R5 — Form hydration / mount effects wipe real data
- useEffect writes form state on mount without hydration sentinel
- Auto-flip / clear-stale that nulls persisted enums/booleans on first paint
- Partial updates that null omitted fields

### R6 — Dual-path / dual-surface inconsistency
- Parallel transformers use different predicates for the same domain concept
- CRM vs funnel (or admin vs LO) encode different rules
- Two canonical schemas/enums disagree
- Sticky DB columns fight live derivation
- Actor identity differs across steps without explicit product rule

### R7 — Response envelopes, partial updates, type lies
- Casts to guessed shapes when real response is an envelope
- Partial update sets omitted fields to null instead of skipping
- Schema/migration drift; mocks missing new columns
- `as any` / double casts / envelope lies

### R8 — UX recovery and edge states
- Async flows missing loading / error / cancel / retry / stale-expired handling
- Broken image/URL with no fallback; double-submit not blocked
- List/create can 500 with no error state
- Eager per-row work without unmount cleanup / virtualization

### R9 — Consistency / scope
- Reinvents existing gate/helper/component nearby
- Unrelated scope creep
- Arbitrary design tokens / z-index when project defines a scale
- Tab-like UI with incomplete a11y

For each finding:
1. Which R# pattern
2. What fails in production (concrete)
3. Concrete fix — prefer DB constraints, existing auth helpers, hard preflight throws, full consumer wiring, envelope-typed clients, tests that fail if the bug returns — not more `??` defaults
```

---

### Agent E — Code Quality / Bugs / Races

- **subagent_type**: `general-purpose`
- **description**: `PR review: code quality`
- **Category tag**: `Quality`

```
You are performing a CODE QUALITY / BUG / RACE-CONDITION review ONLY.
Do not deep-dive security vulns, N+1 perf, silent-failure catalogs, or R1–R9 (other agents own those)
unless the bug is pure correctness unrelated to those catalogs.

[Shared payload]

### Bug Detection
- Race conditions (shared mutable state, async ordering issues)
- Off-by-one errors
- Null/undefined dereferences without guards
- Unhandled promise rejections / missing try-catch
- Type coercion bugs (== vs ===, implicit conversions)
- Copy-paste errors that introduce subtle behavioral bugs (Agent I/J own pure dead code and pure extract-to-shared)

### Error Handling (correctness, not soft-fail catalog)
- Missing error handling on async operations
- Generic error messages that leak internal details
- Missing cleanup in error paths (finally blocks)
- Error responses missing proper HTTP status codes

### Code Patterns
- Inconsistent patterns compared to the rest of the codebase
- Magic numbers or strings without constants
- Missing TypeScript types; `any` / un-narrowed `unknown` / overuse of `Partial` / unnecessary optionals
- Overly complex functions (high cyclomatic complexity)
- Missing comments on non-obvious complex logic (Agent I owns stale/useless leftover comments)

Do NOT deep-dive unused imports, dead symbols, commented-out blocks, or "extract because N copies" — Agents I and J own those.

Read surrounding context, not just the diff hunk.
```

---

### Agent F — Testing Gaps

- **subagent_type**: `test-writer-fixer` (or `general-purpose` if unavailable)
- **description**: `PR review: testing gaps`
- **Category tag**: `Testing`

```
You are performing a TESTING GAPS review ONLY. Identify missing/weak tests; do not rewrite
the product code. Do not invent security/perf findings.

[Shared payload]

### Testing Gaps Checklist
- New code paths without corresponding tests
- Modified behavior without updated tests
- Edge cases not covered
- Missing tests that assert **failure** paths (bad input / missing data errors out rather than soft-succeeding)
- Tests that **no-op green** when fixtures/reference files are missing (hardcoded absolute paths, optional reads, early `return` without assert)
- Fixtures that hardcode the happy path so the assertion cannot fail
- Behavior/UI contract changes without updating e2e/integration assumptions
- Prefer noting at least one test that would **fail** if a silent-success or write-only bug returned

For each finding: what test is missing, where it should live, and what assertion would catch the bug.
```

---

### Agent G — PRD Compliance (only if PRD provided)

- **subagent_type**: `general-purpose`
- **description**: `PR review: PRD compliance`
- **Category tag**: `PRD`
- **Skip entirely** when no PRD path was given.

```
You are validating that code changes correctly implement a PRD. Compliance only —
do not re-do security/performance/quality scans.

## PRD Content
[full PRD text]

## All Diffs on the Branch
[full diff]

## Changed Files
[file list]

Go through EVERY requirement and classify:

| Status | Meaning |
|--------|---------|
| IMPLEMENTED | Fully satisfies |
| PARTIALLY IMPLEMENTED | Some aspects done |
| NOT IMPLEMENTED | No matching code |
| DEVIATED | Differs from PRD |
| NOT APPLICABLE | e.g. deployment-only |

Check: API contracts, data model, frontend components, business logic, acceptance criteria
(Given/When/Then), and task checklist items.

### Output Format

## PRD Compliance Report

### Summary
- Total Requirements: [N]
- Implemented / Partially / Not Implemented / Deviated: counts

### Detailed Findings
#### [Requirement]
- **Status**: ...
- **Evidence**: File:line or "No matching code found"
- **Gap** (if any): ...
- **Severity of Gap**: BLOCKING / SHOULD_FIX / NICE_TO_HAVE

### Deviations from PRD
### Missing Implementations (priority-ordered)
```

---

### Agent H — Architecture sense-check (advisory only)

- **subagent_type**: `general-purpose` (or `plan` if available)
- **description**: `PR review: arch sense`
- **Category tag**: `ArchitectureSense` (advisory — not a merge-blocking category)
- **Always spawn** (unlike Agent G).

```
You are performing an ARCHITECTURE SENSE-CHECK only. Advisory. Conservative.

Your job is to answer one question:

> "Does the way this is implemented actually make sense as it is now?"

[Shared payload]

Also read surrounding codebase context (similar features, existing helpers, layering conventions)
— not just the diff hunks.

Ask: given this codebase and the problem being solved, is the architecture a reasonable fit?
Could a competent engineer reading this in six months understand why it was built this way?

### Stance — default to "fine"

- You are **not** quick to demand a re-architecture. Most working designs that fit local patterns are fine.
- Only speak up when there is a **very clear** more proper way that fits this codebase better for the
  grand change, OR when the current approach is **clearly poor** (wrong layer, fights existing
  abstractions, invents a parallel system for something already solved, will force painful follow-ups).
- Style preferences, micro-optimizations, naming bikesheds, and "I would have done it slightly
  differently" are NOT findings.
- Preferable-but-not-clearly-better alternatives are NOT findings. Silence is correct when the design
  is acceptable.

### What you may conclude

| Verdict | When | What you write |
|---------|------|----------------|
| **fine** | Design is reasonable for this codebase | Exactly: `Verdict: fine` — no other text |
| **clear-better-path** | A clearly better architecture exists that fits the grand change and surrounding code | Short note (see format) |
| **poor-fit** | Current approach is a poor fit | Short note (see format) |

### Critical constraints

- Do **not** invent Severity / CRITICAL / HIGH findings for the main findings tables.
- Do **not** demand a rewrite or re-architecture as a merge blocker.
- Do **not** re-do security, performance, silent-failure, R1–R9, quality, testing, dead-code, duplication, or PRD reviews.
- Keep notes short. If fine, one line only.

### Output format — not Severity findings

# Architecture sense-check

## Verdict
fine | clear-better-path | poor-fit

## Note
(Omit this section entirely when Verdict is fine.)
When not fine: 2–6 sentences covering:
- What was built and why it appears shaped this way
- Why that shape is a poor fit OR why a better path is clearly preferable in this codebase
- The alternative that makes more sense (concrete modules/layers/patterns, not vague advice)
- Frame as advice for the reader — not instructions to rewrite before merge
```

---

### Agent I — Dead code / unused / stale comments

- **subagent_type**: `general-purpose`
- **description**: `PR review: dead code`
- **Category tag**: `DeadCode`

```
You are performing a DEAD CODE / UNUSED / STALE COMMENT review ONLY.
Your job is to remove noise left by refactors — unused symbols and comments that explain
what used to be there rather than what the code does now.

[Shared payload]

Also grep/read surrounding files to confirm something is truly unused (not just unused inside
the diff hunk). Prefer proof of zero references over vibes.

## Checklist

### Unused imports & symbols introduced or left by this change
- Unused imports (named, default, type-only, side-effect imports that are no longer needed)
- Unused locals, params, private helpers, types, interfaces, enums, constants
- Exports added in this PR with no in-repo consumers (or consumers only in deleted code)
- Re-exports / barrel entries that nothing imports
- Feature flags, config keys, or env reads that are never read after the change
- Dead branches / unreachable code after condition changes
- Variables assigned and never read; catch bindings unused without reason

### Stale / useless comments (delete, do not "improve")
- Comments that narrate removed behavior: "used to…", "previously…", "was…", "no longer…",
  "removed X", "old path", "legacy before refactor"
- Block comments that are just deleted code in prose, or large commented-out code blocks
- JSDoc/TSDoc on deleted params/fields, or docs that contradict the current signature
- TODOs/FIXMEs that are already done (or refer to code that no longer exists)
- Section banners / leftover separators for code that was deleted
- "Explain what the next line does" noise on obvious code — only flag when added/left by this PR
  and adds no non-obvious intent; do not bikeshed every pre-existing comment outside the change

### What NOT to flag
- Imports/symbols that are used (including type positions, decorators, DI, framework reflection)
- Public API surface that is part of a published package / intentional external contract
- Comments that explain non-obvious WHY, invariants, security, or protocol constraints
- Temporarily commented code that the PR clearly marks as WIP with an active tracking TODO + issue
- Test fixtures that look "unused" but are required by runners/frameworks

## Severity guidance
| Pattern | Typical severity |
|---------|------------------|
| Unused import / trivial dead local left by refactor | LOW |
| Dead private helper / unreachable branch in changed files | MEDIUM |
| Large commented-out blocks or stale "used to" comments that mislead | MEDIUM |
| Exported/public-looking dead API that confuses callers | MEDIUM / HIGH |
| Misleading comment that contradicts current security/auth behavior | HIGH |

For each finding:
1. Proof it is unused or stale (e.g. "grep for X across repo: 0 refs outside definition")
2. Exact delete/edit (usually delete the import/symbol/comment — not a rewrite)
3. Do not suggest broad cleanups outside the PR's blast radius unless the dead code was introduced here
```

---

### Agent J — Duplication / extract-to-shared

- **subagent_type**: `general-purpose`
- **description**: `PR review: duplication`
- **Category tag**: `Duplication`

```
You are performing a DUPLICATION / EXTRACT-TO-SHARED review ONLY.
Flag repeated logic that should become a shared helper — not every similar-looking line.

[Shared payload]

Read beyond the diff: search the repo for copies of the same logic (same predicates, same
transform sequences, same UI blocks, same validation, same mapping tables).

## When to flag (ALL must hold)

1. **Count ≥ 3** real occurrences of the same logic (in the PR and/or existing codebase after
   this change lands). Two copies is usually not enough unless the PR is clearly about to add more.
2. **Would realistically be used more** — another call site is likely soon (same domain concept,
   sibling features, list+detail+export, CRM+funnel, multiple transformers, repeated form fields).
3. **Stable enough to name** — not a one-off coincidence of similar shape with different invariants.
4. **Extraction improves clarity** — a named helper would reduce drift risk, not hide important differences.

If copies deliberately differ on domain rules, do NOT force a shared abstraction — note the risk
of false unification instead only if the PR already pretends they are the same.

## Scope of the shared home (required on every finding)

Choose scope from **where the copies live and how many consumers exist**, not from taste:

| Occurrences / fan-out | Proposed scope |
|-----------------------|----------------|
| 3+ in one file only | Private helper in that file |
| 3+ across one feature folder / module | Module-level `utils` / `helpers` beside the feature |
| 3+ across packages in one app (e.g. web-crm only) | App-level shared module already used for similar things |
| 3+ across apps or backend+frontend domain rules | Existing monorepo `libs/` package (or the package that already owns this domain) |
| Matches an **existing** helper almost exactly | Reuse/extend that helper — do not invent a parallel one |

Always name:
- Exact occurrence count and file:line list (or representative list if many)
- Proposed symbol name and file path for the shared home
- What varies per call site (parameters) vs what stays identical
- Whether an existing helper already covers this (prefer extend over new)

## What NOT to flag
- Two similar blocks with no likely third consumer
- Framework boilerplate that must stay local (trivial one-liners, obvious map/filter)
- Copy-paste that is test data/fixtures where duplication is intentional
- "Duplication" that would require a premature god-helper with many flags/options
- Style-only similarity (same control-flow shape, different business meaning)
- Huge cross-cutting refactors unrelated to this PR's risk — keep proposals proportional

## Severity guidance
| Pattern | Typical severity |
|---------|------------------|
| 3 local copies, easy file-private helper | LOW / MEDIUM |
| 3+ copies already drifting (subtle bug differences) | HIGH |
| 3+ copies across dual paths (CRM/funnel, twin transformers) with same domain rule | HIGH |
| Should reuse existing shared helper but reinvented | MEDIUM / HIGH |
| Speculative extract with only 2 weak lookalikes | Not a finding |

For each finding include: count, locations, proposed scope + path, and a concrete signature —
not "consider DRY".
```

---

### Fan-out rules

1. **One tool-call batch** — spawn Agents A–F, H, I, J always, and G if PRD, together; do not serialize.
2. **capability_mode**: prefer `read-only` when available so specialists cannot edit code.
3. **Do not** have the main agent re-run the same checklists after specialists return — only synthesize.
4. If a specialist agent fails or returns empty without the required "No X issues found" line (or for Agent H, without a Verdict), re-spawn **that specialty only** once. Do not re-run the whole fan-out. If Agent H fails twice, treat as `Verdict: fine` and continue.
5. Specialists must stay in their lane. Overlap is OK; synthesis deduplicates.
6. **Agent H is never merge-blocking.** Do not promote architecture notes into Critical/High findings tables.

---

## Phase 4: Synthesis & Final Report

After **all** specialists complete, the main agent compiles a unified report.

### 4.1 Collect & Deduplicate

- Merge findings from Agents A–F, I, J (and G if present). **Exclude Agent H** from the findings tables.
- If two specialists flag the same line, merge into one finding with combined Category tags (e.g. `Security + SilentFailure`).
- Prefer the more specific Fix; keep the higher Severity.
- Hold Agent H's verdict aside for the optional architecture section only.

### 4.2 Severity Ranking

| Severity | Action Required | Examples |
|----------|----------------|----------|
| **CRITICAL** | Must fix before merge | SQL injection, auth bypass, data loss, secret exposure, auth fails-open, cross-tenant routing, soft-success on money/credit/AUS/messaging setup |
| **HIGH** | Should fix before merge | N+1 on hot paths, check-then-act races, write-only fields, silent `?? ''` on required vendor payloads, thin tenant-only authZ, form mount wiping data, dual-path divergence, envelope casts, no-op-green tests |
| **MEDIUM** | Fix soon, doesn't block merge | Missing memoization, suboptimal patterns, incomplete validation, swallowed non-critical errors, incomplete UX recovery, dead helpers, stale misleading comments, 3+ copy extract candidates |
| **LOW** | Nice to have | Minor style issues, slightly better naming, small optimizations, pure a11y polish, unused imports |

### 4.3 Final Report Template

```markdown
## Code Review Report

**Branch**: [branch-name]
**Base**: [base-branch]
**Files Changed**: [N]
**Commits**: [N]
**Review Date**: [date]
**Specialists**: Security, Performance, SilentFailure, RecurringPattern, Quality, Testing, DeadCode, Duplication, ArchitectureSense-advisory[, PRD]

---

### Verdict: [BLOCK / APPROVE WITH FIXES / APPROVE]

[1-2 sentence summary of overall code quality. Do not let Agent H change the merge verdict.]

---

### Critical & High Findings (Must Fix)

| # | Severity | Category | File | Line(s) | Issue | Fix |
|---|----------|----------|------|---------|-------|-----|
| 1 | CRITICAL | Security | auth.ts | 45 | SQL injection via unsanitized input | Use parameterized query |
| 2 | HIGH | Performance | users.ts | 88-95 | N+1 query in loop | Batch query with IN clause |

### Medium & Low Findings (Recommendations)

| # | Severity | Category | File | Line(s) | Issue | Fix |
|---|----------|----------|------|---------|-------|-----|
| 3 | MEDIUM | Quality | utils.ts | 30 | Missing error handling on API call | Add try-catch with retry |
| 4 | LOW | Quality | types.ts | 12 | Using `any` type | Define proper interface |

### PRD Compliance (if applicable)

| Requirement | Status | Notes |
|-------------|--------|-------|
| ... | ... | ... |

**PRD Coverage**: [X]% of requirements implemented

### Summary Statistics

| Category | Critical | High | Medium | Low |
|----------|----------|------|--------|-----|
| Security | | | | |
| Performance | | | | |
| Code Quality | | | | |
| Silent Failure | | | | |
| Recurring Pattern (R1–R9) | | | | |
| Testing | | | | |
| Dead Code | | | | |
| Duplication | | | | |
| **Total** | | | | |

### Recurring-pattern coverage

| Pattern | Status |
|---------|--------|
| R1 Soft success | clean / N findings |
| R2 Write-only / E2E wiring | clean / N findings |
| R3 Invariants & races | clean / N findings |
| R4 AuthZ / tenant / secrets | clean / N findings |
| R5 Form hydration wipes | clean / N findings |
| R6 Dual-path inconsistency | clean / N findings |
| R7 Envelopes / partial updates | clean / N findings |
| R8 UX recovery | clean / N findings |
| R9 Consistency / scope | clean / N findings |

### Specialist status

| Specialist | Status | Findings |
|------------|--------|----------|
| Security | complete / failed-retry | N |
| Performance | ... | N |
| Silent Failure | ... | N |
| Recurring Patterns | ... | N |
| Code Quality | ... | N |
| Testing | ... | N |
| Dead Code | ... | N |
| Duplication | ... | N |
| Architecture sense-check | complete / failed→fine | fine / clear-better-path / poor-fit |
| PRD | complete / skipped | N |

### Architecture sense-check (user advisory)

<!-- ONLY include this section when Agent H verdict is clear-better-path or poor-fit.
     If Verdict is fine: OMIT this entire section — say nothing about architecture. -->

**Verdict**: clear-better-path | poor-fit

[2–6 sentence note from Agent H, lightly edited for clarity. Frame as "For your consideration"
— not a merge blocker, not work the review agent will perform. Do not invent a rewrite plan.]

### Next Steps
1. Ask about any finding, or reply with numbers to post as inline GitHub comments (e.g. `add 1-3, 5, 19` or `add 7`)
2. Fix all CRITICAL findings before merge
3. Address HIGH findings — these will cause problems in production
4. Consider MEDIUM findings for code quality
5. [If PRD provided] Implement missing requirements: [list]
6. [Only if architecture section present] Architecture note is optional judgment for you — not a required rewrite
```

**User-facing rule for architecture:** After the report, if Agent H said `fine`, do not mention architecture at all. If not fine, the architecture section in the report is enough — do not push a re-architecture unless the user asks.

**After the report, stop.** Do not call the Question tool. Do not walk findings. Do not post to GitHub in this turn. Phase 5 runs only on later user messages.

---

## Phase 5: Follow-up chat — discuss or post selected findings

The report **is** the end of the review turn. After printing it, **stop**. Do **not** call the Question tool. Do **not** walk findings one at a time. Do **not** post to GitHub until a later user message asks you to add/post findings.

Keep the numbered findings in conversation context. The user will chat from there.

### 5.1 Report-turn stop (required)

In the same turn as the report:

- Print the numbered findings tables (and the rest of the report template).
- In Next Steps, tell the user they can ask questions or reply with numbers to post (e.g. `add 1-3, 5, 19` or `add 7`).
- **Stop.** No Question tool. No GitHub. No "Add / Don't add" prompts.

**Zero findings:** Skip Phase 5 entirely.

**Not selectable:** Agent H architecture notes. They stay in the report only.

### 5.2 Later turns — questions vs post

On later messages:

| User intent | What to do |
|-------------|------------|
| Questions / debate about a finding (or several) | Answer. Do **not** post. |
| Explicit add/post of a number list or a single number | Parse the selection (5.3) and post those as **inline** comments (5.4–5.7). |
| `add all` / `post all` | Post every numbered finding. |
| Unclear (chat that is not a post request) | Answer; do **not** post. |

**Do not invent a default selection.** Never auto-post. Never use the Question tool for this flow.

### 5.3 Parse the selection

Trigger words: `add`, `post`, `comment`, `inline` — plus a number list, a single number, or `all`. Parentheses are optional.

A message that is **only** a number list (or a single number) is also a post request.

Examples that **must** post:

- `add 1-3, 5, 19, 24-26`
- `add 7`
- `7`
- `post 1, 4, 9`
- `1-3, 5, 19, 24-26`
- `(1-3, 5, 19, 24-26)`
- `add all`

Parse rules:

1. Strip wrapping `()` / `[]`.
2. Split on commas and whitespace.
3. A token `N-M` is the inclusive range N through M.
4. A token `N` is finding N.
5. `all` = every numbered finding in the report.
6. Deduplicate; ignore numbers that are not in the report (tell the user which were invalid).
7. If they also paste custom comment text for a specific `#`, use that text as that finding's `body`; otherwise use the finding's Issue + Fix.

If the parsed set is empty after validation, stop — no GitHub.

They may post more than once in later turns (e.g. `add 1-3` then later `add 5`). Do not re-post findings already posted in this conversation unless they ask to post again.

### 5.4 Resolve the PR

Only after a later turn requests posting with at least one valid finding number:

```bash
# Prefer the PR number from Phase 0 — local branch is quick/pr-N, not the GitHub head ref
gh pr view ${PR_NUMBER} --json number,url,title,headRefOid,headRefName
gh repo view --json nameWithOwner -q '.nameWithOwner'
```

Split `nameWithOwner` into `OWNER` / `REPO`. Set `NO_COLOR=1` on `gh api` calls.

- If no PR exists for this branch, **stop** and tell the user. Do not create a PR. Do not post issue comments.
- Confirm `headRefOid` is the commit comments will attach to.

### 5.5 Resolve an inline anchor per selected finding

Every posted comment **must** be inline: `path` + `line` on the PR head (`side: RIGHT` for added/changed lines).

For each selected finding:

1. `path` = repo-relative file from the finding (never absolute).
2. `line` = the finding's line in the **new** file. If the report has a range (`88-95`), use `start_line: 88` and `line: 95`.
3. Confirm that line appears in the PR diff (RIGHT side). Use the local diff or:

```bash
NO_COLOR=1 gh api repos/{OWNER}/{REPO}/pulls/{pr}/files --paginate
```

4. If the exact line is not in the diff, snap to the **nearest changed line in the same file** that is in the hunk. Say so in the comment (`Anchored to line N — nearest changed line.`).
5. If the file is not in the PR diff, **do not** post that finding as a top-level comment. Skip it and tell the user it could not be inlined.
6. Deleted-only lines: `side: LEFT` and the old-file line. Prefer RIGHT whenever the line still exists in the new file.

### 5.6 Submit one review containing every selected inline comment

Write the payload to a JSON file and `POST` it with `--input`. Do **not** use `--field 'comments=[...]'` (breaks on markdown/newlines). Do **not** post one review per finding. Do **not** use `gh pr comment` (that is a non-inline issue comment).

```bash
# commit_id MUST be the PR head SHA from 5.4
cat > /tmp/pr_review.json << 'ENDJSON'
{
  "commit_id": "<headRefOid>",
  "event": "COMMENT",
  "body": "Posted N selected finding(s) from /pr-review as inline comments.",
  "comments": [
    {
      "path": "src/auth.ts",
      "line": 45,
      "side": "RIGHT",
      "body": "**[CRITICAL] Security:** SQL injection via unsanitized input\n\n<input validation missing on query string.>\n\n**Fix:** Use a parameterized query."
    },
    {
      "path": "src/users.ts",
      "start_line": 88,
      "line": 95,
      "side": "RIGHT",
      "body": "**[HIGH] Performance:** N+1 query in loop\n\n...\n\n**Fix:** Batch with `IN`."
    }
  ]
}
ENDJSON

NO_COLOR=1 gh api repos/{OWNER}/{REPO}/pulls/{pr}/reviews \
  -X POST \
  --input /tmp/pr_review.json
```

Each comment `body` format:

```markdown
**[SEVERITY] Category:** Issue title

<1–4 sentence description of what's wrong and why it matters>

**Fix:** <concrete remediation>
```

`event` is always `COMMENT` (do not `REQUEST_CHANGES` / `APPROVE` unless the user explicitly asks).

GitHub review comment cap is 100 inline comments per review. If more than 100 are selected, split across multiple review POSTs (same `event` / `commit_id`).

### 5.7 Report what was posted

After a successful POST, tell the user:

- PR URL
- How many inline comments were posted
- Finding numbers that were posted
- Finding numbers skipped (and why — not in diff, no PR, etc.)

Do not re-print the full review report.

---

## Error Handling

| Error | Action |
|-------|--------|
| No changes on branch (clean diff) | Stop, inform user there's nothing to review |
| Worktree script fails (not already-exists) | Stop; show full output; do **not** review the primary checkout |
| Worktree path already exists | Reuse that path; fetch+reset to latest PR/branch SHA |
| session_move unavailable | `cd` / `working_directory` on every command to the worktree path |
| Cannot detect base branch | Ask user which branch to diff against |
| PRD file not found | Warn user and continue without Agent G |
| Diff is extremely large (>5000 lines) | Chunk and spawn multiple agents **per specialty** in parallel |
| One specialist fails | Re-spawn that specialty once; continue with others |
| Agent returns no findings | Accept it — don't fabricate issues. Report "clean" for that specialty |
| Agent H returns fine | Omit architecture from the report entirely — silence is correct |
| Agent H fails twice | Treat as fine; do not invent architecture concerns |
| No PR for current branch | On a post request, stop; do not create a PR; do not post issue comments |
| User only asks questions | Answer; do not post |
| Number list / add / post in a later turn | Parse and post those findings only |
| Invalid finding numbers | Skip them; tell the user which were invalid |
| Finding file/line not in PR diff | Snap to nearest changed line in that file; if file absent from diff, skip (never fall back to a top-level comment) |
| Review POST 422 (invalid line/commit) | Fix `commit_id` / line / side and retry that review once; if it still fails, skip those comments and report why |
| More than 100 selected findings | Split into multiple review POSTs |

---

## Important Rules

1. **Never fabricate findings.** If the code is clean, say it's clean. False positives destroy trust.
2. **Read the actual code, not just the diff** — specialists must use Read/Grep on surrounding context. For R2/R6, read consumers outside the diff. Architecture sense-check must read surrounding patterns too.
3. **Severity matters.** CRITICAL means genuinely dangerous, not "could be slightly better."
4. **Be specific.** "This might be slow" is useless. Name file, line, impact, and fix. For recurring patterns, name the R# and production failure mode.
5. **Provide fixes, not just complaints.** Every finding must include a concrete remediation. (Architecture notes are advice, not findings tables.)
6. **PRD review is additive.** It never replaces security/performance/quality specialists.
7. **Respect the developer's time.** Prioritize findings so they know what to fix first.
8. **Hard-fail over soft-fail by default.** Flag silent fallbacks, swallowed errors, and defaults that hide misconfiguration.
9. **Hard types over soft types and fallbacks.** Prescribe the exact expected type and validation boundary — never `any`.
10. **Always run the Recurring Patterns specialist.** Even on "small" PRs. Report the coverage table even when clean.
11. **Prefer existing project gates and DB constraints** over new ad-hoc checks and `??` defaults.
12. **Parallel is mandatory.** Do not collapse specialists into one sequential mega-reviewer. Speed and focus come from one concern per agent.
13. **Architecture sense-check defaults to silence.** Only surface when verdict is `clear-better-path` or `poor-fit`. Never treat it as a merge blocker. Never demand a rewrite mid-review or in Next Steps. If fine, omit architecture entirely.
14. **Stop after the report.** Do not walk findings. Do not use the Question tool. Post inline comments only in a later turn when the user asks to add/post a number list or a single finding. Never auto-post. Never post unselected findings.
15. **GitHub comments are inline only.** Each selected finding is a review comment on `path` + `line`. Never use `gh pr comment` or the issue-comments API as a substitute. Skip anything that cannot be inlined.
16. **Always isolate in a code-only worktree first** (Phase 0 / `/worktree-quick` script). Never review the primary checkout. Never use `/monorepo-worktree`. Never skip yarn install on a fresh create. Never destroy the worktree after the report.

User arguments: $ARGUMENTS
````

#### `~/.ai/skills/pr-review-light/SKILL.md`

````markdown file=~/.ai/skills/pr-review-light/SKILL.md
---
name: pr-review-light
description: Fast single-agent code review that always creates a code-only git worktree first (same as /worktree-quick — fetch + checkout, env copy, yarn install; no DB/ports/seed) then reviews the PR/branch in that worktree. Same concerns as /pr-review (security, performance, silent failures/soft types, R1–R9 recurring patterns, quality, testing, dead code, duplication, optional PRD) but does NOT spawn subagents — the main agent reviews the diff in one pass. After the report, MUST stop with the numbered findings list — do not walk findings one at a time and do not use the Question tool. In later turns, answer questions about findings, or when the user asks to add/post a number list (e.g. 1-3, 5, 19, 24-26) or a single number, submit those as inline GitHub PR review comments. Use when the user runs /pr-review-light, /pr-review-light 1234, /pr-review-light <pr-url>, /pr-review-light <prd-file>, "light pr review", "quick pr review", "fast pr review", or wants pr-review without subagents. Do not require a prior /worktree-quick.
---

# /pr-review-light — Fast single-agent PR review

Same review as `/pr-review`, **without subagents**. You (the main agent) gather the diff, review it in one pass, and report. After the report, **stop**. Later, answer questions or post inline GitHub comments when the user asks to add/post finding numbers.

**Usage:** `/pr-review-light [PR number | PR URL | branch] [optional-prd-file-path]`

`/pr-review-light 1234` is enough — this skill creates the code-only worktree itself. Do **not** require a prior `/worktree-quick`.

## Hard rules

1. **NEVER spawn subagents** (`Task`, `spawn_subagent`, specialist agents, fan-out). No exceptions — not for "large diffs", not for "parallel specialists". Speed comes from one pass.
2. **NEVER fabricate findings.** Clean code → say it's clean.
3. **Stop after the report.** Do not walk findings. Do not use the Question tool. Never auto-post. Post only in a later turn when the user asks to add/post a number list or a single finding.
4. **GitHub comments are inline only** (`path` + `line`). Never `gh pr comment` / issue comments as a substitute.
5. Prescribe **hard types + hard fails**, never `any` / `?? ''` papering.
6. **Always isolate in a code-only worktree first** (Phase 0 / `/worktree-quick` script). Never review the primary checkout. Never require a prior `/worktree-quick`.

## Speed model

```
0. Code-only worktree         -> /worktree-quick script + session_move (always; then review)
1. Context (parallel git)     -> branch, base, diff, stat, log, file list (in the worktree)
2. One-pass review            -> YOU read the diff; Grep/Read only to confirm a suspected issue
3. Report                     -> unified tables (no specialist-status theater)
4. STOP after report          -> numbered list is the end of this turn
5. Follow-up (later turns)    -> same as /pr-review Phase 5 (questions, or add/post numbers)
```

- Do **not** pre-build file-category tables, specialist payloads, or "No X issues found" per concern.
- Do **not** read the whole surrounding codebase "to be thorough". Open extra files only when the diff suggests a real issue (authz sibling, consumer of a new field, unique index, etc.).
- Prefer **high-signal** findings. Skip style nits, naming bikesheds, "could useMemo", and obvious-comment noise.
- If the diff is huge, review it in chunks **yourself** (highest-risk files first: auth, API, DB, config). Still no subagents.

---

## Phase 0: Code-only worktree (always, before any review)

Review **never** runs in the primary checkout. Isolate first with the same script as `/worktree-quick`, then review inside that worktree. **Do not** wait for the user to run `/worktree-quick`. **Do not** use `/monorepo-worktree` (no DB, ports, seed, or serve). **Do not** stop after create — continue immediately into Phase 1 in this same session. session_move is **not** a subagent.

User arguments: `$ARGUMENTS`

### Parse target

Split `$ARGUMENTS` into **TARGET** + optional **PRD path**:

| Token | Meaning |
|-------|---------|
| `1234` / `#1234` / `pr 1234` / GitHub `.../pull/1234` | PR |
| `feature/foo` / `origin/foo` / other git ref | Branch |
| Path ending in `.md` or an existing file | PRD (not a worktree target) |
| Empty | `gh pr view --json number -q .number`. If that fails and cwd is already a `*-quick-*` worktree, TARGET = current worktree (skip create). Else ask for a PR number — do not invent a task worktree. |

Resolve a relative PRD path to an **absolute** path against the **pre-move** cwd before leaving the primary checkout.

Remember `PR_NUMBER` when TARGET is a PR. Later `gh pr view` / review POSTs must use `gh pr view ${PR_NUMBER}` — the local branch will be `quick/pr-N`, which GitHub does not treat as the PR head.

### Skip create only when already isolated

Skip create if cwd is already a `*-quick-*` worktree (basename `*-quick-*` or gitdir marker `worktree-quick`) **and** it matches TARGET (same PR number / same slug). Still fetch+reset (below) so the review is current.

### Create or reuse

Script: `~/.ai/oc_skills/worktree-quick/scripts/quick-worktree.sh`

Must run from the git repo under review (or set `REPO_ROOT`). Do **not** hand-roll `git worktree add`.

```bash
~/.ai/oc_skills/worktree-quick/scripts/quick-worktree.sh 1234
~/.ai/oc_skills/worktree-quick/scripts/quick-worktree.sh pr 1234
~/.ai/oc_skills/worktree-quick/scripts/quick-worktree.sh https://github.com/org/repo/pull/1234
~/.ai/oc_skills/worktree-quick/scripts/quick-worktree.sh feature/foo
```

Parse `path:` from the success banner.

If the script fails with `worktree path already exists: <path>`: **reuse `<path>`**. Do not destroy. Fetch the PR/branch and `git -C <path> reset --hard` to that SHA so the review is current:

```bash
# PR
git fetch origin pull/${PR_NUMBER}/head
git -C "<path>" reset --hard FETCH_HEAD

# Branch
git fetch origin <branch>
git -C "<path>" reset --hard origin/<branch>
```

### Yarn (mandatory, every worktree)

After the path is known — **fresh create, reuse, or already-isolated** — run and wait for exit 0:

```bash
(cd "<path>" && yarn install)
```

Timeout 10 minutes. Never skip because `node_modules` exists. Never skip on reuse. Never skip because the task "doesn't need node_modules". If the create script already ran yarn in this turn and you **watched it exit 0**, that create counts; reuse / already-isolated **must still yarn**.

### Move the session, then review

1. OpenCode: `tools.opencode.session_move` with `directory` = the absolute worktree path. Continue **this** session. Do not spawn a subagent to perform the review.
2. If session_move is unavailable: `cd` / set `working_directory` on every later command to that path.
3. Every later git / Read / Grep must run in that worktree, not the primary checkout.
4. One-line note: path, `quick/…` branch, PR URL, destroy command (`~/.ai/oc_skills/worktree-quick/scripts/quick-worktree.sh destroy <slug> --yes`). Then **immediately** start Phase 1.

Do **not** destroy the worktree after the report (follow-up posting still needs the checkout).

---

## Phase 1: Context (run in parallel)

```bash
git branch --show-current
git remote show origin | grep 'HEAD branch' | awk '{print $NF}'
git diff $(git merge-base HEAD origin/main)..HEAD
git diff --stat $(git merge-base HEAD origin/main)..HEAD
git log --oneline $(git merge-base HEAD origin/main)..HEAD
git diff --name-only $(git merge-base HEAD origin/main)..HEAD
```

If HEAD branch is not `main`, swap `origin/main` for the detected base. Clean diff → stop. Cannot detect base → ask. If a PRD path was given, read it; if missing, warn and continue without PRD.

---

## Phase 2: One-pass review

Walk the **full diff** once. Flag only real issues. Every finding needs: Severity, Category, File, Line(s), Issue, Description, Fix.

### Severity

| Severity | When |
|----------|------|
| **CRITICAL** | Must fix before merge: injection, auth bypass, data loss, secret leak, fail-open auth, cross-tenant, soft-success on money/credit/AUS/messaging setup |
| **HIGH** | Should fix: N+1 hot path, check-then-act races, write-only fields, `?? ''` on required vendor payloads, thin tenant-only authZ, form mount wipes, dual-path divergence, envelope casts, no-op-green tests |
| **MEDIUM** | Fix soon: incomplete validation, swallowed non-critical errors, incomplete UX recovery, dead helpers, 3+ copy extract |
| **LOW** | Only if introduced by this PR and cheap: unused imports, tiny dead locals. Skip pure style. |

### Checklists (scan, don't write a report per box)

**Security** — injection (SQL/command/XSS/`dangerouslySetInnerHTML`); missing/thin authZ (tenant membership ≠ authorization; fail-open `catch { return true }`); secrets/PII in code or logs; env names in user errors; missing validation on new endpoints.

**Performance** — N+1 / queries in loops; missing indexes; unbounded lists; O(n²); sequential awaits that should be `Promise.all`; sync blocking I/O.

**Silent failure / soft types** — empty/log-only catch; `.catch(() => null\|[]\|{})`; required data defaulted with `??` / `||` / `?.`; `as any` / `as unknown as T` / `@ts-ignore`; fire-and-forget where the caller must know. Root-cause the **type** (exact Prisma/Zod/DTO), never suggest `any`.

**R1–R9 (always run, even on small PRs)**

| # | Pattern | Look for |
|---|---------|----------|
| R1 | Soft success | catch/log while status still ACTIVE/ready; tests skip-green when fixtures missing |
| R2 | Write-only / E2E | new field saved but not read by list/detail, export, import, job, twin pipeline — **grep consumers** |
| R3 | App-only races | uniqueness only in app code; check-then-act; `last+1` without unique+retry |
| R4 | Thin authZ | weaker gate than siblings; identity mixed with capability; over-broad roles |
| R5 | Form hydration wipe | mount `useEffect` writes form; partial PATCH maps omitted keys → null |
| R6 | Dual-path drift | CRM vs funnel / twin transformers disagree — **read the other path** |
| R7 | Envelope / type lies | guessed response shape; schema drift; double casts |
| R8 | UX stuck | async with no timeout/error/cancel; double-submit |
| R9 | Scope | reinvented nearby helper; arbitrary z-index/tokens |

Hits that look healthy while broken, lose data, or mis-route tenants/credit/messaging → CRITICAL/HIGH.

**Quality** — races, off-by-one, copy-paste bugs, missing await, magic strings that should be consts. Read hunk context, not only the `+` lines.

**Testing** — new paths with no test; no failure-path assert; tests that stay green if fixtures are absent. Name the test file and the assertion that would catch the bug.

**Dead code** — unused imports/symbols **this PR introduced**. Grep to confirm 0 refs. Stale "used to / previously" comments. Don't bikeshed old comments outside the change.

**Duplication** — flag only if **≥ 3** real copies and a named helper would reduce drift. Two copies is not a finding. Point at path + signature.

**PRD** (only if provided) — each requirement: IMPLEMENTED / PARTIAL / NOT IMPLEMENTED / DEVIATED. Evidence = file:line.

**Architecture** — gut check only. Default `fine` and **omit from the report**. Speak only for a clearly better existing-codebase path or a clearly poor fit. Never a merge blocker. Never a finding row.

---

## Phase 3: Report

```markdown
## Code Review Report

**Branch**: …
**Base**: …
**Files Changed**: N
**Commits**: N
**Review Date**: …
**Mode**: pr-review-light (single agent, no subagents)

### Verdict: BLOCK / APPROVE WITH FIXES / APPROVE

[1–2 sentences. Architecture does not change the verdict.]

### Critical & High Findings (Must Fix)

| # | Severity | Category | File | Line(s) | Issue | Fix |
|---|----------|----------|------|---------|-------|-----|

### Medium & Low Findings (Recommendations)

| # | Severity | Category | File | Line(s) | Issue | Fix |
|---|----------|----------|------|---------|-------|-----|

### PRD Compliance (if applicable)

| Requirement | Status | Notes |
|-------------|--------|-------|

### Recurring-pattern coverage

| Pattern | Status |
|---------|--------|
| R1 Soft success | clean / N findings |
| R2 Write-only / E2E wiring | clean / N findings |
| R3 Invariants & races | clean / N findings |
| R4 AuthZ / tenant / secrets | clean / N findings |
| R5 Form hydration wipes | clean / N findings |
| R6 Dual-path inconsistency | clean / N findings |
| R7 Envelopes / partial updates | clean / N findings |
| R8 UX recovery | clean / N findings |
| R9 Consistency / scope | clean / N findings |

### Architecture sense-check (user advisory)

<!-- ONLY if not fine. If fine: OMIT this section entirely. -->

### Next Steps
Ask about any finding, or reply with numbers to post as inline GitHub comments (e.g. `add 1-3, 5, 19` or `add 7`).
```

Number findings CRITICAL → LOW across both tables (continuous `#`). Merge duplicates (same line → one row, higher severity).

**Zero findings:** verdict APPROVE, skip Phase 4.

**After the report, stop.** Do not call the Question tool. Do not walk findings. Do not post to GitHub in this turn. Phase 4 runs only on later user messages.

---

## Phase 4: Follow-up chat — discuss or post selected findings

Same UX as `/pr-review` Phase 5. The report **is** the end of the review turn. Do **not** post in the same turn as the report. Do **not** use the Question tool.

### 4.1 Report-turn stop (required)

Print the numbered findings tables, tell the user they can ask questions or reply with numbers to post (e.g. `add 1-3, 5, 19` or `add 7`), then **stop**.

Architecture notes are **not** selectable.

### 4.2 Later turns — questions vs post

| User intent | What to do |
|-------------|------------|
| Questions / debate about a finding (or several) | Answer. Do **not** post. |
| Explicit add/post of a number list or a single number | Parse (4.3) and post those as **inline** comments (4.4–4.7). |
| `add all` / `post all` | Post every numbered finding. |
| Unclear (chat that is not a post request) | Answer; do **not** post. |

**Do not invent a default selection.** Never auto-post.

### 4.3 Parse the selection

Trigger words: `add`, `post`, `comment`, `inline` — plus a number list, a single number, or `all`. Parentheses are optional. A message that is **only** a number list (or a single number) is also a post request.

Examples that **must** post: `add 1-3, 5, 19, 24-26` · `add 7` · `7` · `post 1, 4, 9` · `1-3, 5, 19, 24-26` · `(1-3, 5, 19, 24-26)` · `add all`.

Parse rules: strip wrapping `()` / `[]`; split on commas/whitespace; `N-M` is inclusive range; `N` is finding N; `all` = every numbered finding; deduplicate; skip invalid numbers (tell the user). Custom comment text for a specific `#` becomes that finding's `body`; otherwise use Issue + Fix.

Empty set after validation → no GitHub. Later turns may post more numbers; do not re-post findings already posted in this conversation unless asked.

### 4.4 Resolve the PR (only after a later turn requests posting with ≥1 valid finding)

```bash
# Prefer the PR number from Phase 0 — local branch is quick/pr-N, not the GitHub head ref
gh pr view ${PR_NUMBER} --json number,url,title,headRefOid,headRefName
gh repo view --json nameWithOwner -q '.nameWithOwner'
```

No PR → stop; do not create one; do not post issue comments. `commit_id` = `headRefOid`.

### 4.5 Inline anchor

For each selected finding: repo-relative `path`; `line` = new-file line (`start_line` + `line` if a range); `side: RIGHT` for added/changed lines.

If the exact line is not in the PR diff, snap to the **nearest changed line in that file** and say so in the comment. If the file is not in the diff, **skip** (never fall back to a top-level comment). Deleted-only: `side: LEFT`. Prefer RIGHT if the line still exists.

### 4.6 One review POST (not one per finding)

Write JSON to a file; `POST` with `--input`. Do **not** `--field 'comments=[...]'`. Do **not** `gh pr comment`.

```bash
cat > /tmp/pr_review_light.json << 'ENDJSON'
{
  "commit_id": "<headRefOid>",
  "event": "COMMENT",
  "body": "Posted N selected finding(s) from /pr-review-light as inline comments.",
  "comments": [
    {
      "path": "src/auth.ts",
      "line": 45,
      "side": "RIGHT",
      "body": "**[CRITICAL] Security:** SQL injection via unsanitized input\n\n…\n\n**Fix:** Use a parameterized query."
    }
  ]
}
ENDJSON

NO_COLOR=1 gh api repos/{OWNER}/{REPO}/pulls/{pr}/reviews \
  -X POST \
  --input /tmp/pr_review_light.json
```

Comment body:

```markdown
**[SEVERITY] Category:** Issue title

<1–4 sentence description>

**Fix:** <concrete remediation>
```

`event` is always `COMMENT`. Cap 100 comments per review; split POSTs if needed.

### 4.7 After POST

Tell the user: PR URL, how many inline comments, which finding #s posted, which skipped and why. Do not re-print the full report.

---

## Errors

| Error | Action |
|-------|--------|
| Clean diff | Stop |
| Worktree script fails (not already-exists) | Stop; show full output; do **not** review the primary checkout |
| Worktree path already exists | Reuse that path; fetch+reset to latest PR/branch SHA |
| session_move unavailable | `cd` / `working_directory` on every command to the worktree path |
| No base branch | Ask |
| PRD missing | Warn; continue without PRD |
| Huge diff | Chunk **yourself**; still no subagents |
| No PR | On a post request, stop; don't create a PR |
| User only asks questions | Answer; do not post |
| Number list / add / post in a later turn | Parse and post those findings only |
| Invalid finding numbers | Skip them; tell the user which were invalid |
| Line not in diff | Snap to nearest changed line in file; else skip |
| POST 422 | Fix commit/line/side; retry once; then skip and report |

---

## Do not

- Spawn subagents, even if `/pr-review` would have. (`session_move` is not a subagent.)
- Collapse this skill into a sequential "run 10 specialist personas as extra turns" — that is the slow path. One pass.
- Demand a rewrite from architecture.
- Walk findings one at a time or use the Question tool after the report.
- Post unselected findings.
- Use `any` as a recommended fix.
- Review in the primary checkout, skip Phase 0, or require a prior `/worktree-quick`.
- Use `/monorepo-worktree` (no DB/ports/seed/serve).
- Skip yarn install on a fresh worktree create.
- Destroy the worktree after the report.

User arguments: $ARGUMENTS
````

#### `~/.ai/skills/project-board/RULES.md`

````markdown file=~/.ai/skills/project-board/RULES.md
# Project management rules — Future Mortgage CRM board

**This file is Martin's.** Edit it freely. `/project-board` reads it on every run, and these rules win over anything in `SKILL.md`.
When Martin says "from now on…" about issues, tickets, or the board, the rule goes **here** (not in memory or CLAUDE.md).

Seeded 2026-10-14 from how the board is actually used (Blake's issues #2382, #2387, #2391, #2392; epics #1100, #1112, #1125). Change anything that's wrong.

---

## Board

- **Future Mortgage CRM**: https://github.com/orgs/Future-Mortgage/projects/1
- Default repo `Future-Mortgage/monorepo`. Use `Verification-Service`, `shipyard`, or `fannie-mae-du` only when the code lives there.

## Every new issue gets these fields

| Field | Rule |
|-------|------|
| Status | `Todo`. Use `In Progress` only if work already started. |
| Priority | Required. Use the rubric below. |
| Area | Required. Pick one option. |
| Category | Required. `Bug` / `Feature` / `Tech Debt` / `Spike` / `Process`. |
| Owner | Set it when someone owns the work, and also assign their GitHub login (see People). Leave both empty if nobody owns it yet. |
| Sprint, Start/End Date | Leave empty unless Martin asks. Sprint has had no active iteration since Sprint 11 (Jul 2026). |

### Priority rubric

- **P0 - Critical**: prod down, data loss or corruption, security hole, or a blocked launch. Ping someone after posting.
- **P1 - High**: user-facing breakage or wrong data, or a committed feature for this cycle.
- **P2 - Medium**: real need, not urgent. This is the default when unsure.
- **P3 - Low**: nice to have, polish, or someday.

## People

| Owner option | GitHub login | Notes |
|--------------|--------------|-------|
| Martin | `mrodhansen` | |
| Marcus | `mdhenke` | |
| Ben | `801C07` | |
| Brandon | — | Not an org member. Set Owner only. |
| Mira | — | Not an org member. Set Owner only. |
| (Blake) | `FutureMortgage` | PM. Not an Owner option. Files most product issues. |

## Titles

- Plain English. Name the problem or the outcome, not the fix: "Funnel loan officer contact card shows placeholder phone (000) 000-0000".
- Optionally lead with the product surface when it helps scanning: "Income Calculator: wage earner income logic".
- Keep it under about 90 characters.
- Don't use conventional-commit prefixes (`bug(web-crm):`, `feat:`). Those belong on PRs.
- Epics: `Epic: <name>`.

## Body template (default)

```markdown
**Role:** <who hits this: Loan Officer / Borrower / Processor / Underwriter / Admin>

**Problem:** <what's wrong or missing today. Be concrete and give a real example when you have one. Number the items if there are several.>

**Success looks like:** <one sentence on the outcome, from the user's point of view>

**Acceptance criteria:**
- [ ] <observable and testable>
- [ ] <...>
```

Optional sections after the acceptance criteria, only when they add something:

- `## Technical notes`: root cause, files, related PRs/issues, migration or authZ concerns. Use this for engineering-filed issues.
- `## Out of scope`
- `## Source`: a link to the PRD, gist, Slack thread, or doc it came from.

Decision or question issues (e.g. #2375) can use `## Context` / `## Today` / `## Open question` instead, and should say what closes the issue ("If not, close this issue.").

## Writing

- Write Role, Problem, Success, and acceptance criteria so Blake or a loan officer can read them. Put jargon in Technical notes.
- Acceptance criteria are checks a tester can actually perform. Avoid "works correctly" and "is improved".
- **No borrower PII**: no names, SSNs, DOBs, account numbers, or real addresses. Staff names and business phones are fine.
- No secrets or credentials.

## Scope and structure

- Bundle related fixes on one screen or flow into one issue, as Blake does (#2382, #2391).
- Split into an **epic plus sub-issues** when the parts have different owners or ship separately. Label the epic `epic`, title it `Epic: …`, and link each child with `--parent`. The board auto-adds sub-issues, but still set their fields.
- **Search for duplicates first.** If one exists, comment on it or update it instead of filing a new issue.

## Labels

Labels are optional. Board fields are the source of truth for type, priority, and area.

- `epic` on epics.
- `prd-needed` or `design-needed` when work is blocked on scope or Figma.
- `integration` for third-party or vendor work.
- `launch-checklist` only for launch-tracking items.
- Never create a new label without asking.

## Posting

- "Draft …" means show the draft and stop.
- "Post / file / create / add to the board" means post, then reply with the link.
- When filing several issues at once, show the list of titles and fields first, then post them all after one OK.
````

#### `~/.ai/skills/project-board/SKILL.md`

````markdown file=~/.ai/skills/project-board/SKILL.md
---
name: project-board
description: Post and triage GitHub issues on the Future Mortgage CRM project board (github.com/orgs/Future-Mortgage/projects/1). Drafts the issue in the team format, checks for duplicates, creates it, adds it to the board, and sets Status / Priority / Area / Category / Owner and the parent epic. Follows Martin's project-management rules in RULES.md, which is also where new PM rules get saved. Use when the user runs /project-board, or says "post an issue", "file a ticket", "add this to the board", "create an issue for X", "make an epic with sub-issues", "set priority/owner on #1234", "add a PM rule", or asks how issues should be written for the board.
---

# /project-board — issues on the Future Mortgage CRM board

Board: https://github.com/orgs/Future-Mortgage/projects/1 (org project #1, "Future Mortgage CRM").

| File | Purpose |
|------|---------|
| `~/.ai/skills/project-board/RULES.md` | **Martin's PM rules.** Read it on every run. Its rules win over this file. |
| `~/.ai/skills/project-board/scripts/board.py` | Creates the issue, adds it to the board, sets fields, links the parent. Validates everything before writing. |

## Workflow

1. **Read `RULES.md`** in full, every run. Don't work from memory of it.
2. **Gather the facts** from the conversation, code, PR, or screenshot. Ask only for what you can't infer. Priority, Area, and Category are usually inferable with the rubric. Owner stays empty unless someone was named.
3. **Check for duplicates:**
   ```bash
   gh issue list -R Future-Mortgage/monorepo --state all --limit 10 --search "<2-4 key words>"
   ```
   If one exists, tell the user and offer to comment on it or update it instead.
4. **Draft** the title, the body (template in RULES.md), and the fields. Write the body to the scratchpad, e.g. `<scratchpad>/issue-<slug>.md`.
5. **Draft or post?** Follow the Posting rules in RULES.md. When showing a draft, show the title, the fields on one line, and the body.
6. **Post:**
   ```bash
   ~/.ai/skills/project-board/scripts/board.py post \
     --title "Funnel loan officer contact card shows placeholder phone (000) 000-0000" \
     --body-file <scratchpad>/issue-lo-phone.md \
     --status Todo --priority P1 --area Funnel --category Bug \
     --owner Marcus --assignee mdhenke
   ```
   Run it with `--dry-run` first if any field value is uncertain. That validates everything and writes nothing.
7. **Report** the issue link as `[#1234](url)` plus the fields that were set, on one line.

## Script reference

```bash
B=~/.ai/skills/project-board/scripts/board.py
$B fields                                   # live field names + options
$B post --title T --body-file F [flags]     # create + add to board + set fields
$B set  --issue REF [flags]                 # existing issue: add to board if missing, set fields
```

Flags for `post` and `set`: `--repo` (default `monorepo`), `--status`, `--priority`, `--area`, `--category`, `--owner`, `--start`/`--end` (YYYY-MM-DD), `--parent REF`, `--dry-run`. Only `post` takes `--assignee LOGIN` and `--label NAME`, and both are repeatable.

- `REF` = `1234` | `repo#1234` | full issue URL.
- Option values match case-insensitively, first exactly, then by unique prefix: `P1` → `P1 - High`, `infra` → `Infrastructure / DevOps`, `funnel` → `Funnel / Borrower`.
- Before any write, the script checks option names, labels (they must already exist in the repo), the parent issue, the title, and that the body isn't empty.
- On success it prints `issue=<url>`, `item=<id>`, one `set Field=Value` line per field, and `parent=<url>`.

### Epic + sub-issues

```bash
$B post --title "Epic: Pre-Approval Page" --body-file epic.md --label epic --status Todo --priority P1 --area CRM --category Feature
$B post --title "Pre-Approval: Settings template config" --body-file child1.md --parent 1128 --status Todo --priority P1 --area CRM --category Feature
```

### Edit fields or attach an existing issue

```bash
$B set --issue 2391 --priority P0 --owner Ben
$B set --issue shipyard#12 --status Todo --priority P2 --area infra --category "Tech Debt"   # adds to board if missing
$B set --issue 2384 --parent 2392
```

To edit the title, body, labels, or assignees of an existing issue, use `gh issue edit <n> -R Future-Mortgage/<repo> ...` directly.

## Board reference (snapshot 2026-10-14; `board.py fields` is live truth)

| Field | Options |
|-------|---------|
| Status | Todo · In Progress · In Review · Validate In Dev · Done |
| Priority | P0 - Critical · P1 - High · P2 - Medium · P3 - Low |
| Area | Voice / Twilio · Inbox · Genius AI · Income Calculator · CRM Features · Infrastructure / DevOps · Testing / E2E · Security · DX / Code Quality · Funnel / Borrower · Process |
| Category | Bug · Feature · Tech Debt · Spike · Process |
| Owner | Ben · Martin · Marcus · Brandon · Mira |
| Other | Sprint (14-day iteration, none active), Start Date, End Date |

- Views: Backlog (table), Sprints (board), View 3 (roadmap), Blake's Board.
- Automations: auto-add sub-issues, item closed → Done, PR merged, PR linked. Don't set `Done` by hand on an open issue; close it instead.
- The org has issue *types* (Task/Bug/Feature), but the board doesn't use them. Category is the board's type field.

## Adding or changing PM rules

When the user states a rule about how issues, tickets, priorities, owners, or the board should work, edit `RULES.md` in the right section. Keep the wording short and concrete, then tell them which line changed. Don't put PM rules in memory, CLAUDE.md, or this file.

## Fail hard

| stderr | Action |
|--------|--------|
| `OPTION_NOT_FOUND` | Pick from the listed valid options. If none fit (e.g. a new Area is needed), ask. Don't force a near miss. |
| `LABEL_NOT_FOUND` | Drop the label or ask the user. Never create labels silently. |
| `ISSUE_NOT_FOUND` / `BAD_ISSUE_REF` | Check the number and repo. |
| `HAS_OTHER_PARENT` | Tell the user. Only re-parent if they ask. |
| `PARTIAL: … was created` | The issue exists but board fields failed. Fix the cause and rerun the `set` command it printed. **Don't** post the issue again. |
| `GH_FAILED` with auth/scope errors | The token needs the `project` scope: `gh auth refresh -s project`. |
````

#### `~/.ai/skills/project-board/scripts/board.py`

```python file=~/.ai/skills/project-board/scripts/board.py mode=755
#!/usr/bin/env python3
"""Post issues to the Future Mortgage CRM project board (github.com/orgs/Future-Mortgage/projects/1).

Field and option names are resolved live through `gh`, and every name, label and parent is
validated BEFORE anything is written. Then: create issue -> add to board -> set fields -> link parent.

  board.py fields
  board.py post --title T --body-file F [--repo monorepo] [--status Todo] [--priority P1]
                [--area "CRM Features"] [--category Bug] [--owner Martin]
                [--assignee LOGIN]... [--label NAME]... [--parent REF] [--start DATE] [--end DATE] [--dry-run]
  board.py set  --issue REF [same field flags] [--parent REF] [--dry-run]

REF = 1234 | repo#1234 | https://github.com/Future-Mortgage/<repo>/issues/1234
Option values match case-insensitively, exact first, then unique prefix ("P1" -> "P1 - High").
"""
from __future__ import annotations

import argparse
import datetime
import json
import re
import subprocess
import sys

ORG = "Future-Mortgage"
PROJECT_NUMBER = "1"
DEFAULT_REPO = "monorepo"
SINGLE_SELECT_FIELDS = {
    "status": "Status",
    "priority": "Priority",
    "area": "Area",
    "category": "Category",
    "owner": "Owner",
}
DATE_FIELDS = {"start": "Start Date", "end": "End Date"}
GITHUB_TITLE_MAX = 256

ISSUE_QUERY = """
query($owner: String!, $repo: String!, $number: Int!) {
  repository(owner: $owner, name: $repo) {
    issue(number: $number) { id url title state parent { url } }
  }
}
"""
ADD_SUB_ISSUE = """
mutation($parent: ID!, $child: ID!) {
  addSubIssue(input: {issueId: $parent, subIssueId: $child}) { issue { url } }
}
"""


class BoardError(Exception):
    pass


def gh(*args: str, stdin: str | None = None) -> str:
    result = subprocess.run(["gh", *args], capture_output=True, text=True, input=stdin)
    if result.returncode != 0:
        raise BoardError(f"GH_FAILED: gh {' '.join(args[:3])}\n{result.stderr.strip()}")
    return result.stdout


def gh_json(*args: str) -> dict | list:
    return json.loads(gh(*args))


def load_board() -> tuple[str, dict[str, dict]]:
    project = gh_json("project", "view", PROJECT_NUMBER, "--owner", ORG, "--format", "json")
    fields = gh_json(
        "project", "field-list", PROJECT_NUMBER, "--owner", ORG, "--format", "json", "--limit", "100"
    )["fields"]
    return project["id"], {field["name"]: field for field in fields}


def board_field(fields: dict[str, dict], name: str) -> dict:
    if name not in fields:
        raise BoardError(f"FIELD_NOT_FOUND: {name!r}. Board fields: {', '.join(fields)}")
    return fields[name]


def resolve_option(field: dict, wanted: str) -> dict:
    options = field.get("options")
    if not options:
        raise BoardError(f"FIELD_NOT_SINGLE_SELECT: {field['name']}")
    needle = wanted.strip().lower()
    exact = [option for option in options if option["name"].lower() == needle]
    if exact:
        return exact[0]
    prefixed = [option for option in options if option["name"].lower().startswith(needle)]
    if len(prefixed) == 1:
        return prefixed[0]
    valid = ", ".join(option["name"] for option in options)
    raise BoardError(f"OPTION_NOT_FOUND: {field['name']}={wanted!r}. Valid: {valid}")


def plan_field_edits(fields: dict[str, dict], args: argparse.Namespace) -> list[tuple[dict, list[str], str]]:
    edits = []
    for arg_name, field_name in SINGLE_SELECT_FIELDS.items():
        wanted = getattr(args, arg_name)
        if wanted is None:
            continue
        field = board_field(fields, field_name)
        option = resolve_option(field, wanted)
        edits.append((field, ["--single-select-option-id", option["id"]], f"{field_name}={option['name']}"))
    for arg_name, field_name in DATE_FIELDS.items():
        wanted = getattr(args, arg_name)
        if wanted is None:
            continue
        try:
            datetime.date.fromisoformat(wanted)
        except ValueError:
            raise BoardError(f"BAD_DATE: --{arg_name} {wanted!r} (use YYYY-MM-DD)")
        field = board_field(fields, field_name)
        edits.append((field, ["--date", wanted], f"{field_name}={wanted}"))
    return edits


def parse_issue_ref(ref: str, default_repo: str) -> tuple[str, int]:
    ref = ref.strip()
    url = re.fullmatch(rf"https://github\.com/{ORG}/([\w.-]+)/issues/(\d+)/?", ref)
    if url:
        return url.group(1), int(url.group(2))
    short = re.fullmatch(r"(?:([\w.-]+)#|#)?(\d+)", ref)
    if short:
        return short.group(1) or default_repo, int(short.group(2))
    raise BoardError(f"BAD_ISSUE_REF: {ref!r} (use 1234, repo#1234, or the issue URL)")


def lookup_issue(repo: str, number: int) -> dict:
    data = gh_json(
        "api", "graphql",
        "-f", f"query={ISSUE_QUERY}",
        "-f", f"owner={ORG}",
        "-f", f"repo={repo}",
        "-F", f"number={number}",
    )
    issue = data["data"]["repository"]["issue"]
    if issue is None:
        raise BoardError(f"ISSUE_NOT_FOUND: {ORG}/{repo}#{number}")
    return issue


def check_labels(repo: str, labels: list[str]) -> None:
    if not labels:
        return
    existing = {label["name"] for label in gh_json("label", "list", "-R", f"{ORG}/{repo}", "--limit", "500", "--json", "name")}
    missing = [label for label in labels if label not in existing]
    if missing:
        raise BoardError(
            f"LABEL_NOT_FOUND: {missing} in {ORG}/{repo}. Pick an existing label (gh label list -R {ORG}/{repo}) "
            "or ask before creating one."
        )


def read_body(path: str) -> str:
    body = sys.stdin.read() if path == "-" else open(path, encoding="utf-8").read()
    if not body.strip():
        raise BoardError("EMPTY_BODY: issue body is empty")
    return body


def apply_to_board(issue: dict, project_id: str, edits: list, parent: dict | None) -> None:
    item = gh_json("project", "item-add", PROJECT_NUMBER, "--owner", ORG, "--url", issue["url"], "--format", "json")
    if "id" not in item:
        raise BoardError(f"ITEM_ADD_NO_ID: unexpected item-add output {item}")
    print(f"item={item['id']}")
    for field, value_args, label in edits:
        gh("project", "item-edit", "--id", item["id"], "--project-id", project_id, "--field-id", field["id"], *value_args)
        print(f"set {label}")
    if parent is None:
        return
    current_parent = (issue.get("parent") or {}).get("url")
    if current_parent == parent["url"]:
        print(f"parent={parent['url']} (already linked)")
        return
    if current_parent is not None:
        raise BoardError(f"HAS_OTHER_PARENT: {issue['url']} is already a sub-issue of {current_parent}")
    gh("api", "graphql", "-f", f"query={ADD_SUB_ISSUE}", "-f", f"parent={parent['id']}", "-f", f"child={issue['id']}")
    print(f"parent={parent['url']}")


def print_plan(action: str, edits: list, parent: dict | None, extra: list[str]) -> None:
    print(f"DRY RUN — {action}")
    for line in extra:
        print(f"  {line}")
    for _, _, label in edits:
        print(f"  set {label}")
    if parent:
        print(f"  parent={parent['url']} ({parent['title']})")


def cmd_fields(_: argparse.Namespace) -> None:
    _, fields = load_board()
    for name, field in fields.items():
        options = field.get("options")
        if options:
            print(f"{name}: {' | '.join(option['name'] for option in options)}")
        else:
            print(f"{name}: ({field['type']})")


def cmd_post(args: argparse.Namespace) -> None:
    title = args.title.strip()
    if not title:
        raise BoardError("EMPTY_TITLE")
    if len(title) > GITHUB_TITLE_MAX:
        raise BoardError(f"TITLE_TOO_LONG: {len(title)} chars (max {GITHUB_TITLE_MAX})")
    body = read_body(args.body_file)
    project_id, fields = load_board()
    edits = plan_field_edits(fields, args)
    check_labels(args.repo, args.label)
    parent = lookup_issue(*parse_issue_ref(args.parent, args.repo)) if args.parent else None

    if args.dry_run:
        print_plan(
            "post",
            edits,
            parent,
            [f"repo={ORG}/{args.repo}", f"title={title}", f"labels={args.label}", f"assignees={args.assignee}"],
        )
        return

    create = ["issue", "create", "-R", f"{ORG}/{args.repo}", "--title", title, "--body-file", "-"]
    for label in args.label:
        create += ["--label", label]
    for assignee in args.assignee:
        create += ["--assignee", assignee]
    url = gh(*create, stdin=body).strip().splitlines()[-1]
    print(f"issue={url}")

    try:
        issue = lookup_issue(*parse_issue_ref(url, args.repo))
        apply_to_board(issue, project_id, edits, parent)
    except BoardError:
        print(
            f"PARTIAL: {url} was created but the board update failed. Fix the cause, then rerun "
            f"`board.py set --issue {url}` with the same field flags.",
            file=sys.stderr,
        )
        raise


def cmd_set(args: argparse.Namespace) -> None:
    repo, number = parse_issue_ref(args.issue, args.repo)
    issue = lookup_issue(repo, number)
    project_id, fields = load_board()
    edits = plan_field_edits(fields, args)
    parent = lookup_issue(*parse_issue_ref(args.parent, repo)) if args.parent else None
    if not edits and parent is None:
        raise BoardError("NOTHING_TO_SET: pass at least one field flag or --parent")
    if args.dry_run:
        print_plan("set", edits, parent, [f"issue={issue['url']} ({issue['title']})"])
        return
    print(f"issue={issue['url']}")
    apply_to_board(issue, project_id, edits, parent)


def add_field_flags(parser: argparse.ArgumentParser) -> None:
    parser.add_argument("--repo", default=DEFAULT_REPO, help=f"repo in {ORG} (default {DEFAULT_REPO})")
    for arg_name, field_name in SINGLE_SELECT_FIELDS.items():
        parser.add_argument(f"--{arg_name}", help=f"board {field_name} option")
    for arg_name, field_name in DATE_FIELDS.items():
        parser.add_argument(f"--{arg_name}", help=f"board {field_name} (YYYY-MM-DD)")
    parser.add_argument("--parent", help="parent issue REF (makes this a sub-issue)")
    parser.add_argument("--dry-run", action="store_true", help="validate and print the plan, write nothing")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = parser.add_subparsers(dest="command", required=True)

    sub.add_parser("fields", help="print live board fields and options").set_defaults(run=cmd_fields)

    post = sub.add_parser("post", help="create an issue and put it on the board")
    post.add_argument("--title", required=True)
    post.add_argument("--body-file", required=True, help="markdown body file, or - for stdin")
    post.add_argument("--assignee", action="append", default=[], help="GitHub login (repeatable)")
    post.add_argument("--label", action="append", default=[], help="existing repo label (repeatable)")
    add_field_flags(post)
    post.set_defaults(run=cmd_post)

    set_ = sub.add_parser("set", help="add an existing issue to the board and/or set its fields")
    set_.add_argument("--issue", required=True, help="issue REF")
    add_field_flags(set_)
    set_.set_defaults(run=cmd_set)

    args = parser.parse_args()
    try:
        args.run(args)
    except BoardError as error:
        print(str(error), file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
```

#### `~/.ai/skills/psychopomp/SKILL.md`

````markdown file=~/.ai/skills/psychopomp/SKILL.md
---
name: psychopomp
description: >
  Make explainer reels and deterministic motion graphics with Psychopomp:
  walkthrough videos of pull requests, code changes, protocols, or lifecycles,
  with GPU Stage choreography, callouts, rolling numbers, sequence diagrams,
  animated diffs, and optional ElevenLabs or Fish Audio narration.
---

# Psychopomp explainer reels

An **explainer reel** is several independently authored Scene Plans joined on one
clock: behavior stories on the GPU Stage (orbs, cards, beams, packets, camera,
bloom), pinned Callouts, Rolling Numbers, changes as animated Stepped Diffs,
captions in a terminal voice, and optional spoken narration. When narrated,
every visual beat waits for a phrase in the transcript, so re-voicing re-times
the film automatically.

Default narration voice is Jack, the cloned ElevenLabs voice `WWy4oxSuyItpmR1cjGaA` (young male, American English). Use `Voice::eleven("WWy4oxSuyItpmR1cjGaA")` and `"voice": "WWy4oxSuyItpmR1cjGaA"` unless the user names a different voice. The key is `ELEVENLABS_API_KEY` in the psychopomp repo `.env`. Do not print it.

The working examples are in `scenes/pr-walkthrough`: `src/flagship.rs` (#50825 as a
Stage film that zooms into its code), `src/stop_stage.rs` (#50042 combining Stage,
Callouts, Rolling Number, and a Zoom into an annotated code diff), and `src/lib.rs`
(the five-PR reel with sequence diagrams). Copy their shape; do not start from a
blank crate. Component payloads, channels, and commands live in `SCENE_PLANS.md`
("Make A Narrated Explainer Reel") and terms in `CONTEXT.md`; read both before
authoring. Engineering rules are in `AGENTS.md`.

## Steps

1. **Establish the facts.** For each change, read the actual diff and PR description
   (`gh pr diff`, `gh pr view`) and write one sentence each for the broken behavior,
   the fixed behavior, and the change. Done when every claim you will narrate is
   traceable to code, a test, or a reproduced run; mark anything you could not verify
   and keep it out of the script.

2. **Write the script** as `scenes/<name>/narration/script.json`, one clip per part:
   intro, then per change `<slug>-before`, `<slug>-after`, `<slug>-code`, then outro.
   Follow [STORY.md](STORY.md) when writing it. Done when each clip is under about 30
   seconds spoken and every planned visual beat has a distinct anchor phrase in it.

3. **Voice it (optional).** Draft first with no credentials (`--draft` uses macOS
   `say`), or synthesize final narration with **ElevenLabs** (`engine: "elevenlabs"`,
   default model `eleven_v4`) or **Fish Audio** (`engine: "fish"`):
   ```json
   {
     "engine": "elevenlabs",
     "model": "eleven_v4",
     "voice": "<elevenlabs-voice-id>",
     "settings": { "stability": 0.5, "similarity": 0.7 },
     "clips": [
       { "id": "change-before", "text": "[warm, conversational voice] ..." }
     ]
   }
   ```
   ```sh
   # Draft (no API key required)
   bun scripts/narrate.ts scenes/<name>/narration/script.json --draft

   # ElevenLabs (requires ELEVENLABS_API_KEY and script.voice)
   ELEVENLABS_API_KEY=... bun scripts/narrate.ts scenes/<name>/narration/script.json

   # Fish Audio (requires FISH_AUDIO_API_KEY)
   FISH_AUDIO_API_KEY=... bun scripts/narrate.ts scenes/<name>/narration/script.json
   ```
   `scripts/narrate.ts` normalizes loudness, transcribes word timings with Whisper,
   and writes `<id>.mp3`, `<id>.words.json`, and `narration.json`. When switching
   voices or engines, rebuild the Scene Plan against the new word timings.

   **Or declare the narration in the Scene Program** with `psychopomp-media`
   (SCENE_PLANS.md, "Declare Narration And Sound"): `media.say(id, &voice, text)`,
   `media.dialogue`, `media.sfx`, and `audio.derive(Effect::pitch(..))`, then
   `media.finish()?`. Each line is generated once and recorded in
   `media.lock.json`; later runs call nothing unless a declaration changed, and
   ElevenLabs words come from its character alignment with the script's spelling.
   Check the cost first with `PSYCHOPOMP_MEDIA=plan cargo run -p <crate>` (zero
   API calls), time with `PSYCHOPOMP_MEDIA=draft`, and clean up with
   `PSYCHOPOMP_MEDIA=prune`. Move a narrate.ts scene with
   `cargo run -p psychopomp-media -- adopt scenes/<name>/narration` (no
   regeneration). Done when a plain run reports every resource `=`.

4. **Author the Scene Program** in `scenes/<name>` (the workspace picks it up; add
   it to `verify.json` with a few key times).
   Use `psychopomp::score` (`SCENE_PLANS.md`, "Author With The Score DSL") so
   `PlanBuilder` is the only `mut` binding and every actor (`Stage`, `Camera`,
   `Caption`, `Callout`, `RollingNumber`, `Checklist`, `Meter`, `Bars`,
   `Subtitles`, `Confetti`, `Terminal`, `Chat`, `ChangedFiles`, `LowerThird`,
   `Lens`) is an immutable value whose methods return composable `Beat`s
   (`.then`, `.also`, `.with`, `.on_end`, `.after`, `.early`, `stagger`, `each`,
   `at!(scene, time => ...)`). Schedule clips with `Narration::reading`, build
   elements with `StageElement::card|orb|beam|packet|label|ring` and relative
   `psychopomp::layout::Placement` envelopes on `StagePost::RESTRAINED`, frame
   with `Caption::header|chip|footer`, and play sounds with `sfx::*.beat(id, gain_db)`
   (or `audio.beat(gain_db)` for `psychopomp-media`). Load the `explainer-motion`
   skill and apply it to every beat: cards `settle_in`, beams `connect`,
   messages `send`, replies wait for `.reply()`, impacts `hit`, the hero `orb_in`,
   the fix's `rewind`; use `Callout` to pin annotations to Stage elements or
   Editor code ranges and `RollingNumber` for live counters/timers; drive camera
   moves through `stage.camera()` (`establish`, `frame`, `follow`, `release`,
   `orbit`, `whip`, `dolly_zoom`). Reach for the visualization and text overlays
   instead of hand-building them from Stage labels and rings: `Checklist` for
   checks that run and resolve, `Meter` (`MeterPlan::countdown`) for a timeout
   ring, `Bars` for before/after numbers, `Confetti` for a success beat, and
   `Subtitles` (`SubtitlesPlan::from_spoken`) to burn in word-timed captions.
   Changes are `Diff`s of `keep`, `add(step)`, and `remove(step)` lines, each step
   keyed to a phrase. Done when `cargo run -p <crate>` writes the reel and
   `cargo run --release -- plan validate <reel>` reports valid. A missing phrase panics
   with its clip: change the anchor to words the transcript actually contains.

5. **Review before rendering.** Get segment spans from `plan inspect <reel>`, then
   contact-sheet each segment at its before, switch, after, and code beats:
   ```sh
   bun scripts/sheet.ts <reel> t1,t2,... --theme neutral --shutter --out output/sheet.jpg
   ```
   When tuning the look, set `PSYCHOPOMP_SHADER_DIR=crates/psychopomp-render/src/render`
   and edit `stage.wgsl`/`stage_post.wgsl`: every frame and sheet picks up shader edits
   without a Rust rebuild.
   Then render one behavior segment with audio (`plan render <reel> out.mp4 --cue <scene-id>`)
   or a 2–3 second window (`--range a..b`) and inspect frames extracted during
   motion. Done when every segment has been looked at and no text overlaps, clips,
   or reads against the wrong chip.

6. **Render and verify** the whole reel once, after the sheets and short windows
   pass. Run it in the foreground with a long timeout and never end a turn while it
   is still running:
   ```sh
   cargo run --release -- plan render <reel> output/<name>.mp4 --theme neutral
   ```
   Done when `ffprobe` shows 1920x1080, 60 fps, AAC audio, and a duration matching
   `plan inspect`, and loudness is near -16 LUFS with peaks under -1 dBFS.

7. **Deliver** the MP4 path. Commit the scene, narration assets, and any engine
   changes in Psychopomp with conventional messages.

## Improving Psychopomp

When a reel needs something the engine cannot do, add it to Psychopomp rather than
working around it in one scene: plan types and validation in `crates/psychopomp`,
strict-channel preflight in `plan_runtime`, pixels in `render`, GPU-free tests plus
an `#[ignore]` GPU test, and the docs `AGENTS.md` asks you to keep current. Run
`cargo run --release -- verify baseline` before the change and `verify compare
--expect <scenes you changed>` after it to prove every other showroom and film is
untouched.

Build from small reusable pieces. Interpolation, easing, curves, shape ports, and
connectors belong in `psychopomp::math` (organized like pmndrs `math`: core `lerp`/
`remap`/`smoothstep`, `easing`, `curve`, `shapes`, `random`; glam vectors). Extend it
instead of inlining math in a renderer or scene, and split renderers into one small
helper per element, as `render/stage.rs` does. Keep
`cargo fmt --check`, `cargo clippy --workspace --all-targets --all-features -- -D warnings`,
and `cargo test --workspace` green.
````

#### `~/.ai/skills/psychopomp/STORY.md`

```markdown file=~/.ai/skills/psychopomp/STORY.md
# Telling an explainer reel

## Structure

- **Behavior before code.** For each change: the broken behavior first, the fixed
  behavior replayed in the same space, then the code diff. Viewers should
  understand what goes wrong before they see why.
- **Replay, don't redraw.** Actors shared by both stories stay; broken-only elements
  fade or rewind; the fix resolves the same moment differently. The switch is the
  comparison.
- **One idea per beat.** A packet, a callout, a strike, or a caption appears when
  the narration says it, and not before.

## Motion craft

Every reel is judged on motion craft; flat fades are the failure mode. Apply the
`explainer-motion` skill to every beat (its rules, beats, and constants are the
single source), and use the Stage's helpers that implement them.

## Narration

- Plain, confident, short sentences. Say what happens, then why it matters. No
  hype, no filler, no "basically".
- Spell things as they should be spoken; the transcript, not the script, decides
  what an anchor matches.
- When using ElevenLabs `eleven_v4`, place concise vocal directions in square
  brackets before the clause (`[warm, conversational voice]`, `[measured,
  concerned voice]`, `[firm, clear delivery]`) and verify that no direction tags
  were spoken in the generated `.words.json` transcript.
- **Anchors** are the phrases visuals wait for. Choose plain words the speech
  recognizer cannot reformat. Avoid acronyms and jargon (TUI, SIGKILL) and spoken
  punctuation as anchors; number words are fine because they match digits.
- Each anchor must be unique within its clip. If a phrase repeats, anchor on the
  earlier phrase and search after it.

## Visual voice

- Themes: `--theme neutral` or `--theme opencode`, CommitMono, lowercase captions,
  one accent keyword per caption, block caret while typing.
- Tones mean the same thing everywhere: request (blue), success (green), error
  (red), warning (yellow), muted, accent (the one thing to follow).
- Header caption top left (`#number  title`), status chip top right (`before`,
  `◀◀ rewind`, `after the fix`, `the change`), one footer caption that sums up the beat.
- Behavior stories use the Stage (orb, cards, beams, packets, callouts, rolling
  numbers); keep Sequence Diagrams for protocols with many ordered messages.
- Code is **condensed for display**, never invented: at most 76 columns and 14 rows,
  real identifiers, the same shape as the real change. Say so in the footer.
- Prefer `zoom` transitions when flying from a Stage card into its code, and `dip`
  transitions between text-dense segments.
```

#### `~/.ai/skills/slack/SKILL.md`

````markdown file=~/.ai/skills/slack/SKILL.md
---
name: slack
description: Post messages to Genius Slack as Martin (slackatui user token). Use when the user says post to Slack, ping someone in Slack, tell #prworld a PR is ready, send a Slack message, or "slack this". Not a slash command — load this skill and run the helper script.
---

# slack — post as Martin

Post to the Genius Slack workspace. **Skill only** (no `/slack` command). Auth is Martin's slackatui user token in macOS Keychain.

Script (never prints tokens):

```bash
~/.ai/skills/slack/scripts/slack-post.py
```

## When to use

User asks to post / ping / tell Slack. Then load this skill and run the script. Do **not** post unless they asked.

## Fast path

```bash
# Channel message
~/.ai/skills/slack/scripts/slack-post.py post \
  --channel prworld \
  --text "https://github.com/Future-Mortgage/monorepo/pull/2133 this is ready again"

# Ping someone, then the text
~/.ai/skills/slack/scripts/slack-post.py post \
  --channel prworld \
  --mention Ben \
  --text "https://github.com/Future-Mortgage/monorepo/pull/2133 this is ready again"

# Thread reply (thread_ts from a prior post)
~/.ai/skills/slack/scripts/slack-post.py post \
  --channel prworld \
  --thread-ts 1789776717.232189 \
  --text "Review comments are done and pushed."

# Direct message one person (exact handle / real name / display name / U… / @me; never a substring guess)
~/.ai/skills/slack/scripts/slack-post.py dm --to "Marcus Henke" \
  --text "https://github.com/Future-Mortgage/monorepo/pull/2133 approved"
~/.ai/skills/slack/scripts/slack-post.py dm --to @me --text "note to self"
~/.ai/skills/slack/scripts/slack-post.py dm --to Ben --text "x" --dry-run   # resolve only

# Resolve names
~/.ai/skills/slack/scripts/slack-post.py channels
~/.ai/skills/slack/scripts/slack-post.py users
```

Stdout on success: permalink, `ts=`, `channel=`. Give the user the permalink.

## Rules

1. **Auth.** Token from `SLACK_USER_TOKEN` / `SLACK_BOT_TOKEN`, else Keychain service `slackatui`. If `AUTH_MISSING`: tell them to run `slackatui auth`. Do not invent tokens. Never print the token or keychain JSON.
2. **Channel.** `--channel prworld` or `#prworld` or `C…`. `#prworld` is where PRs get review pings.
3. **Mentions.** `--mention Ben` (repeatable). Script resolves to `<@U…>` and prepends. Common: Ben (`ben.bengoetxea`, rereview), Marcus (`marcus.henke` / mdhenke), Blake (`blake.bianchi`). Martin's rereview pattern in `#prworld`: ping Ben + PR link + "this is ready again".
4. **Voice.** Short, like Martin's existing `#prworld` messages. Not a changelog. Not "I have completed the requested review items."
5. **Don't.** Don't post from this skill unprompted. Don't create `commands/slack.md`. Don't dump the user/channel list into chat unless you need it to resolve a name.

## Fail hard

| stderr | Action |
|--------|--------|
| `AUTH_MISSING` | Stop. Tell user to `slackatui auth` (or set `SLACK_USER_TOKEN`). |
| `CHANNEL_NOT_FOUND` / `USER_NOT_FOUND` | Run `channels` / `users`, pick the right name, retry once. If still missing, ask. |
| `not_in_channel` / `invalid_auth` | Stop and report the Slack error code. |
````

#### `~/.ai/skills/slack/scripts/slack-post.py`

```python file=~/.ai/skills/slack/scripts/slack-post.py mode=755
#!/usr/bin/env python3
"""Post to Slack as the slackatui user. Never prints tokens."""

from __future__ import annotations

import argparse
import json
import subprocess
import sys
import urllib.error
import urllib.parse
import urllib.request

KEYCHAIN_SERVICE = "slackatui"
KEYCHAIN_ACCOUNTS = ("default", "T0AAYE6T63W")


class SlackError(Exception):
    def __init__(self, message: str, *, code: str = "SLACK_ERROR"):
        super().__init__(message)
        self.code = code


def load_token() -> str:
    env = __import__("os").environ
    for key in ("SLACK_USER_TOKEN", "SLACK_BOT_TOKEN"):
        value = env.get(key, "").strip()
        if value:
            return value

    last_err = "no slackatui tokens in keychain"
    for account in KEYCHAIN_ACCOUNTS:
        try:
            raw = subprocess.check_output(
                [
                    "security",
                    "find-generic-password",
                    "-s",
                    KEYCHAIN_SERVICE,
                    "-a",
                    account,
                    "-w",
                ],
                stderr=subprocess.DEVNULL,
                text=True,
            ).strip()
        except subprocess.CalledProcessError:
            continue
        try:
            data = json.loads(raw)
        except json.JSONDecodeError:
            last_err = "keychain value is not JSON"
            continue
        token = (data.get("user_token") or data.get("bot_token") or "").strip()
        if token:
            return token
        last_err = "keychain JSON has no user_token or bot_token"

    raise SlackError(
        f"{last_err}. Run `slackatui auth` or set SLACK_USER_TOKEN.",
        code="AUTH_MISSING",
    )


def api(token: str, method: str, payload: dict | None = None, **params) -> dict:
    headers = {"Authorization": f"Bearer {token}"}
    if payload is None:
        url = f"https://slack.com/api/{method}?{urllib.parse.urlencode(params)}"
        req = urllib.request.Request(url, headers=headers)
    else:
        req = urllib.request.Request(
            f"https://slack.com/api/{method}",
            data=json.dumps(payload).encode(),
            headers={**headers, "Content-Type": "application/json"},
        )
    try:
        with urllib.request.urlopen(req) as resp:
            body = json.loads(resp.read().decode())
    except urllib.error.HTTPError as exc:
        raise SlackError(f"HTTP {exc.code} calling {method}", code="HTTP") from exc
    if not body.get("ok"):
        raise SlackError(
            body.get("error") or f"{method} failed",
            code=str(body.get("error") or "API"),
        )
    return body


def paginate_users(token: str) -> list[dict]:
    members: list[dict] = []
    cursor = ""
    while True:
        kwargs: dict = {"limit": 200}
        if cursor:
            kwargs["cursor"] = cursor
        data = api(token, "users.list", **kwargs)
        members.extend(data.get("members") or [])
        cursor = (data.get("response_metadata") or {}).get("next_cursor") or ""
        if not cursor:
            return members


def paginate_channels(token: str) -> list[dict]:
    channels: list[dict] = []
    cursor = ""
    while True:
        kwargs: dict = {
            "types": "public_channel,private_channel",
            "limit": 200,
            "exclude_archived": "true",
        }
        if cursor:
            kwargs["cursor"] = cursor
        data = api(token, "conversations.list", **kwargs)
        channels.extend(data.get("channels") or [])
        cursor = (data.get("response_metadata") or {}).get("next_cursor") or ""
        if not cursor:
            return channels


def norm(value: str) -> str:
    return value.strip().lstrip("#@").lower()


def resolve_channel(token: str, name_or_id: str) -> str:
    raw = name_or_id.strip()
    if raw.startswith("C") and raw[1:].isalnum() and len(raw) >= 9:
        return raw
    want = norm(raw)
    for ch in paginate_channels(token):
        if norm(ch.get("name") or "") == want:
            return ch["id"]
    raise SlackError(f"channel not found: {name_or_id}", code="CHANNEL_NOT_FOUND")


def resolve_user(token: str, name_or_id: str) -> str:
    raw = name_or_id.strip()
    if raw.startswith("U") and raw[1:].isalnum() and len(raw) >= 9:
        return raw
    want = norm(raw)
    for member in paginate_users(token):
        if member.get("deleted") or member.get("is_bot"):
            continue
        profile = member.get("profile") or {}
        candidates = [
            member.get("id") or "",
            member.get("name") or "",
            member.get("real_name") or "",
            profile.get("display_name") or "",
            profile.get("real_name") or "",
        ]
        if any(norm(c) == want for c in candidates if c):
            return member["id"]
        if any(want in norm(c) for c in candidates if c):
            return member["id"]
    raise SlackError(f"user not found: {name_or_id}", code="USER_NOT_FOUND")


def resolve_user_exact(token: str, name_or_id: str) -> str:
    """DM targets: exact id / @me / handle / real name / display name. No substring guesses."""
    raw = name_or_id.strip()
    if raw == "@me":
        return api(token, "auth.test")["user_id"]
    if raw.startswith("U") and raw[1:].isalnum() and len(raw) >= 9:
        return raw
    want = norm(raw)
    matches = []
    for member in paginate_users(token):
        if member.get("deleted") or member.get("is_bot"):
            continue
        profile = member.get("profile") or {}
        candidates = [
            member.get("name") or "",
            member.get("real_name") or "",
            profile.get("display_name") or "",
            profile.get("real_name") or "",
        ]
        if any(norm(c) == want for c in candidates if c):
            matches.append(member["id"])
    if len(matches) == 1:
        return matches[0]
    if not matches:
        raise SlackError(f"user not found (exact match): {name_or_id}", code="USER_NOT_FOUND")
    raise SlackError(f"ambiguous user {name_or_id}: {', '.join(matches)}", code="USER_AMBIGUOUS")


def cmd_dm(args: argparse.Namespace) -> int:
    token = load_token()
    user_id = resolve_user_exact(token, args.to)
    if args.dry_run:
        print(f"dry-run: would DM {user_id}: {args.text}")
        return 0
    channel = api(token, "conversations.open", {"users": user_id})["channel"]["id"]
    out = api(token, "chat.postMessage", {"channel": channel, "text": args.text})
    print(permalink(channel, out["ts"]))
    print(f"ts={out['ts']}")
    print(f"channel={channel}")
    print(f"user={user_id}")
    return 0


def permalink(channel: str, ts: str) -> str:
    return f"https://trygenius.slack.com/archives/{channel}/p{ts.replace('.', '')}"


def cmd_post(args: argparse.Namespace) -> int:
    token = load_token()
    channel = resolve_channel(token, args.channel)
    text = args.text
    mentions = args.mention or []
    if mentions:
        tags = " ".join(f"<@{resolve_user(token, m)}>" for m in mentions)
        text = f"{tags} {text}".strip()
    payload: dict = {"channel": channel, "text": text}
    if args.thread_ts:
        payload["thread_ts"] = args.thread_ts
    out = api(token, "chat.postMessage", payload)
    ts = out["ts"]
    print(permalink(channel, ts))
    if args.thread_ts:
        print(f"thread_ts={args.thread_ts}")
    print(f"ts={ts}")
    print(f"channel={channel}")
    return 0


def cmd_list_channels(args: argparse.Namespace) -> int:
    token = load_token()
    for ch in paginate_channels(token):
        flag = "private" if ch.get("is_private") else "public"
        print(f"{ch['id']}\t#{ch.get('name')}\t{flag}")
    return 0


def cmd_list_users(args: argparse.Namespace) -> int:
    token = load_token()
    for member in paginate_users(token):
        if member.get("deleted") or member.get("is_bot"):
            continue
        profile = member.get("profile") or {}
        display = profile.get("display_name") or member.get("real_name") or ""
        print(f"{member['id']}\t{member.get('name')}\t{display}")
    return 0


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest="cmd", required=True)

    post = sub.add_parser("post", help="Post a channel message")
    post.add_argument("--channel", required=True, help="Name (#prworld) or id (C…)")
    post.add_argument("--text", required=True)
    post.add_argument(
        "--mention",
        action="append",
        default=[],
        help="User name or id to ping (repeatable). Prepended as <@U…>.",
    )
    post.add_argument("--thread-ts", default="", help="Reply in this thread")
    post.set_defaults(func=cmd_post)

    dm = sub.add_parser("dm", help="Direct-message one person (or @me)")
    dm.add_argument("--to", required=True, help="@me, U… id, or exact handle / real name / display name")
    dm.add_argument("--text", required=True)
    dm.add_argument("--dry-run", action="store_true", help="Resolve the target, send nothing")
    dm.set_defaults(func=cmd_dm)

    chans = sub.add_parser("channels", help="List channels")
    chans.set_defaults(func=cmd_list_channels)

    users = sub.add_parser("users", help="List users")
    users.set_defaults(func=cmd_list_users)

    args = parser.parse_args()
    try:
        return args.func(args)
    except SlackError as exc:
        print(f"{exc.code}: {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
```

#### `~/.ai/skills/watch-pr/SKILL.md`

````markdown file=~/.ai/skills/watch-pr/SKILL.md
---
name: watch-pr
description: Watches a GitHub PR every 5 minutes and acts on what changed, based on whether you wrote it (author) or are reviewing it (reviewer). Author - auto-fixes merge conflicts and CI, runs review fixes, pushes, and Slack-DMs reviewers ("needs a re-review", "this needs another approval"). Reviewer - when the author pushes or replies, checks whether each of your review threads was addressed well, reviews the new changes, then approves or posts more findings, and DMs the author ("approved", "more findings"). This session only dispatches and answers questions; every fix/review runs in a background subagent, in the current worktree if you are already in one for that PR, else in a dedicated watch worktree. Use when the user says "/watch-pr 1234", "watch this PR", "monitor PR", "babysit PR", "keep an eye on #1234", or "/watch-pr stop 1234".
---

# /watch-pr — PR watcher

**Usage:** `/watch-pr [PR# | URL] [--as author|reviewer] [--every 5m]` · `/watch-pr stop <PR#>` · `/watch-pr status <PR#>`

PR# is optional when the session is already in a worktree for that PR.

User arguments: `$ARGUMENTS`

A deterministic poller (`scripts/watch_pr.py`, no LLM) diffs the PR every interval and prints one line per event. This session runs it under **Monitor**, so quiet polls cost nothing. On events, this session **dispatches background subagents** to do the work. It stays free so the user can ask "what's going on with #1234?" at any time.

```
W=~/.ai/skills/watch-pr/scripts/watch_pr.py      # every call takes --repo OWNER/NAME --pr N
$W watch   --role auto|author|reviewer --interval 300   # Monitor stream
$W status                                             # fresh state + recent activity log
$W threads --started-by @me [--unresolved]            # thread bodies (address check)
$W log     --who <dispatcher|worker:kind> "msg"       # activity log line
$W dm      --to <github-login|@me> --text "msg"       # Slack DM, deduped 30 min
$W once [--no-save] | reset                           # one-off poll / forget state
```

State + activity log: `~/.cache/watch-pr/<owner>-<repo>-<N>.{json,log}`. GitHub→Slack map: `~/.config/watch-pr/people.json` (`{"<github-login>": "<slack handle>" | null}`), kept outside this public repo.
- **Strict.** Only logins listed there get DMs; `null` marks a bot (never DMed). No name matching or guessing.
- **Unmapped login:** `dm` fails with `USER_NOT_MAPPED`. DM self `<url> can't DM <login>: add them to people.json` + push notify, and send nothing to anyone.

---

## Roles

| Role | When | You are in charge of |
|------|------|----------------------|
| **author** | PR author is you (`--as author` to force, e.g. you push to a teammate's PR) | conflicts, CI, answering reviews, getting approvals |
| **reviewer** | anyone else's PR | checking your review was addressed, approving or posting more findings |

`auto` decides from the PR author; the role is saved in state. A cross-repo (fork) PR in author mode cannot be pushed to. Run notify-only and say so.

---

## Dispatcher rules (this session)

1. **Never edit code, run fixes, or push here.** All of that goes to a subagent (Agent tool, background). This session handles: parsing events, `status`, `log`, `dm`, `PushNotification`, `gh pr edit --add-reviewer`, and talking to the user.
2. **One worker per PR at a time.** Events that land while a worker runs are only logged. When the worker finishes, run `status` and dispatch whatever is *still* true (a CI failure on an old head is stale). In author mode, `reviews awaiting your answer: N>0` or unresolved threads where the last word is not yours means a review-fix worker is still owed.
3. **Priority (author):** CONFLICT → pre-push hook failure → CI_FAILED → review fixes. Skip CI fixes while the branch conflicts (CI does not run on a conflicting PR; the merge push re-runs it).
4. **Log every dispatch and outcome:** `$W log --who dispatcher "dispatched ci worker for typecheck@3ef83f30"`.
5. **User questions:** run `$W status` (fresh) and read the log tail. Answer from those plus the running worker's `worker:*` log lines. Never invent a running worker's result. If it hasn't returned, say it is still running and what it last logged.
6. **Loop until it works.** There are no retry caps:
   - After a worker returns `failed` or `no-change`, run `status`. If the same problem is still there on the current head (conflict, failing check, pre-push failure, unanswered review), dispatch again right away.
   - Each retry gets every earlier attempt's SUMMARY/DETAILS for that problem, plus "try a different approach than these".
   - Log each attempt (`attempt N for typecheck`) so `status` shows the loop.
   - Only outcomes code cannot fix wait instead of looping:
     - a safety stop from the sync rule: uncommitted changes, unpushed local commits, diverged
     - an environment failure: Docker not running, gh/git auth, network

     DM self + push notify once for each, then retry on the next event or when the user says go.
7. **Never** merge, never `--no-verify`, never push to the base branch, never force-push.

---

## Setup

1. **Resolve:** `REPO=$(gh repo view --json nameWithOwner -q .nameWithOwner)`.
   - PR number from the arg/URL. With no arg, take it from the current branch: `quick/pr-N` / `quick/watch-pr-N` → N, else `gh pr view --json number -q .number`. If none, ask.
   - Then `gh pr view N --json headRefName,baseRefName,headRefOid,isCrossRepository,author,url`.
2. **Worktree: use the current one if the session is already in a worktree** (`git rev-parse --show-toplevel` ≠ the first path in `git worktree list --porcelain`). This covers quick, slot, and `.claude/worktrees` worktrees.
   - **It must belong to this PR.** `git fetch origin <headRef>`, then accept it only if the branch is `<headRef>`, `quick/pr-N` or `quick/watch-pr-N`, or `HEAD` and `FETCH_HEAD` are ancestor-related in either direction. Anything else is a hard stop: `current worktree is on <branch>, PR #N is <headRef>`. Never repoint someone's worktree.
   - Run `yarn install` there only if `node_modules` is missing (it is your live worktree; don't churn it).
   - Log `worktree <path> owned=false`.
3. **Otherwise create a dedicated one (Haiku subagent, `model: "haiku"`):** from the primary checkout run `~/.ai/oc_skills/worktree-quick/scripts/quick-worktree.sh create N watch-pr-N`. That gives `…/worktrees/<repo>-quick-watch-pr-N`. Never work in the primary checkout.
   - If it fails with `worktree path already exists`, reuse the path and apply the sync rule from the worker preamble.
   - `yarn install` must exit 0, even on reuse.
   - The subagent returns the path. Log `worktree <path> owned=true`.
4. **Arm Monitor:** command `python3 ~/.ai/skills/watch-pr/scripts/watch_pr.py watch --repo $REPO --pr N --role <auto|--as> --interval 300`, description `PR #N watch`, `timeout_ms: 1800000`.
   - On expiry, re-arm the identical command silently; state persists, so nothing repeats.
   - If it exits after `PR_MERGED` / `PR_CLOSED`, do not re-arm.
   - Arm it in parallel with step 3. Events that need the worktree wait for it.
5. **Tell the user in one line:** `Watching #N as <role> (5 min). Ask me anything about it.` The first poll prints `BASELINE` plus anything already actionable. Handle those like any other event.

`/watch-pr stop N`: TaskStop the monitor, stop any worker, log it, keep the worktree. `/watch-pr status N`: run `status` and summarize.

---

## Author playbook

| Event | Action |
|-------|--------|
| `CONFLICT` | conflicts worker → push worker |
| `CI_FAILED` | ci worker (one run covers every failing check on that head) → push worker. `attempt=N` is how many heads in a row the check has failed on: pass the earlier attempts' SUMMARY/DETAILS from the log so the worker does not repeat a dead end |
| `NEW_REVIEW`, `NEW_REPLY` / `NEW_COMMENT` that ask for a change, `UNANSWERED_THREADS`, `UNANSWERED_REVIEWS` | review-fix worker (see the flow below). `UNANSWERED_REVIEWS` = reviews with a body (or CHANGES_REQUESTED) posted before the watch started that you never answered; they often have no inline threads |
| `NEW_REPLY` / `NEW_COMMENT` that is just an acknowledgment | log only |
| `DECISION … CHANGES_REQUESTED` | log; the matching `NEW_REVIEW` drives the work |
| `APPROVAL_LOST approvers=a,b` | `dm --to <each approver> "<url> this needs another approval"` |
| `REVIEW_REQUEST_SENT to=x rereview=true` | `dm --to x "<url> needs a re-review"` |
| `REVIEW_REQUEST_SENT to=x rereview=false` | `dm --to x "<url> ready for review"` |
| `READY_TO_MERGE` | DM self `<url> ready to merge` + push notify. Never merge |
| `CI_GREEN` | log only |

**Review-fix flow.** Every unresolved comment gets addressed, nit to critical. Nothing is skipped and nothing waits for the user:
1. **Worker pass 1:** fixes every unresolved thread and change-request comment at every severity (LOW, SEMANTIC, MEDIUM, HIGH, CRITICAL), commits, returns `ready-to-push`. It does not reply on GitHub yet.
2. **Push worker.**
3. **Worker pass 2** (`SendMessage` with the new SHA): replies on every thread with what changed + resolves it, and posts one PR comment per review body it addressed (fix-pr-review Phase 6, incl. 6.5). It returns the reviewers whose threads or reviews it handled. A review counts as answered once you comment on the PR or re-request that reviewer after it, or every thread it opened is resolved.
4. **Re-request on GitHub:** `gh pr edit N --add-reviewer <them>`. Then `dm --to <each> "<url> needs a re-review"` directly, because GitHub may not log a new request for someone already listed. The `dm` dedupe stops the later `REVIEW_REQUEST_SENT` from sending it twice.

**Pre-push hook failures:** the push worker returns the hook output verbatim. Dispatch a ci worker with that output as the failure source, then push again. Repeat until the push lands.

**Approved, then conflicts:** `CONFLICT` → fix + push → if the repo dismisses stale approvals, the next poll emits `APPROVAL_LOST` → DM the approvers `<url> this needs another approval`.

---

## Reviewer playbook

| Event | Action |
|-------|--------|
| `ADDRESS_CHECK_DUE` | address-check worker (it approves, holds, or posts findings itself). `my_review=APPROVED/DISMISSED` means you had approved and new commits landed (CI fix, conflict fix, anything): the worker runs in **re-check mode** |
| `CONFLICT` | `dm --to <author> "<url> has merge conflicts"` (they are responsible) |
| `CI_FAILED` (one batch per head) | `dm --to <author> "<url> CI failing: <checks>"` |
| `CI_GREEN` | if the log has `held head=<this head>` from an address check → approve worker for that head; else log only |
| worker `RESULT: held` | log `held head=<H> reason=<conflict\|ci>`. If the matching `CONFLICT` / `CI_FAILED` DM was not sent yet, send it now (dedupe makes it safe) |
| `MY_REVIEW_POSTED state=APPROVED` | `dm --to <author> "<url> approved"` |
| `MY_REVIEW_POSTED first=true` (not approved) | `dm --to <author> "<url> left a review"` |
| `MY_REVIEW_POSTED first=false` (not approved) | `dm --to <author> "<url> more findings"` |
| `AWAITING_MY_REVIEW`, `REVIEW_REQUESTED` | DM self `<url> waiting on your review` + push notify. Do not auto-review |
| `NEW_COMMITS`, `AUTHOR_REPLIED`, `MY_THREAD_RESOLVED`, `RE_REQUESTED` | log only; the script turns these into `ADDRESS_CHECK_DUE` once activity settles (one quiet poll) or right away on re-request |

`MY_REVIEW_POSTED` fires for any review you submit, whether the worker posted it or you did by hand, so the author always gets one DM per review.

---

## Both roles

| Event | Action |
|-------|--------|
| `PR_MERGED` / `PR_CLOSED` | Automatic teardown (below) |
| `READY_FOR_REVIEW` | log only |
| `WATCH_ERROR` | DM self `<url> watcher error: <msg>` + push notify. `fatal=true` means the script needs fixing: do not re-arm blindly |
| `WATCH_LIMIT` | tell the user the page limit was hit (events there may be missed) |
| `WATCH_RECOVERED` | log only |

**Teardown on merge/close.** Automatic, no confirmation:
1. **Stop the watch.** The Monitor script exits by itself after `PR_MERGED` / `PR_CLOSED`; do not re-arm. TaskStop any worker still running for this PR.
2. **Leave the worktree.** If this session's cwd is inside the worktree, move out first: `ExitWorktree` with `action: "keep"` if it was entered that way, else run everything from the primary checkout with absolute paths.
3. **Destroy it (Haiku teardown worker).** Owned and reused worktrees alike. The **only** exception is work that would be lost:
   - Keep it if `git -C <WT> status --porcelain` is non-empty, or `git -C <WT> log --oneline HEAD --not --remotes` lists commits. Then DM self `<url> merged, kept <WT>: uncommitted/unpushed work` with the list.
   - Never pass `--force`. Never touch the primary checkout.
   - How to destroy, by worktree type:

     | Worktree | Command |
     |---|---|
     | quick (`*-quick-*` dir or quick marker) | `~/.ai/oc_skills/worktree-quick/scripts/quick-worktree.sh destroy --path <WT> --yes` |
     | slot (`.worktree-slot` file) | `~/.ai/oc_skills/monorepo-worktree/scripts/destroy-worktree.sh --path <WT> --yes` (also drops its DB + Redis slot) |
     | anything else | `git -C <primary> worktree remove <WT>` |
4. **Clean up.** `$W reset` (drop state; keep the log). No DM: tell the user in this session only.

**Slack voice:** the user's own words, one line: `<url> approved`, `<url> needs a re-review`, `<url> more findings`, `<url> this needs another approval`. No greetings, no summaries.

**Messaging the user (DM self + PushNotification): only when the watcher needs something from them.** Progress, fixes pushed, approvals, holds, merges are all logged only; the user asks this session when they want to know. The complete list:
- unmapped login (`USER_NOT_MAPPED`)
- a safety stop: uncommitted changes, unpushed local commits, or a diverged branch in the worktree
- an environment failure: Docker, gh/git auth, network
- `WATCH_ERROR`
- merged, but the worktree was kept because it holds unsaved work
- `READY_TO_MERGE` (only you merge)
- `AWAITING_MY_REVIEW` / `REVIEW_REQUESTED` (the first review is yours)

One message per blocker, deduped; not again until it changes.

---

## Worker prompts

Every worker is a background `general-purpose` subagent. Code workers use the session model; push / setup / teardown use `model: "haiku"`. Every prompt includes this preamble with the values filled in:

```
PR #<N> (<url>) in <REPO>. Head branch <headRef>, base <baseRef>. Role: <role>.
Worktree: <WT> (owned=<true|false>; false = the user's own worktree). Work ONLY there: `cd <WT> && …` on every Bash command, or absolute paths.
Before starting, sync without ever discarding work: `git -C <WT> fetch origin <headRef>`, then
  - uncommitted changes → stop, RESULT: failed, "worktree has uncommitted changes" (never stash/reset the user's edits)
  - HEAD == FETCH_HEAD → go
  - HEAD is an ancestor of FETCH_HEAD → `git -C <WT> merge --ff-only FETCH_HEAD`
  - FETCH_HEAD is an ancestor of HEAD (local commits not pushed yet) → stop, RESULT: needs-decision, list them (`git log FETCH_HEAD..HEAD --oneline`); never push or drop them on your own
  - diverged → stop, RESULT: failed, show both SHAs
  Never `reset --hard`, never `checkout` another branch, never `clean`.
Log progress at each phase: `python3 ~/.ai/skills/watch-pr/scripts/watch_pr.py log --repo <REPO> --pr <N> --who worker:<kind> "<one line>"`.
Never ask the user. If a decision is needed, stop and return RESULT: needs-decision with numbered options.
No attempt caps: keep iterating inside this run until the fix is in, unless the failure is environmental (Docker, auth, network); then return RESULT: failed with the verbatim error.
<if a retry: "Earlier attempts on this problem (do not repeat them):" + their SUMMARY/DETAILS>.
Never push (unless you are the push worker), never --no-verify, never touch <baseRef>/main, never merge the PR.
Follow ~/.claude/CLAUDE.md rules (fail hard, hard types, no soft fallbacks).
End with exactly:
RESULT: ready-to-push | pushed | no-change | needs-decision | approved | held | commented | failed
SUMMARY: <1-3 lines>
DETAILS: <whatever the dispatcher needs: files, SHAs, reviewers, numbered decisions, verbatim errors>
```

| Kind | Model | Task |
|------|-------|------|
| `conflicts` | session | Read `~/.claude/commands/fix-merge-conflicts.md` and follow it from Phase 1. Skip Phase 0: the worktree is given. Merge `origin/<baseRef>`, complete the merge commit, do not push. |
| `ci` | session | Read `~/.ai/skills/fix-ci/SKILL.md` and follow it from Phase 1 (skip Phase 0). Use `<headRef>` for `gh run list --branch`. Given hook output instead of a CI run, fix from that. Commit, do not push. |
| `review-fix` | session | Read `~/.ai/skills/fix-pr-review/SKILL.md`, follow from Phase 1 (skip Phase 0). **Override its Phase 5: no severity gets presented or skipped.** Implement the fix for every item, CRITICAL/HIGH/MEDIUM included, the same way it auto-fixes LOW/SEMANTIC. Change the code for every comment. The only exceptions: a question gets an answer, and a suggestion that is technically wrong (it would break behavior or contradict the PR's purpose) gets an in-thread reply with the concrete reason. Never a silent skip, never "out of scope". Commit, return `ready-to-push`. Do not reply or resolve on GitHub until resumed with the pushed SHA. |
| `push` | haiku | `git -C <WT> push origin HEAD:refs/heads/<headRef>`. Wait for the pre-push hook (minutes). Return the new SHA, or the hook/push error verbatim. Do not fix code. Non-fast-forward → return it (dispatcher re-syncs). |
| `address-check` | session | The procedure below. |
| `approve` | haiku | Only if `gh pr view N --json headRefOid` is still `<H>` and nothing is conflicting/failing: `gh api repos/<REPO>/pulls/<N>/reviews -X POST -f commit_id=<H> -f event=APPROVE -f body="still good, CI green"`. Head moved or not green → `RESULT: no-change` (the next check covers it). |
| `teardown` | haiku | Teardown steps 3–4 above. |

---

## Address check (reviewer worker)

Input from the event: `review_commit` (R, the commit your last review was on), `head` (H), and `my_review`. **Re-check mode** = `my_review` is `APPROVED` or `DISMISSED`: you had approved, and new commits landed after it. `main` dismisses approvals on every push, so it shows up as `DISMISSED`.

1. **Sync** the worktree to H (preamble). `git -C <WT> cat-file -e R || git -C <WT> fetch origin R`.
2. **Threads:** `$W threads --repo <REPO> --pr <N> --started-by @me`. Work on the unresolved ones plus any resolved since the review (they still need a verdict). In re-check mode there are usually none; the delta review is the whole job.
3. **Delta = the author's work since R:**
   - Own commits: `git log --no-merges --format='%H %cI %an %s' R..H` and `git log -p --no-merges R..H`.
   - Merges from base: `git log --merges --format=%H R..H`, then `git show --remerge-diff <sha>` for each. That shows only how the conflicts were resolved, which is the author's work and must be reviewed. The rest of base's changes are not.
   - If R is not an ancestor of H (force-push): compare `git diff R H -- $(gh pr diff N --name-only)` and say so in DETAILS.
4. **No response yet → stop** (not in re-check mode): no commit in R..H has a committer date after your review, and no reply from someone else on your threads after it → `RESULT: no-change`, SUMMARY `no response to the review yet`. Post nothing. In re-check mode any new commit is what you are checking, so always continue.
5. **Verdict per thread**, read against the code at H, the delta, and the author's replies:
   - `ADDRESSED`: fixed, and fixed properly. A band-aid that breaks the CLAUDE.md rules (`?? ''`, swallowed catch, `as any`) is `PARTIAL`.
   - `ADDRESSED_DIFFERENTLY`: a different fix, sound, and explained or self-evident.
   - `PUSHED_BACK_OK`: the author explained why not, and the reason holds against the code (or a follow-up issue is linked).
   - `PUSHED_BACK_WEAK`: the reason does not hold or does not answer the concern.
   - `PARTIAL` / `NOT_ADDRESSED`: no change and no answer, or only part of it.
   - More than 15 threads: group them by file and run the groups as parallel subagents if you have the Agent tool (each returns `{threadId, verdict, why}` JSON). Otherwise work through the files in order.
6. **New findings in the delta only:** use the `/pr-review-light` concerns (read `~/.ai/skills/pr-review-light/SKILL.md` for the rubric: security, silent failure / soft types, R1–R9, tests, dead code). Flag only problems the new commits introduced. Each finding gets severity, path, and a line that exists on the RIGHT side of `gh pr diff N` at H; otherwise it goes in the review body.
   - **Re-reviews post MEDIUM and up only.** LOW findings and nits (style, naming, unused import, tiny dead local) are never posted: not as inline comments, not in the review body, not as thread replies. List them under `DETAILS: unposted LOW:` so the user can ask about them; nothing else.
7. **Decide.** The code is *good* when every thread (nits included) is `ADDRESSED` / `ADDRESSED_DIFFERENTLY` / `PUSHED_BACK_OK` and there are **zero** new CRITICAL/HIGH/MEDIUM findings. Unposted LOW/nit findings never block approval. Then read the PR's health at H (`gh pr view N --json mergeable,statusCheckRollup,reviewDecision`):
   - **Code not good → COMMENT** (re-check mode too). Mention a conflict or failing CI in the body. Never `REQUEST_CHANGES` unless the user's earlier review on this PR used it.
   - **Code good, but the PR conflicts, or any check on H is failing or still pending → `RESULT: held`.** Post nothing. DETAILS: `held head=<H> reason=conflict|ci`. Fixing a conflict or failing CI takes a push, which dismisses any approval anyway. The dispatcher DMs the author, and the approval follows from the next check or from `CI_GREEN`.
   - **Code good, no conflict, every check green (or none) → APPROVE.** In re-check mode the body is `still good after <short H>`. Exception: your approval is still standing (`my_review=APPROVED` and `reviewDecision=APPROVED`, i.e. nothing dismissed it). Then post nothing: `RESULT: no-change`, SUMMARY `still good`.
8. **Post**, in this order, everything against commit H:
   1. `ADDRESSED` → resolve the thread.
   2. `ADDRESSED_DIFFERENTLY` / `PUSHED_BACK_OK` → short reply (`makes sense`) + resolve.
   3. `PARTIAL` / `NOT_ADDRESSED` / `PUSHED_BACK_WEAK` → reply with what is still missing, leave it open.
   4. Then **one** review: `gh api repos/<REPO>/pulls/<N>/reviews -X POST --input <json>` with `commit_id=H`, `event=APPROVE|COMMENT`, a one-line `body`, and `comments[]` = new MEDIUM+ findings `{path, line, side:"RIGHT", body}`.
   - Thread replies use the GraphQL `addPullRequestReviewThreadReply(pullRequestReviewThreadId, body)`; resolving uses `resolveReviewThread(threadId)`.
   - Finding style matches the user's existing comments, e.g. `**[HIGH] SilentFailure:** <problem>. <fix>.` Short, no AI filler.
   - The review must have a body so the watcher sees it as a real review. Do not DM: the watcher's `MY_REVIEW_POSTED` drives the DM.
9. **Return** `RESULT: approved | held | commented | no-change`. SUMMARY gives counts (`38/42 addressed, 2 pushed back ok, 2 still open, 1 new HIGH, 3 LOW unposted`). DETAILS has a verdict table (thread URL, verdict, one-line why) plus the unposted LOW list.

---

## Guardrails

- The script ignores your own pushes, comments, and replies, so the watcher never triggers itself. Bots' PR comments are ignored; bot *reviews* count.
- A lone thread reply is not a review (GitHub wraps every reply in a review object), so it does not count as "you reviewed", and in author mode it is reported as `NEW_REPLY`.
- Re-request = a `ReviewRequestedEvent` for you **after** your last real review. Being on the requested list means nothing, because a COMMENTED review does not clear it.
- A dismissed approval still counts as your last review, so the re-check diffs from the approval commit, not from an older review.
- Reviewer mode reports only *new* conflicts and CI failures. Breakage that was already there when the watch started is not DMed.
- Commits are compared by SHA, never by timestamp, except in the address check's no-response rule, which only *suppresses* posting.
- `mergeable=UNKNOWN` (GitHub still computing) keeps the last known value; it never clears or re-fires CONFLICT.
- Silence means quiet: three `gh` failures in a row emit `WATCH_ERROR`; an unknown response shape exits with `fatal=true`.
- Tests: `python3 -m unittest discover -s ~/.ai/skills/watch-pr/tests` (pure diff logic, no network). Live dry run: `$W once --repo R --pr N --state-dir <scratch dir>`.
- Sessions only: the watch ends when this Claude session closes. Re-running `/watch-pr N` later resumes from the saved state without repeating old events.
````

#### `~/.ai/skills/watch-pr/scripts/watch_pr.py`

```python file=~/.ai/skills/watch-pr/scripts/watch_pr.py mode=755
#!/usr/bin/env python3
"""Poll one GitHub PR, diff against the last saved snapshot, print one line per event.

Deterministic on purpose: no LLM runs here. The /watch-pr skill streams `watch`
stdout through Monitor so the agent only wakes when something changed.

Subcommands:
  watch    poll forever (every --interval s), print events; exits on merge/close
  once     one poll + diff (live dry run); --no-save keeps state untouched
  status   fresh snapshot summary + recent activity log (answer "what's going on")
  threads  review threads with bodies (input for the reviewer address check)
  log      append a line to the PR activity log (dispatcher + workers)
  dm       Slack-DM a GitHub user (or @me), deduped against the activity log
  reset    forget saved state (next poll is a baseline)

Event line format:  KIND pr=N key=value ... | human text
"""
from __future__ import annotations

import argparse
import json
import os
import subprocess
import sys
import time
from dataclasses import asdict, dataclass, field
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Dict, List, Optional, Tuple

ROLES = ("author", "reviewer")
GH_ERROR_ALERT_AFTER = 3
DEFAULT_INTERVAL_S = 300
DEFAULT_STATE_DIR = Path(os.environ.get("WATCH_PR_STATE_DIR", Path.home() / ".cache" / "watch-pr"))

CHECK_FAIL_CONCLUSIONS = {"FAILURE", "TIMED_OUT", "CANCELLED", "ACTION_REQUIRED", "STARTUP_FAILURE", "STALE"}
CHECK_PASS_CONCLUSIONS = {"SUCCESS", "NEUTRAL"}
CHECK_SKIP_CONCLUSIONS = {"SKIPPED"}
STATUS_FAIL_STATES = {"FAILURE", "ERROR"}
STATUS_PENDING_STATES = {"PENDING", "EXPECTED"}
DECISIVE_REVIEW_STATES = {"APPROVED", "CHANGES_REQUESTED", "DISMISSED"}  # DISMISSED = stale approval after a push
ANSWERABLE_REVIEW_STATES = {"CHANGES_REQUESTED", "COMMENTED"}  # a latest review in these states wants an answer
GHOST_LOGIN = "ghost"  # GitHub's name for a deleted account
SLACK_POST = Path.home() / ".ai" / "skills" / "slack" / "scripts" / "slack-post.py"
PEOPLE_FILE = Path(os.environ.get("WATCH_PR_PEOPLE", Path.home() / ".config" / "watch-pr" / "people.json"))
DM_DEDUPE_WINDOW_S = 30 * 60


class GhError(Exception):
    """gh/network failure. Transient: the watch loop retries."""


class ParseError(Exception):
    """GitHub returned a shape we do not understand. Fatal: fix the script."""


# ---------------------------------------------------------------- model


@dataclass
class Check:
    name: str
    bucket: str  # pass | fail | pending | skip
    detail: str


@dataclass
class Review:
    id: str
    author: str
    is_bot: bool
    state: str
    submitted_at: str
    commit_oid: Optional[str]  # None when the reviewed commit was force-pushed away
    has_body: bool


@dataclass
class ThreadComment:
    id: str
    author: str
    created_at: str
    review_id: Optional[str]
    is_reply: bool


@dataclass
class Thread:
    id: str
    path: str
    line: Optional[int]  # None once outdated
    is_resolved: bool
    resolved_by: Optional[str]
    is_outdated: bool
    started_by: str
    comments: List[ThreadComment]


@dataclass
class IssueComment:
    id: str
    author: str
    is_bot: bool
    created_at: str


@dataclass
class ReviewRequest:
    reviewer: str
    requested_by: str
    created_at: str


@dataclass
class Snapshot:
    me: str
    number: int
    url: str
    title: str
    author: str
    state: str  # OPEN | CLOSED | MERGED
    is_draft: bool
    is_cross_repo: bool
    mergeable: str  # MERGEABLE | CONFLICTING | UNKNOWN
    merge_state: str
    review_decision: Optional[str]
    head_ref: str
    base_ref: str
    head_oid: str
    head_author: Optional[str]  # None when the commit email is not linked to a GitHub user
    checks: List[Check]
    reviews: List[Review]
    threads: List[Thread]
    issue_comments: List[IssueComment]
    review_requests: List[ReviewRequest]
    truncated: List[str]


@dataclass
class State:
    role: str
    snapshot: Snapshot
    known_mergeable: str  # last non-UNKNOWN mergeable value
    fail_streaks: Dict[str, List[str]] = field(default_factory=dict)  # check -> head shas it failed on, in a row
    activity_key: Optional[str] = None  # reviewer: head + latest reply seen last poll
    check_due_key: Optional[str] = None  # reviewer: activity key ADDRESS_CHECK_DUE last fired for


# ---------------------------------------------------------------- parsing (boundary)


def req(obj: Any, key: str, where: str) -> Any:
    if not isinstance(obj, dict) or key not in obj:
        raise ParseError(f"missing {where}.{key}")
    return obj[key]


def login_of(actor: Any) -> str:
    if actor is None:
        return GHOST_LOGIN
    return str(req(actor, "login", "actor"))


def is_bot(actor: Any) -> bool:
    return actor is not None and req(actor, "__typename", "actor") == "Bot"


def truncated_if(conn: Any, name: str, direction: str, out: List[str]) -> None:
    info = req(conn, "pageInfo", name)
    if req(info, direction, f"{name}.pageInfo"):
        out.append(name)


SNAPSHOT_QUERY = """
query($owner: String!, $name: String!, $number: Int!) {
  viewer { login }
  repository(owner: $owner, name: $name) {
    pullRequest(number: $number) {
      number url title state isDraft isCrossRepository mergeable mergeStateStatus reviewDecision
      headRefName baseRefName headRefOid
      author { login __typename }
      commits(last: 1) { nodes { commit {
        oid
        author { user { login } }
        statusCheckRollup { contexts(first: 100) {
          pageInfo { hasNextPage }
          nodes {
            __typename
            ... on CheckRun { name status conclusion startedAt }
            ... on StatusContext { context state createdAt }
          }
        } }
      } } }
      reviews(last: 100) {
        pageInfo { hasPreviousPage }
        nodes { id state submittedAt body author { login __typename } commit { oid } }
      }
      reviewThreads(first: 100) {
        pageInfo { hasNextPage }
        nodes {
          id path line isResolved isOutdated resolvedBy { login }
          comments(first: 100) {
            pageInfo { hasNextPage }
            nodes { id createdAt author { login __typename } replyTo { id } pullRequestReview { id } }
          }
        }
      }
      comments(last: 100) {
        pageInfo { hasPreviousPage }
        nodes { id createdAt author { login __typename } }
      }
      timelineItems(last: 50, itemTypes: [REVIEW_REQUESTED_EVENT]) {
        nodes { ... on ReviewRequestedEvent {
          createdAt actor { login }
          requestedReviewer { __typename ... on User { login } }
        } }
      }
    }
  }
}
"""

THREADS_QUERY = """
query($owner: String!, $name: String!, $number: Int!) {
  repository(owner: $owner, name: $name) {
    pullRequest(number: $number) {
      reviewThreads(first: 100) {
        pageInfo { hasNextPage }
        nodes {
          id path line originalLine isResolved isOutdated resolvedBy { login }
          comments(first: 100) {
            nodes {
              id databaseId url body createdAt
              author { login }
              replyTo { id }
              diffHunk
              commit { oid }
              originalCommit { oid }
            }
          }
        }
      }
    }
  }
}
"""


def bucket_check_run(node: Dict[str, Any]) -> Check:
    name = str(req(node, "name", "CheckRun"))
    status = str(req(node, "status", "CheckRun"))
    conclusion = req(node, "conclusion", "CheckRun")
    if status != "COMPLETED" or conclusion is None:
        return Check(name, "pending", status)
    if conclusion in CHECK_FAIL_CONCLUSIONS:
        return Check(name, "fail", conclusion)
    if conclusion in CHECK_PASS_CONCLUSIONS:
        return Check(name, "pass", conclusion)
    if conclusion in CHECK_SKIP_CONCLUSIONS:
        return Check(name, "skip", conclusion)
    raise ParseError(f"unknown CheckRun conclusion {conclusion!r} on {name}")


def bucket_status_context(node: Dict[str, Any]) -> Check:
    name = str(req(node, "context", "StatusContext"))
    state = str(req(node, "state", "StatusContext"))
    if state == "SUCCESS":
        return Check(name, "pass", state)
    if state in STATUS_FAIL_STATES:
        return Check(name, "fail", state)
    if state in STATUS_PENDING_STATES:
        return Check(name, "pending", state)
    raise ParseError(f"unknown StatusContext state {state!r} on {name}")


def parse_checks(commit: Dict[str, Any], truncated: List[str]) -> List[Check]:
    rollup = req(commit, "statusCheckRollup", "commit")
    if rollup is None:
        return []
    contexts = req(rollup, "contexts", "statusCheckRollup")
    truncated_if(contexts, "checks", "hasNextPage", truncated)
    # Re-runs report the same name more than once: pending wins, else the latest start.
    latest: Dict[str, Tuple[str, Check]] = {}
    for node in req(contexts, "nodes", "contexts"):
        kind = req(node, "__typename", "context")
        if kind == "CheckRun":
            check, at = bucket_check_run(node), str(req(node, "startedAt", "CheckRun") or "")
        elif kind == "StatusContext":
            check, at = bucket_status_context(node), str(req(node, "createdAt", "StatusContext"))
        else:
            raise ParseError(f"unknown check context type {kind!r}")
        seen = latest.get(check.name)
        if seen is None or seen[1].bucket != "pending" and (check.bucket == "pending" or at > seen[0]):
            latest[check.name] = (at, check)
    return sorted((c for _, c in latest.values()), key=lambda c: c.name)


def parse_snapshot(data: Dict[str, Any]) -> Snapshot:
    me = login_of(req(data, "viewer", "data"))
    pr = req(req(data, "repository", "data"), "pullRequest", "repository")
    if pr is None:
        raise ParseError("pull request not found")
    truncated: List[str] = []

    commits = req(req(pr, "commits", "pr"), "nodes", "commits")
    if len(commits) != 1:
        raise ParseError(f"expected 1 head commit, got {len(commits)}")
    commit = req(commits[0], "commit", "commits")
    head_user = req(req(commit, "author", "commit"), "user", "commit.author")

    reviews_conn = req(pr, "reviews", "pr")
    truncated_if(reviews_conn, "reviews", "hasPreviousPage", truncated)
    reviews = [
        Review(
            id=str(req(n, "id", "review")),
            author=login_of(req(n, "author", "review")),
            is_bot=is_bot(req(n, "author", "review")),
            state=str(req(n, "state", "review")),
            submitted_at=str(req(n, "submittedAt", "review")),
            commit_oid=None if req(n, "commit", "review") is None else str(req(n["commit"], "oid", "review.commit")),
            has_body=bool(str(req(n, "body", "review")).strip()),
        )
        for n in req(reviews_conn, "nodes", "reviews")
        if req(n, "state", "review") != "PENDING"  # your own unsubmitted draft
    ]

    threads_conn = req(pr, "reviewThreads", "pr")
    truncated_if(threads_conn, "reviewThreads", "hasNextPage", truncated)
    threads: List[Thread] = []
    for t in req(threads_conn, "nodes", "reviewThreads"):
        comments_conn = req(t, "comments", "thread")
        truncated_if(comments_conn, "threadComments", "hasNextPage", truncated)
        comments = [
            ThreadComment(
                id=str(req(c, "id", "comment")),
                author=login_of(req(c, "author", "comment")),
                created_at=str(req(c, "createdAt", "comment")),
                review_id=None if req(c, "pullRequestReview", "comment") is None else str(c["pullRequestReview"]["id"]),
                is_reply=req(c, "replyTo", "comment") is not None,
            )
            for c in req(comments_conn, "nodes", "comments")
        ]
        if not comments:
            raise ParseError(f"thread {t.get('id')} has no comments")
        resolved_by = req(t, "resolvedBy", "thread")
        threads.append(
            Thread(
                id=str(req(t, "id", "thread")),
                path=str(req(t, "path", "thread")),
                line=req(t, "line", "thread"),
                is_resolved=bool(req(t, "isResolved", "thread")),
                resolved_by=None if resolved_by is None else login_of(resolved_by),
                is_outdated=bool(req(t, "isOutdated", "thread")),
                started_by=comments[0].author,
                comments=comments,
            )
        )

    issue_conn = req(pr, "comments", "pr")
    truncated_if(issue_conn, "comments", "hasPreviousPage", truncated)
    issue_comments = [
        IssueComment(
            id=str(req(n, "id", "issueComment")),
            author=login_of(req(n, "author", "issueComment")),
            is_bot=is_bot(req(n, "author", "issueComment")),
            created_at=str(req(n, "createdAt", "issueComment")),
        )
        for n in req(issue_conn, "nodes", "comments")
    ]

    review_requests: List[ReviewRequest] = []
    for n in req(req(pr, "timelineItems", "pr"), "nodes", "timelineItems"):
        reviewer = req(n, "requestedReviewer", "ReviewRequestedEvent")
        if reviewer is None or req(reviewer, "__typename", "requestedReviewer") != "User":
            continue  # team requests are not a personal re-request
        review_requests.append(
            ReviewRequest(
                reviewer=login_of(reviewer),
                requested_by=login_of(req(n, "actor", "ReviewRequestedEvent")),
                created_at=str(req(n, "createdAt", "ReviewRequestedEvent")),
            )
        )

    return Snapshot(
        me=me,
        number=int(req(pr, "number", "pr")),
        url=str(req(pr, "url", "pr")),
        title=str(req(pr, "title", "pr")),
        author=login_of(req(pr, "author", "pr")),
        state=str(req(pr, "state", "pr")),
        is_draft=bool(req(pr, "isDraft", "pr")),
        is_cross_repo=bool(req(pr, "isCrossRepository", "pr")),
        mergeable=str(req(pr, "mergeable", "pr")),
        merge_state=str(req(pr, "mergeStateStatus", "pr")),
        review_decision=req(pr, "reviewDecision", "pr"),
        head_ref=str(req(pr, "headRefName", "pr")),
        base_ref=str(req(pr, "baseRefName", "pr")),
        head_oid=str(req(pr, "headRefOid", "pr")),
        head_author=None if head_user is None else login_of(head_user),
        checks=parse_checks(commit, truncated),
        reviews=reviews,
        threads=threads,
        issue_comments=issue_comments,
        review_requests=review_requests,
        truncated=truncated,
    )


def snapshot_from_dict(d: Dict[str, Any]) -> Snapshot:
    return Snapshot(
        **{
            **d,
            "checks": [Check(**c) for c in d["checks"]],
            "reviews": [Review(**r) for r in d["reviews"]],
            "threads": [
                Thread(**{**t, "comments": [ThreadComment(**c) for c in t["comments"]]}) for t in d["threads"]
            ],
            "issue_comments": [IssueComment(**c) for c in d["issue_comments"]],
            "review_requests": [ReviewRequest(**r) for r in d["review_requests"]],
        }
    )


def state_from_dict(d: Dict[str, Any]) -> State:
    return State(**{**d, "snapshot": snapshot_from_dict(d["snapshot"])})


# ---------------------------------------------------------------- gh


def gh(args: List[str]) -> str:
    try:
        proc = subprocess.run(
            ["gh", *args], capture_output=True, text=True, timeout=90, env={**os.environ, "NO_COLOR": "1"}
        )
    except subprocess.TimeoutExpired as exc:
        raise GhError(f"gh timed out: {' '.join(args[:3])}") from exc
    if proc.returncode != 0:
        raise GhError(proc.stderr.strip() or f"gh exited {proc.returncode}")
    return proc.stdout


def gh_graphql(query: str, owner: str, name: str, number: int) -> Dict[str, Any]:
    out = gh(["api", "graphql", "-f", f"query={query}", "-f", f"owner={owner}", "-f", f"name={name}", "-F", f"number={number}"])
    try:
        payload = json.loads(out)
    except json.JSONDecodeError as exc:
        raise GhError(f"gh returned non-JSON: {out[:200]}") from exc
    if "errors" in payload:
        raise GhError(json.dumps(payload["errors"])[:500])
    return req(payload, "data", "graphql")


def fetch_snapshot(repo: str, number: int) -> Snapshot:
    owner, name = split_repo(repo)
    return parse_snapshot(gh_graphql(SNAPSHOT_QUERY, owner, name, number))


def split_repo(repo: str) -> Tuple[str, str]:
    parts = repo.split("/")
    if len(parts) != 2 or not all(parts):
        raise SystemExit(f"--repo must be owner/name, got {repo!r}")
    return parts[0], parts[1]


# ---------------------------------------------------------------- diff (pure)


def ev(kind: str, snap: Snapshot, text: str, **kv: Any) -> str:
    fields = " ".join(f"{k}={v}" for k, v in kv.items() if v is not None)
    return f"{kind} pr={snap.number}{' ' + fields if fields else ''} | {text}"


def short(oid: Optional[str]) -> str:
    return oid[:8] if oid else "none"


def substantive_review_ids(snap: Snapshot) -> set:
    """Reviews that are a real review pass, not a lone thread reply (GitHub wraps every reply in a review)."""
    opened_threads = {c.review_id for t in snap.threads for c in t.comments if not c.is_reply and c.review_id}
    return {r.id for r in snap.reviews if r.state in DECISIVE_REVIEW_STATES or r.has_body or r.id in opened_threads}


def last_review_by(snap: Snapshot, login: str) -> Optional[Review]:
    ids = substantive_review_ids(snap)
    mine = [r for r in snap.reviews if r.author == login and r.id in ids]
    return max(mine, key=lambda r: r.submitted_at) if mine else None


def latest_reviews(snap: Snapshot) -> Dict[str, Review]:
    ids = substantive_review_ids(snap)
    out: Dict[str, Review] = {}
    for r in sorted(snap.reviews, key=lambda r: r.submitted_at):
        if r.id in ids:
            out[r.author] = r
    return out


def unanswered_reviews(snap: Snapshot) -> List[Review]:
    """Each other reviewer's latest review that asks for something you have not answered yet.

    Only reviews with a body (or CHANGES_REQUESTED): thread-only reviews are covered by their threads.
    Answered = you commented on the PR or re-requested that reviewer after it (the review-fix flow does
    both), or every thread it opened is resolved.
    """
    me = snap.me
    out: List[Review] = []
    for author, r in latest_reviews(snap).items():
        if author == me or r.state not in ANSWERABLE_REVIEW_STATES:
            continue
        if not r.has_body and r.state != "CHANGES_REQUESTED":
            continue
        opened = [t for t in snap.threads if t.comments[0].review_id == r.id]
        if opened and all(t.is_resolved for t in opened):
            continue
        if any(c.author == me and c.created_at > r.submitted_at for c in snap.issue_comments):
            continue
        if any(q.requested_by == me and q.reviewer == author and q.created_at > r.submitted_at for q in snap.review_requests):
            continue
        out.append(r)
    return sorted(out, key=lambda r: r.submitted_at)


def all_green(checks: List[Check]) -> bool:
    return bool(checks) and all(c.bucket in ("pass", "skip") for c in checks)


def ready_to_merge(snap: Snapshot) -> bool:
    return snap.state == "OPEN" and not snap.is_draft and snap.merge_state == "CLEAN" and snap.review_decision in ("APPROVED", None)


def baseline_line(snap: Snapshot, role: str) -> str:
    counts: Dict[str, int] = {}
    for c in snap.checks:
        counts[c.bucket] = counts.get(c.bucket, 0) + 1
    checks = ",".join(f"{k}:{v}" for k, v in sorted(counts.items())) or "none"
    open_threads = sum(1 for t in snap.threads if not t.is_resolved)
    return ev(
        "BASELINE",
        snap,
        f"watching as {role}: {snap.title}",
        role=role,
        state=snap.state,
        mergeable=snap.mergeable,
        merge_state=snap.merge_state,
        decision=snap.review_decision,
        head=short(snap.head_oid),
        checks=checks,
        open_threads=open_threads,
    )


def update_fail_streaks(prev: Dict[str, List[str]], cur: Snapshot) -> Dict[str, List[str]]:
    out: Dict[str, List[str]] = {}
    for check in cur.checks:
        streak = list(prev.get(check.name, []))
        if check.bucket == "fail":
            if cur.head_oid not in streak:
                streak.append(cur.head_oid)
            out[check.name] = streak
        elif check.bucket == "pending" and streak:
            out[check.name] = streak
    return out


def health_events(prev: Optional[State], cur: Snapshot, state: State) -> List[str]:
    """Merge conflicts and failing checks on the current head, each reported once."""
    events: List[str] = []
    p = prev.snapshot if prev else None
    was_conflicting = prev is not None and prev.known_mergeable == "CONFLICTING"
    if state.known_mergeable == "CONFLICTING" and not was_conflicting:
        events.append(ev("CONFLICT", cur, f"{cur.head_ref} conflicts with {cur.base_ref}", merge_state=cur.merge_state))

    prev_fail = {c.name for c in p.checks if c.bucket == "fail"} if p and p.head_oid == cur.head_oid else set()
    for check in cur.checks:
        if check.bucket == "fail" and check.name not in prev_fail:
            attempt = len(state.fail_streaks.get(check.name, []))
            events.append(ev("CI_FAILED", cur, f"{check.name} {check.detail}", sha=short(cur.head_oid), check=check.name, attempt=attempt))

    if p is not None and all_green(cur.checks) and not (p.head_oid == cur.head_oid and all_green(p.checks)):
        events.append(ev("CI_GREEN", cur, "all checks passed", sha=short(cur.head_oid)))
    return events


def author_events(prev: Optional[State], cur: Snapshot, state: State) -> List[str]:
    me = cur.me
    p = prev.snapshot if prev else None
    events = health_events(prev, cur, state)  # baseline included: you own fixing them


    prev_review_ids = {r.id for r in p.reviews} if p else set()
    substantive = substantive_review_ids(cur)
    new_reviews = [r for r in cur.reviews if r.id not in prev_review_ids and r.author != me and r.id in substantive]
    if p is not None:
        for r in new_reviews:
            opened = sum(1 for t in cur.threads for c in t.comments if c.review_id == r.id and not c.is_reply)
            events.append(ev("NEW_REVIEW", cur, f"{r.author} {r.state}", by=r.author, state=r.state, threads=opened, review=r.id))

        new_review_ids = {r.id for r in new_reviews}
        prev_comment_ids = {c.id for t in p.threads for c in t.comments}
        for t in cur.threads:
            fresh = [c for c in t.comments if c.id not in prev_comment_ids and c.author != me and c.review_id not in new_review_ids]
            if fresh:
                events.append(ev("NEW_REPLY", cur, f"{fresh[-1].author} on {t.path}", by=fresh[-1].author, thread=t.id, path=t.path))

        prev_issue_ids = {c.id for c in p.issue_comments}
        for c in cur.issue_comments:
            if c.id not in prev_issue_ids and c.author != me and not c.is_bot:
                events.append(ev("NEW_COMMENT", cur, f"{c.author} commented", by=c.author, comment=c.id))

        approval_lost = p.review_decision == "APPROVED" and cur.review_decision != "APPROVED" and cur.head_oid != p.head_oid
        if approval_lost:
            approvers = sorted(a for a, r in latest_reviews(p).items() if r.state == "APPROVED" and a != me)
            events.append(
                ev("APPROVAL_LOST", cur, "new push dismissed the approval", approvers=",".join(approvers) or "none", decision=cur.review_decision)
            )
        elif cur.review_decision != p.review_decision:
            events.append(ev("DECISION", cur, f"review decision {p.review_decision} -> {cur.review_decision}", value=cur.review_decision))

        prev_request_keys = {(r.reviewer, r.created_at) for r in p.review_requests}
        for r in cur.review_requests:
            if (r.reviewer, r.created_at) in prev_request_keys or r.requested_by != me or r.reviewer == me:
                continue
            rereview = any(x.author == r.reviewer for x in cur.reviews if x.id in substantive)
            events.append(ev("REVIEW_REQUEST_SENT", cur, f"you requested {r.reviewer}", to=r.reviewer, rereview=str(rereview).lower()))
    else:
        waiting = [t for t in cur.threads if not t.is_resolved and t.comments[-1].author != me]
        if waiting:
            events.append(ev("UNANSWERED_THREADS", cur, f"{len(waiting)} unresolved threads where the last word is not yours", count=len(waiting)))
        pending = unanswered_reviews(cur)
        if pending:
            reviewers = ",".join(r.author for r in pending)
            events.append(
                ev("UNANSWERED_REVIEWS", cur, f"{len(pending)} reviews posted before the watch with no answer from you", count=len(pending), by=reviewers)
            )

    if ready_to_merge(cur) and not (p is not None and ready_to_merge(p)):
        events.append(ev("READY_TO_MERGE", cur, "approved, green, no conflicts"))
    return events


def reviewer_events(prev: Optional[State], cur: Snapshot, state: State) -> List[str]:
    me = cur.me
    p = prev.snapshot if prev else None
    # Only new ones: the author owns them, and a baseline DM about old breakage is noise.
    events: List[str] = health_events(prev, cur, state) if p is not None else []
    mine = last_review_by(cur, me)

    since = mine.submitted_at if mine else ""
    prev_request_keys = {(r.reviewer, r.created_at) for r in p.review_requests} if p else set()
    fresh_requests = [
        r for r in cur.review_requests
        if r.reviewer == me and r.created_at > since and (r.reviewer, r.created_at) not in prev_request_keys
    ]
    re_requested = bool(fresh_requests) and mine is not None
    if fresh_requests:
        kind = "RE_REQUESTED" if mine else "REVIEW_REQUESTED"
        events.append(ev(kind, cur, f"{fresh_requests[-1].requested_by} requested your review", by=fresh_requests[-1].requested_by))

    if p is not None and mine is not None:
        prev_ids = {r.id for r in p.reviews}
        substantive = substantive_review_ids(cur)
        if mine.id not in prev_ids:
            first = not any(r.author == me and r.id in substantive and r.submitted_at < mine.submitted_at for r in cur.reviews)
            events.append(
                ev("MY_REVIEW_POSTED", cur, f"you posted {mine.state} on {cur.author}'s PR", state=mine.state, first=str(first).lower(), author=cur.author)
            )

    if mine is None:
        if p is None:
            events.append(ev("AWAITING_MY_REVIEW", cur, f"you have not reviewed {cur.author}'s PR yet", author=cur.author))
        return events

    if p is not None and cur.head_oid != p.head_oid and cur.head_author != me:
        events.append(ev("NEW_COMMITS", cur, f"head {short(p.head_oid)} -> {short(cur.head_oid)}", head=short(cur.head_oid), by=cur.head_author))

    prev_comment_ids = {c.id for t in p.threads for c in t.comments} if p else set()
    prev_resolved = {t.id for t in p.threads if t.is_resolved} if p else set()
    replies_after: List[ThreadComment] = []
    for t in cur.threads:
        if t.started_by != me:
            continue
        others = [c for c in t.comments if c.author != me and c.created_at > mine.submitted_at]
        replies_after.extend(others)
        if p is not None:
            fresh = [c for c in others if c.id not in prev_comment_ids]
            if fresh:
                events.append(ev("AUTHOR_REPLIED", cur, f"{fresh[-1].author} on {t.path}", by=fresh[-1].author, thread=t.id, path=t.path))
            if t.is_resolved and t.id not in prev_resolved and t.resolved_by != me:
                events.append(ev("MY_THREAD_RESOLVED", cur, f"{t.resolved_by} resolved your thread on {t.path}", by=t.resolved_by, thread=t.id, path=t.path))

    latest_reply = max(replies_after, key=lambda c: c.created_at).id if replies_after else "-"
    activity = f"{cur.head_oid}:{latest_reply}"
    has_activity = cur.head_oid != mine.commit_oid or bool(replies_after)
    quiet = prev is not None and prev.activity_key == activity
    state.activity_key = activity
    if has_activity and state.check_due_key != activity and cur.state == "OPEN":
        reason = "re-requested" if re_requested else "baseline" if p is None else "quiet" if quiet else None
        if reason is not None:
            state.check_due_key = activity
            events.append(
                ev(
                    "ADDRESS_CHECK_DUE",
                    cur,
                    "author activity since your last review has settled",
                    review_commit=short(mine.commit_oid),
                    my_review=mine.state,
                    head=short(cur.head_oid),
                    new_replies=len(replies_after),
                    reason=reason,
                )
            )
    return events


def diff(prev: Optional[State], cur: Snapshot, role: str) -> Tuple[List[str], State]:
    if role not in ROLES:
        raise ValueError(f"role must be one of {ROLES}, got {role!r}")
    p = prev.snapshot if prev else None
    state = State(
        role=role,
        snapshot=cur,
        known_mergeable=cur.mergeable if cur.mergeable != "UNKNOWN" else (prev.known_mergeable if prev else "UNKNOWN"),
        fail_streaks=update_fail_streaks(prev.fail_streaks if prev else {}, cur),
        activity_key=prev.activity_key if prev else None,
        check_due_key=prev.check_due_key if prev else None,
    )

    if p is not None and p.state == "OPEN" and cur.state != "OPEN":
        return [ev(f"PR_{cur.state}", cur, f"PR {cur.state.lower()}")], state

    events: List[str] = [] if p is not None else [baseline_line(cur, role)]
    new_truncation = [t for t in cur.truncated if p is None or t not in p.truncated]
    if new_truncation:
        events.append(ev("WATCH_LIMIT", cur, f"page limit hit on {','.join(new_truncation)}; events there may be missed"))
    if p is not None and p.is_draft and not cur.is_draft:
        events.append(ev("READY_FOR_REVIEW", cur, "draft marked ready for review"))

    events.extend(author_events(prev, cur, state) if role == "author" else reviewer_events(prev, cur, state))
    return events, state


# ---------------------------------------------------------------- state + log files


def state_key(repo: str, number: int) -> str:
    return f"{repo.replace('/', '-')}-{number}"


def state_path(state_dir: Path, repo: str, number: int) -> Path:
    return state_dir / f"{state_key(repo, number)}.json"


def log_path(state_dir: Path, repo: str, number: int) -> Path:
    return state_dir / f"{state_key(repo, number)}.log"


def load_state(state_dir: Path, repo: str, number: int) -> Optional[State]:
    path = state_path(state_dir, repo, number)
    if not path.exists():
        return None
    try:
        return state_from_dict(json.loads(path.read_text()))
    except (KeyError, TypeError, json.JSONDecodeError) as exc:
        raise ParseError(f"corrupt state file {path}: {exc}. Run `reset` to start over.") from exc


def save_state(state_dir: Path, repo: str, number: int, state: State) -> None:
    state_dir.mkdir(parents=True, exist_ok=True)
    path = state_path(state_dir, repo, number)
    tmp = path.with_suffix(".tmp")
    tmp.write_text(json.dumps(asdict(state), indent=1))
    tmp.replace(path)


def now_iso() -> str:
    return datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def append_log(state_dir: Path, repo: str, number: int, who: str, line: str) -> None:
    state_dir.mkdir(parents=True, exist_ok=True)
    with log_path(state_dir, repo, number).open("a") as fh:
        fh.write(f"{now_iso()} [{who}] {line}\n")


def resolve_role(requested: str, snap: Snapshot, prev: Optional[State]) -> str:
    if requested in ROLES:
        return requested
    if requested != "auto":
        raise SystemExit(f"--role must be auto|author|reviewer, got {requested!r}")
    if prev is not None:
        return prev.role
    return "author" if snap.author == snap.me else "reviewer"


# ---------------------------------------------------------------- commands


def poll(args: argparse.Namespace, save: bool) -> Tuple[List[str], State]:
    prev = load_state(args.state_dir, args.repo, args.pr)
    cur = fetch_snapshot(args.repo, args.pr)
    role = resolve_role(args.role, cur, prev)
    if prev is not None and prev.role != role:
        prev = None  # role switch: start a fresh baseline for the new view
    events, state = diff(prev, cur, role)
    if save:
        save_state(args.state_dir, args.repo, args.pr, state)
        for line in events:
            append_log(args.state_dir, args.repo, args.pr, "watch", line)
    return events, state


def emit(line: str) -> None:
    print(line, flush=True)


def cmd_watch(args: argparse.Namespace) -> int:
    errors = 0
    while True:
        try:
            events, state = poll(args, save=True)
        except GhError as exc:
            errors += 1
            if errors == GH_ERROR_ALERT_AFTER:
                emit(f"WATCH_ERROR pr={args.pr} consecutive={errors} | {str(exc)[:300]}")
            time.sleep(args.interval)
            continue
        except ParseError as exc:
            emit(f"WATCH_ERROR pr={args.pr} fatal=true | {exc}")
            return 2
        if errors >= GH_ERROR_ALERT_AFTER:
            emit(f"WATCH_RECOVERED pr={args.pr} | gh calls succeed again after {errors} failures")
        errors = 0
        for line in events:
            emit(line)
        if state.snapshot.state != "OPEN":
            return 0
        time.sleep(args.interval)


def cmd_once(args: argparse.Namespace) -> int:
    try:
        events, _ = poll(args, save=not args.no_save)
    except (GhError, ParseError) as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        return 1
    for line in events:
        emit(line)
    return 0


def cmd_status(args: argparse.Namespace) -> int:
    prev = load_state(args.state_dir, args.repo, args.pr)
    snap = fetch_snapshot(args.repo, args.pr)
    role = resolve_role(args.role, snap, prev)
    print(f"PR #{snap.number}  {snap.title}\n{snap.url}")
    print(f"role: {role}   you: {snap.me}   author: {snap.author}")
    print(
        f"state: {snap.state}  draft: {'yes' if snap.is_draft else 'no'}  mergeable: {snap.mergeable} ({snap.merge_state})"
        f"  decision: {snap.review_decision}"
    )
    print(f"head: {short(snap.head_oid)} by {snap.head_author}  ({snap.head_ref} -> {snap.base_ref})")
    if snap.checks:
        for bucket in ("fail", "pending", "pass", "skip"):
            names = [c.name for c in snap.checks if c.bucket == bucket]
            if names:
                print(f"checks {bucket}: {', '.join(names)}")
    else:
        print("checks: none on head" + (" (CI does not run while the branch conflicts)" if snap.mergeable == "CONFLICTING" else ""))
    latest: Dict[str, Review] = {}
    for r in snap.reviews:
        if r.id in substantive_review_ids(snap):
            latest[r.author] = r
    for r in latest.values():
        print(f"review: {r.author} {r.state} {r.submitted_at} @ {short(r.commit_oid)}")
    open_threads = [t for t in snap.threads if not t.is_resolved]
    waiting_on_me = [t for t in open_threads if t.comments[-1].author != snap.me]
    print(f"threads: {len(open_threads)} unresolved ({len(waiting_on_me)} where the last word is not yours)")
    if role == "author":
        pending = unanswered_reviews(snap)
        print(f"reviews awaiting your answer: {len(pending)}")
        for r in pending:
            print(f"  {r.author} {r.state} {r.submitted_at} @ {short(r.commit_oid)}")
    mine = last_review_by(snap, snap.me)
    if role == "reviewer":
        if mine is None:
            print("your review: none yet")
        else:
            my_open = [t for t in open_threads if t.started_by == snap.me]
            print(f"your last review: {mine.state} @ {short(mine.commit_oid)}  head now {short(snap.head_oid)}  your open threads: {len(my_open)}")
    log = log_path(args.state_dir, args.repo, args.pr)
    if log.exists():
        lines = log.read_text().splitlines()[-args.tail:]
        print(f"recent activity ({len(lines)}):")
        for line in lines:
            print(f"  {line}")
    else:
        print("recent activity: none logged yet")
    return 0


def cmd_threads(args: argparse.Namespace) -> int:
    owner, name = split_repo(args.repo)
    data = gh_graphql(THREADS_QUERY, owner, name, args.pr)
    conn = req(req(req(data, "repository", "data"), "pullRequest", "repository"), "reviewThreads", "pr")
    started_by = args.started_by
    if started_by == "@me":
        started_by = gh(["api", "user", "--jq", ".login"]).strip()
    out = []
    for t in req(conn, "nodes", "reviewThreads"):
        comments = req(req(t, "comments", "thread"), "nodes", "comments")
        if not comments:
            raise ParseError(f"thread {t.get('id')} has no comments")
        if started_by and login_of(comments[0]["author"]) != started_by:
            continue
        if args.unresolved and t["isResolved"]:
            continue
        out.append(
            {
                "id": t["id"],
                "path": t["path"],
                "line": t["line"],
                "originalLine": t["originalLine"],
                "isResolved": t["isResolved"],
                "isOutdated": t["isOutdated"],
                "resolvedBy": None if t["resolvedBy"] is None else login_of(t["resolvedBy"]),
                "diffHunk": comments[0]["diffHunk"],
                "comments": [
                    {
                        "id": c["id"],
                        "databaseId": c["databaseId"],
                        "url": c["url"],
                        "author": login_of(c["author"]),
                        "createdAt": c["createdAt"],
                        "commit": None if c["commit"] is None else c["commit"]["oid"],
                        "originalCommit": None if c["originalCommit"] is None else c["originalCommit"]["oid"],
                        "body": c["body"],
                    }
                    for c in comments
                ],
            }
        )
    if req(req(conn, "pageInfo", "reviewThreads"), "hasNextPage", "pageInfo"):
        print("WARNING: more than 100 threads; only the first 100 are listed", file=sys.stderr)
    print(json.dumps(out, indent=1))
    return 0


def cmd_log(args: argparse.Namespace) -> int:
    append_log(args.state_dir, args.repo, args.pr, args.who, " ".join(args.message))
    return 0


def slack_target(login: str) -> Optional[str]:
    """GitHub login -> Slack handle from people.json only. No name guessing: a wrong DM is worse than none.

    A login mapped to null (bots) returns None = never DM.
    """
    if login == "@me":
        return "@me"
    if not PEOPLE_FILE.exists():
        raise SystemExit(f"USER_NOT_MAPPED: {PEOPLE_FILE} missing; map every GitHub login to a Slack handle")
    try:
        people = json.loads(PEOPLE_FILE.read_text())
    except json.JSONDecodeError as exc:
        raise SystemExit(f"invalid JSON in {PEOPLE_FILE}: {exc}") from exc
    if not isinstance(people, dict) or login not in people:
        raise SystemExit(f"USER_NOT_MAPPED: GitHub {login} is not in {PEOPLE_FILE}; add \"{login}\": \"<slack handle>\" (or null for a bot)")
    target = people[login]
    if target is not None and not isinstance(target, str):
        raise SystemExit(f"invalid mapping for {login} in {PEOPLE_FILE}: expected a Slack handle or null")
    return target


def recently_sent(state_dir: Path, repo: str, number: int, marker: str) -> bool:
    log = log_path(state_dir, repo, number)
    if not log.exists():
        return False
    cutoff = time.time() - DM_DEDUPE_WINDOW_S
    for line in reversed(log.read_text().splitlines()):
        stamp = line.split(" ", 1)[0]
        try:
            at = datetime.strptime(stamp, "%Y-%m-%dT%H:%M:%SZ").replace(tzinfo=timezone.utc).timestamp()
        except ValueError:
            continue
        if at < cutoff:
            return False
        if line.endswith(marker):
            return True
    return False


def cmd_dm(args: argparse.Namespace) -> int:
    marker = f"[dm] to={args.to} {args.text}"
    if recently_sent(args.state_dir, args.repo, args.pr, marker):
        print(f"skipped: same DM to {args.to} sent within {DM_DEDUPE_WINDOW_S // 60} min")
        return 0
    target = slack_target(args.to)
    if target is None:
        print(f"skipped: {args.to} is mapped to null (not a person)")
        return 0
    cmd = [sys.executable, str(SLACK_POST), "dm", "--to", target, "--text", args.text]
    if args.dry_run:
        cmd.append("--dry-run")
    proc = subprocess.run(cmd, capture_output=True, text=True)
    sys.stdout.write(proc.stdout)
    if proc.returncode != 0:
        sys.stderr.write(proc.stderr)
        print(f"DM to {args.to} ({target}) failed; map them in {PEOPLE_FILE} if USER_NOT_FOUND", file=sys.stderr)
        return proc.returncode
    if not args.dry_run:
        state_dir = args.state_dir
        state_dir.mkdir(parents=True, exist_ok=True)
        with log_path(state_dir, args.repo, args.pr).open("a") as fh:
            fh.write(f"{now_iso()} {marker}\n")
    return 0


def cmd_reset(args: argparse.Namespace) -> int:
    path = state_path(args.state_dir, args.repo, args.pr)
    if path.exists():
        path.unlink()
        print(f"removed {path}")
    else:
        print(f"no state at {path}")
    return 0


def main(argv: Optional[List[str]] = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = parser.add_subparsers(dest="cmd", required=True)

    def common(p: argparse.ArgumentParser) -> None:
        p.add_argument("--repo", required=True, help="owner/name")
        p.add_argument("--pr", required=True, type=int)
        p.add_argument("--state-dir", type=Path, default=DEFAULT_STATE_DIR)

    for name in ("watch", "once", "status"):
        p = sub.add_parser(name)
        common(p)
        p.add_argument("--role", default="auto", help="auto|author|reviewer (auto: author if you opened the PR)")
        if name == "watch":
            p.add_argument("--interval", type=int, default=DEFAULT_INTERVAL_S)
        if name == "once":
            p.add_argument("--no-save", action="store_true")
        if name == "status":
            p.add_argument("--tail", type=int, default=20)

    p = sub.add_parser("threads")
    common(p)
    p.add_argument("--started-by", default="@me", help="login, @me, or '' for all")
    p.add_argument("--unresolved", action="store_true")

    p = sub.add_parser("log")
    common(p)
    p.add_argument("--who", required=True)
    p.add_argument("message", nargs="+")

    p = sub.add_parser("dm")
    common(p)
    p.add_argument("--to", required=True, help="GitHub login or @me")
    p.add_argument("--text", required=True)
    p.add_argument("--dry-run", action="store_true")

    p = sub.add_parser("reset")
    common(p)

    args = parser.parse_args(argv)
    handler = {
        "watch": cmd_watch,
        "once": cmd_once,
        "status": cmd_status,
        "threads": cmd_threads,
        "log": cmd_log,
        "dm": cmd_dm,
        "reset": cmd_reset,
    }[args.cmd]
    return handler(args)


if __name__ == "__main__":
    sys.exit(main())
```

#### `~/.ai/skills/watch-pr/tests/test_diff.py`

```python file=~/.ai/skills/watch-pr/tests/test_diff.py
"""Event diff tests. Run: python3 -m unittest discover -s ~/.ai/skills/watch-pr/tests"""
from __future__ import annotations

import sys
import unittest
from dataclasses import replace
from pathlib import Path
from typing import List, Optional

sys.path.insert(0, str(Path(__file__).resolve().parent.parent / "scripts"))

from watch_pr import (  # noqa: E402
    Check,
    IssueComment,
    Review,
    ReviewRequest,
    Snapshot,
    State,
    Thread,
    ThreadComment,
    diff,
)

ME = "martin"
OTHER = "marcus"


def snap(**kw) -> Snapshot:
    base = dict(
        me=ME,
        number=7,
        url="https://github.com/o/r/pull/7",
        title="t",
        author=ME,
        state="OPEN",
        is_draft=False,
        is_cross_repo=False,
        mergeable="MERGEABLE",
        merge_state="BLOCKED",
        review_decision="REVIEW_REQUIRED",
        head_ref="feat/x",
        base_ref="main",
        head_oid="a" * 40,
        head_author=ME,
        checks=[],
        reviews=[],
        threads=[],
        issue_comments=[],
        review_requests=[],
        truncated=[],
    )
    base.update(kw)
    return Snapshot(**base)


def review(id: str, author: str, state: str = "COMMENTED", at: str = "2026-10-14T10:00:00Z", commit: Optional[str] = "a" * 40, body: bool = True) -> Review:
    return Review(id=id, author=author, is_bot=False, state=state, submitted_at=at, commit_oid=commit, has_body=body)


def comment(id: str, author: str, at: str, review_id: Optional[str], reply: bool) -> ThreadComment:
    return ThreadComment(id=id, author=author, created_at=at, review_id=review_id, is_reply=reply)


def thread(id: str, comments: List[ThreadComment], resolved: bool = False, resolved_by: Optional[str] = None) -> Thread:
    return Thread(id=id, path="src/a.ts", line=3, is_resolved=resolved, resolved_by=resolved_by, is_outdated=False, started_by=comments[0].author, comments=comments)


def kinds(events: List[str]) -> List[str]:
    return [e.split(" ", 1)[0] for e in events]


def step(prev: Optional[State], cur: Snapshot, role: str):
    return diff(prev, cur, role)


class AuthorTests(unittest.TestCase):
    def test_baseline_surfaces_existing_conflict_and_failures(self):
        s = snap(mergeable="CONFLICTING", merge_state="DIRTY", checks=[Check("typecheck", "fail", "FAILURE"), Check("lint", "pass", "SUCCESS")])
        events, state = step(None, s, "author")
        self.assertEqual(kinds(events), ["BASELINE", "CONFLICT", "CI_FAILED"])
        self.assertIn("attempt=1", events[2])
        self.assertEqual(state.known_mergeable, "CONFLICTING")

    def test_conflict_fires_once_and_unknown_does_not_reset(self):
        _, s1 = step(None, snap(), "author")
        e2, s2 = step(s1, snap(mergeable="CONFLICTING"), "author")
        self.assertEqual(kinds(e2), ["CONFLICT"])
        e3, s3 = step(s2, snap(mergeable="UNKNOWN"), "author")
        self.assertEqual(e3, [])
        e4, _ = step(s3, snap(mergeable="CONFLICTING"), "author")
        self.assertEqual(e4, [], "UNKNOWN in between must not re-fire CONFLICT")

    def test_same_check_failing_after_fix_push_counts_attempts(self):
        fail = [Check("test", "fail", "FAILURE")]
        _, s1 = step(None, snap(checks=fail), "author")
        e_same, s1b = step(s1, snap(checks=fail), "author")
        self.assertEqual(e_same, [], "same failure on same head is not new")
        _, s2 = step(s1b, snap(head_oid="b" * 40, checks=[Check("test", "pending", "IN_PROGRESS")]), "author")
        e3, _ = step(s2, snap(head_oid="b" * 40, checks=fail), "author")
        self.assertEqual(kinds(e3), ["CI_FAILED"])
        self.assertIn("attempt=2", e3[0])

    def test_green_resets_streak(self):
        _, s1 = step(None, snap(checks=[Check("test", "fail", "FAILURE")]), "author")
        e2, s2 = step(s1, snap(head_oid="b" * 40, checks=[Check("test", "pass", "SUCCESS")]), "author")
        self.assertEqual(kinds(e2), ["CI_GREEN"])
        e3, _ = step(s2, snap(head_oid="c" * 40, checks=[Check("test", "fail", "FAILURE")]), "author")
        self.assertIn("attempt=1", e3[0])

    def test_new_review_vs_reply_only_review_vs_my_own(self):
        _, s1 = step(None, snap(), "author")
        r = review("R1", OTHER, body=False)
        t = thread("T1", [comment("C1", OTHER, "2026-10-14T10:00:00Z", "R1", reply=False)])
        e2, s2 = step(s1, snap(reviews=[r], threads=[t]), "author")
        self.assertEqual(kinds(e2), ["NEW_REVIEW"], "thread comments inside a new review are not separate replies")
        self.assertIn("threads=1", e2[0])

        reply_review = review("R2", OTHER, body=False, at="2026-10-14T11:00:00Z")
        t2 = replace(t, comments=t.comments + [comment("C2", OTHER, "2026-10-14T11:00:00Z", "R2", reply=True)])
        e3, s3 = step(s2, snap(reviews=[r, reply_review], threads=[t2]), "author")
        self.assertEqual(kinds(e3), ["NEW_REPLY"], "a lone reply is wrapped in a review by GitHub but is not a review")

        mine = review("R3", ME, body=False, at="2026-10-14T12:00:00Z")
        t3 = replace(t2, comments=t2.comments + [comment("C3", ME, "2026-10-14T12:00:00Z", "R3", reply=True)])
        e4, _ = step(s3, snap(reviews=[r, reply_review, mine], threads=[t3], issue_comments=[IssueComment("I1", ME, False, "2026-10-14T12:00:00Z")]), "author")
        self.assertEqual(e4, [], "my own activity never triggers")

    def test_baseline_surfaces_body_only_review_posted_before_the_watch(self):
        early_request = ReviewRequest(reviewer=OTHER, requested_by=ME, created_at="2026-10-14T09:00:00Z")
        s = snap(reviews=[review("R1", OTHER)], review_requests=[early_request])
        events, _ = step(None, s, "author")
        self.assertEqual(kinds(events), ["BASELINE", "UNANSWERED_REVIEWS"], "a review with no threads must not vanish into the baseline")
        self.assertIn(f"by={OTHER}", events[1])
        self.assertIn("count=1", events[1])

    def test_baseline_changes_requested_without_body_is_unanswered(self):
        events, _ = step(None, snap(reviews=[review("R1", OTHER, state="CHANGES_REQUESTED", body=False)]), "author")
        self.assertEqual(kinds(events), ["BASELINE", "UNANSWERED_REVIEWS"])

    def test_baseline_review_already_answered_is_quiet(self):
        r = review("R1", OTHER, at="2026-10-14T10:00:00Z")
        later = "2026-10-14T11:00:00Z"
        answered = {
            "my PR comment after it": snap(reviews=[r], issue_comments=[IssueComment("I1", ME, False, later)]),
            "re-requested after it": snap(reviews=[r], review_requests=[ReviewRequest(reviewer=OTHER, requested_by=ME, created_at=later)]),
            "its threads all resolved": snap(
                reviews=[r], threads=[thread("T1", [comment("C1", OTHER, r.submitted_at, "R1", reply=False)], resolved=True, resolved_by=ME)]
            ),
            "they approved since": snap(reviews=[r, review("R2", OTHER, state="APPROVED", at=later, body=False)]),
        }
        for why, s in answered.items():
            with self.subTest(why):
                events, _ = step(None, s, "author")
                self.assertEqual(kinds(events), ["BASELINE"])

    def test_baseline_comment_before_the_review_does_not_answer_it(self):
        s = snap(reviews=[review("R1", OTHER, at="2026-10-14T10:00:00Z")], issue_comments=[IssueComment("I1", ME, False, "2026-10-14T09:00:00Z")])
        events, _ = step(None, s, "author")
        self.assertEqual(kinds(events), ["BASELINE", "UNANSWERED_REVIEWS"])

    def test_baseline_thread_only_review_is_left_to_unanswered_threads(self):
        t = thread("T1", [comment("C1", OTHER, "2026-10-14T10:00:00Z", "R1", reply=False)])
        events, _ = step(None, snap(reviews=[review("R1", OTHER, body=False)], threads=[t]), "author")
        self.assertEqual(kinds(events), ["BASELINE", "UNANSWERED_THREADS"])

    def test_bot_issue_comments_ignored(self):
        _, s1 = step(None, snap(), "author")
        e2, _ = step(s1, snap(issue_comments=[IssueComment("I1", "github-actions", True, "2026-10-14T10:00:00Z")]), "author")
        self.assertEqual(e2, [])

    def test_approval_lost_after_my_push(self):
        approved = review("R1", OTHER, state="APPROVED")
        _, s1 = step(None, snap(reviews=[approved], review_decision="APPROVED", merge_state="CLEAN", checks=[Check("t", "pass", "SUCCESS")]), "author")
        e2, _ = step(s1, snap(reviews=[approved], review_decision="REVIEW_REQUIRED", head_oid="b" * 40), "author")
        self.assertEqual(kinds(e2), ["APPROVAL_LOST"])
        self.assertIn(f"approvers={OTHER}", e2[0])

    def test_ready_to_merge_once(self):
        ok = dict(review_decision="APPROVED", merge_state="CLEAN", checks=[Check("t", "pass", "SUCCESS")])
        _, s1 = step(None, snap(), "author")
        e2, s2 = step(s1, snap(**ok), "author")
        self.assertIn("READY_TO_MERGE", kinds(e2))
        e3, _ = step(s2, snap(**ok), "author")
        self.assertEqual(e3, [])

    def test_review_request_sent_marks_rereview(self):
        r = review("R1", OTHER)
        _, s1 = step(None, snap(reviews=[r]), "author")
        req = ReviewRequest(reviewer=OTHER, requested_by=ME, created_at="2026-10-14T12:00:00Z")
        e2, _ = step(s1, snap(reviews=[r], review_requests=[req]), "author")
        self.assertEqual(kinds(e2), ["REVIEW_REQUEST_SENT"])
        self.assertIn("rereview=true", e2[0])

    def test_merged_stops_everything_else(self):
        _, s1 = step(None, snap(), "author")
        e2, _ = step(s1, snap(state="MERGED", mergeable="CONFLICTING"), "author")
        self.assertEqual(kinds(e2), ["PR_MERGED"])


class ReviewerTests(unittest.TestCase):
    def other_pr(self, **kw) -> Snapshot:
        return snap(author=OTHER, head_author=OTHER, **kw)

    def reviewed(self, **kw) -> Snapshot:
        my_review = review("R1", ME, at="2026-10-14T10:00:00Z", commit="a" * 40)
        t = thread("T1", [comment("C1", ME, "2026-10-14T10:00:00Z", "R1", reply=False)])
        kw.setdefault("reviews", [my_review])
        kw.setdefault("threads", [t])
        return self.other_pr(**kw)

    def test_unreviewed_pr_waits(self):
        events, _ = step(None, self.other_pr(), "reviewer")
        self.assertEqual(kinds(events), ["BASELINE", "AWAITING_MY_REVIEW"])

    def test_push_is_debounced_one_quiet_poll(self):
        _, s1 = step(None, self.reviewed(), "reviewer")
        e2, s2 = step(s1, self.reviewed(head_oid="b" * 40), "reviewer")
        self.assertEqual(kinds(e2), ["NEW_COMMITS"], "no check while the author may still be pushing")
        e3, s3 = step(s2, self.reviewed(head_oid="b" * 40), "reviewer")
        self.assertEqual(kinds(e3), ["ADDRESS_CHECK_DUE"])
        self.assertIn("reason=quiet", e3[0])
        e4, _ = step(s3, self.reviewed(head_oid="b" * 40), "reviewer")
        self.assertEqual(e4, [], "fires once per activity")

    def test_baseline_with_moved_head_is_due_immediately(self):
        events, _ = step(None, self.reviewed(head_oid="b" * 40), "reviewer")
        self.assertEqual(kinds(events), ["BASELINE", "ADDRESS_CHECK_DUE"])
        self.assertIn("reason=baseline", events[1])

    def test_rerequest_after_my_review_fires_now(self):
        _, s1 = step(None, self.reviewed(), "reviewer")
        req = ReviewRequest(reviewer=ME, requested_by=OTHER, created_at="2026-10-14T11:00:00Z")
        e2, _ = step(s1, self.reviewed(head_oid="b" * 40, review_requests=[req]), "reviewer")
        self.assertEqual(kinds(e2), ["RE_REQUESTED", "NEW_COMMITS", "ADDRESS_CHECK_DUE"])
        self.assertIn("reason=re-requested", e2[2])

    def test_request_older_than_my_review_is_not_a_rerequest(self):
        old = ReviewRequest(reviewer=ME, requested_by=OTHER, created_at="2026-10-14T09:00:00Z")
        events, _ = step(None, self.reviewed(review_requests=[old]), "reviewer")
        self.assertEqual(kinds(events), ["BASELINE"])

    def test_author_reply_without_push_is_due_after_quiet(self):
        _, s1 = step(None, self.reviewed(), "reviewer")
        t = thread("T1", [comment("C1", ME, "2026-10-14T10:00:00Z", "R1", False), comment("C2", OTHER, "2026-10-14T11:00:00Z", "R9", True)])
        e2, s2 = step(s1, self.reviewed(threads=[t]), "reviewer")
        self.assertEqual(kinds(e2), ["AUTHOR_REPLIED"])
        e3, _ = step(s2, self.reviewed(threads=[t]), "reviewer")
        self.assertEqual(kinds(e3), ["ADDRESS_CHECK_DUE"])
        self.assertIn("new_replies=1", e3[0])

    def test_my_thread_reply_does_not_count_as_a_review(self):
        _, s1 = step(None, self.reviewed(), "reviewer")
        reply_only = review("R2", ME, at="2026-10-14T12:00:00Z", commit="b" * 40, body=False)
        t = thread("T1", [comment("C1", ME, "2026-10-14T10:00:00Z", "R1", False), comment("C2", ME, "2026-10-14T12:00:00Z", "R2", True)])
        _, s2 = step(s1, self.reviewed(head_oid="b" * 40, reviews=[self.reviewed().reviews[0], reply_only], threads=[t]), "reviewer")
        e3, _ = step(s2, self.reviewed(head_oid="b" * 40, reviews=[self.reviewed().reviews[0], reply_only], threads=[t]), "reviewer")
        self.assertEqual(kinds(e3), ["ADDRESS_CHECK_DUE"], "a lone reply at the new head must not hide the push")

    def test_my_new_review_posts_event_and_clears_due(self):
        _, s1 = step(None, self.reviewed(head_oid="b" * 40), "reviewer")
        approve = review("R2", ME, state="APPROVED", at="2026-10-14T12:00:00Z", commit="b" * 40, body=False)
        e2, _ = step(s1, self.reviewed(head_oid="b" * 40, reviews=[self.reviewed().reviews[0], approve]), "reviewer")
        self.assertEqual(kinds(e2), ["MY_REVIEW_POSTED"])
        self.assertIn("state=APPROVED", e2[0])
        self.assertIn("first=false", e2[0])

    def test_dismissed_approval_is_still_my_last_review(self):
        older = review("R1", ME, at="2026-10-14T10:00:00Z", commit="a" * 40)
        approval = review("R2", ME, state="APPROVED", at="2026-10-14T11:00:00Z", commit="b" * 40, body=False)
        _, s1 = step(None, self.reviewed(head_oid="b" * 40, reviews=[older, approval]), "reviewer")
        dismissed = replace(approval, state="DISMISSED")
        _, s2 = step(s1, self.reviewed(head_oid="c" * 40, reviews=[older, dismissed]), "reviewer")
        e3, _ = step(s2, self.reviewed(head_oid="c" * 40, reviews=[older, dismissed]), "reviewer")
        self.assertEqual(kinds(e3), ["ADDRESS_CHECK_DUE"])
        self.assertIn(f"review_commit={'b' * 8}", e3[0], "re-check from the approval, not the older review")
        self.assertIn("my_review=DISMISSED", e3[0])

    def test_new_conflict_and_ci_failure_reported_to_reviewer(self):
        _, s1 = step(None, self.reviewed(), "reviewer")
        e2, _ = step(s1, self.reviewed(mergeable="CONFLICTING", checks=[Check("test", "fail", "FAILURE")]), "reviewer")
        self.assertEqual(kinds(e2), ["CONFLICT", "CI_FAILED"])

    def test_breakage_that_predates_the_watch_is_not_reported_to_reviewer(self):
        events, _ = step(None, self.reviewed(mergeable="CONFLICTING", checks=[Check("test", "fail", "FAILURE")]), "reviewer")
        self.assertEqual(kinds(events), ["BASELINE"])

    def test_ci_green_reported_to_reviewer(self):
        _, s1 = step(None, self.reviewed(checks=[Check("test", "pending", "IN_PROGRESS")]), "reviewer")
        e2, _ = step(s1, self.reviewed(checks=[Check("test", "pass", "SUCCESS")]), "reviewer")
        self.assertEqual(kinds(e2), ["CI_GREEN"])

    def test_thread_resolved_by_author(self):
        _, s1 = step(None, self.reviewed(), "reviewer")
        t = thread("T1", [comment("C1", ME, "2026-10-14T10:00:00Z", "R1", False)], resolved=True, resolved_by=OTHER)
        e2, _ = step(s1, self.reviewed(threads=[t]), "reviewer")
        self.assertEqual(kinds(e2), ["MY_THREAD_RESOLVED"])


if __name__ == "__main__":
    unittest.main()
```

### OpenCode-only skills

Kept apart from `skills/` because OpenCode also scans `~/.claude/skills`, so a shared name would collide.

#### `~/.ai/oc_skills/monorepo-worktree/SKILL.md`

````markdown file=~/.ai/oc_skills/monorepo-worktree/SKILL.md
---
name: monorepo-worktree
description: Create or destroy an isolated git worktree of the Future Mortgage monorepo that runs front-end and back-end on alternate ports (own Postgres DB + Redis DB index) so multiple full stacks can run at once. Remaining args after create are a follow-on coding task — do that immediately in the worktree, do not stop after setup. Use when the user runs /monorepo-worktree, /monorepo-worktree destroy|remove|teardown, asks to "spin up a worktree", "run a second stack", "parallel monorepo", "worktree on new ports", or needs a second seeded local environment without stopping the primary checkout. Do NOT use for a code-only PR/branch checkout — that is /worktree-quick.
---

# /monorepo-worktree

Create **or destroy** a parallel monorepo checkout that coexists with the primary
stack (`:3000` / `:3001` / `:4201`).

Code-only PR/branch checkout (no env/DB/seed): `/worktree-quick`.

User arguments: `$ARGUMENTS`

## Commands

| User says | Action |
|-----------|--------|
| `/monorepo-worktree` / `create` / `setup` | Create + seed + report how to serve |
| `/monorepo-worktree <task>` | Create (defaults) then **immediately do the task** in the worktree |
| `/monorepo-worktree destroy` / `remove` / `teardown` / `rm` | Stop processes, drop DB, remove worktree |
| `/monorepo-worktree list` | Show worktrees, slots, ports, what is listening |

## Parse `$ARGUMENTS` — then do not stall

Classify the first tokens, leftover text is the **follow-on task**:

| Pattern | Action |
|---------|--------|
| `destroy` / `remove` / `teardown` / `rm` … | Destroy. No create. No coding task. |
| `list` | List only. |
| `create` / `setup` (optional), optional slot int, optional git ref, optional name, **rest** | Create. `rest` is the task. |
| Anything else (multi-word, or a single non-verb token) | Create with defaults, whole string is the task. |

Examples:

- `implement fees page polish` → slot `1`, ref `HEAD`, name slug from task, then implement that
- `2 feature/foo my-feature fix login OTP` → slot 2, that ref/name, task `fix login OTP`
- (empty) → create slot 1, report URLs, **stop**

Defaults when unspecified: slot `1`, ref `HEAD`, name `slot-1` **or** a `[a-z0-9-]{1,32}` slug from the task. **Do not ask** for slot/branch/name. Ask only if the chosen slot’s ports are busy (then next free slot ≥1) or a destroy target is ambiguous.

### Model split (Claude Code)

- **You** (session model) parse `$ARGUMENTS` into slot / ref / name / task.
- **Haiku subagent** (Agent tool, `model: "haiku"`) does the mechanical part: port check, `setup-worktree.sh`, or the whole `destroy` / `list`. Tell it to follow `~/.ai/commands/monorepo-worktree.md` with the parsed slot/ref/name, and to return worktree path, slot, ports/URLs, and exit status (or the last ~50 lines of output on failure). It does not edit code or improvise around a failed step.
- **You** then start `./serve-worktree.sh` in the background (your session owns that process) and do the follow-on task. On subagent failure, diagnose it yourself; don't blindly re-delegate.

If you **are** that subagent, skip this section and run the steps directly — do not delegate again.

### HARD RULE: setup is a prefix, not the job

If a follow-on task exists, **you (this same session) start it the moment the setup subagent reports `setup-worktree.sh` exited 0.**

After setup succeeds:

1. Start `./serve-worktree.sh` **background only** (`background: true` / do not wait for exit). Never foreground. Coding does not depend on serve.
2. Optional health check: poll API **≤90s**, then continue even if still warming. Never poll forever.
3. `cd` to the worktree path. **Immediately implement the task.** All edits / git / yarn / nx happen in `$WT`, not the primary checkout.
4. One-line URL/path note is fine. Then keep working.

**Forbidden** when a follow-on task exists:

- Ending the turn after create with only URLs, credentials, or a destroy command
- Asking “want me to start on X?” / “should I continue?”
- Asking for slot, branch, or name
- Spawning a subagent for the task and then idling
- Waiting on `serve-worktree.sh`, webpack compile, or health as if that were the deliverable

## Default ports (primary = slot 0)

| Service    | Primary | Slot 1 | Slot 2 | Slot N        |
|------------|---------|--------|--------|---------------|
| web-crm    | 3000    | 3100   | 3200   | 3000 + N×100  |
| server-crm | 3001    | 3101   | 3201   | 3001 + N×100  |
| web-funnel | 4201    | 4301   | 4401   | 4201 + N×100  |
| Postgres   | dbname  | dbname_wt1 | dbname_wt2 | dbname_wtN |
| Redis DB # | 0       | 1      | 2      | N             |
| Cookie     | auth-token | auth-token-wt1 | … | auth-token-wtN |
| Node inspect | 9229  | 9230   | 9231   | 9229 + N      |

CRM URL for slot N: `http://fm.futurewholesale.local:{WEB_PORT}`

---

## Create (setup)

### When to use

- User wants a second (or third) local stack while primary is already running
- Feature work that needs a clean seeded DB without touching primary data
- Side-by-side UI comparison across branches

### Prerequisites

1. Primary monorepo has working `.env` + `.env.local` (source of secrets)
2. Docker containers running: `future-mortgage-postgres`, `future-mortgage-redis`
3. Hosts file already has tenant subdomains (same as primary):
   `127.0.0.1 fm.futurewholesale.local` (and other tenants as needed)
4. Slot ports are free (`lsof -nP -iTCP:3100 -sTCP:LISTEN` etc.)

### Fast path (preferred)

From inside the **primary** monorepo (or any of its worktrees). Skill is
**user-scoped** at `~/.ai/oc_skills/monorepo-worktree/` (not in the repo).

```bash
# Slot 1 from current HEAD, name "slot-1"
~/.ai/oc_skills/monorepo-worktree/scripts/setup-worktree.sh 1

# Slot 2 from a branch, custom name
~/.ai/oc_skills/monorepo-worktree/scripts/setup-worktree.sh 2 feature/foo my-feature

# Or pin the repo explicitly:
MONOREPO_ROOT=/path/to/monorepo ~/.ai/oc_skills/monorepo-worktree/scripts/setup-worktree.sh 1
```

Script will:

1. `git worktree add` under `../worktrees/monorepo-<name>`
2. Copy env files from primary
3. Create Postgres DB `dbname_wt{N}`
4. Rewrite port / DB / Redis / cookie / FRONTEND_URL values
5. Patch webpack + vite + `web-crm` project.json for env-aware ports (worktree-local)
6. `yarn install` (own `node_modules`; husky postinstall wires pre-push; do not skip yarn; do not symlink from primary) → `yarn prisma:sync` → `yarn nx run database:seed` → `yarn nx run database:seed-du-test-cases` (Fannie Mae) → `yarn nx run database:seed-lpa-test-cases` (Freddie Mac)
7. Write `serve-worktree.sh` and `.worktree-slot` marker

Then start **in the background** (never wait for this process to exit):

```bash
cd ../worktrees/monorepo-slot-1   # or the path printed by the script
./serve-worktree.sh
```

If a follow-on task exists, start serve in background and **begin the task immediately**. Do not wait for compile/health.

Verify:

```bash
curl -s http://localhost:3101/health   # slot 1 API
curl -s -o /dev/null -w "%{http_code}\n" http://localhost:3100/
curl -s -o /dev/null -w "%{http_code}\n" http://localhost:4301/apply/
# Primary must still be up:
curl -s http://localhost:3001/health
```

### Agent checklist — create

1. **Parse** `$ARGUMENTS` (see above). Do **not** ask for slot/branch/name — default them.
2. **Confirm** target slot ports are free (`lsof` / curl). If busy, use the next free slot ≥1.
3. **Run** `~/.ai/oc_skills/monorepo-worktree/scripts/setup-worktree.sh` (preferred) **or** the manual steps below — via the Haiku subagent (steps 2–3; see Model split).
4. **Start** `./serve-worktree.sh` in the worktree **in the background**. Never foreground. Never wait for exit.
5. **Health** (optional, ≤90s): new API port + primary `:3001` still responds. On timeout, continue.
6. **No follow-on task:** report URLs, credentials, path, destroy command, **stop**.
7. **Follow-on task:** one-line path + URLs, then **immediately implement the task in `$WT`** (this session, not a subagent). Do not stop. Do not ask.

### Credentials (same as primary after seed)

| Role  | Email | Password | OTP |
|-------|-------|----------|-----|
| Dev   | `martin.hansen@trygenius.ai` | `admin123` | `1111` |
| Admin | `admin@fm.com` | `admin123` | `1111` |

Tenant CRM: `http://fm.futurewholesale.local:{WEB_PORT}`

---

## Destroy / remove / teardown

Use when the user says any of: `destroy`, `remove`, `teardown`, `rm`, `clean up worktree`,
`kill the worktree stack`, `shut down slot N`.

### Fast path (preferred)

From inside the monorepo (or set `MONOREPO_ROOT`). Scripts live at
`~/.ai/oc_skills/monorepo-worktree/scripts/`.

```bash
# List what exists (no changes)
~/.ai/oc_skills/monorepo-worktree/scripts/destroy-worktree.sh list

# Destroy slot 1 (stops ports, flushes redis DB 1, drops dbname_wt1, removes worktree + branch)
~/.ai/oc_skills/monorepo-worktree/scripts/destroy-worktree.sh destroy 1 --yes

# Same aliases
~/.ai/oc_skills/monorepo-worktree/scripts/destroy-worktree.sh remove 1 --yes
~/.ai/oc_skills/monorepo-worktree/scripts/destroy-worktree.sh teardown --name slot-1 --yes
~/.ai/oc_skills/monorepo-worktree/scripts/destroy-worktree.sh --path ../worktrees/monorepo-slot-1 --yes

# Destroy every monorepo-* under ../worktrees/
~/.ai/oc_skills/monorepo-worktree/scripts/destroy-worktree.sh --all --yes
```

### Flags

| Flag | Effect |
|------|--------|
| `--yes` / `-y` | Required in non-interactive agent shells; skip prompt |
| `--force` | `git worktree remove --force` (discard dirty worktree files) |
| `--keep-db` | Do not `DROP DATABASE dbname_wtN` |
| `--keep-branch` | Do not delete `worktree/<name>` branch |
| `--keep-redis` | Do not `FLUSHDB` on the slot's Redis logical DB |

Default destroy is **full cleanup**: stop processes + flush redis slot + drop DB + remove worktree dir + delete `worktree/*` branch.

### Destroy order (script guarantees this order)

1. **Resolve target(s)** from slot / name / path / `--all` using `.worktree-slot` marker when present
2. **Safety checks** (refuse primary path, primary ports, primary DB name `dbname`)
3. **Stop listeners** on worktree ports only (`WEB` / `API` / `FUNNEL` / inspect)
4. **Best-effort kill** node/yarn/nx processes whose cwd is under the worktree (covers parent `nx run-many`)
5. **Redis** `FLUSHDB` on logical DB `N` (slot index) — not DB 0
6. **Postgres** terminate backends on `dbname_wtN`, then `DROP DATABASE`
7. **`git worktree remove`** (retry with `--force` if needed; prune)
8. **Delete local branch** `worktree/<name>` if it exists and is not checked out elsewhere
9. **Verify** primary ports untouched; print remaining `git worktree list`

### Hard safety rules (never violate)

- **Never** kill ports `3000`, `3001`, `4201` (primary stack)
- **Never** `DROP DATABASE dbname` (only `dbname_wt[1-9]…`)
- **Never** remove the primary monorepo checkout path
- **Never** flush Redis logical DB `0`
- If `.worktree-slot` is missing, still allow destroy when path is under `../worktrees/monorepo-*` and ports can be inferred from slot name `slot-N`

### Agent checklist — destroy

1. **Parse intent**: `destroy` / `remove` / `teardown` / `list`.
2. **Identify target**: slot number, name, path, or `--all`. If ambiguous, run `list` and ask.
3. **If user has uncommitted feature work** only in that worktree: warn and prefer `--keep-branch` or confirm `--force`.
4. **Run** `~/.ai/oc_skills/monorepo-worktree/scripts/destroy-worktree.sh … --yes` (agents are non-interactive).
5. **Verify**:
   - Worktree ports no longer listening
   - `git worktree list` no longer shows the path
   - `dbname_wtN` gone (unless `--keep-db`)
   - Primary `:3001/health` still OK if primary was running
6. **Report** what was stopped, dropped, and removed.

### Manual destroy (if script unavailable)

```bash
PRIMARY="$(git rev-parse --show-toplevel)"
# if already inside a worktree, use git common dir:
# PRIMARY="$(dirname "$(git rev-parse --path-format=absolute --git-common-dir)")"
WT="$(dirname "$PRIMARY")/worktrees/monorepo-slot-1"
SLOT=1
WEB=$((3000 + SLOT*100)); API=$((3001 + SLOT*100)); FUNNEL=$((4201 + SLOT*100))
DB="dbname_wt${SLOT}"

# 1) Stop serve processes on worktree ports ONLY
for p in $WEB $API $FUNNEL; do
  lsof -nP -iTCP:$p -sTCP:LISTEN -t | xargs -r kill -TERM 2>/dev/null || true
done
sleep 1
for p in $WEB $API $FUNNEL; do
  lsof -nP -iTCP:$p -sTCP:LISTEN -t | xargs -r kill -KILL 2>/dev/null || true
done

# 2) Flush redis logical DB for slot (not 0)
docker exec future-mortgage-redis redis-cli -n "$SLOT" FLUSHDB

# 3) Drop isolated DB only
docker exec -e PGPASSWORD=dbpassword future-mortgage-postgres \
  psql -U dbuser -d postgres -c \
  "SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname='${DB}' AND pid<>pg_backend_pid();"
docker exec -e PGPASSWORD=dbpassword future-mortgage-postgres \
  psql -U dbuser -d postgres -c "DROP DATABASE IF EXISTS ${DB};"

# 4) Remove worktree + branch
git -C "$PRIMARY" worktree remove --force "$WT" || {
  rm -rf "$WT"
  git -C "$PRIMARY" worktree prune
}
git -C "$PRIMARY" branch -D "worktree/slot-${SLOT}" 2>/dev/null || true

# 5) Confirm primary still up
curl -s http://localhost:3001/health || true
git -C "$PRIMARY" worktree list
```

---

## Manual create process (if setup script unavailable)

### 1. Create worktree

```bash
PRIMARY="$(git rev-parse --show-toplevel)"
mkdir -p "$(dirname "$PRIMARY")/worktrees"
# Cannot check out the same branch in two worktrees — use a new branch name
git worktree add -b worktree/slot-1 \
  "$(dirname "$PRIMARY")/worktrees/monorepo-slot-1" HEAD
WT="$(dirname "$PRIMARY")/worktrees/monorepo-slot-1"
```

### 2. Copy env files from primary

```bash
cp "$PRIMARY/.env" "$WT/.env"
cp "$PRIMARY/.env.local" "$WT/.env.local"
cp "$PRIMARY/apps/web-crm/.env.local" "$WT/apps/web-crm/.env.local"
cp "$PRIMARY/apps/web-funnel/.env.local" "$WT/apps/web-funnel/.env.local"
cp "$PRIMARY/apps/server-crm/.env.local" "$WT/apps/server-crm/.env.local"
```

### 3. Create isolated database

```bash
docker exec -e PGPASSWORD=dbpassword future-mortgage-postgres \
  psql -U dbuser -d postgres \
  -c "CREATE DATABASE dbname_wt1 OWNER dbuser;"
```

Reuse the same Postgres **container** and Redis **container**; only change
DB name / Redis logical DB index so data and job queues do not collide.

### 4. Rewrite env for slot ports

In `$WT/.env` set (slot 1 example):

```bash
PORT=3101
ADMIN_URL=http://localhost:3100/admin
WEB_FUNNEL_URL=http://localhost:4301
WEB_CRM_PORT=3100
WEB_FUNNEL_PORT=4301
REDIS_URL=redis://localhost:6379/1
DB_NAME=dbname_wt1
DATABASE_URL=postgresql://dbuser:dbpassword@localhost:5432/dbname_wt1
NX_PUBLIC_API_URL=http://localhost:3101
NX_PUBLIC_SERVER_CRM_SOCKET_URL=http://localhost:3101
SESSION_COOKIE_NAME=auth-token-wt1
```

In `$WT/.env.local`:

```bash
FRONTEND_URL=http://fm.futurewholesale.local:3100
# Leave BASE_URL (ngrok) alone unless you open a second tunnel to :3101
```

Write app-local env (Vite only loads env from the app directory):

`apps/web-crm/.env.local`:

```bash
PORT=3100
WEB_CRM_PORT=3100
WEB_FUNNEL_URL=http://localhost:4301
WEB_FUNNEL_PORT=4301
NX_PUBLIC_API_URL=http://localhost:3101
NX_PUBLIC_SERVER_CRM_SOCKET_URL=http://localhost:3101
NX_PUBLIC_ENV=local
```

`apps/web-funnel/.env.local`:

```bash
WEB_FUNNEL_PORT=4301
PORT=4301
NX_PUBLIC_API_URL=http://localhost:3101
NX_PUBLIC_ENV=local
```

### 5. Make front-end ports env-aware (worktree-local)

**Do not commit these with feature work** unless promoting env-aware defaults.

`apps/web-crm/webpack.config.js` — `devServer.port` and `/apply` proxy:

```js
port: Number(process.env.PORT || process.env.WEB_CRM_PORT || 3000),
// ...
target:
  process.env.WEB_FUNNEL_PROXY_TARGET ||
  process.env.WEB_FUNNEL_URL ||
  'http://localhost:4201',
```

`apps/web-funnel/vite.config.ts` — `server.port` / `preview.port`:

```ts
port: Number(process.env.WEB_FUNNEL_PORT || process.env.PORT || 4201),
```

`apps/web-crm/project.json` serve env:

```json
"PORT": "3100",
"WEB_CRM_PORT": "3100",
"WEB_FUNNEL_URL": "http://localhost:4301",
"WEB_FUNNEL_PORT": "4301"
```

### 6. Install, migrate, seed

```bash
cd "$WT"
# If leftover node_modules symlink from older setup: rm -f node_modules
yarn install   # own node_modules; husky postinstall — do not skip
yarn prisma:sync
yarn nx run database:seed
yarn nx run database:seed-du-test-cases   # Fannie Mae DU test loans
yarn nx run database:seed-lpa-test-cases  # Freddie Mac LPA test loans
```

### 7. Serve

```bash
export PORT=3101 WEB_CRM_PORT=3100 WEB_FUNNEL_PORT=4301
export WEB_FUNNEL_URL=http://localhost:4301
export NX_PUBLIC_API_URL=http://localhost:3101
export NX_PUBLIC_SERVER_CRM_SOCKET_URL=http://localhost:3101
export DATABASE_URL=postgresql://dbuser:dbpassword@localhost:5432/dbname_wt1
export REDIS_URL=redis://localhost:6379/1
export SESSION_COOKIE_NAME=auth-token-wt1
export FRONTEND_URL=http://fm.futurewholesale.local:3100
export NODE_OPTIONS="--inspect=9230"

yarn nx run-many --target=serve
```

---

## Do not

- Point the worktree at the primary `DATABASE_URL` (`dbname`) if you plan to seed or migrate
- Reuse `SESSION_COOKIE_NAME=auth-token` across slots on the same host
- Commit worktree-only port patches / `.env*` / `serve-worktree.sh` / `.worktree-slot` as feature commits
- Use preview_* tools (subdomain tenancy requires `*.futurewholesale.local`)
- Run destroy against the primary checkout or ports 3000/3001/4201
- Drop `dbname` when tearing down a worktree
- Stop after setup when `$ARGUMENTS` still contains a coding task
- Run `./serve-worktree.sh` in the foreground, or wait on health/compile before starting a follow-on task
- Ask for slot/branch/name when defaults work
- Edit files in the primary checkout after create — work in `$WT`

## Why each isolation knob

| Knob | Why |
|------|-----|
| Ports | Avoid EADDRINUSE against primary webpack/vite/node |
| Separate Postgres DB | Safe migrate/seed without wiping primary data |
| Redis DB index | BullMQ / cache keys do not steal jobs from primary |
| SESSION_COOKIE_NAME | Browser cookies ignore port; same name collides on `*.futurewholesale.local` |
| FRONTEND_URL | Server redirects / emails must hit this slot’s web port |
| NX_PUBLIC_API_URL / SOCKET | Browser must talk to this slot’s API |
| WEB_FUNNEL_URL | web-crm `/apply` proxy + server funnel links |
| Node inspect port | Primary already binds `9229` |

## Notes from first successful dry-run (slot 1)

- Worktree path: `../worktrees/monorepo-slot-1`
- Both stacks healthy simultaneously: primary `3000/3001/4201` + worktree `3100/3101/4301`
- API health: `{"status":"healthy","database":"connected",...}`
- Seed: `yarn nx run database:seed` against `dbname_wt1` succeeds with standard tenants, then Fannie DU (`database:seed-du-test-cases`) and Freddie LPA (`database:seed-lpa-test-cases`) test loans
- Inspector warning `Starting inspector on localhost:9229 failed` is expected if primary is up — set `NODE_OPTIONS=--inspect=9230` (setup script does this)
- Empty `apps/*/.env.local` in primary is fine; setup overwrites worktree app env with port wiring

## Optional: promote env-aware ports to main

If the team wants worktrees without patching configs every time, land this on main (backwards-compatible defaults):

1. `apps/web-crm/webpack.config.js` — read `PORT` / `WEB_CRM_PORT` / `WEB_FUNNEL_URL`
2. `apps/web-funnel/vite.config.ts` — read `WEB_FUNNEL_PORT` / `PORT`

Then the setup script only needs env rewrites + DB create + install/seed.

User arguments: $ARGUMENTS
````

#### `~/.ai/oc_skills/monorepo-worktree/scripts/destroy-worktree.sh`

```bash file=~/.ai/oc_skills/monorepo-worktree/scripts/destroy-worktree.sh mode=755
#!/usr/bin/env bash
# destroy-worktree.sh — Tear down an isolated monorepo worktree cleanly.
#
# Usage:
#   ./destroy-worktree.sh <slot>                 # e.g. 1 → monorepo-slot-1
#   ./destroy-worktree.sh --name <name>          # e.g. my-feature → monorepo-my-feature
#   ./destroy-worktree.sh --path <abs-or-rel>    # explicit worktree path
#   ./destroy-worktree.sh --all                  # every monorepo-* under ../worktrees/
#   ./destroy-worktree.sh list                   # show discoverable worktrees (no destroy)
#
# Aliases accepted as $1: destroy | remove | teardown | rm | clean | list
#   ./destroy-worktree.sh destroy 1
#   ./destroy-worktree.sh remove --name slot-1
#
# Options:
#   --keep-db       Do not DROP the isolated Postgres database
#   --keep-branch   Do not delete the worktree/* git branch
#   --keep-redis    Do not FLUSHDB the slot's Redis logical DB
#   --force         git worktree remove --force (discard uncommitted worktree files)
#   --yes           Skip interactive confirmation (still prints plan)
#
# Safety (hard rules — script will refuse otherwise):
#   - Never touch primary ports 3000 / 3001 / 4201
#   - Never DROP database "dbname" (primary)
#   - Never remove the primary monorepo checkout
#   - Only kill listeners on the worktree's own ports (or PIDs rooted in WT path)
#   - Only DROP databases matching dbname_wt{N}

set -euo pipefail

KEEP_DB=0
KEEP_BRANCH=0
KEEP_REDIS=0
FORCE=0
YES=0
MODE=""          # slot | name | path | all | list
SLOT=""
NAME=""
WT_PATH_ARG=""
ACTION="destroy" # destroy | list

usage() {
  sed -n '2,35p' "$0" | sed 's/^# \?//'
  exit 1
}

# --- parse args ---
ARGS=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    destroy|remove|teardown|rm|clean)
      ACTION="destroy"
      shift
      ;;
    list|ls)
      ACTION="list"
      shift
      ;;
    --name)
      MODE="name"
      NAME="${2:-}"
      [[ -n "${NAME}" ]] || usage
      shift 2
      ;;
    --path)
      MODE="path"
      WT_PATH_ARG="${2:-}"
      [[ -n "${WT_PATH_ARG}" ]] || usage
      shift 2
      ;;
    --all)
      MODE="all"
      shift
      ;;
    --keep-db) KEEP_DB=1; shift ;;
    --keep-branch) KEEP_BRANCH=1; shift ;;
    --keep-redis) KEEP_REDIS=1; shift ;;
    --force) FORCE=1; shift ;;
    --yes|-y) YES=1; shift ;;
    -h|--help) usage ;;
    --*)
      echo "Unknown option: $1"
      usage
      ;;
    *)
      ARGS+=("$1")
      shift
      ;;
  esac
done

if [[ ${#ARGS[@]} -gt 0 ]]; then
  if [[ -z "${MODE}" && "${ARGS[0]}" =~ ^[1-9][0-9]*$ ]]; then
    MODE="slot"
    SLOT="${ARGS[0]}"
  elif [[ -z "${MODE}" ]]; then
    # treat bare token as name
    MODE="name"
    NAME="${ARGS[0]}"
  fi
fi

if [[ "${ACTION}" == "list" ]]; then
  MODE="list"
fi

if [[ -z "${MODE}" ]]; then
  usage
fi

# --- resolve primary + worktrees root ---
# User-scoped skill — do NOT resolve monorepo from script path.
# Priority: MONOREPO_ROOT env → cwd git main worktree → fail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
resolve_primary() {
  if [[ -n "${MONOREPO_ROOT:-}" && -d "${MONOREPO_ROOT}" ]]; then
    echo "$(cd "${MONOREPO_ROOT}" && pwd)"
    return 0
  fi
  if ! git rev-parse --git-dir >/dev/null 2>&1; then
    echo "ERROR: not inside a monorepo git checkout. cd into it or set MONOREPO_ROOT." >&2
    return 1
  fi
  local main_wt
  main_wt="$(git worktree list --porcelain 2>/dev/null | awk '/^worktree /{print $2; exit}')"
  if [[ -n "${main_wt}" && -d "${main_wt}" ]]; then
    echo "${main_wt}"
    return 0
  fi
  git rev-parse --path-format=absolute --show-toplevel 2>/dev/null
}
PRIMARY="$(resolve_primary)"
PRIMARY="$(cd "${PRIMARY}" && pwd)"
WORKTREES_ROOT="$(dirname "${PRIMARY}")/worktrees"

is_primary_path() {
  local p
  p="$(cd "$1" 2>/dev/null && pwd || echo "$1")"
  [[ "${p}" == "${PRIMARY}" ]]
}

# --- discovery helpers ---
read_marker() {
  # sets SLOT NAME WEB_PORT API_PORT FUNNEL_PORT DB_NAME REDIS_URL INSPECT_PORT from .worktree-slot
  local marker="$1/.worktree-slot"
  SLOT="" NAME="" WEB_PORT="" API_PORT="" FUNNEL_PORT="" DB_NAME="" REDIS_URL="" INSPECT_PORT=""
  if [[ -f "${marker}" ]]; then
    # shellcheck disable=SC1090
    set -a
    # only allow KEY=VALUE lines
    # shellcheck disable=SC1091
    source <(grep -E '^[A-Z_]+=.*' "${marker}" || true)
    set +a
  fi
}

infer_from_path() {
  local path="$1"
  read_marker "${path}"
  if [[ -z "${NAME}" ]]; then
    NAME="$(basename "${path}" | sed 's/^monorepo-//')"
  fi
  if [[ -z "${SLOT}" && "${NAME}" =~ ^slot-([1-9][0-9]*)$ ]]; then
    SLOT="${BASH_REMATCH[1]}"
  fi
  if [[ -n "${SLOT}" ]]; then
    WEB_PORT="${WEB_PORT:-$((3000 + SLOT * 100))}"
    API_PORT="${API_PORT:-$((3001 + SLOT * 100))}"
    FUNNEL_PORT="${FUNNEL_PORT:-$((4201 + SLOT * 100))}"
    DB_NAME="${DB_NAME:-dbname_wt${SLOT}}"
    REDIS_URL="${REDIS_URL:-redis://localhost:6379/${SLOT}}"
    INSPECT_PORT="${INSPECT_PORT:-$((9229 + SLOT))}"
  fi
}

list_worktrees() {
  echo "Primary: ${PRIMARY}"
  echo "Worktrees root: ${WORKTREES_ROOT}"
  echo ""
  git -C "${PRIMARY}" worktree list
  echo ""
  if [[ -d "${WORKTREES_ROOT}" ]]; then
    echo "Discovered monorepo-* dirs:"
    for d in "${WORKTREES_ROOT}"/monorepo-*; do
      [[ -d "$d" ]] || continue
      if is_primary_path "$d"; then
        continue
      fi
      infer_from_path "$d"
      local ports="?"
      if [[ -n "${WEB_PORT:-}" ]]; then
        ports="${WEB_PORT}/${API_PORT}/${FUNNEL_PORT}"
      fi
      local listening=""
      for p in ${WEB_PORT:-} ${API_PORT:-} ${FUNNEL_PORT:-}; do
        [[ -n "$p" ]] || continue
        if lsof -nP -iTCP:"$p" -sTCP:LISTEN >/dev/null 2>&1; then
          listening+="${p} "
        fi
      done
      echo "  - $d"
      echo "      name=${NAME:-?} slot=${SLOT:-?} ports=${ports} db=${DB_NAME:-?} listening=${listening:-none}"
    done
  else
    echo "(no ${WORKTREES_ROOT} directory)"
  fi
}

if [[ "${MODE}" == "list" || "${ACTION}" == "list" ]]; then
  list_worktrees
  exit 0
fi

# --- build target list ---
TARGETS=()

resolve_one() {
  local path="$1"
  path="$(cd "${path}" 2>/dev/null && pwd || true)"
  if [[ -z "${path}" || ! -d "${path}" ]]; then
    echo "ERROR: worktree path not found: $1" >&2
    return 1
  fi
  if is_primary_path "${path}"; then
    echo "ERROR: refusing to destroy primary monorepo: ${path}" >&2
    return 1
  fi
  # Prefer paths under worktrees/ or registered git worktrees that are not primary
  TARGETS+=("${path}")
}

case "${MODE}" in
  slot)
    NAME="slot-${SLOT}"
    resolve_one "${WORKTREES_ROOT}/monorepo-${NAME}"
    ;;
  name)
    resolve_one "${WORKTREES_ROOT}/monorepo-${NAME}"
    ;;
  path)
    resolve_one "${WT_PATH_ARG}"
    ;;
  all)
    shopt -s nullglob
    found=0
    for d in "${WORKTREES_ROOT}"/monorepo-*; do
      if is_primary_path "$d"; then
        continue
      fi
      TARGETS+=("$(cd "$d" && pwd)")
      found=1
    done
    shopt -u nullglob
    if [[ ${found} -eq 0 ]]; then
      echo "No monorepo-* worktrees found under ${WORKTREES_ROOT}"
      exit 0
    fi
    ;;
  *)
    usage
    ;;
esac

if [[ ${#TARGETS[@]} -eq 0 ]]; then
  echo "ERROR: nothing to destroy."
  exit 1
fi

# --- kill helpers ---
PRIMARY_PORTS=(3000 3001 4201)

is_primary_port() {
  local p="$1"
  for pp in "${PRIMARY_PORTS[@]}"; do
    [[ "$p" == "$pp" ]] && return 0
  done
  return 1
}

kill_port() {
  local port="$1"
  if is_primary_port "${port}"; then
    echo "  REFUSE kill primary port ${port}"
    return 0
  fi
  local pids
  pids="$(lsof -nP -iTCP:"${port}" -sTCP:LISTEN -t 2>/dev/null || true)"
  if [[ -z "${pids}" ]]; then
    echo "  port ${port}: nothing listening"
    return 0
  fi
  echo "  port ${port}: killing PIDs ${pids//$'\n'/ }"
  # kill process group leaders gently then hard
  for pid in ${pids}; do
    kill -TERM "${pid}" 2>/dev/null || true
  done
  sleep 1
  for pid in ${pids}; do
    if kill -0 "${pid}" 2>/dev/null; then
      kill -KILL "${pid}" 2>/dev/null || true
    fi
  done
}

kill_tree_by_cwd() {
  # Best-effort: kill node/yarn/nx processes whose cwd is under the worktree
  local wt="$1"
  local pid cwd cmd
  # macOS: lsof +cwd; Linux: /proc
  if [[ "$(uname -s)" == "Darwin" ]]; then
    while read -r pid; do
      [[ -n "${pid}" ]] || continue
      cwd="$(lsof -a -p "${pid}" -d cwd -Fn 2>/dev/null | sed -n 's/^n//p' | head -1 || true)"
      if [[ -n "${cwd}" && "${cwd}" == "${wt}"* ]]; then
        cmd="$(ps -p "${pid}" -o comm= 2>/dev/null || true)"
        case "${cmd}" in
          node|yarn|npm|nx|vite|webpack*|esbuild)
            echo "  cwd-match PID ${pid} (${cmd}) under ${wt}"
            kill -TERM "${pid}" 2>/dev/null || true
            ;;
        esac
      fi
    done < <(pgrep -u "$(id -u)" -f 'node|yarn|nx|vite|webpack' 2>/dev/null || true)
    sleep 1
  fi
}

drop_db() {
  local db="$1"
  if [[ -z "${db}" ]]; then
    echo "  skip DB drop (unknown name)"
    return 0
  fi
  if [[ "${db}" == "dbname" || ! "${db}" =~ ^dbname_wt[1-9][0-9]*$ ]]; then
    echo "  REFUSE to drop non-worktree database: ${db}"
    return 1
  fi
  if ! docker ps --format '{{.Names}}' | grep -qx 'future-mortgage-postgres'; then
    echo "  WARN: future-mortgage-postgres not running; cannot drop ${db}"
    return 0
  fi
  echo "  dropping database ${db}..."
  # terminate backends then drop
  docker exec -e PGPASSWORD=dbpassword future-mortgage-postgres \
    psql -U dbuser -d postgres -v ON_ERROR_STOP=1 -c \
    "SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname = '${db}' AND pid <> pg_backend_pid();" \
    >/dev/null 2>&1 || true
  docker exec -e PGPASSWORD=dbpassword future-mortgage-postgres \
    psql -U dbuser -d postgres -c "DROP DATABASE IF EXISTS ${db};"
}

flush_redis_db() {
  local slot="$1"
  if [[ -z "${slot}" || ! "${slot}" =~ ^[1-9][0-9]*$ ]]; then
    echo "  skip redis flush (unknown slot)"
    return 0
  fi
  if ! docker ps --format '{{.Names}}' | grep -qx 'future-mortgage-redis'; then
    echo "  WARN: future-mortgage-redis not running; skip flush db ${slot}"
    return 0
  fi
  echo "  redis FLUSHDB on logical DB ${slot}..."
  docker exec future-mortgage-redis redis-cli -n "${slot}" FLUSHDB >/dev/null
}

remove_git_worktree() {
  local path="$1"
  local force_flag=()
  [[ "${FORCE}" -eq 1 ]] && force_flag=(--force)

  if git -C "${PRIMARY}" worktree list --porcelain | grep -q "^worktree ${path}$"; then
    echo "  git worktree remove ${path} ${force_flag[*]:-}"
    # If dirty and not forced, try force after unlock
    if ! git -C "${PRIMARY}" worktree remove "${force_flag[@]}" "${path}" 2>/tmp/wt-rm-err.$$; then
      echo "  worktree remove failed, retrying with --force..."
      cat /tmp/wt-rm-err.$$ >&2 || true
      git -C "${PRIMARY}" worktree remove --force "${path}" || {
        echo "  WARN: git worktree remove failed; removing directory manually"
        rm -rf "${path}"
        git -C "${PRIMARY}" worktree prune
      }
    fi
    rm -f /tmp/wt-rm-err.$$
  elif [[ -d "${path}" ]]; then
    echo "  path not registered as git worktree; removing directory ${path}"
    rm -rf "${path}"
    git -C "${PRIMARY}" worktree prune 2>/dev/null || true
  else
    echo "  path already gone: ${path}"
  fi
}

delete_branch() {
  local path="$1"
  local branch name
  # Prefer branch currently (or was) associated via marker name
  infer_from_path "${path}" 2>/dev/null || true
  name="${NAME:-$(basename "${path}" | sed 's/^monorepo-//')}"
  branch="worktree/${name}"
  if git -C "${PRIMARY}" show-ref --verify --quiet "refs/heads/${branch}"; then
    # refuse if checked out elsewhere
    if git -C "${PRIMARY}" worktree list | grep -q "\[${branch}\]"; then
      echo "  branch ${branch} still checked out elsewhere; skip delete"
      return 0
    fi
    echo "  deleting branch ${branch}"
    git -C "${PRIMARY}" branch -D "${branch}" || true
  else
    echo "  no local branch ${branch}"
  fi
}

destroy_one() {
  local path="$1"
  echo ""
  echo "───────────────────────────────────────────────────────────"
  echo " Destroying: ${path}"
  echo "───────────────────────────────────────────────────────────"

  if is_primary_path "${path}"; then
    echo "ERROR: refusing primary path"
    return 1
  fi

  infer_from_path "${path}"

  echo "  slot=${SLOT:-?} name=${NAME:-?} web=${WEB_PORT:-?} api=${API_PORT:-?} funnel=${FUNNEL_PORT:-?}"
  echo "  db=${DB_NAME:-?} redis=${REDIS_URL:-?}"

  # 1) Stop services on worktree ports
  echo "→ Stopping listeners"
  for p in ${WEB_PORT:-} ${API_PORT:-} ${FUNNEL_PORT:-} ${INSPECT_PORT:-}; do
    [[ -n "${p}" ]] || continue
    kill_port "${p}"
  done
  # Also stop anything still rooted in this cwd (nx parent, etc.)
  if [[ -d "${path}" ]]; then
    kill_tree_by_cwd "${path}"
  fi
  sleep 0.5

  # Verify ports free
  for p in ${WEB_PORT:-} ${API_PORT:-} ${FUNNEL_PORT:-}; do
    [[ -n "${p}" ]] || continue
    if lsof -nP -iTCP:"${p}" -sTCP:LISTEN >/dev/null 2>&1; then
      echo "  WARN: port ${p} still listening after kill; retrying KILL"
      kill_port "${p}"
    fi
  done

  # 2) Redis flush for slot
  if [[ "${KEEP_REDIS}" -eq 0 && -n "${SLOT:-}" ]]; then
    echo "→ Redis cleanup"
    flush_redis_db "${SLOT}"
  else
    echo "→ Redis cleanup skipped"
  fi

  # 3) Drop isolated DB
  if [[ "${KEEP_DB}" -eq 0 ]]; then
    echo "→ Postgres cleanup"
    drop_db "${DB_NAME:-}"
  else
    echo "→ Postgres cleanup skipped (--keep-db)"
  fi

  # 4) Remove git worktree + files
  echo "→ Git worktree remove"
  # Capture branch name before path disappears
  local branch_name="${NAME:-}"
  remove_git_worktree "${path}"

  # 5) Delete worktree/* branch
  if [[ "${KEEP_BRANCH}" -eq 0 ]]; then
    echo "→ Branch cleanup"
    # path may be gone; use captured name
    if [[ -n "${branch_name}" ]]; then
      local branch="worktree/${branch_name}"
      if git -C "${PRIMARY}" show-ref --verify --quiet "refs/heads/${branch}"; then
        if git -C "${PRIMARY}" worktree list | grep -q "\[${branch}\]"; then
          echo "  branch ${branch} still checked out; skip"
        else
          echo "  deleting branch ${branch}"
          git -C "${PRIMARY}" branch -D "${branch}" || true
        fi
      else
        echo "  no local branch ${branch}"
      fi
    fi
  else
    echo "→ Branch cleanup skipped (--keep-branch)"
  fi

  echo "✓ Destroy complete for ${NAME:-$path}"
}

# --- plan + confirm ---
echo "═══════════════════════════════════════════════════════════"
echo " Monorepo worktree DESTROY"
echo "═══════════════════════════════════════════════════════════"
echo "  primary:      ${PRIMARY}"
echo "  targets:      ${#TARGETS[@]}"
echo "  keep-db:      ${KEEP_DB}"
echo "  keep-branch:  ${KEEP_BRANCH}"
echo "  keep-redis:   ${KEEP_REDIS}"
echo "  force:        ${FORCE}"
for t in "${TARGETS[@]}"; do
  infer_from_path "$t"
  echo "  - $t  (slot=${SLOT:-?} db=${DB_NAME:-?} ports=${WEB_PORT:-?}/${API_PORT:-?}/${FUNNEL_PORT:-?})"
done
echo "═══════════════════════════════════════════════════════════"

if [[ "${YES}" -ne 1 ]]; then
  if [[ -t 0 ]]; then
    read -r -p "Proceed with destroy? [y/N] " ans
    case "${ans}" in
      y|Y|yes|YES) ;;
      *) echo "Aborted."; exit 1 ;;
    esac
  else
    echo "Non-interactive shell: pass --yes to confirm destroy."
    exit 1
  fi
fi

for t in "${TARGETS[@]}"; do
  destroy_one "$t"
done

echo ""
echo "→ Verifying primary stack still intact"
for p in 3000 3001 4201; do
  if lsof -nP -iTCP:"$p" -sTCP:LISTEN >/dev/null 2>&1; then
    echo "  primary port $p: still listening (ok)"
  else
    echo "  primary port $p: not listening (ok if primary wasn't running)"
  fi
done
if curl -s -m 2 http://localhost:3001/health >/dev/null 2>&1; then
  echo "  primary API :3001 health OK"
fi

echo ""
echo "→ Remaining worktrees"
git -C "${PRIMARY}" worktree list
echo ""
echo "Done."
```

#### `~/.ai/oc_skills/monorepo-worktree/scripts/setup-worktree.sh`

```bash file=~/.ai/oc_skills/monorepo-worktree/scripts/setup-worktree.sh mode=755
#!/usr/bin/env bash
# setup-worktree.sh — Create an isolated monorepo worktree on alternate ports.
#
# Usage:
#   ./setup-worktree.sh <slot> [branch] [worktree-name]
#
# Examples:
#   ./setup-worktree.sh 1
#   ./setup-worktree.sh 2 feature/my-branch my-feature
#   ./setup-worktree.sh 1 HEAD immutable-email
#
# Slot 0 is reserved for the primary checkout (ports 3000/3001/4201).
# Slot N (>=1) uses:
#   web-crm     = 3000 + N*100
#   server-crm  = 3001 + N*100
#   web-funnel  = 4201 + N*100
#   postgres DB = dbname_wt{N}
#   redis DB #  = N
#   cookie name = auth-token-wt{N}
#
# Prerequisites: docker postgres (future-mortgage-postgres), redis, yarn, git.
# Env sources: copies .env / .env.local from the primary monorepo checkout.

set -euo pipefail

SLOT="${1:-}"
BRANCH_OR_REF="${2:-HEAD}"
NAME="${3:-slot-${SLOT}}"

if [[ -z "${SLOT}" || ! "${SLOT}" =~ ^[1-9][0-9]*$ ]]; then
  echo "Usage: $0 <slot>=1..N [branch|ref=HEAD] [name=slot-N]"
  echo "  Slot must be an integer >= 1 (slot 0 = primary checkout)."
  exit 1
fi

# Resolve primary monorepo (user-scoped skill — do NOT use script path).
# Priority: MONOREPO_ROOT env → cwd git common dir → cwd toplevel
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
resolve_primary() {
  if [[ -n "${MONOREPO_ROOT:-}" && -d "${MONOREPO_ROOT}" ]]; then
    echo "$(cd "${MONOREPO_ROOT}" && pwd)"
    return 0
  fi
  local common
  if common="$(git rev-parse --path-format=absolute --git-common-dir 2>/dev/null)"; then
    # common dir is <repo>/.git (or .git file target); primary checkout is parent of .git
    local root
    root="$(dirname "${common}")"
    # If we're inside a linked worktree, common dir still points at main .git
    # Prefer the main worktree path from worktree list (first entry)
    local main_wt
    main_wt="$(git worktree list --porcelain 2>/dev/null | awk '/^worktree /{print $2; exit}')"
    if [[ -n "${main_wt}" && -d "${main_wt}" ]]; then
      echo "${main_wt}"
      return 0
    fi
    echo "${root}"
    return 0
  fi
  echo "ERROR: cannot resolve monorepo root. cd into the monorepo or set MONOREPO_ROOT." >&2
  return 1
}
PRIMARY="$(resolve_primary)"

WORKTREES_ROOT="$(dirname "${PRIMARY}")/worktrees"
WT_PATH="${WORKTREES_ROOT}/monorepo-${NAME}"
BRANCH_NAME="worktree/${NAME}"

WEB_PORT=$((3000 + SLOT * 100))
API_PORT=$((3001 + SLOT * 100))
FUNNEL_PORT=$((4201 + SLOT * 100))
DB_NAME="dbname_wt${SLOT}"
REDIS_URL="redis://localhost:6379/${SLOT}"
COOKIE="auth-token-wt${SLOT}"
INSPECT_PORT=$((9229 + SLOT))

echo "═══════════════════════════════════════════════════════════"
echo " Monorepo worktree setup"
echo "═══════════════════════════════════════════════════════════"
echo "  slot:        ${SLOT}"
echo "  name:        ${NAME}"
echo "  path:        ${WT_PATH}"
echo "  base ref:    ${BRANCH_OR_REF}"
echo "  branch:      ${BRANCH_NAME}"
echo "  web-crm:     http://fm.futurewholesale.local:${WEB_PORT}"
echo "  server-crm:  http://localhost:${API_PORT}"
echo "  web-funnel:  http://localhost:${FUNNEL_PORT}/apply/"
echo "  database:    ${DB_NAME}"
echo "  redis:       ${REDIS_URL}"
echo "  cookie:      ${COOKIE}"
echo "  inspect:     ${INSPECT_PORT}"
echo "═══════════════════════════════════════════════════════════"

# --- port free check ---
for p in "${WEB_PORT}" "${API_PORT}" "${FUNNEL_PORT}"; do
  if lsof -nP -iTCP:"${p}" -sTCP:LISTEN >/dev/null 2>&1; then
    echo "ERROR: port ${p} is already in use. Pick another slot or free the port."
    lsof -nP -iTCP:"${p}" -sTCP:LISTEN || true
    exit 1
  fi
done

# --- create worktree ---
mkdir -p "${WORKTREES_ROOT}"
if [[ -d "${WT_PATH}" ]]; then
  echo "Worktree path already exists: ${WT_PATH}"
  echo "Reusing it (will re-apply env / config patches)."
else
  cd "${PRIMARY}"
  # If BRANCH_OR_REF is an existing local branch name and we want a new worktree branch from it:
  git worktree add -b "${BRANCH_NAME}" "${WT_PATH}" "${BRANCH_OR_REF}"
fi

# --- copy env files from primary ---
copy_env() {
  local src="$1" dest="$2"
  if [[ -f "${src}" ]]; then
    cp "${src}" "${dest}"
    echo "  copied $(basename "${src}") → ${dest}"
  else
    echo "  WARN: missing ${src}"
  fi
}

# Yarn installs a real node_modules in the worktree. Drop a leftover symlink
# from older setup so install does not write into the primary tree.
drop_node_modules_symlink() {
  local dest="${1}/node_modules"
  if [[ -L "${dest}" ]]; then
    rm -f "${dest}"
    echo "  removed leftover node_modules symlink"
  fi
}
echo "Copying env files from ${PRIMARY}..."
copy_env "${PRIMARY}/.env" "${WT_PATH}/.env"
copy_env "${PRIMARY}/.env.local" "${WT_PATH}/.env.local"
copy_env "${PRIMARY}/apps/web-crm/.env.local" "${WT_PATH}/apps/web-crm/.env.local"
copy_env "${PRIMARY}/apps/web-funnel/.env.local" "${WT_PATH}/apps/web-funnel/.env.local"
copy_env "${PRIMARY}/apps/server-crm/.env.local" "${WT_PATH}/apps/server-crm/.env.local"

# --- create isolated postgres database ---
echo "Ensuring postgres database ${DB_NAME}..."
if ! docker ps --format '{{.Names}}' | grep -qx 'future-mortgage-postgres'; then
  echo "ERROR: container future-mortgage-postgres is not running."
  echo "Start it with: docker compose -f docker-compose.database.yml up -d"
  exit 1
fi
EXISTS=$(docker exec -e PGPASSWORD=dbpassword future-mortgage-postgres \
  psql -U dbuser -d postgres -tc "SELECT 1 FROM pg_database WHERE datname = '${DB_NAME}'" | tr -d '[:space:]')
if [[ "${EXISTS}" != "1" ]]; then
  docker exec -e PGPASSWORD=dbpassword future-mortgage-postgres \
    psql -U dbuser -d postgres -c "CREATE DATABASE ${DB_NAME} OWNER dbuser;"
  echo "  created ${DB_NAME}"
else
  echo "  ${DB_NAME} already exists"
fi

# --- patch root .env / .env.local ---
python3 - "${WT_PATH}" "${WEB_PORT}" "${API_PORT}" "${FUNNEL_PORT}" "${DB_NAME}" "${SLOT}" "${COOKIE}" <<'PY'
import re, sys
from pathlib import Path

wt, web, api, funnel, db, slot, cookie = sys.argv[1:8]
web, api, funnel, slot = int(web), int(api), int(funnel), int(slot)

def set_kv(text: str, key: str, value: str) -> str:
    pat = re.compile(rf"^{re.escape(key)}=.*$", re.M)
    line = f"{key}={value}"
    if pat.search(text):
        return pat.sub(line, text)
    if text and not text.endswith("\n"):
        text += "\n"
    return text + line + "\n"

env_path = Path(wt) / ".env"
env = env_path.read_text() if env_path.exists() else ""
for k, v in {
    "PORT": str(api),
    "ADMIN_URL": f"http://localhost:{web}/admin",
    "WEB_FUNNEL_URL": f"http://localhost:{funnel}",
    "WEB_CRM_PORT": str(web),
    "WEB_FUNNEL_PORT": str(funnel),
    "REDIS_URL": f"redis://localhost:6379/{slot}",
    "DB_NAME": db,
    "DATABASE_URL": f"postgresql://dbuser:dbpassword@localhost:5432/{db}",
    "NX_PUBLIC_API_URL": f"http://localhost:{api}",
    "NX_PUBLIC_SERVER_CRM_SOCKET_URL": f"http://localhost:{api}",
    "SESSION_COOKIE_NAME": cookie,
}.items():
    env = set_kv(env, k, v)
env_path.write_text(env)

local_path = Path(wt) / ".env.local"
local = local_path.read_text() if local_path.exists() else ""
local = set_kv(local, "FRONTEND_URL", f"http://fm.futurewholesale.local:{web}")
local_path.write_text(local)

# App-local env so Vite/webpack pick up ports without relying on cwd
(Path(wt) / "apps/web-crm/.env.local").write_text(
    f"""PORT={web}
WEB_CRM_PORT={web}
WEB_FUNNEL_URL=http://localhost:{funnel}
WEB_FUNNEL_PORT={funnel}
NX_PUBLIC_API_URL=http://localhost:{api}
NX_PUBLIC_SERVER_CRM_SOCKET_URL=http://localhost:{api}
NX_PUBLIC_ENV=local
"""
)
(Path(wt) / "apps/web-funnel/.env.local").write_text(
    f"""WEB_FUNNEL_PORT={funnel}
PORT={funnel}
NX_PUBLIC_API_URL=http://localhost:{api}
NX_PUBLIC_ENV=local
"""
)
print("  patched .env, .env.local, app .env.local files")
PY

# --- make webpack + vite + project.json env-aware / slot-ported ---
python3 - "${WT_PATH}" "${WEB_PORT}" "${FUNNEL_PORT}" <<'PY'
from pathlib import Path
import sys, re

wt, web, funnel = sys.argv[1], sys.argv[2], sys.argv[3]
web, funnel = int(web), int(funnel)

# webpack.config.js
wp = Path(wt) / "apps/web-crm/webpack.config.js"
t = wp.read_text()
t2 = re.sub(
    r"port:\s*Number\(process\.env\.PORT \|\| process\.env\.WEB_CRM_PORT \|\| 3000\),|port:\s*3000,",
    "port: Number(process.env.PORT || process.env.WEB_CRM_PORT || 3000),",
    t,
    count=1,
)
t2 = re.sub(
    r"target:\s*\n\s*process\.env\.WEB_FUNNEL_PROXY_TARGET \|\|\n\s*process\.env\.WEB_FUNNEL_URL \|\|\n\s*'http://localhost:4201',|target:\s*'http://localhost:4201',",
    "target:\n          process.env.WEB_FUNNEL_PROXY_TARGET ||\n          process.env.WEB_FUNNEL_URL ||\n          'http://localhost:4201',",
    t2,
    count=1,
)
if t2 != t:
    wp.write_text(t2)
    print("  patched apps/web-crm/webpack.config.js (env-aware ports)")
else:
    # force simple replace if still plain
    if "port: 3000" in t:
        t = t.replace("port: 3000,", "port: Number(process.env.PORT || process.env.WEB_CRM_PORT || 3000),", 1)
        t = t.replace(
            "target: 'http://localhost:4201',",
            "target:\n          process.env.WEB_FUNNEL_PROXY_TARGET ||\n          process.env.WEB_FUNNEL_URL ||\n          'http://localhost:4201',",
            1,
        )
        wp.write_text(t)
        print("  patched apps/web-crm/webpack.config.js")
    else:
        print("  webpack.config.js already env-aware (or unexpected format)")

# vite.config.ts
vt = Path(wt) / "apps/web-funnel/vite.config.ts"
v = vt.read_text()
v2 = v.replace(
    "port: 4201,",
    "port: Number(process.env.WEB_FUNNEL_PORT || process.env.PORT || 4201),",
)
if v2 != v:
    vt.write_text(v2)
    print("  patched apps/web-funnel/vite.config.ts (env-aware ports)")
else:
    print("  vite.config.ts already env-aware (or unexpected format)")

# web-crm project.json — set PORT env for serve target
pj = Path(wt) / "apps/web-crm/project.json"
p = pj.read_text()
p2 = re.sub(r'"PORT":\s*"\d+"', f'"PORT": "{web}"', p)
if '"WEB_FUNNEL_URL"' not in p2:
    p2 = p2.replace(
        f'"PORT": "{web}"',
        f'"PORT": "{web}",\n          "WEB_CRM_PORT": "{web}",\n          "WEB_FUNNEL_URL": "http://localhost:{funnel}",\n          "WEB_FUNNEL_PORT": "{funnel}"',
    )
else:
    p2 = re.sub(r'"WEB_CRM_PORT":\s*"\d+"', f'"WEB_CRM_PORT": "{web}"', p2)
    p2 = re.sub(r'"WEB_FUNNEL_PORT":\s*"\d+"', f'"WEB_FUNNEL_PORT": "{funnel}"', p2)
    p2 = re.sub(
        r'"WEB_FUNNEL_URL":\s*"[^"]*"',
        f'"WEB_FUNNEL_URL": "http://localhost:{funnel}"',
        p2,
    )
if p2 != p:
    pj.write_text(p2)
    print("  patched apps/web-crm/project.json serve ports")
else:
    print("  project.json ports already set")

print(
    "\n  NOTE: webpack/vite/project.json patches are worktree-local infrastructure.\n"
    "  Do NOT commit them with feature work unless promoting env-aware defaults to main."
)
PY

# Write a small marker file (gitignored pattern via name)
cat > "${WT_PATH}/.worktree-slot" <<EOF
SLOT=${SLOT}
NAME=${NAME}
WEB_PORT=${WEB_PORT}
API_PORT=${API_PORT}
FUNNEL_PORT=${FUNNEL_PORT}
DB_NAME=${DB_NAME}
REDIS_URL=${REDIS_URL}
SESSION_COOKIE_NAME=${COOKIE}
INSPECT_PORT=${INSPECT_PORT}
FRONTEND_URL=http://fm.futurewholesale.local:${WEB_PORT}
CREATED_AT=$(date -u +%Y-%m-%dT%H:%M:%SZ)
EOF
echo "  wrote .worktree-slot"

# --- yarn (husky) + prisma + seed ---
cd "${WT_PATH}"
drop_node_modules_symlink "${WT_PATH}"
echo "yarn install (husky postinstall wires pre-push)..."
yarn install

echo "yarn prisma:sync..."
yarn prisma:sync

echo "yarn nx run database:seed..."
yarn nx run database:seed

echo "yarn nx run database:seed-du-test-cases (Fannie Mae)..."
yarn nx run database:seed-du-test-cases

echo "yarn nx run database:seed-lpa-test-cases (Freddie Mac)..."
yarn nx run database:seed-lpa-test-cases

# --- helper serve script ---
cat > "${WT_PATH}/serve-worktree.sh" <<EOF
#!/usr/bin/env bash
# Start this worktree's stack on its dedicated ports.
set -euo pipefail
cd "\$(dirname "\$0")"
# shellcheck disable=SC1091
set -a
source .env
# .env.local overrides
[[ -f .env.local ]] && source .env.local
set +a
export PORT=${API_PORT}
export WEB_CRM_PORT=${WEB_PORT}
export WEB_FUNNEL_PORT=${FUNNEL_PORT}
export WEB_FUNNEL_URL=http://localhost:${FUNNEL_PORT}
export NX_PUBLIC_API_URL=http://localhost:${API_PORT}
export NX_PUBLIC_SERVER_CRM_SOCKET_URL=http://localhost:${API_PORT}
export DATABASE_URL=postgresql://dbuser:dbpassword@localhost:5432/${DB_NAME}
export REDIS_URL=${REDIS_URL}
export SESSION_COOKIE_NAME=${COOKIE}
export FRONTEND_URL=http://fm.futurewholesale.local:${WEB_PORT}
# Avoid clashing with primary checkout's node inspector on 9229
export NODE_OPTIONS="\${NODE_OPTIONS:-} --inspect=${INSPECT_PORT}"
echo "Starting worktree slot ${SLOT} (all serve targets):"
echo "  CRM     http://fm.futurewholesale.local:${WEB_PORT}"
echo "  API     http://localhost:${API_PORT}"
echo "  Funnel  http://localhost:${FUNNEL_PORT}/apply/"
echo "  Worker  redis DB ${SLOT} (worker-crm)"
exec yarn nx run-many --target=serve
EOF
chmod +x "${WT_PATH}/serve-worktree.sh"

echo ""
echo "═══════════════════════════════════════════════════════════"
echo " DONE — worktree ready"
echo "═══════════════════════════════════════════════════════════"
echo "  cd ${WT_PATH}"
echo "  ./serve-worktree.sh"
echo ""
echo "  Login (same as primary):"
echo "    http://fm.futurewholesale.local:${WEB_PORT}"
echo "    admin@fm.com / admin123 / OTP 1111"
echo "    martin.hansen@trygenius.ai / admin123 / OTP 1111"
echo ""
echo "  Tear down later:"
echo "    # stop serve, then:"
echo "    git -C ${PRIMARY} worktree remove ${WT_PATH}"
echo "    docker exec -e PGPASSWORD=dbpassword future-mortgage-postgres \\"
echo "      psql -U dbuser -d postgres -c \"DROP DATABASE IF EXISTS ${DB_NAME};\""
echo "═══════════════════════════════════════════════════════════"
```

#### `~/.ai/oc_skills/worktree-quick/SKILL.md`

````markdown file=~/.ai/oc_skills/worktree-quick/SKILL.md
---
name: worktree-quick
description: Create or destroy a code-only git worktree for a PR, branch, or new task (fetch + checkout, copies env, yarn install; no DB/ports/seed). Use when the user runs /worktree-quick, "worktree quick", "quick worktree", "code-only worktree", "checkout this PR in a worktree", "/worktree-quick add dark mode", or wants a disposable worktree to start a task or review a PR/branch without a second local stack. Do NOT use for a full seeded env on alternate ports — that is /monorepo-worktree.
---

# /worktree-quick

Code-only worktree: `git fetch` + `git worktree add`, then copy `.env*` and `yarn install` (own `node_modules`; husky postinstall wires pre-push). **Yarn is mandatory on every worktree** (create and reuse). Do **not** symlink `node_modules` from primary. **No** Postgres/Redis, **no** port remaps, **no** seed, **no** serve.

Use `/monorepo-worktree` when they need a runnable second stack.

## Commands

| User says | Action |
|-----------|--------|
| `/worktree-quick 1234` / `pr 1234` / PR URL | Fetch that PR, add worktree |
| `/worktree-quick feature/foo` / `branch …` | Fetch that ref, add worktree |
| `/worktree-quick add dark mode` / `new …` / `task …` | New branch from current HEAD for that task |
| `/worktree-quick destroy 1234` / `remove` / `teardown` | Remove the quick worktree + `quick/*` branch |
| `/worktree-quick list` | Show quick worktrees only |

User arguments: `$ARGUMENTS`

## Fast path

Script: `~/.ai/oc_skills/worktree-quick/scripts/quick-worktree.sh`

Must run from inside the target git repo (or set `REPO_ROOT`).

```bash
# PR number, #N, pr N, or github.com/.../pull/N
~/.ai/oc_skills/worktree-quick/scripts/quick-worktree.sh 1234
~/.ai/oc_skills/worktree-quick/scripts/quick-worktree.sh pr 1234
~/.ai/oc_skills/worktree-quick/scripts/quick-worktree.sh https://github.com/org/repo/pull/1234

# Branch / ref
~/.ai/oc_skills/worktree-quick/scripts/quick-worktree.sh feature/foo
~/.ai/oc_skills/worktree-quick/scripts/quick-worktree.sh create origin/fix-types my-review

# New task from current HEAD (quote the description)
~/.ai/oc_skills/worktree-quick/scripts/quick-worktree.sh new "add dark mode toggle"
~/.ai/oc_skills/worktree-quick/scripts/quick-worktree.sh task "fees page polish"

# Destroy / list
~/.ai/oc_skills/worktree-quick/scripts/quick-worktree.sh list
~/.ai/oc_skills/worktree-quick/scripts/quick-worktree.sh destroy 1234 --yes
~/.ai/oc_skills/worktree-quick/scripts/quick-worktree.sh destroy --name pr-1234 --yes
~/.ai/oc_skills/worktree-quick/scripts/quick-worktree.sh destroy --all --yes
```

Agents are non-interactive: always pass `--yes` on destroy. Use `--force` only if the worktree is dirty and the user wants it discarded.

## What the script does (create)

1. Resolve repo root (`REPO_ROOT` or cwd git main worktree).
2. Classify `$ARGUMENTS`: `list` / `destroy` / PR / existing ref / else **new task**.
3. PRs: `git fetch origin pull/N/head` (works for forks). `gh pr view` is optional metadata.
4. Branches: `git fetch origin <ref>`, then `origin/<ref>` or the local ref.
5. Tasks (`new …` / `task …` / multi-word description / unresolved single token): branch from **current HEAD**. No fetch.
6. `git worktree add -b quick/<slug> ../worktrees/<repo>-quick-<slug> <sha>`
7. Write a `worktree-quick` marker in the worktree git dir (not the working tree).
8. Copy `.env`, `.env.local`, and `apps/{web-crm,web-funnel,server-crm}/.env.local` from primary as-is (no port/DB rewrite).
9. `yarn install` in the worktree (own `node_modules`; husky postinstall creates `.husky/_` so pre-push runs). Do not skip yarn. Do not symlink `node_modules` from primary. If a leftover `node_modules` symlink exists, remove it first.

Path example: `/Users/mrodhansen/projects/worktrees/monorepo-quick-pr-1234`  
Branch example: `quick/pr-1234`

Cannot check out the same branch in two worktrees — that is why the local branch is always `quick/<slug>`.

## What the script does (destroy)

1. Resolve target by PR number, slug, `--name`, `--path`, or `--all`.
2. Refuse primary checkout, refuse `.worktree-slot` (full-stack) worktrees, refuse anything that is not `*-quick-*` / `.worktree-quick`.
3. `git worktree remove` (retry `--force` only if asked).
4. Delete local `quick/*` branch unless `--keep-branch` or it is checked out elsewhere.
5. No ports, no Redis, no `DROP DATABASE`.

## Model split (Claude Code)

This whole command is babysitting. Run it in a **Haiku subagent** (Agent tool, `model: "haiku"`): tell it to follow `~/.ai/commands/worktree-quick.md` with the user's arguments and return path, branch, sha, PR URL, and destroy command (or the failing output verbatim). Relay its report. If the user also asked for work in the worktree, **you** (session model) do that in the returned path.

If you **are** that subagent, skip this section and run the steps directly — do not delegate again.

## Agent checklist

1. Parse `$ARGUMENTS`: `list` / `destroy|remove|teardown` / PR / branch / **task description**. If missing, **ask**.
2. `cd` to the repo the user is talking about (do not guess a different project).
3. For a task, run `…/quick-worktree.sh new "<description>"`. Do not hand-roll `git worktree add` unless the script is missing.
4. Do **not** create `dbname_wtN`, rewrite ports, seed, or start serve. The script already copies env and runs `yarn install` — wait for it; do not skip yarn. **Every worktree must run yarn** (husky). If you reuse an existing path (already-exists / already-isolated), remove a leftover `node_modules` symlink if present, then `(cd "<path>" && yarn install)` and wait for exit 0. Never skip yarn because `node_modules` exists. Never symlink `node_modules` from primary.
5. After create: report **path**, **branch**, **sha**, PR URL if any, and the destroy command.
6. After destroy: run `list` / `git worktree list` and confirm the path is gone.
7. If they then ask to run the app: stop and point them at `/monorepo-worktree`.

## Do not

- Use this for a second local stack (ports / DB / seed) — `/monorepo-worktree`
- Destroy `monorepo-slot-*` or any path with `.worktree-slot`
- Remove the primary checkout
- Commit worktree marker files
- Skip the script's env copy / `yarn install`
- Reuse a worktree without running `yarn install`
- Symlink `node_modules` from the primary checkout

User arguments: $ARGUMENTS
````

#### `~/.ai/oc_skills/worktree-quick/scripts/quick-worktree.sh`

```bash file=~/.ai/oc_skills/worktree-quick/scripts/quick-worktree.sh mode=755
#!/usr/bin/env bash
# quick-worktree.sh — Code-only git worktree for a PR or branch.
# Copies .env*, then yarn install (own node_modules; husky postinstall
# wires pre-push — do not skip yarn). Do not symlink node_modules.
# No DB, no Redis, no port remaps, no seed, no serve.
#
# Usage:
#   ./quick-worktree.sh [create] <pr|branch|url> [name]
#   ./quick-worktree.sh [new|task] <what to work on>
#   ./quick-worktree.sh destroy <pr|name|path|task> [--yes] [--force] [--keep-branch]
#   ./quick-worktree.sh list
#
# Examples:
#   ./quick-worktree.sh 1234
#   ./quick-worktree.sh pr 1234
#   ./quick-worktree.sh feature/foo
#   ./quick-worktree.sh https://github.com/org/repo/pull/1234
#   ./quick-worktree.sh create origin/fix-types my-review
#   ./quick-worktree.sh new add dark mode toggle
#   ./quick-worktree.sh task fees page polish
#   ./quick-worktree.sh destroy 1234 --yes
#   ./quick-worktree.sh destroy --name pr-1234 --yes
#   ./quick-worktree.sh list
#
# Env:
#   REPO_ROOT   Pin the primary checkout (otherwise cwd git repo)
#   GIT_REMOTE  Remote to fetch from (default: origin)

set -euo pipefail

REMOTE="${GIT_REMOTE:-origin}"
YES=0
FORCE=0
KEEP_BRANCH=0
ACTION=""
TARGET=""
CUSTOM_NAME=""
NAME_FLAG=""
PATH_FLAG=""
ALL=0
FORCE_TASK=0
TASK_TITLE=""

usage() {
  sed -n '2,26p' "$0" | sed 's/^# \{0,1\}//'
  exit 1
}

die() {
  echo "ERROR: $*" >&2
  exit 1
}

# --- parse args ---
POSITIONAL=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    create|setup)
      ACTION="create"
      shift
      ;;
    new|task|work)
      ACTION="create"
      FORCE_TASK=1
      shift
      ;;
    destroy|remove|teardown|rm|clean)
      ACTION="destroy"
      shift
      ;;
    list|ls)
      ACTION="list"
      shift
      ;;
    --name)
      NAME_FLAG="${2:-}"
      [[ -n "${NAME_FLAG}" ]] || usage
      shift 2
      ;;
    --path)
      PATH_FLAG="${2:-}"
      [[ -n "${PATH_FLAG}" ]] || usage
      shift 2
      ;;
    --all)
      ALL=1
      shift
      ;;
    --keep-branch) KEEP_BRANCH=1; shift ;;
    --force) FORCE=1; shift ;;
    --yes|-y) YES=1; shift ;;
    -h|--help) usage ;;
    --)
      shift
      break
      ;;
    -*)
      die "unknown flag: $1"
      ;;
    *)
      POSITIONAL+=("$1")
      shift
      ;;
  esac
done

join_positional() {
  local start="$1"
  local i=0 s=""
  i="${start}"
  while [[ "${i}" -lt ${#POSITIONAL[@]} ]]; do
    if [[ -n "${s}" ]]; then
      s="${s} "
    fi
    s="${s}${POSITIONAL[$i]}"
    i=$((i + 1))
  done
  printf '%s' "${s}"
}

if [[ ${#POSITIONAL[@]} -gt 0 ]]; then
  if [[ "${POSITIONAL[0]}" == "pr" || "${POSITIONAL[0]}" == "branch" || "${POSITIONAL[0]}" == "ref" ]]; then
    if [[ ${#POSITIONAL[@]} -lt 2 ]]; then
      die "${POSITIONAL[0]} requires a number or ref"
    fi
    TARGET="${POSITIONAL[0]} ${POSITIONAL[1]}"
    if [[ ${#POSITIONAL[@]} -gt 2 ]]; then
      CUSTOM_NAME="$(join_positional 2)"
    fi
  elif [[ ${#POSITIONAL[@]} -gt 1 && "${FORCE_TASK}" -eq 0 ]]; then
    TARGET="${POSITIONAL[0]}"
    CUSTOM_NAME="$(join_positional 1)"
    if [[ "${TARGET}" != *'/'* && ! "${TARGET}" =~ ^[0-9]+$ && "${TARGET}" != http* ]]; then
      TARGET="$(join_positional 0)"
      CUSTOM_NAME=""
      FORCE_TASK=1
    fi
  else
    TARGET="$(join_positional 0)"
  fi
fi

if [[ -z "${ACTION}" ]]; then
  if [[ -z "${TARGET}" && -z "${PATH_FLAG}" && "${ALL}" -eq 0 ]]; then
    ACTION="list"
  else
    ACTION="create"
  fi
fi

slugify() {
  echo "$1" \
    | tr '[:upper:]' '[:lower:]' \
    | sed -E 's#^origin/##; s#^refs/heads/##; s#^refs/pull/##; s#/head$##' \
    | tr '/:#' '---' \
    | tr -cs 'a-z0-9._-' '-' \
    | sed -E 's/^-+//; s/-+$//; s/-+/-/g' \
    | cut -c1-48
}

extract_pr() {
  local raw="$1"
  raw="$(echo "${raw}" | sed -E 's/^#//')"
  if echo "${raw}" | grep -Eq 'github\.com/.+/pull/[0-9]+'; then
    echo "${raw}" | sed -E 's#.*github\.com/.+/pull/([0-9]+).*#\1#'
    return 0
  fi
  if echo "${raw}" | grep -Eq '^[Pp][Rr][-/ ]?[0-9]+$'; then
    echo "${raw}" | sed -E 's/^[Pp][Rr][-/ ]?//'
    return 0
  fi
  if echo "${raw}" | grep -Eq '^[0-9]+$'; then
    echo "${raw}"
    return 0
  fi
  return 1
}

resolve_primary() {
  if [[ -n "${REPO_ROOT:-}" && -d "${REPO_ROOT}" ]]; then
    (cd "${REPO_ROOT}" && pwd)
    return 0
  fi
  local main_wt
  main_wt="$(git worktree list --porcelain 2>/dev/null | awk '/^worktree /{print $2; exit}')"
  if [[ -n "${main_wt}" && -d "${main_wt}" ]]; then
    echo "${main_wt}"
    return 0
  fi
  if git rev-parse --show-toplevel >/dev/null 2>&1; then
    git rev-parse --show-toplevel
    return 0
  fi
  die "cannot resolve repo root. cd into a git repo or set REPO_ROOT."
}

PRIMARY="$(resolve_primary)"
REPO_NAME="$(basename "${PRIMARY}")"
WORKTREES_ROOT="$(dirname "${PRIMARY}")/worktrees"

is_primary() {
  local candidate="$1"
  local a b
  a="$(cd "${candidate}" 2>/dev/null && pwd -P)" || return 1
  b="$(cd "${PRIMARY}" && pwd -P)"
  [[ "${a}" == "${b}" ]]
}

marker_file() {
  local path="$1" gitdir
  if gitdir="$(git -C "${path}" rev-parse --path-format=absolute --git-dir 2>/dev/null)"; then
    if [[ -f "${gitdir}/worktree-quick" ]]; then
      echo "${gitdir}/worktree-quick"
      return 0
    fi
  fi
  if [[ -f "${path}/.worktree-quick" ]]; then
    echo "${path}/.worktree-quick"
    return 0
  fi
  return 1
}

is_quick_worktree() {
  local path="$1"
  [[ -f "${path}/.worktree-slot" ]] && return 1
  marker_file "${path}" >/dev/null && return 0
  local base
  base="$(basename "${path}")"
  [[ "${base}" == "${REPO_NAME}-quick-"* ]] && return 0
  return 1
}

assert_not_primary() {
  local path="$1"
  if is_primary "${path}"; then
    die "refusing to operate on the primary checkout: ${path}"
  fi
}

assert_quick_or_die() {
  local path="$1"
  assert_not_primary "${path}"
  if ! is_quick_worktree "${path}"; then
    die "refusing to touch non-quick worktree: ${path} (no quick marker; expected ${REPO_NAME}-quick-*)"
  fi
}

marker_get() {
  local path="$1" key="$2" file
  file="$(marker_file "${path}")" || return 1
  awk -F= -v k="${key}" '$1==k {print substr($0, index($0,$2)); exit}' "${file}"
}

list_quick_paths() {
  git -C "${PRIMARY}" worktree list --porcelain | awk '/^worktree /{print $2}' | while IFS= read -r p; do
    [[ -n "${p}" ]] || continue
    if is_quick_worktree "${p}"; then
      echo "${p}"
    fi
  done
}

cmd_list() {
  local found=0
  printf '%-56s %-28s %-10s %s\n' "PATH" "BRANCH" "SOURCE" "REF"
  printf '%-56s %-28s %-10s %s\n' "----" "------" "------" "---"
  while IFS= read -r p; do
    [[ -n "${p}" ]] || continue
    found=1
    local branch source ref
    branch="$(git -C "${p}" rev-parse --abbrev-ref HEAD 2>/dev/null || echo "?")"
    source="$(marker_get "${p}" source 2>/dev/null || echo "?")"
    ref="$(marker_get "${p}" ref 2>/dev/null || git -C "${p}" rev-parse --short HEAD 2>/dev/null || echo "?")"
    printf '%-56s %-28s %-10s %s\n' "${p}" "${branch}" "${source}" "${ref}"
  done < <(list_quick_paths)
  if [[ "${found}" -eq 0 ]]; then
    echo "(no quick worktrees for ${REPO_NAME})"
  fi
}

# Same env files as the primary checkout, copied as-is (no port/DB rewrite —
# this is not a second stack). Missing sources are a warning, not a failure.
copy_env_files() {
  local primary="$1" wt="$2"
  copy_one_env() {
    local src="$1" dest="$2"
    if [[ -f "${src}" ]]; then
      mkdir -p "$(dirname "${dest}")"
      cp "${src}" "${dest}"
      echo "  copied ${src#"${primary}"/}"
    else
      echo "  WARN: missing ${src}"
    fi
  }
  copy_one_env "${primary}/.env" "${wt}/.env"
  copy_one_env "${primary}/.env.local" "${wt}/.env.local"
  copy_one_env "${primary}/apps/web-crm/.env.local" "${wt}/apps/web-crm/.env.local"
  copy_one_env "${primary}/apps/web-funnel/.env.local" "${wt}/apps/web-funnel/.env.local"
  copy_one_env "${primary}/apps/server-crm/.env.local" "${wt}/apps/server-crm/.env.local"
}

# Yarn installs a real node_modules in the worktree. Drop a leftover symlink
# from older setup so install does not write into the primary tree.
drop_node_modules_symlink() {
  local dest="${1}/node_modules"
  if [[ -L "${dest}" ]]; then
    rm -f "${dest}"
    echo "  removed leftover node_modules symlink"
  fi
}

write_marker() {
  local path="$1" gitdir
  gitdir="$(git -C "${path}" rev-parse --path-format=absolute --git-dir)"
  cat > "${gitdir}/worktree-quick" <<EOF
kind=quick
repo=${REPO_NAME}
source=${SOURCE}
pr=${PR_NUM}
ref=${RESOLVED_SHA}
upstream=${UPSTREAM_REF}
branch=${BRANCH_NAME}
url=${SOURCE_URL}
task=${TASK_TITLE}
created=$(date -u +%Y-%m-%dT%H:%M:%SZ)
EOF
}

resolve_task() {
  local desc="$1"
  desc="$(echo "${desc}" | sed -E 's/^(new|task|work|on)[[:space:]]+//')"
  [[ -n "${desc}" ]] || die "task mode requires a description (e.g. 'new add dark mode')"
  SOURCE="task"
  TASK_TITLE="${desc}"
  TITLE="${desc}"
  UPSTREAM_REF="$(git -C "${PRIMARY}" rev-parse --abbrev-ref HEAD)"
  RESOLVED_SHA="$(git -C "${PRIMARY}" rev-parse HEAD)"
  SOURCE_URL=""
  PR_NUM=""
}

resolve_create_target() {
  local raw="$1"
  PR_NUM=""
  SOURCE=""
  SOURCE_URL=""
  UPSTREAM_REF=""
  RESOLVED_SHA=""
  TITLE=""
  TASK_TITLE=""

  if [[ "${FORCE_TASK}" -eq 1 ]]; then
    resolve_task "${raw}"
    return 0
  fi

  local maybe_pr
  if maybe_pr="$(extract_pr "${raw}")"; then
    SOURCE="pr"
    PR_NUM="${maybe_pr}"
    git -C "${PRIMARY}" fetch "${REMOTE}" "pull/${PR_NUM}/head"
    RESOLVED_SHA="$(git -C "${PRIMARY}" rev-parse FETCH_HEAD)"
    UPSTREAM_REF="pull/${PR_NUM}/head"
    if command -v gh >/dev/null 2>&1; then
      TITLE="$(gh pr view "${PR_NUM}" --json title --jq .title 2>/dev/null || true)"
      SOURCE_URL="$(gh pr view "${PR_NUM}" --json url --jq .url 2>/dev/null || true)"
      local head
      head="$(gh pr view "${PR_NUM}" --json headRefName --jq .headRefName 2>/dev/null || true)"
      if [[ -n "${head}" && "${head}" != "null" ]]; then
        UPSTREAM_REF="${head}"
      fi
    fi
    return 0
  fi

  SOURCE="branch"
  local ref="${raw}"
  if git -C "${PRIMARY}" fetch "${REMOTE}" "${ref}" 2>/dev/null; then
    if git -C "${PRIMARY}" rev-parse --verify --quiet "${REMOTE}/${ref}^{commit}" >/dev/null; then
      UPSTREAM_REF="${REMOTE}/${ref}"
      RESOLVED_SHA="$(git -C "${PRIMARY}" rev-parse "${REMOTE}/${ref}^{commit}")"
      return 0
    fi
    if git -C "${PRIMARY}" rev-parse --verify --quiet "FETCH_HEAD^{commit}" >/dev/null; then
      UPSTREAM_REF="${ref}"
      RESOLVED_SHA="$(git -C "${PRIMARY}" rev-parse "FETCH_HEAD^{commit}")"
      return 0
    fi
  fi
  if git -C "${PRIMARY}" rev-parse --verify --quiet "${ref}^{commit}" >/dev/null; then
    UPSTREAM_REF="${ref}"
    RESOLVED_SHA="$(git -C "${PRIMARY}" rev-parse "${ref}^{commit}")"
    return 0
  fi
  if [[ "${raw}" == *'/'* || "${raw}" == *':'* ]]; then
    die "cannot resolve '${raw}' as a PR number or git ref (tried fetch ${REMOTE} ${ref})"
  fi
  resolve_task "${raw}"
}

cmd_create() {
  local raw="${TARGET}"
  [[ -n "${raw}" ]] || die "create requires a PR, branch, or task description. Usage: quick-worktree.sh <pr|branch|new …>"

  resolve_create_target "${raw}"

  local slug
  if [[ -n "${CUSTOM_NAME}" ]]; then
    slug="$(slugify "${CUSTOM_NAME}")"
  elif [[ -n "${NAME_FLAG}" ]]; then
    slug="$(slugify "${NAME_FLAG}")"
  elif [[ "${SOURCE}" == "pr" ]]; then
    slug="pr-${PR_NUM}"
  elif [[ "${SOURCE}" == "task" ]]; then
    slug="$(slugify "${TASK_TITLE}")"
  else
    slug="$(slugify "${raw}")"
  fi
  [[ -n "${slug}" ]] || die "could not derive a worktree name from '${raw}'"

  local wt_path="${WORKTREES_ROOT}/${REPO_NAME}-quick-${slug}"
  BRANCH_NAME="quick/${slug}"

  if [[ -d "${wt_path}" ]]; then
    die "worktree path already exists: ${wt_path}"
  fi
  if git -C "${PRIMARY}" show-ref --verify --quiet "refs/heads/${BRANCH_NAME}"; then
    die "local branch already exists: ${BRANCH_NAME} (destroy it first or pass a different name)"
  fi

  mkdir -p "${WORKTREES_ROOT}"
  git -C "${PRIMARY}" worktree add -b "${BRANCH_NAME}" "${wt_path}" "${RESOLVED_SHA}"
  write_marker "${wt_path}"

  echo "Copying env from primary..."
  copy_env_files "${PRIMARY}" "${wt_path}"
  drop_node_modules_symlink "${wt_path}"
  echo "yarn install (husky postinstall wires pre-push)..."
  (cd "${wt_path}" && yarn install)

  echo "═══════════════════════════════════════════════════════════"
  echo " Quick worktree (env + yarn install — no db / seed / serve)"
  echo "═══════════════════════════════════════════════════════════"
  echo "  repo:     ${PRIMARY}"
  echo "  path:     ${wt_path}"
  echo "  branch:   ${BRANCH_NAME}"
  echo "  source:   ${SOURCE}${PR_NUM:+ #${PR_NUM}}"
  echo "  ref:      ${RESOLVED_SHA}"
  echo "  upstream: ${UPSTREAM_REF}"
  if [[ "${SOURCE}" == "task" && -n "${TASK_TITLE}" ]]; then
    echo "  task:     ${TASK_TITLE}"
  elif [[ -n "${TITLE}" ]]; then
    echo "  title:    ${TITLE}"
  fi
  if [[ -n "${SOURCE_URL}" ]]; then
    echo "  url:      ${SOURCE_URL}"
  fi
  echo "═══════════════════════════════════════════════════════════"
  echo "cd ${wt_path}"
  echo "Destroy: $0 destroy ${slug} --yes"
}

resolve_destroy_path() {
  if [[ -n "${PATH_FLAG}" ]]; then
    local p="${PATH_FLAG}"
    if [[ "${p}" != /* ]]; then
      p="$(cd "${p}" 2>/dev/null && pwd)" || die "path not found: ${PATH_FLAG}"
    fi
    echo "${p}"
    return 0
  fi

  local key="${NAME_FLAG:-${TARGET}}"
  [[ -n "${key}" ]] || return 1
  key="$(echo "${key}" | sed -E 's/^(new|task|work|on)[[:space:]]+//')"

  local maybe_pr
  if maybe_pr="$(extract_pr "${key}")"; then
    local p
    p="${WORKTREES_ROOT}/${REPO_NAME}-quick-pr-${maybe_pr}"
    if [[ -d "${p}" ]]; then
      echo "${p}"
      return 0
    fi
    while IFS= read -r cand; do
      [[ -n "${cand}" ]] || continue
      local pr
      pr="$(marker_get "${cand}" pr || true)"
      if [[ "${pr}" == "${maybe_pr}" ]]; then
        echo "${cand}"
        return 0
      fi
    done < <(list_quick_paths)
  fi

  local slug
  slug="$(slugify "${key}")"
  local p="${WORKTREES_ROOT}/${REPO_NAME}-quick-${slug}"
  if [[ -d "${p}" ]]; then
    echo "${p}"
    return 0
  fi

  # Allow passing the full directory basename or an existing worktree path
  if [[ -d "${key}" ]]; then
    (cd "${key}" && pwd)
    return 0
  fi

  return 1
}

destroy_one() {
  local wt_path="$1"
  assert_quick_or_die "${wt_path}"

  local branch
  branch="$(marker_get "${wt_path}" branch || true)"
  if [[ -z "${branch}" ]]; then
    branch="$(git -C "${wt_path}" rev-parse --abbrev-ref HEAD 2>/dev/null || true)"
  fi

  echo "Removing worktree: ${wt_path}"
  rm -f "${wt_path}/.worktree-quick"
  if [[ "${FORCE}" -eq 1 ]]; then
    git -C "${PRIMARY}" worktree remove --force "${wt_path}" \
      || { rm -rf "${wt_path}"; git -C "${PRIMARY}" worktree prune; }
  else
    git -C "${PRIMARY}" worktree remove "${wt_path}" \
      || die "worktree remove failed (dirty?). Re-run with --force"
  fi
  git -C "${PRIMARY}" worktree prune

  if [[ "${KEEP_BRANCH}" -eq 0 && -n "${branch}" && "${branch}" == quick/* ]]; then
    if git -C "${PRIMARY}" show-ref --verify --quiet "refs/heads/${branch}"; then
      if git -C "${PRIMARY}" worktree list --porcelain | awk '/^branch /{print $2}' | grep -qx "refs/heads/${branch}"; then
        echo "Leaving branch ${branch} (still checked out elsewhere)"
      else
        git -C "${PRIMARY}" branch -D "${branch}"
        echo "Deleted branch ${branch}"
      fi
    fi
  fi
}

cmd_destroy() {
  local paths=()
  if [[ "${ALL}" -eq 1 ]]; then
    while IFS= read -r p; do
      [[ -n "${p}" ]] && paths+=("${p}")
    done < <(list_quick_paths)
    [[ ${#paths[@]} -gt 0 ]] || die "no quick worktrees to destroy"
  else
    local p
    p="$(resolve_destroy_path)" || {
      echo "Could not resolve destroy target '${NAME_FLAG:-${TARGET:-}}'." >&2
      echo "Known quick worktrees:" >&2
      cmd_list >&2
      exit 1
    }
    paths+=("${p}")
  fi

  echo "Will destroy:"
  local p
  for p in "${paths[@]}"; do
    echo "  ${p}"
    assert_quick_or_die "${p}"
  done

  if [[ "${YES}" -ne 1 ]]; then
    die "refusing to destroy without --yes (non-interactive). Re-run with --yes."
  fi

  for p in "${paths[@]}"; do
    destroy_one "${p}"
  done

  echo "Remaining worktrees:"
  git -C "${PRIMARY}" worktree list
}

case "${ACTION}" in
  list) cmd_list ;;
  create) cmd_create ;;
  destroy) cmd_destroy ;;
  *) usage ;;
esac
```

### Command assets

Extra references for commands. `*/scripts` are symlinks into `oc_skills`.

#### `~/.ai/command-assets/fix-shipyard-tests/references/shipyard-workflows.md`

````markdown file=~/.ai/command-assets/fix-shipyard-tests/references/shipyard-workflows.md
# Shipyard workflows reference

Source of truth: https://github.com/Future-Mortgage/shipyard/actions

## Active workflows (typical)

| Workflow | Path | Role for this skill |
|----------|------|---------------------|
| Deploy Dev (GCP) | `.github/workflows/deploy-dev-gcp.yml` | **Primary** — runs integration + e2e after deploy |
| Deploy Prod (GCP) | `.github/workflows/deploy-prod-gcp.yml` | Prod deploy; not the default test target |
| Deploy Infrastructure (GCP) | `.github/workflows/deploy-infra-gcp.yml` | Infra only |
| Deploy Ephemeral Preview (GCP) | `.github/workflows/deploy-ephemeral-gcp.yml` | Preview deploys |

## Deploy Dev job chain

1. `prepare` — tag + monorepo/verification refs, actor/Slack mapping  
2. `build_images` — build container images from monorepo ref  
3. `deploy` — deploy to dev GCP  
4. `integration_tests` — Vitest API/integration suite  
5. `e2e_tests` — Playwright server-crm + web-crm suites  

## Commands executed in shipyard (monorepo checkout)

```bash
# integration_tests
yarn vitest run --config apps/server-crm-e2e/vitest.config.ts --no-file-parallelism

# e2e_tests
npx playwright test --config=apps/server-crm-e2e/playwright.config.ts
npx playwright test --config=apps/web-crm-e2e/playwright.config.ts
```

Env: `TEST_BASE_URL` from shipyard vars (dev host).

## Artifacts

- Name: `e2e-test-results`
- Paths: `apps/server-crm-e2e/test-results/`, `apps/web-crm-e2e/test-results/`

## Useful gh commands

```bash
gh run list --repo Future-Mortgage/shipyard --workflow "Deploy Dev (GCP)" --status failure --limit 10
gh run view <id> --repo Future-Mortgage/shipyard --json jobs
gh run view <id> --repo Future-Mortgage/shipyard --log-failed
gh run download <id> --repo Future-Mortgage/shipyard --name e2e-test-results --dir /tmp/shipyard-e2e-<id>
```

## Fix ownership

| Failure shape | Likely repo |
|---------------|-------------|
| Test assertion / selector / playwright setup | monorepo (`apps/*-e2e` or product UI) |
| API contract / server behavior | monorepo (`apps/server-crm`, shared libs) |
| Wrong image tag, secrets, workflow step, URL var | shipyard |
````

#### `~/.ai/command-assets/implement-as-stack/references/gh-stack-cheatsheet.md`

````markdown file=~/.ai/command-assets/implement-as-stack/references/gh-stack-cheatsheet.md
# gh-stack cheatsheet (for /implement-as-stack)

Install: `gh extension install github/gh-stack`

Docs: https://github.github.com/gh-stack/  
About: https://docs.github.com/en/pull-requests/get-started/about-stacked-prs

## Happy path

```bash
gh stack init --base main feat/foo-schema
# ... commit layer 1 ...
gh stack add feat/foo-api
# ... commit layer 2 ...
gh stack add feat/foo-ui
# ... commit layer 3 ...
gh stack submit --auto --open
```

## Essential commands

| Command | Purpose |
|---------|---------|
| `gh stack init [--base B] [branches...]` | Start local stack; adopt/create branches bottom→top |
| `gh stack add <branch>` | New empty branch on top of current stack tip |
| `gh stack submit --auto --open` | Push, create/update PRs, create GitHub Stack |
| `gh stack link [--open] b1 b2 b3` | Stack without local tracking (or after manual branches) |
| `gh stack push` | Force-with-lease push active stack branches |
| `gh stack rebase` | Cascading rebase onto trunk/parents |
| `gh stack sync` | Fetch + rebase + push + sync PR/stack state |
| `gh stack view [--json]` | Show stack |
| `gh stack unstack` | Dissolve stack (local+remote tracking) |
| `gh stack up` / `down` / `top` / `bottom` / `trunk` | Navigate |

## Agent notes

- Prefer `--auto` on `submit` in non-interactive agent shells.
- Use `--open` when PRs should be ready for review (default with `--auto` alone is drafts).
- Exit code **9** = stacked PRs not enabled for the repository.
- Server-side UI “Rebase Stack” force-pushes **unsigned** commits; local `gh stack rebase` respects local signing.
- Cross-fork stacks are not supported; all branches same repo.
- Merge is bottom-up; merging mid PR lands it **and everything below**.

## Manual chain (no local tracking)

```bash
# branches already exist bottom→top with correct parent commits
gh stack link --open feat/foo-schema feat/foo-api feat/foo-ui
```
````

### Workflows

Grok workflows (rhai).

#### `~/.ai/workflows/peer-review.rhai`

```rust file=~/.ai/workflows/peer-review.rhai
// peer-review — plan → implement → specialist review → adversarial verify →
// independent triage → fix → optional delta re-review. Improves on the
// peer-review skill with fail-closed verification, implementer/judge
// separation, early exit, and budget-aware round structure.

let meta = #{
    name: "peer-review",
    description: "Peer-reviewed build: plan, implement, parallel specialists, adversarial verify findings, independent triage, fix, optional delta re-review",
    when_to_use: "When you want /peer-review quality (plan+implement+multi-specialist rounds) with adversarial verification and no implementer-as-judge bias",
    phases: [
        #{ title: "Resolve", detail: "task / PRD / issue into a bound spec" },
        #{ title: "Plan", detail: "structured plan with consumer map, authZ, failure modes" },
        #{ title: "Implement", detail: "build against the plan; record files touched" },
        #{ title: "Review", detail: "parallel specialists (7 actionable + architecture advisory)" },
        #{ title: "Verify", detail: "independent skeptics prove each finding is real" },
        #{ title: "Triage", detail: "fresh judge accepts / rejects / defers confirmed findings only" },
        #{ title: "Fix", detail: "implement accepted changes; type-harden soft-fails" },
        #{ title: "Re-review", detail: "optional delta pass on fixed files only" },
        #{ title: "Summary", detail: "durable report + deferred list + architecture advisory if needed" },
    ],
};

// ── Schemas ────────────────────────────────────────────────────────────────

let plan_schema = #{
    "type": "object",
    "required": ["goal", "approach", "files", "consumer_map", "invariants", "authz", "failure_modes", "out_of_scope", "open_questions", "implementation_steps"],
    "properties": #{
        "goal": #{ "type": "string" },
        "approach": #{ "type": "string" },
        "files": #{ "type": "array", "items": #{ "type": "string" }, "maxItems": 40 },
        "consumer_map": #{ "type": "string" },
        "invariants": #{ "type": "string" },
        "authz": #{ "type": "string" },
        "failure_modes": #{ "type": "string" },
        "out_of_scope": #{ "type": "string" },
        "open_questions": #{ "type": "string" },
        "implementation_steps": #{ "type": "array", "items": #{ "type": "string" }, "maxItems": 20 },
    },
};

let implement_schema = #{
    "type": "object",
    "required": ["summary", "files_touched", "build_ok", "notes"],
    "properties": #{
        "summary": #{ "type": "string" },
        "files_touched": #{ "type": "array", "items": #{ "type": "string" }, "maxItems": 60 },
        "build_ok": #{ "type": "boolean" },
        "notes": #{ "type": "string" },
    },
};

let findings_schema = #{
    "type": "object",
    "required": ["findings", "summary"],
    "properties": #{
        "summary": #{ "type": "string" },
        "findings": #{
            "type": "array",
            "maxItems": 6,
            "items": #{
                "type": "object",
                "required": ["title", "severity", "file", "observation", "why", "suggested_change"],
                "properties": #{
                    "title": #{ "type": "string" },
                    "severity": #{ "type": "string" },
                    "file": #{ "type": "string" },
                    "line": #{ "type": "string" },
                    "observation": #{ "type": "string" },
                    "why": #{ "type": "string" },
                    "suggested_change": #{ "type": "string" },
                },
            },
        },
    },
};

let arch_schema = #{
    "type": "object",
    "required": ["verdict", "note"],
    "properties": #{
        "verdict": #{ "type": "string" },
        "note": #{ "type": "string" },
    },
};

let verdict_schema = #{
    "type": "object",
    "required": ["real", "reason", "evidence"],
    "properties": #{
        "real": #{ "type": "boolean" },
        "reason": #{ "type": "string" },
        "evidence": #{ "type": "string" },
    },
};

let triage_schema = #{
    "type": "object",
    "required": ["decisions"],
    "properties": #{
        "decisions": #{
            "type": "array",
            "maxItems": 24,
            "items": #{
                "type": "object",
                "required": ["index", "decision", "reasoning"],
                "properties": #{
                    "index": #{ "type": "integer" },
                    "decision": #{ "type": "string" },
                    "reasoning": #{ "type": "string" },
                    "implementation_note": #{ "type": "string" },
                },
            },
        },
    },
};

let fix_schema = #{
    "type": "object",
    "required": ["summary", "files_touched", "build_ok", "applied", "rejected_during_apply"],
    "properties": #{
        "summary": #{ "type": "string" },
        "files_touched": #{ "type": "array", "items": #{ "type": "string" }, "maxItems": 60 },
        "build_ok": #{ "type": "boolean" },
        "applied": #{ "type": "array", "items": #{ "type": "string" }, "maxItems": 24 },
        "rejected_during_apply": #{
            "type": "array",
            "maxItems": 12,
            "items": #{
                "type": "object",
                "required": ["title", "reason"],
                "properties": #{
                    "title": #{ "type": "string" },
                    "reason": #{ "type": "string" },
                },
            },
        },
    },
};

let summary_schema = #{
    "type": "object",
    "required": ["report_markdown"],
    "properties": #{
        "report_markdown": #{ "type": "string" },
    },
};

// ── Args ───────────────────────────────────────────────────────────────────

let task = if args == () { () } else { args.task };
if task == () {
    pause("verification", "Pass args.task — free-form description, a PRD path, or a GitHub issue (#42 / URL). Optional: args.rounds (1 or 2, default 2), args.base (git base branch).");
}

let max_rounds = 2;
if args != () && args.rounds != () {
    // Rhai has no int parse from arbitrary; accept number only.
    if type_of(args.rounds) == "i64" || type_of(args.rounds) == "f64" {
        if args.rounds == 1 { max_rounds = 1; }
        if args.rounds == 2 { max_rounds = 2; }
    }
}

let base_branch = "main";
if args != () && args.base != () && type_of(args.base) == "string" && args.base != "" {
    base_branch = args.base;
}

const MAX_VERIFY = 12;
const MAX_FINDINGS_PER_SPECIALIST = 6;

// ── Helpers ────────────────────────────────────────────────────────────────

fn trimmed(s) {
    if type_of(s) == "string" {
        s.trim();
        s
    } else {
        ""
    }
}

// Canned validate_only outputs are small fixed objects — never assume arrays exist.
fn as_array(x) {
    if x == () { return []; }
    if type_of(x) == "array" { return x; }
    []
}

fn as_string(x) {
    if x == () { return ""; }
    if type_of(x) == "string" { return x; }
    json_encode(x)
}

fn severity_rank(sev) {
    let s = trimmed(sev);
    if s == "blocker" || s == "BLOCKER" || s == "critical" || s == "CRITICAL" { return 4; }
    if s == "major" || s == "MAJOR" || s == "high" || s == "HIGH" { return 3; }
    if s == "minor" || s == "MINOR" || s == "medium" || s == "MEDIUM" { return 2; }
    1
}

fn merge_files(a, b) {
    let out = [];
    for p in a {
        let seen = false;
        for q in out {
            if q == p { seen = true; }
        }
        if !seen { out.push(p); }
    }
    for p in b {
        let seen = false;
        for q in out {
            if q == p { seen = true; }
        }
        if !seen { out.push(p); }
    }
    out
}

fn files_prompt_block(files) {
    let block = "";
    let i = 0;
    for f in files {
        if i > 0 { block += "\n"; }
        block += "- ";
        block += f;
        i += 1;
    }
    if block == "" { block = "(no files listed — discover via git status / git diff against base)"; }
    block
}

fn findings_prompt_block(findings) {
    let block = "";
    let i = 0;
    for f in findings {
        block += "\n### INDEX ";
        block += i.to_string();
        block += " — ";
        block += f.title;
        block += "\n- Specialty: ";
        block += f.specialty;
        block += "\n- Severity: ";
        block += f.severity;
        block += "\n- File: ";
        block += f.file;
        if f.line != () && f.line != "" {
            block += ":";
            block += f.line;
        }
        block += "\n- Observation: ";
        block += f.observation;
        block += "\n- Why: ";
        block += f.why;
        block += "\n- Suggested change: ";
        block += f.suggested_change;
        block += "\n";
        i += 1;
    }
    block
}

fn shared_review_rules() {
    let s = "";
    s += "SHARED RULES:\n";
    s += "1. Use read_file / grep / git tools to inspect the ACTUAL code. Do not answer from memory.\n";
    s += "2. Read every listed file fully (not just hunks). For wiring/dual-path issues, also read consumers outside the list.\n";
    s += "3. Stay in your specialty. Skip issues owned by other specialists unless inseparable.\n";
    s += "4. Do not modify code. Review only.\n";
    s += "5. Be specific: file path, line if possible, concrete change. Vague advice is invalid.\n";
    s += "6. Respect OUT OF SCOPE in the plan — do not raise those.\n";
    s += "7. Empty findings is valid ONLY after you read the code and found nothing in your specialty. Summary must say clean.\n";
    s += "8. Cap at 6 findings. Prefer highest severity. Severity: blocker | major | minor | nit.\n";
    s += "9. Never invent issues to fill the quota.\n";
    s
}

fn specialty_body(name) {
    if name == "correctness" {
        let s = "";
        s += "SPECIALTY: Correctness / plan-fit / edge cases\n";
        s += "Review ONLY for: plan vs implementation mismatches; logic bugs; edge cases; off-by-one; null derefs; race/async ordering; incomplete error handling that is pure correctness; missing cleanup; wrong status codes; copy-paste bugs.\n";
        s += "Do NOT deep-dive: injection/auth catalogs, silent-fallback catalogs, R1-R10 checklists, unused-import/dead-symbol cleanup, extract-to-shared DRY, or test-suite design.\n";
        return s;
    }
    if name == "security" {
        let s = "";
        s += "SPECIALTY: Security / authZ / secrets\n";
        s += "Review ONLY for: injection (SQL/NoSQL/command/XSS/template); missing/weak auth; thin tenant checks without assignment/role gates; over-broad procedures; identity vs capability conflation; auth fail-open; secrets/PII in logs or responses; env names in user errors; cross-tenant leakage; missing input validation; crypto/session/JWT issues.\n";
        s += "Do NOT deep-dive: performance, soft-type hardening (except fail-open auth), test coverage, plan-fit nits.\n";
        return s;
    }
    if name == "silent" {
        let s = "";
        s += "SPECIALTY: Silent failure / soft types (\"just make it work\")\n";
        s += "Prefer hard failures with clear errors over wrong-state continuation unless intentional graceful degradation.\n";
        s += "Flag: empty catch; catch that logs and continues as success; .catch(()=>undefined|null|[]|{}); try/catch returning success defaults; fire-and-forget where failure must surface.\n";
        s += "Flag fallbacks that should hard-fail: critical config defaults; empty arrays/objects when required data missing; || [] / ?? {} papering; optional chains on required paths; mock/stale production fallbacks; parse→silent default; retry that succeeds with empty data.\n";
        s += "Soft types root cause: for every fallback, name the exact hard type + validation boundary. Never suggest any / as any / double cast / blanket ! / @ts-ignore.\n";
        s += "Flag: optional fields that should be required; Partial for loaded entities; unvalidated JSON deep in domain; empty success when absence is error.\n";
        s += "For each finding: (1) what happens on failure today (2) what should happen (3) soft-type root cause + hard type (4) concrete fix without more defaults.\n";
        return s;
    }
    if name == "recurring" {
        let s = "";
        s += "SPECIALTY: Recurring PR failure patterns R1-R10\n";
        s += "Walk checklist; flag production failure modes as blocker/major.\n";
        s += "R1 Soft success (looks ACTIVE/ready while broken). R2 Write-only / incomplete E2E wiring (UI→API→DB→read→export pipelines→import→jobs). R3 App-only invariants/races (need DB unique/transactions). R4 Thin authZ/tenant/secret boundaries. R5 Form hydration/mount wipes. R6 Dual-path inconsistency (CRM vs funnel, twin transformers). R7 Envelope casts / partial updates null omitted fields / type lies. R8 Tests that don't protect failure modes. R9 UX recovery missing. R10 Reinvention / arbitrary design tokens / incomplete a11y.\n";
        s += "For R2/R6 read consumers outside the touched list. In Why, name the production failure mode. Prefer DB constraints, existing auth helpers, hard preflight throws, full consumer wiring — not more ?? defaults.\n";
        return s;
    }
    if name == "testing" {
        let s = "";
        s += "SPECIALTY: Testing gaps\n";
        s += "Review ONLY missing/weak tests. Do not redesign product logic except to name the assertion that would catch a bug.\n";
        s += "Flag: new branches without tests; modified behavior without updated tests; happy-path-only fixtures; tests that no-op green when fixtures missing; missing failure-path assertions; contract changes without e2e/integration updates.\n";
        s += "Prefer at least one test that would FAIL if a silent-success or write-only bug returned. For each: where test lives, what to assert, what bug it catches.\n";
        return s;
    }
    if name == "deadcode" {
        let s = "";
        s += "SPECIALTY: Dead code / unused / stale comments\n";
        s += "Remove refactor leftovers. Prove unused with grep/read — do not guess.\n";
        s += "Flag unused imports (named/default/type-only/unneeded side-effect); unused locals/params/private helpers/types/constants; exports/re-exports with no in-repo consumers (unless intentional public package API); dead/unreachable branches; assigned-never-read vars; leftover feature-flag/env reads.\n";
        s += "Flag stale/useless comments to DELETE: narrating removed behavior (used to/previously/was/no longer/removed X/old path); large commented-out blocks; JSDoc contradicting current signatures; TODOs already done or pointing at deleted code; leftover section banners; obvious narrating comments from this change with no non-obvious intent.\n";
        s += "Do NOT flag: symbols used via types/decorators/DI/reflection; WHY/invariant/security comments that still apply; WIP with active TODO+issue; broad cleanups outside this change's blast radius.\n";
        s += "Severity: unused import=nit; dead private helper/misleading stale comment=minor/major; stale comment contradicting auth/security=major/blocker. Each finding needs proof of zero refs (or quote) + exact delete.\n";
        return s;
    }
    if name == "duplication" {
        let s = "";
        s += "SPECIALTY: Duplication / extract-to-shared\n";
        s += "Flag repeated logic only when ALL hold: (1) >=3 real occurrences after this change (2) would realistically be used more (3) stable enough to name (4) extraction reduces drift risk.\n";
        s += "Scope of shared home from fan-out: 3+ in one file => private helper; 3+ in one feature/module => module utils/helpers; 3+ across one app => app shared module; 3+ across apps/FE+BE domain => existing libs/ package; near-match existing helper => extend/reuse, no parallel utility.\n";
        s += "Always include occurrence count, file:line list, proposed symbol+path, params vs identical core. Search the repo, not only touched files.\n";
        s += "Do NOT flag: only 2 weak lookalikes; intentional test-fixture dup; trivial one-liners; similar control flow with different business meaning; huge unrelated DRY refactors.\n";
        s += "Severity: easy local 3-copy=minor/nit; drifting copies or dual-path same domain rule=major; reinvented existing helper=major. Suggested change = concrete signature + home path, not 'consider DRY'.\n";
        return s;
    }
    "SPECIALTY: general review\n"
}

fn make_review_prompt(specialty, plan_json, files_block, round_label, focus_note) {
    let p = "";
    p += "You are an independent specialist code reviewer for ONE concern only.\n";
    p += "You have no prior context. Review what you see. You do not know about other specialists or other rounds.\n\n";
    p += "ROUND: ";
    p += round_label;
    p += "\n\n";
    p += specialty_body(specialty);
    p += "\n";
    p += shared_review_rules();
    p += "\n## The plan (JSON)\n";
    p += plan_json;
    p += "\n\n## Files implemented / in scope\n";
    p += files_block;
    p += "\n\n";
    if focus_note != "" {
        p += "## Focus for this pass\n";
        p += focus_note;
        p += "\n\n";
    }
    p += "Return structured findings for your specialty only. line may be empty string if unknown.\n";
    p
}

fn make_arch_prompt(plan_json, files_block) {
    let p = "";
    p += "You are performing an ARCHITECTURE SENSE-CHECK only. Advisory. Conservative.\n";
    p += "Question: Does the way this is implemented actually make sense as it is now?\n\n";
    p += "Use read_file / grep to inspect the plan, listed files, and surrounding codebase patterns (similar features, helpers, layering).\n\n";
    p += "STANCE — default to fine:\n";
    p += "- Most working designs that fit local patterns are fine.\n";
    p += "- Only speak when there is a VERY CLEAR better path that fits this codebase, or the approach is CLEARLY poor (wrong layer, fights abstractions, parallel system for something already solved).\n";
    p += "- Style prefs, micro-opts, naming bikesheds are NOT findings. Preferable-but-not-clearly-better is NOT a finding. Silence/fine is correct when acceptable.\n\n";
    p += "CRITICAL:\n";
    p += "- Never demand a rewrite or re-architecture.\n";
    p += "- Never emit severity findings for triage.\n";
    p += "- Keep notes short (half page max). If fine: verdict fine and note empty string.\n\n";
    p += "Verdict enum: fine | clear-better-path | poor-fit\n\n";
    p += "## Plan (JSON)\n";
    p += plan_json;
    p += "\n\n## Files\n";
    p += files_block;
    p += "\n";
    p
}

fn make_verify_prompt(f) {
    let p = "";
    p += "You are an adversarial skeptic. Your job is to REFUTE review findings unless the shipped code independently proves them.\n";
    p += "Default real=false. Set real=true ONLY with concrete evidence you inspected yourself (file:line + what the code does).\n";
    p += "Missing evidence, ambiguity, or 'probably' => real=false.\n";
    p += "Use read_file / grep. Do not trust the finding text alone.\n";
    p += "If the finding is true but severity is inflated, still real=true and note that in reason.\n";
    p += "If the finding misreads out-of-scope, intentional tradeoff in the plan, or already-fixed code, real=false.\n\n";
    p += "FINDING TO VERIFY:\n";
    p += "Title: ";
    p += f.title;
    p += "\nSpecialty: ";
    p += f.specialty;
    p += "\nSeverity: ";
    p += f.severity;
    p += "\nFile: ";
    p += f.file;
    if f.line != () && f.line != "" {
        p += "\nClaimed line: ";
        p += f.line;
    }
    p += "\nObservation: ";
    p += f.observation;
    p += "\nWhy it matters: ";
    p += f.why;
    p += "\nSuggested change: ";
    p += f.suggested_change;
    p += "\n\nReturn: real (bool), reason (short), evidence (file:line quotes or concrete code behavior; empty string if unreal).\n";
    p
}

// ── Phase: Resolve ─────────────────────────────────────────────────────────

phase("Resolve");
log("Resolving task into a bound spec");

let resolve_prompt = "";
resolve_prompt += "Resolve the user's peer-review task into a single clear specification document.\n\n";
resolve_prompt += "INPUT (verbatim):\n";
resolve_prompt += json_encode(task);
resolve_prompt += "\n\nRules:\n";
resolve_prompt += "1. If INPUT is a filesystem path that exists, read the file and treat it as the PRD/spec.\n";
resolve_prompt += "2. If INPUT looks like a GitHub issue (#NNN or github.com/.../issues/NNN), use gh issue view (detect repo from git remote) and use title+body as the spec. If the issue references a PRD path, read that too.\n";
resolve_prompt += "3. Otherwise treat INPUT as a free-form task description.\n";
resolve_prompt += "4. Also run: git branch --show-current, and note base branch preference: ";
resolve_prompt += base_branch;
resolve_prompt += "\n5. Return ONLY the resolved specification as plain markdown text (no code edits).\n";
resolve_prompt += "Include a top heading and enough detail for an implementer to plan.\n";

let resolved = agent(resolve_prompt, #{
    label: "resolve-spec",
    capability_mode: "read-only",
    agent_type: "general-purpose",
});

let spec_text = "";
if resolved != () && resolved.success && type_of(resolved.output) == "string" {
    spec_text = resolved.output;
} else if resolved != () && resolved.success {
    spec_text = json_encode(resolved.output);
} else {
    // Fall back to raw task so the loop can continue.
    if type_of(task) == "string" {
        spec_text = task;
    } else {
        spec_text = json_encode(task);
    }
    log("resolve agent failed or empty — using raw task text");
}

let spec_path = write_scratch_file("spec.md", spec_text);
log("Spec written to " + spec_path);

// ── Phase: Plan ────────────────────────────────────────────────────────────

phase("Plan");
log("Writing structured plan");

let plan_prompt = "";
plan_prompt += "You are the planning engineer for a peer-reviewed implementation. Do NOT implement yet.\n";
plan_prompt += "Explore the codebase with read_file / grep / list_dir as needed so the plan fits local patterns.\n\n";
plan_prompt += "## Spec\n";
plan_prompt += spec_text;
plan_prompt += "\n\n## Required plan fields\n";
plan_prompt += "- goal: one paragraph restating the task\n";
plan_prompt += "- approach: design/architecture choice and main tradeoff accepted\n";
plan_prompt += "- files: explicit list of paths to create or modify\n";
plan_prompt += "- consumer_map: for every new/moved field or abstraction, who must read/honor it (API schema, DB, list/read UI, exporters/transformers for EACH pipeline, importers, jobs). Mark intentional deferrals.\n";
plan_prompt += "- invariants: uniqueness/atomicity; whether DB constraint or transaction enforces it\n";
plan_prompt += "- authz: who can call new procedures; which existing gate (role/assignment/tenant helper) is reused\n";
plan_prompt += "- failure_modes: what hard-fails vs user-visible degradation; no silent ACTIVE/success on failed setup\n";
plan_prompt += "- out_of_scope: deliberate non-goals so reviewers don't churn\n";
plan_prompt += "- open_questions: uncertainties\n";
plan_prompt += "- implementation_steps: ordered concrete steps\n";
plan_prompt += "\nSelf-check while planning: soft success, write-only wiring, races, thin authZ, mount wipes, dual-path drift, envelope casts, tests that assert failure paths.\n";
plan_prompt += "Return the structured plan object only.\n";

let plan_result = agent(plan_prompt, #{
    label: "plan",
    capability_mode: "read-only",
    agent_type: "plan",
    output_schema: plan_schema,
});

if plan_result == () || !plan_result.success || plan_result.output == () {
    complete(#{
        ok: false,
        error: "Plan agent failed — cannot continue peer-review loop",
        spec_path: spec_path,
    });
}

let plan = plan_result.output;
let plan_files = as_array(plan.files);
let plan_steps = as_array(plan.implementation_steps);
let plan_json = json_encode(plan);
let plan_md = "";
plan_md += "# Plan\n\n## Goal\n";
plan_md += as_string(plan.goal);
plan_md += "\n\n## Approach\n";
plan_md += as_string(plan.approach);
plan_md += "\n\n## Files\n";
for f in plan_files {
    plan_md += "- ";
    plan_md += as_string(f);
    plan_md += "\n";
}
plan_md += "\n## Consumer map\n";
plan_md += as_string(plan.consumer_map);
plan_md += "\n\n## Invariants\n";
plan_md += as_string(plan.invariants);
plan_md += "\n\n## AuthZ\n";
plan_md += as_string(plan.authz);
plan_md += "\n\n## Failure modes\n";
plan_md += as_string(plan.failure_modes);
plan_md += "\n\n## Out of scope\n";
plan_md += as_string(plan.out_of_scope);
plan_md += "\n\n## Open questions\n";
plan_md += as_string(plan.open_questions);
plan_md += "\n\n## Steps\n";
for s in plan_steps {
    plan_md += "- ";
    plan_md += as_string(s);
    plan_md += "\n";
}
let plan_path = write_scratch_file("plan.md", plan_md);
log("Plan written to " + plan_path);

// ── Phase: Implement ───────────────────────────────────────────────────────

phase("Implement");
log("Implementing against the plan");

let impl_prompt = "";
impl_prompt += "You are the implementing engineer. Execute the plan fully. Prefer existing helpers, auth gates, and DB patterns in this repo.\n";
impl_prompt += "Use the monorepo conventions (Nx via yarn nx, Prisma when needed). Do not expand out_of_scope.\n\n";
impl_prompt += "While implementing, self-check: soft success, write-only wiring, races, thin authZ, mount wipes, dual-path drift, envelope casts, failure-path tests.\n";
impl_prompt += "When soft-fails appear: harden exact types at the boundary; never paper with any / as any / more optionals.\n";
impl_prompt += "Verify build/typecheck for touched projects before finishing (e.g. yarn nx run <project>:typecheck or equivalent).\n\n";
impl_prompt += "## Spec\n";
impl_prompt += spec_text;
impl_prompt += "\n\n## Plan (JSON)\n";
impl_prompt += plan_json;
impl_prompt += "\n\nReturn: summary, files_touched (every created/modified path), build_ok, notes.\n";
impl_prompt += "files_touched must be accurate — reviewers only examine this list.\n";

let impl_result = agent(impl_prompt, #{
    label: "implement",
    capability_mode: "all",
    agent_type: "general-purpose",
    output_schema: implement_schema,
});

if impl_result == () || !impl_result.success || impl_result.output == () {
    complete(#{
        ok: false,
        error: "Implement agent failed",
        spec_path: spec_path,
        plan_path: plan_path,
    });
}

let impl = impl_result.output;
let files_touched = as_array(impl.files_touched);
if files_touched.len() == 0 {
    files_touched = plan_files;
}

// Prefer plan files unioned with reported touches.
files_touched = merge_files(plan_files, files_touched);

let files_md = "";
for f in files_touched {
    files_md += f;
    files_md += "\n";
}
let files_path = write_scratch_file("files-touched.md", files_md);
log("Implementation done; files_touched=" + files_touched.len().to_string() + " build_ok=" + impl.build_ok.to_string());

// Round tracking for summary
let all_round_stats = [];
let all_deferred = [];
let all_rejected = [];
let all_accepted_applied = [];
let strongest_arch = "fine";
let strongest_arch_note = "";
let files_block = files_prompt_block(files_touched);

// ── Review / Verify / Triage / Fix loop ────────────────────────────────────

let round_n = 1;
while round_n <= max_rounds {
    let round_label = "R" + round_n.to_string();
    let is_delta = round_n > 1;
    let focus_note = "";
    if is_delta {
        focus_note = "This is a DELTA re-review after fixes. Focus on the listed files and regressions introduced by recent fixes. Do not re-litigate already-correct code. Do not pad.";
    }

    // ── Review ────────────────────────────────────────────────────────────
    phase("Review");
    log(round_label + ": spawning parallel specialists");

    let specialties = ["correctness", "security", "silent", "recurring", "testing", "deadcode", "duplication"];
    let specialty_labels = ["Correctness", "Security", "SilentFailure", "RecurringPattern", "Testing", "DeadCode", "Duplication"];
    let specialty_count = specialties.len();
    let review_jobs = [];
    let si = 0;
    for sp in specialties {
        let pr = make_review_prompt(sp, plan_json, files_block, round_label, focus_note);
        let agent_type = "general-purpose";
        if sp == "security" { agent_type = "backend-architect"; }
        if sp == "testing" { agent_type = "test-writer-fixer"; }
        review_jobs.push(#{
            prompt: pr,
            label: round_label + "-" + sp,
            capability_mode: "read-only",
            agent_type: agent_type,
            output_schema: findings_schema,
        });
        si += 1;
    }

    // Architecture only on first full pass (saves 1 agent per extra round).
    let arch_included = !is_delta;
    if arch_included {
        review_jobs.push(#{
            prompt: make_arch_prompt(plan_json, files_block),
            label: round_label + "-architecture",
            capability_mode: "read-only",
            agent_type: "plan",
            output_schema: arch_schema,
        });
    }

    let review_results = parallel(review_jobs);

    // Collect findings from actionable specialists; arch is last if present.
    let merged = [];
    let clean_specialists = [];
    let failed_specialists = [];
    let ri = 0;
    while ri < specialty_count {
        let r = review_results[ri];
        let label = specialty_labels[ri];
        let found = [];
        let ok = false;
        if r != () && r.success && r.output != () {
            found = as_array(r.output.findings);
            ok = true;
        }
        if !ok {
            failed_specialists.push(label);
            log(round_label + ": retrying specialist " + label);
            let retry = agent(
                make_review_prompt(specialties[ri], plan_json, files_block, round_label, focus_note),
                #{
                    label: round_label + "-" + specialties[ri] + "-retry",
                    capability_mode: "read-only",
                    agent_type: "general-purpose",
                    output_schema: findings_schema,
                }
            );
            if retry != () && retry.success && retry.output != () {
                found = as_array(retry.output.findings);
                ok = true;
            }
        }
        if !ok {
            merged.push(#{
                title: "reviewer-failed (" + label + ")",
                severity: "major",
                file: "general",
                line: "",
                observation: "Specialist " + label + " failed twice and produced no usable output.",
                why: "Coverage gap for this specialty in " + round_label,
                suggested_change: "Re-run peer-review for this specialty or manual review.",
                specialty: label,
            });
        } else if found.len() == 0 {
            clean_specialists.push(label);
        } else {
            for f in found {
                merged.push(#{
                    title: as_string(f.title),
                    severity: as_string(f.severity),
                    file: as_string(f.file),
                    line: as_string(f.line),
                    observation: as_string(f.observation),
                    why: as_string(f.why),
                    suggested_change: as_string(f.suggested_change),
                    specialty: label,
                });
            }
        }
        ri += 1;
    }

    // Architecture note
    if arch_included {
        let ar = review_results[specialty_count];
        let arch_verdict = "fine";
        let arch_note = "";
        if ar != () && ar.success && ar.output != () {
            if ar.output.verdict != () { arch_verdict = trimmed(ar.output.verdict); }
            if ar.output.note != () { arch_note = ar.output.note; }
        } else {
            // retry once
            let ar2 = agent(make_arch_prompt(plan_json, files_block), #{
                label: round_label + "-architecture-retry",
                capability_mode: "read-only",
                agent_type: "plan",
                output_schema: arch_schema,
            });
            if ar2 != () && ar2.success && ar2.output != () {
                if ar2.output.verdict != () { arch_verdict = trimmed(ar2.output.verdict); }
                if ar2.output.note != () { arch_note = ar2.output.note; }
            } else {
                arch_verdict = "fine";
                arch_note = "";
            }
        }
        // Rank: poor-fit > clear-better-path > fine
        if arch_verdict == "poor-fit" {
            strongest_arch = "poor-fit";
            strongest_arch_note = arch_note;
        } else if arch_verdict == "clear-better-path" && strongest_arch != "poor-fit" {
            strongest_arch = "clear-better-path";
            strongest_arch_note = arch_note;
        }
        let arch_md = "# Architecture sense-check (" + round_label + ")\n\nVerdict: " + arch_verdict + "\n\n" + arch_note + "\n";
        write_scratch_file("round-" + round_n.to_string() + "-architecture-note.md", arch_md);
        log(round_label + " architecture: " + arch_verdict);
    }

    // Dedup near-identical titles+files (keep higher severity)
    let deduped = [];
    for f in merged {
        let dup_idx = -1;
        let di = 0;
        for d in deduped {
            let same_file = d.file == f.file;
            let same_title = d.title == f.title;
            // crude near-dup: same file and overlapping title prefix
            if same_file && same_title {
                dup_idx = di;
            }
            di += 1;
        }
        if dup_idx < 0 {
            deduped.push(f);
        } else {
            if severity_rank(f.severity) > severity_rank(deduped[dup_idx].severity) {
                // replace with stronger severity; note both specialties
                let kept = deduped[dup_idx];
                let specs = kept.specialty + "+" + f.specialty;
                deduped[dup_idx] = #{
                    title: f.title,
                    severity: f.severity,
                    file: f.file,
                    line: f.line,
                    observation: f.observation,
                    why: f.why,
                    suggested_change: f.suggested_change,
                    specialty: specs,
                };
            }
        }
    }

    let comments_md = "# Review " + round_label + "\n\n## Summary\n";
    comments_md += "Merged ";
    comments_md += deduped.len().to_string();
    comments_md += " findings after specialist fan-out (pre-verification).\n\n## Comments\n";
    let ci = 0;
    for f in deduped {
        comments_md += "\n### C";
        comments_md += (ci + 1).to_string();
        comments_md += " — ";
        comments_md += f.title;
        comments_md += "\n- **Specialty**: ";
        comments_md += f.specialty;
        comments_md += "\n- **Severity**: ";
        comments_md += f.severity;
        comments_md += "\n- **File**: ";
        comments_md += f.file;
        comments_md += "\n- **Observation**: ";
        comments_md += f.observation;
        comments_md += "\n- **Why it matters**: ";
        comments_md += f.why;
        comments_md += "\n- **Suggested change**: ";
        comments_md += f.suggested_change;
        comments_md += "\n";
        ci += 1;
    }
    comments_md += "\n## Clean specialists\n";
    for c in clean_specialists {
        comments_md += "- ";
        comments_md += c;
        comments_md += ": no findings\n";
    }
    write_scratch_file("round-" + round_n.to_string() + "-comments.md", comments_md);
    log(round_label + ": " + deduped.len().to_string() + " findings pre-verify");

    if deduped.len() == 0 {
        all_round_stats.push(#{
            round: round_n,
            raised: 0,
            confirmed: 0,
            accepted: 0,
            rejected: 0,
            deferred: 0,
        });
        log(round_label + ": no findings — early exit remaining rounds");
        break;
    }

    // ── Verify (fail-closed) ──────────────────────────────────────────────
    phase("Verify");
    // Cap what we verify to control budget; prioritize by severity.
    // Simple selection: take first MAX_VERIFY after sorting by severity rank desc.
    let ordered = [];
    // 4 buckets
    for f in deduped {
        if severity_rank(f.severity) == 4 { ordered.push(f); }
    }
    for f in deduped {
        if severity_rank(f.severity) == 3 { ordered.push(f); }
    }
    for f in deduped {
        if severity_rank(f.severity) == 2 { ordered.push(f); }
    }
    for f in deduped {
        if severity_rank(f.severity) == 1 { ordered.push(f); }
    }

    let to_verify = [];
    let vi = 0;
    for f in ordered {
        if vi < MAX_VERIFY {
            to_verify.push(f);
        }
        vi += 1;
    }
    if ordered.len() > MAX_VERIFY {
        log(round_label + ": verifying top " + MAX_VERIFY.to_string() + " of " + ordered.len().to_string() + " by severity; remainder dropped as unverified");
    }

    let vjobs = [];
    for f in to_verify {
        vjobs.push(#{
            prompt: make_verify_prompt(f),
            label: round_label + "-verify-" + f.file,
            capability_mode: "read-only",
            output_schema: verdict_schema,
        });
    }
    let verdicts = parallel(vjobs);

    let confirmed = [];
    let dropped = 0;
    let vj = 0;
    for v in verdicts {
        // Fail closed: missing/failed/unusable => not confirmed
        if v != () && v.success && v.output != () && v.output.real == true
            && v.output.evidence != () && trimmed(v.output.evidence) != "" {
            let base = to_verify[vj];
            confirmed.push(#{
                title: base.title,
                severity: base.severity,
                file: base.file,
                line: base.line,
                observation: base.observation,
                why: base.why,
                suggested_change: base.suggested_change,
                specialty: base.specialty,
                evidence: v.output.evidence,
                verify_reason: v.output.reason,
            });
        } else {
            dropped += 1;
        }
        vj += 1;
    }
    log(round_label + ": " + confirmed.len().to_string() + "/" + to_verify.len().to_string() + " findings survived verification (" + dropped.to_string() + " dropped)");

    let confirmed_md = "# Confirmed findings " + round_label + "\n\n";
    confirmed_md += findings_prompt_block(confirmed);
    write_scratch_file("round-" + round_n.to_string() + "-confirmed.md", confirmed_md);

    if confirmed.len() == 0 {
        all_round_stats.push(#{
            round: round_n,
            raised: deduped.len(),
            confirmed: 0,
            accepted: 0,
            rejected: 0,
            deferred: 0,
        });
        log(round_label + ": nothing confirmed — early exit remaining rounds");
        break;
    }

    // ── Triage (independent judge — NOT the implementer) ──────────────────
    phase("Triage");
    log(round_label + ": independent judge triaging confirmed findings");

    let triage_prompt = "";
    triage_prompt += "You are an independent triage judge. You did NOT implement this code and must not defend it.\n";
    triage_prompt += "Only CONFIRMED findings (already adversarially verified against the code) are listed.\n";
    triage_prompt += "For each finding, decide accept | reject | defer.\n\n";
    triage_prompt += "Rules:\n";
    triage_prompt += "- accept: correct, in scope, and should be implemented now. Include implementation_note with the specific edit.\n";
    triage_prompt += "- reject: wrong, already handled, misread of intentional plan tradeoff, or fix would be harmful. Reasoning mandatory.\n";
    triage_prompt += "- defer: reasonable but out of scope / follow-up. Reasoning + where to track mandatory.\n";
    triage_prompt += "- Severity is informational, not binding. A cheap nit can be accept; a misunderstood blocker can be reject.\n";
    triage_prompt += "- Prefer accept for real blocker/major security, soft-success, write-only wiring, auth fail-open, data-loss soft-fails.\n";
    triage_prompt += "- Soft-fail fixes must harden exact types at boundaries — never accept a fix that adds any/as any/more optionals.\n";
    triage_prompt += "- Read the plan's out_of_scope and the code before deciding. Use tools.\n";
    triage_prompt += "- index is the INDEX number shown on each finding (0-based).\n";
    triage_prompt += "- Every finding must appear exactly once in decisions.\n\n";
    triage_prompt += "## Plan (JSON)\n";
    triage_prompt += plan_json;
    triage_prompt += "\n\n## Confirmed findings\n";
    triage_prompt += findings_prompt_block(confirmed);
    triage_prompt += "\nReturn decisions array covering every index.\n";

    let triage_result = agent(triage_prompt, #{
        label: round_label + "-triage",
        capability_mode: "read-only",
        agent_type: "general-purpose",
        output_schema: triage_schema,
    });

    let decisions = [];
    if triage_result != () && triage_result.success && triage_result.output != () {
        decisions = as_array(triage_result.output.decisions);
    }
    if decisions.len() == 0 {
        // Fail closed for triage failure: defer all confirmed (do not auto-accept)
        log(round_label + ": triage agent failed — deferring all confirmed findings");
        let ti = 0;
        for f in confirmed {
            decisions.push(#{
                index: ti,
                decision: "defer",
                reasoning: "Triage agent failed; deferred automatically for human review.",
                implementation_note: "",
            });
            ti += 1;
        }
    }

    let accepted = [];
    let n_accept = 0;
    let n_reject = 0;
    let n_defer = 0;
    let decisions_md = "# Round " + round_n.to_string() + " decisions (confirmed findings only)\n\n";

    for d in decisions {
        let idx = d.index;
        if type_of(idx) == "f64" { idx = idx; }
        // bounds check
        if idx < 0 || idx >= confirmed.len() {
            continue;
        }
        let f = confirmed[idx];
        let dec = trimmed(d.decision);
        let reasoning = if d.reasoning != () { d.reasoning } else { "" };
        let impl_note = if d.implementation_note != () { d.implementation_note } else { "" };

        decisions_md += "## INDEX ";
        decisions_md += idx.to_string();
        decisions_md += " — ";
        decisions_md += f.title;
        decisions_md += "\n- **Decision**: ";
        decisions_md += dec;
        decisions_md += "\n- **Reasoning**: ";
        decisions_md += reasoning;
        if impl_note != "" {
            decisions_md += "\n- **Implementation note**: ";
            decisions_md += impl_note;
        }
        decisions_md += "\n\n";

        if dec == "accept" {
            n_accept += 1;
            accepted.push(#{
                title: f.title,
                severity: f.severity,
                file: f.file,
                line: f.line,
                observation: f.observation,
                why: f.why,
                suggested_change: f.suggested_change,
                specialty: f.specialty,
                evidence: f.evidence,
                implementation_note: impl_note,
            });
        } else if dec == "reject" {
            n_reject += 1;
            all_rejected.push(#{
                round: round_n,
                title: f.title,
                reason: reasoning,
            });
        } else {
            n_defer += 1;
            all_deferred.push(#{
                round: round_n,
                title: f.title,
                file: f.file,
                reason: reasoning,
                specialty: f.specialty,
            });
        }
    }

    write_scratch_file("round-" + round_n.to_string() + "-decisions.md", decisions_md);
    log(round_label + " triage: accept=" + n_accept.to_string() + " reject=" + n_reject.to_string() + " defer=" + n_defer.to_string());

    all_round_stats.push(#{
        round: round_n,
        raised: deduped.len(),
        confirmed: confirmed.len(),
        accepted: n_accept,
        rejected: n_reject,
        deferred: n_defer,
    });

    if accepted.len() == 0 {
        log(round_label + ": nothing accepted — skipping fix and further rounds");
        break;
    }

    // ── Fix ───────────────────────────────────────────────────────────────
    phase("Fix");
    log(round_label + ": applying " + accepted.len().to_string() + " accepted findings");

    let fix_prompt = "";
    fix_prompt += "You are the implementing engineer applying ACCEPTED review fixes only.\n";
    fix_prompt += "Do not re-architect. Do not expand scope. Implement each accepted item's suggested_change / implementation_note.\n\n";
    fix_prompt += "Soft-fail / soft-type fixes:\n";
    fix_prompt += "1. Determine the exact expected type (domain, API, DB, callers).\n";
    fix_prompt += "2. Tighten that hard type; validate once at the boundary.\n";
    fix_prompt += "3. Remove the silent fallback / empty default / type-papering.\n";
    fix_prompt += "4. NEVER fix with any, as any, as unknown as T, blanket !, or by making more fields optional.\n";
    fix_prompt += "If applying a fix breaks the build/types, put it in rejected_during_apply with reason — do not silently drop.\n";
    fix_prompt += "Verify build/typecheck for touched projects.\n\n";
    fix_prompt += "## Plan (JSON)\n";
    fix_prompt += plan_json;
    fix_prompt += "\n\n## Accepted findings to apply\n";
    fix_prompt += json_encode(accepted);
    fix_prompt += "\n\nReturn summary, files_touched, build_ok, applied (titles), rejected_during_apply.\n";

    let fix_result = agent(fix_prompt, #{
        label: round_label + "-fix",
        capability_mode: "all",
        agent_type: "general-purpose",
        output_schema: fix_schema,
    });

    if fix_result != () && fix_result.success && fix_result.output != () {
        let fx = fix_result.output;
        let fx_files = as_array(fx.files_touched);
        if fx_files.len() > 0 {
            files_touched = merge_files(files_touched, fx_files);
            files_block = files_prompt_block(files_touched);
            let fm = "";
            for f in files_touched {
                fm += as_string(f);
                fm += "\n";
            }
            write_scratch_file("files-touched.md", fm);
        }
        for t in as_array(fx.applied) {
            all_accepted_applied.push(#{ round: round_n, title: as_string(t) });
        }
        for r in as_array(fx.rejected_during_apply) {
            all_rejected.push(#{
                round: round_n,
                title: as_string(r.title),
                reason: "rejected during apply: " + as_string(r.reason),
            });
        }
        let build_ok_str = "unknown";
        if fx.build_ok != () { build_ok_str = fx.build_ok.to_string(); }
        log(round_label + " fix done build_ok=" + build_ok_str);
    } else {
        log(round_label + ": fix agent failed — stopping further rounds");
        break;
    }

    round_n += 1;
}

// ── Summary ────────────────────────────────────────────────────────────────

phase("Summary");
log("Writing final summary");

let summary_md = "";
summary_md += "# Peer review summary\n\n";
summary_md += "**Spec source**: see scratch/spec.md\n";
summary_md += "**Review model**: plan → implement → parallel specialists → adversarial verify (fail-closed) → independent triage → fix";
if max_rounds > 1 {
    summary_md += " → optional delta re-review";
}
summary_md += "\n";
summary_md += "**Max rounds**: ";
summary_md += max_rounds.to_string();
summary_md += "\n**Files touched**: ";
summary_md += files_touched.len().to_string();
summary_md += "\n\n## What was built\n\n";
summary_md += as_string(impl.summary);
summary_md += "\n\n## Review rounds\n";

for st in all_round_stats {
    summary_md += "\n### Round ";
    summary_md += st.round.to_string();
    summary_md += "\n- Raised (pre-verify): ";
    summary_md += st.raised.to_string();
    summary_md += "\n- Confirmed (post-verify): ";
    summary_md += st.confirmed.to_string();
    summary_md += "\n- Accepted: ";
    summary_md += st.accepted.to_string();
    summary_md += " | Rejected: ";
    summary_md += st.rejected.to_string();
    summary_md += " | Deferred: ";
    summary_md += st.deferred.to_string();
    summary_md += "\n";
}

summary_md += "\n## Applied fixes\n";
if all_accepted_applied.len() == 0 {
    summary_md += "\n(none)\n";
} else {
    for a in all_accepted_applied {
        summary_md += "- R";
        summary_md += a.round.to_string();
        summary_md += ": ";
        summary_md += a.title;
        summary_md += "\n";
    }
}

summary_md += "\n## Deferred items\n";
if all_deferred.len() == 0 {
    summary_md += "\n(none)\n";
} else {
    for d in all_deferred {
        summary_md += "- R";
        summary_md += d.round.to_string();
        summary_md += " [";
        summary_md += d.specialty;
        summary_md += "] ";
        summary_md += d.title;
        summary_md += " (";
        summary_md += d.file;
        summary_md += "): ";
        summary_md += d.reason;
        summary_md += "\n";
    }
}

summary_md += "\n## Rejected items\n";
if all_rejected.len() == 0 {
    summary_md += "\n(none)\n";
} else {
    for r in all_rejected {
        summary_md += "- R";
        summary_md += r.round.to_string();
        summary_md += ": ";
        summary_md += r.title;
        summary_md += " — ";
        summary_md += r.reason;
        summary_md += "\n";
    }
}

if strongest_arch != "fine" {
    summary_md += "\n## Architecture sense-check (user advisory)\n\n";
    summary_md += "**Verdict**: ";
    summary_md += strongest_arch;
    summary_md += "\n\nFor your consideration — the architecture sense-check thought:\n\n";
    summary_md += strongest_arch_note;
    summary_md += "\n\nThis is not a rewrite demand and was never triaged as implementable work during the loop.\n";
}

summary_md += "\n## Artifacts\n";
summary_md += "- scratch/spec.md\n- scratch/plan.md\n- scratch/files-touched.md\n";
summary_md += "- scratch/round-*-comments.md / confirmed.md / decisions.md\n";
summary_md += "- scratch/round-1-architecture-note.md (if produced)\n";

let report_path = write_scratch_file("summary.md", summary_md);

// Optional: polish report via agent for readability (cheap single call)
let polish = agent(
    "Polish this peer-review summary for a human reader. Keep all facts, counts, deferred items, and architecture note. Return only markdown in report_markdown. Do not invent findings.\n\n" + summary_md,
    #{
        label: "summary-polish",
        capability_mode: "read-only",
        output_schema: summary_schema,
    }
);
if polish != () && polish.success && polish.output != () && polish.output.report_markdown != () {
    let polished = polish.output.report_markdown;
    if trimmed(polished) != "" {
        report_path = write_scratch_file("summary.md", polished);
        summary_md = polished;
    }
}

log("Peer-review complete → " + report_path);

complete(#{
    ok: true,
    path: report_path,
    report: summary_md,
    files_touched: files_touched,
    rounds: all_round_stats,
    deferred: all_deferred,
    architecture: #{
        verdict: strongest_arch,
        note: strongest_arch_note,
    },
    plan_path: plan_path,
    spec_path: spec_path,
});
```

## Hyprland (Arch)

Hyprland + hyprpaper config and Arch bootstrap scripts. All blocks here are `os=linux`.

```sh
python3 /tmp/dotfiles extract --only ~/.config/hypr   # or a full extract
~/.config/hypr/install.sh                            # generic / non-NVIDIA
~/.config/hypr/install-nvidia.sh                     # NVIDIA: runs install.sh, then the driver stack
```

Run as your normal user; the scripts call `sudo` when needed.

**What the scripts do**

- Sync pacman, install Hyprland + ecosystem (hyprpaper, hypridle, hyprlock, hyprshot, waybar, swaync, wofi,
  thunar, xdg-desktop-portal-hyprland, qt wayland), pipewire + wireplumber, brightnessctl, playerctl, firefox,
  polkit-gnome, base-devel + git.
- Bootstrap `paru` if no AUR helper exists, then AUR: `pyprland`, `spotify`, `claude-desktop`.
- Add the `dynamic-cursors` plugin via `hyprpm` (loaded by `hyprland.conf`).
- Enable user services `pipewire`, `pipewire-pulse`, `wireplumber`; create `~/Pictures` and `~/Screenshots`.
- `install-nvidia.sh` also installs `nvidia-dkms nvidia-utils libva-nvidia-driver egl-wayland linux-headers`, adds
  `nvidia nvidia_modeset nvidia_uvm nvidia_drm` to `MODULES` in `/etc/mkinitcpio.conf` (rebuilds initramfs), and
  writes `/etc/modprobe.d/nvidia.conf` with `options nvidia_drm modeset=1 fbdev=1`.

**After install**

1. Reboot (NVIDIA: the DKMS module and `nvidia_drm.modeset=1` take effect at boot).
2. Put a wallpaper at the path in `hyprpaper.conf` (currently `/home/sp00nes/Pictures/arch-linux_upscaled.png`).
3. Create `~/.config/theme/colors-hyprland.conf`; `hyprland.conf` sources it on line 1 for border colors.
4. Install WezTerm (`$terminal`); the scripts do not.
5. Monitors are hardcoded (`eDP-1`, `HDMI-A-1`, `HDMI-A-2`); edit the `monitor=` lines for other setups.

**Keybinds** (`SUPER` is the mod key)

| Bind | Action |
| --- | --- |
| `SUPER + C` | Terminal |
| `SUPER + E` | File manager (thunar) |
| `SUPER + B` | Firefox |
| `SUPER + X` | Spotify |
| `SUPER + space` | wofi launcher |
| `SUPER + Q` | Kill active window |
| `SUPER + F` | Fullscreen |
| `SUPER + V` | Float + center window |
| `SUPER + S` | Toggle `magic` special workspace |
| `SUPER + N` | pypr toggle term |
| `SUPER + T` | pypr toggle taskbar |
| `SUPER + 1..0` | Switch workspace |
| `SUPER + SHIFT + 1..0` | Move window to workspace |
| `SUPER + SHIFT + M` | Exit Hyprland |
| `Print / CTRL+Print / ALT+Print` | Window / region / active-output screenshot |

Volume, brightness, and media keys go through `wpctl`, `brightnessctl`, and `playerctl`.

#### `~/.config/hypr/hyprland.conf`

```ini file=~/.config/hypr/hyprland.conf mode=755 os=linux
source = ~/.config/theme/colors-hyprland.conf

# NVIDIA environment variables
env = LIBVA_DRIVER_NAME,nvidia
env = XDG_SESSION_TYPE,wayland
env = GBM_BACKEND,nvidia-drm
env = __GLX_VENDOR_LIBRARY_NAME,nvidia
env = NVD_BACKEND,direct
env = AQ_DRM_DEVICES,/dev/dri/card1:/dev/dri/card2

$mainMod = SUPER
$terminal = wezterm start --always-new-process
$fileManager = thunar
$menu = wofi -n

monitor=eDP-1,1920x1080@144,0x0,1
monitor=HDMI-A-1,1920x1080@144,1920x0,1
monitor=HDMI-A-2,preferred,3840x0,1
monitor=,preferred,auto,1

exec-once = hypridle
exec-once = waybar
exec-once = hyprpaper
exec-once = swaync
exec-once = pypr
exec-once = swaync-client -df
exec-once = pactl set-sink-mute @DEFAULT_SINK@ 0
exec-once = hyprctl plugin load $HOME/.local/share/hyprpm/dynamic-cursors/dynamic-cursors.so
exec-once = dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP
exec-once = systemctl --user import-environment WAYLAND_DISPLAY XDG_CURRENT_DESKTOP
cursor {
    no_hardware_cursors = true
}

xwayland {
	force_zero_scaling = true
}

plugin:dynamic-cursors {
    mode = stretch
    threshold = 2
    shaperule = grab, stretch, stretch:limit: 2000
    rotate {
        length = 12
        offset = 30
    }
    stretch {
        limit = 1000
        # linear             - a linear function is used
        # quadratic          - a quadratic function is used
        # negative_quadratic - negative version of the quadratic one, feels more aggressive
        function = negative_quadratic
    }
    shake {
        enabled = false
    }
}
general { 
    gaps_in = 2
        gaps_out = 5
        border_size = 1
        col.active_border = $accent
        col.inactive_border = $inactive
        resize_on_border = true
        allow_tearing = false
        layout = dwindle
}
decoration {
    rounding = 10
        active_opacity = 1
        inactive_opacity = 1
        fullscreen_opacity = 1
        blur {
            enabled = false
        }
    shadow {
        enabled = true
            range = 15
            render_power = 5
            color = $shadow
    }
}
animations {
    enabled = false
}
dwindle {
    preserve_split = true
}
misc {
    force_default_wallpaper = -1
    disable_hyprland_logo = true
    focus_on_activate = true
    vrr = 0
}
input {
    kb_options = caps:escape
    kb_layout = us
        follow_mouse = 1
        sensitivity = 0
        touchpad {
            natural_scroll = true
        }
}
#gestures {
#    workspace_swipe = true
#        workspace_swipe_distance = 300
#        workspace_swipe_cancel_ratio = .05
#        workspace_swipe_min_speed_to_force = 0
#}
device {
    name = epic-mouse-v1
    sensitivity = 0
}

#Basic Commands

bind = $mainMod, Q, killactive
bind = $mainMod, C, exec, $terminal
bind = $mainMod, E, exec, $fileManager
bind = $mainMod, B, exec, firefox
bind = $mainMod, X, exec, spotify
bind = $mainMod, space, exec, pidof wofi && killall wofi || wofi -n
bind = $mainMod SHIFT, M, exit
# bind = $mainMod, l, exec, hyprlock

#Screenshots
bind = CTRL, Print, exec, hyprshot -m region -o ~/Screenshots/
bind = , Print, exec, hyprshot -m window -o ~/Screenshots/
bind = ALT, Print, exec, hyprshot -m active -m output -o ~/Screenshots/

#Other settings
bindel = ,XF86AudioRaiseVolume, exec, wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+
bindel = ,XF86AudioLowerVolume, exec, wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-
bindel = ,XF86AudioMute, exec, wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle
bindel = ,XF86AudioMicMute, exec, wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle
bindel = ,XF86MonBrightnessUp, exec, brightnessctl s 10%+
bindel = ,XF86MonBrightnessDown, exec, brightnessctl s 10%-
bindl = , XF86AudioNext, exec, playerctl next
bindl = , XF86AudioPause, exec, playerctl play-pause
bindl = , XF86AudioPlay, exec, playerctl play-pause
bindl = , XF86AudioPrev, exec, playerctl previous
bindl = , switch:on:Lid Switch, exec, systemctl suspend
# bindl = , switch:off:Lid Switch, exec, hyprctl dispatch dpms on

#Window management key binds
bind = $mainMod, F, fullscreen
bind = $mainMod, V, exec, hyprctl --batch "dispatch togglefloating; dispatch resizeactive exact 1000 600; dispatch centerwindow 1;"
bind = $mainMod, left, movefocus, l
bind = $mainMod, right, movefocus, r
bind = $mainMod, up, movefocus, u
bind = $mainMod, down, movefocus, d
bind = $mainMod, 1, workspace, 1
bind = $mainMod, 2, workspace, 2
bind = $mainMod, 3, workspace, 3
bind = $mainMod, 4, workspace, 4
bind = $mainMod, 5, workspace, 5
bind = $mainMod, 6, workspace, 6
bind = $mainMod, 7, workspace, 7
bind = $mainMod, 8, workspace, 8
bind = $mainMod, 9, workspace, 9
bind = $mainMod, 0, workspace, 10
bind = $mainMod SHIFT, 1, movetoworkspace, 1
bind = $mainMod SHIFT, 2, movetoworkspace, 2
bind = $mainMod SHIFT, 3, movetoworkspace, 3
bind = $mainMod SHIFT, 4, movetoworkspace, 4
bind = $mainMod SHIFT, 5, movetoworkspace, 5
bind = $mainMod SHIFT, 6, movetoworkspace, 6
bind = $mainMod SHIFT, 7, movetoworkspace, 7
bind = $mainMod SHIFT, 8, movetoworkspace, 8
bind = $mainMod SHIFT, 9, movetoworkspace, 9
bind = $mainMod SHIFT, 0, movetoworkspace, 10
bind = ALT, left, movewindow, l
bind = ALT, right, movewindow, r
bind = ALT, up, movewindow, u
bind = ALT, down, movewindow, d 
bindm = $mainMod, mouse:272, movewindow
bindm = $mainMod, mouse:273, resizewindow

#Special window sections
bind = $mainMod, S, togglespecialworkspace, magic
bind = $mainMod SHIFT, S, movetoworkspace, special:magic
bind = $mainMod, N, exec, pypr toggle term
bind = $mainMod, T, exec, pypr toggle taskbar

#Layerrules
layerrule = blur on, match:namespace waybar
layerrule = ignore_alpha 0.5, match:namespace waybar
layerrule = blur on, match:namespace swaync-control-center
layerrule = ignore_alpha 0.5, match:namespace swaync-control-center
layerrule = blur on, match:namespace swaync-notification-window
layerrule = ignore_alpha 0.5, match:namespace swaync-notification-window
layerrule = no_anim on, match:namespace selection
#
# Firefox Picture-in-Picture rules
windowrule = match:title ^(Picture-in-Picture)$, float on, pin on, no_blur on, border_size 0, opacity 1.0 override 1.0 override, size 25% 25%, move 74% 73%

# Discord popout rules
windowrule = match:title ^(Discord Popout)$, float on, pin on, no_blur on, border_size 0, opacity 1.0 override 1.0 override, size 25% 25%, move 74% 73%

# Claude rules
windowrule = match:class ^(Claude)$, workspace special:magic, size 98% 94%, move 1% 5%
windowrule = match:title ^(Claude)$, float on
```

#### `~/.config/hypr/hyprpaper.conf`

```ini file=~/.config/hypr/hyprpaper.conf os=linux
wallpaper {
    monitor = eDP-1
    path = /home/sp00nes/Pictures/arch-linux_upscaled.png
}

wallpaper {
    monitor = HDMI-A-1
    path = /home/sp00nes/Pictures/arch-linux_upscaled.png
}

wallpaper {
    monitor = HDMI-A-2
    path = /home/sp00nes/Pictures/arch-linux_upscaled.png
}

splash = false
```

#### `~/.config/hypr/claude-first-launch.sh`

```bash file=~/.config/hypr/claude-first-launch.sh mode=755 os=linux eol=none
#!/bin/bash

# Toggle to the special workspace named "magic"
hyprctl dispatch togglespecialworkspace magic

# Launch Claude in the background so the script can continue
claude-desktop &

# Store the PID of claude-desktop
CLAUDE_PID=$!

# Wait for Claude window to appear
# This checks if any window with Claude class exists
while ! hyprctl clients | grep -q "class: Claude"; do
  # Check if the process is still running
  if ! kill -0 $CLAUDE_PID 2>/dev/null; then
    echo "Claude process terminated unexpectedly"
    exit 1
  fi
  sleep 0.1
done

# Give it a moment to apply window rules
sleep 0.5

# Toggle back to regular workspace
hyprctl dispatch togglespecialworkspace magic
```

#### `~/.config/hypr/install.sh`

```bash file=~/.config/hypr/install.sh mode=755 os=linux
#!/usr/bin/env bash
# Install everything required by this Hyprland config on Arch Linux.
# Generic version - no GPU-vendor packages. For NVIDIA, run install-nvidia.sh.
# Run as your normal user (not root). Sudo will be requested when needed.

set -euo pipefail

if [[ $EUID -eq 0 ]]; then
    echo "Run this script as a regular user, not root." >&2
    exit 1
fi

if ! command -v pacman &>/dev/null; then
    echo "pacman not found - this script targets Arch Linux." >&2
    exit 1
fi

echo ":: Syncing package databases"
sudo pacman -Sy --noconfirm

# --- Official repo packages ---------------------------------------------------
PACMAN_PKGS=(
    # Hyprland core + ecosystem
    hyprland
    hyprpaper
    hypridle
    hyprlock
    hyprshot
    xdg-desktop-portal-hyprland
    qt5-wayland
    qt6-wayland

    # Bar / notifications / launcher / file manager
    waybar
    swaync
    wofi
    thunar

    # Audio / brightness / media keys
    pipewire
    pipewire-pulse
    pipewire-alsa
    wireplumber
    pavucontrol
    brightnessctl
    playerctl

    # Apps referenced by keybinds
    firefox

    # Misc utilities used by config / scripts
    polkit-gnome
    xdg-user-dirs
    git
    base-devel
)

echo ":: Installing official packages"
sudo pacman -S --needed --noconfirm "${PACMAN_PKGS[@]}"

# --- AUR helper ---------------------------------------------------------------
if ! command -v paru &>/dev/null && ! command -v yay &>/dev/null; then
    echo ":: No AUR helper found - bootstrapping paru"
    tmpdir=$(mktemp -d)
    git clone https://aur.archlinux.org/paru-bin.git "$tmpdir/paru-bin"
    (cd "$tmpdir/paru-bin" && makepkg -si --noconfirm)
    rm -rf "$tmpdir"
fi

if command -v paru &>/dev/null; then
    AUR_HELPER=paru
else
    AUR_HELPER=yay
fi

# --- AUR packages -------------------------------------------------------------
AUR_PKGS=(
    pyprland          # pypr (scratchpads / dropdowns referenced in binds)
    spotify           # bound to SUPER+X
    claude-desktop    # used by claude-first-launch.sh + window rules
)

echo ":: Installing AUR packages with $AUR_HELPER"
"$AUR_HELPER" -S --needed --noconfirm "${AUR_PKGS[@]}"

# --- Hyprland plugin: dynamic-cursors -----------------------------------------
# hyprland.conf does: hyprctl plugin load .../dynamic-cursors.so
echo ":: Setting up hyprpm and dynamic-cursors plugin"
hyprpm update || true
if ! hyprpm list 2>/dev/null | grep -q dynamic-cursors; then
    hyprpm add https://github.com/VirtCode/hypr-dynamic-cursors
fi
hyprpm enable dynamic-cursors || true
hyprpm reload || true

# --- Wallpaper / screenshot dirs ---------------------------------------------
mkdir -p "$HOME/Pictures" "$HOME/Screenshots"
if [[ ! -f "$HOME/Pictures/arch-linux_upscaled.png" ]]; then
    echo ":: NOTE: $HOME/Pictures/arch-linux_upscaled.png is missing - hyprpaper will fail until you add it."
fi

# --- Services -----------------------------------------------------------------
systemctl --user enable --now pipewire pipewire-pulse wireplumber || true

cat <<'EOF'

Done (generic install).

If this machine has an NVIDIA GPU, also run:
    ./install-nvidia.sh

Next steps:
  * Drop your wallpaper at ~/Pictures/arch-linux_upscaled.png (or edit hyprpaper.conf).
  * Make sure ~/.config/theme/colors-hyprland.conf exists (sourced by hyprland.conf).
  * Log in via a Wayland session and start Hyprland.
EOF
```

#### `~/.config/hypr/install-nvidia.sh`

```bash file=~/.config/hypr/install-nvidia.sh mode=755 os=linux
#!/usr/bin/env bash
# NVIDIA install on top of the generic Hyprland setup.
# Runs install.sh first, then layers on NVIDIA-specific packages and tweaks
# matching the env vars in hyprland.conf.
# Run as your normal user (not root). Sudo will be requested when needed.

set -euo pipefail

if [[ $EUID -eq 0 ]]; then
    echo "Run this script as a regular user, not root." >&2
    exit 1
fi

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"

# --- Run the generic installer first ------------------------------------------
if [[ -x "$SCRIPT_DIR/install.sh" ]]; then
    echo ":: Running generic install.sh"
    "$SCRIPT_DIR/install.sh"
else
    echo "install.sh not found next to this script - aborting." >&2
    exit 1
fi

# --- NVIDIA packages ----------------------------------------------------------
NVIDIA_PKGS=(
    nvidia-dkms
    nvidia-utils
    libva-nvidia-driver
    egl-wayland
    linux-headers
)

echo ":: Installing NVIDIA packages"
sudo pacman -S --needed --noconfirm "${NVIDIA_PKGS[@]}"

# --- Early KMS in mkinitcpio --------------------------------------------------
# Needed for proper Wayland + NVIDIA behaviour.
MKINIT=/etc/mkinitcpio.conf
if [[ -f "$MKINIT" ]] && ! grep -Eq '^MODULES=.*nvidia' "$MKINIT"; then
    echo ":: Adding nvidia modules to $MKINIT"
    sudo sed -i -E 's/^(MODULES=\()([^)]*)\)/\1\2 nvidia nvidia_modeset nvidia_uvm nvidia_drm)/' "$MKINIT"
    sudo sed -i -E 's/  +/ /g; s/\( /(/' "$MKINIT"
    sudo mkinitcpio -P
fi

# --- nvidia-drm modeset kernel param -----------------------------------------
# Sets nvidia_drm.modeset=1 via a modprobe.d drop-in (works regardless of bootloader).
MODPROBE_FILE=/etc/modprobe.d/nvidia.conf
if [[ ! -f "$MODPROBE_FILE" ]] || ! grep -q 'nvidia_drm modeset=1' "$MODPROBE_FILE"; then
    echo ":: Writing $MODPROBE_FILE"
    echo 'options nvidia_drm modeset=1 fbdev=1' | sudo tee "$MODPROBE_FILE" >/dev/null
fi

cat <<'EOF'

Done (NVIDIA install).

Reboot before launching Hyprland so the DKMS module is in the running kernel
and nvidia_drm.modeset=1 takes effect.
EOF
```

## The dotfiles tool

Python 3 stdlib only. `extract` writes this block to `~/.local/bin/dotfiles` like any other file.

#### `~/.local/bin/dotfiles`

````python file=~/.local/bin/dotfiles mode=755
#!/usr/bin/env python3
"""dotfiles: one markdown file holds every config.

Fenced blocks in dotfiles.md are read by kind:
  ```lang file=~/path [mode=NNN] [eol=none] [os=darwin|linux]   one file (mode omitted = 644)
  ```text links      lines of `<link> -> <target>`; symlinks to create
  ```text roots      lines of `<dir> [!exclude-glob ...]`; refresh adds new files found here

Commands:
  extract   write files + symlinks for this OS (refuses to clobber; --force moves old aside)
  status    show what differs between the md and the live machine (exit 1 if anything does)
  refresh   pull live file contents back into the md; add new files under roots
"""
import argparse
import fnmatch
import os
import re
import sys
import tempfile

DEFAULT_MD = os.path.expanduser('~/projects/dot-config/dotfiles.md')
FENCE = re.compile(r'^(`{3,})(\S*)(.*)$')
JUNK = ('.DS_Store', '__pycache__', '*.pyc', 'node_modules')
BACKUP_SUFFIX = '.pre-dotfiles'
PLATFORM = 'darwin' if sys.platform == 'darwin' else 'linux'


class Block:
    def __init__(self, start, end, lang, words, attrs, body_lines):
        self.start, self.end = start, end  # line index of opening / closing fence
        self.lang, self.words, self.attrs = lang, words, attrs
        self.body_lines = body_lines

    @property
    def kind(self):
        if 'file' in self.attrs:
            return 'file'
        if 'links' in self.words:
            return 'links'
        if 'roots' in self.words:
            return 'roots'
        return None

    @property
    def path(self):
        return self.attrs['file']

    def content(self):
        if not self.body_lines:
            return ''
        text = '\n'.join(self.body_lines)
        return text if self.attrs.get('eol') == 'none' else text + '\n'

    def for_this_os(self):
        return self.attrs.get('os', PLATFORM) == PLATFORM


def parse(text):
    lines = text.split('\n')
    blocks, i = [], 0
    while i < len(lines):
        m = FENCE.match(lines[i])
        if not m:
            i += 1
            continue
        fence, lang, rest = m.groups()
        j = i + 1
        while j < len(lines) and lines[j] != fence:
            j += 1
        if j == len(lines):
            sys.exit(f'dotfiles: line {i + 1}: unclosed fence {fence}')
        words = [w for w in rest.split() if '=' not in w]
        attrs = dict(w.split('=', 1) for w in rest.split() if '=' in w)
        blocks.append(Block(i, j, lang, words, attrs, lines[i + 1:j]))
        i = j + 1
    return lines, blocks


def render(path, content, lang, mode=None, os_name=None):
    """Fenced block for one file. Fence is longer than any backtick run inside."""
    if ' ' in path:
        raise ValueError(f'path with spaces not supported: {path}')
    longest = max((len(r) for r in re.findall(r'`+', content)), default=0)
    fence = '`' * max(3, longest + 1)
    info = [f'{fence}{lang}', f'file={path}']
    if mode:
        info.append(f'mode={mode}')
    if os_name:
        info.append(f'os={os_name}')
    if content == '':
        body = []
    elif content.endswith('\n'):
        body = content[:-1].split('\n')
    else:
        body = content.split('\n')
        info.append('eol=none')
    return [' '.join(info), *body, fence]


def read_text(path):
    with open(path, 'rb') as f:
        raw = f.read()
    if b'\0' in raw:
        raise SystemExit(f'dotfiles: {path}: binary file, cannot embed')
    try:
        return raw.decode('utf-8')
    except UnicodeDecodeError:
        raise SystemExit(f'dotfiles: {path}: not UTF-8, cannot embed')


def file_mode(path):
    mode = format(os.stat(path).st_mode & 0o777, 'o')
    return None if mode == '644' else mode


def lang_for(path):
    name = os.path.basename(path)
    ext = os.path.splitext(name)[1].lstrip('.')
    by_ext = {'md': 'markdown', 'sh': 'bash', 'py': 'python', 'ts': 'ts', 'js': 'js', 'json': 'json',
              'lua': 'lua', 'toml': 'toml', 'yml': 'yaml', 'yaml': 'yaml', 'conf': 'ini', 'rhai': 'rust'}
    by_name = {'.zshrc': 'zsh', '.gitconfig': 'ini', 'dotfiles': 'python'}
    return by_name.get(name) or by_ext.get(ext, 'text')


def link_lines(block):
    out = []
    for raw in block.body_lines:
        line = raw.strip()
        if not line or line.startswith('#'):
            continue
        link, sep, target = line.partition(' -> ')
        if not sep:
            sys.exit(f'dotfiles: bad links line (want "<link> -> <target>"): {raw}')
        out.append((link.strip(), target.strip()))
    return out


def root_lines(block):
    out = []
    for raw in block.body_lines:
        parts = raw.split()
        if parts and not parts[0].startswith('#'):
            out.append((parts[0], [p[1:] for p in parts[1:] if p.startswith('!')]))
    return out


def expand(path):
    return os.path.expanduser(path)


def link_target(target):
    return expand(target) if target.startswith('~') else target


def selected(path, only):
    return not only or any(expand(path).startswith(expand(p)) for p in only)


def file_state(block):
    dest = expand(block.path)
    if os.path.islink(dest) or not os.path.isfile(dest):
        return 'missing' if not os.path.lexists(dest) else 'conflict'
    if read_text(dest) != block.content():
        return 'modified'
    if file_mode(dest) != block.attrs.get('mode'):
        return 'mode'
    return 'ok'


def link_state(link, target):
    dest = expand(link)
    if os.path.islink(dest):
        return 'ok' if os.readlink(dest) == link_target(target) else 'conflict'
    return 'conflict' if os.path.lexists(dest) else 'missing'


def move_aside(dest):
    backup = dest + BACKUP_SUFFIX
    if os.path.lexists(backup):
        sys.exit(f'dotfiles: backup already exists, remove it first: {backup}')
    os.rename(dest, backup)
    return backup


def cmd_extract(args):
    _, blocks = parse(read_text(args.md))
    files = [b for b in blocks if b.kind == 'file' and (args.all_os or b.for_this_os()) and selected(b.path, args.only)]
    links = [(l, t) for b in blocks if b.kind == 'links' and (args.all_os or b.for_this_os())
             for l, t in link_lines(b) if selected(l, args.only)]

    todo_files = [(b, file_state(b)) for b in files]
    todo_links = [(l, t, link_state(l, t)) for l, t in links]
    clobber = [b.path for b, s in todo_files if s in ('modified', 'conflict')] + \
              [l for l, _, s in todo_links if s == 'conflict']
    if clobber and not args.force and not args.dry_run:
        print('dotfiles: these exist and differ (re-run with --force to move them aside as *' + BACKUP_SUFFIX + '):')
        for p in clobber:
            print('  ' + p)
        sys.exit(1)

    for b, state in todo_files:
        dest = expand(b.path)
        if state == 'ok':
            continue
        if args.dry_run:
            print(f'{state:9} {b.path}')
            continue
        if state in ('modified', 'conflict'):
            print(f'backup    {move_aside(dest)}')
        os.makedirs(os.path.dirname(dest), exist_ok=True)
        with open(dest, 'w', encoding='utf-8', newline='') as f:
            f.write(b.content())
        os.chmod(dest, int(b.attrs.get('mode', '644'), 8))
        print(f'wrote     {b.path}')

    for link, target, state in todo_links:
        dest = expand(link)
        if state == 'ok':
            continue
        if args.dry_run:
            print(f'{state:9} {link} -> {target}')
            continue
        if state == 'conflict':
            print(f'backup    {move_aside(dest)}')
        os.makedirs(os.path.dirname(dest), exist_ok=True)
        os.symlink(link_target(target), dest)
        print(f'linked    {link} -> {target}')


def new_files(blocks):
    known = {expand(b.path) for b in blocks if b.kind == 'file'}
    found = []
    for b in blocks:
        if b.kind != 'roots' or not b.for_this_os():
            continue
        for root, excludes in root_lines(b):
            base = expand(root)
            if not os.path.isdir(base):
                sys.exit(f'dotfiles: root missing: {root}')
            for dirpath, dirnames, filenames in os.walk(base):
                rel_dir = os.path.relpath(dirpath, base)

                def skip(name):
                    rel = os.path.normpath(os.path.join(rel_dir, name))
                    return any(fnmatch.fnmatch(name, j) for j in JUNK) or \
                        any(fnmatch.fnmatch(rel, e) or fnmatch.fnmatch(name, e) for e in excludes) or \
                        os.path.islink(os.path.join(dirpath, name))

                dirnames[:] = sorted(d for d in dirnames if not skip(d))
                for name in sorted(filenames):
                    full = os.path.join(dirpath, name)
                    if not skip(name) and full not in known:
                        found.append(root.rstrip('/') + '/' + os.path.relpath(full, base))
    return found


def cmd_status(args):
    _, blocks = parse(read_text(args.md))
    dirty = False
    for b in blocks:
        if b.kind == 'file' and b.for_this_os():
            state = file_state(b)
            if state != 'ok':
                dirty = True
                print(f'{state:9} {b.path}')
        elif b.kind == 'links' and b.for_this_os():
            for link, target in link_lines(b):
                state = link_state(link, target)
                if state != 'ok':
                    dirty = True
                    print(f'{state:9} {link} -> {target}')
    for path in new_files(blocks):
        dirty = True
        print(f'new       {path}')
    if not dirty:
        print('clean')
    sys.exit(1 if dirty else 0)


def common_depth(a, b):
    n = 0
    for x, y in zip(a.split('/'), b.split('/')):
        if x != y:
            break
        n += 1
    return n


def cmd_refresh(args):
    lines, blocks = parse(read_text(args.md))
    file_blocks = [b for b in blocks if b.kind == 'file' and b.for_this_os()]
    missing = [b for b in file_blocks if not os.path.isfile(expand(b.path))]
    if missing and not args.prune:
        print('dotfiles: live file missing (restore it, or re-run with --prune to drop its block):')
        for b in missing:
            print('  ' + b.path)
        sys.exit(1)

    # replacements: (start, end_inclusive) -> new lines; applied bottom-up
    edits, updated, removed = [], 0, 0
    for b in file_blocks:
        if b in missing:
            start = b.start - 2 if b.start >= 2 and lines[b.start - 2] == f'#### `{b.path}`' else b.start
            edits.append((start, b.end + 1 if b.end + 1 < len(lines) and lines[b.end + 1] == '' else b.end, []))
            removed += 1
            continue
        dest = expand(b.path)
        new = render(b.path, read_text(dest), b.lang, file_mode(dest), b.attrs.get('os'))
        if new != lines[b.start:b.end + 1]:
            edits.append((b.start, b.end, new))
            updated += 1

    added = new_files(blocks)
    for path in reversed(added):  # same-anchor inserts stack, so insert last-first to keep order
        anchor = max(file_blocks, key=lambda b: (common_depth(b.path, path), b.end))
        dest = expand(path)
        block = render(path, read_text(dest), lang_for(path), file_mode(dest), anchor.attrs.get('os'))
        edits.append((anchor.end + 1, anchor.end, ['', f'#### `{path}`', '', *block]))

    for start, end, new in sorted(edits, key=lambda e: (e[0], e[1]), reverse=True):
        lines[start:end + 1] = new

    fd, tmp = tempfile.mkstemp(dir=os.path.dirname(os.path.abspath(args.md)))
    with os.fdopen(fd, 'w', encoding='utf-8', newline='') as f:
        f.write('\n'.join(lines))
    os.replace(tmp, args.md)
    print(f'updated {updated}, added {len(added)}, removed {removed}')
    for path in added:
        print(f'  added {path}')


def main():
    p = argparse.ArgumentParser(prog='dotfiles', description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = p.add_subparsers(dest='cmd', required=True)
    e = sub.add_parser('extract', help='write files and symlinks from the md')
    e.add_argument('--only', action='append', default=[], metavar='PATH_PREFIX', help='limit to paths under this prefix (repeatable)')
    e.add_argument('--force', action='store_true', help='move differing files/links aside as *' + BACKUP_SUFFIX)
    e.add_argument('--dry-run', action='store_true')
    e.add_argument('--all-os', action='store_true', help='include blocks marked for another OS')
    s = sub.add_parser('status', help='diff the md against the live machine')
    r = sub.add_parser('refresh', help='pull live files back into the md')
    r.add_argument('--prune', action='store_true', help='drop blocks whose live file is gone')
    for sp in (e, s, r):
        sp.add_argument('md', nargs='?', default=DEFAULT_MD)
    args = p.parse_args()
    {'extract': cmd_extract, 'status': cmd_status, 'refresh': cmd_refresh}[args.cmd](args)


if __name__ == '__main__':
    main()
````
