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

# Model / reasoning effort (effort はモデルが対応する場合のみ存在)
model=$(echo "$input" | jq -r '.model.display_name // empty')
effort=$(echo "$input" | jq -r '.effort.level // empty')

# Context window usage
used_pct=$(echo "$input" | jq -r '.context_window.used_percentage // empty')

# 閾値超過で compact-prep 警告 marker を書く(warned cooldown 中は書かない)
# marker は userpromptsubmit-compact-prep-reminder.sh が読んで /compact-prep 提案を注入する
COMPACT_WARN_THRESHOLD=60
if [ -n "$used_pct" ]; then
  _ctx_pct_int=$(printf '%.0f' "$used_pct" 2>/dev/null || echo 0)
  if [ "$_ctx_pct_int" -ge "$COMPACT_WARN_THRESHOLD" ] 2>/dev/null; then
    _sid=$(echo "$input" | jq -r '.session_id // empty')
    if [ -n "$_sid" ] && [ ! -f "${TMPDIR:-/tmp}/claude-compact-warned/$_sid" ]; then
      _warn_dir="${TMPDIR:-/tmp}/claude-compact-warn"
      mkdir -p "$_warn_dir" 2>/dev/null || true
      printf '%s\n' "$_ctx_pct_int" > "$_warn_dir/$_sid" 2>/dev/null || true
    fi
  fi
fi

# Rate limits (usage % and reset time as unix epoch seconds)
five_h=$(echo "$input" | jq -r '.rate_limits.five_hour.used_percentage // empty')
seven_d=$(echo "$input" | jq -r '.rate_limits.seven_day.used_percentage // empty')
five_h_reset=$(echo "$input" | jq -r '.rate_limits.five_hour.resets_at // empty')
seven_d_reset=$(echo "$input" | jq -r '.rate_limits.seven_day.resets_at // empty')

# Session cost / elapsed time
cost=$(echo "$input" | jq -r '.cost.total_cost_usd // empty')
dur_ms=$(echo "$input" | jq -r '.cost.total_duration_ms // empty')

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

# Format a duration in milliseconds as e.g. 1h23m / 45m12s / 8s
fmt_duration() {
  local ms=$1
  local total_s=$(( ms / 1000 ))
  local h=$(( total_s / 3600 ))
  local m=$(( (total_s % 3600) / 60 ))
  local s=$(( total_s % 60 ))
  if [ "$h" -gt 0 ]; then
    printf '%dh%dm' "$h" "$m"
  elif [ "$m" -gt 0 ]; then
    printf '%dm%ds' "$m" "$s"
  else
    printf '%ds' "$s"
  fi
}

# Format a unix-epoch reset time (empty if unavailable)
fmt_reset() {
  local epoch=$1
  local fmt=$2
  [ -n "$epoch" ] && [ "$epoch" != "null" ] && date -d "@$epoch" +"$fmt" 2>/dev/null
}

# Color a value based on percentage thresholds. $4: optional reset-time suffix
color_bar() {
  local pct=$1
  local label=$2
  local width=${3:-10}
  local reset=$4
  local b=$(bar "$pct" "$width")
  local suffix=""
  [ -n "$reset" ] && suffix=" $reset"
  if [ "$pct" -ge 80 ]; then
    printf '\033[31m%s %s %d%%%s\033[0m' "$label" "$b" "$pct" "$suffix"
  elif [ "$pct" -ge 50 ]; then
    printf '\033[33m%s %s %d%%%s\033[0m' "$label" "$b" "$pct" "$suffix"
  else
    printf '\033[32m%s %s %d%%%s\033[0m' "$label" "$b" "$pct" "$suffix"
  fi
}

# Build output parts
parts=()

# user@host:cwd
parts+=("$(printf '\033[32m%s@%s\033[0m:\033[34m%s\033[0m' "$user" "$host" "$short_cwd")")

# model (+ reasoning effort を dim で後置)
if [ -n "$model" ]; then
  if [ -n "$effort" ]; then
    parts+=("$(printf '\033[36m%s\033[0m \033[2m%s\033[0m' "$model" "$effort")")
  else
    parts+=("$(printf '\033[36m%s\033[0m' "$model")")
  fi
fi

# context usage with bar
if [ -n "$used_pct" ]; then
  ctx_int=$(printf '%.0f' "$used_pct")
  parts+=("$(color_bar "$ctx_int" "Ctx" 10)")
fi

# rate limits with bars
if [ -n "$five_h" ]; then
  fh_int=$(printf '%.0f' "$five_h")
  parts+=("$(color_bar "$fh_int" "5h" 8 "$(fmt_reset "$five_h_reset" '%H:%M')")")
fi
if [ -n "$seven_d" ]; then
  sd_int=$(printf '%.0f' "$seven_d")
  parts+=("$(color_bar "$sd_int" "7d" 8 "$(fmt_reset "$seven_d_reset" '%m/%d %H:%M')")")
fi

# session cost + elapsed time
if [ -n "$cost" ] || [ -n "$dur_ms" ]; then
  cost_fmt=$(printf '$%.2f' "${cost:-0}")
  dur_fmt=$(fmt_duration "${dur_ms:-0}")
  parts+=("$(printf '\033[35m%s %s\033[0m' "$cost_fmt" "$dur_fmt")")
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
