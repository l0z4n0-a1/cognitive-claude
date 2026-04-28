---
doc_type: epistemic-confession
audience: [skeptical-reader, would-be-critic]
prerequisite: docs/MATH.md, docs/REPLICATION_LOG.md
authority: L4 (admission, not refutation)
---

# CONFOUNDS.md — what we cannot prove and why

## A note on this document's provenance

This document was written **after** the ~84x measurement, in response to
internal adversarial review (multi-pillar audit conducted 2026-04-28). It
is **not a pre-registration**. It is a post-hoc honesty pass.

Reader should weight accordingly: virtue signaled after the fact is less
credible than virtue baked in from the start. The author acknowledges
this and offers the document anyway, because no-CONFOUNDS would be worse
than post-hoc-CONFOUNDS.

This document exists because the strongest critique of this repo is the
hardest one to refute, and ignoring it would be intellectually dishonest.

The critique deserves to be stated as strongly as its strongest defender
would state it. Here it is.

---

## The strongest counter-argument

> *cognitive-claude is a single operator's discipline, presented as
> architecture. The ~84x leverage cited at the top is overwhelmingly the
> result of (a) being on the Max plan, and (b) being a heavy user — both of
> which exist independently of the seven invariants. The seven invariants
> are well-articulated and probably correct, but they are not the cause of
> the headline number. The repo conflates "I have a thoughtful setup" with
> "my setup is the cause of my outcomes." A heavy Max user with NO
> architecture optimizations would also see 25-35x leverage versus API rates
> — not ~84x, but in the same order of magnitude. The architecture-multiplier
> is real but smaller. The repo's framing inflates this multiplier into the
> entire phenomenon.*

This argument is mostly correct.

---

## What the repo CAN claim

1. **Architecture-multiplier exists.** Cache hit rate of 91.63%+ sustained
   over 90 days is observable, reproducible, and clearly higher than the
   ~50% baseline that an unoptimized session would produce. The shape of
   sub-agent ratio at 71.76% is consistent with the seven invariants being
   load-bearing. (See `docs/MATH.md` §3, §7.)

2. **Specific cost claims.** Cache breaks cost 50k+ tokens each. Five MCPs
   tax ~5k tokens/session. CLAUDE.md size scales the multiplier on every
   turn. These are derivable from Anthropic's published pricing and the
   author's measured token counts. (See `docs/MATH.md` §3-§9.)

3. **The seven invariants interlock.** Removing any one degrades the
   others observably (e.g., adding MCPs breaks global cache → cache hit
   rate drops → effective cost rises). This is testable; see
   `docs/HOW_TO_FALSIFY.md`.

## What the repo CANNOT claim

1. **~84x as architecture-only leverage.** It is plan × architecture.
   See `docs/MATH.md` §2 "Critical: Attribution of leverage" for the
   honest decomposition.

2. **Architecture-multiplier is universal.** N=1. Heavy Opus, solo,
   multi-project. Profile A in `docs/TRANSFER.md`. Generalization to
   Sonnet-default, Pro-plan, team, or casual profiles is hypothesized
   based on the principles being model-agnostic — but **not measured**.
   See `docs/REPLICATION_LOG.md` (currently empty).

3. **Causation over correlation.** The repo observes the 91.63% cache
   hit rate alongside the seven invariants. It cannot prove the invariants
   *caused* the rate without controlled A/B (which N=1 cannot conduct).
   The architecture is consistent with the data; it is not the only
   architecture that would be.

---

## Architecture-multiplier in isolation: refused

We refuse to give a numeric range. Here's why:

The arithmetic temptation is to say "~84x = plan_leverage × architecture_leverage,
plan_leverage ≈ 25-35x for heavy Max users, therefore architecture ≈ 5-8x."
But this division is **circular**: it uses the same ~84x measurement to
derive both factors, then claims they were independently estimated.

What we can say honestly:

1. Each individual mechanism — the CLAUDE.md tax, cache stability, sub-
   agent isolation — has a derivable per-turn cost in tokens. See
   `docs/MATH.md` §3 (CLAUDE.md tax), §6 (cache breaks), §7 (sub-agent).
   Those derivations don't depend on ~84×.
2. Each of the seven invariants in the README is independently testable
   via `docs/HOW_TO_FALSIFY.md`. Those tests don't depend on ~84× either.
3. The combined architecture-multiplier — what fraction of leverage
   is attributable to architecture vs. plan — **requires controlled
   experiment** (Max-user with vs without architecture, same workload,
   ≥30 days). N=1 cannot conduct that.

We commit to the following: if a credible third-party measurement
isolates the architecture-multiplier, we will publish their result in
`docs/REPLICATION_LOG.md` and revise this section. Until then, this
document refuses to invent a number that the data does not support.

---

## Why publish anyway

Three reasons:

1. **Honesty about confounds is itself the contribution.** Most "look at my
   savings" repos don't acknowledge what their numbers actually measure.
   This one does.

2. **Falsifiability framework is in place.** `docs/HOW_TO_FALSIFY.md`
   describes specific experiments any operator can run to test individual
   invariants. The architecture is structured to be refutable, not just
   validated.

3. **Replication invitation is real.** `docs/REPLICATION_LOG.md` accepts
   PRs from operators who measured their own setups. If 5+ operators report
   that this architecture moves their cache hit rate by less than 10
   percentage points, the author commits to updating the headline claims.

## What to do with this document

If you are about to install: read this AFTER `docs/MATH.md`. Decide
whether the per-mechanism savings (cache breaks avoided, sub-agent
delegation, model routing) are worth the install cost on your workload.

If you are about to dismiss the repo: this document conceded the strongest
form of your critique. The remaining question is: do the per-mechanism
gains exist *at all*, even if the aggregate "~84x" is misleading? Read
`docs/MATH.md` §6 (cache breaks) and §7 (sub-agent) and decide.

If you are about to cite the repo: cite the per-mechanism gains
(falsifiable, derivable), not the ~84x combined figure. Anything else is
overstating what the data supports.

## How to falsify this confession itself

If a controlled measurement shows the architecture-multiplier is ≤2x
on a comparable heavy workload, this entire document overstates the
repo's contribution and the README should be rewritten to reflect that.
The author commits to running such a measurement (or accepting one from
a credible third party) within 90 days of any rigorous claim of
architecture-multiplier ≤ 2x.

---

## Adjacent documents

- **`docs/LIMITATIONS.md`** §1 — the executive-summary version of this
  document's leverage-attribution argument. Read LIMITATIONS first if
  you are scanning; read this if you want the deeper concession.
- **`docs/HOW_TO_FALSIFY.md`** — the runnable experiments that test the
  per-invariant claims this document admits cannot be tested in
  aggregate.
- **`docs/REPLICATION_LOG.md`** — the registry where any operator
  conducting a controlled measurement can publish their result.
