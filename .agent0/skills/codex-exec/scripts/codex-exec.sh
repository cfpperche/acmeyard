#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: codex-exec.sh [options] (--task <prompt> | --task-file <path> | prompt via stdin | -- <prompt...>)

Options:
  --task <text>             Prompt sent to Codex.
  --task-file <path>        Read prompt text from a file.
  --model <model>           Codex model override.
  --profile <profile>       Codex config profile.
  --reasoning-effort <lvl>  minimal|low|medium|high|xhigh (maps to -c model_reasoning_effort).
  --timeout <seconds>       Wall-clock limit for the Codex subprocess (default: 600).
  --progress-interval <sec> Emit waiting heartbeat to stderr every N seconds; 0 disables (default: 30).
  --sandbox <mode>          read-only | workspace-write | danger-full-access (default: read-only).
  --cwd <dir>               Codex working root; must resolve under the repo root.
  --resume <session-id>     Run codex exec resume <session-id> -.
  --json                    Capture Codex JSONL stdout to events.jsonl.
  --output <path>           Path for --output-last-message; must stay under state dir.
  --slug <slug>             Slug for the generated run directory.
  -h, --help                Show this help.
EOF
}

die() {
  printf 'codex-exec error: %s\n' "$*" >&2
  exit 2
}

json_escape() {
  local s=${1//\\/\\\\}
  s=${s//\"/\\\"}
  s=${s//$'\n'/\\n}
  s=${s//$'\r'/\\r}
  s=${s//$'\t'/\\t}
  printf '%s' "$s"
}

json_string() {
  printf '"%s"' "$(json_escape "$1")"
}

require_value() {
  local opt=$1
  local value=${2-}
  if [ -z "$value" ]; then
    die "$opt requires a value"
  fi
}

abs_dir() {
  local dir=$1
  [ -d "$dir" ] || die "directory does not exist: $dir"
  (cd "$dir" && pwd -P)
}

is_non_negative_int() {
  case "$1" in
    ""|*[!0-9]*) return 1 ;;
    *) return 0 ;;
  esac
}

is_positive_int() {
  is_non_negative_int "$1" || return 1
  [ "$1" -gt 0 ]
}

file_size_bytes() {
  local file=$1
  local bytes
  if [ ! -f "$file" ]; then
    printf '0'
    return
  fi
  bytes=$(wc -c < "$file" 2>/dev/null || printf '0')
  bytes=${bytes//[[:space:]]/}
  printf '%s' "${bytes:-0}"
}

derive_slug() {
  local raw slug
  raw=$1
  slug=$(
    printf '%s' "$raw" |
      tr '[:upper:]' '[:lower:]' |
      tr -cs '[:alnum:]' '-' |
      sed 's/^-*//; s/-*$//; s/--*/-/g; s/^\(.\{1,48\}\).*/\1/; s/-$//'
  )
  if [ -z "$slug" ]; then
    slug="task"
  fi
  case "$slug" in
    [a-z]*) ;;
    *) slug="task-$slug" ;;
  esac
  printf '%s' "$slug"
}

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
ROOT="$(cd "$SCRIPT_DIR/../../../.." && pwd -P)"
LAUNCHER="$ROOT/.agent0/tools/codex-local-env.sh"
STATE_ROOT="${CODEX_EXEC_STATE_DIR:-$ROOT/.agent0/.runtime-state/codex-exec}"

task=""
task_file=""
model=""
profile=""
reasoning_effort=""
timeout_seconds="${CODEX_EXEC_TIMEOUT_SECONDS:-600}"
progress_interval_seconds="${CODEX_EXEC_PROGRESS_INTERVAL_SECONDS:-30}"
sandbox="read-only"
cwd="$ROOT"
resume_id=""
json=0
output_path=""
slug=""
positional=()

while [ "$#" -gt 0 ]; do
  case "$1" in
    -h|--help)
      usage
      exit 0
      ;;
    --task)
      shift
      require_value "--task" "${1-}"
      task=$1
      ;;
    --task=*)
      task=${1#--task=}
      require_value "--task" "$task"
      ;;
    --task-file)
      shift
      require_value "--task-file" "${1-}"
      task_file=$1
      ;;
    --task-file=*)
      task_file=${1#--task-file=}
      require_value "--task-file" "$task_file"
      ;;
    --model|-m)
      shift
      require_value "--model" "${1-}"
      model=$1
      ;;
    --model=*)
      model=${1#--model=}
      require_value "--model" "$model"
      ;;
    --profile|-p)
      shift
      require_value "--profile" "${1-}"
      profile=$1
      ;;
    --profile=*)
      profile=${1#--profile=}
      require_value "--profile" "$profile"
      ;;
    --reasoning-effort|-e)
      shift
      require_value "--reasoning-effort" "${1-}"
      reasoning_effort=$1
      ;;
    --reasoning-effort=*)
      reasoning_effort=${1#--reasoning-effort=}
      require_value "--reasoning-effort" "$reasoning_effort"
      ;;
    --timeout)
      shift
      require_value "--timeout" "${1-}"
      timeout_seconds=$1
      ;;
    --timeout=*)
      timeout_seconds=${1#--timeout=}
      require_value "--timeout" "$timeout_seconds"
      ;;
    --progress-interval)
      shift
      require_value "--progress-interval" "${1-}"
      progress_interval_seconds=$1
      ;;
    --progress-interval=*)
      progress_interval_seconds=${1#--progress-interval=}
      require_value "--progress-interval" "$progress_interval_seconds"
      ;;
    --sandbox|-s)
      shift
      require_value "--sandbox" "${1-}"
      sandbox=$1
      ;;
    --sandbox=*)
      sandbox=${1#--sandbox=}
      require_value "--sandbox" "$sandbox"
      ;;
    --cwd|--cd)
      shift
      require_value "--cwd" "${1-}"
      cwd=$1
      ;;
    --cwd=*|--cd=*)
      cwd=${1#*=}
      require_value "--cwd" "$cwd"
      ;;
    --resume)
      shift
      require_value "--resume" "${1-}"
      resume_id=$1
      ;;
    --resume=*)
      resume_id=${1#--resume=}
      require_value "--resume" "$resume_id"
      ;;
    --json)
      json=1
      ;;
    --output|-o)
      shift
      require_value "--output" "${1-}"
      output_path=$1
      ;;
    --output=*)
      output_path=${1#--output=}
      require_value "--output" "$output_path"
      ;;
    --slug)
      shift
      require_value "--slug" "${1-}"
      slug=$1
      ;;
    --slug=*)
      slug=${1#--slug=}
      require_value "--slug" "$slug"
      ;;
    --)
      shift
      while [ "$#" -gt 0 ]; do
        positional+=("$1")
        shift
      done
      break
      ;;
    -*)
      die "unknown option: $1"
      ;;
    *)
      positional+=("$1")
      ;;
  esac
  shift || true
done

case "$sandbox" in
  read-only|workspace-write|danger-full-access) ;;
  *) die "invalid --sandbox '$sandbox' (expected read-only, workspace-write, or danger-full-access)" ;;
esac

case "$reasoning_effort" in
  ""|minimal|low|medium|high|xhigh) ;;
  *) die "invalid --reasoning-effort '$reasoning_effort' (expected minimal, low, medium, high, or xhigh)" ;;
esac

if ! is_positive_int "$timeout_seconds"; then
  die "invalid --timeout '$timeout_seconds' (expected positive integer seconds)"
fi
if ! is_non_negative_int "$progress_interval_seconds"; then
  die "invalid --progress-interval '$progress_interval_seconds' (expected non-negative integer seconds)"
fi

if [ -n "$task_file" ]; then
  [ -f "$task_file" ] || die "task file does not exist: $task_file"
  if [ -n "$task" ] || [ "${#positional[@]}" -gt 0 ]; then
    die "use only one prompt source: --task, --task-file, stdin, or -- <prompt>"
  fi
  task=$(cat "$task_file")
elif [ -z "$task" ] && [ "${#positional[@]}" -gt 0 ]; then
  task="${positional[*]}"
elif [ -z "$task" ] && [ ! -t 0 ]; then
  task=$(cat)
fi

if [ -z "$task" ]; then
  die "missing task prompt"
fi

[ -f "$LAUNCHER" ] || die "missing launcher: $LAUNCHER"
command -v codex >/dev/null 2>&1 || die "codex CLI is not on PATH"
command -v timeout >/dev/null 2>&1 || die "timeout is required to bound the Codex subprocess but is not on PATH"

ROOT_REAL="$(abs_dir "$ROOT")"
case "$STATE_ROOT" in
  /*) ;;
  *) STATE_ROOT="$ROOT/$STATE_ROOT" ;;
esac
STATE_ROOT_REAL="$(realpath -m "$STATE_ROOT")"
STATE_ROOT="$STATE_ROOT_REAL"
case "$cwd" in
  /*) ;;
  *) cwd="$ROOT/$cwd" ;;
esac
CWD_REAL="$(abs_dir "$cwd")"
case "$CWD_REAL" in
  "$ROOT_REAL"|"$ROOT_REAL"/*) ;;
  *) die "--cwd must resolve under repo root: $ROOT_REAL" ;;
esac

if [ -n "$slug" ]; then
  case "$slug" in
    [a-z]*)
      if ! printf '%s' "$slug" | grep -Eq '^[a-z][a-z0-9-]*$'; then
        die "--slug must be kebab-case"
      fi
      ;;
    *) die "--slug must start with a lowercase letter" ;;
  esac
else
  slug=$(derive_slug "$task")
fi

timestamp="$(date -u +%Y%m%dT%H%M%SZ)"
iso_ts="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

if [ -n "$output_path" ]; then
  case "$output_path" in
    /*) ;;
    *) output_path="$STATE_ROOT/$output_path" ;;
  esac
  output_path="$(realpath -m "$output_path")"
  output_parent="$(dirname "$output_path")"
  case "$output_parent" in
    "$STATE_ROOT_REAL"|"$STATE_ROOT_REAL"/*) ;;
    *) die "--output must resolve under state dir: $STATE_ROOT_REAL" ;;
  esac
  mkdir -p "$(dirname "$output_path")"
  run_dir="$(cd "$(dirname "$output_path")" && pwd -P)"
  last_message="$output_path"
else
  run_dir="$STATE_ROOT/$timestamp-$slug"
  last_message="$run_dir/last-message.md"
fi

mkdir -p "$run_dir"

prompt_file="$run_dir/prompt.md"
stderr_file="$run_dir/stderr.txt"
metadata_file="$run_dir/metadata.json"
command_file="$run_dir/command.txt"
if [ "$json" -eq 1 ]; then
  stdout_file="$run_dir/events.jsonl"
else
  stdout_file="$run_dir/stdout.txt"
fi

printf '%s\n' "$task" > "$prompt_file"

top_args=(--sandbox "$sandbox")
if [ -n "$model" ]; then
  top_args+=(--model "$model")
fi
if [ -n "$profile" ]; then
  top_args+=(--profile "$profile")
fi
if [ -n "$reasoning_effort" ]; then
  top_args+=(-c "model_reasoning_effort=$reasoning_effort")
fi
if [ "$CWD_REAL" != "$ROOT_REAL" ]; then
  top_args+=(--cd "$CWD_REAL")
fi

sub_args=(--output-last-message "$last_message")
if [ "$json" -eq 1 ]; then
  sub_args=(--json "${sub_args[@]}")
fi

if [ -n "$resume_id" ]; then
  cmd=(bash "$LAUNCHER" "${top_args[@]}" exec resume "${sub_args[@]}" "$resume_id" -)
else
  cmd=(bash "$LAUNCHER" "${top_args[@]}" exec "${sub_args[@]}" -)
fi

printf '%q ' "${cmd[@]}" > "$command_file"
printf '\n' >> "$command_file"

# A bridge sub-invocation is a bounded subprocess, never the handoff-owning
# session — suppress the session-handoff Stop-hook nag so the child (e.g. a
# /squad peer turn) is not blocked into rewriting the orchestrator-owned
# .agent0/HANDOFF.md. (spec 154)
export CLAUDE_SKIP_SESSION_HOOKS=1

set +e
start_epoch="$(date +%s)"
last_progress_epoch="$start_epoch"
exit_status_file="$run_dir/.exit-code"
timed_out=false
elapsed_seconds=0

(
  timeout "${timeout_seconds}s" "${cmd[@]}" < "$prompt_file" > "$stdout_file" 2> "$stderr_file"
  printf '%s\n' "$?" > "$exit_status_file"
) &
runner_pid=$!

while [ ! -f "$exit_status_file" ]; do
  now_epoch="$(date +%s)"
  elapsed_seconds=$((now_epoch - start_epoch))
  if [ "$progress_interval_seconds" -gt 0 ] && [ $((now_epoch - last_progress_epoch)) -ge "$progress_interval_seconds" ]; then
    printf 'codex-exec: still running elapsed=%ss stdout_bytes=%s stderr_bytes=%s\n' \
      "$elapsed_seconds" \
      "$(file_size_bytes "$stdout_file")" \
      "$(file_size_bytes "$stderr_file")" >&2
    last_progress_epoch="$now_epoch"
  fi
  sleep 1
done

wait "$runner_pid"
runner_status=$?
exit_code="$(cat "$exit_status_file" 2>/dev/null)"
rm -f "$exit_status_file"
set -e
if [ -z "$exit_code" ]; then
  exit_code=$runner_status
fi
end_epoch="$(date +%s)"
elapsed_seconds=$((end_epoch - start_epoch))
if [ "$exit_code" -eq 124 ]; then
  timed_out=true
  printf 'codex-exec: timed out after %ss\n' "$timeout_seconds" >&2
fi

if [ ! -f "$last_message" ]; then
  : > "$last_message"
fi

{
  printf '{\n'
  printf '  "ts": %s,\n' "$(json_string "$iso_ts")"
  printf '  "slug": %s,\n' "$(json_string "$slug")"
  printf '  "sandbox": %s,\n' "$(json_string "$sandbox")"
  printf '  "model": %s,\n' "$(json_string "$model")"
  printf '  "profile": %s,\n' "$(json_string "$profile")"
  printf '  "reasoning_effort": %s,\n' "$(json_string "$reasoning_effort")"
  printf '  "timeout_seconds": %s,\n' "$timeout_seconds"
  printf '  "progress_interval_seconds": %s,\n' "$progress_interval_seconds"
  printf '  "timed_out": %s,\n' "$timed_out"
  printf '  "elapsed_seconds": %s,\n' "$elapsed_seconds"
  printf '  "cwd": %s,\n' "$(json_string "$CWD_REAL")"
  printf '  "resume_id": %s,\n' "$(json_string "$resume_id")"
  printf '  "json": %s,\n' "$([ "$json" -eq 1 ] && printf true || printf false)"
  printf '  "exit_code": %s,\n' "$exit_code"
  printf '  "prompt_file": %s,\n' "$(json_string "$prompt_file")"
  printf '  "last_message": %s,\n' "$(json_string "$last_message")"
  printf '  "stdout_file": %s,\n' "$(json_string "$stdout_file")"
  printf '  "stderr_file": %s,\n' "$(json_string "$stderr_file")"
  printf '  "command_file": %s\n' "$(json_string "$command_file")"
  printf '}\n'
} > "$metadata_file"

{
  printf '{"ts":%s,' "$(json_string "$iso_ts")"
  printf '"slug":%s,' "$(json_string "$slug")"
  printf '"sandbox":%s,' "$(json_string "$sandbox")"
  printf '"model":%s,' "$(json_string "$model")"
  printf '"profile":%s,' "$(json_string "$profile")"
  printf '"reasoning_effort":%s,' "$(json_string "$reasoning_effort")"
  printf '"timeout_seconds":%s,' "$timeout_seconds"
  printf '"progress_interval_seconds":%s,' "$progress_interval_seconds"
  printf '"timed_out":%s,' "$timed_out"
  printf '"elapsed_seconds":%s,' "$elapsed_seconds"
  printf '"cwd":%s,' "$(json_string "$CWD_REAL")"
  printf '"resume_id":%s,' "$(json_string "$resume_id")"
  printf '"json":%s,' "$([ "$json" -eq 1 ] && printf true || printf false)"
  printf '"exit_code":%s,' "$exit_code"
  printf '"run_dir":%s,' "$(json_string "$run_dir")"
  printf '"last_message":%s,' "$(json_string "$last_message")"
  printf '"stdout_file":%s,' "$(json_string "$stdout_file")"
  printf '"stderr_file":%s,' "$(json_string "$stderr_file")"
  printf '"metadata":%s}\n' "$(json_string "$metadata_file")"
} >> "$STATE_ROOT/runs.jsonl"

printf 'codex-exec: exit_code=%s\n' "$exit_code"
printf 'run_dir=%s\n' "$run_dir"
printf 'last_message=%s\n' "$last_message"
printf 'stdout_file=%s\n' "$stdout_file"
printf 'stderr_file=%s\n' "$stderr_file"
printf 'metadata=%s\n' "$metadata_file"

exit "$exit_code"
