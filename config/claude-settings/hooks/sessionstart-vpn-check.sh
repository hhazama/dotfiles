#!/bin/bash
# SessionStart hook (matcher: startup|resume)
# telemetry の送信先に届かないまま使うと、その間の利用量が集計から欠けて後から補えない。
# 起動時に送信先へ TCP 接続を試し、届かなければ VPN の接続を促す。fail-open (常に exit 0)

set -uo pipefail

# 送信先は組織の remote settings で配布され、hook の環境変数には渡らない
ENDPOINT="${OTEL_EXPORTER_OTLP_ENDPOINT:-$(jq -r '.env.OTEL_EXPORTER_OTLP_ENDPOINT // empty' "$HOME/.claude/remote-settings.json" 2>/dev/null)}"
[[ -z "$ENDPOINT" ]] && exit 0

HOSTPORT="${ENDPOINT#*://}"
HOSTPORT="${HOSTPORT%%/*}"
HOST="${HOSTPORT%:*}"
PORT="${HOSTPORT##*:}"

if timeout 2 bash -c "exec 3<>/dev/tcp/${HOST}/${PORT}" 2>/dev/null; then
  exit 0
fi

jq -n --arg msg "telemetry の送信先 (${HOST}:${PORT}) に接続できません。VPN を確認してください。未接続の間の利用量は集計に残りません。" \
  '{systemMessage: $msg}'
exit 0
