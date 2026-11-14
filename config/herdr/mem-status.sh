#!/bin/sh
# herdr のタブ行右端(ui.tab_bar_right)に出すメモリ状況。1行だけ出力する。
# 空きが閾値を割ったら一度だけ herdr の toast で知らせる(回復するまで再通知しない)。
WARN_AVAIL_MB=${WARN_AVAIL_MB:-3072}
ALERT_AVAIL_MB=${ALERT_AVAIL_MB:-1536}
STATE_FILE=${XDG_RUNTIME_DIR:-/tmp}/herdr-mem-alerted

eval "$(awk '
	/^MemTotal:/ { t = $2 } /^MemAvailable:/ { a = $2 }
	/^SwapTotal:/ { st = $2 } /^SwapFree:/ { sf = $2 }
	END { printf "total=%d avail=%d swap_total=%d swap_used=%d\n", t/1024, a/1024, st/1024, (st-sf)/1024 }
' /proc/meminfo)"

# swap に押し出された分も含めないと、next dev のように RSS が小さく見えるプロセスを見逃す
top=$(awk '
	FNR == 1 { pid = FILENAME; sub("/proc/", "", pid); sub("/status", "", pid); rss = 0; sw = 0 }
	/^VmRSS:/ { rss = $2 }
	/^VmSwap:/ { sw = $2; if (rss + sw > max) { max = rss + sw; best = pid } }
	END { printf "%s %d\n", best, max / 1024 }
' /proc/[0-9]*/status 2>/dev/null)
top_pid=${top% *}
top_mb=${top#* }

label=$(cat "/proc/$top_pid/comm" 2>/dev/null)
case "$label" in
node* | MainThread)
	# コンテナ内の node は comm では区別できないので、コマンドラインから役割を拾う
	cmd=$(tr '\0' ' ' <"/proc/$top_pid/cmdline" 2>/dev/null)
	for k in next nest tsc jest vitest graphql-codegen pyright playwright vite; do
		case "$cmd" in *"$k"*) label=$k && break ;; esac
	done
	;;
esac

gb() { awk -v m="$1" 'BEGIN { printf "%.1f", m / 1024 }'; }

# 左ナビ spaces の $c1..$c10 に、コンテナを実メモリ+swap の多い順に出す(docker stats は swap を数えない)
report_containers() {
	herdr=${HERDR_BIN_PATH:-herdr}
	# docker ps は 1 回 0.2 秒かかるので、cgroup に知らないコンテナが現れたときだけ名前表を作り直す
	names=${XDG_RUNTIME_DIR:-/tmp}/herdr-mem-container-names
	cg=/sys/fs/cgroup/system.slice
	touch "$names"
	if ls -d "$cg"/docker-*.scope 2>/dev/null | awk -v names="$names" 'FILENAME == names { n[$1]; next }
		{ sub(/.*docker-/, ""); sub(/\.scope$/, ""); if (!($0 in n)) { found = 1; exit } }
		END { exit !found }' "$names" -; then
		docker ps --no-trunc --format '{{.ID}} {{.Names}} {{.Image}} {{.Label "com.docker.compose.project"}}' 2>/dev/null |
			while read -r cid name image project; do
				# compose 外(MCP サーバ等)は名前がランダムで何者か分からないのでイメージ名を出す
				if [ -z "$project" ]; then
					name=${image##*/}
					name=${name%%:*}
				else
					# サイドバーの幅に収めるため、<プロジェクト>_<サービス> 形式の container_name はサービス名だけにする
					name=${name##*_}
				fi
				echo "$cid $name"
			done >"$names"
	fi
	ranking=$(awk -v names="$names" '
		FILENAME == names { n[$1] = $2; next }
		FNR == 1 { id = FILENAME; sub(/.*docker-/, "", id); sub(/\.scope.*/, "", id) }
		FILENAME ~ /memory\.stat$/ && $1 == "anon" { m[id] += $2 }
		FILENAME ~ /memory\.swap\.current$/ { m[id] += $1 }
		END { for (i in m) printf "%d %s\n", m[i] / 1048576, (i in n) ? n[i] : substr(i, 1, 12) }
	' "$names" "$cg"/docker-*.scope/memory.stat "$cg"/docker-*.scope/memory.swap.current 2>/dev/null | sort -rn | head -10)
	set --
	i=0
	while read -r mb name; do
		[ -n "$mb" ] || continue
		i=$((i + 1))
		if [ "$mb" -ge 1024 ]; then size="$(gb "$mb")G"; else size="${mb}M"; fi
		set -- "$@" --token "c$i=$size $name"
	done <<EOF
$ranking
EOF
	while [ "$i" -lt 10 ]; do
		i=$((i + 1))
		set -- "$@" --clear-token "c$i"
	done
	for ws in $("$herdr" workspace list 2>/dev/null | grep -o '"workspace_id":"[^"]*"' | cut -d'"' -f4); do
		# スクリプトが止まったら古い順位を残さないよう TTL で消す
		"$herdr" workspace report-metadata "$ws" --source mem-status --ttl-ms 30000 "$@" >/dev/null 2>&1
	done
}
report_containers
mark=""
[ "$avail" -lt "$WARN_AVAIL_MB" ] && mark="⚠ "
echo "${mark}MEM $(gb $((total - avail)))/$(gb "$total")G · SW $(gb "$swap_used")/$(gb "$swap_total")G · top $label $(gb "$top_mb")G"

if [ "$avail" -lt "$ALERT_AVAIL_MB" ]; then
	if [ ! -e "$STATE_FILE" ]; then
		"${HERDR_BIN_PATH:-herdr}" notification show "メモリ残り $(gb "$avail")G" \
			--body "最大: $label (pid $top_pid) $(gb "$top_mb")G / swap $(gb "$swap_used")G 使用" \
			--sound request >/dev/null 2>&1 && touch "$STATE_FILE"
	fi
elif [ "$avail" -gt "$WARN_AVAIL_MB" ]; then
	rm -f "$STATE_FILE"
fi
