#!/bin/bash
# PreToolUse hook: Bashコマンドの機密ファイルアクセスを検証する

COMMAND=$(jq -r '.tool_input.command // empty')

if [ -z "$COMMAND" ]; then
  exit 0
fi

# 機密ファイルパターン
SENSITIVE_PATTERNS='\.ssh/|\.aws/|\.azure/|\.gnupg/|\.docker/|credentials|id_rsa|id_ed25519|\.secret'

if echo "$COMMAND" | grep -qE "$SENSITIVE_PATTERNS"; then
  echo "ブロック: 機密ファイルへのアクセスが検出されました" >&2
  echo "コマンド: $COMMAND" >&2
  exit 2
fi

# 外部通信による情報流出の検知
# curl/wget で外部サーバーへPOST送信、またはncによる任意通信をブロック
if echo "$COMMAND" | grep -qE '\bcurl\b.*\s--data\b|\bcurl\b.*\s-d\b|\bcurl\b.*\s-X\s*POST\b|\bcurl\b.*--upload-file'; then
  echo '{"decision":"block","reason":"curl によるデータ送信は禁止されています。読み取り専用のGETリクエストのみ許可します"}'
  exit 0
fi
if echo "$COMMAND" | grep -qE '\bwget\b.*--post'; then
  echo '{"decision":"block","reason":"wget によるPOSTリクエストは禁止されています"}'
  exit 0
fi
if echo "$COMMAND" | grep -qE '\bnc\b|\bncat\b|\bnetcat\b'; then
  echo '{"decision":"block","reason":"nc/ncat/netcat による通信は禁止されています"}'
  exit 0
fi

# .envファイルの読み取り検知
if echo "$COMMAND" | grep -qE '(cat|head|tail|less|more|bat)\s+.*\.env(\s|$|\.)|source\s+.*\.env'; then
  echo '{"decision":"block","reason":".envファイルの内容読み取りは禁止されています"}'
  exit 0
fi

# Git force操作の検知（フラグがどの位置にあってもブロック）
if echo "$COMMAND" | grep -qE '^git\s+push\b.*(\s-f\b|\s--force\b|\s--force-with-lease\b)'; then
  echo '{"decision":"block","reason":"git push --force は禁止されています"}'
  exit 0
fi
if echo "$COMMAND" | grep -qE '^git\s+reset\b.*\s--hard\b'; then
  echo '{"decision":"block","reason":"git reset --hard は禁止されています"}'
  exit 0
fi
if echo "$COMMAND" | grep -qE '^git\s+clean\b.*\s-[a-zA-Z]*f'; then
  echo '{"decision":"block","reason":"git clean -f は禁止されています"}'
  exit 0
fi
if echo "$COMMAND" | grep -qE '^git\s+branch\b.*\s-D\b'; then
  echo '{"decision":"block","reason":"git branch -D は禁止されています"}'
  exit 0
fi

exit 0
