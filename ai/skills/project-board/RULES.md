# Project management rules — Future Mortgage CRM board

**This file is Martin's.** Edit it freely. `/project-board` reads it on every run, and these rules win over anything in `SKILL.md`.
When Martin says "from now on…" about issues, tickets, or the board, the rule goes **here** (not in memory or CLAUDE.md).

Seeded 2026-10-14 from how the board is actually used (Blake's issues #2382, #2387, #2391, #2392; epics #1100, #1112, #1125). Change anything that's wrong.

---

## Board

- **Future Mortgage CRM**: https://github.com/orgs/Future-Mortgage/projects/1
- Default repo `Future-Mortgage/monorepo`. Use `Verification-Service`, `shipyard`, or `fannie-mae-du` only when the code lives there.

## Every new issue gets these fields

| Field | Rule |
|-------|------|
| Status | `Todo`. Use `In Progress` only if work already started. |
| Priority | Required. Use the rubric below. |
| Area | Required. Pick one option. |
| Category | Required. `Bug` / `Feature` / `Tech Debt` / `Spike` / `Process`. |
| Owner | Set it when someone owns the work, and also assign their GitHub login (see People). Leave both empty if nobody owns it yet. |
| Sprint, Start/End Date | Leave empty unless Martin asks. Sprint has had no active iteration since Sprint 11 (Jul 2026). |

### Priority rubric

- **P0 - Critical**: prod down, data loss or corruption, security hole, or a blocked launch. Ping someone after posting.
- **P1 - High**: user-facing breakage or wrong data, or a committed feature for this cycle.
- **P2 - Medium**: real need, not urgent. This is the default when unsure.
- **P3 - Low**: nice to have, polish, or someday.

## People

| Owner option | GitHub login | Notes |
|--------------|--------------|-------|
| Martin | `mrodhansen` | |
| Marcus | `mdhenke` | |
| Ben | `801C07` | |
| Brandon | — | Not an org member. Set Owner only. |
| Mira | — | Not an org member. Set Owner only. |
| (Blake) | `FutureMortgage` | PM. Not an Owner option. Files most product issues. |

## Titles

- Plain English. Name the problem or the outcome, not the fix: "Funnel loan officer contact card shows placeholder phone (000) 000-0000".
- Optionally lead with the product surface when it helps scanning: "Income Calculator: wage earner income logic".
- Keep it under about 90 characters.
- Don't use conventional-commit prefixes (`bug(web-crm):`, `feat:`). Those belong on PRs.
- Epics: `Epic: <name>`.

## Body template (default)

```markdown
**Role:** <who hits this: Loan Officer / Borrower / Processor / Underwriter / Admin>

**Problem:** <what's wrong or missing today. Be concrete and give a real example when you have one. Number the items if there are several.>

**Success looks like:** <one sentence on the outcome, from the user's point of view>

**Acceptance criteria:**
- [ ] <observable and testable>
- [ ] <...>
```

Optional sections after the acceptance criteria, only when they add something:

- `## Technical notes`: root cause, files, related PRs/issues, migration or authZ concerns. Use this for engineering-filed issues.
- `## Out of scope`
- `## Source`: a link to the PRD, gist, Slack thread, or doc it came from.

Decision or question issues (e.g. #2375) can use `## Context` / `## Today` / `## Open question` instead, and should say what closes the issue ("If not, close this issue.").

## Writing

- Write Role, Problem, Success, and acceptance criteria so Blake or a loan officer can read them. Put jargon in Technical notes.
- Acceptance criteria are checks a tester can actually perform. Avoid "works correctly" and "is improved".
- **No borrower PII**: no names, SSNs, DOBs, account numbers, or real addresses. Staff names and business phones are fine.
- No secrets or credentials.

## Scope and structure

- Bundle related fixes on one screen or flow into one issue, as Blake does (#2382, #2391).
- Split into an **epic plus sub-issues** when the parts have different owners or ship separately. Label the epic `epic`, title it `Epic: …`, and link each child with `--parent`. The board auto-adds sub-issues, but still set their fields.
- **Search for duplicates first.** If one exists, comment on it or update it instead of filing a new issue.

## Labels

Labels are optional. Board fields are the source of truth for type, priority, and area.

- `epic` on epics.
- `prd-needed` or `design-needed` when work is blocked on scope or Figma.
- `integration` for third-party or vendor work.
- `launch-checklist` only for launch-tracking items.
- Never create a new label without asking.

## Posting

- "Draft …" means show the draft and stop.
- "Post / file / create / add to the board" means post, then reply with the link.
- When filing several issues at once, show the list of titles and fields first, then post them all after one OK.
