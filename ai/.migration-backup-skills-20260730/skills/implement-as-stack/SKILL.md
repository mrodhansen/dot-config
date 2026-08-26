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
