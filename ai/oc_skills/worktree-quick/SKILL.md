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
