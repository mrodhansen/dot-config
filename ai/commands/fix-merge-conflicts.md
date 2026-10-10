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
