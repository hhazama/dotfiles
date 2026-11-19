#!/usr/bin/env bash
# Claude Code を終えたあとに残った、プロンプト待ちの shell だけのペインをまとめて閉じる。
# herdr の shell コマンド(prefix+alt+x)から使う。
set -u

herdr pane list | jq -r '.result.panes[].pane_id' | while read -r pane; do
	# 前面のプロセスグループが shell 自身なら、何も動かさずプロンプトで待っている(サーバーなどを前面で動かすペインは残す)
	herdr pane process-info --pane "$pane" |
		jq -e '.result.process_info | .foreground_process_group_id == .shell_pid' >/dev/null &&
		herdr pane close "$pane" >/dev/null
done
