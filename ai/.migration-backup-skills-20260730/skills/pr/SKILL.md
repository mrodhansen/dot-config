---
name: pr
description: Automates the full PR workflow - runs all typechecks, formats code, creates a commit with a descriptive message, pushes to remote, and creates a PR if one doesn't exist. Use when user says "/pr", "create pr", "ship it", or "prepare pr".
---

# /pr - Automated PR Workflow

Automates the complete pull request workflow in a single command.

## CRITICAL SAFETY RULE

**NEVER push directly to main or master. ALWAYS create a feature branch first.**

This is non-negotiable. If on main/master, you MUST create a new branch before proceeding.

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
- If there are changes, proceed to typecheck

### Step 3: Run All Typechecks

Detect the project type and run appropriate typecheck:

**For NX monorepos:**
```bash
npx nx run-many --target=typecheck --all
```

**For standard TypeScript projects:**
```bash
npx tsc --noEmit
```

**For projects with a typecheck script:**
```bash
npm run typecheck
# or
yarn typecheck
```

**If typecheck fails:** Stop and report the errors. Do NOT proceed.

### Step 4: Format Code

Detect and run the appropriate formatter:

**For NX monorepos:**
```bash
npx nx format:write
```

**For projects with Prettier:**
```bash
npx prettier --write .
```

**For projects with a format script:**
```bash
npm run format
# or
yarn format
```

### Step 5: Check for Changes After Formatting

```bash
git status
```

If there are changes (from formatting), they need to be committed.

### Step 6: Stage and Commit

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

Always include the co-author tag:
```
Co-Authored-By: Claude <noreply@anthropic.com>
```

### Step 7: Push to Remote (NEVER TO MAIN)

**First, verify you are NOT on main/master:**
```bash
git branch --show-current
```

If on main or master, STOP and go back to Step 1.

**Push the feature branch:**
```bash
git push -u origin HEAD
```

### Step 8: Check for Existing PR

```bash
gh pr view --json url,state,body 2>/dev/null
```

- **If no PR exists** → go to Step 9 to create one.
- **If a PR exists and is OPEN** → do NOT just report the URL. The branch now has new work on it, so the description is stale. **Update the PR body** so it reflects the full current state of the branch, using the handoff template in Step 9:
  ```bash
  gh pr edit --body "$(cat <<'EOF'
  ...regenerated handoff body...
  EOF
  )"
  ```
  Fold the still-relevant parts of the existing body into the new one — don't discard context a human wrote. If the existing description is substantial and clearly hand-authored, ask before overwriting; otherwise regenerate and improve it.

### Step 9: Write the PR description (create or update)

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
[How it was checked — typecheck / tests / build, plus any manual or visual verification. Be explicit about what was NOT verified.]
EOF
)"
```

**What makes a good handoff body:**
- **Intent over inventory.** The diff already lists the changes; the description explains the goal and the reasoning. Don't restate filenames.
- **Surface every real decision** — especially judgment calls and anything the user directed or corrected. That context is exactly what a reviewer needs and can't get from the diff.
- **Be honest about gaps** — unverified paths, known limitations, deferred work. A reviewer who knows the edges reviews faster.
- **Keep it skimmable** — short prose and bullets, no filler.

### Step 10: Report Result

Report:
- Whether typecheck passed
- Whether formatting was applied
- Commit hash and message
- PR URL (new or existing), and whether its description was created or updated
- Issue link (if applicable)

## Error Handling

| Error | Action |
|-------|--------|
| On main/master branch | STOP, create feature branch first |
| Typecheck fails | Stop, report errors, suggest fixes |
| Format fails | Stop, report error |
| Push fails | Check if rebase needed, report |
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
  |-- typecheck (tsc/nx/project-specific)
  |-- format (prettier/nx/project-specific)
  |-- git add -A && git commit
  |-- git push -u origin HEAD (NEVER main)
  |-- gh pr create (new) || gh pr edit --body (existing) -- write/refresh the handoff description
  |-- Report PR URL
```
