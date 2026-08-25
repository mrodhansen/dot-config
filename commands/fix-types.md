---
description: Scans all TypeScript/types in a PR or branch diff for soft types (`any`, unnecessary `null`/`undefined`, optional fields that are required, `Partial`, unvalidated JSON, over-wide unions) and hardens them against Prisma/DB schemas, API contracts, and domain invariants — then fixes call sites so the code compiles with those hard types. Prefer exact definitions over `any` or nullish escape hatches. Use when the user runs /fix-types, /fix-types <pr|branch>, "harden types", "fix soft types", "remove any types", "make types strict", or "hard types on this PR/branch".
---

# /fix-types - Harden Soft Types on a PR / Branch

Scans every type that is **part of the current PR or branch** (not the whole monorepo), finds soft types, grounds the correct hard shape in schema/contracts/domain code, rewrites the types to be exact, and fixes all call sites so the branch typechecks with those hard definitions.

**Usage:**
- `/fix-types` — current branch vs detected base (`main`/`master`)
- `/fix-types <branch>` — treat that branch as the scope (or diff target)
- `/fix-types pr` / `/fix-types <pr-number>` — use the open PR (or a given PR) for the file set

---

## Core Philosophy

- **Hard types by default.** Almost every value has an exact expected shape. Prefer that shape over `any`, over-wide unions, or nullish "maybe."
- **`any` is almost never acceptable.** Neither is `as any`, `as unknown as T`, or `@ts-ignore` / `@ts-expect-error` used to silence type errors.
- **`null` / `undefined` are rare, intentional absences** — not defaults for "we didn't model this." If the domain requires the value after a successful load/auth/parse, the type must require it.
- **Schema is ground truth.** Prisma models, Zod/validators, OpenAPI/tRPC contracts, and existing domain types define what is real. Soften only when the schema truly allows absence.
- **Fix types first, then call sites.** Hardening a type without fixing consumers is incomplete. Softening types to make call sites compile is **forbidden**.
- **Scope is the PR/branch only.** Do not refactor unrelated packages. Touch files outside the diff only when required to export a shared hard type that the branch already depends on.
- **Do not invent product behavior.** If absence is a real product state (draft vs published, optional UI prop), keep it explicit (`T | null`, optional prop, or a dedicated draft type) — do not invent fake defaults.

---

## Execution Flow

```
1. Resolve scope          -> Branch / PR / base, file list, full diff
2. Inventory soft types   -> Scan changed TS/TSX (+ type-bearing files)
3. Ground truth           -> Prisma / Zod / API / domain contracts per finding
4. Plan hard types        -> Exact replacements; classify intentional soft
5. Apply type fixes       -> Interfaces, schemas, generics, return types
6. Fix call sites         -> Remove fallbacks/casts; narrow at boundaries
7. Verify                 -> Typecheck affected projects; fix remaining errors
8. Report                 -> Summary of hardened types + intentional leftovers
```

Use a short todo list for multi-file work. Prefer direct edits; spawn agents only when a package fan-out is large.

---

## Phase 1: Resolve Scope

### 1.1 Inputs

| Argument | Behavior |
|----------|----------|
| (none) | Current branch vs merge-base with origin default branch |
| branch name | Diff that branch vs its merge-base with origin default (or vs current if user asked to compare) |
| `pr` | Open PR for current branch via `gh pr view` |
| PR number | That PR's head vs base |

### 1.2 Gather context (run in parallel)

```bash
git branch --show-current
git remote show origin | grep 'HEAD branch' | awk '{print $NF}'
git merge-base HEAD origin/main   # or origin/master / detected default
git diff --name-only $(git merge-base HEAD origin/<base>)..HEAD
git diff --stat $(git merge-base HEAD origin/<base>)..HEAD
git diff $(git merge-base HEAD origin/<base>)..HEAD
```

If PR mode:

```bash
gh pr view --json number,url,title,baseRefName,headRefName,files
# or: gh pr view <n> --json ...
```

Prefer the PR's `baseRefName` as base when in PR mode.

### 1.3 Changed type-bearing files

Focus on:

- `*.ts`, `*.tsx`, `*.d.ts`
- Schema sources the branch touches: `**/schema.prisma`, Zod schemas, GraphQL SDL, OpenAPI, tRPC routers
- Generated types only if the branch **owns** the generator input (fix the source of truth, then regenerate if the repo has a standard command)

Skip pure assets, lockfiles, migrations SQL (unless types/enums are defined there), and docs unless they embed type contracts.

### 1.4 Stop conditions

| Condition | Action |
|-----------|--------|
| Empty diff | Stop: nothing to harden |
| No TS/schema files in diff | Stop: report no type-bearing changes |
| Cannot detect base | Ask user for base branch |

---

## Phase 2: Inventory Soft Types

Scan **only changed files** (and new symbols they introduce). Read full files when the diff is incomplete context — types often live above the hunk.

### 2.1 Soft-type smells (flag all of these)

| Smell | Examples |
|-------|----------|
| Explicit `any` | `any`, `Array<any>`, `Record<string, any>`, Promise&lt;any&gt; |
| Type erasure | `as any`, `as unknown as T`, double casts, `// @ts-ignore`, unjustified `@ts-expect-error` |
| Lazy non-null | `foo!` used to silence rather than prove presence |
| Unnecessary nullish | `T \| null`, `T \| undefined`, `T \| null \| undefined` when domain always has `T` after success |
| Fake optionals | `foo?: Bar` / `foo: Bar \| undefined` when always required in this flow |
| `Partial` abuse | `Partial<Entity>` for fully loaded entities or API responses |
| Loose bags | `object`, `{}`, `Record<string, unknown>` deep in domain (OK only at raw boundaries before parse) |
| Un-narrowed `unknown` | `unknown` returned or stored without a type guard / schema parse |
| Over-wide primitives | `string` for closed enums/statuses; `number` for fixed unions |
| Soft JSON | `JSON.parse` result used without schema; `any` from HTTP clients |
| Soft returns | Functions returning `T \| undefined` when miss should throw / Result-error |
| Soft params | Optional params added "so call sites compile" |
| Soft Prisma usage | Selecting fewer fields then defaulting; ignoring generated nullability incorrectly |
| Soft React props | Optional props that parent always passes; `children?:` when required by layout |

### 2.2 Search patterns (run over the changed file list)

```bash
# any / casts / ignores (adjust paths to changed files)
rg -n '\bany\b|as any|as unknown as|@ts-ignore|@ts-expect-error' --glob '*.ts' --glob '*.tsx' <files>

# nullish / optional-heavy annotations in the diff
rg -n '\|\s*null|\|\s*undefined|\?:|Partial<|Record<string,\s*(any|unknown)>' --glob '*.ts' --glob '*.tsx' <files>
```

Also read the full diff for newly introduced soft types that regex might miss (inferred `any` from untyped params, missing return types that become soft, etc.).

### 2.3 Build the inventory table

For each finding:

| Field | Content |
|-------|---------|
| File:line | Location |
| Soft form | Current annotation / inference |
| Symbol | Function, field, prop, generic |
| Why soft | any / nullish / Partial / … |
| Suspected hard type | Best guess before schema pass |
| Boundary? | Is this an I/O boundary (HTTP, env, DB raw, form)? |

---

## Phase 3: Ground Truth (Schema & Contracts)

For **each** inventory item, determine the real hard shape. Do not guess from local convenience.

### 3.1 Lookup order (stop when definitive)

1. **Database / Prisma** — model fields, `?` nullability, enums, relations in `schema.prisma` (and related generators)
2. **Validation schemas** — Zod / Yup / class-validator / custom parsers colocated with the API
3. **API contracts** — tRPC procedures, OpenAPI, GraphQL, shared DTO packages
4. **Domain types** — existing entities in `libs/**`, branded types, event payloads
5. **Auth / session** — what is guaranteed after middleware (e.g. `orgId` always present when authenticated)
6. **Call graph on this branch** — who constructs the value; what is proven after a successful path

### 3.2 Nullability rules

| Reality | Hard type |
|---------|-----------|
| Column/field required in DB + always selected | `T` (not `T \| null`) |
| Column nullable in DB | `T \| null` at the **DB/result** layer only |
| Lookup may miss | `T \| null` or `Result` **at the lookup**; after guard/throw, inner type is `T` |
| Authenticated context field always set | required on `AuthenticatedSession` (not optional on a generic session) |
| Form draft vs submitted entity | **Two types**: `DraftX` (soft) vs `X` (hard) — never one soft type for both |
| JSON column with known shape | parse to exact interface; do not leave as `Prisma.JsonValue` in domain |

### 3.3 Boundaries vs core

- **Boundaries** (HTTP body, query, env, `JSON.parse`, third-party SDK): may start as `unknown` / soft → **must parse once** into a hard type.
- **Core domain / UI after load**: only hard types. No `any`, no cascading `?.` / `??` for required invariants.

If a soft type exists only so a boundary can be lazy, introduce:

```ts
// boundary
function parseInput(raw: unknown): HardInput { /* zod/schema; throw on fail */ }

// core
function handle(input: HardInput): HardResult { /* no nullish soup */ }
```

---

## Phase 4: Plan Hard Types

Before editing, produce a short plan (user-visible for large PRs; silent for tiny ones).

For each finding:

1. **Exact hard type** — field-by-field if needed (`{ id: string; email: string }`, `LoanStatus`, `AuthenticatedSession`, …)
2. **Where defined** — existing type to reuse vs new named type (prefer reuse)
3. **Where to narrow** — single validation boundary
4. **Call-site impact** — files that must drop `??`, `?.`, `!`, `as any`, or optional chaining
5. **Intentional soft?** — only if product truly allows absence (document why)

### 4.1 Forbidden "fixes"

Never ship any of these as the solution:

- `any`, `as any`, `as unknown as T` without a real refine
- Widening to `string | number | boolean | null | undefined` to silence errors
- Making more fields optional so call sites compile
- Blanket `!` without a proven invariant
- `@ts-ignore` / empty `@ts-expect-error`
- Replacing hard errors with `?? default` for required data

### 4.2 Preferred patterns

| Situation | Pattern |
|-----------|---------|
| Resource may be missing | `findX(): Promise<X \| null>` then `if (!x) throw/404`; later `X` |
| Create vs entity | `CreateXInput` vs `X` |
| Patch endpoint | `PatchX` / `Partial<Pick<X, ...>>` **only** at patch boundary |
| Status / kind fields | string literal unions or enums matching DB enum |
| Lists that are never null | `T[]` (empty array OK); not `T[] \| null` unless API distinguishes |
| Errors | throw or discriminated union `{ ok: true; data: T } \| { ok: false; error: E }` — not silent empty success |

---

## Phase 5: Apply Type Fixes

Edit in this order to reduce thrash:

1. **Schema / shared contracts** (Prisma enum usage, Zod, shared DTO packages the branch already touches)
2. **Domain type definitions** (interfaces, types, branded IDs)
3. **Function signatures** (params + return types explicit and hard)
4. **Component props** (required vs optional aligned with real usage)

### 5.1 Mechanics

- Prefer **named types** over large inline unions repeated everywhere.
- Match existing project conventions (type vs interface, Zod inference `z.infer<typeof Schema>`, Prisma generated types).
- If Prisma nullability is wrong relative to DB, **do not lie in TS** — fix schema/migration only if the branch already owns that concern; otherwise type the query result honestly and narrow.
- Remove redundant optional markers when the parent type is only used post-validation.

### 5.2 Generated clients

If the monorepo uses Prisma/GraphQL codegen:

- Change the **source** (schema, zod, openapi).
- Run the repo's standard generate command only when needed (`yarn prisma:sync`, project-specific codegen, etc.).
- Do not hand-edit generated files.

---

## Phase 6: Fix Call Sites & Runtime

Hard types will surface real errors — that is the point. Fix them properly.

### 6.1 Replace soft runtime patterns

| Before (soft) | After (hard) |
|---------------|--------------|
| `user?.orgId ?? ''` | Ensure `user: AuthenticatedUser` with `orgId: string`; use `user.orgId` |
| `as SomeType` | Parse/validate or fix the producer type |
| `data: any` from fetch | Typed client / zod parse of response |
| `fn(x?: T)` | `fn(x: T)` + fix callers |
| `return null` on impossible branch | `throw new Error(...)` or exhaustive `never` check |
| `Partial<User>` state for full form | `UserFormState` with explicit optional draft fields only where needed |

### 6.2 Exhaustiveness

- Prefer `switch` on unions with a `default: const _exhaustive: never = x` pattern where the codebase already uses it.
- Do not add `default` that swallows new enum values silently unless product requires it.

### 6.3 Tests

Update tests in the branch that relied on soft types:

- Fixtures must satisfy hard types (full objects, not partials — unless testing the draft path).
- Add/adjust tests that invalid boundary input **rejects**, not soft-succeeds.

---

## Phase 7: Verify

### 7.1 Typecheck affected projects

Prefer Nx (per monorepo Agents.md):

```bash
# Identify projects from changed paths, then:
yarn nx run-many -t typecheck -p <projects>
# or project-specific: yarn nx run web-crm:typecheck / tsc -p ...
```

If no typecheck target, use the package's `tsc --noEmit` / existing CI script.

### 7.2 Loop

While type errors remain that were caused by this hardening:

1. Classify: still-soft type vs real logic bug vs intentional optional
2. Fix hard (never re-introduce `any` to green the build)
3. Re-run typecheck

### 7.3 Lint (optional but recommended)

If eslint has `@typescript-eslint/no-explicit-any` or similar, ensure changed files are clean.

Stop looping if the only remaining errors are **pre-existing on base** and untouched by this skill — note them in the report, do not boil the ocean.

---

## Phase 8: Report

```markdown
## fix-types Report

**Scope**: [branch / PR #] vs [base]
**Files scanned**: [N type-bearing]
**Soft types found**: [N]
**Hardened**: [N]
**Intentional soft left**: [N]
**Call sites updated**: [N]
**Typecheck**: [pass / pass with notes / blocked]

### Hardened

| File | Before | After | Ground truth |
|------|--------|-------|--------------|
| path:line | `orgId?: string` | `orgId: string` on `AuthenticatedSession` | auth middleware always sets org |

### Call-site / runtime fixes

| File | Change |
|------|--------|
| path | Removed `?? ''`; throw if session missing org at boundary |

### Intentional soft types (kept)

| File | Type | Why allowed |
|------|------|-------------|
| path | `deletedAt: Date \| null` | Nullable column; soft-delete |

### Skipped / out of scope

| Item | Reason |
|------|--------|
| Unrelated package soft types | Outside PR diff |

### Follow-ups (if any)

- [ ] e.g. regenerate Prisma client in CI
- [ ] e.g. product decision needed on optional field X
```

---

## Severity / Priority When Triaging

Work in this order:

1. **`any` / type erasure** — always fix
2. **Required domain fields typed optional/nullish** — fix + call sites
3. **Partial / loose records in domain** — replace with exact types
4. **Over-wide string/number** — literal unions / enums
5. **Missing explicit return types** that hide soft inference — add hard returns
6. **Cosmetic** — only if they affect safety

If the PR is huge, fix all `any` + required-nullish first, then continue until typecheck is clean or user stops.

---

## Interaction Rules

1. **Don't ask permission for routine hardening** inside the PR scope (`any` → exact type, remove bogus `\| undefined`, fix call sites).
2. **Do ask** when hardening would change external API contracts, public package exports, or DB schema nullability — present the proposed hard type and wait.
3. **Do ask** when product intent for null vs missing is unclear (e.g. is "no avatar" `null`, omit field, or empty string?).
4. **Never expand scope** into drive-by refactors unrelated to types on this branch.
5. **Align with monorepo rules** — use Nx targets; respect existing validation libraries; no hand-edit of generated clients.

---

## Error Handling

| Error | Action |
|-------|--------|
| No PR and empty/unclear branch diff | Stop and explain |
| Schema file missing / can't find ground truth | Read producers/consumers; if still ambiguous, ask user with options |
| Typecheck target fails for unrelated reasons | Isolate errors from this change; fix only ours; report the rest |
| Hardening breaks a public API the branch didn't mean to change | Revert that surface; propose a follow-up or versioned type |
| User wants one file only | Limit inventory + fixes to that path |

---

## Important Rules

1. **Hard definition of what can be expected** — that is the bar for almost every type.
2. **Rarely** keep `any`, `undefined`, or `null`; when kept, document why in the report.
3. **Schema and contracts win** over local convenience.
4. **Fix the code around the type** so the branch is correctly hard end-to-end.
5. **Never green the build by softening types.**
6. **Never fabricate schema facts** — open the Prisma/Zod/API source.
7. **PR/branch scoped** — leave the rest of the monorepo alone.
8. **Boundary parse once** — core code trusts hard types.
9. **Two types over one soft type** when lifecycle differs (draft vs saved, raw vs parsed, anonymous vs authenticated).
10. **Report clearly** so the user can review intentional soft leftovers.

User arguments: $ARGUMENTS
