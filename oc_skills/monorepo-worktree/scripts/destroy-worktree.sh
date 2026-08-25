#!/usr/bin/env bash
# destroy-worktree.sh — Tear down an isolated monorepo worktree cleanly.
#
# Usage:
#   ./destroy-worktree.sh <slot>                 # e.g. 1 → monorepo-slot-1
#   ./destroy-worktree.sh --name <name>          # e.g. my-feature → monorepo-my-feature
#   ./destroy-worktree.sh --path <abs-or-rel>    # explicit worktree path
#   ./destroy-worktree.sh --all                  # every monorepo-* under ../worktrees/
#   ./destroy-worktree.sh list                   # show discoverable worktrees (no destroy)
#
# Aliases accepted as $1: destroy | remove | teardown | rm | clean | list
#   ./destroy-worktree.sh destroy 1
#   ./destroy-worktree.sh remove --name slot-1
#
# Options:
#   --keep-db       Do not DROP the isolated Postgres database
#   --keep-branch   Do not delete the worktree/* git branch
#   --keep-redis    Do not FLUSHDB the slot's Redis logical DB
#   --force         git worktree remove --force (discard uncommitted worktree files)
#   --yes           Skip interactive confirmation (still prints plan)
#
# Safety (hard rules — script will refuse otherwise):
#   - Never touch primary ports 3000 / 3001 / 4201
#   - Never DROP database "dbname" (primary)
#   - Never remove the primary monorepo checkout
#   - Only kill listeners on the worktree's own ports (or PIDs rooted in WT path)
#   - Only DROP databases matching dbname_wt{N}

set -euo pipefail

KEEP_DB=0
KEEP_BRANCH=0
KEEP_REDIS=0
FORCE=0
YES=0
MODE=""          # slot | name | path | all | list
SLOT=""
NAME=""
WT_PATH_ARG=""
ACTION="destroy" # destroy | list

usage() {
  sed -n '2,35p' "$0" | sed 's/^# \?//'
  exit 1
}

# --- parse args ---
ARGS=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    destroy|remove|teardown|rm|clean)
      ACTION="destroy"
      shift
      ;;
    list|ls)
      ACTION="list"
      shift
      ;;
    --name)
      MODE="name"
      NAME="${2:-}"
      [[ -n "${NAME}" ]] || usage
      shift 2
      ;;
    --path)
      MODE="path"
      WT_PATH_ARG="${2:-}"
      [[ -n "${WT_PATH_ARG}" ]] || usage
      shift 2
      ;;
    --all)
      MODE="all"
      shift
      ;;
    --keep-db) KEEP_DB=1; shift ;;
    --keep-branch) KEEP_BRANCH=1; shift ;;
    --keep-redis) KEEP_REDIS=1; shift ;;
    --force) FORCE=1; shift ;;
    --yes|-y) YES=1; shift ;;
    -h|--help) usage ;;
    --*)
      echo "Unknown option: $1"
      usage
      ;;
    *)
      ARGS+=("$1")
      shift
      ;;
  esac
done

if [[ ${#ARGS[@]} -gt 0 ]]; then
  if [[ -z "${MODE}" && "${ARGS[0]}" =~ ^[1-9][0-9]*$ ]]; then
    MODE="slot"
    SLOT="${ARGS[0]}"
  elif [[ -z "${MODE}" ]]; then
    # treat bare token as name
    MODE="name"
    NAME="${ARGS[0]}"
  fi
fi

if [[ "${ACTION}" == "list" ]]; then
  MODE="list"
fi

if [[ -z "${MODE}" ]]; then
  usage
fi

# --- resolve primary + worktrees root ---
# User-scoped skill — do NOT resolve monorepo from script path.
# Priority: MONOREPO_ROOT env → cwd git main worktree → fail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
resolve_primary() {
  if [[ -n "${MONOREPO_ROOT:-}" && -d "${MONOREPO_ROOT}" ]]; then
    echo "$(cd "${MONOREPO_ROOT}" && pwd)"
    return 0
  fi
  if ! git rev-parse --git-dir >/dev/null 2>&1; then
    echo "ERROR: not inside a monorepo git checkout. cd into it or set MONOREPO_ROOT." >&2
    return 1
  fi
  local main_wt
  main_wt="$(git worktree list --porcelain 2>/dev/null | awk '/^worktree /{print $2; exit}')"
  if [[ -n "${main_wt}" && -d "${main_wt}" ]]; then
    echo "${main_wt}"
    return 0
  fi
  git rev-parse --path-format=absolute --show-toplevel 2>/dev/null
}
PRIMARY="$(resolve_primary)"
PRIMARY="$(cd "${PRIMARY}" && pwd)"
WORKTREES_ROOT="$(dirname "${PRIMARY}")/worktrees"

is_primary_path() {
  local p
  p="$(cd "$1" 2>/dev/null && pwd || echo "$1")"
  [[ "${p}" == "${PRIMARY}" ]]
}

# --- discovery helpers ---
read_marker() {
  # sets SLOT NAME WEB_PORT API_PORT FUNNEL_PORT DB_NAME REDIS_URL INSPECT_PORT from .worktree-slot
  local marker="$1/.worktree-slot"
  SLOT="" NAME="" WEB_PORT="" API_PORT="" FUNNEL_PORT="" DB_NAME="" REDIS_URL="" INSPECT_PORT=""
  if [[ -f "${marker}" ]]; then
    # shellcheck disable=SC1090
    set -a
    # only allow KEY=VALUE lines
    # shellcheck disable=SC1091
    source <(grep -E '^[A-Z_]+=.*' "${marker}" || true)
    set +a
  fi
}

infer_from_path() {
  local path="$1"
  read_marker "${path}"
  if [[ -z "${NAME}" ]]; then
    NAME="$(basename "${path}" | sed 's/^monorepo-//')"
  fi
  if [[ -z "${SLOT}" && "${NAME}" =~ ^slot-([1-9][0-9]*)$ ]]; then
    SLOT="${BASH_REMATCH[1]}"
  fi
  if [[ -n "${SLOT}" ]]; then
    WEB_PORT="${WEB_PORT:-$((3000 + SLOT * 100))}"
    API_PORT="${API_PORT:-$((3001 + SLOT * 100))}"
    FUNNEL_PORT="${FUNNEL_PORT:-$((4201 + SLOT * 100))}"
    DB_NAME="${DB_NAME:-dbname_wt${SLOT}}"
    REDIS_URL="${REDIS_URL:-redis://localhost:6379/${SLOT}}"
    INSPECT_PORT="${INSPECT_PORT:-$((9229 + SLOT))}"
  fi
}

list_worktrees() {
  echo "Primary: ${PRIMARY}"
  echo "Worktrees root: ${WORKTREES_ROOT}"
  echo ""
  git -C "${PRIMARY}" worktree list
  echo ""
  if [[ -d "${WORKTREES_ROOT}" ]]; then
    echo "Discovered monorepo-* dirs:"
    for d in "${WORKTREES_ROOT}"/monorepo-*; do
      [[ -d "$d" ]] || continue
      if is_primary_path "$d"; then
        continue
      fi
      infer_from_path "$d"
      local ports="?"
      if [[ -n "${WEB_PORT:-}" ]]; then
        ports="${WEB_PORT}/${API_PORT}/${FUNNEL_PORT}"
      fi
      local listening=""
      for p in ${WEB_PORT:-} ${API_PORT:-} ${FUNNEL_PORT:-}; do
        [[ -n "$p" ]] || continue
        if lsof -nP -iTCP:"$p" -sTCP:LISTEN >/dev/null 2>&1; then
          listening+="${p} "
        fi
      done
      echo "  - $d"
      echo "      name=${NAME:-?} slot=${SLOT:-?} ports=${ports} db=${DB_NAME:-?} listening=${listening:-none}"
    done
  else
    echo "(no ${WORKTREES_ROOT} directory)"
  fi
}

if [[ "${MODE}" == "list" || "${ACTION}" == "list" ]]; then
  list_worktrees
  exit 0
fi

# --- build target list ---
TARGETS=()

resolve_one() {
  local path="$1"
  path="$(cd "${path}" 2>/dev/null && pwd || true)"
  if [[ -z "${path}" || ! -d "${path}" ]]; then
    echo "ERROR: worktree path not found: $1" >&2
    return 1
  fi
  if is_primary_path "${path}"; then
    echo "ERROR: refusing to destroy primary monorepo: ${path}" >&2
    return 1
  fi
  # Prefer paths under worktrees/ or registered git worktrees that are not primary
  TARGETS+=("${path}")
}

case "${MODE}" in
  slot)
    NAME="slot-${SLOT}"
    resolve_one "${WORKTREES_ROOT}/monorepo-${NAME}"
    ;;
  name)
    resolve_one "${WORKTREES_ROOT}/monorepo-${NAME}"
    ;;
  path)
    resolve_one "${WT_PATH_ARG}"
    ;;
  all)
    shopt -s nullglob
    found=0
    for d in "${WORKTREES_ROOT}"/monorepo-*; do
      if is_primary_path "$d"; then
        continue
      fi
      TARGETS+=("$(cd "$d" && pwd)")
      found=1
    done
    shopt -u nullglob
    if [[ ${found} -eq 0 ]]; then
      echo "No monorepo-* worktrees found under ${WORKTREES_ROOT}"
      exit 0
    fi
    ;;
  *)
    usage
    ;;
esac

if [[ ${#TARGETS[@]} -eq 0 ]]; then
  echo "ERROR: nothing to destroy."
  exit 1
fi

# --- kill helpers ---
PRIMARY_PORTS=(3000 3001 4201)

is_primary_port() {
  local p="$1"
  for pp in "${PRIMARY_PORTS[@]}"; do
    [[ "$p" == "$pp" ]] && return 0
  done
  return 1
}

kill_port() {
  local port="$1"
  if is_primary_port "${port}"; then
    echo "  REFUSE kill primary port ${port}"
    return 0
  fi
  local pids
  pids="$(lsof -nP -iTCP:"${port}" -sTCP:LISTEN -t 2>/dev/null || true)"
  if [[ -z "${pids}" ]]; then
    echo "  port ${port}: nothing listening"
    return 0
  fi
  echo "  port ${port}: killing PIDs ${pids//$'\n'/ }"
  # kill process group leaders gently then hard
  for pid in ${pids}; do
    kill -TERM "${pid}" 2>/dev/null || true
  done
  sleep 1
  for pid in ${pids}; do
    if kill -0 "${pid}" 2>/dev/null; then
      kill -KILL "${pid}" 2>/dev/null || true
    fi
  done
}

kill_tree_by_cwd() {
  # Best-effort: kill node/yarn/nx processes whose cwd is under the worktree
  local wt="$1"
  local pid cwd cmd
  # macOS: lsof +cwd; Linux: /proc
  if [[ "$(uname -s)" == "Darwin" ]]; then
    while read -r pid; do
      [[ -n "${pid}" ]] || continue
      cwd="$(lsof -a -p "${pid}" -d cwd -Fn 2>/dev/null | sed -n 's/^n//p' | head -1 || true)"
      if [[ -n "${cwd}" && "${cwd}" == "${wt}"* ]]; then
        cmd="$(ps -p "${pid}" -o comm= 2>/dev/null || true)"
        case "${cmd}" in
          node|yarn|npm|nx|vite|webpack*|esbuild)
            echo "  cwd-match PID ${pid} (${cmd}) under ${wt}"
            kill -TERM "${pid}" 2>/dev/null || true
            ;;
        esac
      fi
    done < <(pgrep -u "$(id -u)" -f 'node|yarn|nx|vite|webpack' 2>/dev/null || true)
    sleep 1
  fi
}

drop_db() {
  local db="$1"
  if [[ -z "${db}" ]]; then
    echo "  skip DB drop (unknown name)"
    return 0
  fi
  if [[ "${db}" == "dbname" || ! "${db}" =~ ^dbname_wt[1-9][0-9]*$ ]]; then
    echo "  REFUSE to drop non-worktree database: ${db}"
    return 1
  fi
  if ! docker ps --format '{{.Names}}' | grep -qx 'future-mortgage-postgres'; then
    echo "  WARN: future-mortgage-postgres not running; cannot drop ${db}"
    return 0
  fi
  echo "  dropping database ${db}..."
  # terminate backends then drop
  docker exec -e PGPASSWORD=dbpassword future-mortgage-postgres \
    psql -U dbuser -d postgres -v ON_ERROR_STOP=1 -c \
    "SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname = '${db}' AND pid <> pg_backend_pid();" \
    >/dev/null 2>&1 || true
  docker exec -e PGPASSWORD=dbpassword future-mortgage-postgres \
    psql -U dbuser -d postgres -c "DROP DATABASE IF EXISTS ${db};"
}

flush_redis_db() {
  local slot="$1"
  if [[ -z "${slot}" || ! "${slot}" =~ ^[1-9][0-9]*$ ]]; then
    echo "  skip redis flush (unknown slot)"
    return 0
  fi
  if ! docker ps --format '{{.Names}}' | grep -qx 'future-mortgage-redis'; then
    echo "  WARN: future-mortgage-redis not running; skip flush db ${slot}"
    return 0
  fi
  echo "  redis FLUSHDB on logical DB ${slot}..."
  docker exec future-mortgage-redis redis-cli -n "${slot}" FLUSHDB >/dev/null
}

remove_git_worktree() {
  local path="$1"
  local force_flag=()
  [[ "${FORCE}" -eq 1 ]] && force_flag=(--force)

  if git -C "${PRIMARY}" worktree list --porcelain | grep -q "^worktree ${path}$"; then
    echo "  git worktree remove ${path} ${force_flag[*]:-}"
    # If dirty and not forced, try force after unlock
    if ! git -C "${PRIMARY}" worktree remove "${force_flag[@]}" "${path}" 2>/tmp/wt-rm-err.$$; then
      echo "  worktree remove failed, retrying with --force..."
      cat /tmp/wt-rm-err.$$ >&2 || true
      git -C "${PRIMARY}" worktree remove --force "${path}" || {
        echo "  WARN: git worktree remove failed; removing directory manually"
        rm -rf "${path}"
        git -C "${PRIMARY}" worktree prune
      }
    fi
    rm -f /tmp/wt-rm-err.$$
  elif [[ -d "${path}" ]]; then
    echo "  path not registered as git worktree; removing directory ${path}"
    rm -rf "${path}"
    git -C "${PRIMARY}" worktree prune 2>/dev/null || true
  else
    echo "  path already gone: ${path}"
  fi
}

delete_branch() {
  local path="$1"
  local branch name
  # Prefer branch currently (or was) associated via marker name
  infer_from_path "${path}" 2>/dev/null || true
  name="${NAME:-$(basename "${path}" | sed 's/^monorepo-//')}"
  branch="worktree/${name}"
  if git -C "${PRIMARY}" show-ref --verify --quiet "refs/heads/${branch}"; then
    # refuse if checked out elsewhere
    if git -C "${PRIMARY}" worktree list | grep -q "\[${branch}\]"; then
      echo "  branch ${branch} still checked out elsewhere; skip delete"
      return 0
    fi
    echo "  deleting branch ${branch}"
    git -C "${PRIMARY}" branch -D "${branch}" || true
  else
    echo "  no local branch ${branch}"
  fi
}

destroy_one() {
  local path="$1"
  echo ""
  echo "───────────────────────────────────────────────────────────"
  echo " Destroying: ${path}"
  echo "───────────────────────────────────────────────────────────"

  if is_primary_path "${path}"; then
    echo "ERROR: refusing primary path"
    return 1
  fi

  infer_from_path "${path}"

  echo "  slot=${SLOT:-?} name=${NAME:-?} web=${WEB_PORT:-?} api=${API_PORT:-?} funnel=${FUNNEL_PORT:-?}"
  echo "  db=${DB_NAME:-?} redis=${REDIS_URL:-?}"

  # 1) Stop services on worktree ports
  echo "→ Stopping listeners"
  for p in ${WEB_PORT:-} ${API_PORT:-} ${FUNNEL_PORT:-} ${INSPECT_PORT:-}; do
    [[ -n "${p}" ]] || continue
    kill_port "${p}"
  done
  # Also stop anything still rooted in this cwd (nx parent, etc.)
  if [[ -d "${path}" ]]; then
    kill_tree_by_cwd "${path}"
  fi
  sleep 0.5

  # Verify ports free
  for p in ${WEB_PORT:-} ${API_PORT:-} ${FUNNEL_PORT:-}; do
    [[ -n "${p}" ]] || continue
    if lsof -nP -iTCP:"${p}" -sTCP:LISTEN >/dev/null 2>&1; then
      echo "  WARN: port ${p} still listening after kill; retrying KILL"
      kill_port "${p}"
    fi
  done

  # 2) Redis flush for slot
  if [[ "${KEEP_REDIS}" -eq 0 && -n "${SLOT:-}" ]]; then
    echo "→ Redis cleanup"
    flush_redis_db "${SLOT}"
  else
    echo "→ Redis cleanup skipped"
  fi

  # 3) Drop isolated DB
  if [[ "${KEEP_DB}" -eq 0 ]]; then
    echo "→ Postgres cleanup"
    drop_db "${DB_NAME:-}"
  else
    echo "→ Postgres cleanup skipped (--keep-db)"
  fi

  # 4) Remove git worktree + files
  echo "→ Git worktree remove"
  # Capture branch name before path disappears
  local branch_name="${NAME:-}"
  remove_git_worktree "${path}"

  # 5) Delete worktree/* branch
  if [[ "${KEEP_BRANCH}" -eq 0 ]]; then
    echo "→ Branch cleanup"
    # path may be gone; use captured name
    if [[ -n "${branch_name}" ]]; then
      local branch="worktree/${branch_name}"
      if git -C "${PRIMARY}" show-ref --verify --quiet "refs/heads/${branch}"; then
        if git -C "${PRIMARY}" worktree list | grep -q "\[${branch}\]"; then
          echo "  branch ${branch} still checked out; skip"
        else
          echo "  deleting branch ${branch}"
          git -C "${PRIMARY}" branch -D "${branch}" || true
        fi
      else
        echo "  no local branch ${branch}"
      fi
    fi
  else
    echo "→ Branch cleanup skipped (--keep-branch)"
  fi

  echo "✓ Destroy complete for ${NAME:-$path}"
}

# --- plan + confirm ---
echo "═══════════════════════════════════════════════════════════"
echo " Monorepo worktree DESTROY"
echo "═══════════════════════════════════════════════════════════"
echo "  primary:      ${PRIMARY}"
echo "  targets:      ${#TARGETS[@]}"
echo "  keep-db:      ${KEEP_DB}"
echo "  keep-branch:  ${KEEP_BRANCH}"
echo "  keep-redis:   ${KEEP_REDIS}"
echo "  force:        ${FORCE}"
for t in "${TARGETS[@]}"; do
  infer_from_path "$t"
  echo "  - $t  (slot=${SLOT:-?} db=${DB_NAME:-?} ports=${WEB_PORT:-?}/${API_PORT:-?}/${FUNNEL_PORT:-?})"
done
echo "═══════════════════════════════════════════════════════════"

if [[ "${YES}" -ne 1 ]]; then
  if [[ -t 0 ]]; then
    read -r -p "Proceed with destroy? [y/N] " ans
    case "${ans}" in
      y|Y|yes|YES) ;;
      *) echo "Aborted."; exit 1 ;;
    esac
  else
    echo "Non-interactive shell: pass --yes to confirm destroy."
    exit 1
  fi
fi

for t in "${TARGETS[@]}"; do
  destroy_one "$t"
done

echo ""
echo "→ Verifying primary stack still intact"
for p in 3000 3001 4201; do
  if lsof -nP -iTCP:"$p" -sTCP:LISTEN >/dev/null 2>&1; then
    echo "  primary port $p: still listening (ok)"
  else
    echo "  primary port $p: not listening (ok if primary wasn't running)"
  fi
done
if curl -s -m 2 http://localhost:3001/health >/dev/null 2>&1; then
  echo "  primary API :3001 health OK"
fi

echo ""
echo "→ Remaining worktrees"
git -C "${PRIMARY}" worktree list
echo ""
echo "Done."
