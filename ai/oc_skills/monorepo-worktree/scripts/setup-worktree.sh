#!/usr/bin/env bash
# setup-worktree.sh — Create an isolated monorepo worktree on alternate ports.
#
# Usage:
#   ./setup-worktree.sh <slot> [branch] [worktree-name]
#
# Examples:
#   ./setup-worktree.sh 1
#   ./setup-worktree.sh 2 feature/my-branch my-feature
#   ./setup-worktree.sh 1 HEAD immutable-email
#
# Slot 0 is reserved for the primary checkout (ports 3000/3001/4201).
# Slot N (>=1) uses:
#   web-crm     = 3000 + N*100
#   server-crm  = 3001 + N*100
#   web-funnel  = 4201 + N*100
#   postgres DB = dbname_wt{N}
#   redis DB #  = N
#   cookie name = auth-token-wt{N}
#
# Prerequisites: docker postgres (future-mortgage-postgres), redis, yarn, git.
# Env sources: copies .env / .env.local from the primary monorepo checkout.

set -euo pipefail

SLOT="${1:-}"
BRANCH_OR_REF="${2:-HEAD}"
NAME="${3:-slot-${SLOT}}"

if [[ -z "${SLOT}" || ! "${SLOT}" =~ ^[1-9][0-9]*$ ]]; then
  echo "Usage: $0 <slot>=1..N [branch|ref=HEAD] [name=slot-N]"
  echo "  Slot must be an integer >= 1 (slot 0 = primary checkout)."
  exit 1
fi

# Resolve primary monorepo (user-scoped skill — do NOT use script path).
# Priority: MONOREPO_ROOT env → cwd git common dir → cwd toplevel
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
resolve_primary() {
  if [[ -n "${MONOREPO_ROOT:-}" && -d "${MONOREPO_ROOT}" ]]; then
    echo "$(cd "${MONOREPO_ROOT}" && pwd)"
    return 0
  fi
  local common
  if common="$(git rev-parse --path-format=absolute --git-common-dir 2>/dev/null)"; then
    # common dir is <repo>/.git (or .git file target); primary checkout is parent of .git
    local root
    root="$(dirname "${common}")"
    # If we're inside a linked worktree, common dir still points at main .git
    # Prefer the main worktree path from worktree list (first entry)
    local main_wt
    main_wt="$(git worktree list --porcelain 2>/dev/null | awk '/^worktree /{print $2; exit}')"
    if [[ -n "${main_wt}" && -d "${main_wt}" ]]; then
      echo "${main_wt}"
      return 0
    fi
    echo "${root}"
    return 0
  fi
  echo "ERROR: cannot resolve monorepo root. cd into the monorepo or set MONOREPO_ROOT." >&2
  return 1
}
PRIMARY="$(resolve_primary)"

WORKTREES_ROOT="$(dirname "${PRIMARY}")/worktrees"
WT_PATH="${WORKTREES_ROOT}/monorepo-${NAME}"
BRANCH_NAME="worktree/${NAME}"

WEB_PORT=$((3000 + SLOT * 100))
API_PORT=$((3001 + SLOT * 100))
FUNNEL_PORT=$((4201 + SLOT * 100))
DB_NAME="dbname_wt${SLOT}"
REDIS_URL="redis://localhost:6379/${SLOT}"
COOKIE="auth-token-wt${SLOT}"
INSPECT_PORT=$((9229 + SLOT))

echo "═══════════════════════════════════════════════════════════"
echo " Monorepo worktree setup"
echo "═══════════════════════════════════════════════════════════"
echo "  slot:        ${SLOT}"
echo "  name:        ${NAME}"
echo "  path:        ${WT_PATH}"
echo "  base ref:    ${BRANCH_OR_REF}"
echo "  branch:      ${BRANCH_NAME}"
echo "  web-crm:     http://fm.futurewholesale.local:${WEB_PORT}"
echo "  server-crm:  http://localhost:${API_PORT}"
echo "  web-funnel:  http://localhost:${FUNNEL_PORT}/apply/"
echo "  database:    ${DB_NAME}"
echo "  redis:       ${REDIS_URL}"
echo "  cookie:      ${COOKIE}"
echo "  inspect:     ${INSPECT_PORT}"
echo "═══════════════════════════════════════════════════════════"

# --- port free check ---
for p in "${WEB_PORT}" "${API_PORT}" "${FUNNEL_PORT}"; do
  if lsof -nP -iTCP:"${p}" -sTCP:LISTEN >/dev/null 2>&1; then
    echo "ERROR: port ${p} is already in use. Pick another slot or free the port."
    lsof -nP -iTCP:"${p}" -sTCP:LISTEN || true
    exit 1
  fi
done

# --- create worktree ---
mkdir -p "${WORKTREES_ROOT}"
if [[ -d "${WT_PATH}" ]]; then
  echo "Worktree path already exists: ${WT_PATH}"
  echo "Reusing it (will re-apply env / config patches)."
else
  cd "${PRIMARY}"
  # If BRANCH_OR_REF is an existing local branch name and we want a new worktree branch from it:
  git worktree add -b "${BRANCH_NAME}" "${WT_PATH}" "${BRANCH_OR_REF}"
fi

# --- copy env files from primary ---
copy_env() {
  local src="$1" dest="$2"
  if [[ -f "${src}" ]]; then
    cp "${src}" "${dest}"
    echo "  copied $(basename "${src}") → ${dest}"
  else
    echo "  WARN: missing ${src}"
  fi
}

# Yarn installs a real node_modules in the worktree. Drop a leftover symlink
# from older setup so install does not write into the primary tree.
drop_node_modules_symlink() {
  local dest="${1}/node_modules"
  if [[ -L "${dest}" ]]; then
    rm -f "${dest}"
    echo "  removed leftover node_modules symlink"
  fi
}
echo "Copying env files from ${PRIMARY}..."
copy_env "${PRIMARY}/.env" "${WT_PATH}/.env"
copy_env "${PRIMARY}/.env.local" "${WT_PATH}/.env.local"
copy_env "${PRIMARY}/apps/web-crm/.env.local" "${WT_PATH}/apps/web-crm/.env.local"
copy_env "${PRIMARY}/apps/web-funnel/.env.local" "${WT_PATH}/apps/web-funnel/.env.local"
copy_env "${PRIMARY}/apps/server-crm/.env.local" "${WT_PATH}/apps/server-crm/.env.local"

# --- create isolated postgres database ---
echo "Ensuring postgres database ${DB_NAME}..."
if ! docker ps --format '{{.Names}}' | grep -qx 'future-mortgage-postgres'; then
  echo "ERROR: container future-mortgage-postgres is not running."
  echo "Start it with: docker compose -f docker-compose.database.yml up -d"
  exit 1
fi
EXISTS=$(docker exec -e PGPASSWORD=dbpassword future-mortgage-postgres \
  psql -U dbuser -d postgres -tc "SELECT 1 FROM pg_database WHERE datname = '${DB_NAME}'" | tr -d '[:space:]')
if [[ "${EXISTS}" != "1" ]]; then
  docker exec -e PGPASSWORD=dbpassword future-mortgage-postgres \
    psql -U dbuser -d postgres -c "CREATE DATABASE ${DB_NAME} OWNER dbuser;"
  echo "  created ${DB_NAME}"
else
  echo "  ${DB_NAME} already exists"
fi

# --- patch root .env / .env.local ---
python3 - "${WT_PATH}" "${WEB_PORT}" "${API_PORT}" "${FUNNEL_PORT}" "${DB_NAME}" "${SLOT}" "${COOKIE}" <<'PY'
import re, sys
from pathlib import Path

wt, web, api, funnel, db, slot, cookie = sys.argv[1:8]
web, api, funnel, slot = int(web), int(api), int(funnel), int(slot)

def set_kv(text: str, key: str, value: str) -> str:
    pat = re.compile(rf"^{re.escape(key)}=.*$", re.M)
    line = f"{key}={value}"
    if pat.search(text):
        return pat.sub(line, text)
    if text and not text.endswith("\n"):
        text += "\n"
    return text + line + "\n"

env_path = Path(wt) / ".env"
env = env_path.read_text() if env_path.exists() else ""
for k, v in {
    "PORT": str(api),
    "ADMIN_URL": f"http://localhost:{web}/admin",
    "WEB_FUNNEL_URL": f"http://localhost:{funnel}",
    "WEB_CRM_PORT": str(web),
    "WEB_FUNNEL_PORT": str(funnel),
    "REDIS_URL": f"redis://localhost:6379/{slot}",
    "DB_NAME": db,
    "DATABASE_URL": f"postgresql://dbuser:dbpassword@localhost:5432/{db}",
    "NX_PUBLIC_API_URL": f"http://localhost:{api}",
    "NX_PUBLIC_SERVER_CRM_SOCKET_URL": f"http://localhost:{api}",
    "SESSION_COOKIE_NAME": cookie,
}.items():
    env = set_kv(env, k, v)
env_path.write_text(env)

local_path = Path(wt) / ".env.local"
local = local_path.read_text() if local_path.exists() else ""
local = set_kv(local, "FRONTEND_URL", f"http://fm.futurewholesale.local:{web}")
local_path.write_text(local)

# App-local env so Vite/webpack pick up ports without relying on cwd
(Path(wt) / "apps/web-crm/.env.local").write_text(
    f"""PORT={web}
WEB_CRM_PORT={web}
WEB_FUNNEL_URL=http://localhost:{funnel}
WEB_FUNNEL_PORT={funnel}
NX_PUBLIC_API_URL=http://localhost:{api}
NX_PUBLIC_SERVER_CRM_SOCKET_URL=http://localhost:{api}
NX_PUBLIC_ENV=local
"""
)
(Path(wt) / "apps/web-funnel/.env.local").write_text(
    f"""WEB_FUNNEL_PORT={funnel}
PORT={funnel}
NX_PUBLIC_API_URL=http://localhost:{api}
NX_PUBLIC_ENV=local
"""
)
print("  patched .env, .env.local, app .env.local files")
PY

# --- make webpack + vite + project.json env-aware / slot-ported ---
python3 - "${WT_PATH}" "${WEB_PORT}" "${FUNNEL_PORT}" <<'PY'
from pathlib import Path
import sys, re

wt, web, funnel = sys.argv[1], sys.argv[2], sys.argv[3]
web, funnel = int(web), int(funnel)

# webpack.config.js
wp = Path(wt) / "apps/web-crm/webpack.config.js"
t = wp.read_text()
t2 = re.sub(
    r"port:\s*Number\(process\.env\.PORT \|\| process\.env\.WEB_CRM_PORT \|\| 3000\),|port:\s*3000,",
    "port: Number(process.env.PORT || process.env.WEB_CRM_PORT || 3000),",
    t,
    count=1,
)
t2 = re.sub(
    r"target:\s*\n\s*process\.env\.WEB_FUNNEL_PROXY_TARGET \|\|\n\s*process\.env\.WEB_FUNNEL_URL \|\|\n\s*'http://localhost:4201',|target:\s*'http://localhost:4201',",
    "target:\n          process.env.WEB_FUNNEL_PROXY_TARGET ||\n          process.env.WEB_FUNNEL_URL ||\n          'http://localhost:4201',",
    t2,
    count=1,
)
if t2 != t:
    wp.write_text(t2)
    print("  patched apps/web-crm/webpack.config.js (env-aware ports)")
else:
    # force simple replace if still plain
    if "port: 3000" in t:
        t = t.replace("port: 3000,", "port: Number(process.env.PORT || process.env.WEB_CRM_PORT || 3000),", 1)
        t = t.replace(
            "target: 'http://localhost:4201',",
            "target:\n          process.env.WEB_FUNNEL_PROXY_TARGET ||\n          process.env.WEB_FUNNEL_URL ||\n          'http://localhost:4201',",
            1,
        )
        wp.write_text(t)
        print("  patched apps/web-crm/webpack.config.js")
    else:
        print("  webpack.config.js already env-aware (or unexpected format)")

# vite.config.ts
vt = Path(wt) / "apps/web-funnel/vite.config.ts"
v = vt.read_text()
v2 = v.replace(
    "port: 4201,",
    "port: Number(process.env.WEB_FUNNEL_PORT || process.env.PORT || 4201),",
)
if v2 != v:
    vt.write_text(v2)
    print("  patched apps/web-funnel/vite.config.ts (env-aware ports)")
else:
    print("  vite.config.ts already env-aware (or unexpected format)")

# web-crm project.json — set PORT env for serve target
pj = Path(wt) / "apps/web-crm/project.json"
p = pj.read_text()
p2 = re.sub(r'"PORT":\s*"\d+"', f'"PORT": "{web}"', p)
if '"WEB_FUNNEL_URL"' not in p2:
    p2 = p2.replace(
        f'"PORT": "{web}"',
        f'"PORT": "{web}",\n          "WEB_CRM_PORT": "{web}",\n          "WEB_FUNNEL_URL": "http://localhost:{funnel}",\n          "WEB_FUNNEL_PORT": "{funnel}"',
    )
else:
    p2 = re.sub(r'"WEB_CRM_PORT":\s*"\d+"', f'"WEB_CRM_PORT": "{web}"', p2)
    p2 = re.sub(r'"WEB_FUNNEL_PORT":\s*"\d+"', f'"WEB_FUNNEL_PORT": "{funnel}"', p2)
    p2 = re.sub(
        r'"WEB_FUNNEL_URL":\s*"[^"]*"',
        f'"WEB_FUNNEL_URL": "http://localhost:{funnel}"',
        p2,
    )
if p2 != p:
    pj.write_text(p2)
    print("  patched apps/web-crm/project.json serve ports")
else:
    print("  project.json ports already set")

print(
    "\n  NOTE: webpack/vite/project.json patches are worktree-local infrastructure.\n"
    "  Do NOT commit them with feature work unless promoting env-aware defaults to main."
)
PY

# Write a small marker file (gitignored pattern via name)
cat > "${WT_PATH}/.worktree-slot" <<EOF
SLOT=${SLOT}
NAME=${NAME}
WEB_PORT=${WEB_PORT}
API_PORT=${API_PORT}
FUNNEL_PORT=${FUNNEL_PORT}
DB_NAME=${DB_NAME}
REDIS_URL=${REDIS_URL}
SESSION_COOKIE_NAME=${COOKIE}
INSPECT_PORT=${INSPECT_PORT}
FRONTEND_URL=http://fm.futurewholesale.local:${WEB_PORT}
CREATED_AT=$(date -u +%Y-%m-%dT%H:%M:%SZ)
EOF
echo "  wrote .worktree-slot"

# --- yarn (husky) + prisma + seed ---
cd "${WT_PATH}"
drop_node_modules_symlink "${WT_PATH}"
echo "yarn install (husky postinstall wires pre-push)..."
yarn install

echo "yarn prisma:sync..."
yarn prisma:sync

echo "yarn nx run database:seed..."
yarn nx run database:seed

echo "yarn nx run database:seed-du-test-cases (Fannie Mae)..."
yarn nx run database:seed-du-test-cases

echo "yarn nx run database:seed-lpa-test-cases (Freddie Mac)..."
yarn nx run database:seed-lpa-test-cases

# --- helper serve script ---
cat > "${WT_PATH}/serve-worktree.sh" <<EOF
#!/usr/bin/env bash
# Start this worktree's stack on its dedicated ports.
set -euo pipefail
cd "\$(dirname "\$0")"
# shellcheck disable=SC1091
set -a
source .env
# .env.local overrides
[[ -f .env.local ]] && source .env.local
set +a
export PORT=${API_PORT}
export WEB_CRM_PORT=${WEB_PORT}
export WEB_FUNNEL_PORT=${FUNNEL_PORT}
export WEB_FUNNEL_URL=http://localhost:${FUNNEL_PORT}
export NX_PUBLIC_API_URL=http://localhost:${API_PORT}
export NX_PUBLIC_SERVER_CRM_SOCKET_URL=http://localhost:${API_PORT}
export DATABASE_URL=postgresql://dbuser:dbpassword@localhost:5432/${DB_NAME}
export REDIS_URL=${REDIS_URL}
export SESSION_COOKIE_NAME=${COOKIE}
export FRONTEND_URL=http://fm.futurewholesale.local:${WEB_PORT}
# Avoid clashing with primary checkout's node inspector on 9229
export NODE_OPTIONS="\${NODE_OPTIONS:-} --inspect=${INSPECT_PORT}"
echo "Starting worktree slot ${SLOT} (all serve targets):"
echo "  CRM     http://fm.futurewholesale.local:${WEB_PORT}"
echo "  API     http://localhost:${API_PORT}"
echo "  Funnel  http://localhost:${FUNNEL_PORT}/apply/"
echo "  Worker  redis DB ${SLOT} (worker-crm)"
exec yarn nx run-many --target=serve
EOF
chmod +x "${WT_PATH}/serve-worktree.sh"

echo ""
echo "═══════════════════════════════════════════════════════════"
echo " DONE — worktree ready"
echo "═══════════════════════════════════════════════════════════"
echo "  cd ${WT_PATH}"
echo "  ./serve-worktree.sh"
echo ""
echo "  Login (same as primary):"
echo "    http://fm.futurewholesale.local:${WEB_PORT}"
echo "    admin@fm.com / admin123 / OTP 1111"
echo "    martin.hansen@trygenius.ai / admin123 / OTP 1111"
echo ""
echo "  Tear down later:"
echo "    # stop serve, then:"
echo "    git -C ${PRIMARY} worktree remove ${WT_PATH}"
echo "    docker exec -e PGPASSWORD=dbpassword future-mortgage-postgres \\"
echo "      psql -U dbuser -d postgres -c \"DROP DATABASE IF EXISTS ${DB_NAME};\""
echo "═══════════════════════════════════════════════════════════"
