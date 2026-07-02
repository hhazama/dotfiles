# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## リポジトリ概要

このリポジトリは個人の dotfiles を管理するリポジトリです。Ansible を使って設定ファイルのシンボリックリンク作成や各種ツールのインストールを自動化しています。

## セットアップとインストール

### 初回インストール

```bash
# リモートからの初回インストール
bash <(curl -sL https://raw.githubusercontent.com/hhazama/dotfiles/main/install.sh)
```

**注意**: 初回実行時は SSH 鍵(`~/.ssh/id_ed25519_hhazama`)が生成されるので、生成された公開鍵を GitHub に登録する必要があります。

### 手動セットアップ

既にリポジトリをクローン済みの場合:

```bash
# Ansible を使った設定の適用
bash scripts/setup.sh

# 特定のタグのみ実行する場合
cd ansible
ansible-playbook -i ./hosts/local --extra-vars ansible_exec_user=$USER --extra-vars ansible_exec_user_home=$HOME ./site.yml --tags <tag_name>
```

## アーキテクチャ

### ディレクトリ構成

- **ansible/**: Ansible playbook とロール
  - **site.yml**: メインの playbook
  - **roles/**: 各種設定を管理するロール
    - `apt`: apt パッケージのインストール
    - `homebrew`: Homebrew のインストール
    - `links`: config ディレクトリ内のファイルを `~/.config/` にシンボリックリンク
    - `docker`: Docker のセットアップ
    - `zsh`: zsh の設定
    - `mise`: mise(ランタイムバージョン管理ツール)のセットアップ
    - `ssh`: SSH 設定
    - その他: `win32yank`, `sudoers`

- **config/**: 各種ツールの設定ファイル
  - Ansible の `links` ロールにより `~/.config/` 配下にシンボリックリンクが作成される
  - 主要な設定: `nvim`, `tmux`, `zsh`, `git`, `starship`, `navi`, `lazygit`, `lazydocker` など

- **scripts/**: セットアップスクリプト
  - `setup.sh`: Ansible のインストールと実行

- **config/zsh/**: zsh 設定一式。`~/.zshenv`(→ `config/zsh/.zshenv`)が `ZDOTDIR` を `~/.config/zsh` に設定し、`$ZDOTDIR/.zshrc` を読み込む

### 設定ファイルの管理方法

1. `config/` ディレクトリ配下に各ツールの設定を配置
2. Ansible の `links` ロールが `config/` 配下の第1階層のディレクトリを `~/.config/` にシンボリックリンク
3. zsh の入口は `~/.zshenv`(→ `config/zsh/.zshenv`)。これが `ZDOTDIR=~/.config/zsh` を設定し `$ZDOTDIR/.zshrc` 以下を読み込む

### 環境変数とパス

- **XDG_CONFIG_HOME**: `~/.config`
- **ZDOTDIR**: zsh 設定ディレクトリ
- **DATA_DIR**: `/data` (リポジトリのクローン先のベースディレクトリ)

## 設定ファイルの変更方法

### config 配下の設定を変更する場合

1. `config/<ツール名>/` 配下のファイルを直接編集
2. シンボリックリンクを使用しているため、変更は即座に反映される
3. 必要に応じて設定を再読み込み(例: `source ~/.config/zsh/.zshrc`)

### Ansible ロールを変更する場合

1. `ansible/roles/<ロール名>/tasks/main.yml` を編集
2. 変更を適用: `bash scripts/setup.sh` または特定タグで実行
3. テスト環境で動作確認後にコミット

## よく使うコマンド

```bash
# zsh 設定の再読み込み
so  # alias for 'source ${ZDOTDIR}/.zshrc'

# dotfiles ディレクトリへ移動
dot  # alias for 'cd /data/repos/hhazama/dotfiles'

# Ansible の特定ロールのみ実行
cd ansible
ansible-playbook -i ./hosts/local --extra-vars ansible_exec_user=$USER --extra-vars ansible_exec_user_home=$HOME ./site.yml --tags zsh
```

## 開発時の注意事項

### コミットメッセージ

- 日本語で記載すること
- Conventional Commits 形式に従うこと
  - `feat: 機能追加`
  - `fix: バグ修正`
  - `docs: ドキュメントの変更`
  - `style: フォーマットの変更`
  - `refactor: リファクタリング`
  - `chore: その他の変更`

### ブランチ運用

- main ブランチから作業ブランチを作成
- ブランチ名は修正内容を簡潔に表す名前にする

### シンボリックリンクの扱い

- `config/` 配下のファイルは `~/.config/` にシンボリックリンクされる
- リンク切れを防ぐため、ファイルの移動や削除時は注意が必要
- リンクの再作成が必要な場合は `ansible-playbook` を `--tags links` で実行

### 環境依存の設定

- 環境固有の設定は `config/zsh/conf.d/local.zsh` に記載する(gitignore 対象)
- サンプルとして `config/zsh/conf.d/local.zsh.sample` が存在する
