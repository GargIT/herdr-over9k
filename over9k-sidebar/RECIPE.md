# Over9k Sidebar

Every project and every agent, in one list. Point it at your code folder and
every repo shows up on its own, with its git state; pin the ones you care
about. Under each project, every agent shows what it's doing, its model, how
full its context is, what it started, and where its work is going, even over
SSH. Chats hand off to become projects, expired agents clear to a
token-saving recap in one click, and past sessions and local models are one
menu away.

![Over9k Sidebar](preview.png)

## What you see

It docks on the left, 268px wide (44 when collapsed), on `chrome`, in 13px type.
All colours are theme names.

- **Filter row**, 30px: **All** and **Agents N** as 20px tabs, the picked one on
  `raised`. Agents groups every agent by Space or by Status ("Needs you",
  "Working", "Done").
- **Computer headers**: "This computer" or a machine's name, with a monitor or
  server icon, a connection dot (green, or `dim` when offline, which fades its
  rows), a fold chevron and a +. A local model server that's running shows as a
  chip, such as "Qwen3.8".
- **Project rows**, 30px, 8px radius, the name in the project's colour. The open
  space is on `selected`. After the name:
  - the GitHub or GitLab mark
  - uncommitted files (`ansi3`)
  - ↑ ahead (`ansi2`) and ↓ behind (`ansi1`)
  - open pull requests (red when your review is wanted)
  - on your own repos, open issues and stars

  Worktrees sit under their checkout with a branch icon.
- **Agent rows**, 26px (compact) or 36px (expanded):
  - Status: a 12px `working` spinner, or a 7px dot in `blocked` or `done`.
    Idle has no mark and a `muted` name.
  - The program's logo and the conversation's name.
  - Details in 11px `dim`: model · effort · context % (green, yellow from 50,
    red from 80) · time since the last reply.
  - When the prompt cache has run out: a red "exp.", then "clear + recap" on
    `hover`, in red.
  - On the right, a count chip (bot n, subagent n, chevron).
- **What an agent started**, on a 1.5px rail under it, 22px rows:
  - subagents (subagent icon)
  - agents in terminals of their own (bot icon)
  - background commands (cpu icon)
  - scheduled prompts (clock icon)

  Each has its name in `muted` and its age.
- **Links**: 16px chips on a 15% tint of a per-link colour. "icon →" sits where
  the work started, "→ icon" where it's happening. Over SSH, the computer's
  server icon follows the arrow. Hovering either end lights up both rows.
- **Not open**: projects with no open space, under a folded heading.
- **Over9k help & options**, a 32px row at the bottom, when there's no Over9k
  footer.

## How it behaves

- **Projects** are git repos in the projects folder (Options › Folders), plus
  folders with a CLAUDE.md, AGENTS.md or .claude, plus pinned ones. "Add new
  projects automatically" pins new ones it finds.
- **Clicks:**
  - Click a project or agent to focus it. Double-click to rename. Drag to
    reorder.
  - Ctrl or Cmd-click picks one more row, and Shift-click a range. Right-click
    a picked row to group them into one tab, close them or unpin them.
  - Right-click a row for its menu (`over9k-menu`): rename, Open folder,
    pin/unpin, Hand off…, splits, zoom, close. Closing asks first, through
    `over9k-close`.
- **Git badges:**
  - The GitHub or GitLab mark opens the repo.
  - The uncommitted count opens Changes.
  - ↑ pushes (click twice). ↓ pulls (`--ff-only`).
  - Every 5 minutes it runs `git fetch`, and `gh` (GitHub) or `glab` (GitLab) counts pull or merge requests, issues and stars.
- **What an agent started:** click its chip to show or hide the list. Click a
  subagent to view it, Alt-click to view it in the side panel, × to stop it.
- **clear + recap** sends `/clear` with a recap brief, so the agent restarts
  from a short summary instead of re-reading the whole chat.
- **Hand off…** opens `over9k-handoff`. It asks the agent to pass its project
  work to a new agent in that project's space, with a brief.
- **The + on a computer** opens the launcher (`over9k-new-menu`): start an agent
  or CLI, resume a session, start Pi on a local model, stop a server, add
  spaces.
- **Pin an agent in a + (for Pi, a model):** a little bot left of the + starts it
  in one click, on that device and all its spaces.
- **Ctrl+Tab** opens `over9k-switcher`, most recent first. This sidebar keeps
  the order.
- **Options** (the bottom row) covers:
  - folders
  - what each row shows
  - Claude Code: an optional status line (off by default) that shows model,
    context, cache and limits under the prompt and feeds Claude's usage row
  - the hand-off and to-do rules for agents

  Its Help is illustrated, page by page.

## Built from

- **`mods/over9k/`**, with `mod.json` set to `{"place": "left", "size": 268}`:
  - `main.js`: the sidebar.
  - `agent-name.js`, `close-plan.js`.
  - `handoff.sh`, copied to `~/.local/share/over9k` for agents to run.
  - The helper scripts `subagents.sh`, `tasks.sh`, `codex.sh`,
    `subagent-view.sh`, `output-view.sh`, `note-view.sh`, `agy-subagents.py`.
  - `antigravity/` (optional) and the icons.
- **The overlays it opens:** `over9k-menu`, `over9k-new-menu` (with
  `over9k-server-stop`), `over9k-close`, `over9k-rename`, `over9k-handoff`,
  `over9k-panel`, `over9k-switcher`, and `over9k-options` (with `setup.sh`,
  which turns the Claude Code pieces on and off).
- **`keys.json`** (and `keys.macos.json`, with Cmd+Shift+W and Cmd+Shift+X):
  Ctrl+Tab → `over9k.switcher`, Ctrl+Shift+W → `over9k.close-tab`,
  Ctrl+Shift+X → `over9k.close-pane`, plus the switcher's own keys.
- **herdr:**
  - Reading: `spaces`, `agents`, `terminals`, `panes`, `machines`, `focused`,
    `layout`.
  - `run`: `space.select`, `tab.select`, `pane.focus`, `agent.focus`, `tab.new`,
    `space.new`, `layout.set` / `select` / `show` / `hide`, `terminal.peek`.
  - `exec` (`sh`, `git`, `gh`, `glab`, `ps`, Python), `hc` (`read`, `send`, `kill`,
    `run`), `watchFolder`, `readTextFile`, `openOverlay`, `notify`,
    `nextCommand`.
  - It writes `shared` keys for the others: `projects.pinned`,
    `projects.listed`, `over9k.recentAgents`, `sidebar.options`.

## Watch out

- On macOS, merge `keys.macos.json` instead (Cmd where macOS expects it); Ctrl+Tab stays, since macOS keeps Cmd+Tab for switching apps.

- **Agent details:** model, effort, context and cache come from Claude Code's
  own files, never its status line. `claude-info.py` matches
  `~/.claude/sessions/<pid>.json` to the Herdr terminal (the process's
  `HC_TERMINAL_ID`: `/proc` on Linux, `ps -wwE` on macOS; none on Windows),
  reads the end of the conversation and writes
  `~/.cache/over9k/agents/<terminal>.json`.
  Antigravity's come from `agy-info.py`: the `presence/<id>.lock` the agy
  process holds open (`/proc`, or `lsof` on macOS) names its conversation, whose
  newest `gen_metadata` holds "Gemini 4 Argon (Medium)", and
  `conversation_summaries.db` its title. Its context only comes from its
  optional status line.
- **Linux-only extras:** Codex session detection, Antigravity subagents and the
  "SSH'd from here" links read `/proc`.
- **Windows:** needs Git for Windows' `sh`.
- **Side panel:** "View in the side panel" uses the layout's `panel-body` stack.
  A layout without one gets a peek instead.
- **Load:** keep polling gentle, since the sidebar runs git for every visible
  repo. It refreshes git only when something could have changed (a command or
  turn ended, a folder changed), with a fallback timer.

## Done when

- The sidebar docks on the left. With the projects folder set, its git repos
  are listed with branch badges.
- A Claude Code agent in a project shows under it, with a spinner while it
  works. With the data file there, it shows the model and context %.
- A subagent it starts appears under it, and its chip counts it.
- Right-click › Open folder opens the project in the file manager.
- Ctrl+Tab lists agents. Letting go of Ctrl switches.
- After an hour idle, a Claude Code agent shows "exp.". "clear + recap" restarts
  it with a short context.
