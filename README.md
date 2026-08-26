# dot-config

Personal configs. Private.

Clone lives at `~/projects/dot-config`. Live paths are symlinks into this repo.

| Folder | Live path |
|--------|-----------|
| `ai/` | `~/.ai` |
| `wezterm/` | `~/.wezterm.lua` |
| `opencode/` | files under `~/.config/opencode/` |
| `hypr/` | `~/.config/hypr` (Arch) |
| `zsh/` | `~/.zshrc` |

## `ai/`

Shared agents, skills, commands, workflows. Platform dirs symlink into `~/.ai`:

- `~/.config/opencode/{agents,command,skills,AGENTS.md}` → `~/.ai`
- `~/.claude/{skills,agents}` → `~/.ai`
- `~/.grok/{skills,agents,workflows}` → `~/.ai`
- `~/.agents/skills` → `~/.ai/skills`

See `ai/README.md`.

## `wezterm/`

`wezterm.lua` — WezTerm reads `~/.wezterm.lua`.

## `opencode/`

Tracked: `opencode.json`, `cli.json`, `tui.json`, `themes/`, `plugins/`, `package.json`.

Not tracked (runtime / secrets): `service.json`, `node_modules/`, sessions, auth.

## `hypr/`

Hyprland + hyprpaper configs and Arch install scripts. See `hypr/README.md`.

## `zsh/`

`.zshrc` — aliases, keybinds, PATH, yazi helper.

## Local wiring

```bash
ln -s ~/projects/dot-config/ai ~/.ai
ln -s ~/projects/dot-config/wezterm/wezterm.lua ~/.wezterm.lua
ln -s ~/projects/dot-config/opencode/opencode.json ~/.config/opencode/opencode.json
ln -s ~/projects/dot-config/opencode/cli.json ~/.config/opencode/cli.json
ln -s ~/projects/dot-config/opencode/tui.json ~/.config/opencode/tui.json
ln -s ~/projects/dot-config/opencode/package.json ~/.config/opencode/package.json
ln -s ~/projects/dot-config/opencode/themes ~/.config/opencode/themes
ln -s ~/projects/dot-config/hypr ~/.config/hypr
ln -s ~/projects/dot-config/zsh/.zshrc ~/.zshrc
```
