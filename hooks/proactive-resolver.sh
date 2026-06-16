#!/bin/bash
# Excelsior Proactive Resolver — PostToolUse hook for Bash
# Philosophy: ANY failure that can be auto-resolved SHOULD be auto-resolved.
# This hook handles the fast, known patterns. For everything else,
# the CLAUDE.md Excelsior principle tells the model to investigate and resolve.
#
# Contract: the hook payload arrives as JSON on stdin. PostToolUse does NOT
# include an exit code, so instead of gating on a status code we act whenever
# the tool output text contains a known error signal.

INPUT=$(cat)
TOOL_OUTPUT=$(printf '%s' "$INPUT" | jq -r '.tool_response.text // .tool_response // empty' 2>/dev/null)

# Nothing to inspect → nothing to do.
[ -z "$TOOL_OUTPUT" ] && exit 0

# Cheap early-out: only proceed if the output looks like it contains an error.
# This keeps the hook a no-op on successful commands without relying on an
# exit code (which the PostToolUse contract does not provide).
if ! printf '%s' "$TOOL_OUTPUT" | grep -qiE "error|refused|not connect|cannot connect|cannot find|no module|not found|does not exist|already in use|pending|failed|denied"; then
  exit 0
fi

RESOLVED=""

# === SERVICE DETECTION & AUTO-START ===

# Docker (any Docker-related error)
if printf '%s' "$TOOL_OUTPUT" | grep -qiE "docker daemon|Cannot connect to the Docker|docker\.sock|Is the docker daemon running|docker:.*command not found"; then
  if [ "$(uname)" = "Darwin" ] && ! docker info >/dev/null 2>&1; then
    open -a "Docker" 2>/dev/null
    for i in $(seq 1 15); do docker info >/dev/null 2>&1 && break; sleep 1; done
    if docker info >/dev/null 2>&1; then
      RESOLVED="Docker Desktop started automatically."
    else
      RESOLVED="HINT: Docker Desktop is launching. Wait a few seconds and retry."
    fi
  fi
fi

# PostgreSQL (any PG connection error)
if printf '%s' "$TOOL_OUTPUT" | grep -qiE "PG::|postgresql.*refused|could not connect.*5432|could not connect.*5433|connection to server.*failed.*postgres"; then
  if [ "$(uname)" = "Darwin" ]; then
    brew services start postgresql@16 2>/dev/null || brew services start postgresql 2>/dev/null
    STOPPED_PG=$(docker ps -a --filter "ancestor=postgres" --filter "status=exited" --format "{{.Names}}" 2>/dev/null | head -1)
    [ -n "$STOPPED_PG" ] && docker start "$STOPPED_PG" 2>/dev/null
    RESOLVED="PostgreSQL restart attempted."
  fi
fi

# Redis
if printf '%s' "$TOOL_OUTPUT" | grep -qiE "Redis.*refused|ECONNREFUSED.*6379|Redis::CannotConnectError|redis.*not connect"; then
  brew services start redis 2>/dev/null && RESOLVED="Redis started via Homebrew."
fi

# MySQL
if printf '%s' "$TOOL_OUTPUT" | grep -qiE "mysql.*refused|ECONNREFUSED.*3306|Access denied for user.*mysql"; then
  brew services start mysql 2>/dev/null && RESOLVED="MySQL started via Homebrew."
fi

# === DEPENDENCY RESOLUTION ===

# Node modules missing
if printf '%s' "$TOOL_OUTPUT" | grep -qiE "Cannot find module|MODULE_NOT_FOUND|ERR_MODULE_NOT_FOUND" && [ -f "package.json" ]; then
  if [ -f "pnpm-lock.yaml" ]; then
    RESOLVED="HINT: Run 'pnpm install' — missing node_modules detected."
  elif [ -f "yarn.lock" ]; then
    RESOLVED="HINT: Run 'yarn install' — missing node_modules detected."
  elif [ -f "package-lock.json" ]; then
    RESOLVED="HINT: Run 'npm install' — missing node_modules detected."
  fi
fi

# Ruby gems missing
if printf '%s' "$TOOL_OUTPUT" | grep -qiE "Could not find gem|Bundler::GemNotFound|bundle install|Gem::MissingSpecError"; then
  RESOLVED="HINT: Run 'bundle install' — missing gems detected."
fi

# Python deps missing
if printf '%s' "$TOOL_OUTPUT" | grep -qiE "ModuleNotFoundError|No module named|ImportError.*No module"; then
  if [ -f "requirements.txt" ]; then
    RESOLVED="HINT: Run 'pip install -r requirements.txt' — missing Python module."
  elif [ -f "pyproject.toml" ]; then
    RESOLVED="HINT: Run 'pip install -e .' or 'poetry install' — missing Python module."
  fi
fi

# === ENVIRONMENT ISSUES ===

# Port in use — identify the blocker
if printf '%s' "$TOOL_OUTPUT" | grep -qiE "EADDRINUSE|Address already in use|port.*already.*use|bind.*address already"; then
  PORT=$(printf '%s' "$TOOL_OUTPUT" | grep -oE "[0-9]{4,5}" | head -1)
  [ -n "$PORT" ] && PID=$(lsof -ti ":$PORT" 2>/dev/null | head -1)
  [ -n "$PID" ] && PROC=$(ps -p "$PID" -o comm= 2>/dev/null)
  [ -n "$PROC" ] && RESOLVED="HINT: Port $PORT blocked by $PROC (PID $PID). Kill with: kill $PID"
fi

# Database not created
if printf '%s' "$TOOL_OUTPUT" | grep -qiE "database.*does not exist|Unknown database|FATAL.*database.*not exist"; then
  DB=$(printf '%s' "$TOOL_OUTPUT" | grep -oE '"[^"]*"' | head -1 | tr -d '"')
  RESOLVED="HINT: Database '$DB' doesn't exist. Create it: rails db:create or createdb $DB"
fi

# Migrations pending
if printf '%s' "$TOOL_OUTPUT" | grep -qiE "Migrations are pending|pending migration|migrate.*first"; then
  RESOLVED="HINT: Pending migrations. Run: rails db:migrate RAILS_ENV=test"
fi

# === OUTPUT ===
if [ -n "$RESOLVED" ]; then
  echo "PROACTIVE: $RESOLVED Retry your command." >&2
fi

# Always exit 0 — this hook advises, never blocks
exit 0
