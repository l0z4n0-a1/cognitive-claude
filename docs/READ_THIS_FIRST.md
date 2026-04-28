---
doc_type: gentle-introduction
audience: [first-time-visitor]
prerequisite: none
authority: L0 (orientation only)
reading_time: 90 seconds
---

# Read This First

You arrived at a repo that has 8+ docs, 5 hooks, 3 scripts, a Constitution,
and a falsifiability framework. That's a lot.

Here's the minimum you need to know.

## What this is, in plain English

Claude Code charges you for every word it sees, every turn. This repo
contains hooks (5 small bash files) that watch your usage, log it, and
warn you when you're doing things that waste tokens. Plus documentation
explaining why those hooks exist.

That's it. The rest is optional reading.

## Who it's for

Heavy Claude Code users who want measurement. If you use Claude Code
less than ~5 hours per week, this is overhead, not leverage.

## Who it's NOT for

- People looking for "5 prompt tricks"
- People who don't want any hook running on their tool calls
- People who haven't tried Claude Code yet
- Casual users who use Claude.ai web UI primarily

## What you should do, in order

1. **Run smell tests** (90 seconds, no install): copy 5 commands from
   `docs/SMELL_TESTS.md`, paste in your terminal. Decide if this repo
   solves a problem you actually have.
2. **If yes:** install Phase 1 (telemetry only, low risk). Run for 14 days.
3. **Re-evaluate:** is the data useful to you? If yes, install Phase 2.
   If no, uninstall (one command).

## Where to give up gracefully

If at any point this feels like too much process — stop. Read
`docs/ARCHITECTURE.md` for the principles, ignore the install. The
architecture was always more interesting than the implementation.

The principles transfer to any operator's setup. The hooks are one
realization of them.

## Where to go next

| Want to... | Read |
|---|---|
| Understand WHY before installing | `docs/ARCHITECTURE.md` |
| Run the smell tests | `docs/SMELL_TESTS.md` |
| See the math | `docs/MATH.md` |
| See the apparatus | `docs/INTERNALS.md` |
| See the value framework | `docs/VALUE_MODEL.md` |
| See an example intervention | `docs/CASE_STUDY.md` |
| Audit the hooks before installing | `SECURITY.md` + `hooks/*.sh` |
| Read the Constitution | `CLAUDE.md` |

That is the entire surface area. You do not need to read everything.

## What this is NOT

- Not a prerequisite for the rest of the docs.
- Not a marketing page.
- Not the whole story — just enough to decide if you want the whole story.
