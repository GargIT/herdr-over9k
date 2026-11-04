#!/bin/sh
# What a Claude Code session ($1, its transcript) has running in the background,
# one line each, tab-separated: kind (shell, monitor, cron, wakeup), task id, what it is
# (description, or a cron job's prompt), when it started (seconds), a cron
# job's schedule ("Every 2 hours at :13") or a wakeup's time (seconds), and a
# shell's or monitor's output file. A wakeup (ScheduleWakeup, /loop pacing itself)
# is its latest one, until its time comes or it's stopped. Ended ones are left out: a task with a
# notice carrying a <status>, stopped (TaskStop), or a monitor expired (its
# notice, or past its time limit); a cron job deleted, a
# one-off past its time, or a recurring one past its 7 days.
# The answer is kept until the transcript changes, or for a minute at most.
[ -f "$1" ] || exit 0
now=$(date +%s)
dir="${XDG_CACHE_HOME:-$HOME/.cache}/over9k"; mkdir -p "$dir"
cache="$dir/tasks-$(printf '%s' "$1" | cksum | cut -d ' ' -f 1)"
# Bump v when this script changes, so cached answers from the old one go.
v=6
key="v$v $(stat -c '%Y %s' "$1" 2>/dev/null || stat -f '%m %z' "$1") $((now / 60))"
if [ -f "$cache" ] && [ "$(head -n 1 "$cache")" = "$key" ]; then tail -n +2 "$cache"; exit 0; fi
ended=$( { grep -o '<task-id>[a-z0-9]*</task-id>.\{0,600\}' "$1" | grep -E '<status>|Monitor expired' | grep -o '^<task-id>[a-z0-9]*' | cut -c10-
  grep -o 'Successfully stopped task: [a-z0-9]*' "$1" | cut -d' ' -f4; } 2>/dev/null | sort -u | tr '\n' ' ')
# Where this session's background output goes: the folder of its latest task's
# output file (a session started again writes to a new one).
outdir=$(grep -o '/[^ "\\<]*/tasks/[a-z0-9]*\.output' "$1" 2>/dev/null | tail -n 1 | sed 's|/[^/]*$||')
grep -E '"name":"(Bash|Monitor|CronCreate|CronDelete|ScheduleWakeup)"|backgroundTaskId|"taskId":"|humanSchedule|scheduledFor' "$1" 2>/dev/null | jq -rs --arg ended " $ended" --arg out "${outdir:+$outdir/}" --argjson now "$now" '
  [.[] | select(.type == "assistant") | .message.content[]? | select(.type == "tool_use")] as $uses
  | ($uses | map({key: .id, value: .}) | from_entries) as $u
  | [$uses[] | select(.name == "CronDelete") | .input.id] as $del
  | ([$uses[] | select(.name == "ScheduleWakeup")] | last | .id // "") as $wake
  | .[] | select(.type == "user") | . as $line | .toolUseResult as $r | select($r | type == "object")
  | $u[$line.message.content | if type == "array" then .[0].tool_use_id // "" else "" end] as $use
  | ($line.timestamp | sub("\\.[0-9]+Z$"; "Z") | fromdate) as $at
  | if $r.backgroundTaskId then ["shell", $r.backgroundTaskId, ($use.input.description // $use.input.command // "Background command"), $at, "", (if $out == "" then "" else $out + $r.backgroundTaskId + ".output" end)]
    elif $r.taskId and $use.name == "Monitor" and ($at + ($r.timeoutMs // 300000) / 1000 > $now) then ["monitor", $r.taskId, ($use.input.description // "Monitor"), $at, "", (if $out == "" then "" else $out + $r.taskId + ".output" end)]
    elif $r.scheduledFor and $use.id == $wake and ($r.scheduledFor / 1000 > $now) then ["wakeup", $use.id, ($use.input.reason // "Wakeup"), $at, ($r.scheduledFor / 1000 | floor), ""]
    elif $r.humanSchedule and ($del | index($r.id) | not)
      and ($r.recurring or ($r.nextFireAt / 1000) > $now - 120)
      and ($now - $at < 7 * 86400) then ["cron", $r.id, ($use.input.prompt // ""), $at, $r.humanSchedule, ""]
    else empty end
  | select(.[0] == "cron" or .[0] == "wakeup" or (.[1] as $id | $ended | contains(" " + $id + " ") | not))
  | map(tostring | gsub("[\t\n]"; " ")) | @tsv' 2>/dev/null > "$cache.$$"
# Its own file, put in place whole: two runs at once wrote over each other's.
{ echo "$key"; cat "$cache.$$"; } > "$cache.$$.all" && mv -f "$cache.$$.all" "$cache"; rm -f "$cache.$$"
tail -n +2 "$cache"
