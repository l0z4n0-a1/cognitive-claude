---
doc_type: case-study
audience: [skeptical-reader, post-smell-test]
prerequisite: README.md
authority: L4 (illustrative; not normative)
data_provenance: author-personal-changelog-2026-04-07
n_observations: 1
---

# CASE_STUDY.md — One operator, one decision, audited

This is the story behind one specific intervention in this project's
history. Numbers are real and from the operator's local audit logs.
**N=1.** Reproducibility means anyone can run the same audit on
their own setup and compare *shape*, not magnitude.

---

## Context

In April 2026 the operator audited their own `~/.claude/` and found
context bloat that contradicted their own claims about discipline.
This document is what they did, what changed, what didn't.

**Pre-audit state:**
- Boot cost: 38,559 tokens (target for MEDIUM profile: <15,000)
- Skills installed: 54 (most never invoked)
- MCP servers in `permissions.allow`: 4 active
- Health score: 90/100
- Grade: C (FAIL on target)

---

## Intervention

Five concrete actions, applied in one session. **No file deleted** —
all archived under `~/.claude/archive/` with manifest, fully reversible.

| # | Action | Mechanism |
|---|---|---|
| 1 | Archive 36 skills with zero usage in 30d telemetry | move to `archive/skills/` |
| 2 | Remove 4 MCP entries from `permissions.allow` | manual edit, backup made |
| 3 | Remove duplicate `templates/` directory | move to archive |
| 4 | Add 8 universal-secret deny patterns to global `permissions.deny` | settings.json edit |
| 5 | Add `additionalDirectories` for shared workspaces | settings.json edit |

Backup created: `~/.claude/.backups/settings.json.bak.<timestamp>`

---

## Result

**Post-audit state (same machine, same operator, same workload):**

| Metric | Before | After | Δ |
|---|---|---|---|
| Boot cost | 38,559 tok | 30,899 tok | **−7,660 (−19.9%)** |
| Skills loaded | 54 | 18 | −36 |
| MCPs in allow | 4 | 0 | −4 |
| Health score | 90/100 | 95+/100 | +5 |
| Grade vs MEDIUM target | C (FAIL) | ~B | +1 |
| `D:/` permission prompts | intermittent | zero | — |
| Hot projects with project-level config | 0 | 5 | +5 |

**Projected token recovery (extrapolated to ~446 sessions/2 months):**
~3.4M tokens not paid.

> Why we report **token volume**, not dollars: the operator runs
> a flat-rate plan, so the financial impact is **plan-utilization**,
> not direct cost. Tokens recovered → more headroom for actual work
> before hitting cache pressure or compaction.

---

## What did NOT change (and why)

Some things the audit *suggested* changing that the operator
deliberately preserved:

- **`effortLevel`** — explicit personal preference, not default-recommended.
  Documented in private CHANGELOG; not for general adoption.
- **Specialized auxiliary skills** with zero count in `skills.log` —
  inspection revealed they are addressed by Bash directly from the
  orchestrator skill. Telemetry undercounted. Archiving would have
  broken the system.
- **Project memory directory (247 entries)** — audit flagged for prune;
  manual inspection confirmed all entries are operational knowledge.
  Pruning would have been regression, not optimization.

> **Lesson:** Audit data is necessary, not sufficient. Always inspect
> before archive. The score is a hint; the operator decides.

---

## How to measure on your setup

```bash
# 1. Run smell tests (no install needed)
#    See docs/SMELL_TESTS.md — copy 5 commands, paste in terminal.

# 2. Install Phase 1 (telemetry hook only). See docs/INSTALL.md.

# 3. Run for 14-30 days. Collect real numbers.

# 4. Run the audit:
bash tools/cost-audit.sh --days 30

# 5. Compare your shape to this case study. Magnitudes will differ;
#    shape (relative deltas) should be in the same direction if the
#    diagnosis applies to your profile.
```

---

## Honest limitations of this case study

1. **N=1.** One operator, one machine, one workload (heavy Opus,
   solo, multi-project). Generalization is hypothesized.
2. **Confounds.** During the same period the operator also adjusted
   working hours and tooling. Not all gains attributable to the
   audit alone.
3. **Selection bias.** This is the audit that *worked*. Audits that
   failed are not chronicled here. They exist.
4. **Telemetry undercount.** Skills called via Bash from other skills
   show zero usage. The audit had to be cross-checked with manual
   inspection — automated decision-making would have broken the
   system.
5. **Reversibility verified once.** Cross-platform reversibility
   not yet demonstrated.

---

## What this case study is NOT

- Not a promise that you will save 19.9% of boot.
- Not evidence that 36 skills was "too many" universally.
- Not a recommendation to disable all MCPs.
- Not a substitute for `docs/MATH.md` (the math is universal;
  this is one instance).

It is **one observation**. Run your own. Compare.

## How to falsify this case study

If you run a similar audit and your boot cost increases or metrics
degrade, **open an issue with before/after numbers and your
`~/.claude/` topology** (entity counts, not contents). The
intervention model gets refined from divergent data.
