---
doc_type: transfer-guide
audience: [operator-with-different-profile]
prerequisite: ARCHITECTURE.md (section 6)
purpose: practical adaptations for non-default operator profiles
---

# TRANSFER.md — Adapting cognitive-claude to your profile

`ARCHITECTURE.md` section 6 explains *what* transfers in principle.
This document gives *concrete* adaptation recipes for the four most
common profiles that differ from the author's setup.

If your profile matches the author (heavy Opus, solo, multi-project,
public-facing) — read `README.md` and install. You don't need this
document.

If your profile differs — start here.

---

## Profile A — Sonnet-default operator

**You:** Use Sonnet for most coding tasks. Opus only for hard
architectural calls. Cost matters but is not your primary concern.

**What changes:**

```
COMPONENT                  AS-IS              FOR YOU
─────────                  ─────              ───────
Constitution length        91 lines / 1.3k    Same. Independent of model.
Cache hit rate target      ≥ 90%              Same. Independent of model.
Sub-agent ratio target     ≥ 60%              Lower OK (40-50%) — Sonnet
                                              cheaper means main thread
                                              cost is less penal.
Cost/turn target (Max)     ≤ $0.005           Lower naturally (~$0.001).
                                              You'll hit target easily.
Headline ROI claim         189x               Will be 30-50x for you.
                                              Same shape, different magnitude.
Model routing table        Most agents Haiku  More agents on Sonnet OK
                                              for write-heavy tasks
                                              (Sonnet is your "free tier")
```

**What does not change:**

- All 8 Laws. They are model-agnostic.
- All 5 hooks. They observe / enforce regardless of model.
- The closed loop. Calibration works on any model.
- The decision flows in ARCHITECTURE.md section 4.

**Adaptation summary:** Install everything. Adjust your mental
expectation of "headline numbers" downward by ~3x. The architecture
is identical.

---

## Profile B — Pro plan operator (not Max)

**You:** $20/month Claude.ai Pro. Lower usage ceiling. Heavier
limits.

**What changes:**

```
COMPONENT                  AS-IS              FOR YOU
─────────                  ─────              ───────
Plan ROI framing           Franchise          Less franchise, more
                                              "rate-limited subscription"
                                              — Max is a bucket, Pro is
                                              a daily quota
Sub-agent emphasis         Critical           Even more critical — every
                                              wasted token gets you closer
                                              to the daily limit faster
MCP zero policy            Strong rec         Even stronger — you cannot
                                              afford schema tax on a
                                              tighter ceiling
Constitution discipline    Important          Most important component for
                                              you — every persistent token
                                              consumes daily quota
Cost/turn metric           ≤ $0.005           Not directly comparable
                                              (Pro is fixed, no marginal
                                              cost). Track tokens/turn
                                              instead.
```

**What does not change:**

- The Constitution itself.
- The hooks (all 5).
- The principles in ARCHITECTURE.md.

**Adaptation summary:** Install everything. Replace cost-per-turn
metric with tokens-per-turn target (~50k or lower). Be more
aggressive on MCP and skill discipline. Pro plan is where this
architecture pays off most in *experienced flow* (not hitting
limits) rather than in dollars.

---

## Profile C — Team setup (multiple operators)

**You:** A team of 3-15 developers all using Claude Code on a
shared codebase. Want consistent behavior across the team.

**What changes:**

```
COMPONENT                  AS-IS              FOR YOU
─────────                  ─────              ───────
Constitution location      Global             Project-level
                          (~/.claude/         (`<repo>/.claude/CLAUDE.md`)
                           CLAUDE.md)         versioned in git
Constitution governance    Solo decision      PR-reviewed change
Hook deployment            Manual per machine Bootstrap script in repo,
                                              run on `git clone`
Telemetry                  Personal           Personal (each developer's
                                              own data) — not aggregated
                                              by default
Skill catalog              Personal           Mix: shared skills in repo,
                                              personal skills in
                                              ~/.claude/skills/
Calibration loop           Solo              Per-developer (each runs
                                              their own delta tracking)
Settings drift            Personal audit     Team audit — diff settings
                                              per developer monthly to
                                              detect drift
```

**Concrete adaptations:**

1. **Move Constitution to project-level.** Replace `~/.claude/CLAUDE.md`
   with `<repo>/.claude/CLAUDE.md`. Now `git clone` propagates it.
2. **Bootstrap script in repo:**
   ```bash
   # bootstrap.sh
   ln -sf $(pwd)/hooks/*.sh ~/.claude/hooks/
   echo "Hooks symlinked. Add to ~/.claude/settings.json manually."
   ```
3. **Constitution PR review:** Any change to `.claude/CLAUDE.md`
   requires PR + 2 approvals. Treat it like architecture.
4. **Drift audit:** Monthly, compare each developer's
   `~/.claude/settings.json hooks` block. Differences are bugs
   or intentional experiments — both should be conscious.

**What does not change:**

- The 8 Laws.
- The principles.
- The hook contracts.

**Adaptation summary:** The architecture works for teams, but
adoption requires governance (PR review, bootstrap, drift audit).
Skip if your team won't sustain that discipline — solo operators
can be inconsistent with themselves and survive; teams cannot.

---

## Profile D — Casual / occasional Claude Code user

**You:** Use Claude Code <1 hour per day. Single sessions, single
projects. No pattern of returning to the same context.

**Honest answer:** Most of this architecture is overhead for you.

**What you should actually adopt:**

```
COMPONENT                  ADOPT?
─────────                  ──────
Constitution               No. Or a 20-line stripped version.
                           Your sessions are too short for the
                           tax to matter much.
Telemetry hook             Yes, run for 30 days. Then decide
                           if any of this matters for your usage.
Other 4 hooks              No. Overhead exceeds benefit.
Skill catalog discipline   No. You probably have <5 skills total.
MCP zero policy            Maybe. If you have 5+ MCPs and use 1,
                           audit. Otherwise ignore.
Sub-agent ratio            No. Most of your sessions are single-task,
                           no need to delegate.
Calibration loop           No. Without sustained sessions, no
                           signal to calibrate.
Decision flows             Yes — read ARCHITECTURE.md section 4.
                           Mental model transfers even if mechanism
                           doesn't.
```

**Adaptation summary:** Install Phase 1 (telemetry) only. Run for
30 days. Look at your numbers. If you're at 5+ hours/week of Claude
Code with rising usage, install Phase 2 then. Don't install Phase 3
until you've internalized the principles.

For genuinely casual use, the principles in ARCHITECTURE.md section
4 (decision flows) give you 80% of the benefit at 0% of the
overhead. That's the right trade for your profile.

---

## Profile E — Different harness (Cursor, Aider, Continue, etc.)

**You:** Use an LLM coding harness that is not Claude Code.

**What transfers literally:** Nothing in this repo runs on other
harnesses. Hooks depend on Claude Code's hook API. The Constitution
file format is Claude Code-specific.

**What transfers conceptually:** All seven principles in the
Constitution. The decision flows. The mental model.

**Translation guide:**

```
CLAUDE CODE              CURSOR                  AIDER
───────────              ──────                  ─────
~/.claude/CLAUDE.md      .cursorrules            .aider.conf.yml
                                                  + COMMIT_PROMPT
Hooks                    Not directly supported   Not directly supported
                         (use git hooks +         (use git hooks +
                          CI for similar effects) CI for similar effects)
Skills                   Custom rules /           --read flags +
                         system prompt sections   conventional commits
PostToolUse logging      Not native               Not native
                         (build a wrapper)        (build a wrapper)
```

For each missing primitive: ask "what is the cheapest enforcement
in *this* harness?" The cognitive-claude philosophy applies even
when the mechanism does not.

**Adaptation summary:** Read ARCHITECTURE.md, internalize the seven
principles, then implement them in your harness's idiom. The
architecture is the contribution — the Claude Code-specific hooks
are one realization of it.

---

## When to NOT adapt — the honest cut

Skip this entire architecture if:

- You use Claude Code <2 hours per week
- Your monthly LLM cost is <$30 and not growing
- You don't have telemetry or any way to measure your own usage
- You're trying to "optimize prematurely" before understanding
  your actual workload

The architecture pays off when usage is sustained, measurable,
and large enough that 30-50% efficiency gains compound to real
dollars or real time.

For everyone else: read ARCHITECTURE.md, take the principles, skip
the install. The mental model is the gift.
