#!/bin/bash
# Desktop notification ONLY when Claude Code CLI finishes a main response
# Ignores: subagents, Cursor, other AI tools

# Guard: only notify from Claude Code CLI — skip Cursor, VS Code, and any non-CLI entrypoint
if [ "$CLAUDE_CODE_ENTRYPOINT" != "cli" ]; then
  exit 0
fi

# Guard: skip if this is a subagent (spawned by Agent tool)
# Subagents have CLAUDE_AGENT_ID or run in /tmp worktrees
if [ -n "$CLAUDE_AGENT_ID" ]; then
  exit 0
fi
if echo "$(pwd)" | grep -qE '/tmp/claude|\.worktrees/'; then
  exit 0
fi

# Only notify if terminal is NOT the active app
ACTIVE_APP=$(osascript -e 'tell application "System Events" to get name of first application process whose frontmost is true' 2>/dev/null)

if [[ "$ACTIVE_APP" != "Terminal" ]] && [[ "$ACTIVE_APP" != "iTerm2" ]] && [[ "$ACTIVE_APP" != "Ghostty" ]] && [[ "$ACTIVE_APP" != "WezTerm" ]] && [[ "$ACTIVE_APP" != "kitty" ]] && [[ "$ACTIVE_APP" != "Alacritty" ]]; then
  osascript -e 'display notification "Claude terminó de responder" with title "Claude Code" sound name "Glass"' 2>/dev/null
fi

exit 0
