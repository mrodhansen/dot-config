---
name: project-board
description: Post and triage GitHub issues on the Future Mortgage CRM project board (github.com/orgs/Future-Mortgage/projects/1). Drafts the issue in the team format, checks for duplicates, creates it, adds it to the board, and sets Status / Priority / Area / Category / Owner and the parent epic. Follows Martin's project-management rules in RULES.md, which is also where new PM rules get saved. Use when the user runs /project-board, or says "post an issue", "file a ticket", "add this to the board", "create an issue for X", "make an epic with sub-issues", "set priority/owner on #1234", "add a PM rule", or asks how issues should be written for the board.
---

# /project-board — issues on the Future Mortgage CRM board

Board: https://github.com/orgs/Future-Mortgage/projects/1 (org project #1, "Future Mortgage CRM").

| File | Purpose |
|------|---------|
| `~/.ai/skills/project-board/RULES.md` | **Martin's PM rules.** Read it on every run. Its rules win over this file. |
| `~/.ai/skills/project-board/scripts/board.py` | Creates the issue, adds it to the board, sets fields, links the parent. Validates everything before writing. |

## Workflow

1. **Read `RULES.md`** in full, every run. Don't work from memory of it.
2. **Gather the facts** from the conversation, code, PR, or screenshot. Ask only for what you can't infer. Priority, Area, and Category are usually inferable with the rubric. Owner stays empty unless someone was named.
3. **Check for duplicates:**
   ```bash
   gh issue list -R Future-Mortgage/monorepo --state all --limit 10 --search "<2-4 key words>"
   ```
   If one exists, tell the user and offer to comment on it or update it instead.
4. **Draft** the title, the body (template in RULES.md), and the fields. Write the body to the scratchpad, e.g. `<scratchpad>/issue-<slug>.md`.
5. **Draft or post?** Follow the Posting rules in RULES.md. When showing a draft, show the title, the fields on one line, and the body.
6. **Post:**
   ```bash
   ~/.ai/skills/project-board/scripts/board.py post \
     --title "Funnel loan officer contact card shows placeholder phone (000) 000-0000" \
     --body-file <scratchpad>/issue-lo-phone.md \
     --status Todo --priority P1 --area Funnel --category Bug \
     --owner Marcus --assignee mdhenke
   ```
   Run it with `--dry-run` first if any field value is uncertain. That validates everything and writes nothing.
7. **Report** the issue link as `[#1234](url)` plus the fields that were set, on one line.

## Script reference

```bash
B=~/.ai/skills/project-board/scripts/board.py
$B fields                                   # live field names + options
$B post --title T --body-file F [flags]     # create + add to board + set fields
$B set  --issue REF [flags]                 # existing issue: add to board if missing, set fields
```

Flags for `post` and `set`: `--repo` (default `monorepo`), `--status`, `--priority`, `--area`, `--category`, `--owner`, `--start`/`--end` (YYYY-MM-DD), `--parent REF`, `--dry-run`. Only `post` takes `--assignee LOGIN` and `--label NAME`, and both are repeatable.

- `REF` = `1234` | `repo#1234` | full issue URL.
- Option values match case-insensitively, first exactly, then by unique prefix: `P1` → `P1 - High`, `infra` → `Infrastructure / DevOps`, `funnel` → `Funnel / Borrower`.
- Before any write, the script checks option names, labels (they must already exist in the repo), the parent issue, the title, and that the body isn't empty.
- On success it prints `issue=<url>`, `item=<id>`, one `set Field=Value` line per field, and `parent=<url>`.

### Epic + sub-issues

```bash
$B post --title "Epic: Pre-Approval Page" --body-file epic.md --label epic --status Todo --priority P1 --area CRM --category Feature
$B post --title "Pre-Approval: Settings template config" --body-file child1.md --parent 1128 --status Todo --priority P1 --area CRM --category Feature
```

### Edit fields or attach an existing issue

```bash
$B set --issue 2391 --priority P0 --owner Ben
$B set --issue shipyard#12 --status Todo --priority P2 --area infra --category "Tech Debt"   # adds to board if missing
$B set --issue 2384 --parent 2392
```

To edit the title, body, labels, or assignees of an existing issue, use `gh issue edit <n> -R Future-Mortgage/<repo> ...` directly.

## Board reference (snapshot 2026-10-14; `board.py fields` is live truth)

| Field | Options |
|-------|---------|
| Status | Todo · In Progress · In Review · Validate In Dev · Done |
| Priority | P0 - Critical · P1 - High · P2 - Medium · P3 - Low |
| Area | Voice / Twilio · Inbox · Genius AI · Income Calculator · CRM Features · Infrastructure / DevOps · Testing / E2E · Security · DX / Code Quality · Funnel / Borrower · Process |
| Category | Bug · Feature · Tech Debt · Spike · Process |
| Owner | Ben · Martin · Marcus · Brandon · Mira |
| Other | Sprint (14-day iteration, none active), Start Date, End Date |

- Views: Backlog (table), Sprints (board), View 3 (roadmap), Blake's Board.
- Automations: auto-add sub-issues, item closed → Done, PR merged, PR linked. Don't set `Done` by hand on an open issue; close it instead.
- The org has issue *types* (Task/Bug/Feature), but the board doesn't use them. Category is the board's type field.

## Adding or changing PM rules

When the user states a rule about how issues, tickets, priorities, owners, or the board should work, edit `RULES.md` in the right section. Keep the wording short and concrete, then tell them which line changed. Don't put PM rules in memory, CLAUDE.md, or this file.

## Fail hard

| stderr | Action |
|--------|--------|
| `OPTION_NOT_FOUND` | Pick from the listed valid options. If none fit (e.g. a new Area is needed), ask. Don't force a near miss. |
| `LABEL_NOT_FOUND` | Drop the label or ask the user. Never create labels silently. |
| `ISSUE_NOT_FOUND` / `BAD_ISSUE_REF` | Check the number and repo. |
| `HAS_OTHER_PARENT` | Tell the user. Only re-parent if they ask. |
| `PARTIAL: … was created` | The issue exists but board fields failed. Fix the cause and rerun the `set` command it printed. **Don't** post the issue again. |
| `GH_FAILED` with auth/scope errors | The token needs the `project` scope: `gh auth refresh -s project`. |
