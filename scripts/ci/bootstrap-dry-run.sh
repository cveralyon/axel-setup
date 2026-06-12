#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TMP_HOME="$(mktemp -d)"
TMP_BIN="$(mktemp -d)"

cleanup() {
  rm -rf "$TMP_HOME" "$TMP_BIN"
}
trap cleanup EXIT

cat > "$TMP_BIN/claude" <<'STUB'
#!/usr/bin/env bash
case "${1:-}" in
  --version)
    echo "Claude Code 1.0.0"
    ;;
  plugins)
    exit 0
    ;;
  *)
    echo "claude stub"
    ;;
esac
STUB
chmod +x "$TMP_BIN/claude"

PATH="$TMP_BIN:$PATH" \
HOME="$TMP_HOME" \
bash "$ROOT/bootstrap.sh" \
  --dry-run \
  --user-name "CI Bot" \
  --user-context "CI smoke test" \
  --language english

test -d "$TMP_HOME/.claude/hooks"
test -d "$TMP_HOME/.claude/commands"
test -d "$TMP_HOME/.claude/agents"
