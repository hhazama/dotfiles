#!/usr/bin/env zsh
args=("$@")

max_count=100
icon=""
header="PullRequest"

number="{{.number}}"
title="{{.title}}"
headRefName="{{.headRefName}}"
tab="{{printf \"\t\"}}"
line="{{printf \"\n\"}}"

gh pr list \
        --json number,title,headRefName,updatedAt \
        --template "{{range .}}${number}${tab}${title}${tab}${headRefName}${line}{{end}}" \
    2>/dev/null |
    "${0:a:h}/format.zsh" "$icon" "$header" "red" "red" "gray" "blue" "6" "13"
