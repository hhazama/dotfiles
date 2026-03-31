#!/bin/bash
# Claude Code statusline script - Pattern5 with visual bars
# Shows: user@host cwd | model | context bar | rate limit bars

input=$(cat)

# Basic info
user=$(whoami)
host=$(hostname -s)
cwd=$(echo "$input" | jq -r '.workspace.current_dir // .cwd // empty')
if [ -n "$cwd" ]; then
  home="$HOME"
  short_cwd="${cwd/#$home/~}"
else
  short_cwd=$(pwd)
fi

# Model
model=$(echo "$input" | jq -r '.model.display_name // empty')

# Context window usage
used_pct=$(echo "$input" | jq -r '.context_window.used_percentage // empty')

# Rate limits
five_h=$(echo "$input" | jq -r '.rate_limits.five_hour.used_percentage // empty')
seven_d=$(echo "$input" | jq -r '.rate_limits.seven_day.used_percentage // empty')

# Generate a progress bar: bar <percentage> <width>
# Uses block characters for a smooth visual bar
bar() {
  local pct=$1
  local width=${2:-10}
  local filled=$(( pct * width / 100 ))
  local empty=$(( width - filled ))
  local result=""
  for ((i=0; i<filled; i++)); do result+="█"; done
  for ((i=0; i<empty; i++)); do result+="░"; done
  echo "$result"
}

# Color a value based on percentage thresholds
color_bar() {
  local pct=$1
  local label=$2
  local width=${3:-10}
  local b=$(bar "$pct" "$width")
  if [ "$pct" -ge 80 ]; then
    printf '\033[31m%s %s %d%%\033[0m' "$label" "$b" "$pct"
  elif [ "$pct" -ge 50 ]; then
    printf '\033[33m%s %s %d%%\033[0m' "$label" "$b" "$pct"
  else
    printf '\033[32m%s %s %d%%\033[0m' "$label" "$b" "$pct"
  fi
}

# Build output parts
parts=()

# user@host:cwd
parts+=("$(printf '\033[32m%s@%s\033[0m:\033[34m%s\033[0m' "$user" "$host" "$short_cwd")")

# model
if [ -n "$model" ]; then
  parts+=("$(printf '\033[36m%s\033[0m' "$model")")
fi

# context usage with bar
if [ -n "$used_pct" ]; then
  ctx_int=$(printf '%.0f' "$used_pct")
  parts+=("$(color_bar "$ctx_int" "Ctx" 10)")
fi

# rate limits with bars
if [ -n "$five_h" ]; then
  fh_int=$(printf '%.0f' "$five_h")
  parts+=("$(color_bar "$fh_int" "5h" 8)")
fi
if [ -n "$seven_d" ]; then
  sd_int=$(printf '%.0f' "$seven_d")
  parts+=("$(color_bar "$sd_int" "7d" 8)")
fi

# Join with separator
result=""
for part in "${parts[@]}"; do
  if [ -z "$result" ]; then
    result="$part"
  else
    result="$result | $part"
  fi
done

printf '%s' "$result"
