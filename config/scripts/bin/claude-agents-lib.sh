#!/usr/bin/env bash
# claude agents の状態取得・正規化の中核。claude-sessions とサイドバー系が source して使う。
# 状態→アイコンの対応(waiting→⏳ / busy→▶ / idle→✓)はここが唯一の定義箇所。

# セッションの表示名。/rename 等で付けた name を最優先。無ければ transcript の
# ai-title(会話内容から自動生成される日本語タイトル)、それも無ければ cwd 名。
session_label() {
  local sid="$1" cwd="$2" name="$3" files f title
  [ -n "$name" ] && { printf '%s' "$name"; return; }
  files=( "${CLAUDE_PROJECTS:-$HOME/.claude/projects}"/*/"$sid".jsonl )
  f="${files[0]}"
  if [ -n "$sid" ] && [ -f "$f" ]; then
    title=$(grep -h '"type":"ai-title"' "$f" 2>/dev/null | tail -n1 | jq -r '.aiTitle // empty' 2>/dev/null)
  fi
  printf '%s' "${title:-${cwd##*/}}"
}

# 文字列を最大 MAX 文字に丸める(超過分は末尾を … に)。
agents_trunc() {
  local s="$1" m="$2"
  if [ "${#s}" -gt "$m" ]; then printf '%s…' "${s:0:$((m-1))}"; else printf '%s' "$s"; fi
}

# stdin の `claude agents --json` を正規化して生フィールドを吐く。
#   引数: <now_ms> [pane_map_file]   pane_map_file 行 = "<pane_tty>\t<target>"
#   出力(タブ区切り, rank昇順→古い順): icon label cwdbase branch age loc target cwd sid pid
# 副作用は ps(全プロセス1回)と git(cwd毎)のみ。now と json を固定すれば決定的に検証できる。
agents_transform() {
  local now="$1" panemap="${2:-}"
  local json; json=$(cat)
  [ -n "$json" ] && [ "$json" != "null" ] || return 0
  declare -A TTY_BY_PID PANE_BY_TTY
  local p t tty target status pid cwd sid started name rank icon sec age branch label loc
  while read -r p t; do TTY_BY_PID["$p"]="$t"; done < <(ps -eo pid=,tty=)
  if [ -n "$panemap" ] && [ -f "$panemap" ]; then
    while IFS=$'\t' read -r tty target; do PANE_BY_TTY["$tty"]="$target"; done < "$panemap"
  fi
  printf '%s' "$json" \
    | jq -r '.[] | [(.status//"unknown"), (.pid|tostring), (.cwd//""), (.sessionId//""), ((.startedAt//0)|tostring), (.name//"")] | @tsv' \
    | while IFS=$'\t' read -r status pid cwd sid started name; do
        started=${started:-0}
        case "$status" in
          waiting|needs_input|input) rank=0; icon="⏳";;
          busy|running)              rank=1; icon="▶";;
          idle)                      rank=2; icon="✓";;
          *)                         rank=3; icon="·";;
        esac
        sec=$(( (now - started) / 1000 ))
        if   [ "$started" -le 0 ];  then age="-"
        elif [ "$sec" -lt 60 ];     then age="${sec}s"
        elif [ "$sec" -lt 3600 ];   then age="$((sec/60))m"
        elif [ "$sec" -lt 86400 ];  then age="$((sec/3600))h"
        else                             age="$((sec/86400))d"
        fi
        tty="${TTY_BY_PID[$pid]:-}"; target=""
        if [ -n "$tty" ] && [ "$tty" != "?" ]; then target="${PANE_BY_TTY[/dev/$tty]:-}"; fi
        branch=$(git -C "$cwd" rev-parse --abbrev-ref HEAD 2>/dev/null) || branch="-"
        label=$(session_label "$sid" "$cwd" "$name"); label=${label//[$'\t\n']/ }
        loc="${target:-(no pane)}"
        printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
          "$rank" "$started" "$icon" "$label" "${cwd##*/}" "$branch" "$age" "$loc" "$target" "$cwd" "$sid" "$pid"
      done \
    | sort -k1,1n -k2,2n | cut -f3-
}

# ライブ取得: 今の claude/tmux から状態を吐く(agents_transform のラッパ)。
# 環境変数 CLAUDE_AGENTS_CMD で json 取得コマンドを差し替え可(テスト用)。
agents_rows() {
  local json now panemap
  json=$(${CLAUDE_AGENTS_CMD:-claude agents --json} 2>/dev/null) || return 0
  [ -n "$json" ] || return 0
  now=$(date +%s%3N)
  panemap=""
  if [ -n "${TMUX:-}" ]; then
    panemap=$(mktemp)
    tmux list-panes -a -F '#{pane_tty}	#{session_name}:#{window_index}.#{pane_index}' > "$panemap" 2>/dev/null
  fi
  printf '%s' "$json" | agents_transform "$now" "$panemap"
  [ -n "$panemap" ] && rm -f "$panemap"
}

# サイドバー用: state file が maxage 秒より古い(または無い)時だけ再生成する。
# flock で単一化するので、複数レンダラが毎tick呼んでも claude を叩くのはロック保持者だけ。
# 取得コストはサイドバーのペイン数に依らず「約 maxage 秒に1回」に収まる。
agents_refresh_state() {
  local state="$1" lock="$2" maxage="${3:-2}"
  local now mtime age tmp
  exec 8>"$lock" 2>/dev/null || return 0
  flock -n 8 || return 0
  now=$(date +%s)
  mtime=$(stat -c %Y "$state" 2>/dev/null || echo 0)
  age=$(( now - mtime ))
  if [ ! -e "$state" ] || [ "$age" -ge "$maxage" ]; then
    tmp="${state}.tmp.$$"
    agents_rows > "$tmp" 2>/dev/null
    mv -f "$tmp" "$state"
  fi
  flock -u 8
  exec 8>&-
}
