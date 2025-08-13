#!/usr/bin/env zsh
args=("$@")

max_count=100
icon=""
header="Issue"

number="{{.number}}"
title="{{.title}}"
headRefName="{{.headRefName}}"
updatedAt="{{timeago .updatedAt}}"
tab="{{printf \"\t\"}}"
line="{{printf \"\n\"}}"

gh issue list \
        --json number,title,updatedAt \
        --template "{{range .}}${number}${tab}${title}${tab}${updatedAt}${line}{{end}}" \
    2>/dev/null |
    "${0:a:h}/format.zsh" "$icon" "$header" "green" "green" "gray" "blue" "6" "13"
