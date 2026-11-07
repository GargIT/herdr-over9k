#!/bin/sh
# Claude Code's subagents for a transcript ($1), from <transcript>/subagents/:
# one line each, tab-separated: id, last write (seconds), description, type,
# model, when it started (seconds), its context (the last request's input
# tokens), effort, context window, and 1 once it's done.
# Done: the parent was told so (a "finished", killed or failed notice for its
# task id; one waiting on work of its own isn't, though it writes nothing
# meanwhile), it was stopped (TaskStop: its notice only comes at the parent's
# next turn), it handed its report back (a message from it), or it never
# replied (two minutes on: a leftover, not one that runs). A signal only counts
# if the subagent has written nothing since: one told to carry on (SendMessage)
# runs again, with the old "finished" still in the parent's transcript. The parent's
# transcript (big) is read once for all of them; the answer is kept until it or
# a subagent's file changes, or for a minute at most.
dir="${1%.jsonl}/subagents"; [ -d "$dir" ] || exit 0
now=$(date +%s)
cachedir="${XDG_CACHE_HOME:-$HOME/.cache}/over9k"; mkdir -p "$cachedir"
cache="$cachedir/subagents-$(printf '%s' "$1" | cksum | cut -d ' ' -f 1)"
stamp() { stat -c '%Y %s' "$1" 2>/dev/null || stat -f '%m %z' "$1" 2>/dev/null; }
# Bump v when this script changes, so cached answers from the old one go.
v=4
newest=$(ls -t "$dir"/*.jsonl 2>/dev/null | head -n 1)
key="v$v $(stamp "$1") $(stamp "$newest") $((now / 60))"
if [ -f "$cache" ] && [ "$(head -n 1 "$cache")" = "$key" ]; then tail -n +2 "$cache"; exit 0; fi

# Each done signal in the parent's transcript, as "id seconds".
signals=$(grep -E '<task-id>|Successfully stopped task: |agent-message from=' "$1" 2>/dev/null | jq -Rr '
  (try (fromjson | .timestamp // empty | sub("\\.[0-9]+Z$"; "Z") | fromdate) catch empty) as $t
  | ( (scan("<task-id>[a-z0-9]*</task-id>.{0,600}") | select(test("finished</summary>|<status>(killed|failed|stopped)</status>")) | capture("^<task-id>(?<i>[a-z0-9]*)").i),
      (scan("Successfully stopped task: [a-z0-9]*") | split(" ")[3]),
      (scan("agent-message from=\\\\\"[a-z0-9]*") | sub(".*\""; "")) )
  | "\(.) \($t)"' 2>/dev/null | sort -k1,1 -k2,2n)

for m in "$dir"/*.meta.json; do
  [ -f "$m" ] || continue
  j="${m%.meta.json}.jsonl"
  [ -f "$j" ] || continue
  at=$(stat -c %Y "$j" 2>/dev/null || stat -f %m "$j" 2>/dev/null || echo 0)
  model=$(grep -o '"model":"[^"<]*"' "$j" 2>/dev/null | tail -n 1 | cut -d '"' -f 4)
  start=$(head -n 1 "$j" | jq -r '.timestamp // empty | sub("\\.[0-9]+Z$"; "Z") | fromdate' 2>/dev/null)
  tokens=$(grep '"type":"assistant"' "$j" 2>/dev/null | tail -n 1 | jq -r '.message.usage | ((.input_tokens // 0) + (.cache_creation_input_tokens // 0) + (.cache_read_input_tokens // 0))' 2>/dev/null)
  # Its effort (each reply records it) and context window: 1M when its requests
  # asked for that (the context-1m beta), else 200k.
  effort=$(grep -o '"effort":"[a-z]*"' "$j" 2>/dev/null | tail -n 1 | cut -d '"' -f 4)
  if grep -q 'context-1m' "$j" 2>/dev/null; then window=1000000; else window=200000; fi
  id=$(basename "$j" .jsonl)
  # Its last record, not its file's time: a session started again rewrites those.
  last=$(tail -n 20 "$j" | jq -r '.timestamp // empty | sub("\\.[0-9]+Z$"; "Z") | fromdate' 2>/dev/null | tail -n 1)
  said=$(printf '%s\n' "$signals" | grep "^${id#agent-} " | tail -n 1 | cut -d ' ' -f 2)
  done=0; [ -n "$said" ] && [ "${last:-0}" -le $((said + 5)) ] && done=1
  # Newer Claude Codes mark it in its meta file too (and unmark it on a resume).
  grep -q '"finished":true' "$m" 2>/dev/null && done=1
  # Never replied two minutes on: not one that runs (a session started again can
  # write back an old one's files with nothing in them).
  [ "$done" = 0 ] && [ $((now - at)) -gt 120 ] && ! grep -q '"type":"assistant"' "$j" 2>/dev/null && done=1
  printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$id" "$at" "$(jq -r '[.description // "", .agentType // ""] | @tsv' "$m" 2>/dev/null)" "$model" "$start" "$tokens" "$effort" "$window" "$done"
done > "$cache.$$"
# Its own file, put in place whole: two runs at once (a slow one outlasting the
# sidebar's wait) wrote over each other's, losing rows.
{ echo "$key"; cat "$cache.$$"; } > "$cache.$$.all" && mv -f "$cache.$$.all" "$cache"; rm -f "$cache.$$"
tail -n +2 "$cache"
