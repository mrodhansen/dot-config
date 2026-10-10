---
name: pr
description: Commits, pushes the feature branch (never main; never --no-verify), and creates or updates the PR. If the repo pre-push hook fails, fix those errors, commit, and retry the push. Use when user says "/pr", "create pr", "ship it", or "prepare pr".
---

# /pr - Automated PR Workflow

Automates the complete pull request workflow in a single command.

Quality checks (format, lint, typecheck, test, build) run in the repo **pre-push** hook (`.husky/pre-push` — there is no pre-commit hook). Prisma stays in GitHub Actions only. Do **not** run those checks in this skill before push. If the hook fails, fix the reported errors, commit, and push again. Never `--no-verify`.

## Model split (Claude Code)

Steps 1–7 are babysitting. Run them in a **Haiku subagent** (Agent tool, `model: "haiku"`): tell it to follow `~/.ai/skills/pr/SKILL.md`, and pass a 1–3 line summary of what changed and why (you have that context; it doesn't) so the commit and PR text are right. It returns the branch, commit(s), push result, and PR URL.

On a `lint` / `typecheck` / `test` / `build` hook failure the subagent stops and returns the errors. **You** (session model) fix the code, then re-delegate commit + push. Same 3-loop cap.

If you **are** that subagent, skip this section and run the steps directly — do not delegate again.

## CRITICAL SAFETY RULE

**NEVER push directly to main or master. ALWAYS create a feature branch first.**

This is non-negotiable. If on main/master, you MUST create a new branch before proceeding.

**NEVER `git push --no-verify`.** That skips the CI gate.

## Workflow Steps

Execute these steps in order, stopping if any step fails:

### Step 1: Check Current Branch (SAFETY CHECK)

```bash
git branch --show-current
```

**If the current branch is `main` or `master`:**
1. STOP - Do not proceed with push
2. Create a new feature branch based on the changes:
   ```bash
   git checkout -b <branch-name>
   ```
3. Branch naming: Use descriptive names like `fix/openai-api-key-deployment` or `feat/user-authentication`

**Only proceed if on a feature branch (not main/master).**

### Step 2: Check Git Status

```bash
git status
git diff --stat
```

- If working tree is clean and up-to-date with remote, check if PR exists
- If there are changes, proceed to commit
- Do **not** run typecheck, format, lint, test, or build here — pre-push is the gate

### Step 3: Stage and Commit

**Get context for commit message:**
```bash
git diff --staged
git diff
git log --oneline -5
```

**Stage changes:**
```bash
git add -A
```

**Create commit with descriptive message:**

Analyze the changes and create a conventional commit message:
- `feat:` for new features
- `fix:` for bug fixes
- `refactor:` for code refactoring
- `style:` for formatting changes only
- `docs:` for documentation
- `test:` for test changes
- `chore:` for maintenance

If only formatting changes exist, use:
```bash
git commit -m "style: format code"
```

For substantive changes, write a descriptive message explaining what and why.

Do not add any `Co-Authored-By` trailer (Claude, Grok, or otherwise).

### Step 4: Push to Remote (NEVER TO MAIN, NEVER --no-verify)

**First, verify you are NOT on main/master:**
```bash
git branch --show-current
```

If on main or master, STOP and go back to Step 1.

**Push the feature branch:**
```bash
git push -u origin HEAD
```

The **pre-push** hook will run format/sync, lint, typecheck, test, and build. This can take several minutes. Wait for it. Capture the full output.

#### If the hook blocks the push — fix and retry (max 3 loops)

Do **not** `--no-verify`. Do **not** skip to creating the PR.

1. Read the hook banner and the errors above it:
   - `CI job :` — which job failed
   - `Command:` — exact command
   - `Fix    :` — hint
   - The nx / prettier / jest errors above the banner
2. Fix the **root cause**. Job-specific:

   | CI job | Fix |
   |--------|-----|
   | `format-and-sync (yarn install --immutable)` | `yarn install`, commit `yarn.lock` |
   | `format-and-sync (nx sync:check)` | `yarn nx sync`, commit the result |
   | `format-and-sync (format:check)` | `yarn nx format:write`, commit formatted files (`style: format code`) |
   | `lint` | Fix the lint errors; do not disable rules to silence them |
   | `typecheck` | Fix the TypeScript errors; no `any` / `@ts-ignore` to paper over |
   | `test` | Fix implementation or tests so assertions match real behavior |
   | `build` | Fix compile/bundle errors |

3. If Docker is not running and tests need it: tell the user to start Docker, then retry the push. Do not fake a pass.
   **Haiku subagent (see Model split):** do `format-and-sync` fixes yourself. For `lint` / `typecheck` / `test` / `build`, do **not** edit code — stop and return the hook banner + errors verbatim to the main session.
4. If you cannot fix with confidence (ambiguous test, schema conflict, missing product decision): **stop and ask**. Wrong quiet success is worse than a blocked push.
5. Commit the fix (conventional message, no `Co-Authored-By`):
   ```bash
   git add -A
   git commit -m "fix: <what the hook failed on>"
   ```
6. Push again (`git push -u origin HEAD`). Still never `--no-verify`.
7. Repeat from (1) if it fails again. **Maximum 3 fix-push loops.** After 3, stop, report every remaining error, and do not create/update the PR.

Non-hook push failures (non-fast-forward, auth): rebase/merge or report. Do not treat them as hook errors.

### Step 5: Check for Existing PR

```bash
gh pr view --json url,state,body 2>/dev/null
```

- **If no PR exists** → go to Step 6 to create one.
- **If a PR exists and is OPEN** → do NOT just report the URL. The branch now has new work on it, so the description is stale. **Update the PR body** so it reflects the full current state of the branch, using the handoff template in Step 6:
  ```bash
  gh pr edit --body "$(cat <<'EOF'
  ...regenerated handoff body...
  EOF
  )"
  ```
  Fold the still-relevant parts of the existing body into the new one — don't discard context a human wrote. If the existing description is substantial and clearly hand-authored, ask before overwriting; otherwise regenerate and improve it.

### Step 6: Write the PR description (create or update)

The PR description is a **handoff document**, not a changelog. Write it so a reviewer who has never seen this work can read it and immediately know what the PR does, why, what to scrutinize, and how it was checked — enough to jumpstart their review without asking you anything.

**Gather the material.** Don't just diff the code — the intent and the decisions live in the *session*, not the diff:
```bash
git branch --show-current
git log origin/main..HEAD --oneline
git diff origin/main...HEAD --stat
```
Then draw on **this conversation**: the original ask, the decisions you (the AI) made, the alternatives you rejected, anything the user chose or corrected mid-way, and everything you verified. These are the parts a reviewer can't reconstruct from the diff.

**Check for linked GitHub issues:**
- Look at the branch name for issue numbers (e.g., `feat/42-user-dashboard` -> issue #42)
- Check commit messages for issue references
- If found, include `Closes #<number>` in the PR body so the issue auto-closes on merge

**Body template** (omit any section that doesn't apply; keep it tight):
```bash
gh pr create --title "[conventional-commit-style title]" --body "$(cat <<'EOF'
## What & why
[1–3 sentences: what this PR sets out to do and the problem or goal behind it. Lead with intent, not a file list.]

Closes #[issue-number]   <!-- only if an issue is linked -->

## Key decisions & tradeoffs
[The decisions made while building this — whether the AI made them or the user directed them. For each: what was chosen, why, and what was rejected. This is the highest-value section for a reviewer. Call out judgment calls, anything the user explicitly asked for, and anything they changed their mind on.]

## Notes for the reviewer
[Where to focus, the riskiest change, anything non-obvious, follow-ups deliberately left out of scope, and any open questions you want the reviewer to weigh in on.]

## Verification
Pre-push hook (format/sync, lint, typecheck, test, build) passed on push.
[Any extra manual or visual checks. Be explicit about what was NOT verified.]
EOF
)"
```

**What makes a good handoff body:**
- **Intent over inventory.** The diff already lists the changes; the description explains the goal and the reasoning. Don't restate filenames.
- **Surface every real decision** — especially judgment calls and anything the user directed or corrected. That context is exactly what a reviewer needs and can't get from the diff.
- **Be honest about gaps** — unverified paths, known limitations, deferred work. A reviewer who knows the edges reviews faster.
- **Keep it skimmable** — short prose and bullets, no filler.

### Step 7: Report Result

Report:
- Commit hash and message (including any hook-fix commits)
- Whether the push succeeded on the first try or after hook-fix loops (how many)
- If still blocked: the CI job, command, and remaining errors
- PR URL (new or existing), and whether its description was created or updated
- Issue link (if applicable)

## Error Handling

| Error | Action |
|-------|--------|
| On main/master branch | STOP, create feature branch first |
| Pre-push hook fails | Fix the reported job, commit, retry push (max 3). Never `--no-verify`. After 3, STOP and report. |
| Hook failure you cannot fix confidently | STOP and ask. Do not paper over. |
| Push fails (non-fast-forward) | Check if rebase/merge needed, report |
| PR creation fails | Check gh auth, report |

## GitHub PR Comment API Reference

When interacting with PR comments via the GitHub API (`gh api`):

### Get the correct repo name
Repo names are **case-sensitive**. Always resolve dynamically:
```bash
gh repo view --json nameWithOwner -q '.nameWithOwner'
```

### Fetch inline review comments
Use `pulls/{pr}/comments` — NOT `pulls/{pr}/reviews` (reviews endpoint returns the review body which is often empty):
```bash
gh api repos/{owner}/{repo}/pulls/{pr}/comments --jq '.[] | {id, line, body}'
```

### Reply to an inline comment
POST to the comments collection with `in_reply_to`. Do NOT use the `/replies` sub-endpoint (it doesn't exist for PR review comments and returns 404):
```bash
gh api repos/{owner}/{repo}/pulls/{pr}/comments \
  -X POST \
  -f body="Reply text" \
  -F in_reply_to=<parent_comment_id>
```
**Note:** Use `-F` (not `-f`) for `in_reply_to` — it must be sent as an integer, not a string.

### Submit a PR review with inline comments
The `--field 'comments=[...]'` syntax breaks with complex JSON (nested quotes, newlines, code blocks in comment bodies). **Always write the payload to a JSON file and use `--input`:**
```bash
cat > /tmp/pr_review.json << 'ENDJSON'
{
  "commit_id": "<head_sha>",
  "event": "COMMENT",
  "body": "Review summary here.",
  "comments": [
    {
      "path": "app/foo.py",
      "line": 42,
      "body": "Inline comment with `code` and **markdown**."
    }
  ]
}
ENDJSON
gh api repos/{owner}/{repo}/pulls/{pr}/reviews \
  -X POST \
  --input /tmp/pr_review.json
```
**Get the head SHA first:**
```bash
gh api repos/{owner}/{repo}/pulls/{pr} --jq '.head.sha'
```

## Quick Reference

```
/pr
  |-- git branch --show-current (MUST NOT be main/master)
  |-- [if main] git checkout -b <feature-branch>
  |-- git status
  |-- git add -A && git commit (if dirty)
  |-- git push -u origin HEAD (NEVER main, NEVER --no-verify)
  |-- [if pre-push fails] fix → commit → push again (max 3); never skip the hook
  |-- gh pr create (new) || gh pr edit --body (existing) -- write/refresh the handoff description
  |-- Report PR URL
```
