# Antigravity 個人開発高スループットハーネス設計

- 日付: 2026-11-20
- 対象リポジトリ: `hhazama/dotfiles`（公開リポジトリ）

## 目的と背景

Claude Code で運用しているハーネス（安全性ガード・フォーマット自動化・完了通知・運用ルール）を Antigravity へ移植しつつ、**個人開発で月 3,000 PR（≒ 1日 100 PR）級の並列・高スループット開発に耐える推奨設定**を `dotfiles` で再現可能に管理する。

Antigravity の設定実体は `~/.gemini/antigravity-cli/` と `~/.gemini/config/` に分かれて配置されるため、`dotfiles` 内でも実配置パスと対応する `home/.gemini/...` 構造に統一して見通しを良くする。

## ゴール / 非ゴール / アンチゴール

### ゴール
- 個人開発における**境界 A（feature ブランチへの `git push` と PR 作成まで自動、マージ・削除・公開は人間承認）**を、機械的なフックとルールで安全に実現する。
- `dotfiles` 内に `home/.gemini/` ミラー構造を新設し、既存の `config/antigravity-settings/` をそこへ統合する。
- Ansible の `links` ロール実行（`--tags links`）だけで、新規環境でも `home/.gemini/` の配置が再現されるようにする。
- 公開 `dotfiles` には個人情報・会社名・社内ホスト・秘密情報を一切入れず、非公開要素（個人トークン・ローカル MCP・固有ルール）は別の非公開リポジトリを Antigravity ローカルプラグインとして外付けできる設計にする。
- フックスクリプトは `shellcheck` / `shfmt` / 単体テストと `gitleaks` をパスする品質にする。

### 非ゴール
- 非公開プラグイン用リポジトリ自体の作成や編集（本作業のスコープは `dotfiles` 側＋外付け接続口のドキュメント／テンプレートまで）。
- Claude Code 固有かつ Antigravity 未対応のフック（`PreCompact` による transcript 退避、`Notification` イベント、社内 VPN/OTEL チェック）の無理な移植。
- `config/claude-settings/` の移行・構成変更（別タスクとして扱う。ただし個人マシンで `--tags links` が途中停止しないよう、既存 Claude `settings.json` コピータスクへの存在チェックガード追加のみ本作業に含める）。
- `superpowers` プラグインの自動更新設定や submodule 固定（今回は導入済み環境をそのまま使う）。

### アンチゴール
- **公開リポジトリへの機密・会社情報の混入**: 社内ホスト・組織名・プロジェクトキー・社内 DB パス・個人アカウント名等の固有文字列が 1 行でも混ざることは失敗。
- **`PreToolUse` で空 JSON `{}` を返すこと／`BypassSandbox: true` やワークスペース外書込を無条件 `allow` すること**: Antigravity 実ランタイムでは `PreToolUse` の `decision` が必須であり、空 `{}` は fail-closed で全ツール拒否になる。安全なサンドボックス内コマンド・ワークスペース内ファイル操作のみ `allow` を返し、`BypassSandbox: true` およびワークスペース外への書込・編集は `ask` を返して標準確認へ委ねる。
- **`~/.gemini/` ディレクトリ丸ごとの symlink 化**: 認証情報・会話ログ・CLI が自動書換する `settings.json` やインストール済みプラグインと衝突する。
- **`Stop` フックで通常の質疑応答までブロックすること**: 通知のみ行い、検証強制は `AGENTS.md` と `superpowers`（`verification-before-completion`）に委ねる。

## 制約

- `hhazama/dotfiles` は公開 GitHub リポジトリであり、`Makefile` に `lint`（`shellcheck`, `shfmt`, `yamllint`, `ansible-lint`）、`secrets`（`gitleaks`）、`check`（`ansible-playbook --check --diff --tags links`）がある。
- Antigravity の `hooks.json` は以下に従う必要がある:
  - トップレベルキーは**フック名**（イベント名直下ではない）。
  - `PreToolUse` / `PostToolUse` は `matcher`＋`hooks` のネスト配列、`SessionStart` / `PreInvocation` / `PostInvocation` / `Stop` はフラット配列。
  - 入出力 JSON キーは **camelCase**（`toolCall.name`, `toolCall.args`, `conversationId`, `cwd` 等）。
  - フックの実行カレントディレクトリは `hooks.json` が置かれたディレクトリ。
  - `type: "command"` の同期実行のみ対応。
- Antigravity のルールファイル（`AGENTS.md`）は 1 ファイル上限 24 KB、常時読込ルール合計 20,000 トークン上限。
- `~/.gemini/antigravity-cli/settings.json` は CLI 自身が設定変更時に実ファイルで書き換えるため、symlink ではなく初回のみ `copy`（`force: no`）にする。

## アプローチ比較

| 案 | 構成 | トレードオフ | 採否 |
|---|---|---|---|
| **案 1（採用）** | `home/.gemini/` 配下に実配置パスをミラーし、Ansible でファイル／サブディレクトリ単位にリンク。非公開資産は別の非公開リポジトリをローカルプラグイン（`plugins.json`）で外付け | 既存 `config/`（`~/.config/` 自動リンク）の規約を壊さず、実パスが直感的に分かる。`dotfiles` 自身の作業時にプロジェクト設定として誤読・二重読込されるリスクもない。`config/antigravity-settings/` の移行が 1 回発生する | **採用** |
| 案 2 | リポジトリルート直下に `.gemini/` を配置 | パスは最短だが、`dotfiles` 作業時に Gemini CLI / Antigravity がカレントの `.gemini/` をプロジェクト設定として二重読込するリスクがある。隠しディレクトリで見落としやすい | 不採用 |
| 案 3 | 既存 `config/antigravity-settings/` をそのまま拡張 | Ansible 変更が最小だが、実配置先（`antigravity-cli/` と `config/`）の構造が見えにくく、希望の配置方針に合わない | 不採用 |

## 設計詳細

### 1. リポジトリ内ディレクトリ構成

```text
home/
└── .gemini/
    ├── antigravity-cli/
    │   ├── settings.json            # ~/.gemini/antigravity-cli/settings.json へ初回のみ copy
    │   └── statusline-command.sh    # ~/.gemini/antigravity-cli/statusline-command.sh へ symlink
    └── config/
        ├── AGENTS.md                # ~/.gemini/config/AGENTS.md へ symlink
        ├── hooks.json               # ~/.gemini/config/hooks.json へ symlink
        ├── plugins.json.sample      # 非公開ローカルプラグイン外付け用サンプル（リンクしない）
        └── hooks/                   # ~/.gemini/config/hooks へ symlink
            ├── validate-command.sh
            ├── guard-sensitive-files.sh
            ├── format-on-edit.sh
            └── notify-on-stop.sh
```

旧 `config/antigravity-settings/`（`settings.json`, `statusline-command.sh`）は `home/.gemini/antigravity-cli/` へ移動し、旧ディレクトリは削除する。

### 2. 各コンポーネントの仕様

#### 2.1 `home/.gemini/antigravity-cli/settings.json`
既存の `statusLine` 設定を維持しつつ、個人開発・高スループット向けの最小限の検証済みキーを設定する。

```json
{
  "agentMode": "auto",
  "enableTerminalSandbox": true,
  "statusLine": {
    "type": "command",
    "command": "~/.gemini/antigravity-cli/statusline-command.sh",
    "enabled": true,
    "padding": 0,
    "stack_with_default": false
  }
}
```

#### 2.2 `home/.gemini/antigravity-cli/statusline-command.sh`
既存の `config/antigravity-settings/statusline-command.sh` をそのまま移設する（機能変更なし）。

#### 2.3 `home/.gemini/config/AGENTS.md`
月 3,000 PR 級の個人開発を支える常設ルール（簡潔に 3〜5 KB 以内に収める）:
- **言語・コミュニケーション**: 日本語で簡潔に応答する。
- **PR 粒度とブランチ運用**:
  - 1 PR 1 関心事を徹底し、レビューしやすい小粒な PR に分割する。
  - `main` / `master` への直接コミット・直接 push は禁止。必ず feature ブランチまたは git worktree で作業する。
  - 独立したタスクはサブエージェント・並列 worktree を積極活用し、巨大な単一 PR を作らない。
- **完了前検証（Verification Gate）**:
  - PR 作成・完了報告の前に、プロジェクトのテスト・lint・型チェックを必ず実行し、実際の結果を確認してから報告する。
- **コミット・PR 衛生**:
  - コミットメッセージに `Co-Authored-By` トレーラーを付けない。
  - PR 本文は「変更内容（What）」「背景・理由（Why）」「検証結果（Verification）」を簡潔に記載する。
  - `gh pr merge` / リポジトリ削除 / パッケージ公開はユーザーの明示的承認を得る。
- **セキュリティ**:
  - `.env`・秘密鍵・トークン等の機密情報を読み取り・出力・コミットしない。

#### 2.4 `home/.gemini/config/hooks.json`
`~/.gemini/config/hooks.json` は Antigravity CLI・IDE・Antigravity 2.0 で共有されるため、**CLI と IDE/2.0 の両方のツール名**を matcher に含める（当方の判断: どのサーフェスから開いてもセキュリティガードが抜けないようにするため）。名前付きフックとして定義し、カレントディレクトリ（`~/.gemini/config`）からの相対パス `./hooks/...` でスクリプトを呼ぶ:

```json
{
  "command-guard": {
    "PreToolUse": [
      {
        "matcher": "run_command",
        "hooks": [
          {
            "type": "command",
            "command": "./hooks/validate-command.sh",
            "timeout": 10
          }
        ]
      }
    ]
  },
  "sensitive-file-guard": {
    "PreToolUse": [
      {
        "matcher": "read_file|write_file|edit_file|view_file|write_to_file|replace_file_content|multi_replace_file_content",
        "hooks": [
          {
            "type": "command",
            "command": "./hooks/guard-sensitive-files.sh",
            "timeout": 10
          }
        ]
      }
    ]
  },
  "format-on-edit": {
    "PostToolUse": [
      {
        "matcher": "edit_file|write_file|write_to_file|replace_file_content|multi_replace_file_content",
        "hooks": [
          {
            "type": "command",
            "command": "./hooks/format-on-edit.sh",
            "timeout": 30
          }
        ]
      }
    ]
  },
  "notify-on-stop": {
    "Stop": [
      {
        "type": "command",
        "command": "./hooks/notify-on-stop.sh",
        "timeout": 10
      }
    ]
  }
}
```

#### 2.5 フックスクリプト仕様（すべて `jq` 利用、未導入時・空入力時の振る舞いを明確化）

1. **`validate-command.sh`（`PreToolUse` / `run_command`）**
   - 入力: `.toolCall.args.CommandLine // empty`
   - 判定優先順位:
     1. **`deny`（機密ファイル参照）**: `.ssh/`, `.aws/`, `.azure/`, `.config/gcloud/`, `.gnupg/`, `.docker/`, `.netrc`, `.npmrc`, `.git-credentials`, `credentials.json`, `id_rsa`, `id_ed25519`, `.secret`, `.pem`, `.key`, および `.env` 読み取り（`cat|head|tail|less|more|bat|sed|awk|grep|rg|source|\.` による `.env` / `.env.*` 参照。`.env.sample` / `.env.example` / `.env.template` は除外）
     2. **`deny`（外部データ送信）**: `curl` の `-d`/`--data*`/`-X POST`/`--upload-file`/`-F`/`--form`、`wget` の `--post*`、`nc`/`ncat`/`netcat`
     3. **`deny`（破壊的ファイル操作）**: `rm` の再帰強制削除で危険パス（`/`, `~`, `$HOME`, `*`, `..` 等）を対象にするもの、`chmod 777`
     4. **`deny`（破壊的・禁止 git 操作）**:
        - `git push` の force 系（`-f`, `-uf` 等の結合フラグ, `--force`, `--force-with-lease`, `--force-if-includes`, `--mirror`, `+refspec`）
        - **`git push` のデフォルトブランチ直押し**（明示的に `main` / `master` や `:main` / `:master` へ push するコマンド、または refspec 省略時に現在ブランチが `main` / `master` の場合を `.cwd` の `git rev-parse --abbrev-ref HEAD` で検知）
        - `git reset --hard`, `git clean -f`（`-fd` 等含む）, `git branch -D`
        - `git commit` での `Co-Authored-By` 付与
     5. **`force_ask`（境界 A の人間承認ゲート）**:
        - `gh pr merge`, `gh repo delete`, `gh release create`, `npm publish`, `cargo publish`, `twine upload`, `docker push`
     6. **中立（上記以外）**: `{}` を出力して終了コード 0（feature ブランチの `git push` や `gh pr create` はここで Antigravity 標準判定へ通す）。
   - `jq` が存在しない場合は安全側（fail-closed）で `{"decision":"ask","reason":"jq が見つからないためコマンド検証を実行できません"}` を返す。

2. **`guard-sensitive-files.sh`（`PreToolUse` / ファイル読書きツール群）**
   - 入力: `.toolCall.args.Path // .toolCall.args.AbsolutePath // .toolCall.args.TargetFile // .toolCall.args.path // empty`（CLI・IDE/2.0 両対応）
   - 対象パスが機密領域（`~/.ssh/`, `~/.aws/`, `~/.azure/`, `~/.config/gcloud/`, `~/.gnupg/`, `~/.docker/`, `~/.netrc`, `~/.npmrc`, `~/.git-credentials`, `*.pem`, `*.key`, `credentials.json`, `.env`, `.env.*` — ただし `.env.sample`/`.env.example`/`.env.template` は許可）に一致したら `{"decision":"deny","reason":"..."}` を返す。
   - 書込・編集ツール（`write_file|edit_file|write_to_file|replace_file_content|multi_replace_file_content`）かつ対象がシェル設定（`~/.bashrc`, `~/.zshrc`, `~/.profile`）なら `{"decision":"force_ask","reason":"シェル初期化ファイルの変更には確認が必要です"}` を返す。
   - 上記以外は `{}` を返す。

3. **`format-on-edit.sh`（`PostToolUse` / ファイル書込・編集ツール群）**
   - 入力: `.toolCall.args.Path // .toolCall.args.TargetFile // .toolCall.args.path // empty`（および `.error // empty`、`.cwd // empty`）。`.error` があるか対象ファイルが存在しない場合は何もしない。
   - 拡張子と「利用可能なツール」に応じて高速・fail-open で整形:
     - `.sh` / `.bash`: `shfmt -w`（`shfmt` が PATH にある場合）
     - `.go`: `gofmt -w`
     - `.rs`: `rustfmt`
     - `.py`: `ruff format --quiet`（`ruff` が PATH にある場合）
     - `.js/.jsx/.ts/.tsx/.json/.css/.scss/.md/.yaml/.yml`: 対象ファイルの親を遡って見つかるプロジェクトローカルの `./node_modules/.bin/biome`（`biome.json`/`biome.jsonc` がある場合）または `./node_modules/.bin/prettier`（prettier 設定がある場合）のみ実行（設定のない repo を勝手に整形しない）
   - ツール自身の出力はすべて `/dev/null` に捨て、常に `{}` を stdout に出力し `exit 0`。

4. **`notify-on-stop.sh`（`Stop`）**
   - `command -v claude-notify.sh` があれば `claude-notify.sh "処理が完了しました" >/dev/null 2>&1 || true`
   - `command -v claude-tmux-notify.sh` があれば `claude-tmux-notify.sh >/dev/null 2>&1 || true`
   - 常に `{}` を stdout に出力し `exit 0`。

#### 2.6 非公開リポジトリとの接続設計
`home/.gemini/config/plugins.json.sample` を用意し、個人環境で非公開プラグイン（トークン・個人 MCP・非公開ルール・追加フック）を足したい場合は `~/.gemini/config/plugins.json` を非公開リポジトリ側のセットアップから配置するだけで自動マージできることを示す:

```json
{
  "entries": [
    {
      "path": "~/path/to/private-plugins"
    }
  ]
}
```

### 3. Ansible / Makefile / ドキュメント更新

- **`ansible/vars/default.yml`**: `home_directory_path: "{{ repo_root_path }}/home"` を追加。
- **`ansible/roles/links/tasks/main.yml`**:
  - 作成ディレクトリに `~/.gemini/config` を追加（`~/.gemini/antigravity-cli` は既存）。
  - 既存 `links | copy claude settings.json (initial only)` に `stat`＋`when` ガードを追加（当方の判断: 社外・純粋な個人マシンでも `--tags links` が途中失敗せず Antigravity 設定まで完走するようにするため）。
  - 旧 symlink `~/.config/antigravity-settings` を `file: state: absent` で安全に掃除する（当方の判断: `config/antigravity-settings/` 削除後のリンク切れ防止）。
  - `config/antigravity-settings/...` のリンク・コピーを `home/.gemini/...` 参照へ切り替え:
    - `home/.gemini/antigravity-cli/statusline-command.sh` → `~/.gemini/antigravity-cli/statusline-command.sh`（symlink, `force: yes`）
    - `home/.gemini/antigravity-cli/settings.json` → `~/.gemini/antigravity-cli/settings.json`（copy, `force: no`, `mode: "0644"`）
      - ※ すでに `~/.gemini/antigravity-cli/settings.json` がある既存マシンでは `force: no` により上書きされない（CLI のランタイム変更を壊さないため）。既存環境への `agentMode` / `enableTerminalSandbox` の反映は、ロールアウト時に既存設定へ不足キーだけ追記する案内（または `/config` での確認）で対応する（当方の判断）。
    - `home/.gemini/config/AGENTS.md` → `~/.gemini/config/AGENTS.md`（symlink, `force: yes`）
    - `home/.gemini/config/hooks.json` → `~/.gemini/config/hooks.json`（symlink, `force: yes`）
    - `home/.gemini/config/hooks` → `~/.gemini/config/hooks`（symlink, `force: yes`）
- **`Makefile`**: `SHELL_FILES` の `config/antigravity-settings/statusline-command.sh` を `home/.gemini/antigravity-cli/statusline-command.sh` に変更し、新規 4 フックスクリプトとテストスクリプトを追加。
- **`CLAUDE.md`**: `home/` ディレクトリの役割（ホーム直下ミラー管理）を 1〜2 行追記。

### 4. テスト・検証計画

- **フック単体テストスクリプト**（例: `scripts/test-antigravity-hooks.sh`）を作成し、Antigravity 形式の camelCase JSON を stdin 投入して以下を検証:
  - `validate-command.sh`: 各 `deny` ケース（機密ファイル、`.env`、`curl -d`、`rm -rf /`、`git push -f`、`main` 直 push、省略時 `main` ブランチ push、`Co-Authored-By`）、各 `force_ask` ケース（`gh pr merge`, `npm publish`）、中立 `{}` ケース（feature ブランチ `git push`、`gh pr create`、`.env.sample` 読み取り、`git status`）。
  - `guard-sensitive-files.sh`: 機密ファイル `deny`、`.env.sample` 許可 `{}`、`.zshrc` 編集 `force_ask`、通常ファイル `{}`（CLI の `Path` と IDE/2.0 の `AbsolutePath` / `TargetFile` 両方のフィクスチャを検証）。
  - `format-on-edit.sh`: 一時 `.sh` ファイル整形＋`{}` 出力（`Path` / `TargetFile` 両対応）、存在しないファイル／エラー時スキップ＋`{}` 出力。
  - `notify-on-stop.sh`: 通知コマンド不在時でも `{}` 出力・exit 0。
- **リポジトリ標準チェック**: `make lint`, `make secrets`, `make check`（Ansible dry-run）の通過を確認。
- **実環境反映**: 実装完了後、Ansible `--tags links` を適用して `~/.gemini/` に反映し、`hooks.json`・`settings.json` の JSON 構文チェックも実施する。

## ビルダーに委ねる事項
- `validate-command.sh` 内の正規表現の細かなエッジケース調整（シェルのクォートやパイプ連鎖の扱いなど）。
- `test-antigravity-hooks.sh` の詳細なテストケース追加や出力フォーマット。
- `AGENTS.md` の具体的な文面（上記方針と 24 KB 上限を満たす範囲）。
