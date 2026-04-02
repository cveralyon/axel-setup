#!/bin/zsh
# PostToolUse hook: After a git commit, outputs a reminder for AXEL to
# launch excelsior-verifier on the committed files.
# This is a lightweight trigger — the actual verification runs as a subagent.

# Only trigger on Bash tool calls that contain 'git commit'
TOOL_INPUT="${TOOL_INPUT:-}"
if [[ "$TOOL_INPUT" != *"git commit"* ]]; then
  exit 0
fi

# Check if the commit actually succeeded (exit code 0 from the tool)
TOOL_IS_ERROR="${TOOL_RESULT_IS_ERROR:-0}"
if [[ "$TOOL_IS_ERROR" == "1" ]] || [[ "$TOOL_IS_ERROR" == "true" ]]; then
  exit 0
fi

# Get the files from the last commit
CHANGED_FILES=$(git diff-tree --no-commit-id --name-only -r HEAD 2>/dev/null | head -20)
if [ -z "$CHANGED_FILES" ]; then
  exit 0
fi

FILE_COUNT=$(echo "$CHANGED_FILES" | wc -l | tr -d ' ')
COMMIT_MSG=$(git log --oneline -1 2>/dev/null)

# Only trigger for non-trivial commits (2+ files or test/feature commits)
if [[ "$FILE_COUNT" -lt 2 ]] && [[ "$COMMIT_MSG" != *"feat"* ]] && [[ "$COMMIT_MSG" != *"fix"* ]]; then
  exit 0
fi

# Output advisory to AXEL to launch verifier
cat << EOF
Post-commit verification advisory: Commit "$COMMIT_MSG" modified $FILE_COUNT files:
$(echo "$CHANGED_FILES" | sed 's/^/  - /')

Consider launching excelsior-verifier as a background agent to verify this commit.
Command: Agent({ subagent_type: "excelsior-verifier", run_in_background: true, prompt: "Verify commit: $COMMIT_MSG. Files: $CHANGED_FILES" })
EOF

exit 0
