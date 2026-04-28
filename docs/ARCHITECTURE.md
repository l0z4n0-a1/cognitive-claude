---
doc_type: architecture
audience: [human-operator, llm-orchestrator]
reading_order: [overview, mental_model, primitives, decisions, flows, transfer]
prerequisite: README.md
authority: L1 (extends but does not contradict CLAUDE.md)
---

# ARCHITECTURE.md

The reasoning behind every decision in `cognitive-claude`.

This document is for two audiences:

1. **The operator** who wants to understand *why* before adopting,
   so they can adapt instead of cargo-cult.
2. **An LLM** that needs to reason about extending or modifying
   the system. Frontmatter and decision trees are explicit so a
   model can read this and route correctly.

If you only want to install: read `README.md`. If you want to
modify or build your own: this is the document.

---

## 1. Overview — the system in one diagram

```
                       ┌──────────────────────────┐
                       │   OPERATOR INTENT        │
                       │   (your prompt, your     │
                       │    request, your goal)   │
                       └────────────┬─────────────┘
                                    │
                ┌───────────────────▼────────────────────┐
                │           CLAUDE CODE HARNESS          │
                │   (the official CLI + model API)       │
                └───────────────────┬────────────────────┘
                                    │
   ╔════════════════════════════════▼════════════════════════════════╗
   ║              cognitive-claude POLICY LAYER                       ║
   ║                                                                  ║
   ║   ┌───────────────┐  ┌──────────────┐  ┌──────────────────┐    ║
   ║   │ CONSTITUTION  │  │    HOOKS     │  │  GOVERNANCE      │    ║
   ║   │ (CLAUDE.md)   │  │ (5 scripts)  │  │  (L0-L5 layers)  │    ║
   ║   │               │  │              │  │                  │    ║
   ║   │ 8 Laws        │  │ Boot         │  │ Mutability       │    ║
   ║   │ Decision Lvls │  │ Stop         │  │ rules per layer  │    ║
   ║   │ Mode 2 Trigs  │  │ PreToolUse   │  │                  │    ║
   ║   │ Traps         │  │ PostToolUse  │  │ Authority        │    ║
   ║   │               │  │ PostCompact  │  │ resolution       │    ║
   ║   └───────┬───────┘  └──────┬───────┘  └────────┬─────────┘    ║
   ║           │                 │                    │              ║
   ║   ╔═══════▼═════════════════▼════════════════════▼═════════╗   ║
   ║   ║              TELEMETRY CONTRACT                         ║   ║
   ║   ║   Every tool call → log → calibrate → feedback loop    ║   ║
   ║   ╚═══════════════════════╤═════════════════════════════════╝   ║
   ╚═══════════════════════════╪═════════════════════════════════════╝
                               │
                ┌──────────────▼──────────────┐
                │        OPERATOR OUTPUT       │
                │   (better decisions, lower   │
                │    cost, measurable proof)   │
                └──────────────────────────────┘
```

The policy layer sits between operator intent and harness execution.
It does not replace Claude Code — it constrains and observes it.

---

## 2. Mental model — three things to internalize

### 2.1 The hidden tax

Every line of persistent context is charged once per turn.

```
Turn 1   ┌────────────────────────────────────────────┐
         │  CLAUDE.md     │  MCP schemas  │  Skills   │  ← system prompt
         └────────────────────────────────────────────┘
                            ↑ paid once, fresh

Turn 2   ┌────────────────────────────────────────────┐
         │  CLAUDE.md     │  MCP schemas  │  Skills   │  ← cache read
         └────────────────────────────────────────────┘
                            ↑ paid 1/10th, cheap

Turn N   ┌────────────────────────────────────────────┐
         │  CLAUDE.md     │  MCP schemas  │  Skills   │  ← cache read
         └────────────────────────────────────────────┘
                            ↑ still 1/10th, IF cache holds

Cache break (CLAUDE.md edit, MCP toggle, etc):
         ┌────────────────────────────────────────────┐
         │  REBUILD FROM SCRATCH                      │  ← paid full again
         └────────────────────────────────────────────┘
                            ↑ 50k–70k tokens, gone
```

**Implication:** A 5,000-token CLAUDE.md across ~150 turns processes
~750,000 tokens per session. A 1,300-token CLAUDE.md across the same
session processes ~195,000. The difference is not 3.85× cost — it is
3.85× cost *plus* a smaller, more cacheable prefix that survives
longer.

### 2.2 The instrument hierarchy

When you need to enforce something, the cheapest tool that solves it
wins. The hierarchy is:

```
   ┌──────────────────────────────────────────────────────────────┐
   │  CHEAPEST                                       MOST COSTLY  │
   ├──────────────────────────────────────────────────────────────┤
   │                                                              │
   │  Hook        ▶  Rule + glob  ▶  CLAUDE.md  ▶  Skill  ▶  Agent│
   │                                                              │
   │  0 tok          0 tok           ~20 tok       ~100 tok  12k+ │
   │  outside        JIT loaded      persistent    lazy body  fresh│
   │  LLM            on match        in prefix     load       sysprompt│
   │                                                              │
   └──────────────────────────────────────────────────────────────┘
```

Going right requires justification. "I need an agent because..."
should always have an answer. If it doesn't, you are over-paying.

### 2.3 The closed loop

The system is a control loop, not a list of tips.

```
   ┌─────────────┐
   │   PREDICT   │  ← audit estimates expected token usage
   └──────┬──────┘
          │
          ▼
   ┌─────────────┐
   │   EXECUTE   │  ← session runs, hooks log every event
   └──────┬──────┘
          │
          ▼
   ┌─────────────┐
   │   MEASURE   │  ← Stop hook persists actual usage
   └──────┬──────┘
          │
          ▼
   ┌─────────────┐
   │  CALIBRATE  │  ← delta(predicted, actual) → adjust next predict
   └──────┬──────┘
          │
          ▼
       (loop)
```

This is what makes the system improve over time without operator
intervention. Without the loop, every "optimization" is opinion.
With the loop, optimizations are falsifiable.

---

## 3. The seven primitives — what each one is for

| # | Primitive | One-line role | Lives in |
|---|---|---|---|
| 1 | **Constitution** | Persistent governing instructions that change how the LLM reasons | `~/.claude/CLAUDE.md` |
| 2 | **Permission boundary** | What tools the LLM is allowed to call, what it is forbidden from | `~/.claude/settings.json` (allow/deny) |
| 3 | **Hooks** | Event-bound shell scripts running outside the LLM context | `~/.claude/hooks/*.sh` |
| 4 | **Skill catalog** | On-demand instruction bundles, lazy-loaded | `~/.claude/skills/*/SKILL.md` |
| 5 | **Agent routing** | Model assignment per agent archetype (Haiku/Sonnet/Opus) | per-`Task()` call, declared explicitly |
| 6 | **Telemetry contract** | Standardized observation pipeline | `~/.claude/telemetry/*.log` |
| 7 | **Governance layers** | Hierarchy of authority and mutability (L0–L5) | architectural, not file-based |

### 3.1 Constitution — why a separate file matters

The Constitution lives in `~/.claude/CLAUDE.md` and is loaded into
every session as part of the system prompt. It is the most expensive
piece of persistent context because it is paid every turn of every
session.

**Why it exists at all:** Claude Code's default behavior is general-
purpose. The Constitution narrows it to *your* operating philosophy.
Without it, you re-explain context every conversation.

**Why it must be small:** Tax is multiplicative. A 5k-token
Constitution × ~150 turns × 5 sessions/day × 30 days = ~113M tokens
of overhead per month. A 1.3k-token Constitution = ~29M.

**What belongs in it:** Laws (interlocking principles), Mode 2
triggers (when the LLM must slow down), Decision Levels (when to
decide alone vs escalate), Cognitive Traps (failure modes to avoid).

**What does not belong:** Examples, FAQs, "be helpful" instructions,
domain-specific knowledge (use Skills instead), project-specific
config (use project-level CLAUDE.md instead).

### 3.2 Permission boundary — security at harness level, not prompt level

Prompts are not security. The LLM may comply with a prompt-injected
instruction to read a file the operator did not intend it to read.
The harness-level `permissions.deny` block is.

**Why this exists:** Default settings.json allows broad tool access
"because it's convenient." Convenient until an LLM, instructed by a
malicious doc, runs `rm -rf` somewhere it shouldn't.

**Pattern:** Allow what you actively use, explicitly deny what
classes of damage you cannot tolerate.

```json
"deny": [
  "Bash(rm -rf /*)",
  "Read(**/.env)",
  "Read(**/credentials.json)",
  "Read(**/.ssh/**)"
]
```

The deny list is your last defense. Treat it as such.

### 3.3 Hooks — the cheapest enforcement instrument

A hook is a shell script that runs on a Claude Code lifecycle event.
It costs zero context tokens because it executes outside the LLM.

**Lifecycle events used:**

```
SessionStart   →  fires when `claude` starts a new session
PreToolUse     →  fires BEFORE a tool call, can block or warn
PostToolUse    →  fires AFTER a tool call, can log or act on result
PostCompact    →  fires after context compaction
Stop           →  fires when session ends
Notification   →  fires on harness notifications
```

**Decision tree for "should this be a hook?"**

```
Is the rule enforceable by a binary decision (block / allow / log)?
├─ NO  →  this is a heuristic, not a rule. Use CLAUDE.md instead.
└─ YES →  Does it fire more than once per session on average?
          ├─ NO  →  use a rule with a glob pattern
          └─ YES →  use a hook
```

**Why each of the five hooks in this repo exists:**

| Hook | Fires when | Solves what |
|---|---|---|
| `telemetry.sh` | every tool call | Visibility — without it, no claim is verifiable |
| `cache-guard.sh` | before Bash/Edit/Write | Cache breaks cost 50k+ tokens; humans forget; hooks remember |
| `token-economy-guard.sh` | before Write to rules/ | Bloated rules are silent tax — guard catches creation |
| `token-economy-boot.sh` | on session start | Restores discipline state, prints status, no cost in tokens |
| `token-economy-session-end.sh` | on session stop | Persists delta — closes the calibration loop |

Each hook does one thing. None of them block your workflow. They
inform; you decide.

### 3.4 Skills — lazy by default, eager only when justified

A skill is an on-demand instruction bundle. Two parts:

```
SKILL.md                    ← metadata + body
├─ frontmatter (always loaded eagerly, ~100 tokens)
│   description, triggers, args
└─ body (lazy-loaded only on invocation, ~2k tokens average)
    actual instructions
```

**Why lazy by default:** 20 eager skills = 40k tokens of overhead
*every* session, used or not. Same skills lazy-loaded = ~6-8k
overhead. Difference: 30k+ tokens per session.

**When eager is correct:** A skill that ALWAYS fires at session
start (e.g., a status display) can be eager. Almost nothing else
qualifies.

**Pattern:** Tag skills explicitly. Default to lazy. Justify eager
in the skill's own metadata.

### 3.5 Agent routing — model selection per archetype

Default behavior: when you call `Task(subagent_type="X")`, the
sub-agent inherits the parent's model. If your main thread runs on
Opus, your file-search agent runs on Opus. **This is wasteful.**

**Routing table:**

```
Agent archetype                       │  Recommended model  │  Why
──────────────────────────────────────┼─────────────────────┼─────────────────
Explore / file search                 │  Haiku              │  Pure retrieval
Researcher / web fetch                │  Haiku              │  Summarization
General-purpose / mechanical          │  Haiku              │  No reasoning needed
Writer / generator                    │  Sonnet             │  Quality > price
Code implementer                      │  Sonnet             │  Sonnet excels here
Reviewer / pattern matcher            │  Sonnet             │  Adequate
Chief / orchestrator                  │  Opus               │  Strategic depth
Plan / architect                      │  Opus               │  Deep reasoning
Cognitive architecture designer       │  Opus               │  Frontier task
```

**Pricing implication:** Haiku is **18.75×** cheaper than Opus per
token across all four pricing dimensions (input, output, cache-read,
cache-write — see `docs/MATH.md` Section 8 for the per-dimension
derivation). If a meaningful fraction of your agent calls are pure
retrieval (file search, summarization), routing them to Haiku saves
roughly 95% on those calls. In a heavy-Opus workload, this is the
second-largest lever after MCP discipline.

**Pattern:** Declare model explicitly on every `Task()` call. Three
lines of discipline, big chunk of the bill gone.

### 3.6 Telemetry contract — what gets logged, why

Telemetry is not analytics. It is the precondition for any
optimization claim.

**Contract:**

```
event           location                          format
─────           ────────                          ──────
tool call       telemetry/tools-YYYY-MM.log       TIMESTAMP|TOOL|SESSION|INPUT
skill use       telemetry/skills.log              TIMESTAMP|SKILL_NAME
agent dispatch  telemetry/agents.log              TIMESTAMP|TYPE|DESC|MODEL
file op         telemetry/file-ops.log            TIMESTAMP|TOOL|EXT|PATH
hour heatmap    telemetry/activity-hours.log      DATE|HOUR
session delta   bridge-history.jsonl              {est, real, delta_pct, ...}
```

All append-only. All local. Never sent anywhere. Reading these is
how you verify any claim about your own setup.

**Five metrics that matter:**

```
Cache hit rate ≥ 90%       →  Indicator: prefix is stable
Sub-agent ratio ≥ 60%      →  Indicator: delegation discipline
Estimated/actual delta     →  Indicator: model calibration
                ≤ ±10%
Tokens/turn trend          →  Indicator: no drift (rising = scope, not waste)
Cost/turn (Max equiv)      →  Indicator: plan utilization
                ≤ $0.005
```

These five are the dashboard. Everything else is detail.

### 3.7 Governance layers — what changes when

Not all parts of the system have the same authority or change
frequency. A simple six-tier model (L0–L5) is sufficient:

| Tier | Where it lives | Change cadence |
|---|---|---|
| **L0 — Harness defaults** | Anthropic, immutable | never |
| **L1 — Constitution** | `~/.claude/CLAUDE.md` | quarterly |
| **L2 — Policy** | rules, hooks, permissions | quarterly, audited |
| **L3 — Capability** | skills, agents | monthly |
| **L4 — Session** | project CLAUDE.md | per project — extends L1, never contradicts |
| **L5 — Runtime** | telemetry, in-memory | per session, read-only after capture |

Two rules govern movement between tiers:

1. A change at a higher tier can invalidate everything below it.
   The reverse is forbidden — a project CLAUDE.md never overrides
   the global Constitution.
2. Mid-session changes to Constitution or Policy tier break cache.
   Batch them to a pre-session window.

This model is currently *declarative* — no hook in v0.1 enforces
"project CLAUDE.md cannot contradict global." A hook that warns on
contradictions is a candidate for v0.2 if operator demand surfaces.
For now the discipline lives in the Constitution's Section 7
meta-rule and the operator's review.

---

## 4. Decision flows — how an operator (or LLM) chooses

### 4.1 "Where should I put this rule?"

```
You have a pattern you want enforced. Where does it live?

┌─────────────────────────────────────────────────────────────┐
│  IS THE RULE A BINARY DECISION (block / allow / log)?       │
└─────────┬───────────────────────────────────────────────────┘
          │
    ┌─────┴─────┐
   NO          YES
    │           │
    ▼           ▼
HEURISTIC   Does it fire more than once per session on average?
(belongs       │
 in           ┌┴────────────┐
 CLAUDE.md)  NO            YES
              │              │
              ▼              ▼
          RULE +          HOOK
          GLOB            (`~/.claude/hooks/*.sh`)
          (`.claude/
            rules/*.md`
           with
           `globs:` in
           frontmatter)

   COSTS:    HEURISTIC = ~20 tok in CLAUDE.md prefix
             RULE+GLOB = 0 tok unless glob matches, then ~900 tok
             HOOK = 0 tok always
```

### 4.2 "Should I use a sub-agent for this?"

```
You have a task. Direct execution or delegate to sub-agent?

┌─────────────────────────────────────────────────────────────┐
│  WILL THIS TASK GENERATE >300 WORDS OF VERBOSE OUTPUT?      │
└─────────┬───────────────────────────────────────────────────┘
          │
    ┌─────┴─────┐
   NO          YES
    │           │
    ▼           ▼
DIRECT      Is the task pure retrieval (file search, summary)?
EXECUTION       │
(Read,         ┌┴───────────────┐
 Glob,        NO               YES
 Grep,         │                 │
 Bash)         ▼                 ▼
            SUB-AGENT         SUB-AGENT
            on Sonnet         on HAIKU
            (writer,          (Explore,
             reviewer,         researcher,
             code-master)      general-purpose)

   PRINCIPLE: Verbose output goes inside sub-agent context,
              not main thread. Main thread cache stays clean.
              Sub-agent returns a summary, verbose context is
              discarded.
```

### 4.3 "Is this task a job for code or for the LLM?"

```
You have a task to execute. LLM call or program?

┌─────────────────────────────────────────────────────────────┐
│  IS THE ANSWER REPEATABLE, VERIFIABLE, SINGLE-VALUED?       │
└─────────┬───────────────────────────────────────────────────┘
          │
    ┌─────┴─────┐
   NO          YES
    │           │
    ▼           ▼
LLM CALL    CODE
(Task,      (regex, bash, Python script,
 Skill,      function, SQL query)
 main
 thread)    REASON: deterministic, free at runtime,
              auditable, no inference variance.

   LLM is for: judgement, novelty, synthesis, explanation,
               handling natural-language ambiguity.

   CODE is for: parsing, transforming, counting, validating,
                anything with a "right answer".

   HYBRID is where leverage compounds: LLM decides what to
   do, code does it. LLM reads the result, code processes it.
```

### 4.4 "When should I `/clear` between tasks?"

```
You finished a task. Start a new task in the same session?

┌─────────────────────────────────────────────────────────────┐
│  DOES THE NEW TASK NEED CONTEXT FROM THE OLD TASK?           │
└─────────┬───────────────────────────────────────────────────┘
          │
    ┌─────┴─────┐
   NO          YES
    │           │
    ▼           ▼
   /clear   CONTINUE
            (no /clear)
   COST:    /clear is FREE — it discards in-memory context
            but does NOT break the persistent prefix cache
            (CLAUDE.md, skills, etc. stay cached).

   /compact is DIFFERENT — it summarizes context, also free
   for cache. Use when you DO want some context preserved
   but compressed.
```

---

## 5. Data flow — what happens during a real session

```
TIME    EVENT                            HOOK              EFFECT
────    ─────                            ────              ──────
00:00   `claude` starts                  SessionStart      Boot status printed
                                                            Cache discipline reset
00:05   Operator: "build me a feature"   —                 LLM reads CLAUDE.md
                                                            Cache HOT (first turn)
00:06   Claude calls Read(file.py)       PreToolUse        cache-guard checks
                                                            (no break, proceed)
00:06   Read returns                     PostToolUse       telemetry logs:
                                                            tool=Read, ext=py
00:07   Claude calls Task(Explore)       PreToolUse        cache-guard checks
                                                            (no break)
00:07   Sub-agent runs on Haiku          (sub-context)     Main cache untouched
                                                            Verbose context lives
                                                            in sub-agent only
00:09   Sub-agent returns summary        PostToolUse       telemetry logs:
                                                            agent=Explore, model=haiku
00:10   Claude calls Edit(file.py)       PreToolUse        cache-guard:
                                                            "this is file.py, fine"
00:10   Edit succeeds                    PostToolUse       telemetry logs file op
00:15   Operator: "now do X"             —                 New turn, cache hot
                                                            (CLAUDE.md cached)
...
01:30   Session ends                     Stop              Bridge runs:
                                                            est vs real tokens
                                                            delta_pct persisted
                                                            Future estimates
                                                            calibrate from delta
```

This is closed-loop control in action. Every event is observed.
Every observation feeds future predictions. The system improves
without you tuning it.

---

## 6. The transfer test — does this work in your setup?

This entire architecture is **N=1**. One operator. Heavy Opus
workload. Solo, multi-project, public-facing. If your profile
differs, what transfers and what doesn't?

### 6.1 What ALWAYS transfers (the universals)

These work for any operator using any LLM harness with persistent
context:

```
PRINCIPLE                                      TRANSFER
─────────                                      ────────
Persistent context is recurring tax            ✅ Universal
Cache stability dominates token volume         ✅ Universal
Cheapest instrument that solves wins           ✅ Universal
Determinism beats LLM when answer is knowable  ✅ Universal
Sub-agent delegation preserves main cache      ✅ Universal
Model routing per agent class                  ✅ Universal
Telemetry precedes optimization                ✅ Universal
```

### 6.2 What CONDITIONALLY transfers (depends on profile)

```
COMPONENT                       TRANSFERS IF                 ADAPT FOR
─────────                       ────────────                 ─────────
The exact 91-line Constitution  Operator runs heavy Opus     Lighter use:
                                AND values dense reasoning   shorter Constitution,
                                                              fewer Mode 2 triggers
The 5 hooks as-is               Bash + python3 available     Windows-only:
                                                              port to PowerShell
                                                              or WSL
The 5 success metric targets    Workload is comparable       Casual user:
                                                              cache hit ≥ 80%
                                                              acceptable
                                                              Sub-agent ratio
                                                              irrelevant for
                                                              short sessions
The MCP zero policy             You don't actually call MCP  Heavy MCP user:
                                tools weekly                  audit per-MCP, not
                                                              blanket disable
The closed calibration loop     You run sessions to          Interrupt-heavy
                                completion regularly         workflow: skip the
                                                              loop, use raw
                                                              telemetry only
```

### 6.3 What does NOT transfer (operator-specific)

These are personal and should not be copied:

```
- Author's spinner verbs, statusline, voice settings
- Author's specific skill catalog (token-economy, harness-config etc)
- Author's project-level CLAUDE.md extensions
- Author's `additionalDirectories` paths
- Author's permission allow/deny patterns specific to their stack
```

If you copy these, you are cargo-culting. The principles transfer.
The instances are personal.

---

## 7. Anti-patterns — what to avoid (and why)

| Anti-pattern | Symptom | Root cause | Fix |
|---|---|---|---|
| **CLAUDE.md as README** | File >3k tokens, has examples, FAQs, "remember to..." reminders | Treating it as documentation instead of constitution | Rewrite as laws only. Examples belong in skills. |
| **Eager skills sprawl** | 20+ skills, all eager-loaded | "Just in case" thinking | Tag everything lazy. Force eager to justify itself. |
| **Sub-agent recursion** | Agents calling agents calling agents | No depth limit declared | Hard cap at 2. If you need 3, redesign. |
| **MCP collection** | 8+ MCPs installed, 2 actually used weekly | Hype-driven installs | Weekly use test. Disable if unused 7+ days. |
| **Mid-session CLAUDE.md edits** | "Quick tweak" while running | Lack of cache awareness | Batch edits to pre-session window. Hook blocks. |
| **Opus everywhere** | Every Task() inherits Opus | Default model assumption | Declare model explicitly per agent class. |
| **Telemetry without action** | Logs accumulating, no review | Tool fetishism | Weekly review ritual. If not reviewed, archive. |
| **Constitution drift** | CLAUDE.md gains 50 lines/month | No discipline on growth | Net additions = 0 rule. Add only by removing. |

---

## 8. Reference back to source documents

If you want to go deeper on a specific topic:

| Topic | Source |
|---|---|
| Why these specific 8 Laws | `CLAUDE.md` (the Constitution itself, with rationale per Law) |
| Math behind every claim | `docs/MATH.md` (formulas + derivations + reproducibility one-liners) |
| How to install | `docs/INSTALL.md` (manual) or `INSTALL_PROMPT.md` (Claude-native) |
| Security audit / threat model | `SECURITY.md` |
| What the headline numbers mean | `README.md` |

---

## 9. The thesis, restated

> A high-leverage Claude Code setup is not a list of optimizations.
> It is a **policy layer** with a **closed feedback loop**, governed
> by **explicit hierarchical mutability rules**, instrumented by
> **content-free telemetry contracts**, and enforced by the
> **cheapest primitive available for each enforcement task**.

Each phrase in that sentence corresponds to one of the seven
primitives above. The whole is more than the sum because the
primitives interlock — break one, the others lose effectiveness.

Read the Constitution. Run Phase 1. Trust telemetry over opinion.

The rest follows.
