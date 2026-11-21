#!/bin/bash
# Antigravity CLI (agy) statusline script (2-line layout)
# Line 1: user@host:cwd (git-branch) | model effort [tier] | active badges | conversation title
# Line 2: Ctx bar % (tokens cache%) | 5h bar % reset | 7d bar % reset | cost

set -u

input=$(cat)

# Basic host info
user=$(whoami)
host=$(hostname -s)

# Parsed fields (populated in a single jq invocation)
cwd=""
model=""
effort=""
tier=""
conv_title=""
used_pct=""
ctx_size=""
ctx_used_tokens=""
cache_hit_pct=""
five_h_pct=""
five_h_reset=""
five_h_secs=""
seven_d_pct=""
seven_d_reset=""
seven_d_secs=""
cost_usd=""
subagent_usd=""
cost_estimated=""
running_subagents=""
artifact_count=""
task_count=""
sandbox_enabled=""
tool_confirm=""

if [ -n "$input" ] && command -v jq >/dev/null 2>&1; then
  jq_out=$(
    printf '%s' "$input" | jq -r '
      def clamp_pct:
        if . < 0 then 0 elif . > 100 then 100 else . end;

      def model_family:
        ((.model.id // .model.display_name // "") | ascii_downcase) |
        if test("claude") then "claude"
        elif test("gpt|openai|\\bo[134]\\b") then "gpt"
        elif test("gemini") then "gemini"
        else ""
        end;

      def pick_quota($pat; $fam):
        (.quota // {} | to_entries) as $entries |
        (
          ($entries | map(select((.key | ascii_downcase | test($pat)) and ($fam != "" and (.key | ascii_downcase | contains($fam))))) | first)
          // ($entries | map(select(.key | ascii_downcase | test($pat))) | first)
        ) | .value // null;

      def used_pct_of($q; $rl):
        if ($q != null and ($q.remaining_fraction // null) != null) then
          (((1 - $q.remaining_fraction) * 100) | clamp_pct | tostring)
        elif ($q != null and ($q.used_percentage // null) != null) then
          ($q.used_percentage | clamp_pct | tostring)
        elif ($rl != null and ($rl.used_percentage // null) != null) then
          ($rl.used_percentage | clamp_pct | tostring)
        else ""
        end;

      def reset_time_of($q; $rl):
        if ($q != null and ($q.reset_time // null) != null) then ($q.reset_time | tostring)
        elif ($rl != null and ($rl.resets_at // null) != null) then ($rl.resets_at | tostring)
        else ""
        end;

      def reset_secs_of($q):
        if ($q != null and ($q.reset_in_seconds // null) != null) then ($q.reset_in_seconds | floor | tostring)
        else ""
        end;

      def ctx_tokens:
        (.context_window // {}) as $cw |
        if ($cw.current_usage // null) != null then
          (($cw.current_usage.input_tokens // 0) + ($cw.current_usage.cache_read_input_tokens // 0) + ($cw.current_usage.cache_creation_input_tokens // 0)) | floor | tostring
        elif ($cw.used_percentage // null) != null and ($cw.context_window_size // 0) > 0 then
          (($cw.used_percentage * $cw.context_window_size / 100) | floor | tostring)
        else ""
        end;

      def cache_pct:
        (.context_window.current_usage // null) as $cu |
        if $cu != null then
          (($cu.cache_read_input_tokens // 0)) as $cr |
          (($cu.input_tokens // 0) + $cr + ($cu.cache_creation_input_tokens // 0)) as $tot |
          if $tot > 0 and $cr > 0 then
            (($cr * 100 / $tot) | clamp_pct | round | tostring)
          else ""
          end
        else ""
        end;

      def short_title:
        ((.conversation_title // "") | gsub("[\r\n\t]+"; " ")) as $t |
        if ($t | length) > 20 then ($t[0:19] + "…") else $t end;

      model_family as $fam |
      pick_quota("5h|five.?hour"; $fam) as $q5 |
      pick_quota("weekly|7d|seven.?day"; $fam) as $q7 |
      (.rate_limits.five_hour // null) as $rl5 |
      (.rate_limits.seven_day // null) as $rl7 |

      [
        (.workspace.current_dir // .cwd // ""),
        (.model.display_name // ""),
        (.model.effort // .effort.level // ""),
        (.user.subscription_tier // .plan_tier // ""),
        short_title,
        (if (.context_window.used_percentage // null) != null then (.context_window.used_percentage | clamp_pct | tostring) else "" end),
        (if (.context_window.context_window_size // 0) > 0 then (.context_window.context_window_size | floor | tostring) else "" end),
        ctx_tokens,
        cache_pct,
        used_pct_of($q5; $rl5),
        reset_time_of($q5; $rl5),
        reset_secs_of($q5),
        used_pct_of($q7; $rl7),
        reset_time_of($q7; $rl7),
        reset_secs_of($q7),
        (if (.cost.total_usd // .cost.total_cost_usd // null) != null then ((.cost.total_usd // .cost.total_cost_usd) | tostring) else "" end),
        (if (.cost.subagent_usd // null) != null and (.cost.subagent_usd > 0) then (.cost.subagent_usd | tostring) else "" end),
        (if (.cost.estimated // false) then "true" else "false" end),
        ((.subagents // []) | map(select(.status == "running")) | length | tostring),
        ((.artifact_count // 0) | tostring),
        ((.task_count // 0) | tostring),
        (if (.sandbox.enabled // false) then "true" else "false" end),
        (if (.tool_confirmation // false) then "true" else "false" end)
      ] | .[]
    ' 2>/dev/null || true
  )

  if [ -n "$jq_out" ]; then
    {
      IFS= read -r cwd || true
      IFS= read -r model || true
      IFS= read -r effort || true
      IFS= read -r tier || true
      IFS= read -r conv_title || true
      IFS= read -r used_pct || true
      IFS= read -r ctx_size || true
      IFS= read -r ctx_used_tokens || true
      IFS= read -r cache_hit_pct || true
      IFS= read -r five_h_pct || true
      IFS= read -r five_h_reset || true
      IFS= read -r five_h_secs || true
      IFS= read -r seven_d_pct || true
      IFS= read -r seven_d_reset || true
      IFS= read -r seven_d_secs || true
      IFS= read -r cost_usd || true
      IFS= read -r subagent_usd || true
      IFS= read -r cost_estimated || true
      IFS= read -r running_subagents || true
      IFS= read -r artifact_count || true
      IFS= read -r task_count || true
      IFS= read -r sandbox_enabled || true
      IFS= read -r tool_confirm || true
    } <<<"$jq_out"
  fi
fi

work_dir="${cwd:-$(pwd)}"
home="$HOME"
short_cwd="${work_dir/#$home/\~}"

# Fast git branch lookup (HEAD only, avoids slow working tree scans)
git_branch=""
if [ -d "$work_dir" ] && command -v git >/dev/null 2>&1; then
  git_branch=$(git -C "$work_dir" rev-parse --abbrev-ref HEAD 2>/dev/null || true)
fi

# Format token counts compactly (e.g. 1048576 -> 1M, 200000 -> 200k, 850 -> 850)
fmt_tokens() {
  local n=$1
  if [ "$n" -eq 1048576 ]; then
    printf '1M'
  elif [ "$n" -eq 2097152 ]; then
    printf '2M'
  elif [ "$n" -ge 1000000 ]; then
    awk -v v="$n" 'BEGIN { s = sprintf("%.1f", v / 1000000); sub(/\.0$/, "", s); printf "%sM", s }'
  elif [ "$n" -ge 1000 ]; then
    printf '%dk' "$((n / 1000))"
  else
    printf '%d' "$n"
  fi
}

# Generate a progress bar: bar <percentage> <width>
bar() {
  local pct=$1
  local width=${2:-10}
  if [ "$pct" -lt 0 ]; then
    pct=0
  elif [ "$pct" -gt 100 ]; then
    pct=100
  fi
  local filled=$((pct * width / 100))
  local empty=$((width - filled))
  local result=""
  local i
  for ((i = 0; i < filled; i++)); do result+="█"; done
  for ((i = 0; i < empty; i++)); do result+="░"; done
  printf '%s' "$result"
}

# Format reset time from ISO 8601 UTC string, unix epoch, or relative seconds
fmt_reset() {
  local ts=$1
  local secs=$2
  local fmt=$3
  if [ -n "$ts" ] && [ "$ts" != "null" ]; then
    if [[ "$ts" =~ ^[0-9]+$ ]]; then
      date -d "@$ts" +"$fmt" 2>/dev/null || true
    else
      date -d "$ts" +"$fmt" 2>/dev/null || true
    fi
  elif [ -n "$secs" ] && [[ "$secs" =~ ^[0-9]+$ ]]; then
    local now target
    now=$(date +%s)
    target=$((now + secs))
    date -d "@$target" +"$fmt" 2>/dev/null || true
  fi
}

# Color a value based on percentage thresholds. $4: optional suffix
color_bar() {
  local pct=$1
  local label=$2
  local width=${3:-10}
  local suffix=${4:-}
  local b
  b=$(bar "$pct" "$width")
  local tail=""
  if [ -n "$suffix" ]; then
    tail=" $suffix"
  fi
  if [ "$pct" -ge 80 ]; then
    printf '\033[31m%s %s %d%%%s\033[0m' "$label" "$b" "$pct" "$tail"
  elif [ "$pct" -ge 50 ]; then
    printf '\033[33m%s %s %d%%%s\033[0m' "$label" "$b" "$pct" "$tail"
  else
    printf '\033[32m%s %s %d%%%s\033[0m' "$label" "$b" "$pct" "$tail"
  fi
}

join_parts() {
  local sep=$1
  shift
  local out=""
  local item
  for item in "$@"; do
    if [ -z "$out" ]; then
      out="$item"
    else
      out="${out}${sep}${item}"
    fi
  done
  printf '%s' "$out"
}

# ==============================================================================
# Line 1: Environment, model, live badges, conversation title
# ==============================================================================
line1=()

loc=$(printf '\033[32m%s@%s\033[0m:\033[34m%s\033[0m' "$user" "$host" "$short_cwd")
if [ -n "$git_branch" ]; then
  loc="${loc} $(printf '\033[33m(%s)\033[0m' "$git_branch")"
fi
line1+=("$loc")

if [ -n "$model" ]; then
  m_str=$(printf '\033[36m%s\033[0m' "$model")
  if [ -n "$effort" ]; then
    m_str="${m_str} $(printf '\033[2m%s\033[0m' "$effort")"
  fi
  if [ -n "$tier" ]; then
    m_str="${m_str} $(printf '\033[2m[%s]\033[0m' "$tier")"
  fi
  line1+=("$m_str")
fi

# Antigravity-specific live status badges (shown only when active)
badges=()
if [ "$tool_confirm" = "true" ]; then
  badges+=("$(printf '\033[1;31mCONFIRM\033[0m')")
fi
if [ -n "$running_subagents" ] && [ "$running_subagents" -gt 0 ] 2>/dev/null; then
  badges+=("$(printf '\033[36msub:%s\033[0m' "$running_subagents")")
fi
if [ -n "$task_count" ] && [ "$task_count" -gt 0 ] 2>/dev/null; then
  badges+=("$(printf '\033[33mq:%s\033[0m' "$task_count")")
fi
if [ -n "$artifact_count" ] && [ "$artifact_count" -gt 0 ] 2>/dev/null; then
  badges+=("$(printf '\033[34mart:%s\033[0m' "$artifact_count")")
fi
if [ "$sandbox_enabled" = "true" ]; then
  badges+=("$(printf '\033[2msbx\033[0m')")
fi
if [ "${#badges[@]}" -gt 0 ]; then
  line1+=("$(join_parts " " "${badges[@]}")")
fi

if [ -n "$conv_title" ]; then
  line1+=("$(printf '\033[2m%s\033[0m' "$conv_title")")
fi

# ==============================================================================
# Line 2: Context window + tokens/cache, 5h/7d quotas + reset times, cost
# ==============================================================================
line2=()

if [ -n "$used_pct" ]; then
  ctx_int=$(LC_ALL=C printf '%.0f' "$used_pct" 2>/dev/null || echo 0)
  ctx_detail=""
  if [ -n "$ctx_used_tokens" ] && [ -n "$ctx_size" ]; then
    ctx_detail="$(fmt_tokens "$ctx_used_tokens")/$(fmt_tokens "$ctx_size")"
  fi
  if [ -n "$cache_hit_pct" ]; then
    if [ -n "$ctx_detail" ]; then
      ctx_detail="${ctx_detail} cache:${cache_hit_pct}%"
    else
      ctx_detail="cache:${cache_hit_pct}%"
    fi
  fi
  ctx_bar=$(color_bar "$ctx_int" "Ctx" 10)
  if [ -n "$ctx_detail" ]; then
    ctx_bar="${ctx_bar} $(printf '\033[2m(%s)\033[0m' "$ctx_detail")"
  fi
  line2+=("$ctx_bar")
fi

if [ -n "$five_h_pct" ]; then
  fh_int=$(LC_ALL=C printf '%.0f' "$five_h_pct" 2>/dev/null || echo 0)
  fh_reset_fmt=$(fmt_reset "$five_h_reset" "$five_h_secs" '%H:%M')
  line2+=("$(color_bar "$fh_int" "5h" 8 "$fh_reset_fmt")")
fi

if [ -n "$seven_d_pct" ]; then
  sd_int=$(LC_ALL=C printf '%.0f' "$seven_d_pct" 2>/dev/null || echo 0)
  sd_reset_fmt=$(fmt_reset "$seven_d_reset" "$seven_d_secs" '%m/%d %H:%M')
  line2+=("$(color_bar "$sd_int" "7d" 8 "$sd_reset_fmt")")
fi

if [ -n "$cost_usd" ]; then
  cost_prefix=""
  if [ "$cost_estimated" = "true" ]; then
    cost_prefix="~"
  fi
  cost_fmt=$(LC_ALL=C printf '%s$%.2f' "$cost_prefix" "$cost_usd" 2>/dev/null || echo "")
  if [ -n "$cost_fmt" ]; then
    if [ -n "$subagent_usd" ]; then
      sub_fmt=$(LC_ALL=C printf '$%.2f' "$subagent_usd" 2>/dev/null || echo "")
      if [ -n "$sub_fmt" ]; then
        cost_fmt="${cost_fmt} (sub ${sub_fmt})"
      fi
    fi
    line2+=("$(printf '\033[35m%s\033[0m' "$cost_fmt")")
  fi
fi

# Output 1 or 2 lines
out1=$(join_parts " | " "${line1[@]}")
if [ "${#line2[@]}" -gt 0 ]; then
  out2=$(join_parts " | " "${line2[@]}")
  printf '%s\n%s' "$out1" "$out2"
else
  printf '%s' "$out1"
fi
