---
description: Create handoff document for session continuity
allowed-tools: Read, Write, Glob
argument-hint: [optional notes]
---

# /handoff — Session Continuity Protocol

## Purpose
Create a complete state document at session boundary so the next session
starts with full context, not from scratch. Closes the temporal gap that
causes cache breaks + cognitive re-loading.

## Why this matters for token economy

Without handoff: each new session cold-starts. You spend 5-15 turns
re-establishing context with the model. Each of those turns is mostly
*re-discovery*, not *new work*. That is invisible token waste —
~10-30k tokens per session re-payed in cognitive overhead.

With handoff: next session starts at "Continue from handoff" → 1 turn
to load state, then productive work. Saves ~5-15 turns of re-bootstrap.

## Generate handoff with: **$ARGUMENTS**

## Template

```markdown
# SESSION HANDOFF

## Date: [timestamp]

## Context Summary
### What We Were Doing
[Main task/objective]

### Progress Made
- [x] Completed item 1
- [x] Completed item 2
- [ ] In progress: item 3

### Current State
- Active files: [list]
- Pending decisions: [list]
- Blockers: [if any]

## Key Information
### Discoveries
[Important things learned this session]

### Decisions Made
| Decision | Rationale |
|----------|-----------|

### Changed Files
| File | Change |
|------|--------|

## Next Session
### Immediate Next Step
[Exactly what to do first]

### Pending Tasks
1. [Task with context]
2. [Task with context]

### Questions to Resolve
- [Open question]

## Notes
[Additional context from $ARGUMENTS]
```

## Save location

- Primary: `<workspace>/HANDOFF.md`
- Archive: `<workspace>/handoffs/<date>.md`

## Rules

1. **Always handoff before /clear or end-of-session.** Cost: 90 seconds.
   Saves: 5-15 turns next session.
2. **Handoff is FOR YOU, not for showing off.** Be terse, be specific,
   include exact file paths and exact next-step command.
3. **"Immediate Next Step" is mandatory.** If you can't write 1 specific
   action, the handoff isn't ready.
4. **Decisions table > narrative.** Future-you will skim, not read.

## Anti-pattern

A handoff that says "we made progress on X" without listing exact files
+ exact next command is theater. Future-you needs to act, not be impressed.

## Tips for Next Session

Start with: "Continue from handoff"
