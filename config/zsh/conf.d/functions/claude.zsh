### Claude Code ###
# 過去セッションを resume (claude -r)。worktree-cd と同じく行を差し替えて実行する
widget::claude::resume() {
	BUFFER="claude -r"
	zle accept-line
}
zle -N widget::claude::resume

# 起動中セッション一覧ポップアップ。tmux ペインへジャンプする作りのため tmux 内限定
widget::claude::sessions() {
	if [[ -z "$TMUX" ]]; then
		zle -M "claude-sessions は tmux 内でのみ使用できます"
		return 1
	fi
	tmux display-popup -w 90% -h 90% -E claude-sessions
	zle reset-prompt
}
zle -N widget::claude::sessions
