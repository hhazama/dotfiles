#!/bin/bash
# PostToolUse hook (書込・編集ツール群): 編集直後に利用可能なフォーマッタを fail-open で実行する

set -uo pipefail

finish() {
	printf '{}\n'
	exit 0
}

if ! command -v jq >/dev/null 2>&1; then
	cat >/dev/null 2>&1 || true
	finish
fi

INPUT=$(cat)
TOOL_ERROR=$(printf '%s' "$INPUT" | jq -r '.error // empty' 2>/dev/null)
TARGET_PATH=$(printf '%s' "$INPUT" | jq -r '.toolCall.args.Path // .toolCall.args.TargetFile // .toolCall.args.path // empty' 2>/dev/null)
CWD=$(printf '%s' "$INPUT" | jq -r '.cwd // empty' 2>/dev/null)

if [[ -n "$TOOL_ERROR" || -z "$TARGET_PATH" ]]; then
	finish
fi

# ~/ 展開および相対パスの .cwd 解決（フックのカレントは ~/.gemini/config のため）
if [[ "$TARGET_PATH" == "~/"* ]]; then
	TARGET_PATH="${HOME}/${TARGET_PATH#~/}"
elif [[ "$TARGET_PATH" != /* && -n "$CWD" ]]; then
	TARGET_PATH="${CWD%/}/${TARGET_PATH}"
fi

if [[ ! -f "$TARGET_PATH" ]]; then
	finish
fi

find_project_root() {
	local dir="$1"
	while [[ "$dir" != "/" && -n "$dir" ]]; do
		if [[ -d "$dir/node_modules/.bin" ]]; then
			printf '%s\n' "$dir"
			return 0
		fi
		dir=$(dirname "$dir")
	done
	return 1
}

has_prettier_config() {
	local root="$1"
	local cfg=""
	for cfg in \
		"$root/.prettierrc" \
		"$root/.prettierrc.json" \
		"$root/.prettierrc.yml" \
		"$root/.prettierrc.yaml" \
		"$root/.prettierrc.js" \
		"$root/.prettierrc.cjs" \
		"$root/.prettierrc.mjs" \
		"$root/prettier.config.js" \
		"$root/prettier.config.cjs" \
		"$root/prettier.config.mjs"; do
		if [[ -f "$cfg" ]]; then
			return 0
		fi
	done
	return 1
}

case "$TARGET_PATH" in
*.sh | *.bash)
	if command -v shfmt >/dev/null 2>&1; then
		shfmt -w "$TARGET_PATH" >/dev/null 2>&1 || true
	fi
	;;
*.go)
	if command -v gofmt >/dev/null 2>&1; then
		gofmt -w "$TARGET_PATH" >/dev/null 2>&1 || true
	fi
	;;
*.rs)
	if command -v rustfmt >/dev/null 2>&1; then
		rustfmt "$TARGET_PATH" >/dev/null 2>&1 || true
	fi
	;;
*.py)
	if command -v ruff >/dev/null 2>&1; then
		ruff format --quiet "$TARGET_PATH" >/dev/null 2>&1 || true
	fi
	;;
*.js | *.jsx | *.ts | *.tsx | *.json | *.css | *.scss | *.md | *.yaml | *.yml)
	FILE_DIR=$(cd "$(dirname "$TARGET_PATH")" 2>/dev/null && pwd) || FILE_DIR=""
	if [[ -n "$FILE_DIR" ]]; then
		PROJ_ROOT=$(find_project_root "$FILE_DIR") || PROJ_ROOT=""
		if [[ -n "$PROJ_ROOT" ]]; then
			if [[ -x "$PROJ_ROOT/node_modules/.bin/biome" ]] && { [[ -f "$PROJ_ROOT/biome.json" ]] || [[ -f "$PROJ_ROOT/biome.jsonc" ]]; }; then
				"$PROJ_ROOT/node_modules/.bin/biome" format --write "$TARGET_PATH" >/dev/null 2>&1 || true
			elif [[ -x "$PROJ_ROOT/node_modules/.bin/prettier" ]] && has_prettier_config "$PROJ_ROOT"; then
				"$PROJ_ROOT/node_modules/.bin/prettier" --write "$TARGET_PATH" >/dev/null 2>&1 || true
			fi
		fi
	fi
	;;
esac

finish
