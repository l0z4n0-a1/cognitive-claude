# MATH.md — Every Claim, Derived

Every numerical claim in the README and elsewhere in this repo is
derived here from observable, reproducible measurements.

If a number appears anywhere in this project without a derivation
in this document, that is a bug. Open an issue.

**The reproducibility floor:** the script `tools/cost-audit.py` reads
your own session logs and computes every metric below using the same
definitions. Run it. The case study in
[`examples/case-study-2026-04-28/`](../examples/case-study-2026-04-28/)
is one operator's snapshot using these definitions; your numbers
will look like the same shape, with your values.

This document is **the math** (universal). The README is the
**framework summary** (universal). The `examples/` directory is
**the receipts** (one or more case studies grounded in real data).

---

## Section 0 — Canonical Definitions

These definitions are the contract. Every formula below uses them.
The audit instrument implements them. Any claim that contradicts
them is a bug.

| Term | Definition |
|------|------------|
| **turn** | one assistant message that contains a non-empty `usage` block in the JSONL session log |
| **agent turn** | a turn whose source JSONL filename starts with `agent-` (sub-agent context). Stable across all observed Claude Code versions. |
| **main turn** | a turn whose source JSONL filename does **not** start with `agent-` (main thread) |
| **sub-agent work share** | `agent_turns / total_turns × 100` — the canonical metric for "how much of my work happens inside sub-agent contexts" |
| **dispatch** | one `tool_use` block with `name` in `{Task, Agent}` on a main turn (creates a sub-agent context) |
| **session** | one unique value of the record's `sessionId` field |
| **window** | a rolling time horizon (7d, 30d, 90d) bounded by the record's `timestamp` field — **not** by file mtime, which is unreliable across copies and backups |
| **API-equivalent cost** | `tokens × Anthropic public per-model price`, summed across all turns |
| **cache hit rate** | `cache_read_input_tokens / (cache_read + input + cache_creation)` — fraction of *paid prefix tokens* that came from cache |

### Why filename-based sub-share, not the `isSidechain` field

Around Claude Code v2.1.86 (week of 2026-03-23), the JSONL
`isSidechain` field semantics changed. Pre-2.1.86 it was nearly
always `true` for assistant turns (regardless of whether the work
was actually in a sub-agent). Post-2.1.86 it became a real
discriminator. Filename pattern (`agent-*.jsonl`) is stable across
all observed versions. **This repo trusts filenames over flags.**
See `examples/case-study-2026-04-28/CASE_STUDY.md` Section 6 for
the discontinuity evidence and per-week sub-share trend.

### Why three terms in the cache hit denominator

Every turn pays for prefix tokens in one of three states:

- **fresh-input**: new tokens, not in cache (paid at full input rate)
- **cache-create**: new tokens being written to cache (paid at write rate, ~25% premium over input)
- **cache-read**: already in cache (paid at read rate, ~10× cheaper)

All three are real prefix-token costs. A formula that omits
`cache_creation_input_tokens` (the simpler `cache_read / (cache_read
+ input)` form) inflates the apparent hit rate by hiding the prefix
re-write that happens on every cache invalidation. **The repo
publishes the three-term form**; the simpler form is mentioned only
to flag it as an antipattern.

---

## Section 1 — Anthropic API Pricing Reference

All cost calculations use Anthropic's published API pricing (verify
at <https://docs.anthropic.com/en/docs/about-claude/pricing>):

| Model         | Input ($/M tok) | Output ($/M tok) | Cache read ($/M) | Cache write ($/M) |
|---------------|-----------------|------------------|------------------|-------------------|
| Opus 4.6/4.7  | 15.00           | 75.00            | 1.50             | 18.75             |
| Sonnet 4.5/6  | 3.00            | 15.00            | 0.30             | 3.75              |
| Haiku 4.5     | 0.80            | 4.00             | 0.08             | 1.00              |

Cache read costs **10×** less than fresh input. Cache write costs
**1.25×** more than fresh input. This asymmetry is the foundation of
every optimization in this project: cache stability is the dominant
lever, not raw token volume.

---

## Section 2 — The Headline Metrics (formula form)

This section defines each headline metric the instrument computes.
For one operator's actual values, see
[`examples/case-study-2026-04-28/`](../examples/case-study-2026-04-28/).
For yours, run `tools/cost-audit.py --window 90`.

### 2.1 — API-equivalent cost over a window

```
For each assistant turn t in window:
    cost(t) = input_tokens   × P_input(model)
            + output_tokens  × P_output(model)
            + cache_read     × P_cache_read(model)
            + cache_create   × P_cache_write(model)

window_cost = sum(cost(t) for t in window)
```

Output: a dollar number representing what the same workload would
have cost at full Anthropic API rates.

### 2.2 — Leverage on plan paid

```
leverage_full_term = window_cost / plan_paid_total
leverage_per_month = window_cost / plan_paid_monthly
```

Both are valid framings. `--plan-paid` and `--plan-months` to the
instrument let you set your own plan numbers. The 1-month framing
is more sensitive to recent activity; the full-term framing is more
conservative.

### 2.3 — Cache hit rate (canonical)

```
cache_hit = cache_read / (cache_read + input + cache_create)
```

Above 90% sustained means the prefix is stable. Below 85% means
drift (check Constitution edits, MCP toggles, model switches).

**A counter-intuitive pattern from real telemetry:** during the
2026-03-26 → 2026-04-10 Anthropic cache regression, affected
operators saw cache hit rate *rise* (often 85% → 95%+) while real
cost-per-turn also rose 2-3×. The mechanism is documented in
`examples/case-study-2026-04-28/CASE_STUDY.md` Section 7. Short
version: the bug rewrote prefix to cache on every turn, inflating
cache-write tokens in the denominator and making the ratio look
healthier than the underlying efficiency. **Cache hit rate is not a
sufficient single metric.** Pair it with $/turn.

A simpler "naive" formula `cache_read / (cache_read + input)`
returns higher numbers on the same data, but omits cache-write
tokens and overstates hit rate. **Use the three-term denominator.**

### 2.4 — Cost per turn (API-equivalent)

```
cost_per_turn = window_cost / window_turns
```

The plan flat-rate equivalent over the same window is:

```
plan_cost_per_turn = plan_paid_total / window_turns
```

**These two are mathematically related** — their ratio equals the
leverage in §2.2. They are not independent metrics.

### 2.5 — Sub-agent work share (filename-based)

```
sub_agent_share = agent_turns / total_turns
```

Where:
- `agent_turn` = turn whose source JSONL filename starts with `agent-`
- Filename pattern is **stable across all observed Claude Code versions**

**Why filename, not `isSidechain`:** the `isSidechain` field
semantics changed around Claude Code v2.1.86 (W13/2026-03-23).
Pre-2.1.86 it was nearly always `true`; post-2.1.86 it became a
real discriminator. Filename pattern is unaffected by this change.
See Section 0 and the case study Section 6.

### 2.6 — Model routing

By turn count over the window:
- Opus turns / total_turns
- Sonnet turns / total_turns
- Haiku turns / total_turns

By cost share, Opus typically dominates total dollar share (often
90%+ for heavy-Opus operators) because of the 18.75× pricing
differential — see Section 8.

---

## Section 3 — The CLAUDE.md Tax Math

### Claim: A 5,000-token CLAUDE.md across a typical session of ~150 turns processes ~750,000 tokens of overhead per session

```
overhead_per_session = claude_md_tokens × turns_per_session
                     = 5,000 × 150
                     = 750,000 tokens per session
```

That figure is **physical token movement** — not cost. Cost depends
on cache state.

When cache is hot:
```
overhead_cost_per_turn = claude_md_tokens × cache_read_price
                       = 5,000 × $1.50/M (Opus)
                       = $0.0075 per turn
```

When cache is cold (every cache break):
```
overhead_cost_per_turn = claude_md_tokens × input_price
                       = 5,000 × $15.00/M (Opus)
                       = $0.075 per turn
```

A 91-line, ~1,300-token CLAUDE.md (this project's default) reduces:
```
1,300 × 150 = 195,000 tokens per session
```

That is **3.85× less token volume** moving through the system per
session. To compute your own savings, plug in your own median
turns/session (the instrument prints it as `Turns/session: median ...`)
and your own session cadence:

```
saved_tokens_over_window = (current_tokens - 1300)
                         × your_median_turns_per_session
                         × your_sessions_in_window
```

At Opus cache-read price (best case):
```
saved_cost_min = saved_tokens × $1.50/M
```

At Opus input price (cache-cold):
```
saved_cost_max = saved_tokens × $15.00/M
```

Real savings sit between these bounds — closer to the lower bound
when cache discipline is strong (>90% hit rate sustained), closer
to the upper bound when cache discipline is poor.

**Why ~150 turns/session as the modeling anchor:** the case study in
`examples/case-study-2026-04-28/` reports median 112, mean 205 (heavy
right-tail). 150 is a defensible round-number sitting between median
and mean for architecture-heavy operator profiles. **Always use your
own median for sizing** — the instrument prints both median and mean
in the `Turns/session` line so you can see the skew.

---

## Section 4 — The MCP Tax Math

### Claim: Five medium MCPs is roughly 5,000 tokens of overhead per turn

```
tokens_per_mcp ≈ avg_tools_per_mcp × avg_schema_tokens
              = 7.5 × 130
              ≈ 1,000 tokens
total_mcp_tax = 5 × 1,000 = 5,000 tokens loaded every turn
```

Cost per session at ~150 turns:
```
mcp_tax_per_session = 5,000 × 150 = 750,000 tokens

at cache-hot Opus:  750,000 × $1.50/M  = $1.13/session
at cache-cold Opus: 750,000 × $15.00/M = $11.25/session
```

**Critical:** these tokens are paid whether or not you call any of
those MCP tools in the session. Schemas load eagerly.

The 7-day usage test:
```
if days_since_last_call(mcp) > 7:
    monthly_waste = mcp_tokens × turns_per_session
                  × sessions_per_month × token_price
    disable(mcp)  # recovers monthly_waste
```

**Recommended ceiling: MCPs = 0** for the most aggressive
operator profile. Zero, not low. Every tool the operator might
want is implemented as a hook, a skill, or a direct command. If
this is too tight, audit each MCP weekly with the 7-day-no-call
test.

---

## Section 5 — The Hook vs Rule Math

### Claim: A rule file with a glob loads ~900 tokens; a hook loads zero

A Claude Code rule file lives in `.claude/rules/*.md` and is matched
against tool calls via glob patterns. When the glob matches, the
rule body is injected into context for that turn.

Typical rule file (measured across 30 production rules):
```
mean rule tokens = 900 (median)
range            = 200 – 2,500
```

If the rule fires on every Bash call (e.g., `Bash(git:*)`), and a
session has 50 Bash calls:
```
total_rule_cost = 900 × 50 = 45,000 tokens just from one rule
                = $0.0675 (cache-hot Opus) to $0.675 (cache-cold)
```

A hook doing the same enforcement runs as a bash subprocess outside
the LLM. It receives JSON via stdin, returns JSON via stdout, and
has **zero context token cost**. The harness pays nothing for hook
execution beyond hook latency (typically < 100 ms).

```
hook_cost_per_match    = 0 tokens
hook_cost_per_session  = 0 tokens
hook_cost_per_year     = 0 tokens
```

The savings compound silently. Every rule that can be a hook should be.

---

## Section 6 — The Cache Break Math

### Claim: Editing CLAUDE.md mid-session costs 20k–70k tokens

Anthropic's prompt cache uses a byte-prefix hierarchy. When the
prefix changes, the cache invalidates from the change point onward.
The next turn must re-process everything from the change point
forward at fresh input rates.

A typical session has accumulated context of 20k–70k tokens by
mid-session (CLAUDE.md + tool definitions + accumulated turns). When
cache breaks:

```
cache_break_cost = total_accumulated_context × input_price
```

For a 50k-token session at Opus rates:
```
cache_break_cost = 50,000 × $15/M = $0.75 per break
```

If you do this 5 times in one work session:
```
total_waste = 5 × $0.75 = $3.75 in cache breaks
            = 250,000 tokens of pure waste
```

**The cache-guard hook prevents this entire class of waste at zero
context cost.**

A historical example of cache-break catastrophe: the 2026-03-26
Anthropic regression caused cache *writes* on every turn (not just
mutations), inflating cost-per-turn ~3× for affected workloads. See
`examples/case-study-2026-04-28/CASE_STUDY.md` for one operator's
measured loss attribution to that incident.

---

## Section 7 — The Sub-Agent Math

### Claim: Sub-agents preserve main-thread cache; main-thread inflation costs more

Loading a 50-file codebase into main thread:
```
main_thread_cost = 50 files × ~2,000 tokens each
                 = 100,000 tokens loaded into main context, persistent
```

Subsequent turns pay cache-read on those 100k tokens:
```
per_turn_cost = 100,000 × $1.50/M = $0.15/turn (Opus cache-read)
              × ~150 turns         = ~$22.50/session
```

If you load via sub-agent, the verbose context lives in the
sub-agent's own context, returns a summary (~500 tokens), and main
thread is unchanged:

```
subagent_one_time_cost = 100,000 × $15/M     = $1.50 (sub-agent read)
+ summary_returned     = 500 × $1.50/M       = ~$0
- main_thread_cost     = 0 (clean cache)

total_session_cost = $1.50 (vs ~$22.50 main-thread)
```

**Savings: ~94% on that single delegation pattern.**

In a heavy-Opus operator profile with mature delegation discipline,
**30–40% of paid assistant turns happen inside sub-agent contexts on
the post-W13 stable signal** (filename `agent-*.jsonl`); the case
study reports a 90-day-aggregate of 71% which is dominated by a
pre-W13 schema artifact (see CASE_STUDY §6). Cost-basis sub-share is
typically lower than turn-basis when sub-agents are routed to
cheaper models. Run `tools/cost-audit.py --by-project` and look at
where your `subagents` row lands relative to your top main-thread
projects.

---

## Section 8 — The Model Routing Math

### Claim: Opus is 18.75× the cost of Haiku per token (every dimension)

```
opus_input_price       / haiku_input_price       = $15.00 / $0.80 = 18.75×
opus_output_price      / haiku_output_price      = $75.00 / $4.00 = 18.75×
opus_cache_read_price  / haiku_cache_read_price  = $1.50  / $0.08 = 18.75×
opus_cache_write_price / haiku_cache_write_price = $18.75 / $1.00 = 18.75×
```

The ratio is consistent across all four pricing dimensions.

**Pricing implication.** For file-search-heavy operators who do a
significant fraction of agent calls on tasks that are pure retrieval
(zero reasoning), routing those to Haiku saves roughly 95% on those
calls (reading is the dominant share of the cost):

```
saved_per_haiku_routed_call ≈ 0.95 × opus_cost_for_same_call
```

In an operator profile with explicit model routing in place, a
typical pattern is:

- **By turn count**: ~50% Opus / ~20% Sonnet / ~30% Haiku
- **By cost share**: ~90%+ Opus / single-digit Sonnet+Haiku combined

The Sonnet and Haiku dispatches together do half the turns at a
small fraction of the spend. **That is the routing discipline made
visible.**

**Pattern.** Declare model explicitly on every `Task()` call. Three
lines of discipline, big chunk of the bill gone.

---

## Section 9 — The Lazy Skill Math

### Claim: 20 eager skills = 40k tokens overhead; lazy = 6–8k

**Eager loading:**

A skill body averages ~2,000 tokens (range 500–8,000). With twenty
installed:
```
eager_overhead = 20 × 2,000 = 40,000 tokens loaded every session start
```

**Lazy loading:**

Only metadata loads eagerly:
```
metadata_per_skill = 100 tokens (description, triggers, args)
eager_metadata     = 20 × 100 = 2,000 tokens
```

Skill bodies load on invocation. If average operator calls 3 skills
per session, average body 2k tokens:
```
lazy_invocation_cost = 3 × 2,000 = 6,000 tokens
```

Total lazy session overhead:
```
2,000 (metadata) + 6,000 (3 invocations) = 8,000 tokens
```

**Savings: ~32k tokens per session, or 80% reduction in skill
overhead.** At Opus rates, the per-session savings work out to
roughly $0.05 (cache-hot) — multiply by your sessions/window for
your bound. The instrument prints session counts.

Indirect savings (cache stability from smaller prefix) are larger
but harder to quantify without A/B telemetry.

---

## Section 10 — Reproducibility Statement

Every formula in this document operates on values that are
**locally observable** in your own `~/.claude/projects/` directory:

- `usage.input_tokens` — fresh input tokens per turn
- `usage.cache_read_input_tokens` — tokens served from cache
- `usage.cache_creation_input_tokens` — tokens written to cache
- `usage.output_tokens` — tokens generated by the model
- `model` — which model class to apply pricing for
- filename pattern (`agent-*.jsonl`) — sub-agent context indicator
- `sessionId` — for grouping turns into sessions
- `timestamp` — for filtering by time window

To verify any claim in this document against your own data:

```bash
# All five headline metrics
python3 tools/cost-audit.py --window 90

# 7d/30d/90d/all side-by-side
python3 tools/cost-audit.py --verbose

# ASCII charts of daily metrics
python3 tools/cost-audit.py --charts

# Per-project cost breakdown
python3 tools/cost-audit.py --by-project

# Full evidence pack JSON
python3 tools/cost-audit.py --evidence > my-evidence.json
```

Output is the same shape as the README header. If your numbers
differ materially from the snapshot, your workload differs — that
is expected.

---

## Section 11 — Limitations of This Math

1. **Model price assumptions.** Calculations assume Anthropic's
   published API rates. Actual API users may have negotiated rates
   or batch discounts.

2. **Cache-state estimation.** Real cache state is not directly
   observable beyond `cache_read_tokens`, `cache_creation_tokens`,
   and `input_tokens`. The cache-hot vs cache-cold split in some
   formulas is an approximation.

3. **Session-size variance.** The "~150 turns/session" anchor used
   in §3 tax math is a defensible round number for architecture-
   heavy work. Real distributions are heavy-tailed: the case study
   in `examples/` reports median 112, mean 205 — a 1.8× gap that
   confirms the right-tail skew. **Use your own median.** The
   instrument prints both median and mean in its summary line.

4. **Workload bias.** Heavy-Opus orchestration biases all cost
   numbers upward. Sonnet/Haiku-dominant workloads will see lower
   absolute savings but identical leverage shapes.

5. **Compounding interactions.** Optimizations interact non-linearly.
   Disabling MCPs *and* shrinking CLAUDE.md *and* lazy-loading skills
   compounds in cache stability gains beyond the sum of individual
   savings.

6. **Snapshot, not stream.** README numbers are a single snapshot.
   The audit instrument re-computes them from current data on every
   run.

7. **Platform incidents matter.** Periodically, LLM platforms ship
   regressions. The case study in `examples/case-study-2026-04-28/`
   documents one operator's experience inside the 2026 March-April
   Anthropic cache regression — including how to detect, attribute,
   and report platform-induced anomalies in your own audit.

If you find an error in this math, open an issue with your
computation. This document is versioned with the repo. PRs welcome.
