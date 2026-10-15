# dot-config

Personal configs.

Clone lives at `~/projects/dot-config`. Live paths are symlinks into this repo.

| Folder | Live path |
|--------|-----------|
| `ai/` | `~/.ai` |
| `wezterm/` | `~/.wezterm.lua` |
| `opencode/` | files under `~/.config/opencode/` |
| `hypr/` | `~/.config/hypr` (Arch) |
| `zsh/` | `~/.zshrc` |
| `claude/` | `~/.claude/settings.json` (copy) |
| `grok/` | `~/.grok/config.toml` (copy) |
| `git/` | `~/.gitconfig`, `~/.config/git/ignore` (copy) |
| `lazygit/` `yazi/` `btop/` `bottom/` `gitlogue/` `ncspot/` | `~/.config/<tool>/` (copy) |

## `ai/`

Shared agents, skills, commands, workflows. Platform dirs symlink into `~/.ai`:

- `~/.config/opencode/{agents,command,skills,AGENTS.md}` → `~/.ai`
- `~/.claude/{skills,agents,CLAUDE.md}` → `~/.ai` (`CLAUDE.md` → `AGENTS.md`); `~/.claude/commands/*.md` → command-only `~/.ai/commands/*.md`
- `~/.grok/{skills,agents,workflows}` → `~/.ai`
- `~/.agents/skills` → `~/.ai/skills`

See `ai/README.md`.

## `wezterm/`

`wezterm.lua` — WezTerm reads `~/.wezterm.lua`.

## `opencode/`

Tracked: `opencode.json`, `cli.json`, `themes/`, `plugins/`.

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
ln -s ~/projects/dot-config/opencode/themes ~/.config/opencode/themes
ln -s ~/projects/dot-config/hypr ~/.config/hypr
ln -s ~/projects/dot-config/zsh/.zshrc ~/.zshrc
```
