#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

make build >/dev/null
build/codexU.app/Contents/MacOS/codexU --self-test-updates

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

CODEX_DIR="$TMP_DIR/.codex"
CACHE_DIR="$TMP_DIR/cache"
DB_PATH="$CODEX_DIR/state_5.sqlite"
mkdir -p "$CODEX_DIR" "$CACHE_DIR"

sqlite3 "$DB_PATH" <<'SQL'
CREATE TABLE threads (
  id TEXT PRIMARY KEY,
  title TEXT,
  preview TEXT,
  tokens_used INTEGER,
  updated_at INTEGER,
  recency_at INTEGER,
  created_at INTEGER,
  archived_at INTEGER,
  model TEXT,
  cwd TEXT,
  archived INTEGER,
  rollout_path TEXT
);
INSERT INTO threads VALUES (
  'fixture-thread',
  'Codex-only fixture',
  'Local fixture preview',
  4200,
  1893456000,
  1893456000,
  1893456000,
  NULL,
  'gpt-5',
  '/tmp/codex-only-fixture',
  0,
  NULL
);
SQL

OUTPUT="$TMP_DIR/out.json"
CODEXU_HOME_OVERRIDE="$TMP_DIR" \
CODEXU_CACHE_OVERRIDE="$CACHE_DIR" \
CODEXU_CODEX_PATH_OVERRIDE="$TMP_DIR/missing-codex" \
  build/codexU.app/Contents/MacOS/codexU --dump-json > "$OUTPUT"

grep -q '"schemaVersion" : 2' "$OUTPUT"
grep -q '"id" : "codex"' "$OUTPUT"
grep -q '"displayName" : "Codex"' "$OUTPUT"
grep -q '"lifetimeTokens" : 4200' "$OUTPUT"
grep -q '"threadCount" : 1' "$OUTPUT"

if grep -Eqi 'claude|\.claude' "$OUTPUT"; then
  echo "unexpected non-Codex runtime data in dump" >&2
  exit 1
fi

echo "codex-only checks passed"
