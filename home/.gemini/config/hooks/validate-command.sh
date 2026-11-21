#!/bin/bash
# PreToolUse hook (run_command): 機密アクセス・破壊的操作・デフォルトブランチ直 push を検証する

set -uo pipefail

if ! command -v jq >/dev/null 2>&1; then
	printf '{"decision":"ask","reason":"jq が見つからないためコマンド検証を実行できません"}\n'
	exit 0
fi

INPUT=$(cat)
COMMAND=$(printf '%s' "$INPUT" | jq -r '.toolCall.args.CommandLine // empty' 2>/dev/null)
CWD=$(printf '%s' "$INPUT" | jq -r '.cwd // empty' 2>/dev/null)
BYPASS_SANDBOX=$(printf '%s' "$INPUT" | jq -r '.toolCall.args.BypassSandbox // false' 2>/dev/null)

if [[ -z "$COMMAND" ]]; then
	printf '{"decision":"allow"}\n'
	exit 0
fi

emit_decision() {
	jq -nc --arg d "$1" --arg r "$2" '{decision: $d, reason: $r}'
	exit 0
}

# 1. 機密ファイル・鍵・認証情報へのアクセス検知
SENSITIVE_PATTERNS='\.ssh/|\.aws/|\.azure/|\.config/gcloud/|\.gnupg/|\.docker/|\.netrc\b|\.npmrc\b|\.git-credentials\b|credentials\.json\b|\bid_rsa\b|\bid_ed25519\b|\.secret\b|\.(pem|key)(\s|$|["'\'';&|)`])'
if printf '%s' "$COMMAND" | grep -qE "$SENSITIVE_PATTERNS"; then
	emit_decision "deny" "機密ファイル・認証情報へのアクセスは禁止されています"
fi

# 2. .env ファイルの読み取り検知（.env.sample / .env.example / .env.template は除外）
CMD_NO_ENV_TEMPLATES=$(printf '%s' "$COMMAND" | sed -E 's/(^|[^[:alnum:]_.-])\.env\.(sample|example|template)([^[:alnum:]_.-]|$)/\1__ENV_TEMPLATE__\3/g')
if printf '%s' "$CMD_NO_ENV_TEMPLATES" | grep -qE '(^|[;&|({`]|\$\()\s*(cat|head|tail|less|more|bat|sed|awk|grep|rg|source|\.)\s+([^;&|)`]*[\s/"'\''])?\.env(\.[[:alnum:]_.-]+)?([\s"'\'';&|)`]|$)'; then
	emit_decision "deny" ".env ファイルの読み取りは禁止されています（.env.sample 等のテンプレートのみ許可）"
fi

# 3. 外部通信によるデータ流出の検知
if printf '%s' "$COMMAND" | grep -qE '(^|[;&|({`]|\$\()\s*curl\b[^;&|)`]*(\s--data(-[a-z]+)?(\s|=)|\s-d(\s|=)|\s-X\s*POST\b|\s--upload-file\b|\s-F\s|\s--form\b)'; then
	emit_decision "deny" "curl によるデータ送信は禁止されています（読み取り専用 GET のみ許可）"
fi
if printf '%s' "$COMMAND" | grep -qE '(^|[;&|({`]|\$\()\s*wget\b[^;&|)`]*\s--post'; then
	emit_decision "deny" "wget による POST リクエストは禁止されています"
fi
if printf '%s' "$COMMAND" | grep -qE '(^|[;&|({`]|\$\()\s*(nc|ncat|netcat)\b'; then
	emit_decision "deny" "nc/ncat/netcat による任意通信は禁止されています"
fi

# 4. 破壊的ファイル操作の検知
if printf '%s' "$COMMAND" | grep -qE '(^|[;&|({`]|\$\()\s*rm\b[^;&|)`]*(\s-[a-zA-Z]*[rR][a-zA-Z]*f|\s-[a-zA-Z]*f[a-zA-Z]*[rR]|\s--recursive\b[^;&|)`]*--force|\s--force\b[^;&|)`]*--recursive)[^;&|)`]*\s["'\'']?(/|/\*|~|~/|\$HOME|\$\{HOME\}|\*|\.\.)["'\'']?(\s|$|[;&|)`])'; then
	emit_decision "deny" "広範囲または危険パスに対する rm -rf は禁止されています"
fi
if printf '%s' "$COMMAND" | grep -qE '(^|[;&|({`]|\$\()\s*chmod\b[^;&|)`]*\s777\b'; then
	emit_decision "deny" "chmod 777 は禁止されています"
fi

# 5. 破壊的・禁止 git 操作の検知
GIT_PREFIX='(^|[;&|({`]|\$\()\s*([A-Za-z_][A-Za-z0-9_]*=\S*\s+)*git(\s+-[cC]\s+\S+|\s+--\S+)*\s+'

if printf '%s' "$COMMAND" | grep -qE "${GIT_PREFIX}"'push\b[^;&|)`]*(\s-[a-zA-Z]*f[a-zA-Z]*(\s|$|[;&|)`])|\s--force(-with-lease|-if-includes)?(=|\s|$|[;&|)`])|\s--mirror(\s|$|[;&|)`])|\s\+\S)'; then
	emit_decision "deny" "git push --force / --mirror / +refspec は禁止されています"
fi

# デフォルトブランチ（main / master）への直接 push 検知（明示指定）
if printf '%s' "$COMMAND" | grep -qE "${GIT_PREFIX}"'push\b[^;&|)`]*(\s(main|master)|:(refs/heads/)?(main|master)|\srefs/heads/(main|master))(\s|$|[;&|)`])'; then
	emit_decision "deny" "main / master ブランチへの直接 push は禁止されています。feature ブランチから PR を作成してください"
fi

# デフォルトブランチ上での省略 push / HEAD push 検知（複数セグメント・-C 指定も走査）
check_default_branch_push_segment() {
	local seg="$1"
	local target_dir="$CWD"
	local -a tokens=()
	read -r -a tokens <<<"$seg"

	local i=0
	local n=${#tokens[@]}
	# 先頭の git トークン位置までスキップ（環境変数代入を除外）
	while [[ $i -lt $n && "${tokens[$i]}" != "git" ]]; do
		i=$((i + 1))
	done
	[[ $i -ge $n ]] && return 0
	i=$((i + 1))

	# git グローバルオプション（-C <dir> 等）を解析しつつ push まで進める
	while [[ $i -lt $n ]]; do
		case "${tokens[$i]}" in
		-C)
			if [[ $((i + 1)) -lt $n ]]; then
				target_dir="${tokens[$((i + 1))]}"
				i=$((i + 2))
				continue
			fi
			;;
		-c)
			i=$((i + 2))
			continue
			;;
		-*)
			i=$((i + 1))
			continue
			;;
		push)
			i=$((i + 1))
			break
			;;
		*)
			return 0
			;;
		esac
		i=$((i + 1))
	done

	[[ -z "$target_dir" ]] && return 0
	command -v git >/dev/null 2>&1 || return 0

	local cur_branch=""
	cur_branch=$(git -C "$target_dir" rev-parse --abbrev-ref HEAD 2>/dev/null || true)
	if [[ "$cur_branch" != "main" && "$cur_branch" != "master" ]]; then
		return 0
	fi

	# push 以降の引数を解析（値を取るフラグをスキップして位置引数を数える）
	local -a positional=()
	while [[ $i -lt $n ]]; do
		local tok="${tokens[$i]}"
		case "$tok" in
		-o | --push-option | --repo | --receive-pack | --exec)
			i=$((i + 2))
			continue
			;;
		--)
			i=$((i + 1))
			while [[ $i -lt $n ]]; do
				positional+=("${tokens[$i]}")
				i=$((i + 1))
			done
			break
			;;
		-*)
			i=$((i + 1))
			continue
			;;
		*)
			positional+=("$tok")
			i=$((i + 1))
			;;
		esac
	done

	# refspec 省略（位置引数 < 2）または明示 HEAD 指定（HEAD / HEAD:main 等）は拒否
	if [[ ${#positional[@]} -lt 2 ]]; then
		emit_decision "deny" "現在のブランチ (${cur_branch}) への直接 push は禁止されています。feature ブランチを作成してください"
	fi
	local refspec=""
	for refspec in "${positional[@]:1}"; do
		if [[ "$refspec" == "HEAD" ]]; then
			emit_decision "deny" "現在のブランチ (${cur_branch}) の HEAD 直接 push は禁止されています。feature ブランチを作成してください"
		fi
	done
}

if printf '%s' "$COMMAND" | grep -qE "${GIT_PREFIX}"'push(\s|$|[;&|)`])'; then
	while IFS= read -r seg || [[ -n "$seg" ]]; do
		[[ -z "$seg" ]] && continue
		check_default_branch_push_segment "$seg"
	done < <(printf '%s\n' "$COMMAND" | sed -E 's/[;&|)`]+/\n/g; s/\$\(/\n/g')
fi

if printf '%s' "$COMMAND" | grep -qE "${GIT_PREFIX}"'reset\b[^;&|)`]*\s--hard(\s|$|[;&|)`])'; then
	emit_decision "deny" "git reset --hard は禁止されています"
fi
if printf '%s' "$COMMAND" | grep -qE "${GIT_PREFIX}"'clean\b[^;&|)`]*\s-[a-zA-Z]*f'; then
	emit_decision "deny" "git clean -f は禁止されています"
fi
if printf '%s' "$COMMAND" | grep -qE "${GIT_PREFIX}"'branch\b[^;&|)`]*\s-D(\s|$|[;&|)`])'; then
	emit_decision "deny" "git branch -D は禁止されています"
fi
if printf '%s' "$COMMAND" | grep -qE "${GIT_PREFIX}"'commit\b' && printf '%s' "$COMMAND" | grep -qi 'co-authored-by'; then
	emit_decision "deny" "コミットメッセージに Co-Authored-By は付けないルールです"
fi

# 6. 境界 A: マージ・リポジトリ削除・公開操作は必ず人間承認（force_ask）
if printf '%s' "$COMMAND" | grep -qE '(^|[;&|({`]|\$\()\s*gh\s+(pr\s+merge|repo\s+delete|release\s+create)\b'; then
	emit_decision "force_ask" "PR マージ・リポジトリ削除・リリース作成にはユーザーの確認が必要です"
fi
if printf '%s' "$COMMAND" | grep -qE '(^|[;&|({`]|\$\()\s*(npm\s+publish|cargo\s+publish|twine\s+upload|docker\s+push)\b'; then
	emit_decision "force_ask" "外部へのパッケージ・イメージ公開操作にはユーザーの確認が必要です"
fi

# 7. サンドボックス外実行 (BypassSandbox: true) は標準承認フローへ委ねる
if [[ "$BYPASS_SANDBOX" == "true" ]]; then
	emit_decision "ask" "サンドボックス外でのコマンド実行には確認が必要です"
fi

# 安全なサンドボックス内コマンドを許可
printf '{"decision":"allow"}\n'
exit 0
