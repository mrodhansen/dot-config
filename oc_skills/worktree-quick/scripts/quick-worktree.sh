#!/usr/bin/env bash
# quick-worktree.sh — Code-only git worktree for a PR or branch.
# No env copy, no DB, no Redis, no ports, no yarn, no seed.
#
# Usage:
#   ./quick-worktree.sh [create] <pr|branch|url> [name]
#   ./quick-worktree.sh [new|task] <what to work on>
#   ./quick-worktree.sh destroy <pr|name|path|task> [--yes] [--force] [--keep-branch]
#   ./quick-worktree.sh list
#
# Examples:
#   ./quick-worktree.sh 1234
#   ./quick-worktree.sh pr 1234
#   ./quick-worktree.sh feature/foo
#   ./quick-worktree.sh https://github.com/org/repo/pull/1234
#   ./quick-worktree.sh create origin/fix-types my-review
#   ./quick-worktree.sh new add dark mode toggle
#   ./quick-worktree.sh task fees page polish
#   ./quick-worktree.sh destroy 1234 --yes
#   ./quick-worktree.sh destroy --name pr-1234 --yes
#   ./quick-worktree.sh list
#
# Env:
#   REPO_ROOT   Pin the primary checkout (otherwise cwd git repo)
#   GIT_REMOTE  Remote to fetch from (default: origin)

set -euo pipefail

REMOTE="${GIT_REMOTE:-origin}"
YES=0
FORCE=0
KEEP_BRANCH=0
ACTION=""
TARGET=""
CUSTOM_NAME=""
NAME_FLAG=""
PATH_FLAG=""
ALL=0
FORCE_TASK=0
TASK_TITLE=""

usage() {
  sed -n '2,26p' "$0" | sed 's/^# \{0,1\}//'
  exit 1
}

die() {
  echo "ERROR: $*" >&2
  exit 1
}

# --- parse args ---
POSITIONAL=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    create|setup)
      ACTION="create"
      shift
      ;;
    new|task|work)
      ACTION="create"
      FORCE_TASK=1
      shift
      ;;
    destroy|remove|teardown|rm|clean)
      ACTION="destroy"
      shift
      ;;
    list|ls)
      ACTION="list"
      shift
      ;;
    --name)
      NAME_FLAG="${2:-}"
      [[ -n "${NAME_FLAG}" ]] || usage
      shift 2
      ;;
    --path)
      PATH_FLAG="${2:-}"
      [[ -n "${PATH_FLAG}" ]] || usage
      shift 2
      ;;
    --all)
      ALL=1
      shift
      ;;
    --keep-branch) KEEP_BRANCH=1; shift ;;
    --force) FORCE=1; shift ;;
    --yes|-y) YES=1; shift ;;
    -h|--help) usage ;;
    --)
      shift
      break
      ;;
    -*)
      die "unknown flag: $1"
      ;;
    *)
      POSITIONAL+=("$1")
      shift
      ;;
  esac
done

join_positional() {
  local start="$1"
  local i=0 s=""
  i="${start}"
  while [[ "${i}" -lt ${#POSITIONAL[@]} ]]; do
    if [[ -n "${s}" ]]; then
      s="${s} "
    fi
    s="${s}${POSITIONAL[$i]}"
    i=$((i + 1))
  done
  printf '%s' "${s}"
}

if [[ ${#POSITIONAL[@]} -gt 0 ]]; then
  if [[ "${POSITIONAL[0]}" == "pr" || "${POSITIONAL[0]}" == "branch" || "${POSITIONAL[0]}" == "ref" ]]; then
    if [[ ${#POSITIONAL[@]} -lt 2 ]]; then
      die "${POSITIONAL[0]} requires a number or ref"
    fi
    TARGET="${POSITIONAL[0]} ${POSITIONAL[1]}"
    if [[ ${#POSITIONAL[@]} -gt 2 ]]; then
      CUSTOM_NAME="$(join_positional 2)"
    fi
  elif [[ ${#POSITIONAL[@]} -gt 1 && "${FORCE_TASK}" -eq 0 ]]; then
    TARGET="${POSITIONAL[0]}"
    CUSTOM_NAME="$(join_positional 1)"
    if [[ "${TARGET}" != *'/'* && ! "${TARGET}" =~ ^[0-9]+$ && "${TARGET}" != http* ]]; then
      TARGET="$(join_positional 0)"
      CUSTOM_NAME=""
      FORCE_TASK=1
    fi
  else
    TARGET="$(join_positional 0)"
  fi
fi

if [[ -z "${ACTION}" ]]; then
  if [[ -z "${TARGET}" && -z "${PATH_FLAG}" && "${ALL}" -eq 0 ]]; then
    ACTION="list"
  else
    ACTION="create"
  fi
fi

slugify() {
  echo "$1" \
    | tr '[:upper:]' '[:lower:]' \
    | sed -E 's#^origin/##; s#^refs/heads/##; s#^refs/pull/##; s#/head$##' \
    | tr '/:#' '---' \
    | tr -cs 'a-z0-9._-' '-' \
    | sed -E 's/^-+//; s/-+$//; s/-+/-/g' \
    | cut -c1-48
}

extract_pr() {
  local raw="$1"
  raw="$(echo "${raw}" | sed -E 's/^#//')"
  if echo "${raw}" | grep -Eq 'github\.com/.+/pull/[0-9]+'; then
    echo "${raw}" | sed -E 's#.*github\.com/.+/pull/([0-9]+).*#\1#'
    return 0
  fi
  if echo "${raw}" | grep -Eq '^[Pp][Rr][-/ ]?[0-9]+$'; then
    echo "${raw}" | sed -E 's/^[Pp][Rr][-/ ]?//'
    return 0
  fi
  if echo "${raw}" | grep -Eq '^[0-9]+$'; then
    echo "${raw}"
    return 0
  fi
  return 1
}

resolve_primary() {
  if [[ -n "${REPO_ROOT:-}" && -d "${REPO_ROOT}" ]]; then
    (cd "${REPO_ROOT}" && pwd)
    return 0
  fi
  local main_wt
  main_wt="$(git worktree list --porcelain 2>/dev/null | awk '/^worktree /{print $2; exit}')"
  if [[ -n "${main_wt}" && -d "${main_wt}" ]]; then
    echo "${main_wt}"
    return 0
  fi
  if git rev-parse --show-toplevel >/dev/null 2>&1; then
    git rev-parse --show-toplevel
    return 0
  fi
  die "cannot resolve repo root. cd into a git repo or set REPO_ROOT."
}

PRIMARY="$(resolve_primary)"
REPO_NAME="$(basename "${PRIMARY}")"
WORKTREES_ROOT="$(dirname "${PRIMARY}")/worktrees"

is_primary() {
  local candidate="$1"
  local a b
  a="$(cd "${candidate}" 2>/dev/null && pwd -P)" || return 1
  b="$(cd "${PRIMARY}" && pwd -P)"
  [[ "${a}" == "${b}" ]]
}

marker_file() {
  local path="$1" gitdir
  if gitdir="$(git -C "${path}" rev-parse --path-format=absolute --git-dir 2>/dev/null)"; then
    if [[ -f "${gitdir}/worktree-quick" ]]; then
      echo "${gitdir}/worktree-quick"
      return 0
    fi
  fi
  if [[ -f "${path}/.worktree-quick" ]]; then
    echo "${path}/.worktree-quick"
    return 0
  fi
  return 1
}

is_quick_worktree() {
  local path="$1"
  [[ -f "${path}/.worktree-slot" ]] && return 1
  marker_file "${path}" >/dev/null && return 0
  local base
  base="$(basename "${path}")"
  [[ "${base}" == "${REPO_NAME}-quick-"* ]] && return 0
  return 1
}

assert_not_primary() {
  local path="$1"
  if is_primary "${path}"; then
    die "refusing to operate on the primary checkout: ${path}"
  fi
}

assert_quick_or_die() {
  local path="$1"
  assert_not_primary "${path}"
  if ! is_quick_worktree "${path}"; then
    die "refusing to touch non-quick worktree: ${path} (no quick marker; expected ${REPO_NAME}-quick-*)"
  fi
}

marker_get() {
  local path="$1" key="$2" file
  file="$(marker_file "${path}")" || return 1
  awk -F= -v k="${key}" '$1==k {print substr($0, index($0,$2)); exit}' "${file}"
}

list_quick_paths() {
  git -C "${PRIMARY}" worktree list --porcelain | awk '/^worktree /{print $2}' | while IFS= read -r p; do
    [[ -n "${p}" ]] || continue
    if is_quick_worktree "${p}"; then
      echo "${p}"
    fi
  done
}

cmd_list() {
  local found=0
  printf '%-56s %-28s %-10s %s\n' "PATH" "BRANCH" "SOURCE" "REF"
  printf '%-56s %-28s %-10s %s\n' "----" "------" "------" "---"
  while IFS= read -r p; do
    [[ -n "${p}" ]] || continue
    found=1
    local branch source ref
    branch="$(git -C "${p}" rev-parse --abbrev-ref HEAD 2>/dev/null || echo "?")"
    source="$(marker_get "${p}" source 2>/dev/null || echo "?")"
    ref="$(marker_get "${p}" ref 2>/dev/null || git -C "${p}" rev-parse --short HEAD 2>/dev/null || echo "?")"
    printf '%-56s %-28s %-10s %s\n' "${p}" "${branch}" "${source}" "${ref}"
  done < <(list_quick_paths)
  if [[ "${found}" -eq 0 ]]; then
    echo "(no quick worktrees for ${REPO_NAME})"
  fi
}

write_marker() {
  local path="$1" gitdir
  gitdir="$(git -C "${path}" rev-parse --path-format=absolute --git-dir)"
  cat > "${gitdir}/worktree-quick" <<EOF
kind=quick
repo=${REPO_NAME}
source=${SOURCE}
pr=${PR_NUM}
ref=${RESOLVED_SHA}
upstream=${UPSTREAM_REF}
branch=${BRANCH_NAME}
url=${SOURCE_URL}
task=${TASK_TITLE}
created=$(date -u +%Y-%m-%dT%H:%M:%SZ)
EOF
}

resolve_task() {
  local desc="$1"
  desc="$(echo "${desc}" | sed -E 's/^(new|task|work|on)[[:space:]]+//')"
  [[ -n "${desc}" ]] || die "task mode requires a description (e.g. 'new add dark mode')"
  SOURCE="task"
  TASK_TITLE="${desc}"
  TITLE="${desc}"
  UPSTREAM_REF="$(git -C "${PRIMARY}" rev-parse --abbrev-ref HEAD)"
  RESOLVED_SHA="$(git -C "${PRIMARY}" rev-parse HEAD)"
  SOURCE_URL=""
  PR_NUM=""
}

resolve_create_target() {
  local raw="$1"
  PR_NUM=""
  SOURCE=""
  SOURCE_URL=""
  UPSTREAM_REF=""
  RESOLVED_SHA=""
  TITLE=""
  TASK_TITLE=""

  if [[ "${FORCE_TASK}" -eq 1 ]]; then
    resolve_task "${raw}"
    return 0
  fi

  local maybe_pr
  if maybe_pr="$(extract_pr "${raw}")"; then
    SOURCE="pr"
    PR_NUM="${maybe_pr}"
    git -C "${PRIMARY}" fetch "${REMOTE}" "pull/${PR_NUM}/head"
    RESOLVED_SHA="$(git -C "${PRIMARY}" rev-parse FETCH_HEAD)"
    UPSTREAM_REF="pull/${PR_NUM}/head"
    if command -v gh >/dev/null 2>&1; then
      TITLE="$(gh pr view "${PR_NUM}" --json title --jq .title 2>/dev/null || true)"
      SOURCE_URL="$(gh pr view "${PR_NUM}" --json url --jq .url 2>/dev/null || true)"
      local head
      head="$(gh pr view "${PR_NUM}" --json headRefName --jq .headRefName 2>/dev/null || true)"
      if [[ -n "${head}" && "${head}" != "null" ]]; then
        UPSTREAM_REF="${head}"
      fi
    fi
    return 0
  fi

  SOURCE="branch"
  local ref="${raw}"
  if git -C "${PRIMARY}" fetch "${REMOTE}" "${ref}" 2>/dev/null; then
    if git -C "${PRIMARY}" rev-parse --verify --quiet "${REMOTE}/${ref}^{commit}" >/dev/null; then
      UPSTREAM_REF="${REMOTE}/${ref}"
      RESOLVED_SHA="$(git -C "${PRIMARY}" rev-parse "${REMOTE}/${ref}^{commit}")"
      return 0
    fi
    if git -C "${PRIMARY}" rev-parse --verify --quiet "FETCH_HEAD^{commit}" >/dev/null; then
      UPSTREAM_REF="${ref}"
      RESOLVED_SHA="$(git -C "${PRIMARY}" rev-parse "FETCH_HEAD^{commit}")"
      return 0
    fi
  fi
  if git -C "${PRIMARY}" rev-parse --verify --quiet "${ref}^{commit}" >/dev/null; then
    UPSTREAM_REF="${ref}"
    RESOLVED_SHA="$(git -C "${PRIMARY}" rev-parse "${ref}^{commit}")"
    return 0
  fi
  if [[ "${raw}" == *'/'* || "${raw}" == *':'* ]]; then
    die "cannot resolve '${raw}' as a PR number or git ref (tried fetch ${REMOTE} ${ref})"
  fi
  resolve_task "${raw}"
}

cmd_create() {
  local raw="${TARGET}"
  [[ -n "${raw}" ]] || die "create requires a PR, branch, or task description. Usage: quick-worktree.sh <pr|branch|new …>"

  resolve_create_target "${raw}"

  local slug
  if [[ -n "${CUSTOM_NAME}" ]]; then
    slug="$(slugify "${CUSTOM_NAME}")"
  elif [[ -n "${NAME_FLAG}" ]]; then
    slug="$(slugify "${NAME_FLAG}")"
  elif [[ "${SOURCE}" == "pr" ]]; then
    slug="pr-${PR_NUM}"
  elif [[ "${SOURCE}" == "task" ]]; then
    slug="$(slugify "${TASK_TITLE}")"
  else
    slug="$(slugify "${raw}")"
  fi
  [[ -n "${slug}" ]] || die "could not derive a worktree name from '${raw}'"

  local wt_path="${WORKTREES_ROOT}/${REPO_NAME}-quick-${slug}"
  BRANCH_NAME="quick/${slug}"

  if [[ -d "${wt_path}" ]]; then
    die "worktree path already exists: ${wt_path}"
  fi
  if git -C "${PRIMARY}" show-ref --verify --quiet "refs/heads/${BRANCH_NAME}"; then
    die "local branch already exists: ${BRANCH_NAME} (destroy it first or pass a different name)"
  fi

  mkdir -p "${WORKTREES_ROOT}"
  git -C "${PRIMARY}" worktree add -b "${BRANCH_NAME}" "${wt_path}" "${RESOLVED_SHA}"
  write_marker "${wt_path}"

  echo "═══════════════════════════════════════════════════════════"
  echo " Quick worktree (code only — no env / db / seed / serve)"
  echo "═══════════════════════════════════════════════════════════"
  echo "  repo:     ${PRIMARY}"
  echo "  path:     ${wt_path}"
  echo "  branch:   ${BRANCH_NAME}"
  echo "  source:   ${SOURCE}${PR_NUM:+ #${PR_NUM}}"
  echo "  ref:      ${RESOLVED_SHA}"
  echo "  upstream: ${UPSTREAM_REF}"
  if [[ "${SOURCE}" == "task" && -n "${TASK_TITLE}" ]]; then
    echo "  task:     ${TASK_TITLE}"
  elif [[ -n "${TITLE}" ]]; then
    echo "  title:    ${TITLE}"
  fi
  if [[ -n "${SOURCE_URL}" ]]; then
    echo "  url:      ${SOURCE_URL}"
  fi
  echo "═══════════════════════════════════════════════════════════"
  echo "cd ${wt_path}"
  echo "Destroy: $0 destroy ${slug} --yes"
}

resolve_destroy_path() {
  if [[ -n "${PATH_FLAG}" ]]; then
    local p="${PATH_FLAG}"
    if [[ "${p}" != /* ]]; then
      p="$(cd "${p}" 2>/dev/null && pwd)" || die "path not found: ${PATH_FLAG}"
    fi
    echo "${p}"
    return 0
  fi

  local key="${NAME_FLAG:-${TARGET}}"
  [[ -n "${key}" ]] || return 1
  key="$(echo "${key}" | sed -E 's/^(new|task|work|on)[[:space:]]+//')"

  local maybe_pr
  if maybe_pr="$(extract_pr "${key}")"; then
    local p
    p="${WORKTREES_ROOT}/${REPO_NAME}-quick-pr-${maybe_pr}"
    if [[ -d "${p}" ]]; then
      echo "${p}"
      return 0
    fi
    while IFS= read -r cand; do
      [[ -n "${cand}" ]] || continue
      local pr
      pr="$(marker_get "${cand}" pr || true)"
      if [[ "${pr}" == "${maybe_pr}" ]]; then
        echo "${cand}"
        return 0
      fi
    done < <(list_quick_paths)
  fi

  local slug
  slug="$(slugify "${key}")"
  local p="${WORKTREES_ROOT}/${REPO_NAME}-quick-${slug}"
  if [[ -d "${p}" ]]; then
    echo "${p}"
    return 0
  fi

  # Allow passing the full directory basename or an existing worktree path
  if [[ -d "${key}" ]]; then
    (cd "${key}" && pwd)
    return 0
  fi

  return 1
}

destroy_one() {
  local wt_path="$1"
  assert_quick_or_die "${wt_path}"

  local branch
  branch="$(marker_get "${wt_path}" branch || true)"
  if [[ -z "${branch}" ]]; then
    branch="$(git -C "${wt_path}" rev-parse --abbrev-ref HEAD 2>/dev/null || true)"
  fi

  echo "Removing worktree: ${wt_path}"
  rm -f "${wt_path}/.worktree-quick"
  if [[ "${FORCE}" -eq 1 ]]; then
    git -C "${PRIMARY}" worktree remove --force "${wt_path}" \
      || { rm -rf "${wt_path}"; git -C "${PRIMARY}" worktree prune; }
  else
    git -C "${PRIMARY}" worktree remove "${wt_path}" \
      || die "worktree remove failed (dirty?). Re-run with --force"
  fi
  git -C "${PRIMARY}" worktree prune

  if [[ "${KEEP_BRANCH}" -eq 0 && -n "${branch}" && "${branch}" == quick/* ]]; then
    if git -C "${PRIMARY}" show-ref --verify --quiet "refs/heads/${branch}"; then
      if git -C "${PRIMARY}" worktree list --porcelain | awk '/^branch /{print $2}' | grep -qx "refs/heads/${branch}"; then
        echo "Leaving branch ${branch} (still checked out elsewhere)"
      else
        git -C "${PRIMARY}" branch -D "${branch}"
        echo "Deleted branch ${branch}"
      fi
    fi
  fi
}

cmd_destroy() {
  local paths=()
  if [[ "${ALL}" -eq 1 ]]; then
    while IFS= read -r p; do
      [[ -n "${p}" ]] && paths+=("${p}")
    done < <(list_quick_paths)
    [[ ${#paths[@]} -gt 0 ]] || die "no quick worktrees to destroy"
  else
    local p
    p="$(resolve_destroy_path)" || {
      echo "Could not resolve destroy target '${NAME_FLAG:-${TARGET:-}}'." >&2
      echo "Known quick worktrees:" >&2
      cmd_list >&2
      exit 1
    }
    paths+=("${p}")
  fi

  echo "Will destroy:"
  local p
  for p in "${paths[@]}"; do
    echo "  ${p}"
    assert_quick_or_die "${p}"
  done

  if [[ "${YES}" -ne 1 ]]; then
    die "refusing to destroy without --yes (non-interactive). Re-run with --yes."
  fi

  for p in "${paths[@]}"; do
    destroy_one "${p}"
  done

  echo "Remaining worktrees:"
  git -C "${PRIMARY}" worktree list
}

case "${ACTION}" in
  list) cmd_list ;;
  create) cmd_create ;;
  destroy) cmd_destroy ;;
  *) usage ;;
esac
