#!/bin/bash
# PreCompact hook (matcher: manual|auto): 圧縮前に transcript を退避する。
# 圧縮後も判断根拠の生ログに戻れるようにするための保険。
# fail-open (常に exit 0)

set -uo pipefail

INPUT=$(cat)
SESSION_ID=$(printf '%s' "$INPUT" | jq -r '.session_id // empty' 2>/dev/null)
TRANSCRIPT=$(printf '%s' "$INPUT" | jq -r '.transcript_path // empty' 2>/dev/null)
if [[ -z "$SESSION_ID" || -z "$TRANSCRIPT" || ! -f "$TRANSCRIPT" ]]; then
  exit 0
fi

BACKUP_DIR="$HOME/.claude/compact-backups"
mkdir -p "$BACKUP_DIR" 2>/dev/null || true
cp "$TRANSCRIPT" "$BACKUP_DIR/${SESSION_ID}_$(date +%Y%m%d-%H%M%S).jsonl" 2>/dev/null || true

# 掃除は1日1回に間引く(圧縮の臨界パスに毎回 find を乗せない)
STAMP="$BACKUP_DIR/.last-cleanup"
if [[ ! -f "$STAMP" ]] || [[ -n "$(find "$STAMP" -mtime +1 2>/dev/null)" ]]; then
  touch "$STAMP" 2>/dev/null || true
  find "$BACKUP_DIR" -maxdepth 1 -name '*.jsonl' -mtime +14 -type f -exec rm -f {} + 2>/dev/null || true
fi
exit 0
