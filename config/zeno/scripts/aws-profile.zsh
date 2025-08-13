#!/usr/bin/env zsh
. "${0:a:h}/ansi.zsh"

icon="󰸏"
header="profile"

aws configure list-profiles 2>/dev/null |
        "${0:a:h}/format.zsh" "$icon" "$header" "green" "white" "green" "blue"
