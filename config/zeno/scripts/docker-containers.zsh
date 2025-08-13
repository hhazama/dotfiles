#!/usr/bin/env zsh
icon=""
header="container"

docker ps --format="{{.Names}}\t{{.ID}}\t{{.Image}}\t{{.Ports}} {{ .Status }}" |
    "${0:a:h}/format.zsh" "$icon" "$header" "green" "white" "green" "blue"