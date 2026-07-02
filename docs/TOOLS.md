# 導入ツール・プラグイン一覧

この dotfiles でインストール・設定されるツールと、それぞれが何をするものかの1行説明。
「`<従来コマンド>` の置き換え」と書いてあるものは、使い慣れたコマンドの見やすい/速い版と考えてよい。

導入の仕組みは大きく分けて以下:

- CLI ツール: Homebrew(`ansible/roles/homebrew`)
- 言語ランタイム: mise(`config/mise/config.toml`)
- グローバル npm: mise ロール内の `npm install --global`
- zsh プラグイン: zinit(`config/zsh/.zshrc`, `config/zsh/.lazy.zsh`)
- nvim プラグイン: lazy.nvim(`config/nvim/lua/nvim.lua`)

---

## CLI ツール(Homebrew)

### 従来コマンドのモダンな置き換え

| ツール | 説明 |
|---|---|
| bat | `cat` の置き換え。シンタックスハイライト・行番号付きでファイルを表示 |
| eza | `ls` の置き換え。色・アイコン・git 状態・ツリー表示に対応 |
| fd | `find` の置き換え。直感的な構文で速くファイル検索 |
| ripgrep (`rg`) | `grep` の置き換え。再帰検索が高速で `.gitignore` を尊重 |
| dust | `du` の置き換え。ディスク使用量をツリーで可視化 |
| duf | `df` の置き換え。ディスクの空き容量をカラフルな表で表示 |
| procs | `ps` の置き換え。プロセス一覧を見やすく表示 |
| btop | `top` の置き換え。CPU/メモリ/プロセスをグラフィカルに監視 |
| zoxide | `cd` の置き換え。よく行くディレクトリを記憶して最短入力で移動 |

### 検索・ファジーファインダー

| ツール | 説明 |
|---|---|
| fzf | 何でも対話的に絞り込めるファジーファインダー。履歴・ファイル選択などの土台 |
| navi | コマンドのチートシートを対話的に検索・実行できるツール |

### Git / GitHub / GitLab

| ツール | 説明 |
|---|---|
| git | バージョン管理システム本体 |
| git-lfs | 大きいバイナリファイルを Git で扱う拡張 |
| git-delta | `git diff` を色付け・行番号付きで見やすく表示するページャ |
| difftastic | 構文を理解して意味的な差分を表示する diff ツール |
| lazygit | Git 操作のターミナル UI。コミットやブランチを対話的に操作 |
| gh | GitHub 公式 CLI。PR・Issue などをターミナルから操作 |
| gh-dash | gh の拡張。PR/Issue をダッシュボード表示(gh extension で導入) |
| glab | GitLab 版 CLI。MR・Issue などを操作 |

### Docker / コンテナ

| ツール | 説明 |
|---|---|
| lazydocker | Docker 操作のターミナル UI。コンテナ/イメージを対話的に管理 |
| docker-completion | docker コマンドのシェル補完定義 |

### シェル / ターミナル / エディタ / プロンプト

| ツール | 説明 |
|---|---|
| zsh | 本環境のログインシェル |
| tmux | ターミナル多重化。1画面を分割し複数セッションを保持 |
| neovim | Vim ベースの高機能エディタ |
| starship | 高速でカスタマイズ可能なシェルプロンプト |

### Python / クラウド / その他ユーティリティ

| ツール | 説明 |
|---|---|
| uv | 高速な Python パッケージ/プロジェクト管理ツール(pip/venv の置き換え) |
| awscli (`aws`) | AWS をコマンドラインから操作する公式 CLI |
| hyperfine | コマンドの実行時間を統計付きで計測するベンチマークツール |
| yq | YAML/JSON/XML を jq 風に操作するコマンド |
| atuin | シェル履歴を SQLite で管理し、横断検索・同期できるツール(`Ctrl-R`) |

### Lint / セキュリティ(開発・CI 用)

| ツール | 説明 |
|---|---|
| shellcheck | シェルスクリプトの静的解析 |
| shfmt | シェルスクリプトのフォーマッタ |
| yamllint | YAML の lint |
| ansible-lint | Ansible playbook の lint |
| gitleaks | リポジトリ内の秘密情報(トークン等)を検出 |
| pre-commit | コミット前にフックを自動実行する仕組み |

---

## 言語ランタイム(mise)

mise は言語ごとのバージョンを管理するツール(asdf 互換)。`config/mise/config.toml` で以下を固定。

| ランタイム | バージョン | 説明 |
|---|---|---|
| node | 22 | JavaScript 実行環境 |
| python | 3.11.3 | Python 実行環境 |
| deno | 1.41.3 | セキュアな JS/TS ランタイム(zsh の zeno.zsh が依存) |
| rust | 1.82.0 | Rust ツールチェーン |
| bun | latest | 高速な JS ランタイム/パッケージマネージャ |
| pnpm | latest | 高速・省ディスクな Node パッケージマネージャ |
| go | latest | Go 言語ツールチェーン |
| java | 21 | Java 実行環境(JDK) |

---

## グローバル npm パッケージ

| パッケージ | 説明 |
|---|---|
| @anthropic-ai/claude-code | Claude Code CLI |
| @openai/codex | OpenAI Codex CLI |

---

## zsh プラグイン(zinit 管理)

zinit はプラグインマネージャ。大半は遅延ロード(`wait lucid`)で起動を軽くしている。

| プラグイン | 説明 |
|---|---|
| zsh-completions | 多数のコマンドの追加補完定義をまとめたもの |
| zsh-autosuggestions | 履歴から入力候補をグレーで提示し、→ で確定 |
| fast-syntax-highlighting | コマンドラインの構文をリアルタイムに色付け |
| fzf-tab | Tab 補完を fzf の絞り込み UI に置き換え |
| zsh-history-substring-search | 入力中の文字列に部分一致する履歴を ↑↓ で辿る |
| zsh-autopair | 括弧やクォートを自動でペア入力 |
| zsh-replace-multiple-dots | `...` を `../..` に自動展開し階層移動を短縮 |
| zsh-async | zsh で非同期処理を行うライブラリ(他プラグインが利用) |
| zeno.zsh | スニペット展開・補完・履歴選択(deno 製、deno 必須) |
| forgit | fzf を使った対話的な git 操作(add/log/diff など) |
| hgrep | マッチ周辺をコード表示する grep(ripgrep ベース) |
| navi | チートシート検索を `Ctrl-N` に割り当て(本体は上記 CLI) |
| starship | プロンプト(本体は上記 CLI。zinit 経由でバイナリ取得) |

zoxide / atuin は Homebrew で導入し、`.lazy.zsh` の `eval` で有効化している。

---

## nvim プラグイン(lazy.nvim 管理)

### LSP / 補完 / フォーマット

| プラグイン | 説明 |
|---|---|
| nvim-lspconfig | 各言語の LSP(言語サーバ)設定をまとめたプラグイン |
| mason.nvim | LSP・リンタ・フォーマッタを nvim 内から導入する管理ツール |
| mason-lspconfig.nvim | mason と lspconfig を橋渡し |
| mason-tool-installer.nvim | 指定したツールを自動インストール |
| fidget.nvim | LSP の進捗を画面端に表示 |
| neodev.nvim | Neovim 設定用 Lua の補完・型情報を提供 |
| typescript-tools.nvim | TypeScript 専用の高速 LSP 連携 |
| nvim-cmp | 補完エンジン本体 |
| LuaSnip | スニペット展開エンジン |
| cmp_luasnip / cmp-nvim-lsp / cmp-path | それぞれ snippet / LSP / パスの補完ソース |
| conform.nvim | 保存時フォーマット(stylua / biome などを呼ぶ) |

### 検索・ファイル操作

| プラグイン | 説明 |
|---|---|
| telescope.nvim | ファイル/文字列/シンボルなどのファジーファインダー |
| telescope-fzf-native.nvim | telescope の絞り込みを高速化する C 実装 |
| telescope-ui-select.nvim | `vim.ui.select` を telescope の UI に置き換え |
| plenary.nvim | 多くのプラグインが依存する Lua ユーティリティ |
| neo-tree.nvim | サイドバー型のファイルエクスプローラ |
| nui.nvim | UI コンポーネントライブラリ(neo-tree / noice が依存) |
| nvim-lsp-file-operations | ファイル移動/リネーム時に LSP へ通知し import を追従 |

### 編集支援

| プラグイン | 説明 |
|---|---|
| nvim-treesitter | 構文解析ベースの高精度なハイライト/インデント |
| mini.nvim | 小さな便利機能群(ここでは ai / surround / statusline を使用) |
| Comment.nvim | `gc` でコメントアウト |
| nvim-autopairs | 括弧/クォートの自動ペア入力 |
| nvim-ts-autotag | HTML/JSX タグの自動閉じ |
| vim-sleuth | インデント幅(tab/space)をファイルから自動判定 |
| hop.nvim | 画面内の任意位置へ数キーでジャンプ |
| indent-blankline.nvim | インデントのガイド線を表示 |
| auto-save.nvim | 変更を自動保存 |

### 見た目 / UI

| プラグイン | 説明 |
|---|---|
| monokai-pro.nvim | カラースキーム(配色テーマ) |
| alpha-nvim | 起動時のスタート画面(ダッシュボード) |
| lualine.nvim | ステータスライン |
| bufferline.nvim | 開いているバッファをタブ風に表示 |
| noice.nvim | コマンドライン/メッセージ/通知の UI を刷新 |
| nvim-web-devicons | ファイルタイプ別のアイコン表示 |
| nvim-colorizer.lua | `#ff0000` などの色コードをその色で表示 |
| nvim-scrollview | スクロールバーを表示 |
| which-key.nvim | 途中まで押したキーに続く候補をポップアップ表示 |
| todo-comments.nvim | TODO / FIXME などのコメントを強調 |
| symbol-usage.nvim | 関数/変数の参照数を行末に表示(CodeLens 風) |

### Git

| プラグイン | 説明 |
|---|---|
| gitsigns.nvim | 変更行を行番号脇に表示し、行内 blame も表示 |
| diffview.nvim | GitLab MR ライクな差分ビュー |
| gitlinker.nvim | 現在行への Git ホスティングのリンクを生成・コピー |

### その他

| プラグイン | 説明 |
|---|---|
| copilot.vim | GitHub Copilot によるコード補完 |
| obsidian.nvim | Obsidian ノートを nvim から操作 |

---

## システム / WSL 連携

| ツール | 説明 |
|---|---|
| wsl-open | WSL から Windows のブラウザなどでファイル/URL を開く(xdg-open 代替) |
| win32yank | WSL と Windows のクリップボードを連携 |
| wl-clipboard (`wl-copy` / `wl-paste`) | Wayland 用のクリップボード操作(nvim から利用) |
| nkf | 日本語の文字コード変換 |
| jq | JSON を整形・抽出するコマンド |

このほか apt で `build-essential` や各種 `lib*-dev` などをインストールするが、これらは他ツールのビルド用依存のため日常的に直接使うものではない。
