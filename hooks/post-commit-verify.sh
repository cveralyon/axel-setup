#!/bin/bash
# PostToolUse hook (Bash): after a git commit, outputs a reminder for AXEL to
# launch excelsior-verifier on the committed files.
# This is a lightweight trigger — the actual verification runs as a subagent.
#
# Contract: the hook payload arrives as JSON on stdin. PostToolUse does NOT
# include an exit code, so commit success is inferred from the tool output
# (absence of common git failure signals).

INPUT=$(cat)
CMD=$(printf '%s' "$INPUT" | jq -r '.tool_input.command // empty' 2>/dev/null)
OUT=$(printf '%s' "$INPUT" | jq -r '.tool_response.text // .tool_response // empty' 2>/dev/null)

# Only trigger on Bash tool calls that contain 'git commit'
if [[ "$CMD" != *"git commit"* ]]; then
  exit 0
fi

# Infer failure from the tool output: if git refused the commit, bail out.
if printf '%s' "$OUT" | grep -qiE "nothing to commit|no changes added|error:|fatal:|hook declined|rejected"; then
  exit 0
fi

# Get the files from the last commit
CHANGED_FILES=$(git diff-tree --no-commit-id --name-only -r HEAD 2>/dev/null | head -20)
if [ -z "$CHANGED_FILES" ]; then
  exit 0
fi

FILE_COUNT=$(printf '%s' "$CHANGED_FILES" | wc -l | tr -d ' ')
COMMIT_MSG=$(git log --oneline -1 2>/dev/null)

# Only trigger for non-trivial commits (2+ files or test/feature commits)
if [[ "$FILE_COUNT" -lt 2 ]] && [[ "$COMMIT_MSG" != *"feat"* ]] && [[ "$COMMIT_MSG" != *"fix"* ]]; then
  exit 0
fi

# Output advisory to AXEL to launch verifier
cat << EOF
Post-commit verification advisory: Commit "$COMMIT_MSG" modified $FILE_COUNT files:
$(printf '%s' "$CHANGED_FILES" | sed 's/^/  - /')

Consider launching excelsior-verifier as a background agent to verify this commit.
Command: Agent({ subagent_type: "excelsior-verifier", run_in_background: true, prompt: "Verify commit: $COMMIT_MSG. Files: $CHANGED_FILES" })
EOF

exit 0
