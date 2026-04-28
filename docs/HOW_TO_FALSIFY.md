---
doc_type: falsification-protocol
audience: [skeptical-replicator, methodology-curious]
prerequisite: docs/CONFOUNDS.md, tools/cost-audit.sh
authority: L4 (experiment design, not result)
---

# HOW_TO_FALSIFY.md

> A theory that cannot be refuted is not science. — Popper

The seven invariants in `README.md` are presented as load-bearing. This
document provides specific, runnable experiments to test each invariant
on your own setup. If an invariant fails its falsification test on your
workload, that is data — open an issue.

Each test takes 14 days minimum (one cycle of cache state and habituation).

---

## Author has not yet run all 7 tests

Honesty: as of v0.1 publish, the author has informally validated tests
1, 5, and 7 against their own setup. Tests 2, 3, 4, and 6 are designed
experiments not yet executed. Author commits to running and reporting
all 7 within 60 days of v0.1, with results landing in this document.

Until then, treat the falsifiability framework as **specified, not
demonstrated**. The shape of the experiments is right; the data populating
them is incomplete.

---

## Invariant 1 — Persistent context is recurring tax

**Claim:** A 5,000-token CLAUDE.md across 159 turns processes 795,000
tokens (`docs/MATH.md` §3).

**Falsification test:**
1. Run `bash tools/cost-audit.sh --json --days 14 > before.json`
2. Triple your CLAUDE.md word count (add filler that does NOT change behavior)
3. Wait 14 days; run cost-audit again into `after.json`
4. Compare `tokens_per_turn`

**Pass:** `tokens_per_turn` rises proportionally to CLAUDE.md size.
**Fail:** No measurable change → caching is hiding the cost OR the claim
is overstated for your workload class.

**Note:** Restoring the original CLAUDE.md is required for the test to be
ethical to your future self.

---

## Invariant 2 — Cache stability dominates token volume

**Claim:** Cache breaks (>5k cache_creation_input_tokens per turn) cost
50k+ tokens each (`docs/MATH.md` §6).

**Falsification test:**
1. Run normal sessions for 14 days with `cache-guard.sh` ACTIVE.
   Record `cache_breaks_per_session` from cost-audit.
2. Disable `cache-guard.sh`. Edit CLAUDE.md mid-session 3-5 times/week.
   Record same metric for 14 days.
3. Compare.

**Pass:** Cache breaks rise; tokens_per_turn rises; cache_hit_rate falls.
**Fail:** No significant difference → either the guard wasn't catching
breaks or the breaks weren't costing what we claim on your workload.

---

## Invariant 3 — Cheapest instrument that solves wins

**Claim:** Hooks cost 0 tokens; rules without globs cost ~900 tokens each
(`docs/MATH.md` §5).

**Falsification test:**
1. Move one piece of behavioral guidance from CLAUDE.md to a `PreToolUse`
   hook. Verify behavior preserved.
2. Run cost-audit. CLAUDE.md token count should drop; nothing else changes
   adversely.
3. Reverse: move that hook content into CLAUDE.md as a rule. Verify behavior
   still preserved. Check cost-audit again.

**Pass:** Token count moves measurably between conditions; behavior identical.
**Fail:** Behavior breaks in hook form (instrument was wrong choice for that
content) OR cost difference is negligible (claim is overstated).

---

## Invariant 4 — Determinism beats LLM when answer is knowable

**Claim:** A bash one-liner replacing an LLM call saves ~12k tokens (typed
subagent system prompt minimum).

**Falsification test:**
Track for 14 days: every time you reach for `Task(...)` for a task that
has a deterministic answer (file count, regex extraction, JSON parse),
note whether the bash equivalent would have worked. If yes, that's a
12k+ token leak.

**Pass:** Pattern recurs. Discipline saves measurable tokens.
**Fail:** No such opportunities arise on your workload → invariant doesn't
apply to you (you may be a different profile).

---

## Invariant 5 — Sub-agent delegation preserves main-thread cache

**Claim:** Loading 50 files in main thread vs. via sub-agent: 100k vs ~1.5k
tokens persistent in main context.

**Falsification test:**
1. Pick a verbose retrieval task (e.g., "summarize 30 files in this directory")
2. Do it in main thread, with all reads visible. Record `tokens_per_turn` after.
3. Do an equivalent task via `Agent(Explore)`. Record `tokens_per_turn` after.
4. Compare main-thread `tokens_per_turn` post-task across the two conditions.

**Pass:** Sub-agent path keeps main-thread tokens stable; in-line path
inflates them by the file content.
**Fail:** No difference observable → either you have very small files OR
the cache mechanic is masking the savings on cost; check `cache_hit_rate`
both paths.

---

## Invariant 6 — Model routing must be explicit per agent class

**Claim:** Haiku is ~12-19x cheaper than Opus per token for retrieval-dominant
tasks (`docs/MATH.md` §8).

**Falsification test:**
For 14 days, track `tool-freq-*.log` and `agents.log`. Identify
retrieval-dominant calls (Explore, summarization, file search). Compute
the hypothetical cost if those had run on Haiku vs. their actual model.

**Pass:** Material savings are mathematically present.
**Fail:** All your agent calls were already on Haiku, OR none of your work
fits "retrieval-dominant" → invariant doesn't apply to your workload.

---

## Invariant 7 — Telemetry precedes optimization

**Claim:** Without telemetry, "optimization" is opinion.

**Falsification test (the meta-test):**
Disable `telemetry.sh` for 14 days. Continue using cognitive-claude.
After 14 days, ask: "Did I make any optimization decision in this period?
On what evidence?"

**Pass:** You couldn't answer with data → invariant validated for you.
**Fail:** You optimized confidently without telemetry → either you have
exceptional intuition, or you were deciding by feel (the invariant claims
the latter).

---

## What this document is NOT

- Not a checklist to tick before adopting.
- Not a substitute for `docs/MATH.md` (math) or `docs/CONFOUNDS.md` (limits).
- Not a guarantee that passing all 7 means the architecture is "true" — it
  means the invariants are individually falsifiable AND have not been falsified
  on the tested workload. That is the strongest scientific claim available.

## What this document IS

The author's commitment that **this architecture is structured to be wrong**
on workloads where it is wrong. If your tests fail, please open an issue.
The architecture improves only by being challenged from data.

## How to falsify this document

If 3+ operators run these tests honestly and report ≥4 invariants failing,
the architecture's claim of "interlocking seven invariants" is unsupported.
The author commits to revising the README accordingly.
