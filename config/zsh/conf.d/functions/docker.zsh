### docker ###
docker() {
	if [ "$#" -eq 0 ] || [ "$1" = "compose" ] || ! command -v "docker-$1" >/dev/null; then
		command docker "${@:1}"
	else
		"docker-$1" "${@:2}"
	fi
}
docker-rm() {
	if [ "$#" -eq 0 ]; then
		command docker ps -a | \
		fzf --exit-0 --multi --header-lines=1 | \
		awk '{ print $1 }' | \
		xargs -r docker rm --
	else
		command docker rm "$@"
	fi
}
docker-rmi() {
	if [ "$#" -eq 0 ]; then
		command docker images | \
		fzf --exit-0 --multi --header-lines=1 | \
		awk '{ print $3 }' | \
		xargs -r docker rmi --
	else
		command docker rmi "$@"
	fi
}
