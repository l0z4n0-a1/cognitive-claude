---
doc_type: limitations
audience: [reviewer, hostile-reader, future-self]
prerequisite: ../README.md
purpose: the strongest counter-arguments against this framework, stated by the framework's author
---

# LIMITATIONS — what this framework does not prove

This document exists because every framework has structural limits,
and the honest move is to state them in the framework's own voice
before a reviewer states them louder.

If you have read the README and the case study and you came away
thinking *"this is suspicious — too many round numbers, too clean a
story"* — you are reading the framework correctly. The limits below
are the parts I would attack first if this were not my own work.

The README and case study deliberately do not bury these. This
document collects them in one place so they are easy to cite and
hard to miss.

---

## 1. The leverage number is largely plan-vs-API arbitrage, not framework-induced savings

**The claim under attack.** The case study reports an ~84× ratio of
API-equivalent cost to plan paid. The natural inference — which the
framework deliberately does not encourage — is *"this framework
saved me 83 dollars per dollar paid."*

**Why that inference is wrong.** The Anthropic Pro and Max plans are
flat-rate subscriptions priced significantly below the cumulative
API cost of heavy use. **Any** Claude Code operator who:

- Maintains stable system prompts (so cache reads dominate)
- Avoids mid-session config changes (so the cache survives)
- Uses the plan to its capacity

…will see a large plan-vs-API ratio. With or without this framework.
The mechanism is **the cache pricing structure** (cache reads cost
~10× less than fresh input) combined with **the flat-rate plan**.
This is structural, not authored.

**What the framework actually contributes.** Not dollars. **Discipline.**

- The instrument (`tools/cost-audit.py`) lets you *measure* the
  ratio with a defensible formula instead of asserting it.
- The Constitution (`CLAUDE.md`) plus the cache-guard hook protect
  the prefix from drifting, so the ratio you measure is the ratio
  you sustain.
- The case study separates platform-incident-driven cost from your
  own workload, so the ratio you publish is defensible against a
  reviewer who notices the regression window.

A useful framing: **the framework does not earn the leverage; it
makes the leverage measurable, attributable, and defensible.**
Without the instrument, the ratio is unfalsifiable — there is no
defined formula, no reproducible derivation, no audit trail. The
framework's contribution is the falsifiability, not the ratio
magnitude.

**Falsification test.** A controlled A/B — same operator, same
workload, framework off vs. framework on, measured for ≥30 days —
would identify the framework's incremental contribution to the
ratio. **This case study does not include such an A/B.** That work
is open. Until it exists, treat the ratio as a *workload property
made visible by the framework*, not an *outcome caused by the
framework*.

---

## 2. N=1 — one operator, one workload, no replication

**The claim under attack.** The framework targets specific metric
ranges (≥90% cache hit, ≥50% sub-share, ≤$0.50/turn for heavy Opus)
and a single case study reports values consistent with those targets.

**Why N=1 is a real ceiling.** The single operator who designed the
framework also collected the only data, also chose which days to
exclude, also chose which metrics to publish. Every degree of
analyst freedom — what to measure, when to measure, what to call
baseline — is held by the same person whose reputation rises if the
numbers are flattering.

This is not bad faith. This is the structural problem with any solo
artifact: *the absence of a second operator's run does not prove the
framework works for them.*

**What this case study shows.** That the framework is **internally
consistent** — every claim resolves to a file or a run, the math
works, the metric definitions are stable. That is necessary but not
sufficient.

**What this case study does not show.** That the framework
**generalizes**. To prove generalization requires:

- ≥3 independent operator reproductions, each publishing their own
  evidence pack
- Coverage of at least Sonnet-default and Pro-plan profiles, not
  just heavy-Opus / Max
- Failure cases (operators who tried it, found it didn't help,
  documented why)

The `examples/` directory invites contributions exactly to address
this gap. Until ≥3 case studies exist, generalization is a
hypothesis.

**Until then, the honest framing is:** *one operator measured this;
your numbers will be different; the methodology is what transfers.*

---

## 3. Output quality, time-to-completion, and operator load are not measured

**The claim under attack.** The framework optimizes cache discipline,
sub-agent delegation, and cost-per-turn. It is silent on whether
the outputs Claude produces are *better* — by any measure.

**What is not measured here.**

- **Output quality.** The framework can drive cost-per-turn down
  while output quality also drops, and the instrument would not
  notice.
- **Time-to-completion.** A session that costs 50% less but takes
  3× as long is worse on the dimension most operators actually care
  about.
- **Operator cognitive load.** Maintaining the discipline (avoiding
  cache breaks, routing models per agent class, weekly telemetry
  review) is itself a tax on attention. The framework recommends a
  weekly review ritual; the time cost of that ritual is not
  budgeted in the leverage number.
- **Bug rate / regression rate.** Whether code produced under this
  framework breaks production more or less often than code produced
  without it.

**Why this matters.** A framework that optimizes the wrong metric
is worse than no framework — it gives you false confidence that you
are improving when you are trading one cost for another.

**The honest framing.** This is a framework for **token economy and
attribution discipline**, not for **engineering quality**. If the
metrics it optimizes are not the metrics you care about, **save
yourself the install** (the README's "When this fails" section
attempts to surface this filter).

**What would close the gap.** Pairing the audit instrument with at
least one quality signal (test pass rate per session, lint
violations per turn, time-to-merge for PRs touched by Claude). Open
work. Contributions welcome.

---

## 4. Three concurrent platform changes; clean attribution is impossible

**The claim under attack.** The case study attributes ~$12,700 of
the operator's 90-day spend to the 2026-03-26 → 2026-04-10 cache
regression.

**Why clean attribution is hard.** The same window contains:

- The cache regression (Mar 26 → Apr 10)
- The 2× usage promotion (Mar 13 → Mar 27, *partly* in window)
- The reasoning-effort default change (medium until Apr 7, then back
  to high)

Three platform changes overlap. The case study attributes the excess
to the cache bug because (a) the daily $/turn spike is sharp and
synchronized with the bug's published date, (b) the post-fix
elevated $/turn is consistent with the reasoning-effort revert (more
reasoning per turn, not regression), (c) the 2× promo would lower
the operator's *plan* cost, not raise their *API-equivalent* cost.

But that reasoning is **post-hoc and identification-weak**. With
three concurrent treatments and no control, the exact decomposition
is unidentifiable from this operator's data alone.

**The honest framing.** $12,700 is the **upper bound** for cache-
bug-attributable cost. The lower bound is closer to **$8,000–
$10,000** after stripping plausible co-confounders. The exact
number requires a controlled comparison the case study does not
have.

**What would close the gap.** Either Anthropic's internal usage
analytics (which they do not publish) or a multi-operator panel
(which would average out individual workload variation). Both are
beyond the scope of one operator's case study.

---

## 5. The schema discontinuity makes pre-W13 sub-share look fake

**The claim under attack.** The case study reports 71% sub-agent
work share over 90 days.

**Why the number is misleading.** Around 2026-03-23 (Claude Code
v2.1.86), the JSONL `isSidechain` field semantics changed. Pre-2.1.86
files have `isSidechain=true` on nearly every assistant record,
making sub-share appear at ~100% when measured by that field. The
framework correctly switches to filename-based detection
(`agent-*.jsonl`) for the canonical metric — but the *filenames*
themselves were also affected by older Claude Code's tendency to
file most main-thread work under `agent-*` style names.

**Result:** the 71% 90-day average is dominated by pre-W13 weeks
where the filename-based number reads ~100%. The post-W13 stable
signal — the actual delegation rate in this operator's current
workflow — is **30–40%**.

**The honest framing.** When you read "71% sub-agent share" in the
case study, read also Section 6's per-week table. The 71% is a
historical-mean artifact; the 30–40% is the current behavior.
Neither is wrong — they answer different questions.

---

## 6. The ratio of "skin in the game" to "claims made" is one-to-many

**The claim under attack.** The repo includes 11 lessons in
`META_LEARNINGS.md` and a 17-page case study. That much narrative
suggests certainty.

**Why this is suspect.** The narrative is grounded in one operator's
experience. Each lesson is real *to him*. Generalizing each lesson
to *anyone running Claude Code seriously* is the kind of leap a
careful reviewer should resist.

**The honest framing of the lessons.** They are **patterns the
operator observed**, paired with **mechanisms that would explain
them if they generalize**, paired with **trust signals you can
check in your own data**. They are framed as *patterns to look for*,
not *truths to accept*. If you check your own telemetry and the
pattern is not there, the lesson is not violated — it just did not
apply to you. Read META_LEARNINGS in that spirit.

**Where to be most skeptical.** Lessons that lack a trust signal in
the audit instrument (lesson 7 on MCPs, lesson 11 on skin-in-the-
game) are normative arguments, not measurements. The instrument
will not tell you they are true.

---

## 7. The hooks have not been audited by anyone outside the operator

**The claim under attack.** The repo's SECURITY.md is unusually
honest about the prompt-injection surface in `INSTALL_PROMPT.md`,
but no third party has audited the bash hooks or the Python
instrument.

**What this means.** The author has run all of these in production
daily for months without incident. That is not the same as
*third-party verified safe*. A subtle bug in `telemetry.sh` could
be capturing data the README does not disclose — the only check on
that is reading the source yourself, which the SECURITY.md
recommends.

**Mitigations the framework does ship.** Telemetry redacts common
secret patterns before write (added in v0.1; see `hooks/telemetry.sh`).
INSTALL_PROMPT.md is checksum-pinned in the README so a malicious
fork is harder to slip past. The hooks live entirely in
`~/.claude/hooks/`, never call external APIs, never escalate
beyond the Claude Code shell user's privileges.

**What is open.** A formal external audit. A security advisory
process beyond best-effort. CI that runs `shellcheck` on every
hook change.

---

## 8. The framework does not survive a hostile fork

**The claim under attack.** The Claude-native installer (`INSTALL_PROMPT.md`)
lets your own Claude Code instance read a markdown file and install
the framework. This is the framework's clearest architectural
move — the LLM that benefits from the framework is the LLM that
installs it.

**What this enables.** A malicious fork can replace the install
protocol with arbitrary shell. SECURITY.md discloses this risk and
recommends three mitigations (clone from canonical URL only, read
the file before invoking it, prefer manual install if you cannot
verify). README publishes the SHA-256 of `INSTALL_PROMPT.md` so a
fork's mismatch is detectable in one command.

**What is not solved.** Operators who clone forks without checking,
who skip the SECURITY.md read, or who trust the markdown file
because it looks like the original — those operators are exposed.
The framework is convenient. Convenience is the threat.

**The honest framing.** If you cannot read 360 lines of bash and
markdown before letting them touch `~/.claude/`, do not install.
The framework's position is *operator literacy is the prerequisite*,
not *we made it safe regardless of operator literacy*.

---

## What the framework does claim, and what would falsify it

### What is claimed

1. The seven invariants (cache stability, instrument hierarchy,
   sub-agent delegation, model routing, telemetry-first, etc.) are
   **internally consistent** in this operator's 90-day workload.
2. The audit instrument **reproduces** every numerical claim in the
   case study from the operator's own logs.
3. The Constitution (`CLAUDE.md`) **shapes** how Claude Code reasons
   in this operator's daily use — the operator runs the same
   Constitution he distributes (modulo trailing newline).
4. The cache-rate-can-rise-during-regression pattern is **observable**
   in this operator's telemetry and is **consistent** with the
   Anthropic postmortem mechanism.

### What would falsify each claim

1. A reviewer running `cost-audit.py` against the operator's
   committed `EVIDENCE.json` who finds different numbers.
2. A diff of the operator's `~/.claude/CLAUDE.md` against the
   repo's `CLAUDE.md` showing meaningful (not trailing-newline)
   divergence.
3. A second operator publishing a case study with the framework
   enabled and showing **no** improvement over their pre-framework
   baseline. (Falsifies generalization, not internal consistency.)
4. A re-read of the postmortem that reveals the case study's §7
   mechanism is wrong. (Section 7 has been re-read after one
   adversarial review and rewritten; further corrections welcome
   via PR.)

If you find any of those, open an issue. The repo improves under
correction; that is the only kind of repo worth maintaining in
public.

---

## Where to go from here

- The **README** is the entry point.
- The **architecture doc** (`docs/ARCHITECTURE.md`) explains the
  design decisions behind each primitive.
- The **math doc** (`docs/MATH.md`) derives every claim.
- The **case study** (`examples/case-study-2026-04-28/CASE_STUDY.md`)
  is the receipt.
- The **meta-learnings** (`docs/META_LEARNINGS.md`) is what running
  the system over months teaches.
- This document is what you should read **alongside** the case
  study, not after — its caveats reframe the case study's numbers.

If you have read all six of those documents and you still want to
install: you are the operator the framework is for. Read SECURITY.md
once more, then start with Phase 1.

If any of the limits above feels disqualifying for your context:
the framework is honest about not being for you. Take what
generalizes (the principles in `ARCHITECTURE.md` §6.1), skip the
install. That is the right trade.
