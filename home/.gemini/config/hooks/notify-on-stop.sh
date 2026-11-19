#!/bin/bash
# Stop hook: ターン完了時に利用可能な通知スクリプトを呼び出し、常に {} を返す

set -uo pipefail

cat >/dev/null 2>&1 || true

if command -v claude-notify.sh >/dev/null 2>&1; then
	claude-notify.sh "処理が完了しました" >/dev/null 2>&1 || true
fi

if command -v claude-tmux-notify.sh >/dev/null 2>&1; then
	claude-tmux-notify.sh >/dev/null 2>&1 || true
fi

printf '{}\n'
exit 0
