---
doc_type: invariants-reference
audience: [operator, llm-orchestrator, reviewer]
prerequisite: ../README.md
authority: L1 reference (extends but does not contradict CLAUDE.md)
purpose: single-page cross-reference between Constitution Laws, MATH derivations, hook enforcement, and the audit instrument's verification
---

# INVARIANTS.md

The seven invariants in `README.md` and the nine Laws in `CLAUDE.md`
are not separate frameworks. They are the same discipline expressed
at three resolutions:

- **Stated** in the Constitution (`CLAUDE.md`)
- **Derived** in the math (`docs/MATH.md`)
- **Enforced** by hooks or **verified** by the audit instrument
  (`tools/cost-audit.py --invariants`)

If any invariant fails to round-trip across those three layers, that
is a bug. This document is the index that makes the round-trip
auditable.

---

## Section 0 — How to read this table

Each row below traces one invariant from principle (Constitution) to
formula (MATH) to mechanism (hooks/tools). The mechanism column tells
you **where the invariant is enforced** (a hook that warns or blocks)
or **how the invariant is verified** (a metric the instrument
computes against your own logs).

| Symbol | Meaning |
|--------|---------|
| **C-Lx** | Constitution Law x (`CLAUDE.md` §2) |
| **M-§n** | `docs/MATH.md` Section n |
| **A-§n** | `docs/ARCHITECTURE.md` Section n |
| **H-name** | hook at `hooks/name.sh` |
| **T-flag** | flag of `tools/cost-audit.py` |

A **load-bearing** invariant is one whose violation invalidates
downstream claims. Load-bearing invariants get a hook *and* an
audit-instrument verification — belt and suspenders.

---

## Section 1 — The nine invariants

| # | Invariant (one line) | Stated | Derived | Enforced / Verified | Load-bearing |
|---|---|---|---|---|---|
| 1 | **Observe before acting** — read real state before writing; minimum 2:1 read:write ratio | C-L1 | A-§2.1 (the hidden tax: assertions on stale prefix are charged anyway) | T-`--invariants` checks tools-log read:write ratio per session | yes |
| 2 | **Execute and verify** — if you wrote, run; if it ran, check | C-L2 | n/a (operational, not numerical) | n/a — operator discipline; tested by case-study reproducibility | no |
| 3 | **Simplicity wins** — three similar lines beat one premature abstraction | C-L3 | M-§3 (CLAUDE.md tax math: every line of prefix is paid every turn × N sessions) | H-`token-economy-guard` warns on rule files without `globs:` (~930 tok permanent tax) | yes |
| 4 | **Declare uncertainty** — confidence stated explicitly before factual claims | C-L4 | n/a (epistemic, not numerical) | n/a — operator discipline | no |
| 5 | **Partial declared > complete fabricated** | C-L5 | n/a | LIMITATIONS.md is the artifact-level expression of this | no |
| 6 | **Act on intent, not just instruction** | C-L6 | n/a | n/a — operator discipline | no |
| 7 | **Cheapest instrument that solves** — hook < rule < CLAUDE.md < skill < agent | C-L7 | M-§5 (hook vs rule math: hook=0 tok, rule=~900 tok per fire), M-§9 (lazy skill math: 80% saving) | A-§4.1 decision tree; H-`token-economy-guard` redirects rule→hook | yes |
| 8 | **Determinism over generation when answer is knowable** | C-L8 | M-§5 (rule vs hook), M-§8 (model routing: 18.75× ratio Opus/Haiku for retrieval) | A-§4.3 decision tree; T-`--by-project` exposes model-routing share | yes |
| 9 | **Every boundary declares its contract** — no module, hook, or output crosses a boundary without an input/output schema and a failure mode | C-L9 (added v0.1.1) | M-§0 canonical definitions; M-§10 reproducibility statement | T-`--invariants` checks all five canonical metrics resolve and lie in valid ranges | yes |

The final row (L9) is the load-bearing invariant the others depend
on: without explicit contracts, no enforcement is auditable, no
metric is verifiable, no claim is falsifiable.

---

## Section 2 — The five canonical metric contracts

These are the contracts L9 protects. Every published number in this
repo is derivable from these five definitions. Any number that
violates the listed range is either a bug in the instrument or
corruption in the source data.

| Metric | Formula | Valid range | Fails L9 if | Verification |
|---|---|---|---|---|
| **cache hit rate** | `cache_read / (cache_read + input + cache_write)` | `[0.0, 1.0]` | denominator includes/excludes terms not listed in M-§0 | T-`--invariants` |
| **sub-agent work share** | `agent_turns / total_turns` (filename-based) | `[0.0, 1.0]` | uses `isSidechain` flag instead of filename pattern | T-`--invariants` |
| **API-equivalent cost** | `Σ (tokens × per-model-price)` over window | `≥ 0.0` | per-model price not pinned to PRICING table in M-§1 | T-`--invariants` |
| **cost per turn** | `window_cost / window_turns` | `≥ 0.0` | denominator counts turns from outside window | T-`--invariants` |
| **leverage** | `window_cost / plan_paid_total` | `≥ 0.0` | computed across mismatched windows (cost 90d vs plan 30d) | T-`--invariants` |

The instrument will **exit non-zero** on any contract violation when
invoked with `--invariants`. This is the closed-loop guard against
silent metric drift.

---

## Section 3 — The three governance fronteires

The L0–L5 tier model in `ARCHITECTURE.md` §3.7 defines who-may-edit-
what. Three boundaries inside that model are load-bearing for the
framework to remain coherent:

### 3.1 Global ↔ Project (L1 ↔ L4)

**Rule.** Project-level `CLAUDE.md` extends but never contradicts the
global Constitution.

**Why.** A project that contradicts the global cannot inherit the
global's discipline; the operator now runs two competing constitutions
and any claim about "I run what I publish" becomes false at the
project boundary.

**Enforcement.** `hooks/tier-contradiction-guard.sh` (added v0.1.1)
warns on project-`CLAUDE.md` Writes whose content includes language
the global explicitly negates. Heuristic, warn-only, never blocks.

### 3.2 Persistent prefix ↔ Mid-session edit (L1/L2 ↔ L5)

**Rule.** Edits to anything in the persistent prefix (Constitution,
permissions, hooks, MCP toggles, model swap) cost 20–70k tokens via
cache invalidation if performed mid-session.

**Why.** M-§6 derives the cost. The cache is a byte-prefix tree; any
change rebuilds from the change point forward.

**Enforcement.** `hooks/cache-guard.sh` warns on Bash/Edit/Write to
the relevant paths. Never blocks. The point is awareness over time,
not friction.

### 3.3 Hook ↔ Rule ↔ CLAUDE.md ↔ Skill ↔ Agent

**Rule.** Use the cheapest instrument that solves the problem. Going
right (more expensive) requires a stated reason.

**Why.** A-§2.2 derives the cost hierarchy: hooks are zero token
context cost (run outside the LLM); rules are 0 tok unless their glob
matches; CLAUDE.md lines are paid every turn × N sessions; skill
metadata is ~100 tok eager + ~2k lazy on use; sub-agents are ~12k tok
fresh system prompt and cannot share parent cache.

**Enforcement.** `hooks/token-economy-guard.sh` redirects rule→hook
or rule→glob when an operator writes a rule without a glob.

---

## Section 4 — The closed loop, expressed as invariants

The five-phase loop in `README.md` ("BOOT → EXECUTE → COMPACT →
CLOSE → CALIBRATE") preserves four invariants across every cycle:

| Phase | Invariant preserved | If violated, downstream effect |
|---|---|---|
| **BOOT** | persistent prefix is identical to last session's prefix (modulo justified L1/L2 edits batched between sessions) | cache hit rate drops on first turn; the smaller the change the cheaper the recovery |
| **EXECUTE** | every tool call is observed by `telemetry.sh` and every cache-relevant write is observed by `cache-guard.sh` | metric attribution becomes uncomputable post-hoc |
| **CLOSE** | the est-vs-real delta is appended to `bridge-history.jsonl` before the session record is finalized | calibration loop has no signal to learn from |
| **CALIBRATE** | the next BOOT's status is computed from the rolling delta, not from a static estimate | future estimates do not converge to truth |

If any of these invariants is broken in your environment, run
`tools/cost-audit.py --invariants` to identify which contract failed.

---

## Section 5 — The falsifiability matrix

Every load-bearing invariant has a stated falsification test. This
is what makes the framework defensible against `LIMITATIONS.md` §1
(the leverage-arbitrage critique) and §2 (the N=1 critique):

| Invariant | Falsifies if | Test |
|---|---|---|
| 1 — Observe before acting | tools-log shows write events without prior matching read in same session, sustained over a window | `tools/cost-audit.py --invariants` (read:write ratio check) |
| 3 — Simplicity wins | a CLAUDE.md grew >50 lines in a month while cost-per-turn did not improve | manual diff of `~/.claude/CLAUDE.md.<DATE>` backups against current |
| 7 — Cheapest instrument | a hook that emits a non-zero token rule body during execution | `bash -n hooks/*.sh` plus inspection of stdout volume |
| 8 — Determinism over generation | a sub-agent running on Opus for a task with deterministic ground truth (file search, regex extraction) | `tools/cost-audit.py --by-project` plus model-share inspection |
| 9 — Every boundary declares its contract | a metric appears in any document with no derivation in M-§0 or no verification in `--invariants` | grep across docs/ for un-derived numbers |

If a falsification test passes for your data, the invariant holds in
your environment. If it fails, either your usage is outside the
profile this framework targets (see `LIMITATIONS.md` §2 + `TRANSFER.md`)
or the framework has a bug that needs reporting.

---

## Section 6 — Reading order

If you came here from:

- **README** — you wanted to know what to look at after the headline.
  Continue to `ARCHITECTURE.md` for the *why* behind each primitive,
  then `MATH.md` for the formulas, then come back to this document
  to see how they interlock.
- **MATH.md** — you have the formulas; this document tells you which
  Constitution Law each formula serves and which hook enforces it.
- **ARCHITECTURE.md** — you have the design; this document is the
  operational checklist that maps design → enforcement → verification.
- **A failed `--invariants` run** — start at Section 2, find the
  metric that violated its contract, follow the row back to MATH
  derivation and hook source.

This document is intentionally short and structural. The narrative
lives in the other three.

---

## Section 7 — When this document needs editing

This file changes when:

1. A new Law is added to `CLAUDE.md` (extend Section 1).
2. A new metric is published in any case study (extend Section 2).
3. A new governance boundary is introduced (extend Section 3).
4. A new hook materializes a previously declarative rule (update the
   Enforced column for that row).

The file does not change when:

- A specific operator's numbers change (those live in `examples/`).
- The case study window rolls forward.
- A new TRANSFER profile is added.

Net additions to this file follow the Constitution's "add only by
removing" discipline: if a row is added, an unused row should be
removed or marked deprecated. No drift.
