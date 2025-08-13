#!/usr/bin/env zsh
args=("$@")

max_count=100
icon=""
header="WorkFlow"

number="{{.number}}"
databaseId="{{printf \"%.0f\" .databaseId}}"
name="{{.name}}"
runStatus="{{.status}}"
headBranch="{{.headBranch}}"
title="{{.title}}"
headRefName="{{.headRefName}}"
tab="{{printf \"\t\"}}"
line="{{printf \"\n\"}}"

gh run list \
        --json number,status,name,databaseId,headBranch,status \
        --template "{{range .}}${databaseId}${tab}${headBranch}${tab}${runStatus}${line}{{end}}" \
    2>/dev/null |
    "${0:a:h}/format.zsh" "$icon" "$header" "yellow" "yellow" "gray" "blue" "6" "13"
