#!/bin/bash
# PreToolUse hook (ファイル読書きツール群): 機密ファイルアクセス遮断とワークスペース外書込・シェルRC編集確認

set -uo pipefail

if ! command -v jq >/dev/null 2>&1; then
	printf '{"decision":"ask","reason":"jq が見つからないためファイルアクセス検証を実行できません"}\n'
	exit 0
fi

INPUT=$(cat)
TOOL_NAME=$(printf '%s' "$INPUT" | jq -r '.toolCall.name // empty' 2>/dev/null)
TARGET_PATH=$(printf '%s' "$INPUT" | jq -r '.toolCall.args.Path // .toolCall.args.AbsolutePath // .toolCall.args.TargetFile // .toolCall.args.path // empty' 2>/dev/null)

if [[ -z "$TARGET_PATH" ]]; then
	printf '{"decision":"allow"}\n'
	exit 0
fi

emit_decision() {
	jq -nc --arg d "$1" --arg r "$2" '{decision: $d, reason: $r}'
	exit 0
}

is_write_tool() {
	case "$1" in
	write_file | edit_file | write_to_file | replace_file_content | multi_replace_file_content)
		return 0
		;;
	*)
		return 1
		;;
	esac
}

is_within_allowed_write_scope() {
	local target="$1"
	# パストラバーサル ("..") を含むパスは安全側でワークスペース外扱いとする
	if [[ "$target" == ".." || "$target" == ../* || "$target" == */../* || "$target" == */.. ]]; then
		return 1
	fi
	# 相対パス（親ディレクトリ遡りなし）はワークスペース内とみなす
	if [[ "$target" != /* && "$target" != ~* ]]; then
		return 0
	fi
	if [[ "$target" == /tmp/* ]]; then
		return 0
	fi

	local artifact_dir=""
	artifact_dir=$(printf '%s' "$INPUT" | jq -r '.artifactDirectoryPath // empty' 2>/dev/null)
	if [[ -n "$artifact_dir" ]]; then
		artifact_dir="${artifact_dir%/}"
		if [[ "$target" == "$artifact_dir" || "$target" == "$artifact_dir"/* ]]; then
			return 0
		fi
	fi

	local ws_count=0
	ws_count=$(printf '%s' "$INPUT" | jq -r '(.workspacePaths // []) | length' 2>/dev/null || printf '0')
	if [[ "$ws_count" -eq 0 ]]; then
		return 1
	fi

	local ws=""
	while IFS= read -r ws; do
		[[ -z "$ws" ]] && continue
		ws="${ws%/}"
		if [[ "$target" == "$ws" || "$target" == "$ws"/* ]]; then
			return 0
		fi
	done < <(printf '%s' "$INPUT" | jq -r '(.workspacePaths // [])[]' 2>/dev/null)

	return 1
}

BASENAME=$(basename "$TARGET_PATH")

# 機密ファイル・ディレクトリのアクセス遮断（.env.sample / .env.example / .env.template は除外）
IS_ENV_TEMPLATE=0
case "$BASENAME" in
.env.sample | .env.example | .env.template)
	IS_ENV_TEMPLATE=1
	;;
esac

if [[ "$IS_ENV_TEMPLATE" -eq 0 ]]; then
	if printf '%s' "$TARGET_PATH" | grep -qE '(^|/)(\.ssh|\.aws|\.azure|\.gnupg|\.docker)(/|$)|(^|/)\.config/gcloud(/|$)'; then
		emit_decision "deny" "機密ディレクトリ (${TARGET_PATH}) へのアクセスは禁止されています"
	fi

	case "$BASENAME" in
	.netrc | .npmrc | .git-credentials | credentials.json | .env | .env.* | *.pem | *.key | id_rsa | id_ed25519)
		emit_decision "deny" "機密ファイル (${BASENAME}) へのアクセスは禁止されています"
		;;
	esac
fi

# 書込・編集ツール: シェル初期化ファイルは force_ask、ワークスペース外は ask
if is_write_tool "$TOOL_NAME"; then
	case "$BASENAME" in
	.bashrc | .zshrc | .profile)
		emit_decision "force_ask" "シェル初期化ファイル (${BASENAME}) の変更には確認が必要です"
		;;
	esac

	if ! is_within_allowed_write_scope "$TARGET_PATH"; then
		emit_decision "ask" "ワークスペース外 (${TARGET_PATH}) への書き込み・編集には確認が必要です"
	fi
fi

printf '{"decision":"allow"}\n'
exit 0
