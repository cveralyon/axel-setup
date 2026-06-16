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

# Run a stdin-driven hook and assert its exit code.
# Usage: assert_exit <expected_code> <label> <hook_path> <json_payload>
assert_exit() {
  local expected="$1"
  local label="$2"
  local hook="$3"
  local payload="$4"
  local actual=0
  printf '%s' "$payload" | bash "$hook" >/dev/null 2>&1 || actual=$?
  if [ "$actual" -ne "$expected" ]; then
    echo "[$label] expected exit $expected, got $actual" >&2
    exit 1
  fi
}

# ---------------------------------------------------------------------------
# enforce-agent-model.jq — Agent calls must declare a model (deny if missing).
# This jq filter reads the hook payload as JSON on stdin (the correct contract).
# ---------------------------------------------------------------------------
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

# ---------------------------------------------------------------------------
# validate-commit-format.sh — PreToolUse Bash.
# Reads the payload as JSON on stdin (.tool_input.command).
#   valid commit   → exit 0 (allow)
#   invalid commit → exit 2 (block, stderr shown)
#   non-commit cmd → exit 0 (skip)
# ---------------------------------------------------------------------------
VALIDATE_HOOK="$ROOT/hooks/validate-commit-format.sh"

assert_exit 0 "commit: valid format" "$VALIDATE_HOOK" \
  '{"tool_name":"Bash","tool_input":{"command":"git commit -m \"feat (Auth): add OAuth2 login flow\""}}'

assert_exit 2 "commit: invalid format" "$VALIDATE_HOOK" \
  '{"tool_name":"Bash","tool_input":{"command":"git commit -m \"bad message no type\""}}'

assert_exit 2 "commit: missing scope" "$VALIDATE_HOOK" \
  '{"tool_name":"Bash","tool_input":{"command":"git commit -m \"feat: add thing without scope\""}}'

assert_exit 0 "commit: non-commit command skipped" "$VALIDATE_HOOK" \
  '{"tool_name":"Bash","tool_input":{"command":"ls -la"}}'

# ---------------------------------------------------------------------------
# Inline --no-verify guard (mirrors the inline PreToolUse hook in
# templates/settings.json). It reads .tool_input.command from stdin via jq and
# blocks with exit 2 when --no-verify is present.
# ---------------------------------------------------------------------------
no_verify_guard() {
  CMD=$(jq -r '.tool_input.command // empty')
  printf '%s' "$CMD" | grep -qE '\-\-no-verify' && {
    echo 'BLOCKED: --no-verify is prohibited' >&2
    exit 2
  } || exit 0
}
export -f no_verify_guard

guard_exit=0
printf '%s' '{"tool_name":"Bash","tool_input":{"command":"git commit --no-verify -m \"x\""}}' |
  bash -c 'no_verify_guard' >/dev/null 2>&1 || guard_exit=$?
if [ "$guard_exit" -ne 2 ]; then
  echo "[no-verify guard] expected exit 2 for --no-verify, got $guard_exit" >&2
  exit 1
fi

guard_ok_exit=0
printf '%s' '{"tool_name":"Bash","tool_input":{"command":"git commit -m \"feat (X): ok\""}}' |
  bash -c 'no_verify_guard' >/dev/null 2>&1 || guard_ok_exit=$?
if [ "$guard_ok_exit" -ne 0 ]; then
  echo "[no-verify guard] expected exit 0 for clean command, got $guard_ok_exit" >&2
  exit 1
fi

# ---------------------------------------------------------------------------
# session-log-action.sh — PostToolUse logging hook.
# Reads tool_name + tool_input from stdin JSON and appends to the session log.
# ---------------------------------------------------------------------------
home_dir="$TMP_ROOT/home"
project_dir="$TMP_ROOT/hook-project"
mkdir -p "$home_dir" "$project_dir/src"
printf '%s\n' "const enabled = true;" >"$project_dir/src/example.js"

project_name="$(basename "$project_dir")"
session_log="/tmp/claude-session-log-${project_name}.md"
rm -f "$session_log"

edit_payload="$(jq -c '.postToolUseEdit' "$FIXTURE")"
(
  cd "$project_dir"
  HOME="$home_dir" bash "$ROOT/hooks/session-log-action.sh" < <(printf '%s' "$edit_payload")
)

assert_file "$session_log"
assert_contains "$session_log" "example.js"

# Bash action is logged from .tool_input.command
(
  cd "$project_dir"
  HOME="$home_dir" bash "$ROOT/hooks/session-log-action.sh" \
    < <(printf '%s' '{"tool_name":"Bash","tool_input":{"command":"npm test"}}')
)
assert_contains "$session_log" "npm test"

# ---------------------------------------------------------------------------
# session-log-prompt.sh — UserPromptSubmit logging hook.
# Reads .prompt from stdin JSON and appends it to the same session log.
# ---------------------------------------------------------------------------
(
  cd "$project_dir"
  HOME="$home_dir" bash "$ROOT/hooks/session-log-prompt.sh" \
    < <(printf '%s' '{"prompt":"Implement the widget feature"}')
)
assert_contains "$session_log" "Implement the widget feature"

# ---------------------------------------------------------------------------
# session-save.sh — Stop hook. Compiles the session log into a session file
# and clears the temp log. Reads the payload as JSON on stdin.
# ---------------------------------------------------------------------------
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

echo "hook-harness: all assertions passed"
