### zsh-replace-multiple-dots ###
__replace_multiple_dots_atload() {
    replace_multiple_dots_exclude_go() {
        if [[ "$LBUFFER" =~ '^go ' ]]; then
            zle self-insert
        else
            zle .replace_multiple_dots
        fi
    }

    zle -N .replace_multiple_dots replace_multiple_dots
    zle -N replace_multiple_dots replace_multiple_dots_exclude_go
}

zinit wait lucid light-mode for \
    atload'__replace_multiple_dots_atload' \
    @'momo-lab/zsh-replace-multiple-dots'

### zsh-history-substring-search ###
__zsh_history_substring_search_atload() {
    bindkey "${terminfo[kcuu1]}" history-substring-search-up   # arrow-up
    bindkey "${terminfo[kcud1]}" history-substring-search-down # arrow-down
    bindkey "^[[A" history-substring-search-up   # arrow-up
    bindkey "^[[B" history-substring-search-down # arrow-down
}
zinit wait lucid light-mode for \
    atload'__zsh_history_substring_search_atload' \
	@'zsh-users/zsh-history-substring-search'

### zsh-autopair ###
zinit wait'1' lucid light-mode for \
    @'hlissner/zsh-autopair'

### zsh plugins ###
zinit wait lucid blockf light-mode for \
	atload'async_init' @'mafredri/zsh-async' \
	@'zsh-users/zsh-completions' \
	@'zsh-users/zsh-autosuggestions' \
	@'zdharma-continuum/fast-syntax-highlighting'

### hgrep ###
zinit wait lucid light-mode as'program' from'gh-r' for \
    pick'hgrep*/hgrep' \
    @'rhysd/hgrep'

### navi ###
__navi_search() {
    LBUFFER="$(navi --print --query="$LBUFFER")"
    zle reset-prompt
}
__navi_atload() {
    zle -N __navi_search
    bindkey '^N' __navi_search
}
zinit wait lucid light-mode as'program' from'gh-r' for \
    atload'__navi_atload' \
    @'denisidoro/navi'

### zeno.zsh ###
__zeno_atload() {
    bindkey ' ' zeno-auto-snippet
    bindkey '^M' zeno-auto-snippet-and-accept-line
    bindkey '^P' zeno-completion
    bindkey "^R" zeno-history-selection # C-r
}
# NOTE denoがないとインストールできない
if (( ${+commands[deno]} )); then
	zinit wait lucid light-mode for \
        atload'__zeno_atload' \
		@'yuki-yano/zeno.zsh'
fi

### forgit ###
zinit wait lucid light-mode as'program' for \
    pick'bin/git-forgit' \
    @'wfxr/forgit'

### autoloads ###
autoload -Uz compinit
autoload -Uz cdr
autoload -Uz _zinit
zpcompinit
compinit

if type compdef &>/dev/null; then
  _pnpm_completion () {
    local reply
    local si=$IFS

    IFS=$'\n' reply=($(COMP_CWORD="$((CURRENT-1))" COMP_LINE="$BUFFER" COMP_POINT="$CURSOR" pnpm completion -- "${words[@]}"))
    IFS=$si

    if [ "$reply" = "__tabtab_complete_files__" ]; then
      _files
    else
      _describe 'values' reply
    fi
  }
  compdef _pnpm_completion pnpm
fi

eval "$(gh completion -s zsh)"
