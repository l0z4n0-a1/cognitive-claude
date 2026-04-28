---
doc_type: operating-rhythm
audience: [installed-operator]
prerequisite: docs/INSTALL.md (Phase 1+ active)
authority: L2 (closes the loop ARCHITECTURE.md prescribes)
---

# RITUALS.md — the operating rhythm

The closed-loop control diagram in `docs/ARCHITECTURE.md` §2.3 has four
states: PREDICT → EXECUTE → MEASURE → CALIBRATE → loop. **The loop only
closes if you operate it on a rhythm.** Without rhythm, the architecture
is theory.

This document codifies the minimum effective rhythm. Do less than this and
the loop is broken. Do more than this and you are over-instrumenting.

---

## Daily — 1 second

**Trigger:** Every session start.
**Action:** Glance at the boot status line printed by
`token-economy-boot.sh`. Format: `Boot:NNNNk Grade:X Health:Y Profile:Z`.
**Decision rule:** If Grade dropped from your usual baseline, note it but
do not act mid-session. Investigate at end of session if persistent.
**Effect:** Daily presence of awareness; no token cost.

---

## Weekly — 3 minutes

**Trigger:** Monday morning, or any session start where you have <5 minutes
of unloaded attention.
**Action:**
```bash
bash tools/cost-audit.sh --days 7
```

**Decision rule:**
- All 5 metrics within targets → continue normally
- 1 metric outside target → note in private journal; investigate next week
- 2+ metrics outside target → schedule a 30-minute audit session for the week

**What you are looking for:** trend changes, not absolute values. Numbers
themselves don't matter; their direction does.

---

## Bi-weekly — 90 seconds

**Trigger:** Every other Monday after the weekly audit.
**Action:** Re-run the 5 commands in `docs/SMELL_TESTS.md`. Compare verdict
columns to last bi-weekly run.
**Decision rule:**
- A test that was 🟢 turns 🟡 → mild signal; investigate next bi-weekly
- A test that was 🟡 turns 🔴 → action required this week
- A 🔴 stays 🔴 for 3 cycles → either the threshold is wrong for your
  profile (check `docs/TRANSFER.md`) or you need a deeper intervention
  (`docs/CASE_STUDY.md` for inspiration)

---

## Quarterly — 30 minutes

**Trigger:** Once per quarter, or after a major Claude Code version bump.
**Action:**
1. Read `~/.claude/CLAUDE.md` (your Constitution) end to end. Out loud, ideally.
2. Ask: "Is every line still load-bearing?" If not, archive (don't delete).
3. Run `bash tools/cost-audit.sh --days 90` for trend perspective.
4. Read `docs/STABILITY_DISCLAIMER.md`. Anthropic released
   new mechanics? Check whether your derivations still hold.

**Decision rule:** If Constitution drift exceeds 20% additions in a quarter,
something is wrong. Constitutions calcify; they should grow only on
deliberate decisions, not accumulation.

---

## Annual — 2 hours

**Trigger:** Once a year. Anniversary of your install is fine.
**Action:**
1. Pull `audit-history.jsonl` (if you saved it). Plot Boot cost over time.
2. Compare to your first month. Did the architecture stay lean or did it
   bloat?
3. Read your CLAUDE.md against the public `cognitive-claude/CLAUDE.md`.
   Diverged? Document why; that's your architecture, not theirs.
4. Open an issue or comment in `docs/REPLICATION_LOG.md` with anonymized
   summary of your year. The repo improves from your data.

---

## Sustainable use — when to relax the discipline

This architecture is engineered for *sustained* practice, not religious
observance. Signs you are over-applying:

- You read your boot status line and feel anxiety, not awareness.
- You refuse to edit CLAUDE.md mid-session even when the edit is correct
  for the current task.
- You count tokens in your head while writing prompts.
- You measure cache hit rate weekly but haven't shipped a feature in three weeks.

If any of those: you are operating *for* the architecture, not *with* it.
The architecture exists to make Claude Code cheap-and-effective so you can
forget about it. If it has become the foreground, take a week off the
audit cycle. Run normally. Ship something.

The Constitution permits flexibility (`L3 — Simplicity wins`,
`4.6 Context Hygiene`). Use it.

---

## What this document is NOT

- Not a productivity ritual. This is **architecture maintenance**, not personal
  growth.
- Not exhaustive. You will invent your own rhythms beyond this. Good.
- Not a guilt trip. Skipping a week does not break the architecture. Skipping
  a quarter starts to.

## How to falsify this document

If you operate on this rhythm for 3 months and your metrics show no
correlation with the rhythm (no improvement during ritual weeks, no
degradation during skipped weeks), the rhythm is theater for your profile.
Open an issue. The rhythm should be load-bearing or it should not be
recommended.
