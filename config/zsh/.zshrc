### zinit ###
typeset -gAH ZINIT
ZINIT[HOME_DIR]="$XDG_DATA_HOME/zinit"
ZINIT[ZCOMPDUMP_PATH]="$XDG_STATE_HOME/zcompdump"
source "${ZINIT[HOME_DIR]}/bin/zinit.zsh"

### paths ###
typeset -U path
typeset -U fpath

path=(
    "$HOME/.local/bin"(N-/)
    "$CARGO_HOME/bin"(N-/)
    "$VOLTA_HOME/bin"(N-/)
    "$DENO_INSTALL/bin"(N-/)
    "$BREW_HOME/bin"(N-/)
    "$XDG_CONFIG_HOME/scripts/bin"(N-/)
    "$XDG_DATA_HOME/pnpm"
    "$path[@]"
)

fpath=(
    "$BREW_HOME/share/zsh/site-functions"(N-/)
    "$XDG_DATA_HOME/zsh/completions"(N-/)
    "$fpath[@]"
)

eval "$(brew shellenv)"
eval "$(~/.local/bin/mise activate zsh)"
source "$HOME/.rye/env"

setopt AUTO_CD
setopt AUTO_PUSHD
setopt PUSHD_IGNORE_DUPS
setopt GLOBDOTS
setopt APPEND_HISTORY
setopt EXTENDED_HISTORY
setopt HIST_IGNORE_ALL_DUPS
setopt HIST_IGNORE_SPACE
setopt HIST_REDUCE_BLANKS
setopt HIST_SAVE_NO_DUPS
setopt INTERACTIVE_COMMENTS
setopt SHARE_HISTORY
# setopt NO_SHARE_HISTORY
setopt MAGIC_EQUAL_SUBST
setopt PRINT_EIGHT_BIT
setopt nonomatch

zshaddhistory() {
    emulate -L zsh
    [[ ${1%%$'\n'} != ${~HISTORY_IGNORE} ]]
}

# Change the cursor between 'Line' and 'Block' shape
function zle-keymap-select zle-line-init zle-line-finish {
    case "${KEYMAP}" in
        main|viins)
            printf '\033[6 q' # line cursor
            ;;
        vicmd)
            printf '\033[2 q' # block cursor
            ;;
    esac
}
zle -N zle-line-init
zle -N zle-line-finish
zle -N zle-keymap-select

### chpwd-recent-dirs ###
add-zsh-hook chpwd chpwd_recent_dirs
zstyle ':chpwd:*' recent-dirs-file "$XDG_STATE_HOME/chpwd-recent-dirs"

### completion styles ###
zstyle ':completion:*:default' menu select=1
zstyle ':completion:*' list-colors "${(s.:.)LS_COLORS}"

### theme ###
zinit light-mode from'gh-r' as'program' for \
    atclone"./starship init zsh > init.zsh; ./starship completions zsh > _starship" \
    atpull"%atclone" src"init.zsh" \
    @'starship/starship'

### plugins ###
zinit wait lucid null for \
    atinit'source "$ZDOTDIR/.lazy.zsh"' \
    @'zdharma-continuum/null'

if [[ -f "$ZDOTDIR/conf.d/local.zsh" ]]; then
    source "$ZDOTDIR/conf.d/local.zsh"
fi
source "$ZDOTDIR/conf.d/alias.zsh"
source "$ZDOTDIR/conf.d/bindKeys.zsh"
source "$ZDOTDIR/conf.d/command.zsh"
