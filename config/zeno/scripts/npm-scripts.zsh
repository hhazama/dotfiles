#!/usr/bin/env zsh
. "${0:a:h}/ansi.zsh"

icon=""
header="script"

root="$(npm root)"
package="$(dirname -- "$root")/package.json"

jq -r '.scripts | to_entries | map(.key + "\t" + .value)[]' "$package" 2>/dev/null | 
    "${0:a:h}/format.zsh" "$icon" "$header" "green" "white" "green" "blue"
