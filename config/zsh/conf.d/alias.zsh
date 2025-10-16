### Aliases ###
alias so='source ${ZDOTDIR}/.zshrc'

alias la='ls -a'
alias ll='ls -al'
alias exa='eza'
alias ls='exa --group-directories-first'
alias la='exa --group-directories-first -a'
alias ll='exa --group-directories-first -al --header --color-scale --icons --time-style=long-iso'
alias tree='exa --group-directories-first -T --icons'

alias cp='cp -i'
alias mv='mv -i'
alias rm='rm -i'

alias cat='bat --paging=never'
alias batman='bat --language=man --plain'

alias diffall='diff --new-line-format="+%L" --old-line-format="-%L" --unchanged-line-format=" %L"'

alias hgrep="hgrep --hidden --glob='!.git/'"

alias wget='wget --hsts-file="$XDG_STATE_HOME/wget-hsts"'

alias python="python3"
alias pip="pip3"

alias mt="cd ~/gitlab_local/webconnect/material_registration"
alias dot="cd /data/repos/hhazama/dotfiles"
alias gco="git checkout"
alias tiga="tig --all"

if [ -n "$TMUX" ] && [ -n "$FZF_TMUX" ]; then
	__fzf_tmux() {
		if [ -n "$@" ]; then
			fzf-tmux $FZF_TMUX_OPTS -- $@
		else
			fzf-tmux $FZF_TMUX_OPTS
		fi
	}
	alias fzf="fzf-tmux $FZF_TMUX_OPTS -- "
fi

