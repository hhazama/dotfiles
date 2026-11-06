### Aliases ###
alias so='source ${ZDOTDIR}/.zshrc'

alias ls='eza --group-directories-first'
alias la='eza --group-directories-first -a'
alias ll='eza --group-directories-first -al --header --color-scale --icons --time-style=long-iso'
alias tree='eza --group-directories-first -T --icons'

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

### Claude Code ###
alias cl='claude'
alias clc='claude --continue'
alias clr='claude -r'
alias clo='claude --model opus'
alias cls='claude --model sonnet'
alias clf='claude --model fable'

alias mt="cd /data/git/webconnect/material_registration"
alias taco="cd /data/git/webconnect/taco"
alias dot="cd /data/repos/hhazama/dotfiles"
alias misc="cd $HOME/ghq/gitlab.fdev/hazama/misc"
alias tiga="tig --all"

### dev-pulse(開発生産性ダッシュボード、http://127.0.0.1:8787) ###
# stop はコンテナを残して止める。restart: unless-stopped なので、止めている間は Docker を再起動しても上がらない
alias dp-start="docker compose -f $HOME/ghq/gitlab.fdev/hazama/dev-pulse/compose.yaml up -d"
alias dp-stop="docker compose -f $HOME/ghq/gitlab.fdev/hazama/dev-pulse/compose.yaml stop"

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
