#!/bin/sh
# Over9k's Claude Code status line: it shows nothing of its own. It only reads
# what Claude Code passes a status line, and saves it for Over9k:
# - this terminal's model, effort, ultracode, context, cache expiry, last reply
#   and transcript (~/.cache/claude-agents/<terminal>.json), for the sidebar's
#   agent details, its "exp." and the Timeline;
# - Claude's limits (~/.cache/over9k/usage/claude.json), or on Bedrock each
#   session's cost per day, for the usage rows.
# Your own status line, if you had one, still shows: it runs after this.
# Set up by Options › Claude Code › Status line (settings.json statusLine).
# Needs jq.
in=$(cat)
# When the prompt cache runs out (seconds since 1970): the last reply's time plus
# its cache lifetime (1 hour or 5 minutes, from what the last write used).
cache=null last=null
tp=$(printf '%s' "$in" | jq -r --argjson cache "$cache" '.transcript_path // empty')
if [ -f "$tp" ]; then
  cache=$(tail -n 400 "$tp" | jq -sc '[.[] | select(.type == "assistant" and .message.usage)]
    | if length == 0 then null else
        (last.timestamp | sub("\\.[0-9]+Z$"; "Z") | fromdate) as $at
        | ([.[].message.usage.cache_creation // {}
            | if (.ephemeral_1h_input_tokens // 0) > 0 then 3600
              elif (.ephemeral_5m_input_tokens // 0) > 0 then 300 else empty end] | last // 300) as $ttl
        | $at + $ttl end' 2>/dev/null) || cache=null
  [ -n "$cache" ] || cache=null
  # When it last replied (seconds), for the "3m" by its row in Herdr.
  last=$(tail -n 400 "$tp" | jq -sc '[.[] | select(.type == "assistant")] | if length == 0 then null else last.timestamp | sub("\\.[0-9]+Z$"; "Z") | fromdate end' 2>/dev/null) || last=null
  [ -n "$last" ] || last=null
fi
if [ -n "$HC_TERMINAL_ID" ]; then
  # Whether ultracode is on: the last /effort toggle in the transcript says.
  ultra=false
  [ -f "$tp" ] && grep -o '"message":{"role":"user","content":"<local-command-stdout>[^"]*Ultracode o[nf]' "$tp" | tail -n 1 | grep -q 'on$' && ultra=true
  dir="$HOME/.cache/claude-agents"
  mkdir -p "$dir"
  printf '%s' "$in" | jq -c --argjson cache "$cache" --argjson ultra "$ultra" --argjson last "$last" '{model: .model.display_name, id: .model.id, effort: .effort.level, ultracode: $ultra, lastAt: $last, context: .context_window.used_percentage, cacheUntil: $cache, transcript: .transcript_path}' \
    > "$dir/$HC_TERMINAL_ID.json.tmp" && mv "$dir/$HC_TERMINAL_ID.json.tmp" "$dir/$HC_TERMINAL_ID.json"
fi
# Claude's limits for the sidebar's usage section (over9k-usage), when it has them.
u="$HOME/.cache/over9k/usage"; mkdir -p "$u"
# Claude on Amazon Bedrock has no plan limits; it's paid per use. The usage rows
# show today's spend instead: each session's cost per day (Claude Code's running
# total for the session, split at midnight), in usage/bedrock/<session>.json.
bedrock=no
case "${CLAUDE_CODE_USE_BEDROCK:-}" in ""|0|false) ;; *) bedrock=yes ;; esac
printf '%s' "$in" | jq -e '.model.id // "" | test("(^|[.:/])anthropic\\.|arn:aws:bedrock")' >/dev/null 2>&1 && bedrock=yes
if [ "$bedrock" = yes ]; then
  b="$u/bedrock"; mkdir -p "$b"
  sid=$(printf '%s' "$in" | jq -r '.session_id // empty' | tr -cd 'A-Za-z0-9-')
  if [ -n "$sid" ]; then
    prev=$(cat "$b/$sid.json" 2>/dev/null); [ -n "$prev" ] || prev={}
    printf '%s' "$in" | jq -c --argjson prev "$prev" --arg day "$(date +%F)" '
      (.cost.total_cost_usd // 0) as $total
      | ($prev.days // {}) as $d
      | ([$d | to_entries[] | select(.key != $day) | .value] | add // 0) as $other
      | {days: ($d + {($day): ([$total - $other, 0] | max)}),
         project: ((.workspace.current_dir // .cwd // "") | sub("/+$"; "") | split("/") | last),
         at: (now | floor)}' > "$b/$sid.json.tmp" 2>/dev/null && mv "$b/$sid.json.tmp" "$b/$sid.json" || rm -f "$b/$sid.json.tmp"
  fi
  find "$b" -name '*.json' -mtime +30 -exec rm -f {} + 2>/dev/null
  printf '{"at":%s,"bedrock":true}\n' "$(date +%s)" > "$u/claude.json"
fi
printf '%s' "$in" | jq -ce 'select(.rate_limits != null) | {at: (now | floor), five_hour: .rate_limits.five_hour, seven_day: .rate_limits.seven_day}' \
  > "$u/claude.json.tmp" 2>/dev/null && mv "$u/claude.json.tmp" "$u/claude.json" || rm -f "$u/claude.json.tmp"
# What shows under the prompt isn't Over9k's: your own status line, if you had
# one when Over9k's took its place (kept in ~/.claude/.over9k-statusline-was.json),
# runs with the same input and its output shows; otherwise nothing does.
was="$HOME/.claude/.over9k-statusline-was.json"
if [ -s "$was" ]; then
  cmd=$(jq -r '.command // empty' "$was" 2>/dev/null)
  [ -n "$cmd" ] && printf '%s' "$in" | sh -c "$cmd"
fi
exit 0
