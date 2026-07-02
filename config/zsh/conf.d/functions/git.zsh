### git ###
# 旧 alias gco が生きたシェルで再 source してもエラーにならないよう先に解除
unalias gco 2>/dev/null
# 引数ありはそのまま checkout、引数なしは fzf でブランチ/タグをあいまい検索
gco() {
	if [ "$#" -gt 0 ]; then
		git checkout "$@"
		return
	fi

	if ! git rev-parse --is-inside-work-tree &>/dev/null; then
		echo "gitリポジトリ内ではありません" >&2
		return 1
	fi

	local selected
	selected=$(git for-each-ref --sort=-committerdate \
		--format='%(refname:short)' refs/heads refs/tags | \
		fzf --exit-0 \
			--prompt='🔀 Checkout > ' \
			--preview 'git log --oneline --graph --color=always -20 {} 2>/dev/null' \
			--preview-window=right:60% \
			--height=80% \
			--border)

	[ -n "$selected" ] && git checkout "$selected"
}

# git worktree + fzf で worktree 移動
worktree-cd() {
  if ! git rev-parse --is-inside-work-tree &>/dev/null; then
    zle -M "gitリポジトリ内ではありません"
    return 1
  fi

  local selected=$(git worktree list | fzf \
    --exit-0 \
    --preview "git -C {1} log --oneline --graph --color=always -20 2>/dev/null" \
    --preview-window=right:50% \
    --height=80% \
    --border)

  if [ -n "$selected" ]; then
    local dir=$(echo "$selected" | awk '{print $1}')
    BUFFER="cd ${(q)dir}"
    zle accept-line
    zle -R -c
  fi
}

zle -N worktree-cd

# ghq + fzf でリポジトリ移動
ghq-cd() {
  local selected=$(ghq list | fzf \
    --preview "bat --color=always --style=header,grid $(ghq root)/{}/README.md 2>/dev/null || echo 'No README found'" \
    --preview-window=right:60% \
    --prompt='📂 Repositories > ' \
    --height=80% \
    --border)
  
  if [ -n "$selected" ]; then
    cd $(ghq root)/$selected
    zle reset-prompt  # プロンプトをリフレッシュ
  fi
}

# Zsh Line Editorに登録
zle -N ghq-cd
