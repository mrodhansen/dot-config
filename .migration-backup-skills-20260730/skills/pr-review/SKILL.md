---
name: pr-review
description: Deep code review agent that analyzes all diffs on the current branch for performance bottlenecks, security vulnerabilities, code quality issues, "just make it work" silent-failure patterns (swallowed errors, bad fallbacks that should hard-fail — often rooted in soft types; fix by hardening exact types, never with any), incomplete end-to-end wiring (write-only fields, missed dual-path consumers), app-only invariants/races, thin authZ/tenant gates, form hydration wipes, wrong response envelopes, tests that no-op green, dead/unused code and stale leftover comments, and repeated logic that should be shared (3+ real uses). Includes a conservative architecture sense-check that only speaks at the end if the approach is clearly poor or a clearly better path exists in this codebase (silence when fine; never blocks merge). Optionally validates changes against a PRD to ensure implementation correctness and completeness. Spawns one specialist agent per review concern in parallel for speed. Use when user says "/pr-review", "/pr-review <prd-file>", "review my code", "review this branch", or "check my changes".
---

# /pr-review - Deep Code Review Agent

Performs a comprehensive, multi-pass review of all changes on the current branch. Hunts for performance bottlenecks, security vulnerabilities, race conditions, code quality issues, and "just make it work" patterns — silent fallbacks, swallowed errors, and soft-fail paths that hide real bugs. When a PRD is provided, also validates that the implementation matches the requirements.

**Speed model:** After gathering context, **every review concern runs as its own specialist agent in parallel**. The main agent only gathers context, launches the fan-out, and synthesizes findings. Do not run security → performance → quality as sequential main-agent passes.

**Usage:** `/pr-review [optional-prd-file-path]`

---

## Core Philosophy

- **Be ruthlessly thorough.** Every diff line is examined. Nothing slips through.
- **Performance is not optional.** O(n²) loops, N+1 queries, missing indexes, unbounded fetches, synchronous blocking — all get flagged.
- **Security is non-negotiable.** Injection vectors, auth bypasses, secret leaks, unsafe deserialization, missing input validation — all get flagged.
- **"Just make it work" is not acceptable.** Silent fallbacks, swallowed errors, and soft-failure paths that hide real bugs must be flagged. Prefer hard failures with clear errors over continuing in a wrong state.
- **Soft types cause soft fails.** Many fallbacks exist only because a value was typed loosely (`T | undefined`, optional fields, `Partial`, untyped JSON, weak inference). Prefer **hard, exact types** that encode invariants so the compiler forces callers to handle reality — **never** "fix" with `any`, `as any`, or other type-erasing shortcuts.
- **End-to-end completeness is required.** A field or feature that saves in the UI but is not read by exporters, imports, dual pipelines, or shared call sites is incomplete — flag write-only and partial migrations.
- **DB and races beat app conventions.** Uniqueness and "one of X" must be enforced where concurrency lives (unique indexes, transactions), not only in happy-path application code.
- **AuthZ is the real gate, not tenant membership alone.** "Row is in my tenant" is not enough when assignment/role gates already exist.
- **PRD compliance is binary.** When a PRD is provided, every requirement either has a matching implementation or it doesn't. No guessing.
- **Actionable feedback only.** Every finding includes the file, line, what's wrong, why it matters, and how to fix it.
- **Recurring PR failure patterns are a required pass.** These are patterns that repeatedly blocked real merges — treat hits as HIGH/CRITICAL when they match production failure modes.
- **Parallel specialists, never sequential mega-passes.** Launch one agent per concern type; synthesize after all return.
- **Architecture sense-check is advisory and silent by default.** It asks whether the approach makes sense in this codebase, but only speaks when there is a clear better path or a clearly poor fit — never as a merge blocker or rewrite demand.

---

## Execution Flow

```
1. Context Gathering          -> Branch info, base branch, full diff (main agent)
2. Diff Decomposition         -> Split diffs by file, categorize by domain (main agent)
3. PARALLEL SPECIALIST FAN-OUT -> Spawn one agent per concern type AT THE SAME TIME
      ├─ Agent A: Security
      ├─ Agent B: Performance
      ├─ Agent C: Silent Failure / Soft Types
      ├─ Agent D: Recurring PR Patterns (R1–R9)
      ├─ Agent E: Code Quality / Bugs / Races
      ├─ Agent F: Testing Gaps
      ├─ Agent G: PRD Compliance (only if PRD provided)
      ├─ Agent H: Architecture sense-check (advisory; silence when fine)
      ├─ Agent I: Dead code / unused / stale comments
      └─ Agent J: Duplication / extract-to-shared
 4. Synthesis & Report         -> Deduplicate, rank, unified report (main agent)
                                -> Architecture note only if Agent H is not "fine"
```

**Critical rule:** In Phase 3, issue **all** specialist agent spawns in a single parallel batch (multiple tool calls together). Do **not** wait for Agent A before spawning Agent B. Only after every specialist has returned, run Phase 4 synthesis.

**Architecture sense-check rule:** Agent H is advisory only. Its output never becomes CRITICAL/HIGH merge blockers and never asks anyone to re-architect. If the verdict is `fine`, omit architecture entirely from the final report.

---

## Phase 1: Context Gathering

Run all of these in parallel to gather the full picture:

### 1.1 Branch & Diff Info

```bash
# Current branch name
git branch --show-current

# Base branch (detect main or master)
git remote show origin | grep 'HEAD branch' | awk '{print $NF}'

# Full diff against base
git diff $(git merge-base HEAD origin/main)..HEAD

# Stat summary
git diff --stat $(git merge-base HEAD origin/main)..HEAD

# All commits on this branch
git log --oneline $(git merge-base HEAD origin/main)..HEAD
```

### 1.2 Changed Files List

```bash
git diff --name-only $(git merge-base HEAD origin/main)..HEAD
```

### 1.3 Project Context

- Read CLAUDE.md, README.md, or package.json to understand the tech stack
- Identify: language, framework, test framework, linting/formatting tools
- Note any existing security or performance tooling (ESLint security plugins, etc.)

### 1.4 PRD Loading (if provided)

If a PRD file path was given as an argument:
1. Read the PRD file
2. Extract all requirements, acceptance criteria, user stories, API contracts, and task checklists
3. Build a requirements checklist to verify against in the PRD specialist

If no PRD is provided, do **not** spawn the PRD Compliance agent.

---

## Phase 2: Diff Decomposition

Split the full diff into logical review units (for prioritization notes in agent prompts):

### 2.1 Categorize Each Changed File

| Category | File Patterns | Review Focus |
|----------|--------------|--------------|
| **API / Routes** | `**/api/**`, `**/routes/**`, `**/handlers/**`, `**/controllers/**` | Auth, input validation, error responses, rate limiting |
| **Database / Models** | `**/models/**`, `**/schema/**`, `**/migrations/**`, `**/prisma/**`, `**/drizzle/**` | SQL injection, missing indexes, data integrity, migrations |
| **Auth / Security** | `**/auth/**`, `**/middleware/**`, `**/guard/**`, `**/policy/**` | Auth bypass, session handling, token validation, RBAC |
| **Frontend Components** | `**/*.tsx`, `**/*.jsx`, `**/*.vue`, `**/*.svelte` | XSS, state leaks, excessive re-renders, accessibility |
| **Business Logic** | `**/services/**`, `**/lib/**`, `**/utils/**`, `**/helpers/**` | Logic errors, edge cases, error handling, complexity |
| **Configuration** | `*.config.*`, `.env*`, `**/config/**`, `docker*` | Secret exposure, insecure defaults, missing validation |
| **Tests** | `**/test/**`, `**/tests/**`, `**/*.test.*`, `**/*.spec.*` | Coverage gaps, brittle assertions, missing edge cases |
| **Infrastructure** | `**/ci/**`, `**/.github/**`, `**/terraform/**`, `**/k8s/**` | Insecure pipelines, missing checks, exposed secrets |

### 2.2 Priority Order (for agent context, not sequential review)

Highest risk first when agents must chunk large diffs:
1. Auth / Security files
2. API / Routes
3. Database / Models
4. Configuration
5. Business Logic
6. Frontend Components
7. Infrastructure
8. Tests

---

## Phase 3: Parallel Specialist Fan-Out

Spawn **one dedicated agent per concern** below. Use the platform's multi-agent tool (`Task` / `spawn_subagent` / equivalent). **Launch every agent in the same turn** so they run concurrently.

### Shared payload for every agent

Every specialist prompt MUST include:

```
## Branch
[branch-name] vs [base-branch]

## Tech Stack
[detected stack]

## Changed Files
[file list from Phase 1.2]

## Full Diff
[full diff from Phase 1.1]

## File Categories (optional hint)
[Phase 2 categorization summary]
```

If the diff is extremely large (>5000 lines), chunk the diff and note which chunk this agent owns — or spawn **multiple agents of the same specialty** per chunk (e.g. Security-chunk-1, Security-chunk-2). Prefer parallel chunking over sequential reading by the main agent.

### Shared output format (every specialist except Agent H)

```
For each finding, report:
| Field | Value |
|-------|-------|
| Severity | CRITICAL / HIGH / MEDIUM / LOW |
| Category | [agent-specific category tag] |
| File | exact file path |
| Line(s) | line number(s) in the diff / file |
| Issue | short title |
| Description | what's wrong and why it matters |
| Fix | specific code change to remediate |

If NO issues are found for your specialty, explicitly state "No <specialty> issues found" —
do NOT invent issues that don't exist.
Do not review concerns outside your specialty (other specialists own those).
Do not modify any code. Review only.
```

Agent H uses its own verdict format (see Agent H section) — not Severity findings.
Agents I (`DeadCode`) and J (`Duplication`) use the shared Severity findings format above.

---

### Agent A — Security

- **subagent_type**: `backend-architect` (or `general-purpose` if unavailable)
- **description**: `PR review: security`
- **Category tag**: `Security`

```
You are performing a SECURITY-FOCUSED code review ONLY. Ignore performance, style, and tests
except where they create security risk.

[Shared payload]

## Security Checklist - Check EVERY item against the diffs:

### Injection Attacks
- [ ] SQL injection (raw queries, string concatenation in queries)
- [ ] NoSQL injection (unsanitized MongoDB queries)
- [ ] Command injection (exec, spawn with user input)
- [ ] LDAP injection
- [ ] XSS (innerHTML, dangerouslySetInnerHTML, unescaped template output)
- [ ] Template injection (server-side template engines)

### Authentication & Authorization
- [ ] Missing auth checks on new endpoints
- [ ] Broken access control (user A accessing user B's data)
- [ ] JWT issues (missing expiry, weak secret, algorithm confusion)
- [ ] Session fixation or insecure session handling
- [ ] Missing RBAC/permission checks
- [ ] Privilege escalation paths
- [ ] **Thin tenant checks only** — "row exists in caller's tenant" without assignment/role gates used elsewhere for the same resource
- [ ] **Over-broad procedures** — PENDING/onboarding/unprivileged roles can perform privileged side effects
- [ ] **Identity vs capability conflation** — gating "who is this person?" lookups with "can they take a lead / pull credit?" filters (or the reverse)
- [ ] Auth/permission checks that **fail open** (`catch { return true }`)

### Data Exposure
- [ ] Secrets in code (API keys, passwords, tokens)
- [ ] Sensitive data in logs (passwords, tokens, PII)
- [ ] Overly permissive CORS
- [ ] Missing data sanitization in API responses (exposing internal fields)
- [ ] Directory traversal in file operations
- [ ] **Env-var names / internal config in user-facing errors**
- [ ] Cross-tenant leakage via missing tenant filters on global vendor lookups

### Input Validation
- [ ] Missing input validation on API endpoints
- [ ] Missing type checking/schema validation
- [ ] Unbounded input sizes (DoS via large payloads)
- [ ] Missing rate limiting on sensitive endpoints

### Cryptography
- [ ] Weak hashing (MD5, SHA1 for passwords)
- [ ] Missing encryption for sensitive data at rest
- [ ] Hardcoded cryptographic keys
- [ ] Insecure random number generation for security contexts

### Dependencies
- [ ] Known vulnerable dependencies being added
- [ ] Pinned versions vs. floating versions

For each finding also include: Exploit Scenario (how an attacker could exploit this).
```

---

### Agent B — Performance

- **subagent_type**: `backend-architect` (or `general-purpose` if unavailable)
- **description**: `PR review: performance`
- **Category tag**: `Performance`

```
You are performing a PERFORMANCE-FOCUSED code review ONLY. Ignore security vulns and style
except where they create perf risk.

[Shared payload]

## Performance Checklist - Check EVERY item against the diffs:

### Database & Queries
- [ ] N+1 query patterns (queries inside loops)
- [ ] Missing database indexes for new query patterns
- [ ] Unbounded SELECT queries (missing LIMIT/pagination)
- [ ] Missing WHERE clauses (full table scans)
- [ ] Redundant queries (same data fetched multiple times)
- [ ] Missing eager loading / over-fetching relations
- [ ] Large transactions holding locks too long
- [ ] Missing connection pooling

### Algorithmic Complexity
- [ ] O(n²) or worse loops (nested iterations over large datasets)
- [ ] Unnecessary array copies or object spreads in loops
- [ ] Missing early returns / short circuits
- [ ] Sorting where not needed
- [ ] Repeated expensive computations (missing memoization)

### Memory & Resources
- [ ] Memory leaks (event listeners not cleaned up, intervals not cleared)
- [ ] Unbounded caches or collections that grow forever
- [ ] Large objects held in closure scope unnecessarily
- [ ] Missing stream processing for large data
- [ ] File handles or connections not closed

### Network & I/O
- [ ] Sequential API calls that could be parallelized (Promise.all)
- [ ] Missing request timeouts
- [ ] Missing retry logic with backoff
- [ ] Large payloads without compression
- [ ] Missing pagination on list endpoints
- [ ] Synchronous file operations blocking the event loop

### Frontend Performance
- [ ] Unnecessary re-renders (missing useMemo, useCallback, React.memo)
- [ ] Large bundle imports (importing entire libraries for one function)
- [ ] Missing code splitting / lazy loading
- [ ] Layout thrashing (reading/writing DOM in loops)
- [ ] Unoptimized images or assets
- [ ] Missing virtualization for long lists
- [ ] Expensive computations on the main thread

### Caching
- [ ] Missing caching for expensive operations
- [ ] Cache invalidation issues
- [ ] Missing HTTP cache headers

For each finding also include: Impact (latency, memory, CPU estimate).
```

---

### Agent C — Silent Failure / Soft Types

- **subagent_type**: `general-purpose`
- **description**: `PR review: silent failures`
- **Category tag**: `SilentFailure` (and `SoftType` when type-rooted)

```
You are performing a "JUST MAKE IT WORK" / SILENT-FAILURE / SOFT-TYPES code review ONLY.
Prefer hard failures with clear errors over continuing in a wrong state — unless the fallback
is intentional, documented, user-visible graceful degradation.

[Shared payload]

## Checklist

### Silent / swallowed failures
- Empty `catch` blocks, or catch that only logs and continues as if success
- `.catch(() => undefined)`, `.catch(() => null)`, `.catch(() => [])`, `.catch(() => {})`
- `try/catch` that returns a default success value on failure
- Promise rejection handlers that discard the error without rethrowing/surfacing
- Fire-and-forget async (`void fn()`, unawaited promises) where failure should affect the caller

### Fallbacks that should hard-fail instead
- Defaulting critical config/env (`process.env.X || 'localhost'`, fake API keys, wrong URLs)
- Returning empty arrays/objects/`null` when required dependency (DB row, API, auth) is missing
- `|| []`, `?? []`, `?? {}`, `?? ''` papering over unexpected null/undefined
- Long optional chaining (`a?.b?.c?.d`) on a required path
- Fallback to mock, cached-stale, or placeholder data in production without product requirement
- Retry loops that "succeed" with partial/empty data instead of failing after exhaustion
- Parsing wrapped so invalid input becomes a silent default

### Soft types that force soft fails (root-cause pass)

For every soft-fail/fallback finding:
1. Trace the type of the value being defaulted / optional-chained / cast.
2. Determine the exact expected type from domain/API/schema/callers.
3. Prefer hardening the type so the fallback becomes unnecessary.
4. Never suggest `any`, `as any`, un-narrowed `unknown`, or type-erasing shortcuts.

Flag:
| Soft type smell | What to do instead |
|-----------------|--------------------|
| `T \| undefined` / `T \| null` always present after success | Success type is `T`; nullability only on lookup; narrow once then throw/404 |
| Optional fields required by product/API | Required field or draft vs loaded types |
| `Partial<T>` for fully-loaded entities | Separate CreateInput/Patch from full entity |
| Unvalidated JSON / `Record<string, unknown>` deep in domain | Parse at boundary into exact type |
| Over-wide unions (`string` for closed set) | Literal unions or enums |
| Empty success when absence is error | Return `T` + throw, or Result union |
| Optional params only to make call sites compile | Fix call sites |
| Prisma selects omit fields then code defaults them | Select required fields; type result correctly |

### Type / assertion papering
- `as any`, `as unknown as T`, non-null `!` to silence type errors
- Type guards that always return true; bare `@ts-ignore` / `@ts-expect-error`
- Soft API/config types compensated with runtime fallbacks instead of post-validation hard types

### Behavioral soft-fail smells
- Feature flags that disable broken behavior with no error/metric
- Partial success returned as full success (2 of 5 writes fail, API 200)
- Validation that logs a warning and continues
- Auth/permission fail-open (`catch { return true }`)
- "Best effort" comments that excuse missing correctness without explicit design

## Severity guidance
| Pattern | Typical severity |
|---------|------------------|
| Auth fails open; financial/data-loss soft-fails | CRITICAL / HIGH |
| Required data → empty default; config fallback hides misconfig | HIGH |
| Soft type forces cascade of `??` / `||` / `?.` | HIGH (root-cause the type) |
| Suggested/existing fix using `any` / type-erasure | HIGH |
| Swallowed errors on non-critical path | MEDIUM |
| Defensive `??` on truly optional documented fields | Not a finding |

For each finding state:
1. What the code does on failure today
2. What should happen instead (throw / 4xx/5xx / fail the job)
3. Whether the root cause is a soft type — if yes, the exact hard type and validation boundary
4. A concrete fix that hardens types and removes the fallback — not more defaults, not `any`
```

---

### Agent D — Recurring PR Patterns (R1–R9)

- **subagent_type**: `general-purpose`
- **description**: `PR review: recurring patterns`
- **Category tag**: `RecurringPattern` (plus R# in Issue title)

```
You are performing the RECURRING PR FAILURE PATTERNS review ONLY (R1–R9).
These patterns repeatedly blocked real merges. When a hit can cause data loss, wrong
credit/AUS/messaging behavior, cross-tenant routing, or "looks healthy while broken,"
severity is CRITICAL or HIGH.

[Shared payload]

Walk EVERY checklist item. For R2/R6, **read consumers outside the diff** (transformers,
importers, twin pipelines, sibling procedures) when the change introduces fields or dual-path logic.

### R1 — Soft failure that looks like success
- Catch/log-and-continue while status still claims ACTIVE / ready / success
- Empty-string/object fallbacks on **required** export/vendor payloads instead of preflight throw
- Setup/side-effect failures swallowed so operators treat feature as live
- Tests skip/pass when fixtures/reference inputs absent
- Polling-only UIs with no recovery if webhooks never land

### R2 — Incomplete end-to-end wiring (write-only features)
For every new/changed field or source-of-truth move, trace:
UI → API/schema → DB → read/list → export transformers (all engines) → import/mappers → jobs → shared call sites
- Shared component only partially adopted
- Clear/reset persists null but live side effects never update
- Refactor deletes old write path without re-homing data

### R3 — App-only invariants and races
- "One of X" uniqueness only in app code — no DB unique/partial unique/FK
- Check-then-act without atomicity or unique-violation handling
- Position/counter `last + 1` without unique + retry
- Tenant-scoped unique on a **globally** unique shared-vendor resource
- Multi-step writes missing transaction when partial success corrupts state

### R4 — Thin authZ / tenant / secret boundaries
- Weaker gates than sibling resources
- Over-broad caller sets for privileged side effects
- Identity lookup mixed with capability filters
- User-facing errors leak env-var names
- PII/secrets in logs; dual-pipeline credential redaction gaps

### R5 — Form hydration / mount effects wipe real data
- useEffect writes form state on mount without hydration sentinel
- Auto-flip / clear-stale that nulls persisted enums/booleans on first paint
- Partial updates that null omitted fields

### R6 — Dual-path / dual-surface inconsistency
- Parallel transformers use different predicates for the same domain concept
- CRM vs funnel (or admin vs LO) encode different rules
- Two canonical schemas/enums disagree
- Sticky DB columns fight live derivation
- Actor identity differs across steps without explicit product rule

### R7 — Response envelopes, partial updates, type lies
- Casts to guessed shapes when real response is an envelope
- Partial update sets omitted fields to null instead of skipping
- Schema/migration drift; mocks missing new columns
- `as any` / double casts / envelope lies

### R8 — UX recovery and edge states
- Async flows missing loading / error / cancel / retry / stale-expired handling
- Broken image/URL with no fallback; double-submit not blocked
- List/create can 500 with no error state
- Eager per-row work without unmount cleanup / virtualization

### R9 — Consistency / scope
- Reinvents existing gate/helper/component nearby
- Unrelated scope creep
- Arbitrary design tokens / z-index when project defines a scale
- Tab-like UI with incomplete a11y

For each finding:
1. Which R# pattern
2. What fails in production (concrete)
3. Concrete fix — prefer DB constraints, existing auth helpers, hard preflight throws, full consumer wiring, envelope-typed clients, tests that fail if the bug returns — not more `??` defaults
```

---

### Agent E — Code Quality / Bugs / Races

- **subagent_type**: `general-purpose`
- **description**: `PR review: code quality`
- **Category tag**: `Quality`

```
You are performing a CODE QUALITY / BUG / RACE-CONDITION review ONLY.
Do not deep-dive security vulns, N+1 perf, silent-failure catalogs, or R1–R9 (other agents own those)
unless the bug is pure correctness unrelated to those catalogs.

[Shared payload]

### Bug Detection
- Race conditions (shared mutable state, async ordering issues)
- Off-by-one errors
- Null/undefined dereferences without guards
- Unhandled promise rejections / missing try-catch
- Type coercion bugs (== vs ===, implicit conversions)
- Copy-paste errors that introduce subtle behavioral bugs (Agent I/J own pure dead code and pure extract-to-shared)

### Error Handling (correctness, not soft-fail catalog)
- Missing error handling on async operations
- Generic error messages that leak internal details
- Missing cleanup in error paths (finally blocks)
- Error responses missing proper HTTP status codes

### Code Patterns
- Inconsistent patterns compared to the rest of the codebase
- Magic numbers or strings without constants
- Missing TypeScript types; `any` / un-narrowed `unknown` / overuse of `Partial` / unnecessary optionals
- Overly complex functions (high cyclomatic complexity)
- Missing comments on non-obvious complex logic (Agent I owns stale/useless leftover comments)

Do NOT deep-dive unused imports, dead symbols, commented-out blocks, or "extract because N copies" — Agents I and J own those.

Read surrounding context, not just the diff hunk.
```

---

### Agent F — Testing Gaps

- **subagent_type**: `test-writer-fixer` (or `general-purpose` if unavailable)
- **description**: `PR review: testing gaps`
- **Category tag**: `Testing`

```
You are performing a TESTING GAPS review ONLY. Identify missing/weak tests; do not rewrite
the product code. Do not invent security/perf findings.

[Shared payload]

### Testing Gaps Checklist
- New code paths without corresponding tests
- Modified behavior without updated tests
- Edge cases not covered
- Missing tests that assert **failure** paths (bad input / missing data errors out rather than soft-succeeding)
- Tests that **no-op green** when fixtures/reference files are missing (hardcoded absolute paths, optional reads, early `return` without assert)
- Fixtures that hardcode the happy path so the assertion cannot fail
- Behavior/UI contract changes without updating e2e/integration assumptions
- Prefer noting at least one test that would **fail** if a silent-success or write-only bug returned

For each finding: what test is missing, where it should live, and what assertion would catch the bug.
```

---

### Agent G — PRD Compliance (only if PRD provided)

- **subagent_type**: `general-purpose`
- **description**: `PR review: PRD compliance`
- **Category tag**: `PRD`
- **Skip entirely** when no PRD path was given.

```
You are validating that code changes correctly implement a PRD. Compliance only —
do not re-do security/performance/quality scans.

## PRD Content
[full PRD text]

## All Diffs on the Branch
[full diff]

## Changed Files
[file list]

Go through EVERY requirement and classify:

| Status | Meaning |
|--------|---------|
| IMPLEMENTED | Fully satisfies |
| PARTIALLY IMPLEMENTED | Some aspects done |
| NOT IMPLEMENTED | No matching code |
| DEVIATED | Differs from PRD |
| NOT APPLICABLE | e.g. deployment-only |

Check: API contracts, data model, frontend components, business logic, acceptance criteria
(Given/When/Then), and task checklist items.

### Output Format

## PRD Compliance Report

### Summary
- Total Requirements: [N]
- Implemented / Partially / Not Implemented / Deviated: counts

### Detailed Findings
#### [Requirement]
- **Status**: ...
- **Evidence**: File:line or "No matching code found"
- **Gap** (if any): ...
- **Severity of Gap**: BLOCKING / SHOULD_FIX / NICE_TO_HAVE

### Deviations from PRD
### Missing Implementations (priority-ordered)
```

---

### Agent H — Architecture sense-check (advisory only)

- **subagent_type**: `general-purpose` (or `plan` if available)
- **description**: `PR review: arch sense`
- **Category tag**: `ArchitectureSense` (advisory — not a merge-blocking category)
- **Always spawn** (unlike Agent G).

```
You are performing an ARCHITECTURE SENSE-CHECK only. Advisory. Conservative.

Your job is to answer one question:

> "Does the way this is implemented actually make sense as it is now?"

[Shared payload]

Also read surrounding codebase context (similar features, existing helpers, layering conventions)
— not just the diff hunks.

Ask: given this codebase and the problem being solved, is the architecture a reasonable fit?
Could a competent engineer reading this in six months understand why it was built this way?

### Stance — default to "fine"

- You are **not** quick to demand a re-architecture. Most working designs that fit local patterns are fine.
- Only speak up when there is a **very clear** more proper way that fits this codebase better for the
  grand change, OR when the current approach is **clearly poor** (wrong layer, fights existing
  abstractions, invents a parallel system for something already solved, will force painful follow-ups).
- Style preferences, micro-optimizations, naming bikesheds, and "I would have done it slightly
  differently" are NOT findings.
- Preferable-but-not-clearly-better alternatives are NOT findings. Silence is correct when the design
  is acceptable.

### What you may conclude

| Verdict | When | What you write |
|---------|------|----------------|
| **fine** | Design is reasonable for this codebase | Exactly: `Verdict: fine` — no other text |
| **clear-better-path** | A clearly better architecture exists that fits the grand change and surrounding code | Short note (see format) |
| **poor-fit** | Current approach is a poor fit | Short note (see format) |

### Critical constraints

- Do **not** invent Severity / CRITICAL / HIGH findings for the main findings tables.
- Do **not** demand a rewrite or re-architecture as a merge blocker.
- Do **not** re-do security, performance, silent-failure, R1–R9, quality, testing, dead-code, duplication, or PRD reviews.
- Keep notes short. If fine, one line only.

### Output format — not Severity findings

# Architecture sense-check

## Verdict
fine | clear-better-path | poor-fit

## Note
(Omit this section entirely when Verdict is fine.)
When not fine: 2–6 sentences covering:
- What was built and why it appears shaped this way
- Why that shape is a poor fit OR why a better path is clearly preferable in this codebase
- The alternative that makes more sense (concrete modules/layers/patterns, not vague advice)
- Frame as advice for the reader — not instructions to rewrite before merge
```

---

### Agent I — Dead code / unused / stale comments

- **subagent_type**: `general-purpose`
- **description**: `PR review: dead code`
- **Category tag**: `DeadCode`

```
You are performing a DEAD CODE / UNUSED / STALE COMMENT review ONLY.
Your job is to remove noise left by refactors — unused symbols and comments that explain
what used to be there rather than what the code does now.

[Shared payload]

Also grep/read surrounding files to confirm something is truly unused (not just unused inside
the diff hunk). Prefer proof of zero references over vibes.

## Checklist

### Unused imports & symbols introduced or left by this change
- Unused imports (named, default, type-only, side-effect imports that are no longer needed)
- Unused locals, params, private helpers, types, interfaces, enums, constants
- Exports added in this PR with no in-repo consumers (or consumers only in deleted code)
- Re-exports / barrel entries that nothing imports
- Feature flags, config keys, or env reads that are never read after the change
- Dead branches / unreachable code after condition changes
- Variables assigned and never read; catch bindings unused without reason

### Stale / useless comments (delete, do not "improve")
- Comments that narrate removed behavior: "used to…", "previously…", "was…", "no longer…",
  "removed X", "old path", "legacy before refactor"
- Block comments that are just deleted code in prose, or large commented-out code blocks
- JSDoc/TSDoc on deleted params/fields, or docs that contradict the current signature
- TODOs/FIXMEs that are already done (or refer to code that no longer exists)
- Section banners / leftover separators for code that was deleted
- "Explain what the next line does" noise on obvious code — only flag when added/left by this PR
  and adds no non-obvious intent; do not bikeshed every pre-existing comment outside the change

### What NOT to flag
- Imports/symbols that are used (including type positions, decorators, DI, framework reflection)
- Public API surface that is part of a published package / intentional external contract
- Comments that explain non-obvious WHY, invariants, security, or protocol constraints
- Temporarily commented code that the PR clearly marks as WIP with an active tracking TODO + issue
- Test fixtures that look "unused" but are required by runners/frameworks

## Severity guidance
| Pattern | Typical severity |
|---------|------------------|
| Unused import / trivial dead local left by refactor | LOW |
| Dead private helper / unreachable branch in changed files | MEDIUM |
| Large commented-out blocks or stale "used to" comments that mislead | MEDIUM |
| Exported/public-looking dead API that confuses callers | MEDIUM / HIGH |
| Misleading comment that contradicts current security/auth behavior | HIGH |

For each finding:
1. Proof it is unused or stale (e.g. "grep for X across repo: 0 refs outside definition")
2. Exact delete/edit (usually delete the import/symbol/comment — not a rewrite)
3. Do not suggest broad cleanups outside the PR's blast radius unless the dead code was introduced here
```

---

### Agent J — Duplication / extract-to-shared

- **subagent_type**: `general-purpose`
- **description**: `PR review: duplication`
- **Category tag**: `Duplication`

```
You are performing a DUPLICATION / EXTRACT-TO-SHARED review ONLY.
Flag repeated logic that should become a shared helper — not every similar-looking line.

[Shared payload]

Read beyond the diff: search the repo for copies of the same logic (same predicates, same
transform sequences, same UI blocks, same validation, same mapping tables).

## When to flag (ALL must hold)

1. **Count ≥ 3** real occurrences of the same logic (in the PR and/or existing codebase after
   this change lands). Two copies is usually not enough unless the PR is clearly about to add more.
2. **Would realistically be used more** — another call site is likely soon (same domain concept,
   sibling features, list+detail+export, CRM+funnel, multiple transformers, repeated form fields).
3. **Stable enough to name** — not a one-off coincidence of similar shape with different invariants.
4. **Extraction improves clarity** — a named helper would reduce drift risk, not hide important differences.

If copies deliberately differ on domain rules, do NOT force a shared abstraction — note the risk
of false unification instead only if the PR already pretends they are the same.

## Scope of the shared home (required on every finding)

Choose scope from **where the copies live and how many consumers exist**, not from taste:

| Occurrences / fan-out | Proposed scope |
|-----------------------|----------------|
| 3+ in one file only | Private helper in that file |
| 3+ across one feature folder / module | Module-level `utils` / `helpers` beside the feature |
| 3+ across packages in one app (e.g. web-crm only) | App-level shared module already used for similar things |
| 3+ across apps or backend+frontend domain rules | Existing monorepo `libs/` package (or the package that already owns this domain) |
| Matches an **existing** helper almost exactly | Reuse/extend that helper — do not invent a parallel one |

Always name:
- Exact occurrence count and file:line list (or representative list if many)
- Proposed symbol name and file path for the shared home
- What varies per call site (parameters) vs what stays identical
- Whether an existing helper already covers this (prefer extend over new)

## What NOT to flag
- Two similar blocks with no likely third consumer
- Framework boilerplate that must stay local (trivial one-liners, obvious map/filter)
- Copy-paste that is test data/fixtures where duplication is intentional
- "Duplication" that would require a premature god-helper with many flags/options
- Style-only similarity (same control-flow shape, different business meaning)
- Huge cross-cutting refactors unrelated to this PR's risk — keep proposals proportional

## Severity guidance
| Pattern | Typical severity |
|---------|------------------|
| 3 local copies, easy file-private helper | LOW / MEDIUM |
| 3+ copies already drifting (subtle bug differences) | HIGH |
| 3+ copies across dual paths (CRM/funnel, twin transformers) with same domain rule | HIGH |
| Should reuse existing shared helper but reinvented | MEDIUM / HIGH |
| Speculative extract with only 2 weak lookalikes | Not a finding |

For each finding include: count, locations, proposed scope + path, and a concrete signature —
not "consider DRY".
```

---

### Fan-out rules

1. **One tool-call batch** — spawn Agents A–F, H, I, J always, and G if PRD, together; do not serialize.
2. **capability_mode**: prefer `read-only` when available so specialists cannot edit code.
3. **Do not** have the main agent re-run the same checklists after specialists return — only synthesize.
4. If a specialist agent fails or returns empty without the required "No X issues found" line (or for Agent H, without a Verdict), re-spawn **that specialty only** once. Do not re-run the whole fan-out. If Agent H fails twice, treat as `Verdict: fine` and continue.
5. Specialists must stay in their lane. Overlap is OK; synthesis deduplicates.
6. **Agent H is never merge-blocking.** Do not promote architecture notes into Critical/High findings tables.

---

## Phase 4: Synthesis & Final Report

After **all** specialists complete, the main agent compiles a unified report.

### 4.1 Collect & Deduplicate

- Merge findings from Agents A–F, I, J (and G if present). **Exclude Agent H** from the findings tables.
- If two specialists flag the same line, merge into one finding with combined Category tags (e.g. `Security + SilentFailure`).
- Prefer the more specific Fix; keep the higher Severity.
- Hold Agent H's verdict aside for the optional architecture section only.

### 4.2 Severity Ranking

| Severity | Action Required | Examples |
|----------|----------------|----------|
| **CRITICAL** | Must fix before merge | SQL injection, auth bypass, data loss, secret exposure, auth fails-open, cross-tenant routing, soft-success on money/credit/AUS/messaging setup |
| **HIGH** | Should fix before merge | N+1 on hot paths, check-then-act races, write-only fields, silent `?? ''` on required vendor payloads, thin tenant-only authZ, form mount wiping data, dual-path divergence, envelope casts, no-op-green tests |
| **MEDIUM** | Fix soon, doesn't block merge | Missing memoization, suboptimal patterns, incomplete validation, swallowed non-critical errors, incomplete UX recovery, dead helpers, stale misleading comments, 3+ copy extract candidates |
| **LOW** | Nice to have | Minor style issues, slightly better naming, small optimizations, pure a11y polish, unused imports |

### 4.3 Final Report Template

```markdown
## Code Review Report

**Branch**: [branch-name]
**Base**: [base-branch]
**Files Changed**: [N]
**Commits**: [N]
**Review Date**: [date]
**Specialists**: Security, Performance, SilentFailure, RecurringPattern, Quality, Testing, DeadCode, Duplication, ArchitectureSense-advisory[, PRD]

---

### Verdict: [BLOCK / APPROVE WITH FIXES / APPROVE]

[1-2 sentence summary of overall code quality. Do not let Agent H change the merge verdict.]

---

### Critical & High Findings (Must Fix)

| # | Severity | Category | File | Line(s) | Issue | Fix |
|---|----------|----------|------|---------|-------|-----|
| 1 | CRITICAL | Security | auth.ts | 45 | SQL injection via unsanitized input | Use parameterized query |
| 2 | HIGH | Performance | users.ts | 88-95 | N+1 query in loop | Batch query with IN clause |

### Medium & Low Findings (Recommendations)

| # | Severity | Category | File | Line(s) | Issue | Fix |
|---|----------|----------|------|---------|-------|-----|
| 3 | MEDIUM | Quality | utils.ts | 30 | Missing error handling on API call | Add try-catch with retry |
| 4 | LOW | Quality | types.ts | 12 | Using `any` type | Define proper interface |

### PRD Compliance (if applicable)

| Requirement | Status | Notes |
|-------------|--------|-------|
| ... | ... | ... |

**PRD Coverage**: [X]% of requirements implemented

### Summary Statistics

| Category | Critical | High | Medium | Low |
|----------|----------|------|--------|-----|
| Security | | | | |
| Performance | | | | |
| Code Quality | | | | |
| Silent Failure | | | | |
| Recurring Pattern (R1–R9) | | | | |
| Testing | | | | |
| Dead Code | | | | |
| Duplication | | | | |
| **Total** | | | | |

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

### Specialist status

| Specialist | Status | Findings |
|------------|--------|----------|
| Security | complete / failed-retry | N |
| Performance | ... | N |
| Silent Failure | ... | N |
| Recurring Patterns | ... | N |
| Code Quality | ... | N |
| Testing | ... | N |
| Dead Code | ... | N |
| Duplication | ... | N |
| Architecture sense-check | complete / failed→fine | fine / clear-better-path / poor-fit |
| PRD | complete / skipped | N |

### Architecture sense-check (user advisory)

<!-- ONLY include this section when Agent H verdict is clear-better-path or poor-fit.
     If Verdict is fine: OMIT this entire section — say nothing about architecture. -->

**Verdict**: clear-better-path | poor-fit

[2–6 sentence note from Agent H, lightly edited for clarity. Frame as "For your consideration"
— not a merge blocker, not work the review agent will perform. Do not invent a rewrite plan.]

### Next Steps
1. Fix all CRITICAL findings before merge
2. Address HIGH findings — these will cause problems in production
3. Consider MEDIUM findings for code quality
4. [If PRD provided] Implement missing requirements: [list]
5. [Only if architecture section present] Architecture note is optional judgment for you — not a required rewrite
```

**User-facing rule for architecture:** After the report, if Agent H said `fine`, do not mention architecture at all. If not fine, the architecture section in the report is enough — do not push a re-architecture unless the user asks.

---

## Error Handling

| Error | Action |
|-------|--------|
| No changes on branch (clean diff) | Stop, inform user there's nothing to review |
| Cannot detect base branch | Ask user which branch to diff against |
| PRD file not found | Warn user and continue without Agent G |
| Diff is extremely large (>5000 lines) | Chunk and spawn multiple agents **per specialty** in parallel |
| One specialist fails | Re-spawn that specialty once; continue with others |
| Agent returns no findings | Accept it — don't fabricate issues. Report "clean" for that specialty |
| Agent H returns fine | Omit architecture from the report entirely — silence is correct |
| Agent H fails twice | Treat as fine; do not invent architecture concerns |

---

## Important Rules

1. **Never fabricate findings.** If the code is clean, say it's clean. False positives destroy trust.
2. **Read the actual code, not just the diff** — specialists must use Read/Grep on surrounding context. For R2/R6, read consumers outside the diff. Architecture sense-check must read surrounding patterns too.
3. **Severity matters.** CRITICAL means genuinely dangerous, not "could be slightly better."
4. **Be specific.** "This might be slow" is useless. Name file, line, impact, and fix. For recurring patterns, name the R# and production failure mode.
5. **Provide fixes, not just complaints.** Every finding must include a concrete remediation. (Architecture notes are advice, not findings tables.)
6. **PRD review is additive.** It never replaces security/performance/quality specialists.
7. **Respect the developer's time.** Prioritize findings so they know what to fix first.
8. **Hard-fail over soft-fail by default.** Flag silent fallbacks, swallowed errors, and defaults that hide misconfiguration.
9. **Hard types over soft types and fallbacks.** Prescribe the exact expected type and validation boundary — never `any`.
10. **Always run the Recurring Patterns specialist.** Even on "small" PRs. Report the coverage table even when clean.
11. **Prefer existing project gates and DB constraints** over new ad-hoc checks and `??` defaults.
12. **Parallel is mandatory.** Do not collapse specialists into one sequential mega-reviewer. Speed and focus come from one concern per agent.
13. **Architecture sense-check defaults to silence.** Only surface when verdict is `clear-better-path` or `poor-fit`. Never treat it as a merge blocker. Never demand a rewrite mid-review or in Next Steps. If fine, omit architecture entirely.
