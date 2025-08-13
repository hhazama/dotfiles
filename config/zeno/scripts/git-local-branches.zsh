#!/usr/bin/env zsh
icon=""
header="branch"

name="%(refname:short)"
subject="%(subject)"
committer_date="%(committerdate:relative)"

git --no-pager for-each-ref \
    'refs/heads' \
    --format="$name%09$subject%09$committer_date" \
    --sort='-committerdate' \
    2>/dev/null |
    "${0:a:h}/format.zsh" "$icon" "$header" "blue" "blue" "gray" "blue" "6" "13"