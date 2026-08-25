---
description: Code-only git worktree for a PR, branch, or new task (no env/DB/ports/yarn/seed). Use when the user runs /worktree-quick or wants a disposable checkout to start a task or review a PR/branch without a second stack.
---

# /worktree-quick

Code-only worktree: `git fetch` + `git worktree add`. **No** env copy, **no** Postgres/Redis, **no** port remaps, **no** `yarn install`, **no** seed, **no** serve.

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

Cannot check out the same branch in two worktrees — local branch is always `quick/<slug>`.

## What the script does (destroy)

1. Resolve target by PR number, slug, `--name`, `--path`, or `--all`.
2. Refuse primary checkout, refuse `.worktree-slot` (full-stack) worktrees, refuse anything that is not `*-quick-*` / quick marker.
3. `git worktree remove`. Delete local `quick/*` branch unless `--keep-branch`.
4. No ports, no Redis, no `DROP DATABASE`.

## Agent checklist

1. Parse `$ARGUMENTS`: `list` / `destroy|remove|teardown` / PR / branch / **task description**. If missing, **ask**.
2. `cd` to the repo the user is talking about (do not guess a different project).
3. For a task, run `…/quick-worktree.sh new "<description>"`. Do not hand-roll `git worktree add` unless the script is missing.
4. Do **not** copy `.env`, create `dbname_wtN`, rewrite ports, `yarn install`, seed, or start serve.
5. After create: report **path**, **branch**, **sha**, PR URL if any, and the destroy command.
6. After destroy: confirm the path is gone via `list`.
7. If they then ask to run the app: stop and point them at `/monorepo-worktree`.

User arguments: $ARGUMENTS
