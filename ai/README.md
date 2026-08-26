# ~/.ai — shared agents, skills, commands, workflows

Folder in [dot-config](https://github.com/mrodhansen/dot-config). Live path is `~/.ai` (symlink).

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
- `~/.claude/{skills,agents}` → `~/.ai/{skills,agents}`
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
