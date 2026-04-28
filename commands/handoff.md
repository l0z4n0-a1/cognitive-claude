---
description: Create a session-handoff document so the next session starts with full context, not from scratch
allowed-tools: Read, Write, Glob
argument-hint: [optional notes]
---

# /handoff — Session Continuity Protocol

## Purpose

Capture session state at session boundary so the next session starts
with full context, not cold-start. Closes the temporal gap that
otherwise burns 5–15 turns of cognitive re-bootstrap (each turn paid
twice: once in attention, once in tokens).

This is the executable form of the ritual described in
[`docs/HANDBOOK.md`](../docs/HANDBOOK.md) §4 (session-close) and §5
(handoff between sessions).

## Why this matters for token economy

Without handoff: each new session cold-starts. ~10–30k tokens per
session re-paid in cognitive overhead — turns spent re-discovering
context, not producing new work. Invisible waste.

With handoff: next session starts at *"Continue from handoff"* → 1
turn loads state, then productive work resumes. **The handoff file
costs ~500 tokens to read; saves ~5,000–15,000 tokens of
re-orientation.**

Trust signal: if your boot-turn token count is consistently >10k for
projects you have worked on multiple times, your handoff is not
working. See HANDBOOK §5 for the full diagnostic.

## Generate handoff with: **$ARGUMENTS**

## Template

```markdown
# SESSION HANDOFF

**Date:** [timestamp]
**Session:** [project name + brief identifier]

## Where we are

[2–3 sentences. Project, current goal, last completed milestone.]

## Progress this session

- [x] Completed item 1
- [x] Completed item 2
- [ ] In progress: item 3 (state of completion + next move)

## Decisions made (with the trade-off accepted)

| Decision | Rationale | Alternatives ruled out |
|----------|-----------|----------------------|
| [decision] | [why] | [what we considered and rejected] |

## Files changed

| Path | Change | Why |
|------|--------|-----|
| [path] | [created/modified/deleted] | [reason] |

## What to skip on read-in (next session)

- [files Claude does NOT need to re-read; state already known]
- [patterns already established that are tax to re-explain]

## Immediate next step

[Exactly one specific action. If you can't write 1 specific action,
the handoff isn't ready.]

## Open questions

- [thing we don't know yet that should be answered before we proceed]

## Notes from $ARGUMENTS

[Extra context the operator passed in.]
```

## Save location

Default: `<workspace>/.session-state.md` — the convention used in
HANDBOOK §5 and protected by `.gitignore` so personal session state
does not leak into shared repos.

Archive (optional, for long-running projects): `<workspace>/.session-states/<YYYY-MM-DD>.md`.

## Rules

1. **Always handoff before `/clear`, before `/compact`, or at
   end-of-session.** Cost: ~90 seconds. Saves: 5–15 turns next
   session. Net positive on every measurement.
2. **Handoff is FOR YOU, not for showing off.** Be terse. Be
   specific. Include exact file paths and the exact next-step
   command.
3. **"Immediate next step" is mandatory.** If you can't write one
   concrete action, the handoff is incomplete and you have not
   actually understood where you left off.
4. **Decisions table > narrative.** Future-you will skim, not read.
   Tables are scannable; paragraphs are not.

## Anti-pattern

A handoff that says *"we made progress on X"* without listing exact
files and the exact next command is theater. Future-you needs to
*act*, not be impressed.

## How to use the handoff next session

Start your next session with:

> Continue from handoff. Read `.session-state.md`.

The model loads the entire state in one turn. Productive work
resumes on turn two.
