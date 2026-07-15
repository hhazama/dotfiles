#!/usr/bin/env bash
# claude-agents-lib.sh の純関数テスト(claude/tmux 非依存)。
set -uo pipefail
DIR="$(cd "$(dirname "$0")/../bin" && pwd)"
. "$DIR/claude-agents-lib.sh"

fail=0
assert_eq() { # name expected actual
  if [ "$2" = "$3" ]; then
    printf 'ok   - %s\n' "$1"
  else
    printf 'FAIL - %s\n' "$1"
    printf '  expected: |%s|\n' "$2"
    printf '  actual:   |%s|\n' "$3"
    fail=1
  fi
}

# --- agents_transform: 状態マップ / age / 並び順 -------------------------------
# now を固定し、startedAt を now からの差で置いて age を決定的にする。
NOW=2000000000000
fixture='[
 {"pid":99001,"cwd":"/nonexistent/proj-alpha","sessionId":"aaaa","startedAt":1999999875000,"name":"alpha-agent","status":"busy"},
 {"pid":99002,"cwd":"/nonexistent/proj-beta","sessionId":"bbbb","startedAt":1999996400000,"name":"beta-agent","status":"waiting"},
 {"pid":99003,"cwd":"/nonexistent/proj-gamma","sessionId":"cccc","startedAt":1999992800000,"name":"gamma-agent","status":"idle"}
]'
out=$(printf '%s' "$fixture" | agents_transform "$NOW" "")
# 並び: waiting(⏳,rank0) → busy(▶,rank1) → idle(✓,rank2)。age=1h/2m/2h。
# panemap 空なので target 空・loc=(no pane)、存在しない cwd なので branch=-。
expected=$'⏳\tbeta-agent\tproj-beta\t-\t1h\t(no pane)\t\t/nonexistent/proj-beta\tbbbb\t99002
▶\talpha-agent\tproj-alpha\t-\t2m\t(no pane)\t\t/nonexistent/proj-alpha\taaaa\t99001
✓\tgamma-agent\tproj-gamma\t-\t2h\t(no pane)\t\t/nonexistent/proj-gamma\tcccc\t99003'
assert_eq "transform: 状態マップ/age/並び順" "$expected" "$out"

# 未知 status は · rank3。
out2=$(printf '%s' '[{"pid":1,"cwd":"/x/z","sessionId":"z","startedAt":0,"name":"z","status":"???"}]' | agents_transform "$NOW" "")
assert_eq "transform: 未知statusは·/age=-(started<=0)" $'·\tz\tz\t-\t-\t(no pane)\t\t/x/z\tz\t1' "$out2"

# 空入力は無出力。
assert_eq "transform: 空配列は無出力" "" "$(printf '[]' | agents_transform "$NOW" "")"

# --- agents_trunc -------------------------------------------------------------
assert_eq "trunc: 超過で…付与"       "abcd…" "$(agents_trunc abcdefgh 5)"
assert_eq "trunc: ちょうどはそのまま" "abcde" "$(agents_trunc abcde 5)"
assert_eq "trunc: 範囲内はそのまま"   "abc"   "$(agents_trunc abc 5)"

# --- session_label ------------------------------------------------------------
assert_eq "label: name優先"          "myname" "$(session_label sid /x/y myname)"
assert_eq "label: name空はcwd名"     "y"      "$(CLAUDE_PROJECTS=/nonexistent session_label '' /x/y '')"

# --- agents_refresh_state: 生成 / スロットル -----------------------------------
fix=$(mktemp); printf '%s' "$fixture" > "$fix"
st=$(mktemp -u); lk=$(mktemp -u)
unset TMUX                                   # tmux 突合を無効化(target 空)
export CLAUDE_AGENTS_CMD="cat $fix"          # json 取得をフィクスチャに差し替え

agents_refresh_state "$st" "$lk" 2
assert_eq "refresh: 初回で生成(3行)" "3" "$(grep -c . "$st" 2>/dev/null || echo 0)"

printf 'SENTINEL\n' > "$st"                  # fresh(mtime新)なら据え置き
agents_refresh_state "$st" "$lk" 999
assert_eq "refresh: fresh時は据え置き" "SENTINEL" "$(cat "$st")"

printf 'SENTINEL\n' > "$st"; touch -d '1 hour ago' "$st"   # stale なら再生成
agents_refresh_state "$st" "$lk" 2
if grep -q SENTINEL "$st"; then
  printf 'FAIL - refresh: stale時に再生成\n  SENTINEL が残存\n'; fail=1
else
  printf 'ok   - refresh: stale時に再生成\n'
fi

unset CLAUDE_AGENTS_CMD
rm -f "$fix" "$st" "$lk"

exit $fail
