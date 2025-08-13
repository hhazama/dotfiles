### locale ###
# NOTE 必要があれば設定
# export LANG=""

export COLORTERM=truecolor

### EDITOR ###
export EDITOR="code"

### history ###
export HISTORY_IGNORE="(cd|pwd|l[sal]|jj?|history|clear)"
export HISTFILE="$XDG_STATE_HOME/zsh_history"
export HISTSIZE=1000
export SAVEHIST=1000

### less ###
export LESSHISTFILE='-'

### ls-colors ###
export LS_COLORS="di=01;34:ln=01;36:pi=40;33:so=01;35:do=01;35:bd=40;33;01:cd=40;33;01:or=01;05;37;41:mi=01;05;37;41:su=37;41:sg=30;43:tw=30;42:ow=34;42:st=37;44:ex=01;32"

### XDG ###
export XDG_CONFIG_HOME="$HOME/.config"
export XDG_DATA_HOME="$HOME/.local/share"
export XDG_STATE_HOME="$HOME/.local/state"
export XDG_CACHE_HOME="$HOME/.cache"

### starship ###
export STARSHIP_DIR="$XDG_CONFIG_HOME/starship"
export STARSHIP_CONFIG="$STARSHIP_DIR/starship.toml"
export STARSHIP_CACHE="$XDG_CACHE_HOME/starship"

### zsh ###
export ZDOTDIR="$XDG_CONFIG_HOME/zsh"

### Rust ###
export RUST_BACKTRACE=1
export RUSTUP_HOME="$XDG_DATA_HOME/rustup"
export CARGO_HOME="$XDG_DATA_HOME/cargo"

### Volta ###
export VOLTA_HOME="$XDG_DATA_HOME/volta"

### Deno ###
export DENO_INSTALL="$XDG_DATA_HOME/deno"

### Homebrew ###
export BREW_HOME="/home/linuxbrew/.linuxbrew"

### glab ###
export GLAB_REPO_BASE="/data/repos"

### FZF ###
export FZF_DEFAULT_OPTS='--cycle --reverse --border --ansi --bind="ctrl-d:print-query,ctrl-p:replace-query"'
export FZF_DEFAULT_COMMAND='fd --hidden --color=always'
# export FZF_TMUX=1
export FZF_TMUX_OPTS="-p 80%"

### ripgrep ###
export RIPGREP_CONFIG_PATH="$XDG_CONFIG_HOME/ripgrep/config"

### man ###
export MANPAGER="sh -c 'col -bx | bat --color=always --language=man --plain'"

### zeno ###
export ZENO_ENABLE_FZF_TMUX=1
export ZENO_FZF_TMUX_OPTIONS="-p 90%"
export ZENO_HOME="$XDG_CONFIG_HOME/zeno"
export ZENO_ENABLE_SOCK=1
export ZENO_GIT_CAT="bat --color=always"
export ZENO_GIT_TREE="exa --tree"

### Forgit ###
export FORGIT_INSTALL_DIR="$PWD"
export FORGIT_NO_ALIASES=1

### ripgrep ###
export RIPGREP_CONFIG_PATH="$XDG_CONFIG_HOME/ripgrep/config"

### navi ###
export NAVI_CONFIG="$XDG_CONFIG_HOME/navi/config.yaml"

### Node.js ###
export NODE_REPL_HISTORY="$XDG_STATE_HOME/node_history"

### npm ###
export NPM_CONFIG_DIR="$XDG_CONFIG_HOME/npm"
export NPM_DATA_DIR="$XDG_DATA_HOME/npm"
export NPM_CACHE_DIR="$XDG_CACHE_HOME/npm"
export NPM_CONFIG_USERCONFIG="$NPM_CONFIG_DIR/npmrc"

### pnpm ###
export PNPM_HOME="$XDG_DATA_HOME/pnpm"

### Python ###
export PYTHONSTARTUP="$XDG_CONFIG_HOME/python/startup.py"

### pipenv ###
export PIPENV_VENV_IN_PROJECT=true

### pylint ###
export PYLINTHOME="$XDG_CACHE_HOME/pylint"

### PostgreSQL ###
export PSQL_HISTORY="$XDG_STATE_HOME/psql_history"

### AWS CLI ###
export AWS_CONFIG_FILE="$XDG_CONFIG_HOME/aws/config"
export AWS_SHARED_CREDENTIALS_FILE="$XDG_CONFIG_HOME/aws/credentials"

### auto suggestions ###
export ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE="fg=244"

source "$XDG_CONFIG_HOME/zsh/.zshenv.local"
. "/home/hatano/.local/share/cargo/env"
