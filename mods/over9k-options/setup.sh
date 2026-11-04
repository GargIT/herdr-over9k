#!/bin/sh
# Over9k's setup outside Herdr: what Options' switches turn on and off, and what
# install.sh sets up. Linux, macOS, and Windows through Git Bash.
#   setup.sh status on|off <mods>     Claude Code's status line (over9k/statusline.sh);
#                                     someone else's is kept aside and comes back when off
#   setup.sh cleanup                  takes out hooks earlier versions of Over9k added
#   setup.sh todo on|off <mods>       the to-do rule (CLAUDE.md, AGENTS.md), the `todo`
#                                     command (~/.local/bin) and its hook (UserPromptSubmit)
#   setup.sh default log|sync on|off  Log / Sync for projects that haven't set their own
#   setup.sh check                    what's missing: one line each (none: nothing printed)
# <mods>: Herdr's mods folder (forward slashes on Windows). Claude Code's settings
# are ~/.claude/settings.json; Over9k's own entries are found by a marker in
# their command, so an older one is replaced and no one else's is touched.
set -u
cmd=${1:-} on=${2:-} mods=${3:-}
settings="$HOME/.claude/settings.json"

need_jq() { command -v jq >/dev/null 2>&1 || { echo "Over9k needs jq for this (https://jqlang.org/download/)" >&2; exit 4; }; }

# Claude Code's settings through jq: edit '<filter>' [jq args...].
edit() {
  need_jq
  mkdir -p "$HOME/.claude"; [ -s "$settings" ] || echo '{}' > "$settings"
  filter=$1; shift
  tmp=$(mktemp) || exit 1
  if jq "$@" "$filter" "$settings" > "$tmp" && [ -s "$tmp" ]; then cat "$tmp" > "$settings"; fi
  rm -f "$tmp"
}

# One of Over9k's hooks on or off: hook <on|off> <event> <marker> <command>.
hook() {
  edit '
    .hooks[$ev] = ((.hooks[$ev] // []) | map(.hooks |= map(select((.command // "") | contains($m) | not))) | map(select(.hooks | length > 0)))
    | if $on == "on" then .hooks[$ev] += [{hooks: [{type: "command", command: $c}]}] else . end
    | if .hooks[$ev] == [] then del(.hooks[$ev]) else . end
    | if .hooks == {} then del(.hooks) else . end' \
    --arg on "$1" --arg ev "$2" --arg m "$3" --arg c "$4"
}

case "$cmd" in
  status)
    was="$HOME/.claude/.over9k-statusline-was.json"
    if [ "$on" = on ]; then
      need_jq
      [ -s "$settings" ] && jq -e '(.statusLine.command // "") as $c | ($c | length) > 0 and ($c | contains("over9k/statusline.sh") | not)' "$settings" >/dev/null 2>&1 \
        && jq '.statusLine' "$settings" > "$was"
      edit '.statusLine = {type: "command", command: $c, refreshInterval: 5}' --arg c "sh \"$mods/over9k/statusline.sh\""
    elif [ -s "$was" ]; then
      edit '.statusLine = $w[0]' --slurpfile w "$was" && rm -f "$was"
    else
      edit 'if ((.statusLine.command // "") | contains("over9k/statusline.sh")) then del(.statusLine) else . end'
    fi ;;
  cleanup)
    # Next-prompt suggestions (removed): their Stop hook.
    [ -s "$settings" ] && command -v jq >/dev/null 2>&1 && hook off Stop over9k-prompts/next.py ""
    exit 0 ;;
  todo)
    t="$mods/over9k-todos/todo.sh"
    [ -f "$t" ] || { echo "No $t" >&2; exit 2; }
    sh "$t" --rule "$on"
    # The `todo` command agents run: a small wrapper (only Over9k's own is ever
    # replaced or removed).
    w="$HOME/.local/bin/todo"
    ours() { grep -q 'over9k todo wrapper' "$w" 2>/dev/null || { [ -L "$w" ] && readlink "$w" | grep -q over9k; }; }
    if [ "$on" = on ]; then
      if [ ! -e "$w" ] || ours; then
        mkdir -p "$HOME/.local/bin" && rm -f "$w" \
          && printf '#!/bin/sh\n# over9k todo wrapper (Options > To-do)\nexec sh "%s" "$@"\n' "$t" > "$w" && chmod +x "$w"
      fi
    elif ours; then rm -f "$w"; fi
    command -v jq >/dev/null 2>&1 && hook "$on" UserPromptSubmit over9k-todos/todo-hook.sh "sh \"$mods/over9k-todos/todo-hook.sh\""
    exit 0 ;;
  default)
    k=$on v=${3:-}
    case "$k:$v" in log:on|log:off|sync:on|sync:off) ;; *) echo "usage: setup.sh default log|sync on|off" >&2; exit 2 ;; esac
    d="${XDG_DATA_HOME:-$HOME/.local/share}/over9k"; mkdir -p "$d"
    { grep -v "^$k " "$d/todo-defaults" 2>/dev/null; echo "$k $v"; } > "$d/todo-defaults.tmp" && mv "$d/todo-defaults.tmp" "$d/todo-defaults" ;;
  check)
    command -v git >/dev/null 2>&1 || echo "git: the sidebar's branch, changes and push/pull"
    command -v jq >/dev/null 2>&1 || echo "jq: Claude Code's status line, subagents, background tasks, resume, hand-off"
    { command -v python3 >/dev/null 2>&1 || command -v python >/dev/null 2>&1; } || echo "python 3: the Timeline, TODO.md sync"
    exit 0 ;;
  *) sed -n '2,12s/^# \{0,1\}//p' "$0"; exit 2 ;;
esac
