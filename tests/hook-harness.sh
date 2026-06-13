#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FIXTURE="$ROOT/tests/fixtures/hooks/events.json"
TMP_ROOT="$(mktemp -d)"

cleanup() {
  rm -rf "$TMP_ROOT"
}
trap cleanup EXIT

assert_file() {
  local path="$1"
  if [ ! -f "$path" ]; then
    echo "Expected file to exist: $path" >&2
    exit 1
  fi
}

assert_contains() {
  local path="$1"
  local expected="$2"
  if ! grep -F -- "$expected" "$path" >/dev/null; then
    echo "Expected $path to contain: $expected" >&2
    exit 1
  fi
}

missing_model_output="$(jq -c '.preToolUseAgentMissingModel' "$FIXTURE" | jq -c -f "$ROOT/hooks/enforce-agent-model.jq")"
echo "$missing_model_output" | jq -e '
  .hookSpecificOutput.hookEventName == "PreToolUse"
  and .hookSpecificOutput.permissionDecision == "deny"
  and (.hookSpecificOutput.permissionDecisionReason | contains("missing required model"))
' >/dev/null

with_model_output="$(jq -c '.preToolUseAgentWithModel' "$FIXTURE" | jq -c -f "$ROOT/hooks/enforce-agent-model.jq")"
if [ -n "$with_model_output" ]; then
  echo "Expected Agent call with model to pass without hook output" >&2
  exit 1
fi

home_dir="$TMP_ROOT/home"
project_dir="$TMP_ROOT/hook-project"
mkdir -p "$home_dir" "$project_dir/src"
printf '%s\n' "const enabled = true;" >"$project_dir/src/example.js"

project_name="$(basename "$project_dir")"
session_log="/tmp/claude-session-log-${project_name}.md"
rm -f "$session_log"

tool_name="$(jq -r '.postToolUseEdit.tool_name' "$FIXTURE")"
tool_input="$(jq -c '.postToolUseEdit.tool_input' "$FIXTURE")"
(
  cd "$project_dir"
  HOME="$home_dir" TOOL_NAME="$tool_name" TOOL_INPUT="$tool_input" \
    bash "$ROOT/hooks/session-log-action.sh"
)

assert_file "$session_log"
assert_contains "$session_log" "example.js"

jq -e '.sessionStop.hook_event_name == "Stop"' "$FIXTURE" >/dev/null
(
  cd "$project_dir"
  HOME="$home_dir" bash "$ROOT/hooks/session-save.sh" < <(jq -c '.sessionStop' "$FIXTURE")
)

session_file="$(ls "$home_dir"/.claude/sessions/hook-project_*.md | head -1)"
assert_file "$session_file"
assert_contains "$session_file" "example.js"

if [ -e "$session_log" ]; then
  echo "Expected session-save.sh to clear $session_log" >&2
  exit 1
fi
