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
  if ! echo "$COMMAND" | grep -qE 'source\s+tools/access_db/\.env(\s|$)'; then
    echo '{"decision":"block","reason":".envファイルの内容読み取りは禁止されています"}'
    exit 0
  fi
fi

# コミットメッセージへの Co-Authored-By 付与を検知（CLAUDE.md のルールを機械的に強制）
if echo "$COMMAND" | grep -qE '\bgit\s+commit\b' && echo "$COMMAND" | grep -qi 'co-authored-by'; then
  echo '{"decision":"block","reason":"コミットメッセージに Co-Authored-By は付けないルールです。トレーラーを除いて commit してください"}'
  exit 0
fi

# Git force操作の検知（フラグがどの位置にあってもブロック）
# 行頭に限らず && ; | $( の後ろも見る。先頭の環境変数代入と git -C <dir> / -c k=v などのグローバルオプションも挟める
GIT_PREFIX='(^|[;&|({`]|\$\()\s*(\S+=\S*\s+)*git(\s+-[cC]\s+\S+|\s+--\S+)*\s+'
# -uf のようなまとめ書き、--force-with-lease=<ref>:<sha>、refspec 先頭の + も force になる
if echo "$COMMAND" | grep -qE "${GIT_PREFIX}"'push\b.*(\s-[a-zA-Z]*f[a-zA-Z]*\b|\s--force(-with-lease|-if-includes)?\b|\s--mirror\b|\s\+\S)'; then
  echo '{"decision":"block","reason":"git push --force は禁止されています"}'
  exit 0
fi
if echo "$COMMAND" | grep -qE "${GIT_PREFIX}"'reset\b.*\s--hard\b'; then
  echo '{"decision":"block","reason":"git reset --hard は禁止されています"}'
  exit 0
fi
if echo "$COMMAND" | grep -qE "${GIT_PREFIX}"'clean\b.*\s-[a-zA-Z]*f'; then
  echo '{"decision":"block","reason":"git clean -f は禁止されています"}'
  exit 0
fi
if echo "$COMMAND" | grep -qE "${GIT_PREFIX}"'branch\b.*\s-D\b'; then
  echo '{"decision":"block","reason":"git branch -D は禁止されています"}'
  exit 0
fi

exit 0
