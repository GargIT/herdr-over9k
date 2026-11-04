# Over9k Usage

Know your limits before you hit them. Claude's, Codex's and Gemini's 5-hour and
weekly limits sit in one line along the bottom of the window, each coloured green,
yellow or red, with when it resets. Hover a service to see every limit.

![Over9k Usage](preview.png)

## What you see

- **The strip**, docked at the bottom, 30px high, on `chrome` with a 1px
  `border` above, in 12px. For each service:
  - its name in `muted`
  - its plan in a 10.5px badge (`raised`, `accent` text)
  - the most-used limit's percentage: `ansi2` (green) under 50, `ansi3` (yellow)
    from 50, `ansi1` (red) from 80
  - the time until it resets, in 11px `dim`
- **"Claude · Show its limits"**, a link in `accent` at the end of the strip.
  It shows when Claude Code is installed but the status line isn't Over9k's.
- **Claude on Amazon Bedrock** has no plan limits (it's paid per use), so its
  row shows a "Bedrock" badge and today's spend, such as "today $14.20". Hover
  or open it for each session's cost by project. This is Claude Code's own
  estimate, not the AWS bill.
- **Inside the Over9k layout**, the same data is drawn as 28px rows above the
  sidebar's footer. Clicking a row opens every limit as a 3px bar.

## How it behaves

- **Hover:** a service shows every limit and its reset time.
- **"Show its limits"** runs `setup.sh status on <this mod>/statusline.sh`,
  which makes Over9k's status line Claude Code's. It shows nothing itself:
  someone else's status line is kept in `~/.claude/.over9k-statusline-was.json`,
  still shows (Over9k's runs it), and is put back when it's turned off. Claude's numbers appear after the next reply.
- **Where the data comes from:**
  - **Claude:** `~/.cache/over9k/usage/claude.json`, written by the status
    line, plus the plan name from `~/.claude.json`. On Bedrock
    (`CLAUDE_CODE_USE_BEDROCK`, or a Bedrock model id), the status line marks it
    `{"bedrock": true}` and keeps each session's cost per day in
    `usage/bedrock/<session>.json` as `{days: {"2026-11-04": 2.5}, project}`. That
    is Claude Code's running `cost.total_cost_usd`, split at midnight.
  - **Codex:** its latest session file under `~/.codex/sessions`.
  - **Gemini:** `~/.cache/over9k/usage/antigravity.json`, from Antigravity's
    status line (`agy-statusline.sh` in the Over9k layout, set up by hand).

## Built from

- **`mods/over9k-usage/`**, with `mod.json` set to
  `{"place": "bottom", "size": 30}`:
  - `main.js`: the strip, or the layout's rows.
  - `statusline.sh`: Claude Code's status line. It shows nothing itself (your own status line, if any, still shows) and writes
    `~/.cache/claude-agents/<terminal>.json`.
  - `setup.sh`: the status line on or off.
- `main.js` draws rows when the layout has a block with id `usage` holding this
  mod (the Over9k layout), and the strip otherwise. Only the rows resize their
  block (`layout.resize`).
- **herdr:** `layout`, `run`, `exec` (`sh`, `jq`), `readTextFile`, `notify`,
  `shared` (`sidebar.options` hides services in Over9k).
- **Programs:** `sh` and `jq`.

## Watch out

- The strip has no room to open rows, so it lists limits on hover instead.
- Claude's limits exist only in the status line's input, so without Over9k's
  status line there's no Claude row.
- The status line refreshes every 5s, and only while Claude Code is open.

## Done when

- The strip docks at the bottom and shows Codex's limits after a Codex
  session.
- "Show its limits" sets `statusLine` in `~/.claude/settings.json` to this
  mod's `statusline.sh`. After a Claude Code reply, Claude shows with its plan
  and percentage.
- Turning the status line off again restores the previous `statusLine`.
