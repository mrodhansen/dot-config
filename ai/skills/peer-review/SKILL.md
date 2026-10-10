---
name: peer-review
description: Builds a feature with a three-round peer review loop. The main agent plans and implements, then three FRESH review rounds run in sequence. Within each round, specialist agents (security, silent-failure/soft-types, recurring patterns, correctness/plan-fit, testing, dead-code/stale-comments, duplication/extract-to-shared, architecture sense-check) spawn in parallel with no prior-round context. After each round, the main agent merges actionable comments, triages every comment as accept / reject / defer with reasoning, then implements accepted changes before the next round. Architecture sense-check notes are advisory only (never trigger a redo mid-loop) and surface to the user only at the end if the agent has a clear concern. Use when user says "/peer-review <task>", "/peer-review <prd-file>", "/peer-review #42", or asks for a "reviewed" / "triple-reviewed" / "peer-reviewed" implementation.
allowed-tools: Read, Grep, Glob, Bash, Edit, Write, Task, TaskCreate, TaskUpdate, TaskList, WebFetch
permissionMode: acceptEdits
---

# /peer-review — Plan, Implement, Review x3, Triage

> **Prefer the workflow when possible.**  
> Run `/peer-review` as a **workflow** (`.grok/workflows/peer-review.rhai` or `~/.grok/workflows/peer-review.rhai`) instead of this skill when you want durable orchestration. The workflow keeps the same specialist concerns but is better in important ways:
>
> | Skill (this file) | Workflow |
> |-------------------|----------|
> | Implementer also triages findings (bias) | Fresh independent judge |
> | Findings accepted on trust | Adversarial verify, fail-closed (evidence required) |
> | Always 3 full rounds × 8 specialists | Default 2 rounds; early exit; round 2 is delta-only; arch once |
> | Free-form markdown, main-thread orchestration | Structured schemas, scratch artifacts, resumable `/workflows` UI |
> | ~24+ review agents fixed | Budget-aware caps (`MAX_VERIFY=12`, 6 findings/specialty) |
>
> **Workflow usage:**  
> `/workflow peer-review` with args  
> `{ "task": "<description | prd path | #issue>", "rounds": 1|2, "base": "main" }`  
> Or from the tool: `workflow(name: "peer-review", args: #{ task: "..." })`.  
> Watch progress in `/workflows`.
>
> Use **this skill** when you want the interactive main agent to plan/implement in-conversation (more chat control, less structure).

---

A development loop where a main agent produces a solution and three independent review **rounds** stress-test it in sequence. **Within each round, multiple specialist agents run in parallel** (one concern type each), so the round finishes much faster than a single mega-reviewer. Each round starts with a fresh set of agents (no prior-round context). The main agent merges specialist comments, triages every comment, and implements accepted changes before the next round begins. One specialist (architecture sense-check) is **advisory only**: it never asks the main agent to re-architect mid-loop; notes accumulate and surface to the user only at the end if there is a clear concern.

**Usage (skill / interactive):** `/peer-review <task-description | prd-file-path | github-issue>`

**Examples:**
- `/peer-review add rate limiting to the public API` — free-form task
- `/peer-review docs/prd/user-dashboard.md` — read a PRD file
- `/peer-review #42` — fetch GitHub issue #42 (uses repo of current working directory)
- `/peer-review https://github.com/org/repo/issues/42`

---

## Core Invariants

These rules MUST hold for every run. If you cannot satisfy them, stop and tell the user why.

1. **Three review rounds, in sequence.** Not two, not four. Round N+1 must not start until round N is fully triaged and accepted changes are implemented.
2. **Within each round, specialists run in parallel.** Spawn one agent per concern type **in a single tool-call batch**. Do not run security → silent-failure → testing as sequential main-agent work or sequential single agents.
3. **Reviewers see no prior rounds.** Every specialist prompt must include the plan and the current code state ONLY. It MUST NOT contain prior round comments, prior decisions, or any acknowledgement that earlier rounds happened.
4. **Specialists stay in their lane.** Each agent reviews only its concern type. Overlap is OK; the main agent deduplicates when merging.
5. **Every actionable comment is triaged.** The main agent decides per comment from actionable specialists (S1–S5, S7–S8): `accept` (implement now), `reject` (with reasoning), or `defer` (with reasoning + scope note). No actionable comment is silently ignored.
6. **Architecture sense-check (S6) is advisory only.** S6 never produces accept/reject/defer items and **must never** cause the main agent to re-architect or redo the feature mid-loop. Persist notes quietly; surface them to the user only in Phase 3, and only if S6 has a clear concern.
7. **Accepted changes are implemented before the next round.** The next round's specialists read the updated code. Earlier accepted feedback is reflected in the code itself, not in side text.
8. **All artifacts are persisted.** Plan, per-round comments, per-round decisions, architecture notes, and final summary all live in `.peer-review/` so the user can audit the whole loop.
9. **Never stall the loop on a missing reviewer.** A specialist that errors, times out, hangs, or never returns a usable review is a failure. Retry that specialty once, then continue. Do not sit idle waiting for a notification that may never come.

---

## Phase 0 — Resolve Input

The single argument can be one of three forms. Detect and dispatch:

1. **GitHub issue** — matches `^#?\d+$` or contains `github.com/.*/issues/\d+`:
   - For `#NNN` or bare `NNN`: detect the repo from `git remote get-url origin` in the CWD, then `gh issue view <NNN> --repo <owner>/<repo>`
   - For full URL: parse repo + issue number, then `gh issue view`
   - If a PRD path is referenced in the issue body, read it too
2. **File path** — argument exists as a file on disk (use `Read`):
   - Treat the file contents as the spec
3. **Free-form description** — anything else:
   - Treat the argument as the task description directly

If detection is ambiguous (e.g. a string that could be either a filename or a description), prefer the most concrete: check filesystem first, then issue pattern, then fall back to free-form.

Save the resolved spec to `.peer-review/spec.md` (verbatim for files/issues, or the user's free-form text as a one-paragraph spec for free-form inputs).

---

## Phase 1 — Plan and Implement

The MAIN agent (you, in this conversation) does this phase directly. Do not delegate the plan.

1. **Create the plan.** Write a concrete plan to `.peer-review/plan.md`. The plan must include:
   - **Goal** — one paragraph restating the task in your own words
   - **Approach** — the design / architecture choice and the main tradeoff you're accepting
   - **Files to create or modify** — explicit list of paths
   - **Consumer / dual-path map** — for every new or moved field/abstraction, list who must read or honor it (API schema, DB, list/read UI, exporters/transformers for **each** pipeline, importers, jobs). Mark any intentionally deferred consumer under Out of scope.
   - **Invariants & concurrency** — what must be unique / atomic; whether a DB constraint or transaction enforces it
   - **AuthZ** — who can call new procedures and which existing gate (role/assignment/tenant helper) is reused
   - **Failure modes** — what hard-fails vs user-visible degradation; no silent ACTIVE/success on failed setup
   - **Out of scope** — what you are deliberately NOT doing, so reviewers don't churn on it
   - **Open questions** — anything you're uncertain about (reviewers can weigh in)
2. **Track tasks.** Use `TaskCreate` to enumerate the implementation steps from the plan. Update them as you go.
3. **Implement.** Write the code. Use specialized agents (`backend-architect`, `frontend-developer`, etc.) via the `Task` tool when the work clearly fits their domain — otherwise do it yourself. Verify it builds / type-checks before declaring Phase 1 complete.
   - While implementing, self-check the recurring patterns (soft success, write-only wiring, races, thin authZ, mount wipes, dual-path drift, envelope casts, tests that assert failure paths) so round 1 does not rediscover basics.
4. **Snapshot files changed.** Write the list of created/modified paths to `.peer-review/files-touched.md` — one path per line. This is the file set the specialists will examine.

Do not announce "ready for review" to the user. Move directly into Phase 2.

---

## Phase 2 — Three Sequential Rounds (Parallel Specialists Inside Each Round)

Loop the following EXACTLY three times. Variable `N` is the round number (1, 2, 3).

```
Round N:
  2.N.a  Spawn ALL specialists in parallel (one agent per concern)
  2.N.b  Wait for all specialists; merge S1–S5 + S7–S8 into round-N-comments.md; stash S6 notes only
  2.N.c  Triage every actionable comment → round-N-decisions.md (S6 is never triaged)
  2.N.d  Implement accepted changes
  2.N.e  Update files-touched.md
```

### 2.N.a — Spawn parallel specialist agents

Spawn **eight** independent agents in **one tool-call batch** (same turn). Use the platform's multi-agent tool (`Task` / `spawn_subagent` / equivalent).

| Specialist ID | Concern | subagent_type | description | Actionable? |
|---------------|---------|---------------|-------------|-------------|
| **S1** | Correctness / plan-fit / edge cases | `general-purpose` | `Peer R{N}: correctness` | Yes — triage |
| **S2** | Security / authZ / secrets | `backend-architect` (fallback: `general-purpose`) | `Peer R{N}: security` | Yes — triage |
| **S3** | Silent failure / soft types | `general-purpose` | `Peer R{N}: silent fail` | Yes — triage |
| **S4** | Recurring PR patterns R1–R10 | `general-purpose` | `Peer R{N}: recurring` | Yes — triage |
| **S5** | Testing gaps | `test-writer-fixer` (fallback: `general-purpose`) | `Peer R{N}: testing` | Yes — triage |
| **S6** | Architecture sense-check | `general-purpose` (or `plan` if available) | `Peer R{N}: arch sense` | **No** — advisory notes only |
| **S7** | Dead code / unused / stale comments | `general-purpose` | `Peer R{N}: dead code` | Yes — triage |
| **S8** | Duplication / extract-to-shared | `general-purpose` | `Peer R{N}: duplication` | Yes — triage |

Prefer `capability_mode: read-only` (or equivalent) so specialists cannot edit code.

**Do not** spawn one mega-reviewer. **Do not** wait for S1 before launching S2–S8.
**Do not** treat S6 output as work for the main agent. Never re-architect or rewrite the feature because of S6 during the loop.

---

### Shared prefix for every specialist (round N)

Interpolate plan + files. Never include prior-round artifacts.

```
You are an independent specialist code reviewer for ONE concern only (stated below).
You have no prior context about this work — review what you see, not what you assume.
You do not know about other specialists or other review rounds.

## The plan

The implementing engineer wrote this plan before coding:

---
{contents of .peer-review/plan.md}
---

## Files implemented

These files were created or modified for this work:

{contents of .peer-review/files-touched.md}

## Shared rules (all specialists)

1. Read the plan carefully. Note what is explicitly OUT OF SCOPE — do not raise comments about those.
2. Read every file in the list above using the Read tool. Read the full file, not just changed regions.
3. Stay in your specialty. Skip issues owned by other specialists unless they are inseparable from your finding.
4. Do not modify any code. Review only.
5. Do not read `.peer-review/round-*` files. Your review must be independent.
6. Be specific. "Add error handling" is useless; cite file:line and a concrete change.
7. If you have nothing substantive for your specialty, return an empty Comments section with Summary: "clean for this specialty" — do not pad.
8. Severity: blocker | major | minor | nit

## Comment format (each specialist uses local IDs S1, S2, ... within their own output)

Write findings ONLY (no need to write a full markdown file — return structured markdown in your final message):

```markdown
# Specialist: <SPECIALTY_NAME> (round N)

## Summary
One paragraph: overall impression for THIS specialty only.

## Comments

### S1 — <short title>
- **Severity**: blocker | major | minor | nit
- **File**: path/to/file.ts:LINE (or "general")
- **Observation**: what you see
- **Why it matters**: concrete consequence
- **Suggested change**: specific change, not a vague direction

### S2 — ...
```

This is round: N
Your specialty: <SPECIALTY_NAME>
```

---

### S1 — Correctness / plan-fit / edge cases

Append to shared prefix:

```
## Your specialty: Correctness / plan-fit / edge cases

Review ONLY for:
- Mismatches between the plan and the implementation
- Logic bugs, edge cases, off-by-one, null derefs, race/async ordering
- Incomplete error handling that is pure correctness (not the soft-fail catalog)
- Maintainability issues that meaningfully hurt this change
- Missing cleanup, wrong status codes, copy-paste bugs

Do NOT deep-dive: injection/auth catalogs, silent-fallback catalogs, R1–R10 checklists, unused-import/dead-symbol cleanup, extract-to-shared DRY, or test-suite design (other specialists).
```

---

### S2 — Security / authZ / secrets

Append to shared prefix:

```
## Your specialty: Security / authZ / secrets

Review ONLY for:
- Injection (SQL/NoSQL/command/XSS/template)
- Missing or weak auth checks; broken access control
- Thin tenant checks without assignment/role gates used elsewhere
- Over-broad procedures (PENDING/onboarding performing privileged side effects)
- Identity vs capability conflation
- Auth that fails open (`catch { return true }`)
- Secrets/PII in logs or responses; env names in user-facing errors
- Cross-tenant leakage; missing input validation on new endpoints
- Crypto/session/JWT issues

Do NOT deep-dive: performance, silent-fallback type hardening (except fail-open auth), test coverage, or plan-fit nits.
```

---

### S3 — Silent failure / soft types

Append to shared prefix:

```
## Your specialty: "Just make it work" / silent-failure / soft types

Prefer hard failures with clear errors over continuing in a wrong state — unless the fallback
is intentional, documented, user-visible graceful degradation.

**Root cause of many fallbacks: soft types.** Prefer a hard, exact type + validation boundary —
never `any` / type-erasure.

### Silent / swallowed failures
- Empty catch, or catch that only logs and continues as success
- `.catch(() => undefined|null|[]|{})`
- try/catch returning default "success" on failure
- Fire-and-forget async where failure should affect the caller

### Fallbacks that should hard-fail
- Critical config/env defaults that hide misconfiguration
- Empty arrays/objects/`null` when required data is missing
- `|| []`, `?? []`, `?? {}`, `?? ''` papering over unexpected null/undefined
- Long optional chains on required paths
- Production mock/stale/placeholder fallbacks without product requirement
- Parse failures converted to silent defaults
- Retry that "succeeds" with partial/empty data

### Soft types that force soft fails
For every fallback you flag:
1. Trace the type of the value being defaulted
2. Name the **exact** expected hard type (field-by-field if needed)
3. Prefer fixing the type so the fallback is unnecessary
4. Never suggest `any`, `as any`, double casts, blanket `!`, or `@ts-ignore` as the fix

Flag: optional fields that should be required, `Partial<T>` for loaded entities, unvalidated JSON
deep in domain, empty success when absence is error, optional params only to make call sites compile,
DB selects omitting fields that code then defaults.

### Type papering & soft-fail behavior
- `as any` / double casts / non-null `!` to silence the compiler
- Partial success as full success; validation that warns and continues
- Auth fail-open (also report — security specialist may overlap; still flag)

For each finding include:
1. What happens on failure today
2. What should happen instead
3. Soft-type root cause? → exact hard type + boundary
4. Concrete fix (not more defaults, not `any`)

Severity: auth fails-open and data-loss soft-fails = blocker/major; config/required-data silent defaults
and soft-type fallback cascades = major; suggesting `any` = major; non-critical swallows = minor.
```

---

### S4 — Recurring PR patterns (R1–R10)

Append to shared prefix:

```
## Your specialty: Recurring PR failure patterns (R1–R10)

Walk this checklist against the touched files. Flag hits with blocker/major when they can cause
data loss, wrong money/credit/AUS/messaging behavior, cross-tenant issues, or "looks healthy while broken."
For R2/R6, read consumers outside the touched list when needed.

### R1 — Soft failure that looks like success
- Catch/log-and-continue while status claims ACTIVE / ready / success
- Empty fallbacks on **required** export/vendor payloads instead of preflight throw
- Setup failures swallowed so feature looks live
- Tests skip/pass when fixtures missing
- Polling-only UIs with no recovery if webhooks never land

### R2 — Incomplete end-to-end wiring (write-only)
UI → API/schema → DB → read/list → export transformers (each pipeline) → import → jobs → shared sites
- Partial shared-component adoption; clear/reset without live side-effect update; deleted write path without re-home
If deferred, plan must say so; else blocker/major.

### R3 — App-only invariants and races
- Uniqueness only in app code; check-then-act without atomicity; counter without unique+retry
- Tenant-scoped unique on globally unique vendor resource; multi-step writes missing transaction

### R4 — Thin authZ / tenant / secret boundaries
- Weaker gates than siblings; over-broad callers; identity mixed with capability filters
- Env names in user errors; PII/secrets logged; dual-pipeline redaction gaps

### R5 — Form hydration / mount wipes
- useEffect mount write without hydration sentinel; auto-flip nulling persisted enums/booleans
- Partial updates nulling omitted fields

### R6 — Dual-path inconsistency
- Parallel transformers with different predicates; CRM vs funnel / admin vs LO rule drift
- Dual schemas; sticky columns vs live derivation; actor identity changes across steps

### R7 — Envelopes / partial updates / type lies
- Casts to guessed shapes vs real envelopes; omitted fields set to null; `as any` to compile

### R8 — Tests that do not protect the change
- No unit test on new branches/guards; happy-path-only fixtures; no-op when inputs absent
- Prefer a test that would fail if silent-success or write-only bug returned
(Overlap with testing specialist is OK — focus on "does this test protect the failure mode?")

### R9 — UX recovery and edge states
- Missing loading/error/cancel/retry/stale handling; double-submit; broken image fallback
- Eager per-row work without cleanup/virtualization

### R10 — Consistency with codebase patterns
- Reinventing existing helpers; arbitrary design tokens/z-index; incomplete a11y for tab-like UI

In **Why it matters**, name the production failure mode. In **Suggested change**, prefer DB constraints,
existing auth helpers, hard preflight throws, full consumer wiring, tests that pin the failure path —
not more `??` defaults.
```

---

### S5 — Testing gaps

Append to shared prefix:

```
## Your specialty: Testing gaps

Review ONLY for missing or weak tests. Do not redesign product logic except to say what assertion would catch a bug.

- New branches/logic without unit tests (especially refusal/guard/migration/backfill)
- Modified behavior without updated tests
- Fixtures hardcoding happy path so assertions always pass
- Tests that no-op green when fixtures/reference files are missing
- Missing tests that assert **failure** paths
- Behavior/UI contract changes without e2e/integration updates
- Prefer at least one test that would **fail** if a silent-success or write-only bug returned

For each comment: where the test should live, what to assert, and what bug it would catch.
```

---

### S7 — Dead code / unused / stale comments

Append to shared prefix:

```
## Your specialty: Dead code / unused / stale comments

Remove refactor leftovers. Prove unused with grep/read — do not guess.

### Unused imports & symbols
- Unused imports (named/default/type-only/unneeded side-effect)
- Unused locals, params, private helpers, types, constants
- Exports/re-exports with no in-repo consumers (unless intentional public package API)
- Dead/unreachable branches after condition changes
- Assigned-never-read variables; leftover feature-flag/env reads

### Stale / useless comments (prefer delete)
- Comments narrating removed behavior: "used to", "previously", "was", "no longer", "removed X", "old path"
- Large commented-out code blocks; JSDoc that contradicts current signatures
- TODOs/FIXMEs already done or pointing at deleted code
- Leftover section banners for deleted code
- Obvious narrating comments added/left by this change that add no non-obvious intent

### Do NOT flag
- Symbols used via types/decorators/DI/framework reflection
- WHY/invariant/security comments that still apply
- WIP blocks with an active tracking TODO + issue
- Broad cleanups outside this change's blast radius

Severity: unused import = nit; dead private helper / misleading stale comment = minor/major;
stale comment that contradicts auth/security behavior = major/blocker.
For each: proof of zero refs (or quote the stale comment) + exact delete.
```

---

### S8 — Duplication / extract-to-shared

Append to shared prefix:

```
## Your specialty: Duplication / extract-to-shared

Flag repeated logic only when ALL hold:
1. **≥ 3 real occurrences** after this change (in touched files and/or existing codebase)
2. **Would realistically be used more** (sibling features, list+detail+export, dual pipelines, repeated fields)
3. **Stable enough to name** — not coincidental similar shape with different invariants
4. **Extraction reduces drift risk** — not a premature flag-soup helper

### Scope of the shared home (required on every finding)
Pick from usage count + where copies live:
| Fan-out | Scope |
|---------|--------|
| 3+ in one file | Private helper in that file |
| 3+ in one feature/module | Module `utils` / `helpers` beside the feature |
| 3+ across one app | App-level shared module already used for similar things |
| 3+ across apps / FE+BE domain rule | Existing monorepo `libs/` domain package |
| Near-match to existing helper | Extend/reuse that helper — no parallel utility |

Always include: occurrence count, file:line list, proposed symbol + path, params vs identical core.
Search the repo — do not only look inside the touched list.

### Do NOT flag
- Only 2 weak lookalikes; intentional test-fixture duplication; trivial one-liners
- Similar control flow with different business meaning
- Huge unrelated DRY refactors disproportionate to this change

Severity: easy local 3-copy helper = minor/nit; drifting copies or dual-path same domain rule = major;
reinvented existing helper = major.
Suggested change must be a concrete signature + home path — not "consider DRY".
```

---

### S6 — Architecture sense-check (advisory only)

Append to shared prefix. **Override** the shared comment format: S6 does **not** emit C#/S# triage items.

```
## Your specialty: Architecture sense-check (advisory)

Your job is to answer one question:

> "Does the way this is implemented actually make sense as it is now?"

Look at:
1. The plan's stated approach and tradeoffs
2. The implemented files end-to-end
3. Surrounding codebase patterns (read related modules, existing helpers, how similar features are done)

Ask yourself: given this codebase and the problem being solved, is the architecture a reasonable fit?
Could a competent engineer reading this in six months understand why it was built this way?

### Stance — default to "fine"

- You are **not** quick to demand a re-architecture. Most working designs that fit local patterns are fine.
- Only speak up when there is a **very clear** more proper way that fits this codebase better, or when the current approach is **clearly poor** (wrong layer, fights existing abstractions, invents a parallel system for something already solved, will force painful follow-ups).
- Style preferences, micro-optimizations, and "I would have named it differently" are NOT findings.
- Preferable-but-not-clearly-better alternatives are NOT findings. Silence is the correct output when the design is acceptable.

### What you may conclude

| Verdict | When | What you write |
|---------|------|----------------|
| **fine** | Design is reasonable for this codebase | Empty note: `Verdict: fine` only — no explanation needed |
| **clear-better-path** | A clearly better architecture exists that fits the grand change and surrounding code | Short note: current approach, why a better path is obvious, what that path is |
| **poor-fit** | Current approach is a poor fit (wrong layer, fights patterns, invents parallel systems) | Short note: what is poor, why, and the coherent alternative |

### Critical constraints

- **Never** tell the implementing agent to redo or re-architect the work.
- **Never** emit Severity / Suggested change / C# comments for triage.
- Your output is a **user-facing advisory note** collected until the end of the peer-review loop.
- Keep notes short (half page max). If fine, keep it to one line.

### Output format (return this only) — do not use Severity / C# items

# Specialist: Architecture sense-check (round N)

## Verdict
fine | clear-better-path | poor-fit

## Note
(Omit entirely when Verdict is fine.)
When not fine: 2–6 sentences.
- What was built and why it was shaped this way (as far as you can tell)
- Why that shape is a poor fit OR why a better path is clearly preferable
- The alternative that makes more sense in this codebase (concrete, not vague)
- Do NOT instruct anyone to rewrite now
```

---

### 2.N.b — Merge specialist outputs into one comments file

Wait until **all eight** specialists finish (or one retry each if a specialist failed).

#### Actionable specialists (S1–S5, S7–S8)

Write `.peer-review/round-N-comments.md` by merging **S1–S5, S7–S8 only**:

1. Start with a round header and a short overall summary (1–3 sentences) synthesized by the main agent.
2. Renumber all specialist comments globally as **C1, C2, C3, ...** (stable order: S1, S2, S3, S4, S5, S7, S8).
3. On each comment, preserve Severity / File / Observation / Why it matters / Suggested change.
4. Add a line: `- **Specialty**: Correctness | Security | SilentFailure | RecurringPattern | Testing | DeadCode | Duplication`
5. Deduplicate near-identical findings from two specialists: keep one comment, note both specialties, keep the stronger severity and the more specific fix.
6. If a specialist returned clean, note under a "Clean specialists" line — do not invent padding comments.
7. **Do not** put S6 content into this file as triageable comments.

Exact format:

```markdown
# Review round N

## Summary
One paragraph: overall impression and the single most important thing the engineer should address.
Specialists run: Correctness, Security, SilentFailure, RecurringPattern, Testing, DeadCode, Duplication, ArchitectureSense (advisory).

## Comments

### C1 — <short title>
- **Specialty**: Security
- **Severity**: blocker | major | minor | nit
- **File**: path/to/file.ts:LINE (or "general")
- **Observation**: ...
- **Why it matters**: ...
- **Suggested change**: ...

### C2 — ...

## Clean specialists
- Testing: no findings

## Architecture sense-check (advisory — not triaged)
- Round N verdict: fine | clear-better-path | poor-fit
- (Full note lives in round-N-architecture-note.md; do not implement from this)
```

#### Architecture specialist (S6) — stash only

Write `.peer-review/round-N-architecture-note.md` with S6's raw output (or `Verdict: fine` if clean/empty).

**Main agent rules for S6:**
- Do **not** triage S6.
- Do **not** implement, re-architect, or open follow-up work because of S6 during the loop.
- Do **not** stream S6 notes to the user mid-loop.
- After all three rounds, keep the **strongest** non-fine verdict across rounds (poor-fit > clear-better-path > fine). If all rounds said fine, the final summary omits architecture entirely.

If a specialist agent produces no usable output: re-spawn **that specialty only** once. If an actionable specialist (S1–S5, S7–S8) fails twice, add a single comment `C? — reviewer-failed (<specialty>)` with severity `major` and continue. If S6 fails twice, write `Verdict: fine` with a one-line note that the architecture specialist failed, and continue (do not block the loop).

---

### 2.N.c — Triage every comment (actionable only)

Read `.peer-review/round-N-comments.md`. For each comment C1, C2, ..., decide.
**Skip S6 entirely** — architecture notes are never accept / reject / defer.

- **accept** — the comment is correct and you will implement the suggested change now
- **reject** — the comment is wrong, already handled elsewhere, or based on a misreading; you must explain why
- **defer** — the comment is reasonable but out of scope for this work; you must explain why and note where it should be tracked (a follow-up issue, a TODO, etc.)

Write decisions to `.peer-review/round-N-decisions.md` in this format:

```markdown
# Round N decisions

## C1 — <title from comment>
- **Decision**: accept | reject | defer
- **Reasoning**: 1-3 sentences. For reject/defer this is mandatory.
- **Implementation note**: (only if accepted) the specific edit you will make

## C2 — ...
```

**Severity is informational, not binding.** A `nit` may be worth accepting if cheap; a `blocker` may be worth rejecting if the reviewer misunderstood. Use judgment.

---

### 2.N.d — Implement accepted changes

Apply every `accept` decision before the next round begins. Use `Edit` / `Write` / specialist Task agents as appropriate. Verify the code still builds / type-checks.

**When the accepted fix is about a soft-fail / fallback / soft type:**
1. Determine the **exact** expected type (domain, API contract, DB schema, caller guarantees) — field-level precision.
2. Introduce or tighten that hard type; validate/narrow once at the appropriate boundary.
3. Remove the silent fallback / empty default / type-papering that prompted the comment.
4. **Do not** "fix" with `any`, `as any`, `as unknown as T`, blanket `!`, or by making more fields optional. If the compiler complains, the call sites or boundary validation are wrong — fix those.

If applying an accepted change reveals it was wrong (test now fails, type error you didn't anticipate), update the decision file: change it from `accept` to `reject` and document what you learned. Do not silently drop it. A type error after removing a fallback is often a signal to harden more call sites, not to revert to soft types.

---

### 2.N.e — Update files-touched

If implementing accepted changes added new files, append them to `.peer-review/files-touched.md` so round N+1 sees the full surface area.

---

## Phase 3 — Final Summary

After round 3 is fully triaged and implemented, write `.peer-review/summary.md`:

```markdown
# Peer review summary

**Spec source**: <path / issue # / "free-form">
**Files created**: <count>
**Files modified**: <count>
**Review model**: 3 sequential rounds × 8 parallel specialists (Correctness, Security, SilentFailure, RecurringPattern, Testing, DeadCode, Duplication, ArchitectureSense-advisory)

## What was built

<2-4 sentences describing the final implementation>

## Review rounds

### Round 1
- Specialists: 8 parallel (7 actionable + architecture advisory)
- Comments raised: <N> (after merge/dedupe; actionable only)
- Accepted: <N> | Rejected: <N> | Deferred: <N>
- Architecture sense-check: fine | clear-better-path | poor-fit
- Notable changes from this round: <bullets>

### Round 2
(same structure)

### Round 3
(same structure)

## Deferred items

<list every deferred comment across all rounds with a one-line note on where it should be tracked>

## Architecture sense-check (user advisory)

<!-- ONLY include this section if the strongest verdict across rounds is NOT fine.
     If all rounds said fine: OMIT this entire section — say nothing about architecture. -->

**Verdict**: clear-better-path | poor-fit

<Synthesize the strongest non-fine note(s) from round-*-architecture-note.md into a short
user-facing paragraph. Do not re-implement. Do not present this as work the agent will do.
Frame as: "For your consideration — the architecture sense-check thought…" >

## Open risks

<anything the reviewers didn't catch but you noticed during the loop, or known limitations>
```

Then output a short message to the user pointing them at `.peer-review/summary.md` and listing the deferred items inline so they don't have to open the file to see what's left.

**Architecture note in the user message:**
- If strongest S6 verdict across all rounds is `fine` → **say nothing** about architecture.
- If `clear-better-path` or `poor-fit` → include a short final paragraph so the user sees what the sense-check thinks. Do not offer to rewrite unless the user asks.

---

## Output Discipline

- Do not stream every specialist comment to the user as it arrives — the files are the record. Give the user a one-line status per phase ("plan + implementation done", "round 1: 8 specialists done, 4 comments — 2 accepted, 1 rejected, 1 deferred", etc.). Do not surface architecture notes mid-loop.
- Do not ask the user for approval between rounds. The loop is autonomous by design.
- If the user interrupts mid-loop, the state in `.peer-review/` is enough to resume — say so.
- If a specialist batch is incomplete, merge what you have and proceed. Never leave the user waiting on a hung reviewer.
- Never rewrite or re-architect the feature because of S6. Architecture sense-check is for the user's judgment at the end only.

---

## Error Recovery

- **Spawn specialists as one foreground parallel batch** so the batch returns together. Do **not** background them and wait for a later notify. Background + “do not poll” is how this loop stalls.
- **One specialist fails** (error, empty output, capacity/timeout, or never returns): retry **that specialty only**, once, immediately. If the retry also fails or does not return a usable review, log `reviewer-failed (<specialty>)` as a `major` comment and **continue the round with whoever finished**.
- **Silent / hung specialist**: treat as a failure. Do not poll. Do not wait. A missing result after the batch (or after the one retry) is enough to mark `reviewer-failed`.
- **All specialists fail**: stop the loop and tell the user; do not invent comments.
- **Accepted change breaks the build**: revert that specific change, flip the decision to `reject` with reasoning `"applying this broke <X>"`, continue.
- **Specialists contradict each other**: both comments appear after merge (or dedupe if identical). Triage on merits independently.
- **Reviewer suggests a contradicting change to one already accepted in a prior round**: allowed and expected — rounds are fresh. Triage on merits; if you reject, note that round M's accepted change was deliberate.

---

## Checklist Before Marking Complete

- [ ] `.peer-review/plan.md` exists (includes consumer map, invariants, authZ, failure modes)
- [ ] `.peer-review/files-touched.md` exists and lists every changed file
- [ ] `.peer-review/round-1-comments.md`, `round-2-comments.md`, `round-3-comments.md` exist
- [ ] Each round spawned **eight parallel specialists** (Correctness, Security, SilentFailure, RecurringPattern, Testing, DeadCode, Duplication, ArchitectureSense) — not one mega-reviewer
- [ ] Each round's merged comments cover silent-failure, recurring patterns, dead-code, and duplication (via S3, S4, S7, S8)
- [ ] S6 notes written to `round-N-architecture-note.md` and **never** triaged as accept/reject/defer
- [ ] Main agent did **not** re-architect or redo work because of S6 during the loop
- [ ] `.peer-review/round-1-decisions.md`, `round-2-decisions.md`, `round-3-decisions.md` exist
- [ ] Every actionable comment (S1–S5, S7–S8) in every round has a corresponding decision
- [ ] All `accept` decisions are reflected in the code
- [ ] `.peer-review/summary.md` exists
- [ ] Architecture section in summary + user message only appears when strongest S6 verdict is not fine
- [ ] Code builds / type-checks
- [ ] User received a short status message with a pointer to the summary

If any item is unchecked, the loop is not done.
