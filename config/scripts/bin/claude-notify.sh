#!/bin/bash

# Claude Code completion notification script
# Usage: ./claude-notify.sh [success|error] [optional_message]

set -e

# Default values
CUSTOM_MESSAGE="${1:-"通知"}"
CHANNEL="$MCP_SLACK_CHANNEL"

# 環境変数をチェック
if [ -z "$MCP_SLACK_TOKEN" ]; then
    echo "Warning: MCP_SLACK_TOKEN environment variable is not set. Skipping Slack notification."
    exit 0
fi

if [ -z "$MCP_SLACK_CHANNEL" ]; then
    echo "Warning: MCP_SLACK_CHANNEL environment variable is not set. Skipping Slack notification."
    exit 0
fi

# 通知に載せる情報
DIRECTORY=$(git rev-parse --show-toplevel 2>/dev/null || echo "unknown directory")
BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "unknown branch")
EMOJI=":claude:"

# Slack APIを使用してメッセージを送信（シンプルなBlock Kit使用）
response=$(curl -s -X POST https://slack.com/api/chat.postMessage \
    -H "Authorization: Bearer $MCP_SLACK_TOKEN" \
    -H "Content-Type: application/json" \
    -d "{
        \"channel\": \"$CHANNEL\",
        \"text\": \"$EMOJI $CUSTOM_MESSAGE\",
        \"blocks\": [
            {
                \"type\": \"section\",
                \"text\": {
                    \"type\": \"mrkdwn\",
                    \"text\": \"$EMOJI *$CUSTOM_MESSAGE* \`${DIRECTORY}@${BRANCH}\`\"
                }
            }
        ]
    }")

curl_exit_code=$?

if [ $curl_exit_code -ne 0 ]; then
    echo "Warning: Failed to send Slack notification (curl exit code: $curl_exit_code)"
    exit 0
fi

# Slack APIのエラーをチェック
if echo "$response" | grep -q '"ok":false'; then
    echo "Warning: Slack API returned an error:"
    echo "$response"
    exit 0
fi

echo "Claude Code notification sent to #$CHANNEL"