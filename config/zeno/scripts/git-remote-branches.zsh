#!/usr/bin/env zsh
icon=""
header="remote"

name="%(refname:short)"
subject="%(subject)"
committer_date="%(committerdate:relative)"

git --no-pager for-each-ref \
    'refs/remotes' \
    --format="$name%09$subject%09$committer_date" \
    --sort='-committerdate' \
    2>/dev/null |
    "${0:a:h}/format.zsh" "$icon" "$header" "red" "red" "gray" "blue" "6" "13"