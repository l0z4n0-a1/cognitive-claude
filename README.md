# cognitive-claude

> *The operator's accountant for Claude Code.*

This is what one operator runs to keep their Claude Code harness honest.
It does not motivate you. It does not explain caching seven different ways.
It logs, measures, reports. The work is yours.

If you are using Claude Code seriously enough to want measurement, and
disciplined enough to act on what the numbers say — keep reading. If not,
this repo will frustrate you. **By design.**

---

```
┌─────────────────────────────────────────────────────────────┐
│                                                             │
│   90 days. 353 sessions. 176,839 turns. 17.62B tokens.      │
│                                                             │
│   Plan paid (Max ×3 mo):  $600                              │
│   Workload at API rates:  $37,801                           │
│                                                             │
│     of which:                                               │
│     ~$25–30k attributable to plan structure                 │
│       (any heavy Max user gets this leverage)               │
│     remaining attributable to architecture                  │
│       (this repo's contribution; isolation: refused)        │
│                                                             │
│   Cache hit rate:    99.6%   (Mode 2, MCP-free, fleet cache)│
│   Sub-agent ratio:   74.2%   (full corpus)                  │
│                                                             │
│   N=1. Architecture-multiplier in isolation: refused.       │
│   Measure SHAPE on yours: bash tools/cost-audit.sh          │
│   See docs/CONFOUNDS.md and docs/REPLICATION_LOG.md         │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

Numbers come from one operator's local telemetry. **N=1.**
Every numerical claim traces to a derivation in [`docs/MATH.md`](./docs/MATH.md).
Measure yours via `tools/cost-audit.sh`. If your shape diverges, that is data — open an issue.

**Primary audience:** heavy Claude Code operators. They install, run, read SMELL_TESTS and cost-audit output, ignore most docs.
**Secondary audience:** epistemic auditors. They read MATH, ARCHITECTURE, CONFOUNDS, INTERNALS, never install. The doc pyramid is for them.

---

## Who is this for, who is it not for (read first)

The numbers above are from one operator running Claude Code 6+ hours/day across multiple projects. The architecture is **engineered for that profile**.

If you use Claude Code less than 5 hours per week, this is overhead, not leverage.

| Hours/week of Claude Code | Recommendation                                             |
|---------------------------|------------------------------------------------------------|
| < 5h                      | Read principles in `docs/ARCHITECTURE.md`. Skip install.   |
| 5–15h                     | Phase 1 only (telemetry). Re-evaluate after 30 days.       |
| 15–40h                    | Phase 1 + 2. Phase 3 if Constitution resonates.            |
| 40h+                      | Full install + Phase 2.5 project governance.               |

[`docs/SMELL_TESTS.md`](./docs/SMELL_TESTS.md) (90 seconds, no install) is the calibrated way to decide.

---

## What this is

Three mechanisms (how Claude Code actually charges you) and four disciplines (how to operate well within them).

**Three mechanisms — physics of the system:**

1. **Persistent context is recurring tax.** Tokens × turns × cost. (`docs/MATH.md` §3)
2. **Cache stability dominates token volume.** Stable byte-prefix → cheap. Break → full rebuild. (`docs/MATH.md` §6)
3. **Sub-agent context is separate.** Verbose work isolates from main thread. (`docs/MATH.md` §7)

**Four disciplines — operator wisdom (testable, not dogmatic):**

4. **Cheapest instrument that solves wins.** Hook < rule+glob < CLAUDE.md line < skill < rule-no-glob < inline.
5. **Determinism beats LLM when answer is knowable.** Bash beats Task() ~12k tokens minimum.
6. **Model routing must be explicit per agent class.** Haiku retrieve, Sonnet code, Opus orchestrate.
7. **Telemetry precedes optimization.** Phase 1 is telemetry-only by design.

The mechanisms describe physics. The disciplines describe choices. Don't conflate them.

You don't have to adopt all four disciplines. Each is independently testable in [`docs/HOW_TO_FALSIFY.md`](./docs/HOW_TO_FALSIFY.md).

---

## What this is not

- Not a config file. It is the policy that generates configs.
- Not a framework library. Plugs into vanilla Claude Code, no dependencies.
- Not a prompt engineering kit. Governs the harness, not the prompts.
- Not a productivity hack. It is accounting discipline applied to LLM context.
- Not opinion-driven. Every numerical claim traces to a telemetry log entry.

---

## When this fails

- **Casual users** (< 1 h Claude Code per day): overhead exceeds benefit.
- **Single-session task users**: no calibration loop, all visibility wasted.
- **Pro plan users**: cost ceiling lower, leverage less stark.
- **Teams without shared discipline**: constitution drifts, hooks diverge per machine.
- **Operators who haven't run telemetry yet**: install Phase 1 only and validate the gap exists before adopting the rest.

---

## Smell test before install (90 seconds, no install required)

Run [`docs/SMELL_TESTS.md`](./docs/SMELL_TESTS.md) — five one-liners that read your `~/.claude/` and tell you whether this architecture solves a problem you actually have.

If smell tests come back green: read [`docs/ARCHITECTURE.md`](./docs/ARCHITECTURE.md) for the principles, skip the install, save 30 minutes.

---

## What it produces (after install)

Run cost-audit on your setup:

```
$ bash tools/cost-audit.sh --days 7

cognitive-claude — cost audit (7-day window)

THE 5 METRICS (cited from docs/MATH.md)
  Cache hit rate ...... 99.6%   [target ≥90%]
  Sub-agent ratio ..... 74.2%   [target ≥60%; full corpus]
  Tokens per turn ..... 179228  [flat-or-rising = no waste]
  Est/actual delta .... <run for 14d to compute>
  Cost per turn (Max) . see MATH §2; depends on model mix
```

Read-only. No external calls.

For a real before/after intervention story, see [`docs/CASE_STUDY.md`](./docs/CASE_STUDY.md).

---

## Install

**Recommended path (Claude-native, ~5 min interactive):**

```bash
git clone https://github.com/l0z4n0-a1/cognitive-claude.git
cd cognitive-claude
claude
```

Then say:

> `Read INSTALL_PROMPT.md and run Phase 1 only`

Phase progression:

| Phase | Duration | Risk | Outcome                                                   |
|-------|----------|------|-----------------------------------------------------------|
| 1     | 10 min   | Zero | Telemetry hook. Real numbers, no behavior change.         |
| 2     | 15 min   | Low  | 4 more hooks (warn-only). Cache breaks surface.           |
| 2.5   | 20 min   | Low  | Project-level governance via templates.                   |
| 3     | 30 min   | High | Constitution replaces global CLAUDE.md. Read first.       |

Manual install at [`docs/INSTALL.md`](./docs/INSTALL.md).

---

## Uninstall

```bash
bash scripts/uninstall.sh             # dry-run
bash scripts/uninstall.sh --apply     # restore + remove
```

---

## Repository layout (v0.1)

```
cognitive-claude/
├── README.md                       this file
├── CLAUDE.md                       91-line Cognitive Constitution
├── AUTHOR.md                       human context (2026 trust check)
├── INSTALL_PROMPT.md               Claude-native installer
├── SECURITY.md                     audit before installing
├── LICENSE                         MIT
├── install.sh                      phase-gated installer (dry-run default)
├── hooks/                          5 bash files, the actual mechanism
├── scripts/uninstall.sh            clean reverse, byte-exact restore
├── tools/                          cost-audit (cache-mode/health in v0.2)
├── templates/                      Phase 2.5 project profiles
├── output-styles/                  voice DNA installable
├── commands/handoff.md             session continuity
└── docs/
    ├── READ_THIS_FIRST.md          90s gentle introduction
    ├── ARCHITECTURE.md             reasoning behind every decision
    ├── MATH.md                     every number, derived
    ├── TRANSFER.md                 adapt for Sonnet/Pro/team/casual
    ├── INSTALL.md                  manual install fallback
    ├── SMELL_TESTS.md              pre-install diagnostic
    ├── CASE_STUDY.md               one operator, one decision, audited
    ├── CONFOUNDS.md                what we cannot prove and why
    ├── REPLICATION_LOG.md          external operator data (PRs welcome)
    ├── HOW_TO_FALSIFY.md           7 invariant tests + admission
    ├── STABILITY_DISCLAIMER.md     versioning + EOL conditions
    ├── RITUALS.md                  operating rhythm
    ├── SESSION_LIFECYCLE.md        per-session protocol
    ├── AUTO_EVOLUTION.md           the metabolic loop
    ├── INTERNALS.md                source-verified mechanics
    ├── VALUE_MODEL.md              ROI / 76% ignored / 2D classification
    └── META_LEARNINGS.md           30 principles distilled from 192 sessions
```

---

## Going deeper

| If you want to...                    | Read                              |
|--------------------------------------|-----------------------------------|
| Understand *why* before installing   | `docs/ARCHITECTURE.md`            |
| See every formula                    | `docs/MATH.md`                    |
| See the apparatus                    | `docs/INTERNALS.md`               |
| See the value framework              | `docs/VALUE_MODEL.md`             |
| Adapt for non-default profile        | `docs/TRANSFER.md`                |
| Audit hooks before installing        | `SECURITY.md` + `hooks/*.sh`      |
| Install manually                     | `docs/INSTALL.md`                 |
| Let Claude install                   | `INSTALL_PROMPT.md`               |
| Read the principles distilled        | `docs/META_LEARNINGS.md`          |

---

## Honest limitations

- **N=1.** Heavy-Opus, solo, multi-project. Generalizability hypothesized, not demonstrated.
- **Hooks** depend on Claude Code's hook API. Other harnesses require translation.
- **Calibration loop** is open in v0.1; closes in v0.2 with `tools/calibrate.sh`.
- **Architecture-multiplier in isolation: unknown.** See `docs/CONFOUNDS.md`.
- **Author has not run all 7 falsification tests.** Tests 1, 5, 7 informally validated. Tests 2, 3, 4, 6 designed but not executed. Commitment: 60 days post-publish.

---

## License

MIT. Use it. Fork it. Improve it. Tell me what broke.

---

## The thesis

> AI didn't automate my work. It taught me how to think better.

Built by [@l0z4n0-a1](https://github.com/l0z4n0-a1) — São Paulo, Brazil.
