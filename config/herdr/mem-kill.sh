#!/usr/bin/env bash
# メモリを食っている docker コンテナとプロセスを、実メモリ+swap の多い順に並べて選んで止める。
# herdr の popup(prefix+m)から使う。Tab で複数選択、Enter で停止、Esc で閉じる。
set -u

list() {
	declare -A cname
	while read -r id name; do cname[$id]=$name; done < <(docker ps --no-trunc --format '{{.ID}} {{.Names}}' 2>/dev/null)

	# コンテナは cgroup の anon+swap を見る(docker stats は swap を含まず、swap に逃げたコンテナが小さく見える)
	for id in "${!cname[@]}"; do
		d=/sys/fs/cgroup/system.slice/docker-$id.scope
		anon=$(awk '$1 == "anon" { print $2 }' "$d/memory.stat" 2>/dev/null)
		swap=$(cat "$d/memory.swap.current" 2>/dev/null)
		printf 'docker\t%s\t%d\t%s\t%s\n' "${cname[$id]}" $(((${anon:-0} + ${swap:-0}) / 1048576)) "${cname[$id]}" "docker container ${cname[$id]}"
	done

	for s in /proc/[0-9]*/status; do
		p=${s#/proc/}
		p=${p%/status}
		kb=$(awk '/^VmRSS:/ { r = $2 } /^VmSwap:/ { print r + $2 }' "$s" 2>/dev/null)
		[ -n "$kb" ] && [ "$kb" -gt 102400 ] || continue
		cmd=$(tr '\0' ' ' <"/proc/$p/cmdline" 2>/dev/null)
		where=host
		cg=$(grep -o 'docker-[0-9a-f]*' "/proc/$p/cgroup" 2>/dev/null)
		[ -n "$cg" ] && where=${cname[${cg#docker-}]:-docker}
		label=$(cat "/proc/$p/comm" 2>/dev/null)
		case "$label" in node* | MainThread)
			for k in next nest tsc jest vitest graphql-codegen pyright playwright vite; do
				[[ "$cmd" == *"$k"* ]] && label="node:$k" && break
			done
			;;
		esac
		printf 'proc\t%s\t%d\t%s [%s]\t%s\n' "$p" $((kb / 1024)) "$label" "$where" "$cmd"
	done
}

render() {
	list | sort -t$'\t' -k3,3nr | awk -F'\t' '{ printf "%s\t%s\t%7.1fG  %-6s %s\t%s\n", $1, $2, $3 / 1024, $1, $4, $5 }'
}

stop() {
	while IFS=$'\t' read -r kind id _ cmd; do
		if [ "$kind" = docker ]; then
			docker stop "$id" >/dev/null && echo "stopped container $id"
		else
			kill "$id" && echo "sent SIGTERM to $id: ${cmd:0:80}"
		fi
	done
}

while true; do
	sel=$(render | fzf --multi --delimiter='\t' --with-nth=3 --no-sort --layout=reverse \
		--header=$'Tab:複数選択  Enter:停止(docker stop / SIGTERM)  Esc:閉じる\n[ ] 内はプロセスがいるコンテナ。restart: always のコンテナはプロセスを殺しても再起動するので、コンテナごと止める' \
		--preview='echo {4}' --preview-window=down,3,wrap) || break
	# 確認も fzf にして、ダブルクリックだけで最後まで操作できるようにする
	ans=$(printf 'やめる\n停止する\n' | fzf --layout=reverse --no-sort --height=10 \
		--header=$'次を停止します:\n'"$(printf '%s\n' "$sel" | cut -f3)") || continue
	[ "$ans" = 停止する ] && printf '%s\n' "$sel" | stop
	sleep 1
done
