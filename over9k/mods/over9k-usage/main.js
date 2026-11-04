// Usage limits across every model, at the bottom of the sidebar (main-projects
// layout, block "usage", between the project list and the footer). One row per
// service with limits: its name, plan, when its fullest limit resets, a dot and
// that limit's used %; a click shows every limit as a bar. Local models have no
// limits, so they aren't here.
// Where the numbers come from (this computer):
//   Claude       ~/.cache/over9k/usage/claude.json, saved by Over9k's optional status
//                line (claude-statusline.sh: Options › Status lines, or "Show its
//                limits" here), the only thing Claude Code gives its limits to; plan
//                from ~/.claude.json's oauthAccount.planDisplayName. On Amazon Bedrock
//                (no plan limits, paid per use) it says so, and the row shows today's
//                spend instead: usage/bedrock/<session>.json, each session's cost per day.
//   Gemini       ~/.cache/over9k/usage/antigravity.json, written by
//                Antigravity's (over9k/antigravity/agy-statusline.sh, optional: README):
//                gemini-* and 3p-* (Claude and GPT) buckets, and the plan.
//   Codex        the last rate_limits in its newest session file.
// Each is as fresh as that program's last run; a limit whose reset time has
// passed shows 0%. Over9k's Options › Usage (shared "sidebar.options": usage,
// usageClaude, usageCodex, usageGemini) hides the section or a service.

import { View, div, svg } from "gpui-kit";
import { v_flex, h_flex } from "gpui-base";
import { theme, exec, home, appHome, run, shared, setShared, layout, notify, readTextFile } from "herdr";

const BLOCK = "usage";
// Is this copy the Over9k layout's (its "usage" block above the footer)? Else it
// is the mod on its own, docked at the bottom: one line across the window.
function inLayout() {
  const find = (n) => n && (n.id === BLOCK && n.content?.mod === "over9k-usage" ? n : (n.children ?? []).map(find).find(Boolean));
  return Boolean(find(layout()));
}
const ROW = 28, LIMIT = 20;

const CODEX = `f=$(ls -t "$HOME"/.codex/sessions/*/*/*/*.jsonl 2>/dev/null | head -n 1); [ -n "$f" ] || exit 0
grep -o '"rate_limits":{.*' "$f" | tail -n 1 | sed 's/^"rate_limits"://' | jq -c '{plan: .plan_type, primary, secondary}' 2>/dev/null`;
const CLAUDE_PLAN = `jq -r '.oauthAccount.planDisplayName // empty' "$HOME/.claude.json" 2>/dev/null`;

// Seconds as "3h 54m", "6d 23h", "12m".
function left(s) {
  s = Math.max(0, Math.round(s));
  return s < 3600 ? `${Math.max(1, Math.floor(s / 60))}m` : s < 86400 ? `${Math.floor(s / 3600)}h ${Math.floor((s % 3600) / 60)}m` : `${Math.floor(s / 86400)}d ${Math.floor((s % 86400) / 3600)}h`;
}
// A window's length in words: 300 minutes is "5 hours", 10080 "7 days".
function windowName(min) {
  if (!min) return "Limit";
  return min % 1440 === 0 ? `${min / 1440}d` : min % 60 === 0 ? `${min / 60}h` : `${min}m`;
}
// "Google AI Ultra" is "Ultra"; "Claude Max" is "Max".
const money = (n) => `$${(n ?? 0).toFixed(2)}`;
const SPEND_TIP = "Today's cost on Amazon Bedrock: Claude Code's estimate, not your AWS bill";
const planName = (p) => (p ?? "").replace(/^(google ai|claude|chatgpt)\s+/i, "").replace(/^\w/, (c) => c.toUpperCase()) || null;

async function readJson(path) {
  const r = await exec("cat", [path]).catch(() => null);
  try { return r?.code === 0 ? JSON.parse(r.stdout) : null; } catch { return null; }
}

export default class Usage extends View {
  init(_props, cx) {
    this.services = [];
    this.open = new Set(shared("over9k.usageOpen") ?? []);
    this.height = 0;
    cx.spawn(async (cx) => {
      for (;;) {
        await this.load();
        cx.notify();
        await cx.sleep(30000);
      }
    });
  }

  async load() {
    const now = Date.now() / 1000, dir = `${home()}/.cache/over9k/usage`;
    const out = [];
    // A limit: label, used % (0 once it has reset), seconds to its reset.
    const limit = (label, used, resetsAt) => resetsAt && resetsAt <= now ? { label, used: 0, left: null } : { label, used: Math.max(0, Math.min(100, used ?? 0)), left: resetsAt ? resetsAt - now : null };

    const claude = await readJson(`${dir}/claude.json`);
    if (claude?.bedrock) {
      // Today's spend: each session's cost today, by project (Claude Code's estimate).
      const d = new Date(), day = `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, "0")}-${String(d.getDate()).padStart(2, "0")}`;
      const r = await exec("sh", ["-c", 'for f in "$1"/*.json; do [ -f "$f" ] && cat "$f" && echo; done', "sh", `${dir}/bedrock`]).catch(() => null);
      const sessions = (r?.stdout ?? "").split("\n").map((l) => { try { return JSON.parse(l); } catch { return null; } })
        .filter((x) => x?.days?.[day] > 0).map((x) => ({ label: x.project || "session", cost: x.days[day] })).sort((a, b) => b.cost - a.cost);
      out.push({ key: "claude", name: "Claude", plan: "Bedrock", spend: sessions.reduce((n, x) => n + x.cost, 0), sessions });
    } else if (claude) {
      const plan = (await exec("sh", ["-c", CLAUDE_PLAN]).catch(() => null))?.stdout.trim();
      out.push({ key: "claude", name: "Claude", plan: planName(plan), limits: [
        claude.five_hour && limit("5h", claude.five_hour.used_percentage, claude.five_hour.resets_at),
        claude.seven_day && limit("7d", claude.seven_day.used_percentage, claude.seven_day.resets_at),
      ].filter(Boolean) });
    }
    const codex = await exec("sh", ["-c", CODEX]).then((r) => JSON.parse(r.stdout || "null")).catch(() => null);
    if (codex) {
      out.push({ key: "codex", name: "Codex", plan: planName(codex.plan), limits: [codex.primary, codex.secondary].filter(Boolean)
        .map((w) => limit(windowName(w.window_minutes), w.used_percent, w.resets_at)) });
    }
    const agy = await readJson(`${dir}/antigravity.json`);
    if (agy?.quota) {
      const q = agy.quota, at = agy.at ?? now;
      const b = (key, label) => q[key] && limit(label, (1 - (q[key].remaining_fraction ?? 1)) * 100, q[key].reset_in_seconds != null ? at + q[key].reset_in_seconds : null);
      out.push({ key: "gemini", name: "Gemini", plan: planName(agy.plan), limits: [
        b("gemini-5h", "5h"), b("gemini-weekly", "7d"), b("3p-5h", "5h 3rd party"), b("3p-weekly", "7d 3rd party"),
      ].filter(Boolean) });
    }
    this.all = out;
    this.pick();
  }

  // What Options says to show.
  pick() {
    const o = shared("sidebar.options") ?? {};
    const want = { claude: o.usageClaude !== false, codex: o.usageCodex !== false, gemini: o.usageGemini !== false };
    this.services = o.usage === false ? [] : (this.all ?? []).filter((s) => want[s.key] !== false);
    this.fit();
  }

  // The block's height: every row, plus the open ones' limits.
  fit() {
    if (!inLayout()) return;
    const h = this.services.length ? 6 + this.services.reduce((n, s) => n + ROW + (this.open.has(s.key) ? Math.max(1, s.spend != null ? s.sessions.length : s.limits?.length ?? 0) * LIMIT + 4 : 0), 0) : 0;
    if (h !== this.height) { this.height = h; run("layout.resize", { id: BLOCK, px: h }); }
  }

  toggle(key, cx) {
    if (this.open.has(key)) this.open.delete(key); else this.open.add(key);
    setShared("over9k.usageOpen", [...this.open]);
    this.fit();
    cx.notify();
  }

  color(t, used) {
    return used >= 80 ? t.ansi1 : used >= 50 ? t.ansi3 : t.ansi2;
  }

  // Claude's limits only reach a status line: on its own, this mod offers to turn
  // on Over9k's (claude-statusline.sh, setup.sh next to this file). Optional.
  setUpClaude(cx) {
    const mods = `${appHome().replace(/\\/g, "/")}/mods`;
    cx.spawn(async (cx) => {
      const r = await exec("sh", [`${mods}/over9k-usage/setup.sh`, "status", "on", `${mods}/over9k-usage/claude-statusline.sh`]).catch(() => null);
      notify(r?.code === 0
        ? { title: "Claude's limits are on their way", body: "They show after Claude Code's next reply, with a status line under its prompt. Agents started from now on get it.", level: "info" }
        : { title: "Couldn't turn on the status line", body: (r?.stderr ?? "").trim() || "Needs sh and jq.", level: "warning" });
      this.checkClaude(cx);
    });
  }

  checkClaude(cx) {
    readTextFile(`${home()}/.claude/settings.json`).then((text) => {
      const ours = /over9k[^/"]*\/claude-statusline\.sh/.test(text ?? "");
      const has = text != null;
      if (ours !== this.claudeOurs || has !== this.claudeHere) { this.claudeOurs = ours; this.claudeHere = has; cx.notify(); }
    }).catch(() => null);
  }

  // On its own: one line across the bottom. Each service's name, plan, the most
  // used limit and when it resets; hover shows every limit.
  strip(t, cx) {
    if (this.claudeChecked !== true) { this.claudeChecked = true; this.checkClaude(cx); }
    const missingClaude = this.claudeHere && !this.claudeOurs && !this.services.some((s) => s.key === "claude");
    return h_flex().size_full().px(12).gap(18).items_center().bg(t.chrome).border_t(1).border_color(t.border).text_size(12)
      .children(this.services.map((s) => {
        const top = s.limits?.length ? s.limits.reduce((a, b) => (b.used > a.used ? b : a)) : null;
        const all = s.spend != null ? [SPEND_TIP, ...s.sessions.map((x) => `${x.label}: ${money(x.cost)}`)].join("\n")
          : (s.limits ?? []).map((l) => `${l.label}: ${Math.round(l.used)}%${l.left != null ? `, resets in ${left(l.left)}` : ""}`).join("\n");
        return h_flex().id(`strip-${s.key}`).flex_none().gap(6).items_center().when(Boolean(all), (el) => el.tooltip(all))
          .child(div().text_color(t.muted).child(s.name))
          .when(Boolean(s.plan), (el) => el.child(div().px(5).py(1).rounded(4).bg(t.raised).text_size(10.5).text_color(t.accent).child(s.plan)))
          .when(s.spend != null, (el) => el.child(div().text_color(t.foreground).child(money(s.spend))).child(div().text_size(11).text_color(t.dim).child("today")))
          .when(Boolean(top), (el) => el.child(div().text_color(this.color(t, top.used)).child(`${Math.round(top.used)}%`))
            .when(top.left != null, (el) => el.child(div().text_size(11).text_color(t.dim).child(left(top.left)))));
      }))
      .when(missingClaude, (el) => el.child(h_flex().id("strip-setup").flex_none().gap(6).items_center().px(7).py(2).rounded(5).cursor_pointer()
        .text_color(t.accent).hover((x) => x.bg(t.hover)).on_click((_e, cx) => this.setUpClaude(cx))
        .tooltip("Turns on Over9k's Claude Code status line, which shows a line under the prompt and saves the limits. Your own comes back when it's off.")
        .child(div().text_color(t.muted).child("Claude")).child("Show its limits")))
      .when(!this.services.length && !missingClaude, (el) => el.child(div().text_color(t.dim).child("No usage yet: start Claude Code, Codex or Antigravity")));
  }

  render(cx) {
    const t = theme();
    const o = JSON.stringify(shared("sidebar.options") ?? {});
    if (o !== this.seenOptions) { this.seenOptions = o; this.pick(); }
    if (!inLayout()) return this.strip(t, cx);
    const dim = (s) => div().text_size(11).text_color(t.dim).child(s);
    return v_flex().w_full().pt(3).px(10).border_t(1).border_color(t.border).bg(t.chrome).text_size(12.5)
      .children(this.services.map((s, i) => {
        const open = this.open.has(s.key);
        const top = s.limits?.length ? s.limits.reduce((a, b) => (b.used > a.used ? b : a)) : null;
        return v_flex().w_full()
          .when(i > 0, (el) => el.border_t(1).border_color(t.border))
          .child(h_flex().id(`usage-${s.key}`).h(ROW).px(4).gap(6).items_center().rounded(6).cursor_pointer()
            .hover((x) => x.bg(t.hover))
            .on_click((_e, cx) => this.toggle(s.key, cx))
            // Name and plan shrink too (the name is cut) once the reset time is gone,
            // so the right side never moves.
            .child(h_flex().min_w(0).flex_shrink(1).gap(6).items_center().overflow_hidden()
              .child(div().min_w(0).truncate().text_color(t.muted).child(s.name))
              .when(Boolean(s.plan), (el) => el.child(div().flex_shrink_0().px(5).py(1).rounded(4).bg(t.raised).text_size(10.5).text_color(t.accent).child(s.plan))))
            // The reset time gives way first when the sidebar is narrow (cut, then
            // gone); the dot, the % (fixed width, right-aligned) and the arrow stay put.
            .child(h_flex().flex_1().min_w(0).justify_end().overflow_hidden()
              .when(s.spend != null && !open, (el) => el.child(dim("today").id(`spend-${s.key}`).tooltip(SPEND_TIP)))
              .when(Boolean(top) && !open && top.left != null, (el) => el.child(h_flex().id(`reset-${s.key}`).min_w(0).gap(3).items_center().tooltip(`Resets in ${left(top.left)}`)
                .child(dim(left(top.left)).min_w(0).truncate()))))
            .when(Boolean(top) && !open, (el) => el
              .child(div().w(32).flex_none().flex().justify_end().text_color(this.color(t, top.used)).child(`${Math.round(top.used)}%`)))
            .when(s.spend != null && !open, (el) => el.child(div().flex_none().pl(6).text_color(t.foreground).child(money(s.spend))))
            .child(svg(`mods/workspace-chrome/chevron-${open ? "down" : "right"}.svg`).size(8).flex_none().flex_shrink_0().text_color(t.dim)))
          .when(open && s.spend != null, (el) => el.child(v_flex().px(4).pb(4)
            .when(!s.sessions.length, (el) => el.child(div().h(LIMIT).flex().items_center().text_size(11.5).text_color(t.dim).child("No sessions today")))
            .children(s.sessions.map((x) => h_flex().h(LIMIT).items_center().gap(7).text_size(11.5)
              .child(div().flex_1().min_w(0).truncate().text_color(t.muted).child(x.label))
              .child(div().flex_none().text_color(t.foreground).child(money(x.cost)))))))
          .when(open && Boolean(s.limits), (el) => el.child(v_flex().px(4).pb(4).children(s.limits.map((l) =>
            h_flex().h(LIMIT).items_center().gap(7).text_size(11.5)
              .child(div().w(82).flex_none().truncate().text_color(t.muted).child(l.label))
              .child(div().flex_1().h(3).rounded(2).bg(t.raised)
                .child(div().h(3).rounded(2).bg(this.color(t, l.used)).w(`${Math.max(l.used > 0 ? 3 : 0, l.used)}%`)))
              .child(div().w(30).flex_none().flex().justify_end().text_color(this.color(t, l.used)).child(`${Math.round(l.used)}%`))
              .child(div().w(44).flex_none().flex().justify_end().text_size(10.5).text_color(t.dim).child(l.left != null ? left(l.left) : ""))))));
      }));
  }
}
