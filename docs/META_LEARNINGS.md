---
doc_type: meta-learnings
audience: [operator, anthropic-engineer, anyone-running-claude-code-seriously]
prerequisite: README.md (and ideally examples/case-study-*/CASE_STUDY.md)
purpose: lessons that survive across operator profiles, harness updates, and platform incidents
---

# META_LEARNINGS.md — What real telemetry teaches

This document is the part of the project that survives ports across
harnesses. The hooks may break when Claude Code's API changes. The
Constitution may need editing as the LLM's reasoning evolves. The
metric definitions may sharpen.

The lessons below are durable because they are lessons about *how an
operator builds a feedback loop with an LLM*, not lessons about a
specific tool. Each one is generalizable; each one is grounded in
patterns that show up in any sufficiently-instrumented Claude Code
deployment. Concrete numbers in the case studies (`examples/`) are
illustrative — the lessons themselves do not depend on them.

Each lesson is presented in the format:

> **N. Headline.**
> Pattern (what happens in real telemetry).
> Mechanism (why it happens).
> Implication (what to do differently).
> Trust signal (which metric in `tools/cost-audit.py` would have flagged it).

---

### A note on these eleven

The eleven entries below overlap. Several are different operational
faces of the same underlying discipline (e.g., lesson 9 on hooks <
rules and lesson 8 on Constitution size both reduce to "shrink the
recurring tax"). They are presented separately because each frame
surfaces a different *trust signal* in the audit instrument — the
trust signal is what makes the lesson actionable.

Read them as patterns to *look for* in your own data. Not as
truths to adopt. If the pattern shows up in your telemetry, the
lesson applies; if not, it does not.

---

## 1. The most expensive cache hit rate in your data may be the buggy one.

**Pattern.** During the 2026-03-26 → 2026-04-10 Anthropic platform
incident (cache `clear_thinking` regression), affected operators saw
cache hit rate *rise* (often 85% → 95%+) while real cost-per-turn
*also* rose 2-3×. The natural reading "cache discipline improving"
was the opposite of what was happening. See
`examples/case-study-2026-04-28/` for one snapshot of this exact
inversion.

**Mechanism.** Cache hit rate is a *ratio*. Ratios can be moved by
either numerator or denominator. A bug that increases cache writes
*and* cache reads in lock-step looks identical to a bug-free system
with more cache traffic.

**Implication.** **Cache hit rate is a hygiene metric, not an
efficiency metric.** Use it to detect prefix drift (it falls when
prefix breaks) but do not use it as evidence of optimization. Pair
it with **$/turn**, which is a flow metric: it cannot be gamed by
ratios.

**Trust signal in the instrument.** `cost_per_turn_api_usd`. When
it rises sharply over a 7-day rolling window with no workflow
change, you are inside a regression — yours or platform's.

---

## 2. The platform itself is a noise source. Treat it like one.

**Pattern.** Three separate Anthropic-confirmed regressions hit
Claude Code in March-April 2026: lower default reasoning effort
(Mar 4), prompt-cache thinking-clear bug (Mar 26 → Apr 10),
verbosity-reducing system prompt (Apr 16-20). Without the official
[postmortem](https://www.anthropic.com/engineering/april-23-postmortem)
of 2026-04-23, affected operators would have spent weeks debugging
their own setup. This pattern recurs across LLM platforms — Anthropic
is the most transparent about it, but it is not unique to them.

**Mechanism.** Even rigorously-tested platforms ship regressions.
Anthropic admits it: "neither internal usage nor evals initially
reproduced the issues." If the vendor's own evals don't catch
production regressions, the operator's evals won't catch them either.

**Implication.** Treat platform-induced anomalies like any other
data anomaly. Three rules:

1. **Bookmark the postmortem URL.** Build a habit of cross-referencing
   your spike days with the vendor's incident log. The postmortem at
   <https://www.anthropic.com/engineering/april-23-postmortem> is a
   model of the genre.
2. **Always preserve the raw data.** `~/.claude/projects/*.jsonl` is
   your audit trail. Backup, don't delete.
3. **Report numbers as ranges, not points, during incident windows.**
   The case study in `examples/` shows both raw and bug-excluded
   baseline figures side-by-side. That is the honest framing — let
   the reader choose which to trust.

**Trust signal in the instrument.** `--verbose` shows 7d/30d/90d
side-by-side. When 7d and 30d disagree by >2× on $/turn, your
recent week is anomalous (yours, or platform's, or both). Investigate
before publishing claims.

---

## 3. Sub-agent delegation is the only token-economy move that scales.

**Pattern.** In a heavy-Opus operator profile with delegation
discipline in place, the cumulative cost in `agent-*.jsonl` files
(sub-agent contexts) typically rivals or exceeds the cumulative cost
of all main-thread projects combined. The operator's main thread
plateaus at a comfortable size; sub-agents absorb the volume that
would otherwise inflate it. Run `tools/cost-audit.py --by-project`
on your own data to see where this lands.

**Mechanism.** A sub-agent inherits a fresh ~12k-token system prompt
but does not pollute the parent's prefix cache. When the sub-agent
returns, its verbose context is discarded; main thread keeps a clean
cache that reuses across many turns. **The cost is paid once
(sub-agent spawn) and amortized across all subsequent main-thread
turns that reuse the unchanged prefix.**

**Implication.** Every Task() call you avoid by "just doing it
yourself in the main thread" inflates the prefix cache or breaks it.
Inverse-Pareto applies: 20% of your tasks deserve sub-agent dispatch
(retrieval, summarization, scoped exploration); the other 80% you do
inline. Get that 20% wrong (do them inline anyway) and your $/turn
doubles silently.

**Trust signal in the instrument.** `sub_share_pct_filename_based`.
Rule of thumb: under 30% on heavy-Opus workloads = you are
under-delegating. Operator profiles with mature delegation discipline
typically run 60-80% sub-share. That is what makes the leverage real.

---

## 4. Mean and median diverge when work is heavy-tailed. Always report both.

**Pattern.** A typical solo-multi-project operator's session-size
distribution is heavily right-skewed: median sessions are short
(~100-150 turns), but a small number of multi-thousand-turn
architecture sessions push the mean to 1.5-2× the median. Reporting
only the mean creates a false impression of "typical session size."

**Mechanism.** Operator workload is power-law: a small number of
multi-thousand-turn architecture sessions dominate the tail. Average
sessions are short. Reporting only mean creates a false impression of
"typical session size."

**Implication.** Use **median** for sizing assumptions ("how big is
my typical CLAUDE.md tax?"). Use **P95 or max** for capacity planning
("what is the worst case I need to fit?"). Reporting only mean is the
classic statistics trap that ends careers.

**Trust signal in the instrument.** `turns_per_session_median` vs
`turns_per_session_mean`. Gap > 2× means heavy-tail; mean is
misleading.

---

## 5. Concentration is the rule, not the exception. Plan for it.

**Pattern.** In a multi-project operator's audit, the top 5 projects
typically account for 80-90% of total cost. The long tail of smaller
projects shares the remainder. This is Pareto applied to LLM
workload — 10% of projects produce 90% of the spend.

**Mechanism.** Solo-multi-project operators do *deep work* on a few
streams and *quick context-switches* on many. The economics reflect
that.

**Implication.** Don't optimize uniformly across all your projects.
**Audit the top-5.** That is where the leverage compounds. The 50
small projects can run with default settings — total cost is
negligible. The top 5 deserve project-level CLAUDE.md, dedicated
hooks, careful sub-agent delegation patterns.

**Trust signal in the instrument.** Per-project breakdown
(implementation roadmap: `--by-project` flag in v0.2). For now, group
your JSONL files by project directory and run `cost-audit.py` per
directory.

---

## 6. The schema can change underneath you. Use stable identifiers.

**Pattern.** Around Claude Code v2.1.86 (week of 2026-03-23), the
`isSidechain` field semantics changed: pre-2.1.86 it was nearly always
`true`; post-2.1.86 it became a real main/sub discriminator. Building
metrics on `isSidechain` alone produced apparent "100% sub-agent share"
in the first 8 weeks of data — **not real**, just a schema artifact.

**Mechanism.** Tools evolve faster than instrumentation. Fields that
are convenient to use today may have meant something different 6
months ago.

**Implication.** **Prefer stable identifiers over convenient flags.**
The filename pattern `agent-*.jsonl` is stable across all observed
versions of Claude Code; we use it as the canonical signal for
sub-agent context. The `isSidechain` field is unreliable as a
historical metric.

**Trust signal in the instrument.** `sub_share_pct_filename_based` is
the only one published. The `isSidechain` field is read but not
trusted. Comment in the source code documents this.

---

## 7. Disable MCPs you do not actively use. Every week.

**Pattern.** The most aggressive operator profile this framework
serves runs **MCPs = 0** — not "low MCP usage," actually zero. Every
tool the operator might have wanted is implemented as a hook, a
skill, or a direct command.

**Mechanism.** An MCP server registers tool schemas that load eagerly
into the system prompt. Five medium MCPs ≈ 5,000 tokens × ~150 turns
× 150 sessions/month ≈ ~120M tokens of overhead per month, paid
whether or not those tools fire.

**Implication.** Re-evaluate every MCP weekly with the test:
*"In the last 7 days, did I actually use this?"* If no, disable.
Re-enable when needed. The prompt-cache will recover within one
session of stable use.

**Trust signal in the instrument.** Not directly measured by
`cost-audit.py` — this is a configuration check, not telemetry.
But: if your `cache_hit_rate` is sticky-low (<85%) and you have
MCPs, that is a strong correlation worth investigating.

---

## 8. The Constitution is the highest-leverage primitive. Every word costs N times.

**Pattern.** A 5,000-token CLAUDE.md across ~150 turns/session ≈
750,000 tokens of overhead per session. A 1,300-token CLAUDE.md
(this repo's default) reduces that to ~195,000 — a **3.85×
compression** on the most recurring tax.

**Mechanism.** The Constitution loads into every session's system
prompt and is paid as cache-read on every subsequent turn. Compounding:
fewer tokens in the prefix = smaller cache footprint = faster cache
warmup = more stable prefix across sessions.

**Implication.** **Treat CLAUDE.md as code.** Every line you add must
justify itself against the multiplication "N turns × M sessions × P
months." If it does not, it does not belong. The ~100-line Constitution
in this repo is the result of months of brutal removal.

**Trust signal in the instrument.** `wc -w ~/.claude/CLAUDE.md` (~1
token = 0.75 words, divide). If your Constitution is over 2k tokens
and you are not measurably outperforming your past self, audit what
each line earns.

---

## 9. Hooks are 10× cheaper than rules; rules are infinity× cheaper than ad-hoc.

**Pattern.** A heavily-used setup with the 6 hooks in this repo
executes them hundreds of thousands of times at zero context-token
cost. A single rule-without-glob in `.claude/rules/` would cost
~900 tokens per match × ~50 matches/session × hundreds of sessions
≈ tens of millions of tokens of overhead, *for the same enforcement*.
The cost differential is unbounded; pick the cheaper instrument.

**Mechanism.** Hooks run as bash subprocesses outside the LLM
context. The harness pays nothing in tokens for hook execution, only
hook latency (typically <100ms). Rules with globs are JIT-loaded
only on match. Rules without globs are eager-loaded into every
session.

**Implication.** When you can phrase enforcement as a binary
(block/allow/log), use a hook. When it's heuristic, use a rule with
a glob. Never write a rule without a glob unless it must apply to
every single turn — and even then, ask why it can't be in CLAUDE.md
where you can see it.

**Trust signal in the instrument.** No direct metric — this is
hygiene. But: if your `cache_hit_rate` keeps dropping after rule
additions, the rule is breaking cache continuity. Diagnose with
`git log` on `.claude/rules/`.

---

## 10. Telemetry without action is theater. Build the action loop first.

**Pattern.** The hooks in this repo log every tool call to
`~/.claude/telemetry/`. In a heavy-use deployment, that produces
~50-200 MB of structured data per quarter. Without a cost-audit
instrument and a weekly review ritual, all of it is noise.

**Mechanism.** Logging is cheap. Reading logs is cheap. Acting on
patterns in logs is the expensive part — and the part that matters.

**Implication.** Don't install telemetry hooks until you have a
weekly ritual to review the output. The audit instrument
(`cost-audit.py`) is one half of the loop; the other half is *you,
on a recurring calendar reminder, reading the output and asking
"what should I change this week?"*

**Trust signal in the instrument.** Run `cost-audit.py --verbose`
weekly. Compare the 7d window to the prior week. If anything shifted
>5%, find the cause. If you cannot, that is the actionable gap, not
the number itself.

---

## 11. Skin-in-the-game is the only proof. Show your work or stay quiet.

**Pattern.** Every lesson in this document is grounded in real
operator telemetry — not synthetic benchmarks, not "in our tests we
observed..." The original case study in
`examples/case-study-2026-04-28/` documents one operator's actual
90 days: real money paid, real tokens consumed, real artifacts
shipped, including being affected by an Anthropic platform incident
that the postmortem confirmed.

**Mechanism.** LLM-coding advice is currently dominated by influencers
with no logs. The signal-to-noise ratio is terrible. The only
reliable filter is: *did this person ship the audit trail along with
the claim?*

**Implication.** When you publish optimizations, publish the receipt.
When you cite numbers, cite the formula. When you make claims, run
the instrument that produced them and link the output. **The repo
that taught you something has a `tools/cost-audit.py` or equivalent.
The one that did not, did not.**

**Trust signal in the instrument.** Every claim in this repo is
re-derivable by running `tools/cost-audit.py` against the originating
operator's session logs. The case studies in `examples/` link their
JSON evidence packs. That's the test of skin-in-the-game.

---

## How these compound

These eleven lessons are not eleven independent insights. They
compound:

```
1. Trust $/turn over cache hit rate         ──┐
2. Treat platform incidents as data         ──┤
3. Maximize sub-agent share                 ──┤
                                              ├── observable via instrument
4. Always report mean AND median            ──┤
5. Audit top-5 projects, ignore tail        ──┤
6. Use stable identifiers (filename, not flag)─┤
7. Audit MCPs weekly                        ──┘

8. Constitution is highest leverage         ──┐
9. Hook < rule with glob < rule without     ──┤
                                              ├── visible in CLAUDE.md+settings.json
10. Telemetry needs an action loop          ──┘

11. Skin-in-the-game or stay quiet          ── (cultural; gates 1-10)
```

The first seven require an instrument (`tools/cost-audit.py`). The
next two require a mature configuration (`CLAUDE.md` + `settings.json`).
The tenth requires a habit (weekly review). The eleventh is the
threshold-of-publication.

If you are missing any of these, the others are weaker. The
architecture is the contribution; this is the meta-architecture.

---

*These lessons are what doing the work over months teaches any
operator who runs the system seriously. The lessons survive across
LLM versions and harness updates. The specific numbers in any
single case study will drift; the lessons will not.*
