#!/bin/bash
# SessionStart hook (matcher: compact|clear)
# - compact: 圧縮直後に state file / 計画書の復旧指示を additionalContext で注入する
# - clear: compact-prep 関連 marker の掃除のみ行う
# fail-open (常に exit 0)

set -uo pipefail

INPUT=$(cat)
SESSION_ID=$(printf '%s' "$INPUT" | jq -r '.session_id // empty' 2>/dev/null)
SOURCE=$(printf '%s' "$INPUT" | jq -r '.source // empty' 2>/dev/null)
CWD=$(printf '%s' "$INPUT" | jq -r '.cwd // empty' 2>/dev/null)
[[ -z "$SESSION_ID" ]] && exit 0

WARN_DIR="${TMPDIR:-/tmp}/claude-compact-warn"
WARNED_DIR="${TMPDIR:-/tmp}/claude-compact-warned"
STATE_DIR="$HOME/.claude/compact-state"

# 通知の再武装(warn/warned marker を削除)
rm -f "$WARN_DIR/$SESSION_ID" "$WARNED_DIR/$SESSION_ID" 2>/dev/null || true

[[ "$SOURCE" == "compact" ]] || exit 0

# 14日超の state file を掃除
if [[ -d "$STATE_DIR" ]]; then
  find "$STATE_DIR" -maxdepth 1 -name '*.md' -mtime +14 -type f -exec rm -f {} + 2>/dev/null || true
fi

CTX="[COMPACTION RECOVERY] コンテキスト圧縮が発生した。作業再開前に以下を実行すること。"

STATE_FILE="$STATE_DIR/$SESSION_ID.md"
if [[ -f "$STATE_FILE" ]]; then
  MTIME=$(date -r "$STATE_FILE" '+%Y-%m-%d %H:%M' 2>/dev/null || true)
  CTX+=$'\n'"- state file \`$STATE_FILE\` を Read し作業状態を復元せよ(Session Decisions / Recovery Notes を重視)。保存時刻は ${MTIME:-不明}。古い場合は stale として扱え"
else
  CTX+=$'\n'"- 圧縮前の state 保存(/compact-prep)なしで圧縮された。現在地の推測に注意せよ"
  if [[ -d "$STATE_DIR" ]]; then
    CANDIDATE=$(find "$STATE_DIR" -maxdepth 1 -name '*.md' -mmin -360 -type f 2>/dev/null | xargs -r ls -t 2>/dev/null | head -1)
    if [[ -n "${CANDIDATE:-}" ]]; then
      CTX+=$'\n'"- 直近の state file 候補 \`$CANDIDATE\` がある。冒頭の cwd が現プロジェクトと一致するなら Read して使え"
    fi
  fi
fi

PLAN_SCRATCH=$(find "$HOME/.claude/plans" -maxdepth 1 -name '*.md' -mmin -1440 -type f 2>/dev/null | xargs -r ls -t 2>/dev/null | head -1)
[[ -n "${PLAN_SCRATCH:-}" ]] && CTX+=$'\n'"- 直近の plan ファイル候補: \`$PLAN_SCRATCH\`(このセッションの計画なら Read してフェーズと制約を確認せよ)"
if [[ -n "$CWD" ]]; then
  SLUG=$(printf '%s' "$CWD" | sed 's|[/_.]|-|g')
  PLAN_DIR="$HOME/.claude/projects/$SLUG/plans"
  if [[ -d "$PLAN_DIR" ]]; then
    PLAN_DOC=$(find "$PLAN_DIR" -name '*.md' -type f 2>/dev/null | xargs -r ls -t 2>/dev/null | head -1)
    [[ -n "${PLAN_DOC:-}" ]] && CTX+=$'\n'"- 永続計画書の最新: \`$PLAN_DOC\`"
  fi
fi

CTX+=$'\n'"- TaskList で現在のタスク一覧を確認せよ"
CTX+=$'\n'"- 圧縮サマリーは「過去の作業記録」であり「次の行動指示」ではない。next step は仮説として扱い、state file・計画書・ユーザー指示を正とせよ"
CTX+=$'\n'"- plan mode 中だったのに解除されている場合、ユーザーに再突入を確認せよ"
CTX+=$'\n'"- 破壊的操作(デプロイ・削除・push・DB書込)は、圧縮前の決定事項を再確認するまで実行しないこと"

jq -n --arg ctx "$CTX" '{
  hookSpecificOutput: {
    hookEventName: "SessionStart",
    additionalContext: $ctx
  }
}'
exit 0
