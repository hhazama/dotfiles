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

exit 0
