---
doc_type: longitudinal-architecture
audience: [adopter-30day-plus]
prerequisite: docs/RITUALS.md, docs/ARCHITECTURE.md
authority: L2
---

# AUTO_EVOLUTION.md — How the architecture gets smarter over time

A static architecture is a snapshot. A self-evolving architecture is a
process. This document describes how operators graduate from "running
the hooks" to "the system improving itself."

## The metabolic loop

```
   ┌──────────────────────────────────────────────────────┐
   │                                                      │
   │   KNOW   ←   read state                              │
   │     ↓                                                │
   │   PLAN   ←   decide next action                      │
   │     ↓                                                │
   │   DO     ←   execute / produce work                  │
   │     ↓                                                │
   │   OBSERVE ←  hooks log every tool call               │
   │     ↓                                                │
   │   LEARN  ←   distill pattern → memory file           │
   │     ↓                                                │
   │   KNOW (better) ──── close the loop                  │
   │                                                      │
   └──────────────────────────────────────────────────────┘
```

Without LEARN, every session restarts. With LEARN, each session begins
ahead of the last. **This is what makes the architecture compound.**

## Stages of adoption

### Stage 1 — Mechanic (weeks 1-2)
You install hooks. They run. You read cost-audit output once a week.
Numbers exist; you don't act on them yet. **This is fine.** The architecture
is not yet evolving; it is observing.

### Stage 2 — Reactive (weeks 3-6)
You start *responding* to numbers. Cache hit dropped → you check what
changed (CLAUDE.md edit? new MCP?). You make a small fix. **The loop
closes locally.** One observation, one action, one improvement.

### Stage 3 — Pattern-aware (months 2-3)
You notice patterns recurring across sessions. You start writing
`feedback_<topic>.md` files in your project memory directories. Each
file is a 1-2 line lesson with the session it came from. **You are now
producing data the future-you can read.**

### Stage 4 — Self-evolving (month 4+)
Every 30 days, you re-read your accumulated `feedback_*.md` files.
Patterns emerge that no single session would surface. You distill them
into your local CLAUDE.md (project-level, not global). **The architecture
is now writing itself.** Operations the model needs to remember are
codified; operations it doesn't are removed.

## Building your own META_LEARNINGS

The author's `docs/META_LEARNINGS.md` is one operator's distillate.
Yours will look different. Rules:

1. **Write feedback files immediately, not "later".** If a session taught
   you something, append 1 line to `<repo>/memory/feedback_<topic>.md`
   before /clear. Future-you forgets within 24 hours.
2. **Distill quarterly, not weekly.** Patterns need accumulation. 7 days
   of journals is anecdotes; 90 days is data.
3. **Filter for transferability.** A lesson that only applied once is
   trivia. A lesson that applied across 3+ unrelated incidents is a principle.
4. **Promote principles to CLAUDE.md only when they fail in 7+/10 turns
   without them.** Otherwise they are noise tax.

## Operational mechanics

### Per-session

- Run hooks (automatic).
- At session end, optionally append to `<repo>/memory/feedback_<topic>.md`:
  ```
  - [Lesson] (1 line) — context: <what triggered the lesson>
  ```

### Per-week

- Read cost-audit output. Note any drift.

### Per-month

- Read all feedback files added this month. Identify recurrences.
- If 3+ recurrences of same pattern: promote to CLAUDE.md as a rule.

### Per-quarter

- Full audit. Re-read CLAUDE.md aloud. Cut anything that hasn't fired.
- Compare your META_LEARNINGS evolution against author's
  `docs/META_LEARNINGS.md`. Diverged? That is your architecture.

## Why this matters more than the hooks

Hooks are static. They observe today the same way they observed yesterday.
They never get smarter.

Your *judgment* gets smarter — IF you write what you learn down. If you
don't, the architecture caps at "what I happened to remember at install
time."

The author's setup has 192 distilled meta-learnings from 89 sessions
because every session ended with feedback file writes. **That is the
self-evolving part.** The hooks are the substrate; the writing is the
intelligence.

## What this document is NOT

- Not a journaling cult. Operators who don't journal still benefit from
  hooks; they just plateau at Stage 1-2.
- Not a substitute for `docs/RITUALS.md` (which is the rhythm; this is
  the *what* of the rhythm).
- Not a guarantee of evolution. Many operators install hooks, never
  journal, and that is fine. They adopt the architecture as static.

## How to falsify

If you operate at Stage 4 for 90 days and your meta-learnings list does
NOT produce measurable improvement (cache hit drift, error rate trend,
session-cost trend), the loop is not load-bearing for your workload.
Stage 1-3 may be sufficient. Open an issue with your data.
