# cognitive-claude

The meta-architecture behind a high-leverage Claude Code setup.
Hooks, telemetry contract, governance, and the math behind every claim.

```
┌─────────────────────────────────────────────────────────────┐
│                                                             │
│   90 days. 353 sessions. 176,839 turns. 17.62B tokens.      │
│                                                             │
│   API equivalent cost:    $37,801.31                        │
│   Plan paid (Max ×3 mo):  $600.00                           │
│   Cache hit rate:         92.4%                             │
│   Cost per turn (Max):    $0.0011                           │
│   Cost per turn (API):    $0.2138                           │
│                                                             │
│   Leverage: 189x.                                           │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

Numbers above come from the operator's local telemetry. Every claim
in this repo traces to a formula in [`docs/MATH.md`](./docs/MATH.md).
Reproduce yours by running the hooks below for 30 days.

---

## A note on novelty (read before stars)

The individual principles in this repo (prompt caching, sub-agent
delegation, model routing, lazy loading) are documented in Anthropic's
official docs. **Nothing here is invented.** What is offered:

- **Synthesis.** The seven invariants (below) interlock. None of them
  in isolation moves the needle the same way.
- **Numbers.** 90 days of telemetry from one operator, audited.
- **Frame.** "Max is a franchise, not a discount" reframes the
  conversation from "is X worth it" to "what is your throughput
  per dollar?"
- **Composition.** Hooks + Constitution + telemetry contract +
  governance layers as a coherent stack, not isolated tips.

If you came here for "5 prompt tricks," you are in the wrong repo.
If you came here for the architecture behind a measured 92.4% cache
hit rate sustained over 353 sessions, keep reading.

---

## What this is

A pluggable policy layer that sits above your Claude Code harness
and codifies seven invariants:

1. Persistent context is a recurring tax, charged N times where N = turn count
2. Cache stability dominates token volume
3. Cheapest instrument that solves wins (hook < rule < skill < agent)
4. Determinism beats LLM inference when the answer is knowable
5. Sub-agent delegation preserves main-thread cache
6. Model routing must be explicit per agent class
7. Telemetry is precondition for any optimization claim

You don't have to adopt all of it. The architecture is staged.

---

## What this is not

- Not a config file. It is the policy that generates configs.
- Not a framework library. Plugs into vanilla Claude Code, no dependencies.
- Not a prompt engineering kit. Governs the harness, not the prompts.
- Not project-specific. Any project inherits without modification.
- Not a productivity hack. It is accounting discipline applied to LLM context.
- Not opinion-driven. Every claim traces to a telemetry log entry.

---

## When this fails (when not to use it)

This setup is engineered for one specific operator profile. It works
poorly outside it. Save yourself the install:

- **Casual users** (< 1 hour Claude Code per day): overhead exceeds benefit
- **Single-session task users**: no calibration loop, all visibility wasted
- **Pro plan users**: cost ceiling lower, leverage less stark
- **Teams without shared discipline**: constitution drifts, hooks diverge per machine
- **Operators who haven't run telemetry yet**: install Phase 1 only and validate
  the gap exists before adopting the rest

The architecture is honest about who it serves. If your profile is above,
read the math, take what generalizes, skip the install.

---

## Status of components (honest version)

This project ships in stages. v0.1 is what is in this repo right now.
Future versions are roadmap, not vapor.

| Component                            | v0.1 status     | Notes                                                       |
|--------------------------------------|-----------------|-------------------------------------------------------------|
| `CLAUDE.md` (Constitution)           | ✅ Ready        | Drop into `~/.claude/CLAUDE.md`, 91 lines, byte-exact      |
| `INSTALL_PROMPT.md` (Claude-native)  | ✅ Ready        | Recommended path. Claude reads it and installs the rest    |
| `hooks/telemetry.sh`                 | ✅ Ready        | PostToolUse hook, logs to `~/.claude/telemetry/`           |
| `hooks/cache-guard.sh`               | ✅ Ready        | PreToolUse hook on Bash/Edit/Write, warns only             |
| `hooks/token-economy-guard.sh`       | ✅ Ready        | PreToolUse hook on Write to rules/, warns only             |
| `hooks/token-economy-boot.sh`        | ✅ Ready        | SessionStart hook, fail-silent if optional tools absent    |
| `hooks/token-economy-session-end.sh` | ✅ Ready        | Stop hook, fail-silent if optional tools absent            |
| `docs/MATH.md`                       | ✅ Ready        | Every claim derived from first principles                  |
| `docs/INSTALL.md` (manual fallback)  | ✅ Ready        | ~15 min per phase if you prefer to read every command      |
| `SECURITY.md`                        | ✅ Ready        | How to audit hooks before installing, how to report issues |
| `tools/telemetry-engine.py`          | 🚧 v0.2 roadmap | Sample dashboard output shown in INSTALL.md                |
| `tools/cost-audit.sh`                | 🚧 v0.2 roadmap | Math derivations in `docs/MATH.md` you can compute now     |
| Plugin contracts                     | 🚧 v0.3 roadmap | Will materialize when 3+ operators ask                     |

**Rule of this project: nothing in roadmap blocks v0.1 from being useful.**
The Constitution + 5 hooks + the math are enough to extract real leverage.
Tools come when they can be tested across platforms without breaking yours.

---

## The five-phase loop

```
BOOT       → SessionStart hook restores discipline, sets cache prefix
EXECUTE    → Operator + LLM produce work; PreToolUse hooks enforce
             cache laws; PostToolUse hook records telemetry per call
COMPACT    → On context pressure, PostCompact hook reminds state recovery
CLOSE      → Stop hook persists session delta (estimated vs actual tokens)
CALIBRATE  → Bridge-history correlates estimates with reality across
             sessions, tightening future estimates
```

Closed-loop control. Predictions corrected by measurements. Compounds.

---

## The five success metrics

| Metric                          | Target          | Why it matters                                |
|---------------------------------|-----------------|-----------------------------------------------|
| Cache hit rate                  | ≥ 90% sustained | Indicator of prefix stability                 |
| Sub-agent / main-thread ratio   | ≥ 60% sub-agent | Indicator of delegation discipline            |
| Estimated/actual delta          | ≤ ±10%          | Indicator of model calibration                |
| Tokens per turn trend           | Flat or rising  | Indicator of no drift (rising = scope, not waste) |
| Cost per turn (Max equivalent)  | ≤ $0.005        | Indicator of plan utilization                 |

If you cannot measure these, you cannot claim improvement.

---

## Install — Claude installs itself

The setup that ships in this repo is installed by the very tool it
optimizes. Open Claude Code in the cloned directory and let it
configure your harness.

**Recommended path (Claude-native, ~5 min interactive):**

```bash
git clone https://github.com/l0z4n0-a1/cognitive-claude.git
cd cognitive-claude
claude
```

Then say:

> `Read INSTALL_PROMPT.md and run Phase 1 only`

Claude reads [`INSTALL_PROMPT.md`](./INSTALL_PROMPT.md), shows you
exactly what it will do, asks for consent at each write, backs up
everything before touching it, and stops at Phase 1.

When you want more, ask:

> `Run Phase 2 of cognitive-claude install`

> `I have read CLAUDE.md end-to-end. Run Phase 3.`

Claude refuses Phase 3 unless you confirm you have read the
Constitution. By design.

**Manual path (audit-first, ~15 min per phase):**

If you prefer to read every command before it runs, or do not want
Claude touching your `~/.claude/`, follow [`docs/INSTALL.md`](./docs/INSTALL.md).
Step-by-step manual install with exact JSON to paste, exact files
to copy, exact backups to make. No automation. Same result.

**Three phases, regardless of path:**

| Phase | Duration | Risk    | Outcome                                                          |
|-------|----------|---------|------------------------------------------------------------------|
| 1     | 10 min   | Zero    | Telemetry hook installed. You see your real numbers, no behavior change. |
| 2     | 15 min   | Low     | 4 more hooks (warn-only). Cache breaks and rule bloat surface as warnings. |
| 3     | 30 min   | High    | Constitution replaces your global CLAUDE.md. Mandatory: read it first.    |

Each phase is independent. Stop anywhere. Each phase has a measurable
outcome you verify before moving to the next.

---

## Auditing without the tooling

`tools/cost-audit.sh` lands in v0.2. Until then, you can compute the
same numbers manually using formulas in [`docs/MATH.md`](./docs/MATH.md):

- **CLAUDE.md tax:** `wc -w ~/.claude/CLAUDE.md` × `0.75` = your token cost per turn
- **MCP tax:** count enabled MCPs × ~1,000 tokens per medium MCP
- **Eager skill tax:** `find ~/.claude/skills -name SKILL.md -exec wc -w {} +`
- **Sub-agent ratio:** `grep -c "Agent" ~/.claude/telemetry/tool-freq-*.log` ÷ total

Multiply by your turns/session × sessions/month × Anthropic's pricing.
Five minutes. No automation needed.

When v0.2 ships, the script does this for you and prints a personalized
waste report. Same numbers, faster.

---

## Repository layout (v0.1)

```
cognitive-claude/
├── README.md                         this file
├── CLAUDE.md                         the 91-line Cognitive Constitution
├── INSTALL_PROMPT.md                 Claude-native installer (read by claude)
├── SECURITY.md                       audit before installing, how to report
├── LICENSE                           MIT
├── hooks/
│   ├── telemetry.sh                  PostToolUse: log everything
│   ├── cache-guard.sh                PreToolUse: warn on cache breaks
│   ├── token-economy-guard.sh        PreToolUse: warn on bloated rules
│   ├── token-economy-boot.sh         SessionStart: optional discipline check
│   └── token-economy-session-end.sh  Stop: optional delta persistence
└── docs/
    ├── ARCHITECTURE.md               the why behind every decision (read this)
    ├── TRANSFER.md                   adapting to your profile
    ├── INSTALL.md                    manual install fallback
    └── MATH.md                       every claim, derived
```

Roadmap directories (`tools/`, additional docs) ship when ready.
No empty placeholders.

---

## Going deeper

| If you want to...                    | Read                              |
|--------------------------------------|-----------------------------------|
| Understand *why* before installing   | `docs/ARCHITECTURE.md`            |
| Adapt for Sonnet, Pro, team, casual  | `docs/TRANSFER.md`                |
| See every formula behind the numbers | `docs/MATH.md`                    |
| Audit hooks before installing        | `SECURITY.md` + `hooks/*.sh`      |
| Install manually, line by line       | `docs/INSTALL.md`                 |
| Let Claude install for you           | `INSTALL_PROMPT.md` (in `claude`) |

`ARCHITECTURE.md` is the document this project is most proud of.
It is what would have saved the author 6 months of mistakes.

---

## Limitations (declared upfront)

- Numbers reflect one operator's heavy-Opus workload over 90 days.
  Generalizability to lighter or team workloads is hypothesized,
  not yet demonstrated. **N=1.**
- Hook contracts depend on Claude Code's hook API. Portability to
  other harnesses (Cursor, Aider) requires translation, not copy.
- Calibration loop assumes sessions run to completion. Interrupted
  sessions break the delta record.
- "Pluggable" is being validated in public. Operators with different
  setups: open issues, the data improves the architecture.
- v0.1 is manual install or Claude-native install. The fully automated
  cross-platform `install.sh` is roadmap, not vapor.
- **Metrics are operator-selected.** Cache hit rate, sub-agent ratio,
  and cost per turn are the dimensions this setup optimizes for. Output
  quality, time-to-completion, and operator cognitive load are not
  measured. The setup may be optimizing the wrong thing for your
  workload — only your own telemetry will tell you.
- The reproducibility claim has a gap: hooks log raw data, but the
  exact dashboard numbers in this README are produced by a Python
  engine that ships in v0.2. The MATH.md document gives one-liner
  formulas to compute the headline numbers manually today.

---

## License

MIT. Use it. Fork it. Improve it. Tell me what broke.

---

## The thesis

> AI didn't automate my work. It taught me how to think better.

Whoever masters language will master the technology.

Built by [@l0z4n0-a1](https://github.com/l0z4n0-a1) — São Paulo, Brazil.
Part of [Life-OS](https://github.com/l0z4n0-a1) (in development).
