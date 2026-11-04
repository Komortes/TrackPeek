#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
usage: ./script/agent.sh [help|context|doctor|board|next|show <item-id>|new-task <kebab-case-slug>]

  context   Print bounded checkout context and current task paths (read-only).
  doctor    Report local verification tools; install or change nothing.
  board     List the private board (read-only; requires gh access).
  next      Export one eligible Ready task to .agent-work/current.md; do not claim it.
  show      Export one private draft item to .agent-work/current.md.
  new-task  Create a private local task card without replacing existing work.

Verification remains in ./script/ci.sh [checks|test|build|all].
EOF
}

MODE="${1:-help}"
case "$MODE" in
  help|--help|context|doctor|board|next)
    if [[ $# -gt 1 ]]; then usage >&2; exit 2; fi
    ;;
  show)
    if [[ $# -ne 2 ]] || [[ ! $2 =~ ^[a-zA-Z0-9_-]+$ ]]; then
      usage >&2
      exit 2
    fi
    ;;
  new-task)
    if [[ $# -ne 2 ]] || [[ ! $2 =~ ^[a-z0-9]+(-[a-z0-9]+)*$ ]]; then
      usage >&2
      exit 2
    fi
    ;;
  *) usage >&2; exit 2 ;;
esac
if [[ "$MODE" == help || "$MODE" == --help ]]; then usage; exit 0; fi

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PYTHON="${TRACKPEEK_PYTHON:-/usr/bin/python3}"

context() {
  local branch task count=0
  branch="$(git -C "$ROOT_DIR" symbolic-ref --quiet --short HEAD || true)"
  printf 'Branch: %s\n' "${branch:-detached HEAD}"
  git -C "$ROOT_DIR" rev-parse --verify HEAD
  printf '\nWorking tree (first 80 lines):\n'
  git --no-optional-locks -C "$ROOT_DIR" status --short | sed -n '1,80p'
  printf '\nUnstaged / staged summary:\n'
  git -C "$ROOT_DIR" diff --stat=100,70,30
  git -C "$ROOT_DIR" diff --cached --stat=100,70,30
  printf '\nCurrent state (first 100 lines):\n'
  if [[ -f "$ROOT_DIR/docs/agents/STATE.md" ]]; then
    sed -n '1,100p' "$ROOT_DIR/docs/agents/STATE.md"
  else
    printf 'Missing docs/agents/STATE.md\n' >&2
    return 1
  fi
  printf '\nPrivate local task paths (up to 30; .agent-work/tasks/):\n'
  for task in "$ROOT_DIR"/.agent-work/tasks/*.md; do
    [[ -f "$task" ]] || continue
    printf '%s\n' "${task#"$ROOT_DIR"/}"
    count=$((count + 1))
    [[ $count -lt 30 ]] || break
  done
  printf '\nRead AGENTS.md and docs/agents/LOOP.md. Run ./script/agent.sh board for the live queue.\n'
}

doctor() {
  local failures=0
  check_tool() {
    printf '\n%s\n' "$*"
    if ! command -v "$1" >/dev/null 2>&1; then
      printf 'MISSING: %s\n' "$1" >&2
      failures=$((failures + 1))
    elif ! "$@"; then
      printf 'FAILED: %s\n' "$1" >&2
      failures=$((failures + 1))
    fi
  }
  if [[ "$(uname -s)" != Darwin ]]; then
    printf 'TrackPeek app checks require macOS and Xcode.\n' >&2
    failures=$((failures + 1))
  else
    check_tool sw_vers
  fi
  check_tool git --version
  check_tool gh --version
  check_tool "$PYTHON" --version
  check_tool xcodebuild -version
  check_tool xcrun swiftc --version
  check_tool xcodegen --version
  check_tool actionlint -version
  check_tool shellcheck --version
  printf '\nCompare versions with .github/workflows/ci.yml; see CONTRIBUTING.md for setup.\n'
  printf 'Doctor checks tool availability, not app correctness. Failures: %s\n' "$failures"
  [[ $failures -eq 0 ]]
}

new_task() {
  local template task_date base_commit target content
  template="$ROOT_DIR/docs/agents/TASK_TEMPLATE.md"
  if [[ ! -f "$template" ]]; then
    printf 'error: Missing task template: %s\n' "$template" >&2
    return 1
  fi
  task_date="$(date +%F)"
  base_commit="$(git -C "$ROOT_DIR" rev-parse --verify HEAD)"
  target="$ROOT_DIR/.agent-work/tasks/$task_date-$2.md"
  content="$(sed -e "s/{{SLUG}}/$2/g" -e "s/{{DATE}}/$task_date/g" \
    -e "s/{{BASE_COMMIT}}/$base_commit/g" "$template")"
  if [[ -L "$ROOT_DIR/.agent-work" || -L "$ROOT_DIR/.agent-work/tasks" ]]; then
    printf 'error: Private task directories must not be symbolic links.\n' >&2
    return 1
  fi
  (umask 077; mkdir -p "$ROOT_DIR/.agent-work/tasks")
  # noclobber uses exclusive creation, including concurrent calls for one slug.
  if ! (umask 077; set -o noclobber; printf '%s\n' "$content" > "$target"); then
    printf 'error: Cannot create task; existing files are never replaced: %s\n' "$target" >&2
    return 1
  fi
  printf 'Created %s\nFill its scope and acceptance criteria before implementation.\n' "${target#"$ROOT_DIR"/}"
}

case "$MODE" in
  context) context ;;
  doctor) doctor ;;
  board) "$PYTHON" "$ROOT_DIR/script/board.py" list ;;
  next) "$PYTHON" "$ROOT_DIR/script/board.py" next ;;
  show) "$PYTHON" "$ROOT_DIR/script/board.py" show "$2" ;;
  new-task) new_task "$@" ;;
esac
