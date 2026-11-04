# Over9k for Herdr

Over9k is a set of [Herdr](https://herdr.dev) mods for working with many coding
agents at once. It adds a sidebar that lists your projects and the agents in
them, a to-do list per project that you and your agents share, a timeline of
each conversation, and your plans' usage limits, all in one layout.

![The Over9k layout](layouts/over9k.svg)

## What you get

- **Sidebar.** A space for each project in your projects folder, pinned or
  parked. Each shows its branch, uncommitted files, pull requests and
  push/pull. Under each project are its agents, with their status, model,
  context and time since their last reply. Under each agent are its subagents,
  background commands and scheduled prompts. Links show work that crosses
  spaces or computers, and projects can have their own icons. You can pick
  several rows and act on them together. Past chats can be resumed from the +
  menu. When an agent's prompt cache has expired, "clear + recap" restarts it
  from a short summary. You can also start Pi on another model, local ones too.
- **Tab bar.** Buttons for Files, Changes, To-do and Timeline. Ctrl+Tab switches
  between agents, most recent first. Closing a tab or pane asks first, and says
  what's still running.
- **To-do panel.** Each project's list, with tabs for the project you're in and
  for All your pinned projects. Agents add and tick items with the `todo`
  command. **Log** has agents add what you ask for as you ask it. **Sync** keeps
  the project's own TODO.md matching the list. Each to-do can be sent to the
  current conversation or to a new agent, and several can be marked done, sent
  or deleted together.
- **Timeline panel.** Your prompts in the agent you're in, each with how long
  the agent worked, when it finished, the tokens it wrote, and the files and
  commands it touched. Click a prompt to read the whole reply. The header shows
  the tokens the agent has written and the context it holds now.
- **Usage.** The 5-hour and weekly limits of Claude, Codex and Gemini, above
  Settings.
- **Help & options** at the bottom of the sidebar. Help is illustrated. Options
  covers what each row shows, the panels, and the Claude Code extras.

## Requirements

| | |
|---|---|
| [Herdr](https://herdr.dev/download/) | 0.1.12 or newer |
| git | the sidebar's branch, changes and push/pull |
| jq | Claude Code's status line, subagents, background tasks, resume, hand-off |
| Python 3 | the Timeline, TODO.md sync |
| Agents | Claude Code gets the most (status, Timeline, to-dos); Codex, Pi and Antigravity are listed too |

Over9k still works without git, jq or Python; it just leaves out the features
that need them. The installer says what's missing and how to install it.

**Platforms.** Over9k is developed on Linux. The macOS and Windows code paths
are in place, but neither has been run there yet. Please report what doesn't
work.

- **Linux:** everything. Choosing a project icon from a file needs kdialog or
  zenity, and pasting one needs wl-paste or xclip.
- **macOS:** everything except two extras that read Linux's `/proc`: finding
  Codex sessions, and listing Antigravity's subagents. Install the tools with
  `brew install jq python git`.
- **Windows:** needs [Git for Windows](https://git-scm.com/download/win), whose
  `sh` runs Over9k's scripts, plus jq and Python:
  `winget install Git.Git jqlang.jq Python.Python.3.12`. The installer can put
  Git's tools on your PATH (`-AddGitToPath`). The same `/proc` extras as on
  macOS are left out.

## Install

```sh
git clone https://github.com/herunan/herdr-over9k.git
cd herdr-over9k
sh install.sh                # Linux, macOS, or Git Bash on Windows
```

Or download the ZIP from GitHub, unzip it, and run the installer from inside it.

On Windows, from PowerShell:

```powershell
powershell -ExecutionPolicy Bypass -File install.ps1
```

Then open Herdr and pick **Settings › Layout › Over9k**. If Herdr is already
running, `herdr-app do layout.switch '{"name":"over9k"}'` switches to it.
**Over9k help & options**, at the bottom of the sidebar, walks you through
picking your projects folder.

The installer takes these options:

- `--home <dir>` (`-HerdrHome` on Windows): a different Herdr home.
- `--no-claude` (`-NoClaude`): leave Claude Code's settings alone.
- `--yes` (`-Yes`): don't ask any questions.

To update, get a newer copy and run the installer again. Your settings and lists
stay.

### What the installer changes

- **Herdr's home** (`~/.config/herdr-app`, or wherever `herdr-app --help` says):
  the mods in `mods/over9k*`, the layout in `layouts/over9k.json`, and Over9k's
  key bindings merged into `keys.json`. Your earlier `keys.json` is kept as
  `keys.json.before-over9k`, and any bindings Over9k replaces come back when you
  uninstall.
- **Claude Code**, only if you say yes: its status line (your own is kept aside),
  the to-do rule in `~/.claude/CLAUDE.md`, the `todo` command in
  `~/.local/bin`, and a hook that reminds agents when request logging is on.
  Codex's and Pi's `AGENTS.md` get the same to-do rule. You can turn each of
  these off again in Options.

## Optional extras

Each of these is off until you turn it on, and each says what it changes.

- **Claude Code status line** (Options › Claude Code). This is the line under
  Claude Code's prompt: model, context, cache and limits. It's also where the
  sidebar's agent details, the usage rows and the Timeline get their data, so
  keep it on unless you have your own. Yours is kept aside and comes back when
  you turn it off.
- **To-do for agents** (Options › To-do, on by default when installed). This
  sets up the rule, the `todo` command and the hook. Below it you can choose
  whether new projects start with Log and Sync on.
- **Hand off project work** (Options › Folders). A chat started outside your
  projects can hand project work to a new agent in that project. This adds a
  rule to CLAUDE.md and AGENTS.md.
- **Antigravity (Gemini) usage and titles.** These are set up by hand. Add the
  following to `~/.gemini/antigravity-cli/settings.json`, with `<mods>` replaced
  by your Herdr home's `mods` folder:

  ```json
  "statusLine": { "type": "command", "command": "sh <mods>/over9k/antigravity/agy-statusline.sh", "stack_with_default": true },
  "title": { "type": "command", "command": "sh <mods>/over9k/antigravity/agy-title.sh" }
  ```

  The usage rows then show Gemini's limits, and the sidebar names Antigravity
  agents by their conversation. Conversation titles need `sqlite3`.
- **Local models for Pi.** The + menu's **Model ›** button for Pi lists the
  models in Pi's `~/.pi/agent/models.json`, and starts a local model's server
  when it has one.

## Uninstall

```sh
sh install.sh --uninstall          # or: install.ps1 -Uninstall
```

This removes the mods, the layout, Over9k's key bindings (giving yours back) and
its Claude Code pieces, restoring your own status line. Your to-do lists stay in
`~/.local/share/over9k`; delete that folder to remove them too.

## Privacy

Everything stays on your computer. Over9k reads your agents' conversation files,
your git repos and Herdr's own state locally, and sends nothing anywhere. Other
computers you've added to Herdr are reached through Herdr itself.

## In this repo

```
install.sh, install.ps1   install, update, uninstall
keys.json                 Over9k's key bindings
layouts/                  the Over9k layout and its preview
mods/
  over9k/                 the sidebar (+ statusline.sh, antigravity/)
  over9k-tabs/            the tab bar
  over9k-todos/           the To-do panel, todo.sh (the `todo` command), its hook
  over9k-prompts/         the Timeline panel
  over9k-usage/           the usage rows
  over9k-options/         Help & Options, setup.sh (what the switches set up)
  over9k-menu/            right-click menus
  over9k-new-menu/        the + menu (start agents, resume chats, other models)
  over9k-footer/          the sidebar's footer
  over9k-switcher/        Ctrl+Tab between agents
  over9k-close/           asks before closing what's still running
  over9k-handoff/         hand an agent's work to another space
  over9k-rename/          rename dialogs
  over9k-server-stop/     stop a local model's server
  over9k-panel/           the header over a subagent shown in the side panel
```

## Licence

MIT. See [LICENSE](LICENSE).
