---
description: Create or destroy an isolated git worktree of the Future Mortgage monorepo that runs front-end and back-end on alternate ports (own Postgres DB + Redis DB index) so multiple full stacks can run at once. Remaining args after create are a follow-on coding task — do that immediately in the worktree, do not stop after setup. Use when the user runs /monorepo-worktree, /monorepo-worktree destroy|remove|teardown, asks to "spin up a worktree", "run a second stack", "parallel monorepo", "worktree on new ports", or needs a second seeded local environment without stopping the primary checkout. Do NOT use for a code-only PR/branch checkout — that is /worktree-quick.
---

# /monorepo-worktree

Create **or destroy** a parallel monorepo checkout that coexists with the primary
stack (`:3000` / `:3001` / `:4201`).

Code-only PR/branch checkout (no env/DB/seed): `/worktree-quick`.

User arguments: `$ARGUMENTS`

## Commands

| User says | Action |
|-----------|--------|
| `/monorepo-worktree` / `create` / `setup` | Create + seed + report how to serve |
| `/monorepo-worktree <task>` | Create (defaults) then **immediately do the task** in the worktree |
| `/monorepo-worktree destroy` / `remove` / `teardown` / `rm` | Stop processes, drop DB, remove worktree |
| `/monorepo-worktree list` | Show worktrees, slots, ports, what is listening |

## Parse `$ARGUMENTS` — then do not stall

Classify the first tokens, leftover text is the **follow-on task**:

| Pattern | Action |
|---------|--------|
| `destroy` / `remove` / `teardown` / `rm` … | Destroy. No create. No coding task. |
| `list` | List only. |
| `create` / `setup` (optional), optional slot int, optional git ref, optional name, **rest** | Create. `rest` is the task. |
| Anything else (multi-word, or a single non-verb token) | Create with defaults, whole string is the task. |

Examples:

- `implement fees page polish` → slot `1`, ref `HEAD`, name slug from task, then implement that
- `2 feature/foo my-feature fix login OTP` → slot 2, that ref/name, task `fix login OTP`
- (empty) → create slot 1, report URLs, **stop**

Defaults when unspecified: slot `1`, ref `HEAD`, name `slot-1` **or** a `[a-z0-9-]{1,32}` slug from the task. **Do not ask** for slot/branch/name. Ask only if the chosen slot’s ports are busy (then next free slot ≥1) or a destroy target is ambiguous.

### Model split (Claude Code)

- **You** (session model) parse `$ARGUMENTS` into slot / ref / name / task.
- **Haiku subagent** (Agent tool, `model: "haiku"`) does the mechanical part: port check, `setup-worktree.sh`, or the whole `destroy` / `list`. Tell it to follow `~/.ai/commands/monorepo-worktree.md` with the parsed slot/ref/name, and to return worktree path, slot, ports/URLs, and exit status (or the last ~50 lines of output on failure). It does not edit code or improvise around a failed step.
- **You** then start `./serve-worktree.sh` in the background (your session owns that process) and do the follow-on task. On subagent failure, diagnose it yourself; don't blindly re-delegate.

If you **are** that subagent, skip this section and run the steps directly — do not delegate again.

### HARD RULE: setup is a prefix, not the job

If a follow-on task exists, **you (this same session) start it the moment the setup subagent reports `setup-worktree.sh` exited 0.**

After setup succeeds:

1. Start `./serve-worktree.sh` **background only** (`background: true` / do not wait for exit). Never foreground. Coding does not depend on serve.
2. Optional health check: poll API **≤90s**, then continue even if still warming. Never poll forever.
3. `cd` to the worktree path. **Immediately implement the task.** All edits / git / yarn / nx happen in `$WT`, not the primary checkout.
4. One-line URL/path note is fine. Then keep working.

**Forbidden** when a follow-on task exists:

- Ending the turn after create with only URLs, credentials, or a destroy command
- Asking “want me to start on X?” / “should I continue?”
- Asking for slot, branch, or name
- Spawning a subagent for the task and then idling
- Waiting on `serve-worktree.sh`, webpack compile, or health as if that were the deliverable

## Default ports (primary = slot 0)

| Service    | Primary | Slot 1 | Slot 2 | Slot N        |
|------------|---------|--------|--------|---------------|
| web-crm    | 3000    | 3100   | 3200   | 3000 + N×100  |
| server-crm | 3001    | 3101   | 3201   | 3001 + N×100  |
| web-funnel | 4201    | 4301   | 4401   | 4201 + N×100  |
| Postgres   | dbname  | dbname_wt1 | dbname_wt2 | dbname_wtN |
| Redis DB # | 0       | 1      | 2      | N             |
| Cookie     | auth-token | auth-token-wt1 | … | auth-token-wtN |
| Node inspect | 9229  | 9230   | 9231   | 9229 + N      |

CRM URL for slot N: `http://fm.futurewholesale.local:{WEB_PORT}`

---

## Create (setup)

### When to use

- User wants a second (or third) local stack while primary is already running
- Feature work that needs a clean seeded DB without touching primary data
- Side-by-side UI comparison across branches

### Prerequisites

1. Primary monorepo has working `.env` + `.env.local` (source of secrets)
2. Docker containers running: `future-mortgage-postgres`, `future-mortgage-redis`
3. Hosts file already has tenant subdomains (same as primary):
   `127.0.0.1 fm.futurewholesale.local` (and other tenants as needed)
4. Slot ports are free (`lsof -nP -iTCP:3100 -sTCP:LISTEN` etc.)

### Fast path (preferred)

From inside the **primary** monorepo (or any of its worktrees). Skill is
**user-scoped** at `~/.ai/oc_skills/monorepo-worktree/` (not in the repo).

```bash
# Slot 1 from current HEAD, name "slot-1"
~/.ai/oc_skills/monorepo-worktree/scripts/setup-worktree.sh 1

# Slot 2 from a branch, custom name
~/.ai/oc_skills/monorepo-worktree/scripts/setup-worktree.sh 2 feature/foo my-feature

# Or pin the repo explicitly:
MONOREPO_ROOT=/path/to/monorepo ~/.ai/oc_skills/monorepo-worktree/scripts/setup-worktree.sh 1
```

Script will:

1. `git worktree add` under `../worktrees/monorepo-<name>`
2. Copy env files from primary
3. Create Postgres DB `dbname_wt{N}`
4. Rewrite port / DB / Redis / cookie / FRONTEND_URL values
5. Patch webpack + vite + `web-crm` project.json for env-aware ports (worktree-local)
6. `yarn install` (own `node_modules`; husky postinstall wires pre-push; do not skip yarn; do not symlink from primary) → `yarn prisma:sync` → `yarn nx run database:seed`
7. Write `serve-worktree.sh` and `.worktree-slot` marker

Then start **in the background** (never wait for this process to exit):

```bash
cd ../worktrees/monorepo-slot-1   # or the path printed by the script
./serve-worktree.sh
```

If a follow-on task exists, start serve in background and **begin the task immediately**. Do not wait for compile/health.

Verify:

```bash
curl -s http://localhost:3101/health   # slot 1 API
curl -s -o /dev/null -w "%{http_code}\n" http://localhost:3100/
curl -s -o /dev/null -w "%{http_code}\n" http://localhost:4301/apply/
# Primary must still be up:
curl -s http://localhost:3001/health
```

### Agent checklist — create

1. **Parse** `$ARGUMENTS` (see above). Do **not** ask for slot/branch/name — default them.
2. **Confirm** target slot ports are free (`lsof` / curl). If busy, use the next free slot ≥1.
3. **Run** `~/.ai/oc_skills/monorepo-worktree/scripts/setup-worktree.sh` (preferred) **or** the manual steps below — via the Haiku subagent (steps 2–3; see Model split).
4. **Start** `./serve-worktree.sh` in the worktree **in the background**. Never foreground. Never wait for exit.
5. **Health** (optional, ≤90s): new API port + primary `:3001` still responds. On timeout, continue.
6. **No follow-on task:** report URLs, credentials, path, destroy command, **stop**.
7. **Follow-on task:** one-line path + URLs, then **immediately implement the task in `$WT`** (this session, not a subagent). Do not stop. Do not ask.

### Credentials (same as primary after seed)

| Role  | Email | Password | OTP |
|-------|-------|----------|-----|
| Dev   | `martin.hansen@trygenius.ai` | `admin123` | `1111` |
| Admin | `admin@fm.com` | `admin123` | `1111` |

Tenant CRM: `http://fm.futurewholesale.local:{WEB_PORT}`

---

## Destroy / remove / teardown

Use when the user says any of: `destroy`, `remove`, `teardown`, `rm`, `clean up worktree`,
`kill the worktree stack`, `shut down slot N`.

### Fast path (preferred)

From inside the monorepo (or set `MONOREPO_ROOT`). Scripts live at
`~/.ai/oc_skills/monorepo-worktree/scripts/`.

```bash
# List what exists (no changes)
~/.ai/oc_skills/monorepo-worktree/scripts/destroy-worktree.sh list

# Destroy slot 1 (stops ports, flushes redis DB 1, drops dbname_wt1, removes worktree + branch)
~/.ai/oc_skills/monorepo-worktree/scripts/destroy-worktree.sh destroy 1 --yes

# Same aliases
~/.ai/oc_skills/monorepo-worktree/scripts/destroy-worktree.sh remove 1 --yes
~/.ai/oc_skills/monorepo-worktree/scripts/destroy-worktree.sh teardown --name slot-1 --yes
~/.ai/oc_skills/monorepo-worktree/scripts/destroy-worktree.sh --path ../worktrees/monorepo-slot-1 --yes

# Destroy every monorepo-* under ../worktrees/
~/.ai/oc_skills/monorepo-worktree/scripts/destroy-worktree.sh --all --yes
```

### Flags

| Flag | Effect |
|------|--------|
| `--yes` / `-y` | Required in non-interactive agent shells; skip prompt |
| `--force` | `git worktree remove --force` (discard dirty worktree files) |
| `--keep-db` | Do not `DROP DATABASE dbname_wtN` |
| `--keep-branch` | Do not delete `worktree/<name>` branch |
| `--keep-redis` | Do not `FLUSHDB` on the slot's Redis logical DB |

Default destroy is **full cleanup**: stop processes + flush redis slot + drop DB + remove worktree dir + delete `worktree/*` branch.

### Destroy order (script guarantees this order)

1. **Resolve target(s)** from slot / name / path / `--all` using `.worktree-slot` marker when present
2. **Safety checks** (refuse primary path, primary ports, primary DB name `dbname`)
3. **Stop listeners** on worktree ports only (`WEB` / `API` / `FUNNEL` / inspect)
4. **Best-effort kill** node/yarn/nx processes whose cwd is under the worktree (covers parent `nx run-many`)
5. **Redis** `FLUSHDB` on logical DB `N` (slot index) — not DB 0
6. **Postgres** terminate backends on `dbname_wtN`, then `DROP DATABASE`
7. **`git worktree remove`** (retry with `--force` if needed; prune)
8. **Delete local branch** `worktree/<name>` if it exists and is not checked out elsewhere
9. **Verify** primary ports untouched; print remaining `git worktree list`

### Hard safety rules (never violate)

- **Never** kill ports `3000`, `3001`, `4201` (primary stack)
- **Never** `DROP DATABASE dbname` (only `dbname_wt[1-9]…`)
- **Never** remove the primary monorepo checkout path
- **Never** flush Redis logical DB `0`
- If `.worktree-slot` is missing, still allow destroy when path is under `../worktrees/monorepo-*` and ports can be inferred from slot name `slot-N`

### Agent checklist — destroy

1. **Parse intent**: `destroy` / `remove` / `teardown` / `list`.
2. **Identify target**: slot number, name, path, or `--all`. If ambiguous, run `list` and ask.
3. **If user has uncommitted feature work** only in that worktree: warn and prefer `--keep-branch` or confirm `--force`.
4. **Run** `~/.ai/oc_skills/monorepo-worktree/scripts/destroy-worktree.sh … --yes` (agents are non-interactive).
5. **Verify**:
   - Worktree ports no longer listening
   - `git worktree list` no longer shows the path
   - `dbname_wtN` gone (unless `--keep-db`)
   - Primary `:3001/health` still OK if primary was running
6. **Report** what was stopped, dropped, and removed.

### Manual destroy (if script unavailable)

```bash
PRIMARY="$(git rev-parse --show-toplevel)"
# if already inside a worktree, use git common dir:
# PRIMARY="$(dirname "$(git rev-parse --path-format=absolute --git-common-dir)")"
WT="$(dirname "$PRIMARY")/worktrees/monorepo-slot-1"
SLOT=1
WEB=$((3000 + SLOT*100)); API=$((3001 + SLOT*100)); FUNNEL=$((4201 + SLOT*100))
DB="dbname_wt${SLOT}"

# 1) Stop serve processes on worktree ports ONLY
for p in $WEB $API $FUNNEL; do
  lsof -nP -iTCP:$p -sTCP:LISTEN -t | xargs -r kill -TERM 2>/dev/null || true
done
sleep 1
for p in $WEB $API $FUNNEL; do
  lsof -nP -iTCP:$p -sTCP:LISTEN -t | xargs -r kill -KILL 2>/dev/null || true
done

# 2) Flush redis logical DB for slot (not 0)
docker exec future-mortgage-redis redis-cli -n "$SLOT" FLUSHDB

# 3) Drop isolated DB only
docker exec -e PGPASSWORD=dbpassword future-mortgage-postgres \
  psql -U dbuser -d postgres -c \
  "SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname='${DB}' AND pid<>pg_backend_pid();"
docker exec -e PGPASSWORD=dbpassword future-mortgage-postgres \
  psql -U dbuser -d postgres -c "DROP DATABASE IF EXISTS ${DB};"

# 4) Remove worktree + branch
git -C "$PRIMARY" worktree remove --force "$WT" || {
  rm -rf "$WT"
  git -C "$PRIMARY" worktree prune
}
git -C "$PRIMARY" branch -D "worktree/slot-${SLOT}" 2>/dev/null || true

# 5) Confirm primary still up
curl -s http://localhost:3001/health || true
git -C "$PRIMARY" worktree list
```

---

## Manual create process (if setup script unavailable)

### 1. Create worktree

```bash
PRIMARY="$(git rev-parse --show-toplevel)"
mkdir -p "$(dirname "$PRIMARY")/worktrees"
# Cannot check out the same branch in two worktrees — use a new branch name
git worktree add -b worktree/slot-1 \
  "$(dirname "$PRIMARY")/worktrees/monorepo-slot-1" HEAD
WT="$(dirname "$PRIMARY")/worktrees/monorepo-slot-1"
```

### 2. Copy env files from primary

```bash
cp "$PRIMARY/.env" "$WT/.env"
cp "$PRIMARY/.env.local" "$WT/.env.local"
cp "$PRIMARY/apps/web-crm/.env.local" "$WT/apps/web-crm/.env.local"
cp "$PRIMARY/apps/web-funnel/.env.local" "$WT/apps/web-funnel/.env.local"
cp "$PRIMARY/apps/server-crm/.env.local" "$WT/apps/server-crm/.env.local"
```

### 3. Create isolated database

```bash
docker exec -e PGPASSWORD=dbpassword future-mortgage-postgres \
  psql -U dbuser -d postgres \
  -c "CREATE DATABASE dbname_wt1 OWNER dbuser;"
```

Reuse the same Postgres **container** and Redis **container**; only change
DB name / Redis logical DB index so data and job queues do not collide.

### 4. Rewrite env for slot ports

In `$WT/.env` set (slot 1 example):

```bash
PORT=3101
ADMIN_URL=http://localhost:3100/admin
WEB_FUNNEL_URL=http://localhost:4301
WEB_CRM_PORT=3100
WEB_FUNNEL_PORT=4301
REDIS_URL=redis://localhost:6379/1
DB_NAME=dbname_wt1
DATABASE_URL=postgresql://dbuser:dbpassword@localhost:5432/dbname_wt1
NX_PUBLIC_API_URL=http://localhost:3101
NX_PUBLIC_SERVER_CRM_SOCKET_URL=http://localhost:3101
SESSION_COOKIE_NAME=auth-token-wt1
```

In `$WT/.env.local`:

```bash
FRONTEND_URL=http://fm.futurewholesale.local:3100
# Leave BASE_URL (ngrok) alone unless you open a second tunnel to :3101
```

Write app-local env (Vite only loads env from the app directory):

`apps/web-crm/.env.local`:

```bash
PORT=3100
WEB_CRM_PORT=3100
WEB_FUNNEL_URL=http://localhost:4301
WEB_FUNNEL_PORT=4301
NX_PUBLIC_API_URL=http://localhost:3101
NX_PUBLIC_SERVER_CRM_SOCKET_URL=http://localhost:3101
NX_PUBLIC_ENV=local
```

`apps/web-funnel/.env.local`:

```bash
WEB_FUNNEL_PORT=4301
PORT=4301
NX_PUBLIC_API_URL=http://localhost:3101
NX_PUBLIC_ENV=local
```

### 5. Make front-end ports env-aware (worktree-local)

**Do not commit these with feature work** unless promoting env-aware defaults.

`apps/web-crm/webpack.config.js` — `devServer.port` and `/apply` proxy:

```js
port: Number(process.env.PORT || process.env.WEB_CRM_PORT || 3000),
// ...
target:
  process.env.WEB_FUNNEL_PROXY_TARGET ||
  process.env.WEB_FUNNEL_URL ||
  'http://localhost:4201',
```

`apps/web-funnel/vite.config.ts` — `server.port` / `preview.port`:

```ts
port: Number(process.env.WEB_FUNNEL_PORT || process.env.PORT || 4201),
```

`apps/web-crm/project.json` serve env:

```json
"PORT": "3100",
"WEB_CRM_PORT": "3100",
"WEB_FUNNEL_URL": "http://localhost:4301",
"WEB_FUNNEL_PORT": "4301"
```

### 6. Install, migrate, seed

```bash
cd "$WT"
# If leftover node_modules symlink from older setup: rm -f node_modules
yarn install   # own node_modules; husky postinstall — do not skip
yarn prisma:sync
yarn nx run database:seed
```

### 7. Serve

```bash
export PORT=3101 WEB_CRM_PORT=3100 WEB_FUNNEL_PORT=4301
export WEB_FUNNEL_URL=http://localhost:4301
export NX_PUBLIC_API_URL=http://localhost:3101
export NX_PUBLIC_SERVER_CRM_SOCKET_URL=http://localhost:3101
export DATABASE_URL=postgresql://dbuser:dbpassword@localhost:5432/dbname_wt1
export REDIS_URL=redis://localhost:6379/1
export SESSION_COOKIE_NAME=auth-token-wt1
export FRONTEND_URL=http://fm.futurewholesale.local:3100
export NODE_OPTIONS="--inspect=9230"

yarn nx run-many --target=serve
```

---

## Do not

- Point the worktree at the primary `DATABASE_URL` (`dbname`) if you plan to seed or migrate
- Reuse `SESSION_COOKIE_NAME=auth-token` across slots on the same host
- Commit worktree-only port patches / `.env*` / `serve-worktree.sh` / `.worktree-slot` as feature commits
- Use preview_* tools (subdomain tenancy requires `*.futurewholesale.local`)
- Run destroy against the primary checkout or ports 3000/3001/4201
- Drop `dbname` when tearing down a worktree
- Stop after setup when `$ARGUMENTS` still contains a coding task
- Run `./serve-worktree.sh` in the foreground, or wait on health/compile before starting a follow-on task
- Ask for slot/branch/name when defaults work
- Edit files in the primary checkout after create — work in `$WT`

## Why each isolation knob

| Knob | Why |
|------|-----|
| Ports | Avoid EADDRINUSE against primary webpack/vite/node |
| Separate Postgres DB | Safe migrate/seed without wiping primary data |
| Redis DB index | BullMQ / cache keys do not steal jobs from primary |
| SESSION_COOKIE_NAME | Browser cookies ignore port; same name collides on `*.futurewholesale.local` |
| FRONTEND_URL | Server redirects / emails must hit this slot’s web port |
| NX_PUBLIC_API_URL / SOCKET | Browser must talk to this slot’s API |
| WEB_FUNNEL_URL | web-crm `/apply` proxy + server funnel links |
| Node inspect port | Primary already binds `9229` |

## Notes from first successful dry-run (slot 1)

- Worktree path: `../worktrees/monorepo-slot-1`
- Both stacks healthy simultaneously: primary `3000/3001/4201` + worktree `3100/3101/4301`
- API health: `{"status":"healthy","database":"connected",...}`
- Seed: `yarn nx run database:seed` against `dbname_wt1` succeeds with standard tenants
- Inspector warning `Starting inspector on localhost:9229 failed` is expected if primary is up — set `NODE_OPTIONS=--inspect=9230` (setup script does this)
- Empty `apps/*/.env.local` in primary is fine; setup overwrites worktree app env with port wiring

## Optional: promote env-aware ports to main

If the team wants worktrees without patching configs every time, land this on main (backwards-compatible defaults):

1. `apps/web-crm/webpack.config.js` — read `PORT` / `WEB_CRM_PORT` / `WEB_FUNNEL_URL`
2. `apps/web-funnel/vite.config.ts` — read `WEB_FUNNEL_PORT` / `PORT`

Then the setup script only needs env rewrites + DB create + install/seed.

User arguments: $ARGUMENTS
