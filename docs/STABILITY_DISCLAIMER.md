---
doc_type: stability-contract
audience: [maintainer, future-replicator]
prerequisite: docs/MATH.md
authority: L4 (versioning honesty)
---

# STABILITY_DISCLAIMER.md

This repo derives claims from observable behaviors of Claude Code as it
existed at the time of measurement. Anthropic's tooling evolves. This
document is the contract about what stays true and what may not.

---

## Three categories of claims

### Category A — Anchored in published pricing

Claims that depend only on Anthropic's **published API pricing**:

- "Output tokens cost ~5x input tokens"
- "Cache read costs ~10x less than fresh input"
- "Cache write costs 1.25x fresh input, paid once"
- All dollar derivations in `docs/MATH.md` §2

**Stability:** High. Anthropic announces pricing changes; we update the math.
Last verified: 2026-04-28 against rates listed at `anthropic.com/pricing`.

### Category B — Anchored in documented platform behavior

Claims that depend on **publicly documented features** (prompt caching, hook
events, skill progressive disclosure, sub-agent semantics):

- "Prompt caching makes turns 2-N cheaper"
- "Skills lazy-load by default"
- "Hooks fire on lifecycle events"
- "Sub-agents have separate context"

**Stability:** Medium-high. Anthropic documents these. Behavior may evolve
across major versions; the *direction* of the claims should remain valid.
Last verified: 2026-04-28 against Claude Code documentation.

### Category C — Anchored in observed internal mechanics

Claims that depend on **source-verified internal details** (3-zone cache
hierarchy, 12 cache break triggers, fork vs. typed subagent cost asymmetry,
sticky header latches):

- Specific cache break costs (50-70k tokens)
- Specific zone assignment for system prompt vs. tools vs. messages
- Specific behavior of `enableAllProjectMcpServers` on cache strategy
- Specific cost asymmetry of typed-subagent (~12-15k creation minimum)

**Stability:** Low. These are implementation details of Claude Code itself.
They were captured at a specific point in time. Anthropic may change them
without notice. We pledge to:

1. **Date every Category-C derivation** in `docs/MATH.md` and `docs/INTERNALS.md`.
2. **Re-measure on each Claude Code minor version** before claiming continuity.
3. **Open issues for breaking changes** when our hooks or measurements
   diverge from prior baselines.
4. **Mark deprecated derivations** explicitly, not silently delete them.

---

## Versioning of claims

This repo will use semantic versioning where:

- **MAJOR** bump (1.x.0 → 2.0.0): Headline claims updated due to Category-C
  breakage that materially changes the architecture's effectiveness.
- **MINOR** bump (1.0.x → 1.1.0): New invariants, new tools, new docs.
- **PATCH** bump (1.0.0 → 1.0.1): Wording, fixes, replication entries.

[`CHANGELOG.md`](../CHANGELOG.md) tracks all of the above, with explicit
labeling of which category any change touches.

---

## What you sign up for

Adopting this repo means committing to:

1. **Re-running `tools/cost-audit.py`** after each Claude Code version bump
   to detect drift in your own metrics.
2. **Reading the CHANGELOG** before treating any prior derivation as still
   valid.
3. **Opening issues** when your numbers diverge from documented baselines —
   the divergence might be your workload, or might be Anthropic shipping
   something new that the repo hasn't caught yet. Either is data.

---

## What we do NOT promise

- We do NOT promise this repo will track Anthropic's tooling forever.
- We do NOT promise Category-C claims will stay accurate across major
  Claude Code releases without re-derivation.
- We do NOT promise to backport new mechanics into v0.1; new mechanics
  ship in new versions.

---

## EOL conditions (when this repo is officially obsolete)

This repo will be marked deprecated and archived under any of:

1. **Claude Code architecture pivot.** Anthropic ships a new harness
   that doesn't use the hooks API or the prompt-caching mechanism this
   repo derives from. The repo's primary mechanism becomes ahistorical.
2. **Author lifecycle.** Author commits to maintaining this for 24 months
   minimum from v0.1 publish (until 2028-04). After that, transfer to
   a maintainer or archive with a final state-of-the-mechanics document.
3. **Fundamental falsification.** If 5+ controlled experiments report
   the architecture-multiplier is ≤1.5x, the repo's central claim is
   falsified. Author commits to a public retraction document and archive.
4. **Anthropic-grade tooling supersedes.** If Anthropic ships native
   telemetry, audit, and governance tooling that makes this repo redundant,
   the repo points at the official tooling and archives.

We will not let this repo become a zombie. Either it works, or it is
gone with a clear note about why.

## How to falsify this disclaimer

If a Claude Code release silently changes a Category-C claim and the
repo does NOT publish a corresponding update or deprecation within 30
days of measurable change, this disclaimer has been violated. Open an
issue with the diff and the date.
