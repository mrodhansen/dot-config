---
description: Fetches unresolved review comments and discussion threads from the current branch's PR, automatically fixes LOW (nits) and SEMANTIC items, presents CRITICAL/HIGH/MEDIUM items to the user with proposed fixes for approval, then replies on EVERY processed thread (including skipped) describing what changed or why it was skipped, and marks each resolved on GitHub. Use when user says "/fix-pr-review", "fix pr review", "address pr feedback", "handle review comments", or "/pr-review-fix".
---

# /fix-pr-review - PR Review Feedback Handler

Reads **unresolved** review comments and discussion threads from the current branch's PR, triages them by severity, auto-fixes low-risk nits and semantic suggestions, presents higher-impact items to the user with proposed fixes for approval, then **replies on every processed thread (including skipped) and marks it resolved on GitHub**. Each reply must say what changed or why the item was skipped. Already-resolved threads are excluded from processing.

**Usage:** `/fix-pr-review`

---

## Core Philosophy

- **Low (nits) & Semantic = Fix immediately.** Style preferences, naming, import ordering, comment wording, subjective/architectural opinions — these are low-risk and get applied without asking.
- **Critical, High & Medium = User decides.** Security issues, bugs, logic errors, missing error handling, code quality concerns, missing tests — these have real impact and deserve explicit review. Each is presented with a proposed fix the user can approve, tweak, or skip.
- **Never dismiss feedback silently.** Every unresolved comment is acknowledged, categorized, replied to on GitHub, and resolved — including items we skipped.
- **Close the loop on GitHub.** Code changes alone are not enough. Every processed thread gets a reply (what we did, or why we skipped it) and is then marked resolved so the PR conversation is clean.

---

## Execution Flow

```
1. Identify PR              -> Find the PR for the current branch
2. Fetch Unresolved Feedback -> Reviews, inline comments, conversation threads (skip resolved)
3. Triage & Classify        -> Assign severity to each unresolved piece of feedback
4. Auto-Fix Low/Semantic    -> Implement nits and semantic suggestions directly
5. Present Crit/High/Med    -> Show user each item with a proposed fix for approval
6. Comment & Resolve        -> Reply on EVERY processed thread (fixed AND skipped), then resolve each
7. Report Summary           -> Final status of all feedback items (already-resolved listed separately)
```

---

## Phase 1: Identify the PR

```bash
gh pr view --json number,url,title,state,headRefName 2>/dev/null
```

Resolve repo names dynamically (case-sensitive):

```bash
gh repo view --json nameWithOwner -q '.nameWithOwner'
```

Split into `OWNER` and `REPO` for API calls. Set `NO_COLOR=1` on all `gh api` invocations to avoid ANSI noise in JSON.

- If no PR exists for the current branch, **stop and inform the user**.
- Confirm the PR number and title before proceeding.

---

## Phase 2: Fetch All Feedback (Unresolved Only)

Gather feedback from the PR, **filtering to only unresolved discussions**. Use the GraphQL API to get thread resolution status, since the REST API does not expose `isResolved`.

### 2.1 Review Threads with Resolution Status (GraphQL — Primary Source)

Use the GraphQL API to fetch all review threads and their resolution status. **Only process threads where `isResolved` is `false`.**

**Always request thread `id` (GraphQL node ID) and each comment's `databaseId`** — both are required later for replying and resolving.

```bash
NO_COLOR=1 gh api graphql -f query='
  query($owner: String!, $repo: String!, $pr: Int!, $cursor: String) {
    repository(owner: $owner, name: $repo) {
      pullRequest(number: $pr) {
        reviewThreads(first: 100, after: $cursor) {
          pageInfo { hasNextPage endCursor }
          nodes {
            id
            isResolved
            isOutdated
            path
            line
            startLine
            comments(first: 100) {
              nodes {
                id
                databaseId
                body
                author { login }
                createdAt
                url
              }
            }
          }
        }
      }
    }
  }
' -F owner='{owner}' -F repo='{repo}' -F pr={pr_number}
```

Paginate while `pageInfo.hasNextPage` is true so every unresolved thread is collected.

**Filtering rules:**
- **Skip** threads where `isResolved` is `true` — these have already been addressed and marked resolved by the reviewer or author.
- **Include** threads where `isResolved` is `false` — these are unresolved and need attention.
- Optionally note `isOutdated` threads (code has changed since the comment was made) but still include them if unresolved.
- Store per thread: `thread.id` (for resolve mutation), first comment's `databaseId` (for reply), path, line, body, author.

### 2.2 Review Summaries (top-level review bodies)

```bash
NO_COLOR=1 gh api repos/{owner}/{repo}/pulls/{pr_number}/reviews --paginate
```

Only process reviews with a non-empty `body`. Reviews with state `DISMISSED` should be skipped.

### 2.3 Issue-Style Comments (discussion thread on the PR)

```bash
NO_COLOR=1 gh api repos/{owner}/{repo}/issues/{pr_number}/comments --paginate
```

These are top-level PR discussion comments (not inline code comments). They have no resolution status — include them all, but deprioritize any that have already been replied to with a resolution. Replies use `gh pr comment` or the issues comments API (they cannot be "resolved" like review threads).

### 2.4 PR Description Checklists

```bash
gh pr view --json body
```

Check for any unchecked requirement boxes or inline review notes from the author.

### 2.5 Deduplicate & Filter

- Group reply threads together under their parent comment
- Remove bot comments (dependabot, CI bots, etc.) unless they are actionable review findings you still want to address
- **Exclude all resolved threads** — they should not appear in triage, fixes, or the user decision list
- Note resolved threads only in the final summary report under "Already Resolved" for completeness

---

## Phase 3: Triage & Classify

For each **unresolved** piece of feedback, classify into one of these severity levels:

### Classification Rubric

| Severity | Description | Examples | Action |
|----------|-------------|----------|--------|
| **CRITICAL** | Security vulnerabilities, data loss, crashes, broken auth | SQL injection, unvalidated input reaching DB, missing auth checks, null pointer in critical path | **Present to user with proposed fix** |
| **HIGH** | Bugs, logic errors, missing error handling, race conditions, performance issues likely to cause incidents | Off-by-one errors, unhandled promise rejections, missing null checks, N+1 queries, resource leaks | **Present to user with proposed fix** |
| **MEDIUM** | Code quality issues, suboptimal patterns, minor refactors, missing tests | Better abstraction possible, duplicated logic, missing edge case tests, overly complex function | **Present to user with proposed fix** |
| **LOW** | Style preferences, naming suggestions, documentation, minor improvements | Variable renaming, comment additions, import ordering, slightly better wording | **Auto-fix immediately** |
| **SEMANTIC** | Subjective opinions, architectural philosophy, bikeshedding | Tabs vs spaces debates, framework preferences, "I would have done it differently" | **Auto-fix immediately** |

### Classification Process

For each comment:
1. Read the full comment text and any code context referenced
2. Read the actual file and line range being discussed to understand the real impact
3. Determine if the reviewer is requesting a change vs. asking a question vs. making an observation
4. Assign severity based on the rubric above
5. If a comment is ambiguous, classify it as **MEDIUM** (err on the side of showing the user — safer than silently auto-fixing).

---

## Phase 4: Auto-Fix Low (Nits) & Semantic Items

These are low-risk — naming, comments, import order, style preferences, subjective architectural nits. Apply them directly without asking.

### 4.1 Plan Fixes

For each LOW and SEMANTIC item:
1. Read the relevant file(s) and surrounding context
2. Understand exactly what the reviewer asked for — do not expand scope
3. Plan the minimal change that addresses the comment

### 4.2 Implement Fixes Directly

Most nits and semantic changes are simple edits — make them directly with Edit. Only delegate to a specialized agent if the change touches a meaningfully complex area:

- backend-architect — for semantic refactors across backend/API surfaces
- frontend-developer — for semantic refactors in UI components

For single-file renames, comment tweaks, import reordering, wording changes: just edit inline.

### 4.3 Track Each Fix

Record **every** LOW/SEMANTIC item for the final summary **and** for Phase 6 (reply + resolve) — including ones you did not apply. Track at minimum:

- `thread_id` (GraphQL node id)
- `comment_database_id` (numeric id of the first/root comment in the thread)
- severity, path, reviewer
- outcome: `fixed` | `question-answered` | `skipped` | `deferred`
- `reply_body` draft: one sentence of what changed, or why it was skipped

If a nit is already applied, is incorrect, or you choose not to apply it, still record `skipped` with a concrete reason. Do not drop it from Phase 6.

---

## Phase 5: Present Critical/High/Medium Items With Proposed Fixes

After nits/semantic are applied, present the remaining impactful items to the user. **Each item must include a concrete proposed fix** — not just the reviewer's comment. The user should be able to approve, modify, or skip each one without having to re-read the diff themselves.

### Preparing Each Item

For every CRITICAL/HIGH/MEDIUM comment, before presenting:
1. Read the file and surrounding code the reviewer referenced
2. Understand the underlying problem (not just the surface complaint)
3. Draft the specific code change you would make — exact file, exact lines, before/after snippet
4. Note any risk, tradeoff, or ambiguity the user should know about

### Presentation Format

Order by severity (CRITICAL → HIGH → MEDIUM), then group by file within each severity:

```
## Review Feedback Needing Your Decision

### CRITICAL

1. [auth.ts:45] "User input flows into SQL query without sanitization" — @alice
   Problem: `email` is interpolated directly into the query string, enabling SQL injection.
   Proposed fix: switch to a parameterized query via the existing `db.query(sql, params)` helper.
   ```ts
   // before
   db.query(`SELECT * FROM users WHERE email = '${email}'`)
   // after
   db.query('SELECT * FROM users WHERE email = $1', [email])
   ```
   Notes: No behavior change for valid inputs. Safe to apply.

### HIGH

2. [api/users.ts:92] "This can crash if `profile` is null" — @bob
   Problem: `user.profile.name` is dereferenced without a null check; `profile` is optional in the schema.
   Proposed fix: add a nullish guard and return a default display name.
   ```ts
   // before
   return user.profile.name
   // after
   return user.profile?.name ?? user.email
   ```
   Notes: Matches the fallback pattern already used in `getDisplayName()` at line 140.

### MEDIUM

3. [utils/parse.ts:30] "Extract the date-handling block into a helper" — @alice
   Problem: 20 lines of date parsing are duplicated in 3 call sites.
   Proposed fix: extract a `parseFlexibleDate(input: string): Date | null` helper in the same file and replace all 3 call sites.
   Notes: Low risk, but touches 3 files — confirm you want this bundled in the review-fix commit vs. its own PR.
```

### User Decision

Ask the user which items to apply. Defaults and guidance:
- Default to applying all CRITICAL and HIGH items — but still require explicit confirmation before editing.
- MEDIUM items are opt-in — user picks which to apply.
- Allow the user to reply with freeform edits ("apply #1 and #2, skip #3, and for #1 use `email.toLowerCase()` in the param").

### Implement Approved Items

For each item the user approves:
1. Apply the exact fix shown (with any user-requested tweaks)
2. Use specialized agents only if the fix fans out across multiple complex files
3. Record the applied change for the summary and Phase 6

For items the user **skips**, record them with outcome `skipped` and a concrete reason (user's words if given, otherwise a short summary). Phase 6 **must** reply with that reason and resolve the thread. Skipping the code change does **not** skip the GitHub reply.

---

## Phase 6: Comment & Resolve on GitHub

**This phase is mandatory and must cover 100% of processed threads.** After code changes (and user decisions) are done, close the loop on **every** unresolved thread that entered triage — including every skipped item — by (1) posting a reply that describes the outcome and (2) marking the thread resolved.

Do **not** skip this phase even if all items were auto-fixed LOW/SEMANTIC nits. Do **not** skip it for items the user skipped, items the agent skipped, questions, or items already correct. Reviewers should not have to re-open the diff to discover that feedback was addressed or declined.

**Hard coverage rule:** before posting, list every unresolved `thread.id` from Phase 2. Each must have an outcome. Any thread missing an outcome is treated as `skipped` with reason "not applied this pass" — still reply and resolve. Leaving a processed thread with no reply is a failure of this skill.

### 6.0 When to run

Run Phase 6 once for **all** items that entered triage in Phases 3–5 (not only the ones you fixed):

| Outcome | Reply must say | Resolve thread? |
|---------|----------------|-----------------|
| `fixed` (code change applied) | What we changed | **Yes** |
| `question-answered` (no code change; clarified) | The technical answer | **Yes** |
| `skipped` (user or agent chose not to apply) | Why it was skipped | **Yes** |
| `deferred` (follow-up agreed with user) | Why deferred and the follow-up plan | **Yes** (default). Leave open **only** if the user explicitly said "leave this thread open" |
| Already resolved (Phase 2 filter) | — | No (never entered processing) |

Default: **reply, then resolve**, including skipped and deferred. The only exception is an explicit user request to leave a specific thread open.

### 6.1 Reply to an inline review thread

Use the **numeric** `databaseId` of the root (or latest) comment in the thread — not the opaque GraphQL node id.

Prefer the replies endpoint (works with PR number + comment databaseId):

```bash
NO_COLOR=1 gh api repos/{OWNER}/{REPO}/pulls/{pr_number}/comments/{databaseId}/replies \
  -X POST \
  -f body="<reply text>"
```

Fallback if `/replies` fails (some API versions / permissions):

```bash
NO_COLOR=1 gh api repos/{OWNER}/{REPO}/pulls/{pr_number}/comments \
  -X POST \
  -f body="<reply text>" \
  -F in_reply_to={databaseId}
```

**Note:** Use `-F` (not `-f`) for `in_reply_to` so it is sent as an integer, not a string.

### 6.2 Reply templates (always substantive — never bare acks)

**Never** reply with only "Done", "Fixed", "Ack", "Thanks", or "Will fix". Every reply must explain the outcome.

**Fixed (with local commits not yet pushed):**

```text
Addressed: <one-sentence description of the change>.
```

**Fixed (after push, when you have a commit SHA):**

```text
Addressed in <short_sha>: <one-sentence description of the change>.
```

If fixes are not pushed yet (this skill does not require push — `/pr` may come later), omit the SHA and still describe the change clearly. Optionally note that the fix is on the branch and will land with the next push.

**Question / observation (no code change):**

```text
<Substantive technical answer: why the current code is correct / how it works / what the constraint is.>
```

**Skipped (user declined, or agent did not apply):**

```text
Skipping this change: <concrete reason — user declined / already correct because … / out of scope because …>. Happy to revisit if needed.
```

The skip reason must be specific. Not allowed: "Skipping.", "Won't fix.", "No.", or an empty reason.

**Deferred (still reply + resolve unless user said leave open):**

```text
Acknowledged — deferring to a follow-up: <what will be done and where/when if known>. Resolving this thread; tracking the follow-up separately.
```

If the user explicitly said leave the thread open, use the same body but end with "Leaving this thread open to track." and do **not** resolve.

### 6.3 Resolve the review thread (GraphQL)

After a successful reply (for outcomes that should resolve), mark the thread resolved using the GraphQL node `id` from Phase 2:

```bash
NO_COLOR=1 gh api graphql -f query='
  mutation($threadId: ID!) {
    resolveReviewThread(input: {threadId: $threadId}) {
      thread {
        id
        isResolved
      }
    }
  }
' -f threadId='{thread_graphql_id}'
```

Verify `isResolved` is `true` in the response. If the mutation fails (permissions, already resolved, invalid id), log it in the summary and continue with remaining threads — do not abort the whole phase.

### 6.4 Order of operations per thread

For each handled item:

1. Compose the reply body from the template matching the outcome (what we did, or why we skipped)
2. POST the reply (`/replies` or `in_reply_to`)
3. Run `resolveReviewThread` for `fixed` | `question-answered` | `skipped` | `deferred`
4. Leave unresolved **only** if the user explicitly said to leave that thread open
5. Record success/failure of reply and resolve for the summary

Process threads sequentially (or with modest parallelism) but **do not** resolve before replying — reviewers should see the explanation on a resolved thread.

### 6.5 Top-level review bodies & issue comments

These are not GraphQL review threads:

- **Review summary body** (non-empty CHANGES_REQUESTED / COMMENTED review): after addressing, post a single PR conversation comment summarizing what was done, e.g. `gh pr comment {pr} --body "..."`. There is no per-review "resolve" API beyond dismissing the review (do **not** dismiss reviews unless the user asks).
- **Issue-style PR comments**: reply in the conversation with `gh pr comment` when a response is warranted. No resolve action.

### 6.6 Batching guidance

- One reply per thread (do not spam multiple status updates).
- If several threads were fixed by the same change, still reply on **each** thread referencing that change so each conversation closes cleanly.
- Prefer short, specific replies over long essays.

---

## Phase 7: Summary Report

After all work is complete (including Phase 6), provide a final report:

```markdown
## PR Review Fix Summary

**PR**: #[number] - [title]
**Branch**: [branch-name]

### Auto-Fixed (Low & Semantic)
| # | Severity | File | Fix Applied | Reviewer | GH Reply | Resolved |
|---|----------|------|-------------|----------|----------|----------|
| 1 | LOW | utils.ts:12 | Renamed `val` → `validationResult` | @alice | ✓ | ✓ |
| 2 | SEMANTIC | hooks/useData.ts:30 | Converted useState cluster to useReducer | @bob | ✓ | ✓ |

### User-Approved Fixes (Critical/High/Medium)
| # | Severity | File | Fix Applied | Reviewer | GH Reply | Resolved |
|---|----------|------|-------------|----------|----------|----------|
| 3 | CRITICAL | auth.ts:45 | Parameterized SQL query | @alice | ✓ | ✓ |
| 4 | HIGH | api/users.ts:92 | Added null guard on profile | @bob | ✓ | ✓ |

### Skipped (user or agent)
| # | Severity | File | Why skipped | Reviewer | GH Reply | Resolved |
|---|----------|------|-------------|----------|----------|----------|
| 5 | MEDIUM | utils/parse.ts:30 | User declined — extract date helper later | @alice | ✓ | ✓ |

### Already Resolved (pre-existing)
| # | File | Comment | Reviewer |
|---|------|---------|----------|
| 6 | old-file.ts | Previous review round | @charlie |

### GitHub thread actions
- Processed unresolved threads: N (must equal Phase 2 count)
- Replied: N threads (must equal processed count)
- Resolved: M threads
- Left open (user asked): K threads
- Failed reply/resolve: list any errors
- **Coverage check:** every Phase 2 unresolved thread id appears above. If any are missing, go back and reply + resolve them before finishing.

### Next Steps
- Run `/pr` to commit and push all fixes (if not already pushed)
- Confirm every processed thread has a reply + resolved state on the PR
```

---

## Error Handling

| Error | Action |
|-------|--------|
| No PR found | Stop, tell user to create a PR first |
| No review comments | Stop, tell user the PR has no feedback yet |
| gh CLI not authenticated | Stop, tell user to run `gh auth login` |
| Fix causes issues | Try alternative approach, or escalate to user |
| Ambiguous comment | Classify as MEDIUM and present to user |
| Comment is a question, not a request | Answer in the thread reply (Phase 6), resolve the thread, don't make code changes |
| User or agent skips a change | Still reply with the skip reason and resolve the thread — never silently leave it |
| Reply API fails | Retry once with the `in_reply_to` fallback; if still failing, note in summary and still attempt resolve if appropriate |
| Resolve mutation fails | Note in summary; leave thread open rather than faking success |
| Missing `thread.id` or `databaseId` | Re-fetch that thread via GraphQL before Phase 6; do not invent ids |

---

## Important Rules

1. **Only process unresolved threads** for triage and fixes — already-resolved discussions are not re-fixed. They appear only in the "Already Resolved" section of the summary.
2. **Read the actual code** before classifying — a "rename variable" comment on a public API export is HIGH, not LOW. Getting this wrong means silently applying a breaking change.
3. **Preserve reviewer intent** — don't "improve" beyond what was asked.
4. **Never auto-apply impactful changes** — CRITICAL/HIGH/MEDIUM always wait for user approval, even when the fix looks obvious. The user wants to see every meaningful change before it lands.
5. **Always include a concrete proposed fix** when presenting CRITICAL/HIGH/MEDIUM — don't just relay the reviewer's comment. Show the exact code change.
6. **Group related comments** — if 3 comments are all about the same function, fix them together (but still reply/resolve each thread in Phase 6).
7. **Don't argue with reviewers** — implement what's asked. If you disagree, note it in the summary for the user and in the thread reply if the item is skipped.
8. **Track everything** — every unresolved comment must appear in the final summary. Already-resolved comments are listed separately for reference.
9. **Reply + resolve every processed thread, including skipped** — Phase 6 is not optional and is not "fixed items only". Every unresolved thread from Phase 2 gets a reply (what we did, or why we skipped it) and is then marked resolved. A skipped code change still gets a skip-reason reply and a resolve.
10. **Never bare-ack** — every GitHub reply must explain what was done or why it was skipped. Empty / "Done" / "Skipping." replies are a failure of this skill.
11. **Reply before resolve** — always post the explanation first, then mark the thread resolved.
12. **Do not dismiss reviews** (`PUT .../reviews/{id}/dismissals`) unless the user explicitly asks — resolving threads is enough for conversation hygiene.
13. **Coverage before done** — do not finish until replied + resolved count matches the Phase 2 unresolved thread count (minus any the user explicitly asked to leave open).
