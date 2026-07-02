### utility ###
forward-kill-word() {
	zle vi-forward-word
	zle vi-backward-kill-word
}

zle -N forward-kill-word

mkcd() { command mkdir -p -- "$@" && builtin cd "${@[-1]:a}" }

j() {
	local root dir
	root="${$(git rev-parse --show-cdup 2>/dev/null):-.}"
	dir="$(fd --color=always --hidden --type=d . "$root" | fzf --select-1 --query="$*" --preview='fzf-preview-directory {}')"
	if [ -n "$dir" ]; then
		builtin cd "$dir"
		echo "$PWD"
	fi
}

jj() {
	local root
	root="$(git rev-parse --show-toplevel)" || return 1
	builtin cd "$root"
}


### diff ###
diff() {
	command diff "$@" | bat --paging=never --plain --language=diff
}


### Editor ###
e() {
	tmux split-window -h
	tmux split-window -v
	tmux resize-pane -D 20
	tmux resize-pane -L 60
	tmux select-pane -t 1
	tmux split-window -v
	# clear
	tmux setw synchronize-panes on
	tmux send-keys "clear" C-m
	tmux setw synchronize-panes off
	tmux select-pane -t 3
	tmux send-keys "nvim $@" C-m
}


### ssh ###
# ssh先のterminfoにtmux-256colorが無いことが多いため、pty-req送出時のTERMだけ広く互換性のある値に上書きする
ssh() {
	TERM=xterm-256color command ssh "$@"
}


### shrink path ###
colorlist() {
	for i in {0..255}; do
		printf "\x1b[48;5;${i}m\x1b[38;5;0mcolor%03d\x1b[0m " $i
		if [ $((($i + 1) % 8)) -eq 0 ]; then
			echo
		fi
	done
}
