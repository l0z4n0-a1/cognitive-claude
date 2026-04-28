---
doc_type: operator-handbook
audience: [operator-day-1, operator-month-1, operator-coming-back-after-a-break]
prerequisite: README.md (or completed Phase 1)
purpose: the practical handbook for living with this system — the things that show up after install, in the daily work, that no other doc tells you
authority: L4 (extends but does not contradict CLAUDE.md or any L1/L2 doc)
register: field manual — austere, concrete, falsifiable, with one analogy per section
---

# 📖 HANDBOOK — Living with cognitive-claude

> *"The architecture is the contribution. The receipts are in `examples/`.
> The math is in `docs/MATH.md`. **This is the field manual.**"*

This is not the README. This is not the architecture spec. This is the
codex you read **after** you installed Phase 1, **after** you saw your
first telemetry numbers, **after** you stopped wondering if the framework
is real and started wondering how to actually live with it.

Nine other documents in this repo speak to nine other audiences. This
one speaks to **you, on day eight, with three sessions logged and a
question nobody else has answered yet**.

---

## 🗺️ Where this document fits

```
┌─ I want to know IF this is for me ─────►  README.md
├─ I want to INSTALL it ──────────────────►  INSTALL_PROMPT.md / docs/INSTALL.md
├─ I want to UNDERSTAND the design ───────►  docs/ARCHITECTURE.md
├─ I want to FALSIFY the numbers ─────────►  docs/MATH.md + LIMITATIONS.md
├─ I want to LIVE with it day-to-day ─────►  ✦ HANDBOOK.md (you are here)
├─ I want to DEEPEN over months ──────────►  docs/META_LEARNINGS.md
└─ I want to ADAPT for my profile ────────►  docs/TRANSFER.md
```

**The seven sections below are the seven things that change after you
install.** They are ordered chronologically by when they hit you —
day-one shifts first, month-one rituals last.

---

## 1. 🌅 Day one — what changes in your Claude

You install Phase 1, you start a new session. **Three things are different.**
Nothing else. The first week is just observation; behavior change comes
later (and only if you choose Phase 2 and 3).

```
BEFORE INSTALL                          AFTER PHASE 1
──────────────                          ─────────────
You start `claude`                      You start `claude`
                                          ↓
                                        Boot status line:
                                          Boot:19900tok Grade:C
                                          Health:96/100 Profile:MEDIUM
                                          ↑
                                          (this is your last
                                           session's numbers,
                                           computed at boot)

You work normally                       You work normally
                                          ↓
                                        Every tool call gets logged
                                        to ~/.claude/telemetry/
                                        (you don't see this happen;
                                         secrets are redacted before
                                         write — see SECURITY.md)

You close the session                   You close the session
                                          ↓
                                        Session-end hook persists
                                        the est-vs-real delta to
                                        bridge-history.jsonl
                                        (you don't see this either)
```

**Analogy.** The framework is the **flight data recorder**. Phase 1 is
turning it on. The plane flies the same way. You get to know what
happened after you land.

**Day-one move.** After your first 5 sessions, run:

```bash
python3 ~/cognitive-claude/tools/cost-audit.py --window 7 --verbose
```

You will see your real numbers. Five metrics. The ones in the README
header. **Now you know your baseline.** Decide Phase 2 from data, not
from hope.

> **Trust signal.** If `cost-audit.py` prints `error: no JSONL files
> under ~/.claude/projects` — you have not actually run any session
> since installing the hook. Run one. Come back.

---

## 2. 🧱 The 200k context wall

This is the single most important paragraph in this document.

**Claude Code's effective context window is 1 million tokens (Opus
4.7).** The hard ceiling is not where you hit a problem. **The problem
starts around 200k.**

```
TOKEN COUNT IN ACTIVE CONTEXT       WHAT YOU EXPERIENCE
──────────────────────────────      ───────────────────
       0 ──    50k                  Sharp. Fast. Coherent.
                                    This is the operating zone.

      50k ── 150k                   Still sharp. Cache hot.
                                    Most sessions live here.

     150k ── 200k                   Fine but you start paying.
                                    Cost-per-turn climbs as the
                                    prefix grows. No quality loss
                                    yet.

     200k ── 400k          ⚠️       Quality starts degrading.
                                    Recall drops. Long-range
                                    references get dropped.
                                    Hedging increases.
                                    Cost climbs sharper.

     400k ── 800k          ⚠️⚠️     You are paying frontier
                                    rates for non-frontier
                                    output. The model is in
                                    the room but it is tired.

     800k ── 1M            🛑       Hard ceiling approaches.
                                    Compaction becomes
                                    mandatory or quality
                                    collapses.
```

**Analogy.** Context is **working memory, not long-term memory**. A
human can hold 7±2 things in working memory; an LLM can hold a million
tokens, but the *quality* of holding them degrades long before the
ceiling. Imagine someone trying to keep 30 phone numbers in their head:
technically possible, but they will start swapping digits.

### The four operating moves

| Move | When to use | Cost |
|---|---|---|
| **Just keep going** | Under 100k, task is coherent | Free |
| **`/compact`** | At 150k–200k, you want to keep most of the thread but compress | Free for cache, the LLM summarizes itself; minor recall loss |
| **`/clear`** | New independent task | Free, brutal — discards in-memory context but preserves the persistent prefix cache |
| **Close session, start new** | End of day, end of feature, after a major divergence | Free, cleanest possible state |

**The mistake nobody warns you about.** Operators ride context to 400k
"because it's still working" and then wonder why the same kind of task
that took 8 turns yesterday now takes 22. **The model isn't tired. The
context is.** Trust the wall.

> **Trust signal.** Run `python3 tools/cost-audit.py --charts` weekly.
> Look at the daily $/turn line. If it climbs without a corresponding
> increase in task complexity, you are riding context too long. The
> wall is not a metaphor; it is in your data.

**Field rule.** **Below 200k or `/compact`. Above 200k means you are
paying for cognitive decline.**

---

## 3. 🚀 The boot ritual — first 30 seconds

The boot hook prints one line at session start:

```
Boot:19900tok Grade:C Health:96/100 Profile:MEDIUM
```

**Read it. Every time. It takes 3 seconds.**

```
Boot:19900tok    ← persistent prefix size from last session
Grade:C          ← cache hit rate letter (A=90%+, B=85+, C=75+, D=60+, F=below)
Health:96/100    ← composite indicator (cache hit rate, scaled 0-100)
Profile:MEDIUM   ← turn volume (LIGHT<1k, MEDIUM<5k, HEAVY>5k weekly)
```

### What each grade means in practice

| Grade | What it tells you | What to do |
|---|---|---|
| **🟢 A** (90%+) | Cache discipline is strong. Prefix is stable. | Keep doing what you're doing. |
| **🟡 B** (85–90%) | Healthy. Small drift. | Note it. If it persists 3 boots, audit recent CLAUDE.md edits. |
| **🟠 C** (75–85%) | Drift. Something changed in the prefix. | Run `cost-audit.py --window 7`. Look at recent days. |
| **🔴 D-F** (below 75%) | Cache is fighting you. | **Pause.** Did you edit CLAUDE.md? Toggle MCP? Switch model mid-session yesterday? Diagnose before working. |

**Analogy.** This is the **morning weather report before you go sailing**.
Three seconds tells you whether today is sail-anywhere or
hug-the-coast. Skipping it is fine on a sunny day. Skipping it during
a storm is how boats get lost.

### When the boot status looks wrong

If you see `?` in any field — the audit instrument couldn't find your
data. Three causes, in order of likelihood:

1. You cloned to a non-canonical path. Export `COGNITIVE_CLAUDE_HOME`
   in your shell rc:
   ```bash
   export COGNITIVE_CLAUDE_HOME="$HOME/path/to/cognitive-claude"
   ```
2. You haven't run any session yet (telemetry is empty). Work for 30
   minutes, restart Claude.
3. The instrument is missing or broken. Run
   `python3 ~/cognitive-claude/tools/cost-audit.py --window 7` directly
   and read the error.

**Field rule.** **3 seconds of attention at boot saves 20 minutes of
diagnosis at hour two.**

---

## 4. 🌑 The session-close ritual — extracting meta-learnings

This is where most operators leave value on the table. The session ends.
You close the terminal. The hook persists the est-vs-real delta to
`bridge-history.jsonl`. **But the meta-learnings — the actual
intelligence about what happened in this session — vanish into the void.**

The session-close ritual is the discipline of capturing them before they vanish.

### What gets captured

```
┌────────────────────────────────────────────────┐
│ SESSION-CLOSE META-EXTRACTION                  │
│                                                │
│  ┌─ FRICTIONS ─────────────────────────────┐   │
│  │ • Where did I have to repeat myself?    │   │
│  │ • Where did Claude go in circles?       │   │
│  │ • What ate tokens for no value?         │   │
│  └─────────────────────────────────────────┘   │
│                                                │
│  ┌─ DECISIONS WORTH KEEPING ───────────────┐   │
│  │ • Architectural calls made today        │   │
│  │ • Trade-offs accepted                   │   │
│  │ • Things ruled out (and why)            │   │
│  └─────────────────────────────────────────┘   │
│                                                │
│  ┌─ NEXT-SESSION PROMPT ───────────────────┐   │
│  │ • One paragraph: "where I left off,     │   │
│  │   what's the next move, what to skip"   │   │
│  └─────────────────────────────────────────┘   │
│                                                │
│  ┌─ STATE UPDATES ─────────────────────────┐   │
│  │ • Files changed                         │   │
│  │ • Decisions to remember                 │   │
│  │ • Open questions for tomorrow           │   │
│  └─────────────────────────────────────────┘   │
│                                                │
└────────────────────────────────────────────────┘
              │
              ▼
   Persist to a project-local file
   (e.g., .session-state.md or whatever
    convention works for your stack)
```

### How to do it manually today (5 minutes)

Before you close the session, run **one prompt**:

> "Audit this session for me. Three buckets:
> (1) frictions — where did we go in circles, where did I have to
> repeat myself, where did tokens get wasted on dead ends;
> (2) decisions worth keeping — what did we decide today that future-me
> needs to know;
> (3) next move — write me a one-paragraph prompt I can paste at the
> start of the next session to pick up where we left off, including
> what to skip. Be honest about what didn't work."

Save the output to `.session-state.md` (or any convention you adopt) in
the project root.

**Analogy.** This is the **end-of-day field journal**. Generals didn't
trust their morning memory; they wrote the day's lessons before sleep.
Without the journal, every campaign restarts from scratch.

### What v0.2 will add

A `session-close` skill that automates the three-bucket extraction,
appends to `bridge-history.jsonl`, and writes the next-session prompt to
a known path. **The ritual is the algorithm. The skill will be the
algorithm running by itself.** Practicing it manually now means you
will know what the skill is doing when it ships — not cargo-cult, but
internalization.

> **Trust signal.** If after 2 weeks you have zero `.session-state.md`
> files saved, you are not running this ritual. The framework's
> calibration loop is telemetry-only without it; with it, you are
> compounding human-readable intelligence on top of the numerical
> calibration.

**Field rule.** **The session that captures its own lessons is worth
1.5× the session that just ends.**

---

## 5. 🔄 The handoff between sessions — persistence beyond the window

Every session is amnesiac by default. Claude doesn't remember yesterday.
The 200k wall is also a 200k *forgetting*. Without a handoff discipline,
every session restarts from raw context and burns tokens explaining what
should already be known.

### The handoff payload

A good handoff is **three artifacts, no more**:

```markdown
<!-- .session-state.md (or your equivalent) -->

# Where we are
[2-3 sentences: project, current goal, last completed milestone]

# What was decided in the last 3 sessions
- [decision 1, with the trade-off accepted]
- [decision 2]
- [decision 3]

# What to skip on read-in
- [files Claude does NOT need to re-read this session]
- [patterns already established that are tax to re-explain]

# What's next
[1 sentence: the literal next move]

# Open questions
- [thing we don't know yet]
```

**The next session starts with one move:** paste this file at the top
of your first prompt. **Cost: ~500 tokens. Saved: ~5,000 tokens of
re-orientation.** 10× ROI on every session.

### The fractal nature of handoff

Handoff works at three scales:

| Scale | Artifact | Lifetime |
|---|---|---|
| **Within-session** | `/compact` keeps essence, drops noise | minutes |
| **Session-to-session** | `.session-state.md` (or equivalent) | days |
| **Project-to-project** | `CLAUDE.md` at project root, with the handoff convention referenced | months |

**Analogy.** Memory in this system works like **archaeological strata**.
Active context is the surface. Session-state files are last week's
sediment. Project CLAUDE.md is the bedrock. Each layer is cheaper to
read than the layer above. **Don't make the next session dig through
surface dirt to find bedrock.**

> **Trust signal.** If your average session-1-tokens (the boot turn) is
> > 10k for projects you have worked on multiple times, your handoff
> is not working. Boot turn should drop after the first few sessions on
> a project, as you formalize what to skip.

**Field rule.** **A handoff file is the smallest thing that turns
N sessions into 1 conversation.**

---

## 6. 🛠️ The seven trenches — frictions you will hit, and the move

These are the seven situations where the discipline pays off — or where
you will pay for not having it. Each one is real. Each one has happened
to operators who shipped this framework. Each has a specific move.

---

### Trench 1 — *"It's just one line in CLAUDE.md"*

**The friction.** You're mid-session. You realize a Constitution line
should be slightly different. You open it. You change it. Save.
Continue.

**What just happened.** The cache-guard hook printed a warning. You
ignored it. The persistent prefix cache invalidated. Your next turn
re-processed 50,000 tokens at fresh-input rates.

**Cost.** $0.75 at Opus rates. For one line.

**The move.** Open a separate scratch file. Write the change there.
**At end of session**, paste it into CLAUDE.md and let the next session
re-cache cleanly. **Batch all CLAUDE.md edits to between sessions.**

**Analogy.** Editing CLAUDE.md mid-session is like **changing the
foundation of a house while the family is having dinner inside**. Yes,
you can. The dinner will not be the same.

---

### Trench 2 — *"This task feels too big for the model"*

**The friction.** You're 3 hours in. Quality is dropping. The model is
hedging. You think the task is too hard.

**What's actually happening.** Context is at 350k. The task isn't too
hard; the model is full.

**The move.** `/compact` or `/clear` and split the task. If the task
genuinely needs continuity, run `/compact`, summarize what you have so
far, save to `.session-state.md`, restart fresh.

**Anti-pattern.** Adding more explanation in the same overloaded
context. **You are pouring water into a full glass.** It just spills.

---

### Trench 3 — *"I'll just install one more MCP, this one looks useful"*

**The friction.** Every MCP looks useful. You install five. Your boot
prefix is now 30,000 tokens of MCP schemas you call once a week.

**What just happened.** Your sessions are paying ~$0.045/turn extra in
cache-read fees, plus ~$0.45/turn on cache breaks, for tools you don't
use.

**The move.** **The 7-day no-call test.** Once a week, ask yourself:
"Did I actually invoke this MCP's tools in the last 7 days?" If no —
disable. You can re-enable in 30 seconds. Schemas don't get rusty.

**Field rule.** **MCPs you don't call are taxes you pay.**

---

### Trench 4 — *"Claude is going in circles"*

**The friction.** Same answer, three different framings, no progress.
You feel like Claude isn't listening.

**What's actually happening.** **Two failures with the same approach
mean change strategy, not parameters.** This is a Constitution Law
(L4.5 / Anti-Loop). Claude is following your instruction; the
instruction is the loop.

**The move.** Stop. Don't reword the prompt. Ask Claude **explicitly**:
"What's the assumption we're both making that's wrong?" Force a
re-frame, not a re-try.

**Analogy.** When the lock won't turn, you don't push the key harder —
you check whether it's the right key.

---

### Trench 5 — *"My cache hit rate jumped to 95% — I'm winning"*

**The friction.** You see your cache hit rate go up. You celebrate. The
next bill comes; cost per turn tripled.

**What's actually happening.** This is the **2026 cache regression
pattern**, documented in `examples/case-study-2026-04-28/CASE_STUDY.md`
§7. During an Anthropic platform incident, cache hit rate **rose**
while real cost-per-turn **also rose** because the bug inflated cache
writes in the denominator.

**The move.** **Trust $/turn over cache hit rate.** Cache hit rate is
a ratio; ratios can be moved by either term. $/turn is a flow metric;
it cannot be gamed. When they disagree, $/turn wins.

**Field rule.** During incident windows: $/turn is the truth. Cache
hit rate is the rumor.

---

### Trench 6 — *"I'm going to add a rule for this pattern"*

**The friction.** A coding pattern keeps coming up. You're tempted to
add a rule file with the pattern, in case Claude needs it.

**What just happened (if you write it without `globs:`).** You added
~930 tokens of permanent tax to every session. The token-economy-guard
hook should have warned you.

**The move.** **Decide before writing.**

```
Is the rule a binary decision (block/allow/log)?
├─ YES → Hook (zero context tokens)
└─ NO  → Does it fire more than once per session?
         ├─ YES → Rule with `globs:` frontmatter (zero unless matched)
         └─ NO  → Don't write it. Use it once and move on.
```

**Anti-pattern.** "Just-in-case" rules. The cost is permanent; the
benefit is occasional.

---

### Trench 7 — *"I'll fix this 'small' permission/setting/model thing now"*

**The friction.** You're mid-session. You want to add a permission, or
toggle a setting, or switch model "just for this task". You do it.

**What just happened.** Cache break. Same mechanism as Trench 1.
Different cause, same loss. 20k–70k tokens, depending on how deep your
session was.

**The move.** **Pre-session window.** Make all configuration changes
before you `claude`, never during. Keep a sticky note (or
`.session-todo.md`) of "things to change before next session". Batch
them. Eat the cost once.

**Field rule.** **The cheapest cache break is the one you batched into
a session boundary.**

---

## 7. 🌳 What "good" looks like at 30 days

After 30 days of running this system, here is the shape of "good".
Compare your numbers honestly. **Numbers below are targets for the
heavy-Opus operator profile**; if you are in another profile, see
`docs/TRANSFER.md` for adjusted targets.

```
                                                    HEALTHY    AUDIT IF
                                                    ────────   ────────
Boot status grade (last 14 days)                    A or B     C or worse 3+ days
Cache hit rate (90-day)                             ≥ 90%      < 85% sustained
Cost per turn (90-day, API-equiv)                   trend flat trending up >10%/wk
Sub-agent turn-share (post-W13 stable)              ≥ 30%      < 15%
Boot turn token size                                  decline    rising
  on returning projects                              over time  over time
Sessions/week with .session-state.md saved          ≥ 50%      < 20%
CLAUDE.md edits in last 30 days                     1-2        more than 5
Times you ignored a cache-guard warning             0-1        > 3
```

### The 30-day diagnostic command

```bash
python3 ~/cognitive-claude/tools/cost-audit.py --verbose --charts
```

Read three things in the output:

1. **The 30d window** — is your $/turn flat or trending?
2. **The cache hit rate** — is it ≥ 90% or has it slipped?
3. **The daily timeseries chart** — are there spikes that don't
   correspond to known platform incidents?

If all three look good, **you don't need to do anything**. The system
is doing its job. Keep operating.

If any one looks bad, the **other six trenches** above are the
diagnostic checklist. Walk them in order.

**Analogy.** This is the **annual physical**. You don't optimize during
the exam; you take readings and trust the trends. Most of the time,
"healthy" is the answer and the right move is to go back to work.

---

## 📜 Appendix — The 9 Laws in human words

The Constitution (`CLAUDE.md`) states the Laws as instruction. This
appendix states what they **feel like** in daily practice.

| # | Law (formal) | What it feels like (practical) |
|---|---|---|
| **L1** | Observe before acting | Read the file before you change it. Run the test before you assume it passes. |
| **L2** | Execute and verify | If you wrote it, run it. If it ran, check the output. Don't trust your own draft. |
| **L3** | Simplicity wins | Three similar lines beat one clever abstraction. If you can't explain it in a sentence, simplify it. |
| **L4** | Declare uncertainty | "I think" beats "definitely" when you only think. The number 60% is information; "high confidence" is decoration. |
| **L5** | Partial declared > complete fabricated | 70% real with the gap stated wins against 100% with silent gaps. Always. |
| **L6** | Act on intent, not just instruction | When the literal instruction misses the goal, follow the goal and flag the gap. |
| **L7** | Cheapest instrument that solves | Hook before rule before CLAUDE.md before skill before agent. Going up the cost ladder requires a reason. |
| **L8** | Determinism over generation | A regex beats an LLM call for any task with a right answer. Save the LLM for judgment. |
| **L9** | Every boundary declares its contract | If you can't say what enters and what leaves, the boundary isn't real and the work isn't auditable. |

These nine compound. Violating one weakens the others. Following them
is not a checklist — it is a **way of working** that, after a few
weeks, becomes invisible.

---

## 🌅 The one paragraph version

If you read nothing else: **install Phase 1, look at the boot status
every morning, batch CLAUDE.md edits between sessions, run the
session-close ritual once a day, save your `.session-state.md`, trust
$/turn over cache hit rate, and stay below 200k context.** Everything
else in this document is detail on those seven moves. Everything else
in the repo is the math, the receipts, and the falsifiability of the
seven moves.

---

## 🧭 Where to go from here

| You finished this and you want to... | Read |
|---|---|
| See an operator's actual 90-day data | `examples/case-study-2026-04-28/CASE_STUDY.md` |
| Understand the design rationale | `docs/ARCHITECTURE.md` |
| Verify the math on your own data | `python3 tools/cost-audit.py --evidence` |
| Find the strongest counter-arguments | `docs/LIMITATIONS.md` |
| Adapt for a non-heavy-Opus profile | `docs/TRANSFER.md` |
| Go deeper on the lessons | `docs/META_LEARNINGS.md` |
| Audit the contract enforcement | `docs/INVARIANTS.md` |

---

*This handbook documents the practice that emerges from running the
system. The eleven lessons in `META_LEARNINGS.md` are what those
practices teach over months. The handbook is for the day; the
meta-learnings are for the year.*

*Practice the day. The year takes care of itself.*
