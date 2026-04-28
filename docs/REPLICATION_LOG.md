---
doc_type: replication-registry
audience: [skeptical-reader, prospective-replicator]
prerequisite: examples/case-study-2026-04-28/CASE_STUDY.md
authority: L4 (data, not normative)
data_provenance: external-operators-via-PR
---

# REPLICATION_LOG.md

This file documents operators who installed cognitive-claude and ran
`tools/cost-audit.py` on their own setups for 14+ days.

**Status as of v0.1: empty.** The author's own data is in `examples/case-study-2026-04-28/CASE_STUDY.md`.
This file exists to be populated by external operators via PR.

---

## Why this exists

The repo's headline numbers (91.63% cache hit, sub-agent ratio 71.76%, leverage
breakdown) are from a single operator. Any honest claim of "this transfers"
requires external replication. Without it, the architecture is one person's
discipline dressed as universal pattern.

The repo cannot conduct controlled experiments at scale. What it can do is
collect honest reports from operators who chose to adopt and measure.

---

## How to contribute

After running Phase 1 for at least 14 days:

1. Run `python3 tools/cost-audit.py --json --window 14 > my-report.json`
2. Open a PR adding a new entry below (template provided)
3. Anonymize as much as you want — only the structure matters

Template:

```yaml
- operator_id: "anon-NNN"        # or your handle
  date_range: "YYYY-MM-DD to YYYY-MM-DD"
  profile: "A | B | C | D | E"   # see docs/TRANSFER.md
  workload_intensity: "light | medium | heavy | very-heavy"
  phases_installed: [1, 2, 3]    # which phases were active
  metrics:
    cache_hit_rate: 0.XX
    subagent_ratio: 0.XX
    cache_breaks_per_session: NN
    tokens_per_turn: NNNN
  delta_from_baseline_pre_install:
    cache_hit_rate: "+X pp"      # if you measured pre-install
    boot_cost: "-X tokens"
  notes: "1-2 sentences max"
  divergence_from_author: "X pp on cache_hit_rate; Y pp on subagent_ratio"
```

## Entries

```yaml
# author's data (reference, sha256-pinned)
- operator_id: "l0z4n0-a1"
  date_range: "2026-01-29 to 2026-04-28"   # 90-day window per CASE_STUDY frontmatter
  profile: "A"                              # heavy Opus, solo, multi-project
  workload_intensity: "very-heavy"
  phases_installed: [1, 2, 3]
  metrics:                                  # canonical values from EVIDENCE.json sha256
    cache_hit_rate: 0.9163                  # 91.63%
    subagent_ratio: 0.7176                  # 71.76% turn-basis (filename-based)
    sessions: 987
    turns_total: 201910
    cost_per_turn_api_usd: 0.2098
    leverage_full_term: 84.72
  evidence_pack: examples/case-study-2026-04-28/EVIDENCE.json
  notes: "Author's own. Baseline for comparison, not for replication claim. Run cost-audit.py against your own data — see CASE_STUDY for the full forensic methodology including platform-incident attribution."
```

---

## Limits of this method

- **Self-selection bias.** People who report are people who succeeded.
  Failures are silent. Mitigation: explicitly invite negative results
  ("if your numbers got worse, please open an issue with that data too").
- **No baseline pre-install for most.** Without before/after on the same
  operator, attribution to the architecture vs. profile vs. random is impossible.
- **Adversarial submission.** Someone could fabricate data. Mitigation: for
  any claim cited externally (talks, posts), the author will reach out to the
  reporting operator to confirm. Anonymous data is informational only.

## What this log will NOT do

- Will not be aggregated into "average user gets Y leverage"
- Will not be used to claim "this is universal"
- Will not paywall or gate the repo behind metric thresholds
- Will not penalize divergent reports — divergence IS the data

## How to falsify the repo's universality claim

If 5+ operators across diverse profiles report cache_hit_rate < 80% after
14 days of Phase 2, the architecture's effectiveness on their workload class
is questionable. The author commits to documenting that finding in this file
and updating the README accordingly within 30 days of receiving the data.
