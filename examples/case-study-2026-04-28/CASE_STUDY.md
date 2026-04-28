---
doc_type: case-study
status: example, not framework canon
audience: [operator-considering-the-framework, llm-engineer, reviewer]
prerequisite: ../../README.md
purpose: one operator's 90-day Claude Code economics, with platform-incident detection methodology
data_source: ~/.claude/projects/**/*.jsonl (8,512 files, 498,587 lines)
snapshot_date: 2026-04-28 (UTC)
window: 90 days (2026-01-29 → 2026-04-28)
evidence_pack: ./EVIDENCE.json (sha256: b2145b871ae5c57a1646e01ea5741e43bf70653d8120289264cc4ff2686f0429)
---

# CASE STUDY — A 90-Day Snapshot

> ⚠️ **This is one operator's case study, not framework canon.**
> The framework lives in `/CLAUDE.md`, `/docs/MATH.md`, `/tools/`,
> and `/hooks/`. The numbers below are not what you should expect to
> see — they are what one operator measured. **Run
> `tools/cost-audit.py` against your own data for your own numbers.**
> Project names are anonymized (Project A–N). The methodology is the
> transferable contribution; the values are this operator's receipts.

This document exists to demonstrate the methodology that the
framework prescribes:

- How an operator separates own-workload baseline cost from a
  platform-confirmed incident.
- How to read a per-project breakdown (and the double-counting
  property of the `subagents/` virtual project).
- Why cache hit rate alone can mislead during a regression, and
  what to pair it with.
- What a real 90-day window looks like under three concurrent
  Anthropic platform changes (cache regression, reasoning-effort
  drop, 2× usage promotion).
- The honest separation of *framework contribution* (measurement
  and attribution discipline) from *plan-vs-API arbitrage* (which
  exists for any heavy user with or without this framework).

It is the receipt that backs the README's headline numbers — and the
template another operator can use to publish their own.

---

## 1. Data source and methodology

**Source:** `~/.claude/projects/**/*.jsonl` on the operator's local
machine. **8,512 files, 498,587 lines.** Span: 2026-01-09 → 2026-04-28
(110 days raw; 88 days with assistant activity in raw span).

**Window for this snapshot:** 90 days = **2026-01-29 → 2026-04-28**,
**72 active days**. Time filtering uses per-record `timestamp`, not
file mtime — see [`docs/MATH.md`](../../docs/MATH.md) Section 0.

**Instrument:** [`tools/cost-audit.py`](../../tools/cost-audit.py)
reads those files, applies the canonical metric definitions in
[`docs/MATH.md`](../../docs/MATH.md) Section 0, and produces every
number in this document. The full evidence pack used to generate
this case study is committed alongside it as
[`EVIDENCE.json`](./EVIDENCE.json) (sha256 in frontmatter).

**Reproducibility floor:** Every number here is reproducible by any
operator running the same instrument against their own data:

```bash
python3 tools/cost-audit.py --window 90 --evidence > my-evidence.json
```

**Pricing:** Anthropic public API rates as of 2026-04-28
([docs.anthropic.com/en/docs/about-claude/pricing](https://docs.anthropic.com/en/docs/about-claude/pricing)).

**A note on snapshot drift.** This case study reports values frozen at
the snapshot date in frontmatter. The same instrument run a week
later will produce different numbers. That is expected; the
*methodology* is the contract, not the values.

---

## 2. Operator profile

| | |
|---|---|
| Plan history | Pro $100/mo (~1 month) → Max $200/mo (~2 months) |
| Approximate paid total | ~$500 over 3 months |
| Workload pattern | Heavy-Opus, multi-project, solo, public-facing |
| Active projects in 90d window | 50+ unique project directories |
| Top 5 projects | ~89% of total cost concentrated |
| MCPs enabled | 0 active during the window |

This is **one operator**. Generalize cautiously.

---

## 3. The 90-day economic summary

```
Window:                  2026-01-29 → 2026-04-28 (72 active days)
Sessions:                987
Assistant turns:         199,133
Tokens billable:         19.46B (input + cache_read + cache_write)
Tokens output:           60.4M
API-equivalent cost:     $42,148
Cache hit rate:          91.74%
Sub-agent turn-share:    71.4% (turns in agent-*.jsonl / total turns)
Sub-agent cost-share:    ~43%  (cost in subagents/ dir / window cost; see §9)
Cost per turn (API):     $0.2117
Models (by turn):        52.5% Opus / 19.9% Sonnet / 27.6% Haiku
Median turns/session:    112
Mean turns/session:      205   (heavy right-tail; use median for sizing)
```

**Plan paid (~$500):** ratio of API-equivalent cost to plan paid =
**~84×**.

**A critical reframe.** That ratio measures *plan-flat-rate vs.
API-list-price arbitrage*. Most of it exists for any heavy Claude
Code user with stable context, with or without this framework. The
framework's contribution is not the ratio's magnitude — it is the
**discipline that makes the ratio measurable, attributable, and
defensible**. See [§11](#11-what-this-case-study-actually-demonstrates)
for the explicit separation.

---

## 4. The platform incidents inside the window

Three Anthropic-confirmed events affected Claude Code during this
window. Source:
[anthropic.com/engineering/april-23-postmortem](https://www.anthropic.com/engineering/april-23-postmortem).

| Date (UTC) | Event | Source |
|------------|-------|--------|
| 2026-03-04 | Reasoning effort default lowered high → medium | Postmortem |
| 2026-03-13 | 2× usage promotion START (off-peak weekdays + 24/7 weekends) | [support.claude.com/articles/14063676](https://support.claude.com/en/articles/14063676-claude-march-2026-usage-promotion) |
| 2026-03-26 | **Cache bug shipped** — `clear_thinking_20251015 + keep:1` | Postmortem |
| 2026-03-27 | 2× usage promotion END | Anthropic announcement |
| 2026-04-07 | Reasoning effort REVERTED to high (xhigh for Opus 4.7) | Postmortem |
| 2026-04-10 | **Cache bug fixed** | Postmortem |
| 2026-04-16 | Verbosity-reduction prompt added (regression) | Postmortem |
| 2026-04-20 | All fixes live in v2.1.116 | Postmortem |
| 2026-04-23 | Postmortem published | Anthropic engineering blog |

The cache bug is the most consequential event for token economics.
The mechanism, quoted from the postmortem:

> "The implementation had a bug. Instead of clearing thinking history
> once, it cleared it on every turn for the rest of the session. […]
> The repeated dropping of thinking blocks likely caused cache misses.
> A cache miss means prior context cannot be reused cheaply and has
> to be processed again as fresh input."

Independent community researchers (cnighswonger,
[claude-code-cache-fix](https://github.com/cnighswonger/claude-code-cache-fix))
reverse-engineered the binary and reported up to 20× cost increase
on resumed sessions in their test conditions.

Anthropic shipped the bug **2026-03-26**. In this operator's data,
the inflation pattern emerges starting **2026-03-29** — a 3-day
delay consistent with a weekend gap before resumption-heavy work.
The bug was officially fixed on **2026-04-10**.

The window **2026-03-29 → 2026-04-09** (12 days) is therefore treated
as the **observed bug window** for this operator.

**Three events overlap in this window**, not one. Section 5 attributes
excess cost to the cache bug only when (a) the date falls inside the
12-day bug window AND (b) the daily $/turn deviates >2× from pre-bug
baseline. The attribution is **a bound, not a point estimate** — see
the conservative-vs-attributed framing below.

---

## 5. Cost split: baseline vs platform-bug spike

Reproducible from `EVIDENCE.json` `daily_timeseries`:

```
                    Days  Turns      Cost      $/turn   $/day   CHit%   Sub%
─────────────────────────────────────────────────────────────────────────────
Pre-bug baseline      46  111,769  $12,284   $0.110   $267    85.3%   100%*
Observed bug window   12   50,993  $15,918   $0.312   $1,326  95.5%    37%
Post-fix              14   36,371  $13,946   $0.383   $996    94.4%    31%
─────────────────────────────────────────────────────────────────────────────
90d in-window total   72  199,133  $42,148   $0.212   $585    91.7%    71%
90d excluding bug     60  148,140  $26,230   $0.177   $437    89.3%    83%
```

\* See [§6](#6-the-schema-discontinuity-claude-code-2186) for the
schema discontinuity that makes pre-W13 sub-share appear as 100%.
The real pre-W13 sub-share is unrecoverable from the JSONL flag and
is likely comparable to post-fix (~30–40%).

### Bug-attribution math (and its limits)

**Direct excess attribution.** If the 12 bug-window days had run at
pre-bug $/day rate ($267), they would have cost ~$3,200. They cost
$15,918. Excess = **~$12,700**.

**Co-confounder caveat.** Two other Anthropic platform changes touch
this same window:

1. The 2× usage promotion ran 2026-03-13 → 2026-03-27 — partly
   *before* the bug window. It encouraged heavier use on off-peak
   slots, which can elevate `$/day` independently of the bug.
2. The reasoning-effort default was at *medium* from 2026-03-04 to
   2026-04-07 — overlapping the bug window. Reverting to *high* on
   2026-04-07 partly explains why post-fix `$/turn` ($0.38) stays
   *higher* than the bug window ($0.31): more reasoning means more
   tokens per turn, even after the bug was fixed.

**Honest framing.** The $12,700 excess is the upper bound for cache-
bug-attributable cost; the lower bound (after stripping reasoning-
effort and promotion effects) is closer to **$8,000–$10,000**. The
exact decomposition is unidentifiable from this operator's data
alone — that requires a controlled A/B that this case study does not
have. See [`docs/LIMITATIONS.md`](../../docs/LIMITATIONS.md).

**Cnighswonger's "20× cost increase" vs this operator's 2.84× spike
($0.312 / $0.110).** The 7× discrepancy is most likely explained by
workload mix: cnighswonger's reproduction targeted resume-heavy
sessions (where the bug bites hardest); this operator's mix included
many fresh sessions that were unaffected. **Both numbers can be true
in their own contexts.**

---

## 6. The schema discontinuity (Claude Code 2.1.86)

Around the W13 ISO week (2026-03-23) — coinciding with Claude Code
version 2.1.86 — the JSONL schema changed how the `isSidechain`
field was populated:

| Pre-2.1.86 | Post-2.1.86 |
|------------|-------------|
| Almost all assistant records have `isSidechain=true` | Records split: main thread = `false`, sub-agent context = `true` |
| Cannot distinguish main vs sub from this field | Field becomes semantically reliable |

**Filename pattern is stable across versions:**

- Files named `agent-*.jsonl` are sub-agent contexts (regardless of version).
- Files named `<uuid>.jsonl` are main-thread sessions.

**Decision:** in this repo, "sub-agent work share" is computed from
**filename pattern**, not from the `isSidechain` field. This is the
stable cross-version metric. Confidence: HIGH.

Per-week sub-share trend (filename-based, after schema reform):

```
W13 (Mar 23–29)    71.1%  ← schema reform week
W14 (Mar 30–Apr 5) 40.0%  ← bug active
W15 (Apr 6–12)     23.6%  ← bug fix transition
W16 (Apr 13–19)    39.2%  ← post-fix stable
W17 (Apr 20–26)    31.3%  ← v2.1.116 clean
W18 (Apr 27–28)     7.2%  ← partial week
```

Pre-W13 sub-share is reported as 100% because almost all records
were marked sidechain by the older schema; the underlying real share
was likely close to the post-W13 range (30–40%).

**Implication for the headline 71.4% sub-share.** The 90-day average
is dominated by pre-W13 weeks where filename-based sub-share is
~100% (an artifact of how Claude Code wrote files in that version).
The post-W13 sub-share is the stable signal: **30–40%** in this
operator's workload. The 71% headline overstates the post-W13
delegation rate. **This is a schema property, not a measurement
error — but it must be disclosed.**

---

## 7. Cache hit rate behavior — why the bug raised the visible ratio

Counter-intuitive but explained by the bug mechanism. Daily cache
hit rates (definition: `cache_read / (cache_read + input + cache_write)`):

```
Pre-bug:           ~85% mean (range 70%–92%)
Bug window:         95.5% (sustained)
Post-fix:           94.4% (sustained)
```

### The actual mechanism

The Anthropic postmortem describes the bug as causing **cache misses**:
"The repeated dropping of thinking blocks likely caused cache misses.
A cache miss means prior context cannot be reused cheaply and has
to be processed again as fresh input."

So during the bug:
- `input` (fresh tokens re-processed) — **rose** sharply
- `cache_write` (the system rebuilding the cache after each miss) —
  **rose** sharply
- `cache_read` (reads against the partial cache that did survive) —
  **also rose** because resumed sessions kept hitting the cache *for
  the parts that were cached* before the next eviction

In the ratio `cache_read / (cache_read + input + cache_write)`, **all
three terms grew**. The numerator grew faster than the denominator on
this operator's workload because heavy resumption traffic concentrated
in the surviving cached prefix while the bug churned the volatile
parts. Result: the **ratio rose**, while the **underlying efficiency
collapsed** (each unit of useful work cost 2.84× more).

### Why this matters

Cache hit rate is a **ratio**. Ratios can be moved by either
numerator or denominator, in either direction. A bug that pumps
*both* the cached and the fresh-input pools — even by different
amounts — can produce a misleading ratio.

The flow metric **$/turn** has no denominator-game vulnerability. It
is dollars-per-thing-done. During the bug window it rose 2.84×
($0.110 → $0.312). Post-fix it rose further to $0.383, dominated by
the reasoning-effort revert (Apr 7) which is a workload-shift
explanation, not a regression.

**The trust hierarchy during incident windows:**

1. **$/turn** — flow metric, ungameable by cache mechanics
2. **tokens/turn** — workload composition signal
3. **cache hit rate** — useful for prefix-stability detection in
   normal operation; **unreliable as a single efficiency metric**
4. **session count** — volume signal, useful for normalization

The post-fix sustained 94.4% cache hit rate is the genuine indicator
of a stable prefix in the new equilibrium. The pre-bug 85% suggests
the operator's pre-March cache discipline had headroom that was
being recovered before the bug hit.

**Reconciliation with cnighswonger's binary analysis.** The community
fork's "20× cost increase" figure refers to *cost per resumed
session*, not cost per turn. On a fresh session the bug had little
effect; on a long-resumed session with many thinking blocks it could
be catastrophic. Both metrics are true; they measure different
things.

---

## 8. Daily timeseries (ASCII)

Daily $/turn over 72 active days (sparkline rendered by
`cost-audit.py --charts`). Bug-window days marked `★`.

```
                                  Mar 26 cache bug shipped       Apr 23
                                  │                              │ postmortem
                                  │              Apr 10 fix      │
                                  │              │               │
$0.75 ─────────────────────────────────────────────────────────────────
$0.50 ──────────────────────────────────────█──██──██─────────█──█████
$0.25 ─────────█─────────────────█───────████████████████████████████─
$0.10 █████████████████████████████████████████████████████████████████
$0.05 █████████████████████████████████████████████████████████████████
       │  │  │  │  │  │  │  │  │  │  │  │  │  │  │  │  │  │  │  │  │
       Jan        Feb               Mar           ★bug window★       Apr
                                                  ████████████
```

For your own version of this chart:

```bash
python3 tools/cost-audit.py --window 90 --charts
```

Numeric sample (most informative weeks):

| Week | $/turn (mean) | Comment |
|------|---------------|---------|
| W02–W08 | $0.07–$0.15 | Pre-bug baseline. Heavy use, low cost/turn. |
| W09–W11 | $0.12–$0.17 | Pre-bug, slight upward drift |
| W13 | $0.10–$0.21 | Schema reform week; reasoning-effort still low |
| **W14** | **$0.25–$0.27** | **Bug active, sustained spike** |
| W15 | $0.27–$0.60 | Bug + reasoning revert overlap |
| W16 | $0.24–$0.45 | Post-fix; verbosity-reduction prompt 04-16 |
| W17 | $0.41–$0.69 | v2.1.116 clean; reasoning-effort fully reverted |
| W18 | $0.61–$0.74 | Heavy main-thread workload, post-fix equilibrium |

Why $/turn stays elevated post-fix even when cache hit rate is high:
the operator's mix shifted toward heavier main-thread use (40% → 32%
sub-share) on Opus-dominant tasks (reasoning effort reverted to high).
Post-fix turns are intrinsically more expensive because each turn
carries more reasoning context. **This is not a regression — it is
workload evolution and platform-default change.**

---

## 9. Project concentration

Top 10 projects by API-equivalent cost (anonymized), including the
`subagents/` directory bucket where all sub-agent contexts are filed:

```
project (anonymized)               cost      share*  turns
─────────────────────────────────────────────────────────────
subagents (all agent-*.jsonl)    $18,172    40.2%   163,145
Project A                         $8,306    18.4%    16,970
Project B                         $6,064    13.4%    12,635
Project C                         $5,769    12.8%    13,735
Project D                         $1,865     4.1%     4,339
Project E                         $1,190     2.6%     1,369
Project F                           $879     1.9%     1,834
Project G                           $856     1.9%     1,848
Project H                           $447     1.0%       749
Project I                           $428     0.9%     1,210
─────────────────────────────────────────────────────────────
Top 10 sum                       $43,976    97.2% of $45,236 raw
```

\* "Share" is computed against the **raw cost universe of $45,236**
that Claude Code records across `~/.claude/projects/` for the file
span (2026-01-09 → 2026-04-28, 110 calendar days). This differs
from the **window total of $42,148** reported in §3 by **$2,878**;
the difference is cost from records that fall *outside* the
strict 90-day window (Jan 9–28). The `--by-project` output of
`cost-audit.py` operates on the file span, not the window — a
known schema property of the instrument.

**Each turn is counted exactly once.** Each JSONL file lives in
exactly one project directory (`tools/cost-audit.py:252` does
`project_name = os.path.basename(os.path.dirname(fp))`). The
`subagents/` row is a sibling directory bucket, not an aggregator
that double-counts costs from other projects. Summing all rows
yields the universe; no row contributes to any other row.

**The honest read of the 90-day window** ($42,148 total, in-window):

- **Main-thread cost** (all rows excluding `subagents/`, in-window only): ~$24,000
- **Sub-agent context cost** (`subagents/` row, in-window only): ~$18,000
- These two are mutually exclusive (different files, different
  directory) and sum (within rounding) to the window total.

**Two valid sub-agent share metrics** that answer different questions:

- **Turn-basis sub-share: 71.4%** — the fraction of *assistant turns*
  that ran inside `agent-*.jsonl` files. Reported in §3 as the
  headline.
- **Cost-basis sub-share: ~43%** — the fraction of *API-equivalent
  dollars* spent inside `subagents/`. Reported here.

The 28-point gap between turn-basis and cost-basis is **the
operator's model-routing discipline made visible**: sub-agents are
routed predominantly to Haiku (~18.75× cheaper than Opus per
token), so they consume most turns at a small fraction of the
spend. Both numbers are real; both are honest; neither tells the
whole story alone.

Project names are redacted; only the distribution shape matters for
generalization.

**Concentration conclusion:** the shape of solo-multi-project work
is consistent with Pareto — a few deep workstreams dominate, many
quick tasks orbit them. Top 9 main-thread projects (excluding
`subagents/`) account for ~57% of the raw universe; including
`subagents/` and the long tail brings it to 97.2%. The framework's
project-concentration discipline (audit the top 5 weekly; the long
tail can run with default settings) follows directly from this shape.

---

## 10. Session size distribution

```
n          = 1,085 unique sessions in raw span
mean       = 205 turns/session
median     = 112 turns/session
p25        = ~21
p75        = ~257
p95        = ~873
max        = 6,442 turns in a single session
```

The mean-vs-median gap (205 vs 112) signals heavy right-tail: a
small number of multi-thousand-turn architecture sessions skew the
mean upward. **Use median for sizing assumptions, not mean** — the
mean is dominated by outliers that are not representative of typical
work.

The framework's CLAUDE.md tax math (e.g., "5,000 tokens × ~150 turns
= 750k tokens of overhead per typical session") uses median as the
typical-session anchor. See [`docs/MATH.md`](../../docs/MATH.md)
Section 3 for the derivation and [`docs/LIMITATIONS.md`](../../docs/LIMITATIONS.md)
for the heavy-tail caveat.

---

## 11. What this case study actually demonstrates

Narrative claims the README header makes, audited against this data:

| Claim in README | Status | Evidence |
|---|---|---|
| Headline 90d snapshot numbers | ✅ exact | Sections 3, 5; `EVIDENCE.json` |
| ~71% sub-agent turn-share (90d aggregate) | ⚠️ schema-affected | §6: pre-W13 weeks read as ~100% sub-share due to historical filename convention; post-W13 stable signal is **30–40%**. The 71% headline is dominated by the historical artifact. Cost-basis sub-share is **~43%** (§9). |
| 52% Opus / 20% Sonnet / 28% Haiku routing | ✅ exact | Section 3 |
| ~$0.21 cost/turn (API-equivalent) | ✅ exact | Section 3 |
| ~84× plan-vs-API ratio | ✅ exact | Section 3 with reframe |
| Numbers are partially platform-affected | ✅ declared | Sections 4, 5 |

What this case study **does not** demonstrate (declared upfront):

- That the framework *causes* the leverage. The 84× plan-vs-API
  ratio is largely *plan-flat-rate vs. API-list-price arbitrage*
  that exists for any heavy Claude Code user with stable context,
  with or without this framework. The framework's contribution is
  **measurement and attribution discipline**, not dollars saved.
  See [`docs/LIMITATIONS.md`](../../docs/LIMITATIONS.md) §1.
- That the seven invariants will produce comparable numbers for
  any operator. (N=1.) See [`docs/LIMITATIONS.md`](../../docs/LIMITATIONS.md) §2.
- That sub-agent delegation is universally optimal. (Workload-
  dependent.)
- That cache hit rate alone is a sufficient health metric.
  (Section 7 shows it can rise during a regression.)
- That the model routing in this snapshot is optimal for any other
  workload. (Heavy-Opus operator profile is specific.)
- That output quality, time-to-completion, or operator cognitive
  load improved. **The framework optimizes cache discipline and
  cost discipline. It does not measure quality.**
  See [`docs/LIMITATIONS.md`](../../docs/LIMITATIONS.md) §3.

The architecture is the contribution. The numbers are the receipt.
**The receipt does not prove the architecture caused the numbers** —
it proves the architecture *is consistent with* the numbers, and
provides the instrument anyone can use to test their own data.

---

## 12. How to reproduce

```bash
git clone https://github.com/l0z4n0-a1/cognitive-claude.git
cd cognitive-claude

# Run the canonical instrument against your own data
python3 tools/cost-audit.py --window 90 --verbose

# JSON evidence pack (re-derive every section in this document)
python3 tools/cost-audit.py --window 90 --evidence > my-evidence.json

# Compare your snapshot to this one's hash
sha256sum examples/case-study-2026-04-28/EVIDENCE.json
```

The JSON evidence pack is the input that produced every chart and
table in this case study. If your evidence pack differs from the
snapshot here, your workload differs. **The methodology transfers;
the values do not.**

---

## 13. Sources cited

- [Anthropic engineering postmortem (Apr 23, 2026)](https://www.anthropic.com/engineering/april-23-postmortem) — official confirmation of all three regressions
- [Claude March 2026 usage promotion (support.claude.com)](https://support.claude.com/en/articles/14063676-claude-march-2026-usage-promotion) — 2× usage promo announcement and dates
- [HN discussion of postmortem](https://news.ycombinator.com/item?id=47878905) — independent community technical analysis
- [DevClass — usage limits "way faster than expected" (Apr 1, 2026)](https://www.devclass.com/ai-ml/2026/04/01/anthropic-admits-claude-code-users-hitting-usage-limits-way-faster-than-expected/5213575) — early reporting of the bug
- [GitHub: claude-code-cache-fix (cnighswonger)](https://github.com/cnighswonger/claude-code-cache-fix) — community reverse-engineering of the cache bug
- [Anthropic API pricing](https://docs.anthropic.com/en/docs/about-claude/pricing) — pricing source for cost calculations

---

*Snapshot date: 2026-04-28. Document is versioned with the repo.
The operative date and current numbers may have drifted by the time
you read this. Run the instrument; trust your own data over this
snapshot.*
