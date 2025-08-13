#!/usr/bin/env zsh
icon=""
header="image"

docker images --format="{{.Repository}}:{{.Tag}}\t{{.ID}} {{.Size}}\t{{.CreatedSince}}" |
    "${0:a:h}/format.zsh" "$icon" "$header" "green" "white" "green" "blue"