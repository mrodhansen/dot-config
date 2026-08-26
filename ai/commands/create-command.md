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
