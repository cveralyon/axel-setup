#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_ROOT="$(mktemp -d)"

cleanup() {
  rm -rf "$TMP_ROOT"
}
trap cleanup EXIT

existing="$TMP_ROOT/existing.json"
axel="$TMP_ROOT/axel.json"
merged="$TMP_ROOT/merged.json"

cat >"$existing" <<'JSON'
{
  "env": {
    "EXISTING_ONLY": "1",
    "CLAUDE_CODE_IDLE_THRESHOLD_MINUTES": "45"
  },
  "permissions": {
    "allow": ["Read(*)"],
    "deny": ["Bash(rm -rf *)"],
    "defaultMode": "acceptEdits"
  },
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "command",
            "command": "echo existing"
          }
        ]
      }
    ]
  },
  "enabledPlugins": {
    "existing@example": true
  }
}
JSON

cat >"$axel" <<'JSON'
{
  "env": {
    "CLAUDE_CODE_IDLE_THRESHOLD_MINUTES": "30",
    "AXEL_ONLY": "1"
  },
  "permissions": {
    "allow": ["Read(*)", "Edit(*)"],
    "deny": ["Bash(dd *)"],
    "defaultMode": "bypassPermissions"
  },
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "command",
            "command": "echo existing"
          }
        ]
      },
      {
        "matcher": "Agent",
        "hooks": [
          {
            "type": "command",
            "command": "jq -c -f hook.jq"
          }
        ]
      }
    ]
  },
  "enabledPlugins": {
    "axel@example": true
  }
}
JSON

jq -s -f "$ROOT/templates/merge-settings.jq" "$existing" "$axel" >"$merged"

jq -e '.env.CLAUDE_CODE_IDLE_THRESHOLD_MINUTES == "45"' "$merged" >/dev/null
jq -e '.env.AXEL_ONLY == "1"' "$merged" >/dev/null
jq -e '.permissions.defaultMode == "acceptEdits"' "$merged" >/dev/null
jq -e '(.permissions.allow | index("Read(*)")) != null' "$merged" >/dev/null
jq -e '(.permissions.allow | index("Edit(*)")) != null' "$merged" >/dev/null
jq -e '(.permissions.deny | index("Bash(dd *)")) != null' "$merged" >/dev/null
jq -e '.hooks.PreToolUse | length == 2' "$merged" >/dev/null
jq -e '.enabledPlugins["existing@example"] == true' "$merged" >/dev/null
jq -e '.enabledPlugins["axel@example"] == true' "$merged" >/dev/null
