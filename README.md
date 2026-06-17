# Installation

```bash
$ bash <(curl -sL https://raw.githubusercontent.com/hhazama/dotfiles/main/install.sh)
```

- 初回実行時に SSH 鍵(`$HOME/.ssh/id_ed25519_hhazama.pub`)が生成されるので、公開鍵を GitHub に登録する

## 構成

- Ansible で設定を適用する。zsh の入口は `~/.zshenv`(→ `config/zsh/.zshenv`)で、`ZDOTDIR=~/.config/zsh` を設定し `$ZDOTDIR/.zshrc` 以下を読み込む。
- `config/` 配下の各ディレクトリは `links` ロールで `~/.config/` にシンボリックリンクされる。
- 導入される CLI ツール・zsh プラグイン・nvim プラグインの一覧と1行説明は [docs/TOOLS.md](docs/TOOLS.md) を参照。

## 開発

```bash
make setup-hooks  # pre-commit + commit-msg フック(秘密検知 / Conventional Commits 強制)を有効化
make lint         # shellcheck / shfmt / yamllint / ansible-lint(助言的)
make secrets      # gitleaks で秘密情報を走査
make check        # ansible を --check ドライランし links のドリフトを検知
```
