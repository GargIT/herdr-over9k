# Over9k for Herdr

**Run a fleet of coding agents and actually know what they're doing.** Over9k is
a [Herdr](https://herdr.dev) layout that takes your productivity and visibility
over 9000.

![Over9k](over9k/preview.png)

### See what every agent is doing

One sidebar holds every project and every agent working in it. Point it at your
code folder and each repo shows up on its own, with its branch, uncommitted
files, pull requests and push/pull; pin the projects you care about and park the
rest. Under each project, every agent shows whether it's working or needs you,
which model it's on, how full its context is, and how long since it last
replied. Under each agent sit the subagents, background commands and scheduled
prompts it started. Links show where the work is going: an agent working in
another space, or over SSH on another computer, is marked at both ends.

### Keep the work moving

Your agents keep a to-do list for each project. They add what you ask for as you
ask it and tick it off when it's done, in step with the project's own TODO.md,
and any to-do goes to the current conversation or a new agent in one click. A
chat you started anywhere can hand off to a new agent in the right project, with
a brief, so it becomes project work. Ctrl+Tab jumps between agents, most recent
first, and past Claude Code, Codex and Pi sessions resume from one menu.

### Spend fewer tokens

When an agent's prompt cache has expired, its next message would re-read the
whole chat. One click clears it instead and restarts it from a short recap. The
Timeline shows what every prompt took, in time and tokens, live while the agent
works. Your Claude, Codex and Gemini limits stay in view, and Pi starts on a
local model like Qwen in a click, with its server started and stopped for you.

### Make it yours

Over9k help & options, at the bottom of the sidebar, decides what every row
shows, which panels appear and what's set up for your agents, and its
illustrated Help walks through each part. Right-click menus open folders, hand
off work, split, zoom and close. Use the whole layout, or add only the parts you
want to your own.

## Get started

```sh
git clone https://github.com/herunan/herdr-over9k.git
cd herdr-over9k
sh install.sh                # Linux, macOS, or Git Bash on Windows
```

On Windows, from PowerShell: `powershell -ExecutionPolicy Bypass -File install.ps1`.
Then open Herdr and pick **Settings › Layout › Over9k** (or, if it's running,
`herdr-app do layout.switch '{"name":"over9k"}'`). **Over9k help & options**
walks you through picking your projects folder. To update, run the installer
again from a newer copy; your settings and lists stay.

**Just the parts you want.** Each piece also works on its own in your own
layout. It docks itself the first time Herdr sees it, and installs with
`sh install.sh <name>` (on Windows, `install.ps1 -Mod <name>`):

| Mod | What it is |
|---|---|
| [`over9k-sidebar`](over9k-sidebar) | Projects and agents, with git, links, recaps, hand-offs and its own Help & Options (left) |
| [`over9k-todo`](over9k-todo) | Agentic to-do lists and the `todo` command (right) |
| [`over9k-timeline`](over9k-timeline) | Every prompt's time and tokens (right) |
| [`over9k-usage`](over9k-usage) | Claude, Codex and Gemini limits in one line (bottom) |
| [`over9k-launcher`](over9k-launcher) | Start agents, resume sessions, local models (Ctrl+Shift+A) |
| [`over9k-switcher`](over9k-switcher) | Ctrl+Tab between agents |

The layout already includes all six, so install one or the other, not both.

**What it needs.** Herdr 0.1.12 or newer. git, jq and Python 3 power the git
badges, Claude Code's status line and the Timeline; without one, Over9k leaves
out what needs it, and the installer says what's missing. Claude Code gets the
most out of it; Codex, Pi and Antigravity agents are listed too. Over9k is
developed on Linux. On macOS, install the tools with `brew install jq python
git`. On Windows, it runs its scripts with [Git for Windows](https://git-scm.com/download/win)'
`sh` (`winget install Git.Git jqlang.jq Python.Python.3.12`; the installer can
add Git's tools to your PATH with `-AddGitToPath`). The macOS and Windows paths
haven't been run there yet, so please report what doesn't work. Two extras read
Linux's `/proc` and stay off elsewhere: finding Codex sessions, and listing
Antigravity's subagents.

## What the installer changes

In Herdr's home (`~/.config/herdr-app`, or wherever `herdr-app --help` says), it
adds the mods (`mods/over9k*`) and the layout (`layouts/over9k.json`), and merges
Over9k's key bindings into `keys.json`. Your earlier `keys.json` is kept as
`keys.json.before-over9k`, and any binding Over9k replaces comes back when you
uninstall.

For Claude Code, and only if you say yes, it sets up three things:
- Over9k's status line, with your own kept aside.
- The to-do rule in `~/.claude/CLAUDE.md` (and in Codex's and Pi's `AGENTS.md`),
  plus the `todo` command in `~/.local/bin`.
- A hook that reminds agents when request logging is on.

Each can be turned off again in Options. The installer's other options are
`--home <dir>`, `--no-claude` and `--yes` (`-HerdrHome`, `-NoClaude` and `-Yes`
on Windows).

## Extras

**Claude Code's status line** (Options › Claude Code) is the line under Claude
Code's prompt: model, context, cache and limits. It's also where the sidebar's
agent details, the usage rows and the Timeline get their data, so keep it on
unless you have your own. Yours is kept aside and comes back when you turn it
off.

**To-do for agents** (Options › To-do) sets up the rule, the `todo` command and
the hook. You can also choose whether new projects start with Log and Sync on.

**Hand off project work** (Options › Folders) adds the rule that lets a chat
outside your projects pass project work to a new agent in the right space.

**Local models** come from Pi's `~/.pi/agent/models.json`. A model whose server
is off is started when you pick it, using the commands in
`over9k-new-menu/servers.json`.

**Antigravity (Gemini)** usage and conversation titles are set up by hand. Add
this to `~/.gemini/antigravity-cli/settings.json`, with `<mods>` replaced by
your Herdr home's `mods` folder. Titles need `sqlite3`.

```json
"statusLine": { "type": "command", "command": "sh <mods>/over9k/antigravity/agy-statusline.sh", "stack_with_default": true },
"title": { "type": "command", "command": "sh <mods>/over9k/antigravity/agy-title.sh" }
```

## Uninstall

`sh install.sh --uninstall` (or `install.ps1 -Uninstall`) removes the mods, the
layout, Over9k's key bindings (giving yours back) and its Claude Code pieces,
restoring your own status line. For a single mod, add its name. Your to-do lists
stay in `~/.local/share/over9k`; delete that folder to remove them too.

## Privacy

Over9k has no server of its own and collects nothing. It reads your agents'
conversation files, your git repos and Herdr's state on your computer, and only
reaches the network through your own tools, in three ways:

- **git:** every 5 minutes it fetches each project with a GitHub remote, to show
  how far ahead or behind it is. It pushes and pulls only when you click.
- **gh:** in the same pass, if `gh` is installed, it counts open pull requests
  and checks whether your review is wanted.
- **curl:** the + menu checks whether the local model servers in Pi's list are
  up.

Other computers you've added to Herdr are reached through Herdr itself.

## In this repo

```
install.sh, install.ps1   install, update, uninstall (the layout, or one mod)
tools/build-mods.py       builds the mod folders below from over9k/mods
over9k/                   the layout: layouts/, mods/, keys.json, RECIPE.md, preview.png
  mods/over9k/            the sidebar (+ statusline.sh, antigravity/)
  mods/over9k-tabs/       Herdr's tab bar, with To-do and Timeline added
  mods/over9k-todos/      the To-do panel, todo.sh (the `todo` command), its hook
  mods/over9k-prompts/    the Timeline panel
  mods/over9k-usage/      the usage rows
  mods/over9k-options/    Help & Options, setup.sh (what the switches set up)
  mods/over9k-menu/       right-click menus
  mods/over9k-new-menu/   the + menu (start agents, resume chats, local models)
  mods/over9k-footer/     the sidebar's footer
  mods/over9k-switcher/   Ctrl+Tab between agents
  mods/over9k-close/      asks before closing what's still running
  mods/over9k-handoff/    hand an agent's work to another space
  mods/over9k-rename/     rename dialogs
  mods/over9k-server-stop/  stop a local model's server
  mods/over9k-panel/      the header over a subagent shown in the side panel
over9k-sidebar/ … over9k-switcher/   the six mods on their own, each with
                          mods/, RECIPE.md, preview.png (and keys.json)
```

## Licence

MIT. See [LICENSE](LICENSE).
