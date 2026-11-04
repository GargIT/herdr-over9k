#!/bin/sh
# Over9k for Herdr: install, update or remove (Linux, macOS, and Windows in Git Bash;
# on Windows, install.ps1 does the same from PowerShell).
#
#   sh install.sh              install, or update an earlier install (settings are kept)
#   sh install.sh --uninstall  remove Over9k's mods, layout, key bindings and Claude
#                              Code pieces (your to-do lists stay)
# Options:
#   --home <dir>   Herdr's home (default: what `herdr-app --help` says, else
#                  $HERDR_APP_HOME, else ~/.config/herdr-app)
#   --no-claude    leave Claude Code's settings alone (turn things on later in
#                  Over9k's Options instead)
#   --yes          don't ask
set -eu

here=$(cd "$(dirname "$0")" && pwd)
home_dir="" claude=ask yes=no mode=install
while [ $# -gt 0 ]; do
  case "$1" in
    --home) home_dir=${2:?--home needs a folder}; shift ;;
    --no-claude) claude=no ;;
    --yes|-y) yes=yes ;;
    --uninstall) mode=uninstall ;;
    -h|--help) sed -n '2,15s/^# \{0,1\}//p' "$0"; exit 0 ;;
    *) echo "Unknown option: $1 (see --help)" >&2; exit 2 ;;
  esac
  shift
done

say() { printf '%s\n' "$*"; }
ask() { # ask "question" -> 0 for yes (the default), 1 for no
  [ "$yes" = yes ] && return 0
  [ -t 0 ] || return 0
  printf '%s [Y/n] ' "$1"; read -r a || a=""
  case "$a" in n|N|no|No) return 1 ;; *) return 0 ;; esac
}
py=$(command -v python3 2>/dev/null || command -v python 2>/dev/null || true)
[ -n "$py" ] && ! "$py" -c 'import sys; sys.exit(sys.version_info[0] < 3)' 2>/dev/null && py=""

# Herdr's home: --home, what Herdr itself says, $HERDR_APP_HOME, or the default.
if [ -z "$home_dir" ]; then
  h=$(herdr-app --help 2>/dev/null | sed -n 's/^Home: \([^ ]*\).*/\1/p' | head -n 1 || true)
  case "$h" in "~"*) h="$HOME${h#\~}" ;; esac
  home_dir=${h:-${HERDR_APP_HOME:-$HOME/.config/herdr-app}}
fi
case "$home_dir" in [A-Za-z]:\\*|[A-Za-z]:/*) command -v cygpath >/dev/null 2>&1 && home_dir=$(cygpath -u "$home_dir") ;; esac
mods_dir="$home_dir/mods"
# The mods folder as Over9k's scripts get it (forward slashes, which sh and
# Python take on Windows too).
mods_arg=$mods_dir
command -v cygpath >/dev/null 2>&1 && mods_arg=$(cygpath -m "$mods_dir")
setup() { sh "$mods_dir/over9k-options/setup.sh" "$@"; }

# Key bindings: Over9k's (keys.json here) merged into Herdr's, or taken out again
# where they're still Over9k's. Needs Python; without it, says what to add.
keys() {
  if [ -z "$py" ]; then
    say "  Key bindings: add these to $home_dir/keys.json yourself:"; sed 's/^/    /' "$here/keys.json"; return
  fi
  "$py" -I - "$1" "$here/keys.json" "$home_dir/keys.json" <<'EOF'
import json, os, shutil, sys
how, ours_path, theirs_path = sys.argv[1:4]
ours = json.load(open(ours_path, encoding="utf-8"))
# What Over9k's bindings replaced, given back when it's removed.
was_path = os.path.join(os.path.dirname(theirs_path), "keys.over9k-was.json")
was = json.load(open(was_path, encoding="utf-8")) if os.path.exists(was_path) else {}
theirs = {}
if os.path.exists(theirs_path):
    if not os.path.exists(theirs_path + ".before-over9k"):
        shutil.copyfile(theirs_path, theirs_path + ".before-over9k")
    with open(theirs_path, encoding="utf-8") as f:
        theirs = json.load(f)
for section, binds in ours.items():
    have = theirs.setdefault(section, {})
    for key, action in binds.items():
        if how == "add":
            if key in have and have[key] != action:
                was.setdefault(section, {}).setdefault(key, have[key])
            have[key] = action
        elif have.get(key) == action:
            del have[key]
            if key in was.get(section, {}):
                have[key] = was[section].pop(key)
    if not have:
        del theirs[section]
if how == "add" and was:
    json.dump(was, open(was_path, "w", encoding="utf-8"), indent=2)
elif how != "add" and os.path.exists(was_path):
    os.remove(was_path)
with open(theirs_path, "w", encoding="utf-8") as f:
    json.dump(theirs, f, indent=2, ensure_ascii=False)
    f.write("\n")
EOF
}

if [ "$mode" = uninstall ]; then
  say "Removing Over9k from $home_dir"
  if [ -f "$mods_dir/over9k-options/setup.sh" ] && command -v jq >/dev/null 2>&1; then
    setup status off "$mods_arg" || true
    setup todo off "$mods_arg" || true
    setup cleanup || true
  fi
  for d in "$here"/mods/*/; do rm -rf "$mods_dir/$(basename "$d")"; done
  rm -f "$home_dir/layouts/over9k.json" "$home_dir/layouts/over9k.svg"
  [ -f "$home_dir/keys.json" ] && keys remove
  say "Done. Your to-do lists are still in ${XDG_DATA_HOME:-$HOME/.local/share}/over9k (delete it to remove them too)."
  say "If Over9k's layout was showing, pick another in Herdr's settings."
  exit 0
fi

say "Installing Over9k into $home_dir"
mkdir -p "$mods_dir" "$home_dir/layouts"

# The mods. Files the mods write themselves aren't replaced on an update.
for d in "$here"/mods/*/; do
  name=$(basename "$d") dest="$mods_dir/$name"
  mkdir -p "$dest"
  (cd "$d" && find . -type f ! -name 'gpui-kit.d.ts' ! -name 'herdr.d.ts' ! -name 'jsconfig.json' ! -name '*.pyc') | while read -r f; do
    case "$name/${f#./}" in over9k-new-menu/servers.json) [ -f "$dest/${f#./}" ] && continue ;; esac
    mkdir -p "$dest/$(dirname "$f")"; cp "$d/$f" "$dest/$f"
  done
  # Files an earlier version had that this one doesn't (Herdr's own and what
  # the mods write themselves stay).
  (cd "$dest" && find . -type f ! -name 'gpui-kit.d.ts' ! -name 'herdr.d.ts' ! -name 'jsconfig.json' ! -name '*.error') | while read -r f; do
    case "$name/${f#./}" in over9k-new-menu/servers.json) continue ;; esac
    [ -e "$d/$f" ] || rm -f "$dest/$f"
  done
  chmod +x "$dest"/*.sh 2>/dev/null || true
done
say "  Mods: $(ls -d "$here"/mods/*/ | wc -l | tr -d ' ') copied"

# The layout (a changed copy of an earlier one is kept beside it).
if [ -f "$home_dir/layouts/over9k.json" ] && ! cmp -s "$here/layouts/over9k.json" "$home_dir/layouts/over9k.json"; then
  cp "$home_dir/layouts/over9k.json" "$home_dir/layouts/over9k.json.before-update"
fi
cp "$here/layouts/over9k.json" "$here/layouts/over9k.svg" "$home_dir/layouts/"
say "  Layout: over9k"
keys add && say "  Key bindings: added (Herdr's earlier keys.json is kept as keys.json.before-over9k)"

# Hooks earlier versions of Over9k added (removed features).
setup cleanup || true

# What the mods need from this computer.
missing=$(setup check)
if [ -n "$missing" ]; then
  say ""; say "Missing (Over9k works without them, minus these):"
  printf '%s\n' "$missing" | sed 's/^/  - /'
  case "$(uname -s)" in
    Darwin) say "  Install with Homebrew: brew install jq python git" ;;
    Linux) say "  Install with your package manager, e.g. sudo apt install jq python3 git" ;;
    MINGW*|MSYS*|CYGWIN*) say "  Install with winget: winget install jqlang.jq Python.Python.3.12 Git.Git" ;;
  esac
fi

# Claude Code: its status line (the sidebar's agent details, the usage rows and
# the Timeline read it), the to-do rule, command and hook.
if [ -d "$HOME/.claude" ] || command -v claude >/dev/null 2>&1; then
  if [ "$claude" != no ] && ask "Set up Claude Code for Over9k (status line, to-do rule and hook; your own status line is kept aside)?"; then
    if command -v jq >/dev/null 2>&1; then
      setup status on "$mods_arg" && setup todo on "$mods_arg" && say "  Claude Code: status line, to-do rule, todo command and hook set up"
    else
      setup todo on "$mods_arg"; say "  Claude Code: to-do rule and todo command set up; the status line and hook need jq (then Options › Claude Code)"
    fi
    case ":$PATH:" in *":$HOME/.local/bin:"*) ;; *) say "  Note: add ~/.local/bin to your PATH so agents can run \`todo\`." ;; esac
  fi
fi

say ""
say "Next:"
say "  1. Open Herdr (or restart it), then Settings › Layout › Over9k."
if herdr-app status >/dev/null 2>&1; then say "     It's running: herdr-app do layout.switch '{\"name\":\"over9k\"}' switches now."; fi
say "  2. Over9k help & options is at the bottom of the sidebar: pick your projects"
say "     folder, then what each row shows. Claude Code extras: Options › Claude Code."
say "  Update: pull or download a newer copy and run this again. Remove: sh install.sh --uninstall"
