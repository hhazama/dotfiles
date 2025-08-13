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

# ===== 基本効率化 =====
setopt AUTO_CD                      # ディレクトリ名だけでcd
setopt AUTO_PUSHD                   # 自動でディレクトリスタックに追加
setopt PUSHD_IGNORE_DUPS           # スタックの重複を除去
setopt PUSHD_SILENT                # pushd/popdを静かに実行

# ===== ファイル・グロブ操作 =====
setopt GLOBDOTS                    # 隠しファイルもグロブ対象
setopt EXTENDED_GLOB               # 高度なグロブパターン有効
setopt NO_CASE_GLOB               # 大文字小文字を区別しないグロブ
setopt NUMERIC_GLOB_SORT          # 数値順ソート
setopt NO_NOMATCH                 # グロブマッチしない時エラーにしない
setopt NULL_GLOB                  # パターンマッチしない場合は削除

# ===== 履歴管理（完全版） =====
setopt APPEND_HISTORY             # 履歴をファイルに追記
setopt SHARE_HISTORY              # リアルタイムで履歴共有
setopt INC_APPEND_HISTORY         # 履歴をすぐに追記
setopt HIST_IGNORE_ALL_DUPS       # 重複する履歴を除去
setopt HIST_IGNORE_DUPS           # 連続する重複エントリを除去
setopt HIST_FIND_NO_DUPS          # 検索で重複を表示しない
setopt HIST_IGNORE_SPACE          # スペース始まりは履歴に残さない
setopt HIST_REDUCE_BLANKS         # 余分な空白を除去
setopt HIST_SAVE_NO_DUPS          # 履歴保存時に重複除去
setopt EXTENDED_HISTORY           # タイムスタンプを記録
setopt HIST_VERIFY                # 履歴展開を確認
setopt HIST_NO_STORE              # historyコマンド自体は履歴に残さない

# ===== 補完システム強化 =====
setopt COMPLETE_IN_WORD           # 単語の途中からでも補完
setopt MAGIC_EQUAL_SUBST          # = 以降も補完対象
setopt AUTO_LIST                  # 補完候補をリスト表示
setopt AUTO_MENU                  # Tab連打で補完候補を順番に表示
setopt LIST_TYPES                 # ファイル名の補完で末尾に識別マークを表示
setopt LIST_PACKED                # 補完候補をパックして表示
setopt NO_LIST_BEEP               # 曖昧な補完でベルを鳴らさない

# ===== 対話性・ユーザビリティ =====
setopt INTERACTIVE_COMMENTS       # インタラクティブシェルでコメント有効
setopt PRINT_EIGHT_BIT           # 8ビット文字を正しく表示（日本語対応）
setopt NO_BEEP                   # ビープ音を無効化
setopt LONG_LIST_JOBS            # 長いリストを聞いてから表示
setopt NOTIFY                    # バックグラウンドジョブの状態をすぐに通知
setopt CHECK_JOBS               # exit時にジョブがあれば確認

# ===== プロンプト・表示 =====
setopt PROMPT_SUBST              # プロンプトで変数展開・コマンド置換を有効
setopt TRANSIENT_RPROMPT         # 右プロンプトを一時的に隠す


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
