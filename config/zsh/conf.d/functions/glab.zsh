### glab ###
glab() {
	if [ "$#" -eq 0 ] || ! command -v "glab-$1" >/dev/null; then
		command glab "${@:1}"
	else
		"glab-$1" "${@:2}"
	fi
}

glab-root() {
	if [ -z "$GLAB_REPO_BASE" ]; then
		echo "[ERROR] Specific environment variable: GLAB_REPO_BASE"
		return 1
	fi
	echo $GLAB_REPO_BASE
}

glab-list() {
	fd -td -d 4 -gIH '.git' $(glab root) --exec dirname {} | \
	awk -F "/" '{for(i=4;i<NF;i++){printf("%s%s",$i,OFS="/")}print $NF}' | \
	sort
}

glab-get() {
	glab repo clone $1 $(glab root)/$1 -- --recursive
}

widget::glab::source() {
    local session color green="\e[32m" blue="\e[34m" reset="\e[m" checked="\uf631" unchecked="\uf630"
    local sessions=($(tmux list-sessions -F "#S" 2>/dev/null))

    glab list | while read -r repo; do
        session="${repo//[:. ]/-}"
        color="$blue"
		icon="$unchecked"
        if (( ${+sessions[(r)$session]} )); then
            color="$green"
			icon="$checked"
        fi
        printf "$color$icon %s$reset\n" "$repo"
    done
}

widget::glab::select() {
    local root="$(glab root)"
    widget::glab::source | fzf --exit-0 --preview="fzf-preview-git ${(q)root}/{+2}" --preview-window="right:60%" | cut -d' ' -f2-
}

widget::glab::dir() {
    local selected="$(widget::glab::select)"
    if [ -z "$selected" ]; then
        return
    fi

    local root="$(glab root)"
    BUFFER="cd ${(q)root}/$selected"
    zle accept-line
    zle -R -c # refresh screen
}

widget::glab::session() {
    local selected="$(widget::glab::select)"
    if [ -z "$selected" ]; then
        return
    fi

    local root="$(glab root)"
    local repo_dir="${(q)root}/$selected"
    local session_name="${selected//[:. ]/-}"

    echo ${session_name}

    if [ -z "$TMUX" ]; then
        BUFFER="tmux new-session -A -s ${(q)session_name} -c ${repo_dir}"
        zle accept-line
    elif [ "$(tmux display-message -p "#S")" = "$session_name" ] && [ "$PWD" != "$repo_dir" ]; then
        BUFFER="cd ${repo_dir}"
        zle accept-line
    else
        tmux new-session -d -s "$session_name" -c "$repo_dir" 2>/dev/null
        tmux switch-client -t "$session_name"
    fi
    zle -R -c # refresh screen
}

zle -N widget::glab::dir
zle -N widget::glab::session
