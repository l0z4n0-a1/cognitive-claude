---
doc_type: token-value-framework
audience: [adopter, system-designer]
prerequisite: docs/MATH.md, docs/INTERNALS.md
authority: L2 (extends ARCHITECTURE)
---

# VALUE_MODEL.md — Beyond cost: what tokens are *worth*

The missing half of token economy: not just what tokens COST, but what
they're WORTH.

## The Real Cost Formula

The naive formula (`count × average`) misses two critical dimensions.

### Effective Cost (token frequency × cache state)

```
effective_cost = tokens × frequency × (cache_hit_rate × 0.1 + cache_miss_rate × 1.0)
```

| Factor | What it means |
|---|---|
| tokens | Raw token count |
| frequency | every turn (1.0), per session (0.3), on-demand (0.1) |
| cache_hit_rate | % loads where prefix is stable (CLAUDE.md ~0.99, state ~0.30) |

A 500-line file loaded on-demand (0.1 freq) costs LESS than a 50-line file
loaded every turn (1.0 freq). **Size alone is misleading.**

### Output Economics (5x rule)

**Output tokens cost 5x input tokens.** This is the single most important
economic fact in context engineering.

| Model | Input/1M | Output/1M | Cached Input/1M |
|---|---|---|---|
| Haiku 4.5 | $0.80 | $4.00 | $0.08 |
| Sonnet 4.5/6 | $3.00 | $15.00 | $0.30 |
| Opus 4.6/4.7 | $15.00 | $75.00 | $1.50 |

> Pricing canonical source: `docs/MATH.md` §1 (Anthropic public API rates,
> verified 2026-04-28). All four pricing dimensions per model are listed
> there, including the cache-write rate this table omits for brevity.

**The output inflation hypothesis:** Verbose input context tends to generate
verbose output. If the system prompt is 50k tokens of dense instruction,
the model mirrors that density. Cutting 10k input tokens may cut ~5k output
tokens per turn.

**The TRUE cost formula:**
```
total_cost = input_effective_cost + (output_tokens × 5 × output_price)
```

Optimizing input is only HALF. Constraining output is the other half:
- "Respond in under 200 words"
- Structured formats (JSON/YAML) — inherently concise
- "Which option and why in one sentence" (30 tokens) vs "Analyze options" (500 tokens)

---

## Token Value (ROI per Entity)

Every context entity has COST and VALUE. The ratio determines its worth.

### ROI Formula

```
ROI = (behavior_change_frequency × impact_magnitude) / effective_cost
```

| Entity | Behavior change | Impact | Eff. cost | ROI |
|---|---|---|---|---|
| CLAUDE.md "Act on intent" | 8/10 turns | HIGH | ~20 tok | INFINITE |
| Unused command description | 0/100 sessions | ZERO | ~30 tok/session | 0 |
| Rule with glob (when matched) | 5/10 turns in context | HIGH | ~0 (JIT) | HIGH |
| Skill metadata (never invoked) | 0 sessions | ZERO | ~100 tok | 0 |

**The 76% statistic:** CL-Bench (2024) found that **76% of loaded context
is IGNORED** by the model. Only 24% actually influences output. **Loading
is not using.**

---

## Value Classification

| Class | Criteria | Action |
|---|---|---|
| **ESSENTIAL** | Changes behavior 7+/10 turns, high impact | PROTECT. Never cut. |
| **USEFUL** | Changes behavior 3-6/10 turns, moderate impact | KEEP. Monitor ROI. |
| **MARGINAL** | Changes behavior 1-2/10 turns, low impact | MOVE to on-demand. |
| **DEAD** | 0 behavior change, 0 invocations | CUT. Delete entirely. |

---

## Temporal Value

Entities have different value at different points in a session:

| Type | Description | Value pattern |
|---|---|---|
| **SETUP** | Identity, mode, voice | High in turns 1-3, then internalized |
| **ONGOING** | Safety rules, constraints, patterns | Constant value every turn |
| **TRIGGERED** | Skills, rules with globs, on-demand refs | Zero until triggered, then high |

The framework has EAGER/LAZY as loading axis. This adds SETUP/ONGOING/TRIGGERED
as the value axis. Together they form a 2D classification:

```
           EAGER          LAZY
SETUP      CLAUDE.md      (rare — setup that's on-demand)
ONGOING    Rules w/o glob  Hooks (0 tokens, always active)
TRIGGERED  Command desc    Skills, rules w/ glob
```

The ideal: ONGOING content uses hooks (0 tokens). SETUP content is minimal
CLAUDE.md. TRIGGERED content uses skills/rules with globs (0 until needed).

---

## Epistemic Status

Not all context is equally reliable. Classify every entity:

| Status | Definition | Can override? |
|---|---|---|
| **AXIOM** | True by definition in this system | Only by redesign |
| **FACT** | Externally verifiable | When reality changes |
| **EVIDENCE** | Collected from real source | With new collection |
| **HEURISTIC** | Works empirically | When exception found |
| **INFERENCE** | Derived by reasoning | With new data |
| **SPECULATION** | Unverified | Any time |

**Hard rule:** Lower-status information NEVER overwrites higher-status. A
heuristic cannot override a fact. An inference cannot override evidence.

Applied to this framework:
- The 11-phase model = INFERENCE (derived from code analysis)
- "Output costs 5x input" = FACT (published pricing)
- "76% of context is ignored" = EVIDENCE (CL-Bench 2024)
- The ~6-8k skill-overhead target = HEURISTIC (lazy-loaded skills target, see `docs/MATH.md` §9 derivation)
- "Verbose input → verbose output" = SPECULATION (plausible but untested here)

---

## The 4 Context Pathologies

Failure modes that destroy value regardless of token count:

### 1. Context Poisoning
Hallucinated/flawed data propagates through subsequent reasoning.
**Detection:** Output references facts not present in any loaded context.
**Prevention:** Self-critique loops. Source fidelity clauses. Never trust
unvalidated context.

### 2. Context Distraction
Model overfocuses on repeated patterns, loses novel problem-solving.
**Threshold:** ~100K tokens for large models; ~32K for smaller.
**Prevention:** Aggressive pruning. Summarize previous turns instead of
including verbatim.

### 3. Context Confusion
Superfluous content causes wrong tool selection or wrong focus.
**Evidence:** 46 tools = 0% success rate. 10-15 tools = optimal range.
**Prevention:** Minimal relevant subset per step. Deferred tool loading.

### 4. Context Clash
Conflicting information in same prompt degrades performance.
**Impact:** Multi-turn sharding causes 39% average performance drop.
**Prevention:** Single authoritative source per fact. Clear priority hierarchy.

---

## MVC Formula (Minimum Viable Context)

```
Intelligence = f(relevance × quality) / noise
```

Maximize: relevance (is this needed NOW?) and quality (is it accurate?).
Minimize: noise (everything else).

The target is not "less context." It's "**higher signal-to-noise ratio**."

---

## 5 Laws of Context Engineering

1. **Wrong > Missing** — Incorrect context causes wrong decisions. Delete
   ruthlessly. A stale rule that says "use API v1" when you're on v3 is
   WORSE than no rule.
2. **Every Line Burns** — Auto-loaded content costs tokens EVERY turn.
3. **Code > Instruction** — Enforce with scripts/hooks, not prose.
   Zero-token enforcement.
4. **Pointer > Inline** — 1-line reference beats N-line duplication.
5. **Decay Is Default** — Context rots. Unvalidated in 10 sessions =
   suspect. Every entity needs an owner. No owner = no maintenance = decay.

---

## Prescriptions (action vocabulary)

After audit, every entity gets a prescription:

| Prescription | When | Action |
|---|---|---|
| **CUT** | Zero ROI, dead weight | Delete entirely |
| **CONDENSE** | Useful but verbose | Reduce without losing value |
| **MOVE** | Valuable but rarely needed | EAGER → on-demand |
| **CACHE** | Stable but poorly positioned | Reorder for cache prefix optimization |
| **KEEP** | Justified cost, good ROI | No action. Document justification. |

---

## How to falsify this model

If your audit using these classes produces actions that DEGRADE your
metrics (cache hit drops, tokens/turn rises) over 30 days, the model is
wrong for your workload. Open an issue.
