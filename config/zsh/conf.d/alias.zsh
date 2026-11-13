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

### opsdesk(Slack 運用デスク、http://127.0.0.1:7420) ###
# ログは $XDG_STATE_HOME/opsdesk/serve.log。画面の URL(key 付き)は起動時にログへ出る
# mise の shim を経由すると実体のフルパスで動くので、パスの有無どちらにも合わせる。
# 末尾を固定し、コマンド文字列に「opsdesk serve」を含むだけのシェルには合わせない
__ods_pattern='(^|/)opsdesk serve$'
ods-start() {
	local log="$XDG_STATE_HOME/opsdesk/serve.log"
	if pgrep -f "$__ods_pattern" >/dev/null; then
		echo "opsdesk serve は起動済み(PID: $(pgrep -f "$__ods_pattern"))"
		return 1
	fi
	mkdir -p "${log:h}"
	# setsid で独立したプロセスグループにし、ods-stop で子の claude -p ごと止められるようにする
	setsid nohup opsdesk serve >>"$log" 2>&1 </dev/null &!
	sleep 2
	if ! pgrep -f "$__ods_pattern" >/dev/null; then
		echo "起動に失敗しました。ログ: $log"
		tail -n 20 "$log"
		return 1
	fi
	grep '画面の URL' "$log" | tail -n 1
}
ods-stop() {
	local pid pgid
	pid="$(pgrep -f "$__ods_pattern")" ||{ echo "opsdesk serve は動いていません"; return 1; }
	pgid="$(ps -o pgid= -p "$pid" | tr -d ' ')"
	# serve は SIGTERM で即終了し子を片付けないため、グループ全体に送る。
	# グループの長でないとき(シェルと同じグループ)はシェルを巻き込まないよう本体だけ止める
	if [[ "$pgid" == "$pid" ]]; then
		kill -TERM -- "-$pgid"
	else
		kill -TERM "$pid"
	fi
	echo "opsdesk serve を停止しました(PID: $pid)"
}

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
