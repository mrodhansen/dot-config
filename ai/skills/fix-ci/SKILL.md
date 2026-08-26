---
name: fix-ci
description: Fetches the most recent GitHub Actions CI run for the current branch's PR, parses all failed jobs/steps for error messages, then diagnoses and fixes each failure in the codebase. Use when user says "/fix-ci", "fix ci", "fix the build", "fix pipeline", "fix github actions", or "ci is failing".
---

# /fix-ci - GitHub Actions CI Failure Fixer

Fetches the most recent GitHub Actions CI run for the current branch's PR, finds all failures and errors, diagnoses root causes, and fixes them in the codebase.

**Usage:** `/fix-ci`

---

## Core Philosophy

- **Find every failure.** Don't stop at the first error — CI runs have multiple jobs and steps, and each can fail independently.
- **Understand before fixing.** Read the full error context, not just the error line. Many CI errors are symptoms of a root cause elsewhere.
- **Fix the code, not the CI.** The goal is to fix the source code so CI passes, not to hack around CI configuration (unless the CI config itself is the bug).
- **Verify locally when possible.** After fixing, run the same commands locally to confirm the fix before pushing.

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
1. Identify PR & Branch      -> Find the PR for the current branch
2. Fetch Latest CI Run       -> Get the most recent workflow run
3. Find All Failed Jobs      -> Identify every job that didn't pass
4. Extract Error Messages    -> Parse logs for all error patterns
5. Diagnose Root Causes      -> Group errors by root cause
6. Fix Each Issue            -> Implement fixes using specialized agents
7. Verify Locally            -> Run failing commands locally
8. Report Summary            -> Show what was fixed
```

---

## Phase 1: Identify PR & Branch

```bash
# Get current branch
git branch --show-current

# Get repo owner/name
gh repo view --json owner,name --jq '.owner.login + "/" + .name'

# Find the PR for this branch
gh pr view --json number,url,title,headRefName 2>/dev/null
```

- If no PR exists, check for CI runs on the branch directly (push-triggered workflows).
- If neither exists, **stop and inform the user**.

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

## Phase 7: Verify Locally

After all fixes are applied, run the same commands that CI runs locally:

### 7.1 Detect CI Commands

Read the workflow file(s) to understand what CI runs:

```bash
# Find workflow files
ls .github/workflows/

# Read the workflow that failed
cat .github/workflows/<workflow-file>.yml
```

### 7.2 Run Verification Commands

Run the same commands locally in order:

```bash
# Typical verification sequence (adapt to what CI actually runs):

# 1. Install dependencies (if needed)
npm ci  # or yarn install --frozen-lockfile, pnpm install --frozen-lockfile

# 2. Type check
npx tsc --noEmit  # or the project's typecheck command

# 3. Lint
npm run lint  # or the project's lint command

# 4. Test
npm test  # or the project's test command

# 5. Build
npm run build  # or the project's build command
```

### 7.3 If Local Verification Fails

If running locally still shows errors:
1. Read the new errors
2. Fix them (repeat Phase 5-6 for new errors)
3. Re-run verification
4. Loop until all commands pass

**Maximum 3 fix-verify loops.** If still failing after 3 attempts, report remaining errors to the user.

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

| Command | Result |
|---------|--------|
| `npx tsc --noEmit` | PASS |
| `npm run lint` | PASS |
| `npm test` | PASS |
| `npm run build` | PASS |

### Next Steps
- Run `/pr` to commit and push the fixes
- CI should pass on the next run
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
| Fix causes new errors | Re-run verification loop (max 3 iterations) |
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
7. **Verify before declaring victory.** Always run local verification. An untested fix is not a fix.
8. **Be honest about environment-specific failures.** Some CI failures can't be reproduced locally (Docker, specific OS, secret-dependent tests). Report these clearly.
9. **Use the right agent for each fix type.** Backend errors -> backend-architect, frontend -> frontend-developer, tests -> test-writer-fixer, infra -> devops-automator.
