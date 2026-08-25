# Personal coding rules (Martin / mrodhansen)

High-signal preferences distilled from PR reviews (mdhenke + self-review), `dot-claude` / `dot-grok`, and agent skills. Prefer these over "make it compile" shortcuts.

**How to use this file (model performance):** keep rules concrete and short. Explore → plan → implement on multi-file work. Verify with typecheck/tests, not vibes. Clear context between unrelated tasks. Prefer subagents for large exploration so the main thread stays for implementation.

---

## Absolute: fail hard, never "make it work"

**Wrong state with a quiet success is worse than a loud failure.**

| Forbidden | Required |
|-----------|----------|
| `try/catch` that returns `null` / `[]` / `true` / fake defaults | Throw or return a typed error with a clear message/code |
| `catch { /* ignore */ }` / log-and-continue on setup paths | Fail the operation; surface `validationError` / non-ready status |
| `as any`, `as unknown as T`, `@ts-ignore` to silence | Fix the real type / parse at the boundary |
| `foo?.bar ?? ''` / `?? 0` on required domain data | Require `T`; narrow once, then use hard types |
| Soft-success setup (e.g. mark `ACTIVE` while A2P/Twilio failed) | Leave non-ready + explicit error; never claim live when side effects failed |
| Auth/permission fail-open (`catch { return true }`) | Fail closed |
| Corrupt/missing crypto or invariant data | Fail closed (no partial decrypt / guess) |

If you find yourself casting through multiple types or piling `any`/`unknown`, **stop and fix the type** (schema, Zod, Prisma select, shared DTO). Soft types cause soft fails.

---

## Absolute: Prisma migrations

### Schema changes — ALWAYS generate (never hand-write DDL)

1. Edit `libs/database/prisma/schema.prisma` only
2. `yarn nx run database:prisma-create-migration --name=descriptive_name`
3. **Review** generated SQL — do **not** edit DDL to "fix" types/defaults
4. `yarn nx run database:prisma-apply-migrations`
5. `yarn nx run database:prisma-check-drift`

**Never** hand-write `CREATE TABLE` / `ALTER` / enums to match Prisma. Drift from hand SQL (`TIMESTAMPTZ` vs `TIMESTAMP(3)`, `gen_random_uuid()` vs client `@default(uuid())`, missing unique migrations) has broken prod.

If Prisma errors: **STOP**, show full output, ask the user. Do not bypass with manual SQL.

No AI/clanker comments in migration SQL. Prefer pure generated output.

### Data migrations — SEPARATE hand-written migration (allowed)

**Only** for data ops Prisma cannot express from schema, e.g.:

- Feature flag seeds / enable / disable / delete rows
- One-off `INSERT` / `UPDATE` / `DELETE` backfills
- Data cleanup required **before** a generated enum rebuild

Pattern used in-repo:

1. Schema/enum change → **generated** migration (`…_add_…` / `…_feature_flag_audit_cleanup`)
2. Seeds/data → **separate** hand-written migration (`…_seed_feature_flags`, `…_seed_…_flag`, `…_reenable_…`)

Name data migrations clearly (`seed_`, `delete_…_rows`, `backfill_`). Keep them idempotent when possible (`ON CONFLICT`, guarded deletes). Do **not** mix large seed SQL into a generated schema migration.

---

## Types (hard by default)

- Prefer exact types from Prisma, Zod, and tRPC contracts.
- Closed statuses → Prisma `enum` or TS union, not free `String` / `TEXT`.
- `null` / `undefined` / `Partial` / optional fields only when the domain truly allows absence.
- Boundaries (`JSON.parse`, HTTP, SDK): start `unknown` → **parse once** (Zod) → hard type in core.
- `createMany` does **not** apply Prisma client `@default(uuid())` — use nested `create` or pass `id` explicitly.
- Type external errors when possible; put magic error codes in named consts.
- Reuse shared packages (e.g. encryption) — don't reimplement.

---

## Backend / multi-tenant / AuthZ

- Every tenant-scoped query/update/delete filters by `tenantId` (id alone is not enough).
- **Tenant membership ≠ authorization.** Reuse existing assignment/role gates (`authorizeLoanAccess`, etc.). In-tenant IDOR is a blocker.
- Shared global resources (phone SIDs, E.164 on a master account, etc.) need **global** uniqueness + atomic claim (`updateMany` where unassigned, transactions) — not check-then-act.
- Enforce invariants in the DB (unique indexes) where races exist; app checks alone are insufficient.
- Zod partial updates: coerce `''` → `null` only; **never** map missing keys to `null` (wipes fields on partial PATCH).
- FE↔BE: **tRPC only** (no new RTK Query / ad-hoc axios API layers for CRM).
- Terminalize state machines (campaigns, queues): skipped/deduped work must leave rows in a terminal state so finalize isn't stranded on `PENDING`.

---

## Frontend / React

- Drive UI from **React state/query**, not module-level `let` mutated in effects (won't re-render).
- Waiting/polling UIs: hard timeout + recovery path (manual confirm / fail + toast). Cancel must clear server pending state when it would accept late webhooks.
- Don't clear a good prior value (verified SID, etc.) until the new flow **succeeds**.
- Extract calc/format out of JSX; keep templates as templates. Prefer numbers in form state over string split/replace soup.
- When introducing a shared component, migrate call sites you touch — no half-shared systems.
- Image/remote assets: `onError` fallbacks; trim empty src; wait for CDN base before painting relative keys.
- web-crm z-index: follow `apps/web-crm/AGENTS.md` (no `z-[9999]`).
- Tailwind: config tokens only (no arbitrary colors/spacing).

---

## Completeness & dual paths

Before calling done, check **all consumers**: list + detail, CRM + funnel, import + export, worker + cron, seed + prod path. Write-only fields and "fixed one path" are incomplete.

Dual surfaces must stay consistent (same auth, same types, same status meaning).

---

## Code taste (from human review)

- Delete dead params/code; don't leave unused knobs.
- Prefer boring direct code over clever fallbacks and number↔status maps nobody can read.
- Don't grow god-files past ~1k lines without extracting.
- No spaghetti special-cases in unrelated flows — push into a named helper/policy.
- Search existing patterns before new files/abstractions.
- Constants over magic strings/numbers (Twilio codes, status literals).

---

## Verify before done

```bash
yarn nx run-many -t typecheck   # affected at minimum
yarn nx run-many -t test        # affected
yarn nx run database:prisma-check-drift   # if schema touched
```

- Prefer focused tests that **fail** if the bug returns (mention create, authz deny, unique conflict, partial update omit).
- Do not ship tests that only assert happy-path fixtures and cannot catch soft-success.

---

## Absolute: Docker rebuild (oh-heck and similar)

When shipping UI/API changes via Docker, **always destroy and rebuild** — never `up --build` alone (cache lies).

```bash
docker compose down
docker compose build --no-cache
docker compose up -d
```

Only use `down -v` when the user also wants the DB volume wiped.

---

## Communication

- Concise. Diffs and verification steps over essays.
- PR/issue numbers as links: `[#1234](https://github.com/Future-Mortgage/monorepo/pull/1234)`.
- Report: what changed, how to verify, residual risk.
- Never commit secrets; never push main; never `--no-verify` unless asked.

---

## Recurring PR failure patterns (self-check)

Before finishing a feature, mentally run:

1. **R1** Soft failure looks like success  
2. **R2** Write-only / incomplete E2E wiring  
3. **R3** App-only invariants & races (need DB unique / tx)  
4. **R4** Thin AuthZ (tenant-only)  
5. **R5** Form mount/hydration wipes real data  
6. **R6** Dual-path inconsistency  
7. **R7** Partial update / envelope / type lies  
8. **R8** UX stuck states (no timeout/recovery)  
9. **R9** Scope/consistency (half migration, dead code)

When in doubt: hard fail with a good error, or fix the type — never paper over it.

---

## Oh Heck prod (Pages + Fly + Neon)

Runbook is the repo file `/Users/mrodhansen/projects/oh-heck/AGENTS.md`. Short version: `cd backend && fly deploy` (release_command migrates Neon), then push `main` for GitHub Pages. API first, frontend second.
