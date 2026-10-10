---
description: Fast single-agent PR review (same as /pr-review, no subagents). Always creates a code-only git worktree first (same as /worktree-quick) so /pr-review-light 1234 does not need a prior /worktree-quick. After the report, stop with the numbered findings list. In later turns, answer questions or post inline GitHub comments when the user asks to add/post a number list.
---

# /pr-review-light — Fast single-agent PR review

Same review as `/pr-review`, **without subagents**. You (the main agent) gather the diff, review it in one pass, and report. After the report, **stop**. Later, answer questions or post inline GitHub comments when the user asks to add/post finding numbers.

**Usage:** `/pr-review-light [PR number | PR URL | branch] [optional-prd-file-path]`

`/pr-review-light 1234` is enough — this skill creates the code-only worktree itself. Do **not** require a prior `/worktree-quick`.

User arguments: $ARGUMENTS

## Hard rules

1. **NEVER spawn subagents** (`Task`, `spawn_subagent`, specialist agents, fan-out). No exceptions — not for "large diffs", not for "parallel specialists". Speed comes from one pass.
2. **NEVER fabricate findings.** Clean code → say it's clean.
3. **Stop after the report.** Do not walk findings. Do not use the Question tool. Never auto-post. Post only in a later turn when the user asks to add/post a number list or a single finding.
4. **GitHub comments are inline only** (`path` + `line`). Never `gh pr comment` / issue comments as a substitute.
5. Prescribe **hard types + hard fails**, never `any` / `?? ''` papering.
6. **Always isolate in a code-only worktree first** (Phase 0 / `/worktree-quick` script). Never review the primary checkout. Never require a prior `/worktree-quick`.

## Speed model

```
0. Code-only worktree         -> /worktree-quick script + session_move (always; then review)
1. Context (parallel git)     -> branch, base, diff, stat, log, file list (in the worktree)
2. One-pass review            -> YOU read the diff; Grep/Read only to confirm a suspected issue
3. Report                     -> unified tables (no specialist-status theater)
4. STOP after report          -> numbered list is the end of this turn
5. Follow-up (later turns)    -> same as /pr-review Phase 5 (questions, or add/post numbers)
```

- Do **not** pre-build file-category tables, specialist payloads, or "No X issues found" per concern.
- Do **not** read the whole surrounding codebase "to be thorough". Open extra files only when the diff suggests a real issue (authz sibling, consumer of a new field, unique index, etc.).
- Prefer **high-signal** findings. Skip style nits, naming bikesheds, "could useMemo", and obvious-comment noise.
- If the diff is huge, review it in chunks **yourself** (highest-risk files first: auth, API, DB, config). Still no subagents.

---

## Phase 0: Code-only worktree (always, before any review)

Review **never** runs in the primary checkout. Isolate first with the same script as `/worktree-quick`, then review inside that worktree. **Do not** wait for the user to run `/worktree-quick`. **Do not** use `/monorepo-worktree` (no DB, ports, seed, or serve). **Do not** stop after create — continue immediately into Phase 1 in this same session. session_move is **not** a subagent.

User arguments: `$ARGUMENTS`

### Parse target

Split `$ARGUMENTS` into **TARGET** + optional **PRD path**:

| Token | Meaning |
|-------|---------|
| `1234` / `#1234` / `pr 1234` / GitHub `.../pull/1234` | PR |
| `feature/foo` / `origin/foo` / other git ref | Branch |
| Path ending in `.md` or an existing file | PRD (not a worktree target) |
| Empty | `gh pr view --json number -q .number`. If that fails and cwd is already a `*-quick-*` worktree, TARGET = current worktree (skip create). Else ask for a PR number — do not invent a task worktree. |

Resolve a relative PRD path to an **absolute** path against the **pre-move** cwd before leaving the primary checkout.

Remember `PR_NUMBER` when TARGET is a PR. Later `gh pr view` / review POSTs must use `gh pr view ${PR_NUMBER}` — the local branch will be `quick/pr-N`, which GitHub does not treat as the PR head.

### Skip create only when already isolated

Skip create if cwd is already a `*-quick-*` worktree (basename `*-quick-*` or gitdir marker `worktree-quick`) **and** it matches TARGET (same PR number / same slug). Still fetch+reset (below) so the review is current.

### Create or reuse

Script: `~/.ai/oc_skills/worktree-quick/scripts/quick-worktree.sh`

Must run from the git repo under review (or set `REPO_ROOT`). Do **not** hand-roll `git worktree add`.

```bash
~/.ai/oc_skills/worktree-quick/scripts/quick-worktree.sh 1234
~/.ai/oc_skills/worktree-quick/scripts/quick-worktree.sh pr 1234
~/.ai/oc_skills/worktree-quick/scripts/quick-worktree.sh https://github.com/org/repo/pull/1234
~/.ai/oc_skills/worktree-quick/scripts/quick-worktree.sh feature/foo
```

Parse `path:` from the success banner.

If the script fails with `worktree path already exists: <path>`: **reuse `<path>`**. Do not destroy. Fetch the PR/branch and `git -C <path> reset --hard` to that SHA so the review is current:

```bash
# PR
git fetch origin pull/${PR_NUMBER}/head
git -C "<path>" reset --hard FETCH_HEAD

# Branch
git fetch origin <branch>
git -C "<path>" reset --hard origin/<branch>
```

### Yarn (mandatory, every worktree)

After the path is known — **fresh create, reuse, or already-isolated** — run and wait for exit 0:

```bash
(cd "<path>" && yarn install)
```

Timeout 10 minutes. Never skip because `node_modules` exists. Never skip on reuse. Never skip because the task "doesn't need node_modules". If the create script already ran yarn in this turn and you **watched it exit 0**, that create counts; reuse / already-isolated **must still yarn**.

### Move the session, then review

1. OpenCode: `tools.opencode.session_move` with `directory` = the absolute worktree path. Continue **this** session. Do not spawn a subagent to perform the review.
2. If session_move is unavailable: `cd` / set `working_directory` on every later command to that path.
3. Every later git / Read / Grep must run in that worktree, not the primary checkout.
4. One-line note: path, `quick/…` branch, PR URL, destroy command (`~/.ai/oc_skills/worktree-quick/scripts/quick-worktree.sh destroy <slug> --yes`). Then **immediately** start Phase 1.

Do **not** destroy the worktree after the report (follow-up posting still needs the checkout).

---

## Phase 1: Context (run in parallel)

```bash
git branch --show-current
git remote show origin | grep 'HEAD branch' | awk '{print $NF}'
git diff $(git merge-base HEAD origin/main)..HEAD
git diff --stat $(git merge-base HEAD origin/main)..HEAD
git log --oneline $(git merge-base HEAD origin/main)..HEAD
git diff --name-only $(git merge-base HEAD origin/main)..HEAD
```

If HEAD branch is not `main`, swap `origin/main` for the detected base. Clean diff → stop. Cannot detect base → ask. If a PRD path was given, read it; if missing, warn and continue without PRD.

---

## Phase 2: One-pass review

Walk the **full diff** once. Flag only real issues. Every finding needs: Severity, Category, File, Line(s), Issue, Description, Fix.

### Severity

| Severity | When |
|----------|------|
| **CRITICAL** | Must fix before merge: injection, auth bypass, data loss, secret leak, fail-open auth, cross-tenant, soft-success on money/credit/AUS/messaging setup |
| **HIGH** | Should fix: N+1 hot path, check-then-act races, write-only fields, `?? ''` on required vendor payloads, thin tenant-only authZ, form mount wipes, dual-path divergence, envelope casts, no-op-green tests |
| **MEDIUM** | Fix soon: incomplete validation, swallowed non-critical errors, incomplete UX recovery, dead helpers, 3+ copy extract |
| **LOW** | Only if introduced by this PR and cheap: unused imports, tiny dead locals. Skip pure style. |

### Checklists (scan, don't write a report per box)

**Security** — injection (SQL/command/XSS/`dangerouslySetInnerHTML`); missing/thin authZ (tenant membership ≠ authorization; fail-open `catch { return true }`); secrets/PII in code or logs; env names in user errors; missing validation on new endpoints.

**Performance** — N+1 / queries in loops; missing indexes; unbounded lists; O(n²); sequential awaits that should be `Promise.all`; sync blocking I/O.

**Silent failure / soft types** — empty/log-only catch; `.catch(() => null\|[]\|{})`; required data defaulted with `??` / `||` / `?.`; `as any` / `as unknown as T` / `@ts-ignore`; fire-and-forget where the caller must know. Root-cause the **type** (exact Prisma/Zod/DTO), never suggest `any`.

**R1–R9 (always run, even on small PRs)**

| # | Pattern | Look for |
|---|---------|----------|
| R1 | Soft success | catch/log while status still ACTIVE/ready; tests skip-green when fixtures missing |
| R2 | Write-only / E2E | new field saved but not read by list/detail, export, import, job, twin pipeline — **grep consumers** |
| R3 | App-only races | uniqueness only in app code; check-then-act; `last+1` without unique+retry |
| R4 | Thin authZ | weaker gate than siblings; identity mixed with capability; over-broad roles |
| R5 | Form hydration wipe | mount `useEffect` writes form; partial PATCH maps omitted keys → null |
| R6 | Dual-path drift | CRM vs funnel / twin transformers disagree — **read the other path** |
| R7 | Envelope / type lies | guessed response shape; schema drift; double casts |
| R8 | UX stuck | async with no timeout/error/cancel; double-submit |
| R9 | Scope | reinvented nearby helper; arbitrary z-index/tokens |

Hits that look healthy while broken, lose data, or mis-route tenants/credit/messaging → CRITICAL/HIGH.

**Quality** — races, off-by-one, copy-paste bugs, missing await, magic strings that should be consts. Read hunk context, not only the `+` lines.

**Testing** — new paths with no test; no failure-path assert; tests that stay green if fixtures are absent. Name the test file and the assertion that would catch the bug.

**Dead code** — unused imports/symbols **this PR introduced**. Grep to confirm 0 refs. Stale "used to / previously" comments. Don't bikeshed old comments outside the change.

**Duplication** — flag only if **≥ 3** real copies and a named helper would reduce drift. Two copies is not a finding. Point at path + signature.

**PRD** (only if provided) — each requirement: IMPLEMENTED / PARTIAL / NOT IMPLEMENTED / DEVIATED. Evidence = file:line.

**Architecture** — gut check only. Default `fine` and **omit from the report**. Speak only for a clearly better existing-codebase path or a clearly poor fit. Never a merge blocker. Never a finding row.

---

## Phase 3: Report

```markdown
## Code Review Report

**Branch**: …
**Base**: …
**Files Changed**: N
**Commits**: N
**Review Date**: …
**Mode**: pr-review-light (single agent, no subagents)

### Verdict: BLOCK / APPROVE WITH FIXES / APPROVE

[1–2 sentences. Architecture does not change the verdict.]

### Critical & High Findings (Must Fix)

| # | Severity | Category | File | Line(s) | Issue | Fix |
|---|----------|----------|------|---------|-------|-----|

### Medium & Low Findings (Recommendations)

| # | Severity | Category | File | Line(s) | Issue | Fix |
|---|----------|----------|------|---------|-------|-----|

### PRD Compliance (if applicable)

| Requirement | Status | Notes |
|-------------|--------|-------|

### Recurring-pattern coverage

| Pattern | Status |
|---------|--------|
| R1 Soft success | clean / N findings |
| R2 Write-only / E2E wiring | clean / N findings |
| R3 Invariants & races | clean / N findings |
| R4 AuthZ / tenant / secrets | clean / N findings |
| R5 Form hydration wipes | clean / N findings |
| R6 Dual-path inconsistency | clean / N findings |
| R7 Envelopes / partial updates | clean / N findings |
| R8 UX recovery | clean / N findings |
| R9 Consistency / scope | clean / N findings |

### Architecture sense-check (user advisory)

<!-- ONLY if not fine. If fine: OMIT this section entirely. -->

### Next Steps
Ask about any finding, or reply with numbers to post as inline GitHub comments (e.g. `add 1-3, 5, 19` or `add 7`).
```

Number findings CRITICAL → LOW across both tables (continuous `#`). Merge duplicates (same line → one row, higher severity).

**Zero findings:** verdict APPROVE, skip Phase 4.

**After the report, stop.** Do not call the Question tool. Do not walk findings. Do not post to GitHub in this turn. Phase 4 runs only on later user messages.

---

## Phase 4: Follow-up chat — discuss or post selected findings

Same UX as `/pr-review` Phase 5. The report **is** the end of the review turn. Do **not** post in the same turn as the report. Do **not** use the Question tool.

### 4.1 Report-turn stop (required)

Print the numbered findings tables, tell the user they can ask questions or reply with numbers to post (e.g. `add 1-3, 5, 19` or `add 7`), then **stop**.

Architecture notes are **not** selectable.

### 4.2 Later turns — questions vs post

| User intent | What to do |
|-------------|------------|
| Questions / debate about a finding (or several) | Answer. Do **not** post. |
| Explicit add/post of a number list or a single number | Parse (4.3) and post those as **inline** comments (4.4–4.7). |
| `add all` / `post all` | Post every numbered finding. |
| Unclear (chat that is not a post request) | Answer; do **not** post. |

**Do not invent a default selection.** Never auto-post.

### 4.3 Parse the selection

Trigger words: `add`, `post`, `comment`, `inline` — plus a number list, a single number, or `all`. Parentheses are optional. A message that is **only** a number list (or a single number) is also a post request.

Examples that **must** post: `add 1-3, 5, 19, 24-26` · `add 7` · `7` · `post 1, 4, 9` · `1-3, 5, 19, 24-26` · `(1-3, 5, 19, 24-26)` · `add all`.

Parse rules: strip wrapping `()` / `[]`; split on commas/whitespace; `N-M` is inclusive range; `N` is finding N; `all` = every numbered finding; deduplicate; skip invalid numbers (tell the user). Custom comment text for a specific `#` becomes that finding's `body`; otherwise use Issue + Fix.

Empty set after validation → no GitHub. Later turns may post more numbers; do not re-post findings already posted in this conversation unless asked.

### 4.4 Resolve the PR (only after a later turn requests posting with ≥1 valid finding)

```bash
# Prefer the PR number from Phase 0 — local branch is quick/pr-N, not the GitHub head ref
gh pr view ${PR_NUMBER} --json number,url,title,headRefOid,headRefName
gh repo view --json nameWithOwner -q '.nameWithOwner'
```

No PR → stop; do not create one; do not post issue comments. `commit_id` = `headRefOid`.

### 4.5 Inline anchor

For each selected finding: repo-relative `path`; `line` = new-file line (`start_line` + `line` if a range); `side: RIGHT` for added/changed lines.

If the exact line is not in the PR diff, snap to the **nearest changed line in that file** and say so in the comment. If the file is not in the diff, **skip** (never fall back to a top-level comment). Deleted-only: `side: LEFT`. Prefer RIGHT if the line still exists.

### 4.6 One review POST (not one per finding)

Write JSON to a file; `POST` with `--input`. Do **not** `--field 'comments=[...]'`. Do **not** `gh pr comment`.

```bash
cat > /tmp/pr_review_light.json << 'ENDJSON'
{
  "commit_id": "<headRefOid>",
  "event": "COMMENT",
  "body": "Posted N selected finding(s) from /pr-review-light as inline comments.",
  "comments": [
    {
      "path": "src/auth.ts",
      "line": 45,
      "side": "RIGHT",
      "body": "**[CRITICAL] Security:** SQL injection via unsanitized input\n\n…\n\n**Fix:** Use a parameterized query."
    }
  ]
}
ENDJSON

NO_COLOR=1 gh api repos/{OWNER}/{REPO}/pulls/{pr}/reviews \
  -X POST \
  --input /tmp/pr_review_light.json
```

Comment body:

```markdown
**[SEVERITY] Category:** Issue title

<1–4 sentence description>

**Fix:** <concrete remediation>
```

`event` is always `COMMENT`. Cap 100 comments per review; split POSTs if needed.

### 4.7 After POST

Tell the user: PR URL, how many inline comments, which finding #s posted, which skipped and why. Do not re-print the full report.

---

## Errors

| Error | Action |
|-------|--------|
| Clean diff | Stop |
| Worktree script fails (not already-exists) | Stop; show full output; do **not** review the primary checkout |
| Worktree path already exists | Reuse that path; fetch+reset to latest PR/branch SHA |
| session_move unavailable | `cd` / `working_directory` on every command to the worktree path |
| No base branch | Ask |
| PRD missing | Warn; continue without PRD |
| Huge diff | Chunk **yourself**; still no subagents |
| No PR | On a post request, stop; don't create a PR |
| User only asks questions | Answer; do not post |
| Number list / add / post in a later turn | Parse and post those findings only |
| Invalid finding numbers | Skip them; tell the user which were invalid |
| Line not in diff | Snap to nearest changed line in file; else skip |
| POST 422 | Fix commit/line/side; retry once; then skip and report |

---

## Do not

- Spawn subagents, even if `/pr-review` would have. (`session_move` is not a subagent.)
- Collapse this skill into a sequential "run 10 specialist personas as extra turns" — that is the slow path. One pass.
- Demand a rewrite from architecture.
- Walk findings one at a time or use the Question tool after the report.
- Post unselected findings.
- Use `any` as a recommended fix.
- Review in the primary checkout, skip Phase 0, or require a prior `/worktree-quick`.
- Use `/monorepo-worktree` (no DB/ports/seed/serve).
- Skip yarn install on a fresh worktree create.
- Destroy the worktree after the report.

User arguments: $ARGUMENTS
