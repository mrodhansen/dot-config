# gh-stack cheatsheet (for /implement-as-stack)

Install: `gh extension install github/gh-stack`

Docs: https://github.github.com/gh-stack/  
About: https://docs.github.com/en/pull-requests/get-started/about-stacked-prs

## Happy path

```bash
gh stack init --base main feat/foo-schema
# ... commit layer 1 ...
gh stack add feat/foo-api
# ... commit layer 2 ...
gh stack add feat/foo-ui
# ... commit layer 3 ...
gh stack submit --auto --open
```

## Essential commands

| Command | Purpose |
|---------|---------|
| `gh stack init [--base B] [branches...]` | Start local stack; adopt/create branches bottom→top |
| `gh stack add <branch>` | New empty branch on top of current stack tip |
| `gh stack submit --auto --open` | Push, create/update PRs, create GitHub Stack |
| `gh stack link [--open] b1 b2 b3` | Stack without local tracking (or after manual branches) |
| `gh stack push` | Force-with-lease push active stack branches |
| `gh stack rebase` | Cascading rebase onto trunk/parents |
| `gh stack sync` | Fetch + rebase + push + sync PR/stack state |
| `gh stack view [--json]` | Show stack |
| `gh stack unstack` | Dissolve stack (local+remote tracking) |
| `gh stack up` / `down` / `top` / `bottom` / `trunk` | Navigate |

## Agent notes

- Prefer `--auto` on `submit` in non-interactive agent shells.
- Use `--open` when PRs should be ready for review (default with `--auto` alone is drafts).
- Exit code **9** = stacked PRs not enabled for the repository.
- Server-side UI “Rebase Stack” force-pushes **unsigned** commits; local `gh stack rebase` respects local signing.
- Cross-fork stacks are not supported; all branches same repo.
- Merge is bottom-up; merging mid PR lands it **and everything below**.

## Manual chain (no local tracking)

```bash
# branches already exist bottom→top with correct parent commits
gh stack link --open feat/foo-schema feat/foo-api feat/foo-ui
```
