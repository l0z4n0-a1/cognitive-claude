---
doc_type: session-rhythm
audience: [installed-operator]
prerequisite: docs/RITUALS.md
authority: L2
---

# SESSION_LIFECYCLE.md — How sessions accumulate value

A session is not a discrete event. It is a node in a chain. The chain
either compounds (each session starts smarter) or resets (each session
starts at zero). The architecture below makes the chain compound.

## Pre-session (30 seconds)

1. Read last `HANDOFF.md` if present.
2. Glance at `~/.claude/cognitive-claude/last-boot-status.txt` (Boot/Grade/Health)
   if you have one (Phase 2+).
3. Decide: continue, branch, or reset (`/clear`).

## During session

- `cache-guard.sh` warns if you're about to break cache mid-session.
- `telemetry.sh` logs every tool call.
- Boot hook prints status.

## Post-session (90 seconds — CRITICAL)

1. Run `/handoff "1-line summary"`.
2. Glance at session-end output (delta, est vs real).
3. Optionally: append a 1-line meta-learning to `<repo>/memory/feedback_<topic>.md`.

## Why post-session is the load-bearing step

The Stop hook persists session delta. Without that, the calibration loop
(see `docs/ARCHITECTURE.md` §2.3) cannot close in v0.2. Post-session
discipline is what makes the architecture get smarter over time.

Skipping handoff once: harmless. Skipping habitually: every session
re-pays 5-15 turns of context re-bootstrap. Compounds badly.

## What this document is NOT

- Not a productivity ritual.
- Not "always handoff" dogma — short experimental sessions don't need it.
- Not a substitute for `docs/RITUALS.md` (different cadence, different purpose).
