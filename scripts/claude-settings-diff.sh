#!/bin/bash
# ~/.claude/settings.json (live) とリポジトリ管理版の drift を検知する
# Claude Code が settings.json を直接書き換えるため live が source of truth。
# --pull で live → repo に取り込む
set -euo pipefail

REPO_FILE="$(cd "$(dirname "$0")/.." && pwd)/config/claude-settings/settings.json"
LIVE_FILE="${HOME}/.claude/settings.json"

if diff <(jq -S . "$REPO_FILE") <(jq -S . "$LIVE_FILE"); then
  echo "drift なし"
  exit 0
fi

if [ "${1:-}" = "--pull" ]; then
  cp "$LIVE_FILE" "$REPO_FILE"
  echo "live → repo に取り込みました。差分を確認して commit してください"
else
  echo "drift があります。live を repo に取り込むには: $0 --pull" >&2
  exit 1
fi
