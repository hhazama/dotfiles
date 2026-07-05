#!/bin/bash
# UserPromptSubmit hook:
# 1. session-map に現セッションの session_id を記録する(compact-prep skill が参照)
# 2. statusline が書いた compact-warn marker を検出したら
#    additionalContext で /compact-prep の提案を注入する(one-shot + cooldown)
# fail-open (常に exit 0)

set -uo pipefail

INPUT=$(cat)
SESSION_ID=$(printf '%s' "$INPUT" | jq -r '.session_id // empty' 2>/dev/null)
CWD=$(printf '%s' "$INPUT" | jq -r '.cwd // empty' 2>/dev/null)
[[ -z "$SESSION_ID" ]] && exit 0

# session-map: cwd-slug → session_id
if [[ -n "$CWD" ]]; then
  MAP_DIR="$HOME/.claude/compact-state/.session-map"
  mkdir -p "$MAP_DIR" 2>/dev/null || true
  SLUG=$(printf '%s' "$CWD" | sed 's|[/_.]|-|g')
  printf '%s\n' "$SESSION_ID" > "$MAP_DIR/$SLUG" 2>/dev/null || true
fi

# warn marker がなければ何もしない
WARN_MARKER="${TMPDIR:-/tmp}/claude-compact-warn/$SESSION_ID"
[[ -f "$WARN_MARKER" ]] || exit 0

CTX_PCT=$(cat "$WARN_MARKER" 2>/dev/null)
CTX_PCT=${CTX_PCT:-"?"}
rm -f "$WARN_MARKER" 2>/dev/null || true

# cooldown marker(SessionStart(compact|clear) が削除して再武装する)
WARNED_DIR="${TMPDIR:-/tmp}/claude-compact-warned"
mkdir -p "$WARNED_DIR" 2>/dev/null || true
printf '%s\n' "$(date +%s)" > "$WARNED_DIR/$SESSION_ID" 2>/dev/null || true

CTX="[COMPACT PREP REMINDER] context 使用率が ${CTX_PCT}% に達した。"
CTX+=$'\n'"- 作業の区切りでユーザーに \`/compact-prep\` → \`/compact\` の実行を提案せよ。"
CTX+=$'\n'"- scope 縮小や別セッション化ではなく、圧縮前の state 保存で対処せよ。"

jq -n --arg ctx "$CTX" '{
  hookSpecificOutput: {
    hookEventName: "UserPromptSubmit",
    additionalContext: $ctx
  }
}'
exit 0
