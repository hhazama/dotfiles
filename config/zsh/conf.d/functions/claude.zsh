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

# worktree を作成して claude を起動する(並列セッション用)
# 使い方: claude-worktree <ブランチ名> [ベースブランチ]
#   worktree は <repo親>/<repo名>-wt/<ブランチ名> に作られる
#   後片付け: git worktree remove <dir> && git branch -d <ブランチ名>
claude-worktree() {
	if [[ -z "$1" ]]; then
		echo "使い方: claude-worktree <ブランチ名> [ベースブランチ]" >&2
		return 1
	fi
	local repo_root
	repo_root=$(git rev-parse --show-toplevel 2>/dev/null) || {
		echo "gitリポジトリ内で実行してください" >&2
		return 1
	}
	local branch="$1"
	local base="${2:-HEAD}"
	local dir="${repo_root:h}/${repo_root:t}-wt/${branch//\//-}"

	if [[ ! -d "$dir" ]]; then
		mkdir -p "${dir:h}"
		if git show-ref --verify --quiet "refs/heads/${branch}"; then
			git worktree add "$dir" "$branch" || return 1
		else
			git worktree add -b "$branch" "$dir" "$base" || return 1
		fi
	fi

	if [[ -n "$TMUX" ]]; then
		tmux new-window -c "$dir" -n "${branch//\//-}" claude
	else
		cd "$dir" && claude
	fi
}
