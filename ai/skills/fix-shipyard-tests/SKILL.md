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
