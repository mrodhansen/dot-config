---
name: watch-pr
description: Watches a GitHub PR every 5 minutes and acts on what changed, based on whether you wrote it (author) or are reviewing it (reviewer). Author - auto-fixes merge conflicts and CI, runs review fixes, pushes, and Slack-DMs reviewers ("needs a re-review", "this needs another approval"). Reviewer - when the author pushes or replies, checks whether each of your review threads was addressed well, reviews the new changes, then approves or posts more findings, and DMs the author ("approved", "more findings"). This session only dispatches and answers questions; every fix/review runs in a background subagent, in the current worktree if you are already in one for that PR, else in a dedicated watch worktree. Use when the user says "/watch-pr 1234", "watch this PR", "monitor PR", "babysit PR", "keep an eye on #1234", or "/watch-pr stop 1234".
---

# /watch-pr — PR watcher

**Usage:** `/watch-pr [PR# | URL] [--as author|reviewer] [--every 5m]` · `/watch-pr stop <PR#>` · `/watch-pr status <PR#>`

PR# is optional when the session is already in a worktree for that PR.

User arguments: `$ARGUMENTS`

A deterministic poller (`scripts/watch_pr.py`, no LLM) diffs the PR every interval and prints one line per event. This session runs it under **Monitor**, so quiet polls cost nothing. On events, this session **dispatches background subagents** to do the work. It stays free so the user can ask "what's going on with #1234?" at any time.

```
W=~/.ai/skills/watch-pr/scripts/watch_pr.py      # every call takes --repo OWNER/NAME --pr N
$W watch   --role auto|author|reviewer --interval 300   # Monitor stream
$W status                                             # fresh state + recent activity log
$W threads --started-by @me [--unresolved]            # thread bodies (address check)
$W log     --who <dispatcher|worker:kind> "msg"       # activity log line
$W dm      --to <github-login|@me> --text "msg"       # Slack DM, deduped 30 min
$W once [--no-save] | reset                           # one-off poll / forget state
```

State + activity log: `~/.cache/watch-pr/<owner>-<repo>-<N>.{json,log}`. GitHub→Slack map: `~/.config/watch-pr/people.json` (`{"<github-login>": "<slack handle>" | null}`), kept outside this public repo.
- **Strict.** Only logins listed there get DMs; `null` marks a bot (never DMed). No name matching or guessing.
- **Unmapped login:** `dm` fails with `USER_NOT_MAPPED`. DM self `<url> can't DM <login>: add them to people.json` + push notify, and send nothing to anyone.

---

## Roles

| Role | When | You are in charge of |
|------|------|----------------------|
| **author** | PR author is you (`--as author` to force, e.g. you push to a teammate's PR) | conflicts, CI, answering reviews, getting approvals |
| **reviewer** | anyone else's PR | checking your review was addressed, approving or posting more findings |

`auto` decides from the PR author; the role is saved in state. A cross-repo (fork) PR in author mode cannot be pushed to. Run notify-only and say so.

---

## Dispatcher rules (this session)

1. **Never edit code, run fixes, or push here.** All of that goes to a subagent (Agent tool, background). This session handles: parsing events, `status`, `log`, `dm`, `PushNotification`, `gh pr edit --add-reviewer`, and talking to the user.
2. **One worker per PR at a time.** Events that land while a worker runs are only logged. When the worker finishes, run `status` and dispatch whatever is *still* true (a CI failure on an old head is stale). In author mode, `reviews awaiting your answer: N>0` or unresolved threads where the last word is not yours means a review-fix worker is still owed.
3. **Priority (author):** CONFLICT → pre-push hook failure → CI_FAILED → review fixes. Skip CI fixes while the branch conflicts (CI does not run on a conflicting PR; the merge push re-runs it).
4. **Log every dispatch and outcome:** `$W log --who dispatcher "dispatched ci worker for typecheck@3ef83f30"`.
5. **User questions:** run `$W status` (fresh) and read the log tail. Answer from those plus the running worker's `worker:*` log lines. Never invent a running worker's result. If it hasn't returned, say it is still running and what it last logged.
6. **Loop until it works.** There are no retry caps:
   - After a worker returns `failed` or `no-change`, run `status`. If the same problem is still there on the current head (conflict, failing check, pre-push failure, unanswered review), dispatch again right away.
   - Each retry gets every earlier attempt's SUMMARY/DETAILS for that problem, plus "try a different approach than these".
   - Log each attempt (`attempt N for typecheck`) so `status` shows the loop.
   - Only outcomes code cannot fix wait instead of looping:
     - a safety stop from the sync rule: uncommitted changes, unpushed local commits, diverged
     - an environment failure: Docker not running, gh/git auth, network

     DM self + push notify once for each, then retry on the next event or when the user says go.
7. **Never** merge, never `--no-verify`, never push to the base branch, never force-push.

---

## Setup

1. **Resolve:** `REPO=$(gh repo view --json nameWithOwner -q .nameWithOwner)`.
   - PR number from the arg/URL. With no arg, take it from the current branch: `quick/pr-N` / `quick/watch-pr-N` → N, else `gh pr view --json number -q .number`. If none, ask.
   - Then `gh pr view N --json headRefName,baseRefName,headRefOid,isCrossRepository,author,url`.
2. **Worktree: use the current one if the session is already in a worktree** (`git rev-parse --show-toplevel` ≠ the first path in `git worktree list --porcelain`). This covers quick, slot, and `.claude/worktrees` worktrees.
   - **It must belong to this PR.** `git fetch origin <headRef>`, then accept it only if the branch is `<headRef>`, `quick/pr-N` or `quick/watch-pr-N`, or `HEAD` and `FETCH_HEAD` are ancestor-related in either direction. Anything else is a hard stop: `current worktree is on <branch>, PR #N is <headRef>`. Never repoint someone's worktree.
   - Run `yarn install` there only if `node_modules` is missing (it is your live worktree; don't churn it).
   - Log `worktree <path> owned=false`.
3. **Otherwise create a dedicated one (Haiku subagent, `model: "haiku"`):** from the primary checkout run `~/.ai/oc_skills/worktree-quick/scripts/quick-worktree.sh create N watch-pr-N`. That gives `…/worktrees/<repo>-quick-watch-pr-N`. Never work in the primary checkout.
   - If it fails with `worktree path already exists`, reuse the path and apply the sync rule from the worker preamble.
   - `yarn install` must exit 0, even on reuse.
   - The subagent returns the path. Log `worktree <path> owned=true`.
4. **Arm Monitor:** command `python3 ~/.ai/skills/watch-pr/scripts/watch_pr.py watch --repo $REPO --pr N --role <auto|--as> --interval 300`, description `PR #N watch`, `timeout_ms: 1800000`.
   - On expiry, re-arm the identical command silently; state persists, so nothing repeats.
   - If it exits after `PR_MERGED` / `PR_CLOSED`, do not re-arm.
   - Arm it in parallel with step 3. Events that need the worktree wait for it.
5. **Tell the user in one line:** `Watching #N as <role> (5 min). Ask me anything about it.` The first poll prints `BASELINE` plus anything already actionable. Handle those like any other event.

`/watch-pr stop N`: TaskStop the monitor, stop any worker, log it, keep the worktree. `/watch-pr status N`: run `status` and summarize.

---

## Author playbook

| Event | Action |
|-------|--------|
| `CONFLICT` | conflicts worker → push worker |
| `CI_FAILED` | ci worker (one run covers every failing check on that head) → push worker. `attempt=N` is how many heads in a row the check has failed on: pass the earlier attempts' SUMMARY/DETAILS from the log so the worker does not repeat a dead end |
| `NEW_REVIEW`, `NEW_REPLY` / `NEW_COMMENT` that ask for a change, `UNANSWERED_THREADS`, `UNANSWERED_REVIEWS` | review-fix worker (see the flow below). `UNANSWERED_REVIEWS` = reviews with a body (or CHANGES_REQUESTED) posted before the watch started that you never answered; they often have no inline threads |
| `NEW_REPLY` / `NEW_COMMENT` that is just an acknowledgment | log only |
| `DECISION … CHANGES_REQUESTED` | log; the matching `NEW_REVIEW` drives the work |
| `APPROVAL_LOST approvers=a,b` | `dm --to <each approver> "<url> this needs another approval"` |
| `REVIEW_REQUEST_SENT to=x rereview=true` | `dm --to x "<url> needs a re-review"` |
| `REVIEW_REQUEST_SENT to=x rereview=false` | `dm --to x "<url> ready for review"` |
| `READY_TO_MERGE` | DM self `<url> ready to merge` + push notify. Never merge |
| `CI_GREEN` | log only |

**Review-fix flow.** Every unresolved comment gets addressed, nit to critical. Nothing is skipped and nothing waits for the user:
1. **Worker pass 1:** fixes every unresolved thread and change-request comment at every severity (LOW, SEMANTIC, MEDIUM, HIGH, CRITICAL), commits, returns `ready-to-push`. It does not reply on GitHub yet.
2. **Push worker.**
3. **Worker pass 2** (`SendMessage` with the new SHA): replies on every thread with what changed + resolves it, and posts one PR comment per review body it addressed (fix-pr-review Phase 6, incl. 6.5). It returns the reviewers whose threads or reviews it handled. A review counts as answered once you comment on the PR or re-request that reviewer after it, or every thread it opened is resolved.
4. **Re-request on GitHub:** `gh pr edit N --add-reviewer <them>`. Then `dm --to <each> "<url> needs a re-review"` directly, because GitHub may not log a new request for someone already listed. The `dm` dedupe stops the later `REVIEW_REQUEST_SENT` from sending it twice.

**Pre-push hook failures:** the push worker returns the hook output verbatim. Dispatch a ci worker with that output as the failure source, then push again. Repeat until the push lands.

**Approved, then conflicts:** `CONFLICT` → fix + push → if the repo dismisses stale approvals, the next poll emits `APPROVAL_LOST` → DM the approvers `<url> this needs another approval`.

---

## Reviewer playbook

| Event | Action |
|-------|--------|
| `ADDRESS_CHECK_DUE` | address-check worker (it approves, holds, or posts findings itself). `my_review=APPROVED/DISMISSED` means you had approved and new commits landed (CI fix, conflict fix, anything): the worker runs in **re-check mode** |
| `CONFLICT` | `dm --to <author> "<url> has merge conflicts"` (they are responsible) |
| `CI_FAILED` (one batch per head) | `dm --to <author> "<url> CI failing: <checks>"` |
| `CI_GREEN` | if the log has `held head=<this head>` from an address check → approve worker for that head; else log only |
| worker `RESULT: held` | log `held head=<H> reason=<conflict\|ci>`. If the matching `CONFLICT` / `CI_FAILED` DM was not sent yet, send it now (dedupe makes it safe) |
| `MY_REVIEW_POSTED state=APPROVED` | `dm --to <author> "<url> approved"` |
| `MY_REVIEW_POSTED first=true` (not approved) | `dm --to <author> "<url> left a review"` |
| `MY_REVIEW_POSTED first=false` (not approved) | `dm --to <author> "<url> more findings"` |
| `AWAITING_MY_REVIEW`, `REVIEW_REQUESTED` | DM self `<url> waiting on your review` + push notify. Do not auto-review |
| `NEW_COMMITS`, `AUTHOR_REPLIED`, `MY_THREAD_RESOLVED`, `RE_REQUESTED` | log only; the script turns these into `ADDRESS_CHECK_DUE` once activity settles (one quiet poll) or right away on re-request |

`MY_REVIEW_POSTED` fires for any review you submit, whether the worker posted it or you did by hand, so the author always gets one DM per review.

---

## Both roles

| Event | Action |
|-------|--------|
| `PR_MERGED` / `PR_CLOSED` | Automatic teardown (below) |
| `READY_FOR_REVIEW` | log only |
| `WATCH_ERROR` | DM self `<url> watcher error: <msg>` + push notify. `fatal=true` means the script needs fixing: do not re-arm blindly |
| `WATCH_LIMIT` | tell the user the page limit was hit (events there may be missed) |
| `WATCH_RECOVERED` | log only |

**Teardown on merge/close.** Automatic, no confirmation:
1. **Stop the watch.** The Monitor script exits by itself after `PR_MERGED` / `PR_CLOSED`; do not re-arm. TaskStop any worker still running for this PR.
2. **Leave the worktree.** If this session's cwd is inside the worktree, move out first: `ExitWorktree` with `action: "keep"` if it was entered that way, else run everything from the primary checkout with absolute paths.
3. **Destroy it (Haiku teardown worker).** Owned and reused worktrees alike. The **only** exception is work that would be lost:
   - Keep it if `git -C <WT> status --porcelain` is non-empty, or `git -C <WT> log --oneline HEAD --not --remotes` lists commits. Then DM self `<url> merged, kept <WT>: uncommitted/unpushed work` with the list.
   - Never pass `--force`. Never touch the primary checkout.
   - How to destroy, by worktree type:

     | Worktree | Command |
     |---|---|
     | quick (`*-quick-*` dir or quick marker) | `~/.ai/oc_skills/worktree-quick/scripts/quick-worktree.sh destroy --path <WT> --yes` |
     | slot (`.worktree-slot` file) | `~/.ai/oc_skills/monorepo-worktree/scripts/destroy-worktree.sh --path <WT> --yes` (also drops its DB + Redis slot) |
     | anything else | `git -C <primary> worktree remove <WT>` |
4. **Clean up.** `$W reset` (drop state; keep the log). No DM: tell the user in this session only.

**Slack voice:** the user's own words, one line: `<url> approved`, `<url> needs a re-review`, `<url> more findings`, `<url> this needs another approval`. No greetings, no summaries.

**Messaging the user (DM self + PushNotification): only when the watcher needs something from them.** Progress, fixes pushed, approvals, holds, merges are all logged only; the user asks this session when they want to know. The complete list:
- unmapped login (`USER_NOT_MAPPED`)
- a safety stop: uncommitted changes, unpushed local commits, or a diverged branch in the worktree
- an environment failure: Docker, gh/git auth, network
- `WATCH_ERROR`
- merged, but the worktree was kept because it holds unsaved work
- `READY_TO_MERGE` (only you merge)
- `AWAITING_MY_REVIEW` / `REVIEW_REQUESTED` (the first review is yours)

One message per blocker, deduped; not again until it changes.

---

## Worker prompts

Every worker is a background `general-purpose` subagent. Code workers use the session model; push / setup / teardown use `model: "haiku"`. Every prompt includes this preamble with the values filled in:

```
PR #<N> (<url>) in <REPO>. Head branch <headRef>, base <baseRef>. Role: <role>.
Worktree: <WT> (owned=<true|false>; false = the user's own worktree). Work ONLY there: `cd <WT> && …` on every Bash command, or absolute paths.
Before starting, sync without ever discarding work: `git -C <WT> fetch origin <headRef>`, then
  - uncommitted changes → stop, RESULT: failed, "worktree has uncommitted changes" (never stash/reset the user's edits)
  - HEAD == FETCH_HEAD → go
  - HEAD is an ancestor of FETCH_HEAD → `git -C <WT> merge --ff-only FETCH_HEAD`
  - FETCH_HEAD is an ancestor of HEAD (local commits not pushed yet) → stop, RESULT: needs-decision, list them (`git log FETCH_HEAD..HEAD --oneline`); never push or drop them on your own
  - diverged → stop, RESULT: failed, show both SHAs
  Never `reset --hard`, never `checkout` another branch, never `clean`.
Log progress at each phase: `python3 ~/.ai/skills/watch-pr/scripts/watch_pr.py log --repo <REPO> --pr <N> --who worker:<kind> "<one line>"`.
Never ask the user. If a decision is needed, stop and return RESULT: needs-decision with numbered options.
No attempt caps: keep iterating inside this run until the fix is in, unless the failure is environmental (Docker, auth, network); then return RESULT: failed with the verbatim error.
<if a retry: "Earlier attempts on this problem (do not repeat them):" + their SUMMARY/DETAILS>.
Never push (unless you are the push worker), never --no-verify, never touch <baseRef>/main, never merge the PR.
Follow ~/.claude/CLAUDE.md rules (fail hard, hard types, no soft fallbacks).
End with exactly:
RESULT: ready-to-push | pushed | no-change | needs-decision | approved | held | commented | failed
SUMMARY: <1-3 lines>
DETAILS: <whatever the dispatcher needs: files, SHAs, reviewers, numbered decisions, verbatim errors>
```

| Kind | Model | Task |
|------|-------|------|
| `conflicts` | session | Read `~/.claude/commands/fix-merge-conflicts.md` and follow it from Phase 1. Skip Phase 0: the worktree is given. Merge `origin/<baseRef>`, complete the merge commit, do not push. |
| `ci` | session | Read `~/.ai/skills/fix-ci/SKILL.md` and follow it from Phase 1 (skip Phase 0). Use `<headRef>` for `gh run list --branch`. Given hook output instead of a CI run, fix from that. Commit, do not push. |
| `review-fix` | session | Read `~/.ai/skills/fix-pr-review/SKILL.md`, follow from Phase 1 (skip Phase 0). **Override its Phase 5: no severity gets presented or skipped.** Implement the fix for every item, CRITICAL/HIGH/MEDIUM included, the same way it auto-fixes LOW/SEMANTIC. Change the code for every comment. The only exceptions: a question gets an answer, and a suggestion that is technically wrong (it would break behavior or contradict the PR's purpose) gets an in-thread reply with the concrete reason. Never a silent skip, never "out of scope". Commit, return `ready-to-push`. Do not reply or resolve on GitHub until resumed with the pushed SHA. |
| `push` | haiku | `git -C <WT> push origin HEAD:refs/heads/<headRef>`. Wait for the pre-push hook (minutes). Return the new SHA, or the hook/push error verbatim. Do not fix code. Non-fast-forward → return it (dispatcher re-syncs). |
| `address-check` | session | The procedure below. |
| `approve` | haiku | Only if `gh pr view N --json headRefOid` is still `<H>` and nothing is conflicting/failing: `gh api repos/<REPO>/pulls/<N>/reviews -X POST -f commit_id=<H> -f event=APPROVE -f body="still good, CI green"`. Head moved or not green → `RESULT: no-change` (the next check covers it). |
| `teardown` | haiku | Teardown steps 3–4 above. |

---

## Address check (reviewer worker)

Input from the event: `review_commit` (R, the commit your last review was on), `head` (H), and `my_review`. **Re-check mode** = `my_review` is `APPROVED` or `DISMISSED`: you had approved, and new commits landed after it. `main` dismisses approvals on every push, so it shows up as `DISMISSED`.

1. **Sync** the worktree to H (preamble). `git -C <WT> cat-file -e R || git -C <WT> fetch origin R`.
2. **Threads:** `$W threads --repo <REPO> --pr <N> --started-by @me`. Work on the unresolved ones plus any resolved since the review (they still need a verdict). In re-check mode there are usually none; the delta review is the whole job.
3. **Delta = the author's work since R:**
   - Own commits: `git log --no-merges --format='%H %cI %an %s' R..H` and `git log -p --no-merges R..H`.
   - Merges from base: `git log --merges --format=%H R..H`, then `git show --remerge-diff <sha>` for each. That shows only how the conflicts were resolved, which is the author's work and must be reviewed. The rest of base's changes are not.
   - If R is not an ancestor of H (force-push): compare `git diff R H -- $(gh pr diff N --name-only)` and say so in DETAILS.
4. **No response yet → stop** (not in re-check mode): no commit in R..H has a committer date after your review, and no reply from someone else on your threads after it → `RESULT: no-change`, SUMMARY `no response to the review yet`. Post nothing. In re-check mode any new commit is what you are checking, so always continue.
5. **Verdict per thread**, read against the code at H, the delta, and the author's replies:
   - `ADDRESSED`: fixed, and fixed properly. A band-aid that breaks the CLAUDE.md rules (`?? ''`, swallowed catch, `as any`) is `PARTIAL`.
   - `ADDRESSED_DIFFERENTLY`: a different fix, sound, and explained or self-evident.
   - `PUSHED_BACK_OK`: the author explained why not, and the reason holds against the code (or a follow-up issue is linked).
   - `PUSHED_BACK_WEAK`: the reason does not hold or does not answer the concern.
   - `PARTIAL` / `NOT_ADDRESSED`: no change and no answer, or only part of it.
   - More than 15 threads: group them by file and run the groups as parallel subagents if you have the Agent tool (each returns `{threadId, verdict, why}` JSON). Otherwise work through the files in order.
6. **New findings in the delta only:** use the `/pr-review-light` concerns (read `~/.ai/skills/pr-review-light/SKILL.md` for the rubric: security, silent failure / soft types, R1–R9, tests, dead code). Flag only problems the new commits introduced. Each finding gets severity, path, and a line that exists on the RIGHT side of `gh pr diff N` at H; otherwise it goes in the review body.
   - **Re-reviews post MEDIUM and up only.** LOW findings and nits (style, naming, unused import, tiny dead local) are never posted: not as inline comments, not in the review body, not as thread replies. List them under `DETAILS: unposted LOW:` so the user can ask about them; nothing else.
7. **Decide.** The code is *good* when every thread (nits included) is `ADDRESSED` / `ADDRESSED_DIFFERENTLY` / `PUSHED_BACK_OK` and there are **zero** new CRITICAL/HIGH/MEDIUM findings. Unposted LOW/nit findings never block approval. Then read the PR's health at H (`gh pr view N --json mergeable,statusCheckRollup,reviewDecision`):
   - **Code not good → COMMENT** (re-check mode too). Mention a conflict or failing CI in the body. Never `REQUEST_CHANGES` unless the user's earlier review on this PR used it.
   - **Code good, but the PR conflicts, or any check on H is failing or still pending → `RESULT: held`.** Post nothing. DETAILS: `held head=<H> reason=conflict|ci`. Fixing a conflict or failing CI takes a push, which dismisses any approval anyway. The dispatcher DMs the author, and the approval follows from the next check or from `CI_GREEN`.
   - **Code good, no conflict, every check green (or none) → APPROVE.** In re-check mode the body is `still good after <short H>`. Exception: your approval is still standing (`my_review=APPROVED` and `reviewDecision=APPROVED`, i.e. nothing dismissed it). Then post nothing: `RESULT: no-change`, SUMMARY `still good`.
8. **Post**, in this order, everything against commit H:
   1. `ADDRESSED` → resolve the thread.
   2. `ADDRESSED_DIFFERENTLY` / `PUSHED_BACK_OK` → short reply (`makes sense`) + resolve.
   3. `PARTIAL` / `NOT_ADDRESSED` / `PUSHED_BACK_WEAK` → reply with what is still missing, leave it open.
   4. Then **one** review: `gh api repos/<REPO>/pulls/<N>/reviews -X POST --input <json>` with `commit_id=H`, `event=APPROVE|COMMENT`, a one-line `body`, and `comments[]` = new MEDIUM+ findings `{path, line, side:"RIGHT", body}`.
   - Thread replies use the GraphQL `addPullRequestReviewThreadReply(pullRequestReviewThreadId, body)`; resolving uses `resolveReviewThread(threadId)`.
   - Finding style matches the user's existing comments, e.g. `**[HIGH] SilentFailure:** <problem>. <fix>.` Short, no AI filler.
   - The review must have a body so the watcher sees it as a real review. Do not DM: the watcher's `MY_REVIEW_POSTED` drives the DM.
9. **Return** `RESULT: approved | held | commented | no-change`. SUMMARY gives counts (`38/42 addressed, 2 pushed back ok, 2 still open, 1 new HIGH, 3 LOW unposted`). DETAILS has a verdict table (thread URL, verdict, one-line why) plus the unposted LOW list.

---

## Guardrails

- The script ignores your own pushes, comments, and replies, so the watcher never triggers itself. Bots' PR comments are ignored; bot *reviews* count.
- A lone thread reply is not a review (GitHub wraps every reply in a review object), so it does not count as "you reviewed", and in author mode it is reported as `NEW_REPLY`.
- Re-request = a `ReviewRequestedEvent` for you **after** your last real review. Being on the requested list means nothing, because a COMMENTED review does not clear it.
- A dismissed approval still counts as your last review, so the re-check diffs from the approval commit, not from an older review.
- Reviewer mode reports only *new* conflicts and CI failures. Breakage that was already there when the watch started is not DMed.
- Commits are compared by SHA, never by timestamp, except in the address check's no-response rule, which only *suppresses* posting.
- `mergeable=UNKNOWN` (GitHub still computing) keeps the last known value; it never clears or re-fires CONFLICT.
- Silence means quiet: three `gh` failures in a row emit `WATCH_ERROR`; an unknown response shape exits with `fatal=true`.
- Tests: `python3 -m unittest discover -s ~/.ai/skills/watch-pr/tests` (pure diff logic, no network). Live dry run: `$W once --repo R --pr N --state-dir <scratch dir>`.
- Sessions only: the watch ends when this Claude session closes. Re-running `/watch-pr N` later resumes from the saved state without repeating old events.
