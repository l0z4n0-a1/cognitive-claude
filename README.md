# cognitive-claude 🧙‍♂️

**A policy layer for Claude Code.** A ~100-line Constitution, six
governance hooks, and a single-file audit instrument that reads your
own session logs and prints what your discipline is actually worth.

The architecture is the contribution. The numbers are yours to measure.

---

## TL;DR — see your numbers in 60 seconds

```bash
git clone https://github.com/l0z4n0-a1/cognitive-claude.git ~/cognitive-claude
cd ~/cognitive-claude
python3 tools/cost-audit.py --window 90 --verbose
```

No install required. Reads `~/.claude/projects/`, applies the canonical
metric definitions in [`docs/MATH.md`](./docs/MATH.md) §0, prints your
cost-per-turn, cache hit rate, sub-agent work share, and per-model
routing breakdown. Stdlib Python only. ~60 seconds against ~10k JSONL
files.

---

### What you will see (one operator's 90-day snapshot)

This is **not a marketing screenshot.** It is the literal output of
`cost-audit.py --window 90 --verbose` against one operator's
`~/.claude/projects/`, derived from the sha256-pinned `EVIDENCE.json`
in `examples/case-study-2026-04-28/`. **Your shape will differ.** The
format will not. (Numbers here may differ by ~1% from the case-study
prose: the case study locks the strict 90-day window 2026-01-29 →
2026-04-28; the evidence pack uses the same definitions over the
record's full file span. Same instrument, same definitions, slightly
different windows. Run the instrument; trust your own data.)

```
  Window:                  90d (74 active days)
  Sessions:                987
  Turns (assistant):       201,910
    main thread:           57,029
    inside sub-agents:     144,881
  Sub-agent work share:    71.76%      (filename-based, schema-stable)
  Turns/session:           median 112  mean 205    (heavy right-tail)

  Tokens (total billable): 19.46B
  Cache hit rate:          91.63%

  API-equivalent cost:     $42,358.19
  Cost per turn (API):     $0.2098
  Plan paid (3 months):    $500.00
  Leverage (vs full term): 84.7×       (← see caveat below)

  Per-model breakdown:
    model       turns    share         cost      tokens
    opus      106,092    52.5%   $39,873.47    18.62B
    sonnet     40,109    19.9%    $1,804.10     0.66B
    haiku      55,709    27.6%      $680.63     0.18B
```

**The ~84× leverage number is not what this framework "saves" you.** It
is largely **plan-flat-rate vs. API-list-price arbitrage** that exists
for any heavy Claude Code user with stable context, with or without
this framework. What this framework actually contributes is **the
instrument that makes the ratio measurable, attributable, and
defensible** — see [`docs/LIMITATIONS.md`](./docs/LIMITATIONS.md) §1
for the explicit separation, and the rest of this README for what the
architecture does add.

The full receipt — including the platform-incident attribution
methodology, the schema-discontinuity disclosure, and the cache-rate-
during-regression mechanism — is in
[`examples/case-study-2026-04-28/`](./examples/case-study-2026-04-28/).
The sha256-pinned evidence pack is committed alongside it; reproduce
it with `python3 tools/cost-audit.py --window 90 --evidence`.

If your numbers surprise you, read [`docs/MATH.md`](./docs/MATH.md) for
the formulas and [`docs/LIMITATIONS.md`](./docs/LIMITATIONS.md) for
what the framework does *not* prove.

---

## What is in this repo

```
cognitive-claude/
├── CLAUDE.md                the Cognitive Constitution (~100 lines, 9 Laws)
├── INSTALL_PROMPT.md        a Claude-native installer (read by claude itself)
├── SECURITY.md              audit before installing, how to report
├── tools/
│   ├── cost-audit.py        reproducible audit of your own telemetry
│   ├── audit.sh             boot-hook companion, fail-silent
│   └── bridge.sh            session-end calibration loop
├── hooks/                   6 hooks (telemetry, cache-guard, rule-bloat, tier-guard, boot, end)
├── docs/
│   ├── ARCHITECTURE.md      the why behind every decision
│   ├── INSTALL.md           manual install fallback
│   ├── MATH.md              every claim, derived from first principles
│   ├── META_LEARNINGS.md    generalizable lessons from running the system
│   ├── TRANSFER.md          adapting to other operator profiles
│   └── LIMITATIONS.md       the strongest counter-arguments, stated up front
└── examples/
    └── case-study-2026-04-28/   one operator's 90-day snapshot
        ├── CASE_STUDY.md
        └── EVIDENCE.json    machine-readable evidence pack
```

---

## A note on novelty (read before stars)

The individual principles in this repo (prompt caching, sub-agent
delegation, model routing, lazy loading) are documented in Anthropic's
official docs. **Nothing here is invented.** What is offered:

- **Synthesis.** Seven invariants and three governing structures (8
  Laws, Mode 2 triggers, Decision Levels) that interlock. None of them
  in isolation moves the needle the same way.
- **Instrumentation.** A single Python script that reads your raw
  Claude Code session logs and computes the same metrics, by the same
  definitions, that any case study in `examples/` cites. No black box.
- **Forensic transparency.** A documented methodology for separating
  your own workload baseline from confirmed Anthropic platform
  incidents. The repo contains one such case study under
  `examples/case-study-2026-04-28/` — including the cache regression
  Anthropic confirmed in their
  [postmortem](https://www.anthropic.com/engineering/april-23-postmortem)
  on 2026-04-23.
- **Composition.** Hooks + Constitution + telemetry contract +
  governance layers as a coherent stack, not isolated tips.

If you came here for "5 prompt tricks," you are in the wrong repo.
If you came here for an architecture you can audit yourself, keep
reading.

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

These invariants are operationalized through three governing
structures in the [Constitution](./CLAUDE.md):

- **9 Laws of Operation** — operational invariants that compound when interlocked
- **Mode 2 Triggers** — explicit pre-action states that force genuine reasoning
- **Decision Levels (1/2/3)** — when to decide alone, when to flag, when to escalate

You don't have to adopt all of it. The architecture is staged.

---

## What this is not

- Not a config file. It is the policy that generates configs.
- Not a framework library. Plugs into vanilla Claude Code, no dependencies.
- Not a prompt engineering kit. Governs the harness, not the prompts.
- Not project-specific. Any project inherits without modification.
- Not a productivity hack. It is accounting discipline applied to LLM context.
- Not opinion-driven. Every claim traces to a telemetry log entry computable
  by [`tools/cost-audit.py`](./tools/cost-audit.py).

---

## What the framework actually contributes (and what it does not)

The case study in `examples/` reports a large ratio of API-equivalent
cost to plan paid. That ratio is **not** what this framework "saves
you." It is largely **plan-flat-rate vs. API-list-price arbitrage**
that exists for any heavy Claude Code user with stable context, with
or without this framework.

What the framework actually contributes is **measurement and
attribution discipline** — the instrument that lets you compute the
ratio with a defensible formula, the Constitution and hooks that
keep the prefix stable so the ratio is sustained, and the case-study
methodology that separates your own workload from platform incidents.

Read [`docs/LIMITATIONS.md`](./docs/LIMITATIONS.md) §1 for the explicit
separation. Treat any "leverage" number you see as a *workload
property made visible by the framework*, not as an *outcome caused
by the framework*.

---

## How this differs from related work

The Claude Code OSS ecosystem is healthy. Several adjacent projects
do related things well. cognitive-claude is **not a competitor** to
the projects below — it occupies a different position in the stack.
Each row links to that project's README so you can verify the
characterization yourself.

| Project | What it does (per their README) | Position relative to cognitive-claude |
|---|---|---|
| [disler/claude-code-hooks-mastery](https://github.com/disler/claude-code-hooks-mastery) | Reference implementation of Claude Code hooks across the lifecycle | **Below** us in the stack: hooks are a primitive cognitive-claude depends on. Read their repo to understand the primitive; read this one for what to do with it. |
| [SuperClaude_Framework](https://github.com/SuperClaude-Org/SuperClaude_Framework) | Configuration framework with multiple sub-systems (personas, methodologies, token discipline) | **Adjacent**: broader scope, configures Claude Code in many dimensions. cognitive-claude focuses narrowly on cache + cost attribution discipline. The frameworks are not exclusive. |
| [ryoppippi/ccusage](https://github.com/ryoppippi/ccusage) | Usage observability dashboard for Claude Code | **Complementary**: same data source (`~/.claude/projects/`), different framing. ccusage answers *"what did I spend?"*; `cost-audit.py` answers *"is my context strategy defensible against the math?"*. Run both. |
| [hesreallyhim/awesome-claude-code](https://github.com/hesreallyhim/awesome-claude-code) | Curated list of Claude Code skills, hooks, slash commands | **Above** us: a directory. cognitive-claude is the kind of thing that *belongs on* this list, not a competitor to it. |
| Generic `~/.claude/CLAUDE.md` templates | A markdown file dropped in `~/.claude/` to shape Claude's behavior | **Different shape**: most templates are long. The Constitution is ~100 lines on purpose. Tax is multiplicative; small Constitution + hooks + telemetry tends to outperform long Constitution alone in this operator's measurements. |

If your itch is *"give me a constitution-shaped policy with the
instrument that proves it works on my own data"* — this is the repo.
If your itch is something adjacent — pick the row above that
matches. They are good projects with their own communities.

---

## When this fails (when not to use it)

This setup is engineered for one specific operator profile. It works
poorly outside it. Save yourself the install:

- **Casual users** (< 1 hour Claude Code per day): overhead exceeds benefit
- **Single-session task users**: no calibration loop, all visibility wasted
- **Pro plan users with low usage**: cost ceiling lower, leverage less stark
- **Teams without shared discipline**: constitution drifts, hooks diverge per machine
- **Operators who haven't run telemetry yet**: install Phase 1 only and validate
  the gap exists before adopting the rest

The architecture is honest about who it serves. If your profile is above,
read the math, take what generalizes, skip the install.

---

## Status of components

This project ships in stages. v0.1.1 is what is in this repo right now.
Future versions are roadmap, not vapor.

| Component                            | v0.1 status     | Notes                                                        |
|--------------------------------------|-----------------|--------------------------------------------------------------|
| `CLAUDE.md` (Constitution)           | ✅ Ready        | Drop into `~/.claude/CLAUDE.md`, 103 lines, byte-exact      |
| `INSTALL_PROMPT.md` (Claude-native)  | ✅ Ready        | Recommended path. Claude reads it and installs the rest     |
| `tools/cost-audit.py`                | ✅ Ready        | Reproduces every metric definition against your own data    |
| `tools/audit.sh`                     | ✅ Ready        | Boot-hook companion, fail-silent if `cost-audit.py` absent  |
| `tools/bridge.sh`                    | ✅ Ready        | Session-end calibration loop                                |
| `hooks/telemetry.sh`                 | ✅ Ready        | PostToolUse hook with built-in secret redaction             |
| `hooks/cache-guard.sh`               | ✅ Ready        | PreToolUse hook on Bash/Edit/Write, warns only              |
| `hooks/token-economy-guard.sh`       | ✅ Ready        | PreToolUse hook on Write to rules/, warns only              |
| `hooks/token-economy-boot.sh`        | ✅ Ready        | SessionStart hook, fail-silent if optional tools absent     |
| `hooks/token-economy-session-end.sh` | ✅ Ready        | Stop hook, fail-silent if optional tools absent             |
| `hooks/tier-contradiction-guard.sh`  | ✅ Ready (0.1.1)| PreToolUse on Edit/Write, warns on project↔global CLAUDE.md contradiction |
| `tools/stress-test.py`               | ✅ Ready (0.1.1)| End-to-end test of audit instrument vs ideal/edge/malformed inputs |
| `tools/cost-audit.py --invariants`   | ✅ Ready (0.1.1)| Verifies five canonical metric contracts; exit 4 on violation |
| `docs/INVARIANTS.md`                 | ✅ Ready (0.1.1)| Cross-reference: Laws ↔ MATH ↔ hooks ↔ instrument verification |
| `docs/HANDBOOK.md`                   | ✅ Ready (0.1.1)| Field manual — day-to-day practice, boot/close rituals, seven trenches |
| `docs/MATH.md`                       | ✅ Ready        | Every claim derived from first principles                   |
| `docs/INSTALL.md` (manual fallback)  | ✅ Ready        | ~15 min per phase if you prefer to read every command       |
| `docs/ARCHITECTURE.md`               | ✅ Ready        | The why behind every decision                               |
| `docs/TRANSFER.md`                   | ✅ Ready        | Adaptation to other operator profiles                       |
| `docs/META_LEARNINGS.md`             | ✅ Ready        | Generalizable lessons from running the system               |
| `docs/LIMITATIONS.md`                | ✅ Ready        | Strongest counter-arguments stated upfront                  |
| `examples/case-study-2026-04-28/`    | ✅ Ready        | One operator's 90-day snapshot, including platform incident |
| `SECURITY.md`                        | ✅ Ready        | How to audit hooks before installing, how to report issues  |
| `tools/install.sh`                   | 🚧 v0.2 roadmap | Cross-platform automated installer                          |
| `skills/` and `agents/`              | 🚧 v0.2 roadmap | The operationalization layer (token-economy, harness-config, skill-architect) |
| Plugin contracts                     | 🚧 v0.3 roadmap | Will materialize when 3+ operators ask                     |

**Rule of this project: nothing in roadmap blocks v0.1 from being useful.**
The Constitution + 6 hooks + the audit instrument + the math are enough to
extract real measurement discipline. Tools come when they can be tested across
platforms without breaking yours.

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
| Cache hit rate                  | ≥ 90% sustained | Indicator of prefix stability *(but see caveat)* |
| Sub-agent turn-share *(see note)* | ≥ 50% (turns) | Indicator of delegation discipline. Turn-basis. Pair with cost-basis (typically lower for Haiku-routed sub-agents). |
| Estimated/actual delta          | ≤ ±10%          | Indicator of model calibration                |
| Tokens per turn trend           | Flat or rising  | Indicator of no drift (rising = scope, not waste) |
| Cost per turn (API-equivalent)  | < $0.50 (Opus heavy) | Plan utilization vs raw API                |

**Caveat on cache hit rate.** During a confirmed Anthropic platform
incident in March-April 2026, the case study operator's cache hit
rate *rose* (85% → 95%) while real cost-per-turn *also* tripled.
Cache hit rate alone can be misleading during regressions. **Trust
$/turn over cache hit rate** during incident windows. See
`examples/case-study-2026-04-28/CASE_STUDY.md` Section 7 for the
mechanism.

If you cannot measure these, you cannot claim improvement. The audit
instrument computes all five from raw telemetry.

---

## Install — Claude installs itself

The setup that ships in this repo is installed by the very tool it
optimizes. Open Claude Code in the cloned directory and let it
configure your harness.

**Recommended path (Claude-native, ~5 min interactive):**

```bash
git clone https://github.com/l0z4n0-a1/cognitive-claude.git ~/cognitive-claude
cd ~/cognitive-claude
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
outcome you verify with `tools/cost-audit.py` before moving to the next.

---

## Verify before you install (integrity manifest)

The Claude-native installer (`INSTALL_PROMPT.md`) lets your own
Claude Code instance read a markdown file and execute installation
shell. **This is convenient and it is also a prompt-injection
surface** — see [`SECURITY.md`](./SECURITY.md) §"Special warning."

If you cloned a fork (or want to be sure the canonical repo wasn't
silently modified), verify the integrity-critical files against
this manifest before invoking the installer:

```bash
cd ~/cognitive-claude
sha256sum INSTALL_PROMPT.md \
          tools/cost-audit.py tools/audit.sh tools/bridge.sh tools/test_redaction.py tools/stress-test.py \
          CLAUDE.md \
          hooks/*.sh
```

Expected (v0.1.1):

```
abfd8bc485ad4bc131cc0179a99445424c50d75034657756acad0bf04a3d3a69  INSTALL_PROMPT.md
7a856f67a646306ba762cd189db4d76f5cf9f813a3799130dbfbd0a8d266b240  tools/cost-audit.py
636602b5953ba3a461d87d8a26b1f81bb9e6e4a8b39c98ee8199b5e3701e60e7  tools/audit.sh
d8b82f412b40cb81f797a939109dcc98e23366cfe880dd1ec87face704b21aee  tools/bridge.sh
c3564626c39de31e47f3ebf6dd27896b2ca7c5de7696079ca3938d2b18627ea3  tools/test_redaction.py
e43eb85c8b0c9eb747b7ca131f0fce30d7c5bc9306b969947d3b602f1bd35fa7  tools/stress-test.py
58536bd5065c87ac14db97ea1190a1124077290b5abb2732ee6ff1d826d4e71e  CLAUDE.md
2506714d11f363f1493ee67163674e6f94439314d01574e2bc47de9ec40285e3  hooks/cache-guard.sh
9ce14ea40dfa45238af0813f5babf6b6fcf30c71e602bcaf127fac8029ef08f6  hooks/telemetry.sh
58dd22b6f169962e88968d738b7f0602cb68c99e01185081205cf6408d7e3e30  hooks/tier-contradiction-guard.sh
7c7214d55b007e8fd116fbe05c5570f357cfb6d5802a839a606f4d8dd33d98ce  hooks/token-economy-boot.sh
a3aecd79794f465949b047e585307ea0755b5b491b7d1eb10f72ef3a59a1db75  hooks/token-economy-guard.sh
6cee0755c41bb33654c3476eb8eb089386ffc38a055ba35cfae6592cacc6aaf9  hooks/token-economy-session-end.sh
```

The repo ships a `.gitattributes` (`* text=auto eol=lf`) that pins
LF line endings on every clone, so these hashes verify identically
on Linux, macOS, WSL, and Windows. If you see mismatches anyway:
your local git config likely overrode the attribute (`git config
--local --get core.autocrlf`); reclone with `git clone --config
core.autocrlf=false` and try again.

Any verified mismatch on `INSTALL_PROMPT.md`, the hooks, the audit
instrument, or its tests means you are looking at modified code.
Do not run the installer until you understand why.

You can also verify the two non-visual contracts ship unbroken:

```bash
python3 tools/test_redaction.py
# Expected: OK (16 tests, 0 failures) — secret-redaction patterns

python3 tools/stress-test.py
# Expected: OK across ideal / edge / malformed fixtures —
# the audit instrument honors the metric contracts in docs/INVARIANTS.md §2
```

---

## Auditing your own setup

The audit instrument is the central reproducibility artifact:

```bash
# Default 90-day window
python3 tools/cost-audit.py

# Verbose: 7d / 30d / 90d / all-time side-by-side
python3 tools/cost-audit.py --verbose

# ASCII charts of daily $/turn, $/day, cache hit, sub-share
python3 tools/cost-audit.py --charts

# Per-project cost breakdown
python3 tools/cost-audit.py --by-project

# Machine-readable JSON evidence pack
python3 tools/cost-audit.py --evidence > my-evidence.json
```

It reads your `~/.claude/projects/**/*.jsonl` session logs, applies
the canonical metric definitions (documented in
[`docs/MATH.md`](./docs/MATH.md) Section 0), and prints your five
key metrics.

**What to look for in your output:**

- **Cache hit rate < 85%** — likely prefix drift; check Constitution edits
- **Sub-agent work share < 30%** — most work in main thread; cache cost compounds
- **Cost per turn > $0.50** — plan utilization is poor relative to raw API,
  *or* you are inside a platform incident
- **Cost per turn rising sharply** — primary regression signal. Trust this
  over cache hit rate.

The instrument is **single-file Python, no external dependencies**. Read
it before running it. That is the discipline this project teaches.

---

## Going deeper

| If you want to...                        | Read                              |
|------------------------------------------|-----------------------------------|
| Understand *why* before installing       | `docs/ARCHITECTURE.md`            |
| **Live with it day-to-day after install** | **`docs/HANDBOOK.md`** (the field manual) |
| See an example operator's 90-day audit   | `examples/case-study-2026-04-28/` |
| Adapt for Sonnet, Pro, team, casual      | `docs/TRANSFER.md`                |
| See every formula behind the methodology | `docs/MATH.md`                    |
| Reproduce metrics on your own data       | `python3 tools/cost-audit.py`     |
| Audit hooks before installing            | `SECURITY.md` + `hooks/*.sh`      |
| Install manually, line by line           | `docs/INSTALL.md`                 |
| Let Claude install for you               | `INSTALL_PROMPT.md` (in `claude`) |
| Generalizable lessons from one run       | `docs/META_LEARNINGS.md`          |
| The strongest counter-arguments          | `docs/LIMITATIONS.md`             |

`ARCHITECTURE.md` is the document this project is most proud of.
`examples/case-study-2026-04-28/` is the receipt that backs it.
`LIMITATIONS.md` is the document that makes the receipt defensible.

---

## License

MIT. Use it. Fork it. Improve it. Tell me what broke.

---

## The thesis

> AI didn't automate my work. It taught me how to think better.

Whoever masters language will master the technology.

Built by [@l0z4n0-a1](https://github.com/l0z4n0-a1).
