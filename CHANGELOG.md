# Changelog

All notable changes to `cognitive-claude` are documented here.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).
Versioning follows [SemVer](https://semver.org/) once we leave `0.x`; until
then, `0.MAJOR.MINOR` increments at architectural changes (`MAJOR`) or
substantive additions / corrections (`MINOR`).

---

## [0.1.1] — 2026-04-28

Polish release. No breaking changes. The five-phase loop, telemetry
contract, and metric definitions are unchanged. This release closes
three documented gaps in v0.1.0: the L4↔L1 boundary was declarative
only (now enforced); the audit instrument had no end-to-end stress
test (now ships one); the Constitution stated eight Laws and an
implicit voice (now nine Laws and an explicit Voice & Stance section).

### Added

- **`docs/INVARIANTS.md`** — single-page cross-reference between
  Constitution Laws, MATH derivations, hook enforcement, and
  audit-instrument verification.
- **`docs/HANDBOOK.md`** — the field manual. Practical companion to
  the install: the day-one shifts, the 200k context wall, the boot
  ritual, the session-close ritual, the handoff between sessions,
  seven concrete trenches with their moves, and the 30-day "good"
  shape. Closes the gap between "I installed it" and "I live with
  it." Lazy-read, non-prefix, no token tax. Where META_LEARNINGS.md
  is the lecture, this is the field manual; both honor the same
  truth in different registers. Section 1 maps every invariant to
  its enforcement mechanism. Section 2 specifies the five canonical
  metric contracts (cache hit rate, sub-agent share, API-equivalent
  cost, cost per turn, leverage) with valid ranges and falsification
  tests. Section 5 states what would falsify each load-bearing claim.
  Lazy-loaded — zero prefix cost.
- **`hooks/tier-contradiction-guard.sh`** — PreToolUse hook on Edit
  / Write / NotebookEdit. Materializes the L1↔L4 boundary
  (`docs/ARCHITECTURE.md` §3.7, `docs/INVARIANTS.md` §3.1) by
  warning when a project-level `CLAUDE.md` write contains language
  the global Constitution explicitly negates. Heuristic, warn-only,
  fail-silent if the global is absent. Zero context-token cost.
- **`tools/stress-test.py`** — end-to-end test of the audit
  instrument against three synthetic input classes (ideal / edge /
  malformed). Verifies the five canonical contracts hold for each
  class and that the malformed class survives without crashing.
  Closes the Quintessence integration phase that v0.1.0 only
  covered narratively.
- **`tools/cost-audit.py --invariants`** — new flag. Verifies the
  five canonical contracts against the scanned data and exits 4 on
  any violation. Produces the operational signal `INVARIANTS.md` §2
  is the contract for. Default behavior unchanged when the flag is
  absent.
- **`CLAUDE.md` Section 7 — Voice & Stance** — three lines codifying
  the register the system communicates in (austere, falsifiable,
  anti-hype) without inventing a persona or arquetype. Net additions
  to the Constitution: ~140 tokens, ~$0.0002 per cache-hot Opus turn.

### Changed

- **`CLAUDE.md` Section 2 — Laws of Operation** now has nine Laws.
  L9 (*Every boundary declares its contract*) makes explicit the
  contract discipline that `docs/MATH.md` §0 already required of the
  audit instrument and that `docs/INVARIANTS.md` indexes across the
  whole repo.
- **`SECURITY.md`** — added entry for `tier-contradiction-guard.sh`
  to the "what hooks actually do" table. Same fail-silent / warn-only
  posture as the existing four hooks.
- **`README.md`** — Status of components table extended with the
  three new artifacts (INVARIANTS, tier-contradiction-guard,
  stress-test). Integrity manifest re-hashed for the load-bearing
  files (CLAUDE.md, the new hook, both new tools).
- **`INSTALL_PROMPT.md`** — Phase 2 hook registration extended to
  cover `tier-contradiction-guard.sh` (PreToolUse on Edit / Write /
  NotebookEdit).
- **`docs/INSTALL.md`** — manual install path brought in sync with the
  Claude-native installer: Phase 2 includes `tier-contradiction-guard`
  cp, JSON registration, and rollback line. New "Verify the repo
  before you trust it" pre-install block invokes both
  `test_redaction.py` and `stress-test.py`.
- **`tools/audit.sh` and `tools/bridge.sh`** — path-agnostic discovery.
  Both scripts now consult `$COGNITIVE_CLAUDE_HOME` first when locating
  `cost-audit.py`, before falling back to the canonical
  `~/cognitive-claude/` and `~/.claude/cognitive-claude/` paths.
  Operators who clone to a non-canonical path can export the env var
  in their shell rc to close the calibration loop. Unset = identical
  prior behavior.
- **Cross-doc consistency pass.** Updated `8 Laws` → `9 Laws`,
  `5 hooks` → `6 hooks`, and the `91-line / 1.3k-token` Constitution
  references throughout `README.md`, `INSTALL_PROMPT.md`,
  `docs/INSTALL.md`, `docs/MATH.md`, `docs/ARCHITECTURE.md`,
  `docs/META_LEARNINGS.md`, `docs/INVARIANTS.md`, and `docs/TRANSFER.md`
  to reflect the v0.1.1 shape. CHANGELOG `[0.1.0]` block intentionally
  preserves the original phrasing as a historical record.
- **Integrity manifest** in `README.md` re-hashed for the three files
  whose content moved (`INSTALL_PROMPT.md`, `tools/audit.sh`,
  `tools/bridge.sh`).
- **`examples/case-study-2026-04-28/EVIDENCE.json`** — re-hashed
  after a final LF normalization pass enforced by `.gitattributes`
  (`* text=auto eol=lf`). The v0.1.0 hash
  `d17f121e8cfb6a1557229286911ff6c227d27e02ad3934564cd478a3384fef34`
  reflected the file with mixed CRLF line endings. The v0.1.1 hash
  `b2145b871ae5c57a1646e01ea5741e43bf70653d8120289264cc4ff2686f0429`
  reflects the canonical LF form. Content unchanged; only line
  endings normalized to match the repo-wide convention. The CASE_STUDY
  frontmatter is updated to the new hash.

### Absorbed from a parallel work-in-progress branch

A parallel `release/v0.1-karpathy-grade` branch had developed
artifacts that complement v0.1.1 without contradicting it. After
audit, eight artifacts were absorbed into v0.1.1; eight were
declined as redundant with v0.1.1's existing maturity (notably the
documents `RITUALS.md`, `SESSION_LIFECYCLE.md`, and
`AUTO_EVOLUTION.md`, which overlap fully with `docs/HANDBOOK.md`'s
boot/close/30-day sections).

Operational artifacts absorbed:

- **`AUTHOR.md`** — public identity check at repo root. In 2026,
  *"is this real?"* is a fair first question for any GitHub repo.
  Names the operator, the workload profile, the conflict of
  interest, the lifecycle commitment (24 months from v0.1.0), the
  contact channel.
- **`commands/handoff.md`** — Claude Code slash-command that
  materializes the session-close ritual prescribed in
  `docs/HANDBOOK.md` §4 and §5. Operator types `/handoff` and
  the model produces the `.session-state.md` per the convention.
- **`output-styles/cognitive-claude.md`** — installable voice
  profile. The operational expression of the Constitution's
  Section 7 (Voice & Stance) at the Claude Code output-style
  layer. Activated via `/output-style cognitive-claude`.
- **`templates/project-{simple,squad,sensitive}.json`** — three
  starter `.claude/settings.json` files for project-level deny
  patterns. Adapted from the parallel branch with English comments
  and a `templates/README.md` explaining the deny-only convention.
- **`tools/install.sh`** — phase-gated installer. Dry-run by
  default. Idempotent (skip-on-identical-backup). Phase 3 requires
  `--i-have-read-claudemd` flag by design. Adapted to v0.1.1 hook
  inventory (registers `tier-contradiction-guard.sh` as well).
- **`tools/uninstall.sh`** — byte-exact restore from
  `~/.claude/.backups/`. Idempotent, dry-run default, never deletes
  telemetry (moves to `<dir>.removed.<ts>` for operator review).
  Closes the previously-undocumented "easy to remove" claim.

Documents absorbed:

- **`docs/READ_THIS_FIRST.md`** — 90-second gentle introduction.
  Different audience (first-time visitor) than `HANDBOOK.md`
  (post-install operator). Both honor the same architecture in
  different registers.
- **`docs/SMELL_TESTS.md`** — five pre-install one-line diagnostics
  that read `~/.claude/projects/`. Operator decides in 90 seconds
  whether `cognitive-claude` would help or be cargo-cult adoption.
  Read-only, zero side effects.
- **`docs/INTERNALS.md`** — source-verified Claude Code mechanics:
  3-zone cache, 12 break triggers, schema discontinuity history.
  Captured at point-in-time per `STABILITY_DISCLAIMER.md`.
- **`docs/VALUE_MODEL.md`** — token value framework beyond cost.
  EAGER/LAZY × frequency × cache-state cost formula. Complement to
  `MATH.md`'s cost derivations.
- **`docs/HOW_TO_FALSIFY.md`** — seven runnable falsification
  protocols, one per invariant. Each takes 14+ days to execute.
  Materializes the falsifiability claims in `LIMITATIONS.md`.
- **`docs/CONFOUNDS.md`** — post-hoc honesty pass on the headline
  leverage number. Stronger version of `LIMITATIONS.md` §1's
  attribution argument; preserved as separate doc because it is
  written in confessional register (acknowledges the post-hoc
  provenance up front).
- **`docs/STABILITY_DISCLAIMER.md`** — three categories of claims
  (anchored / mechanistic / observation-bound) and the EOL conditions
  that would tell any future maintainer when to deprecate.
- **`docs/REPLICATION_LOG.md`** — empty registry inviting external
  operators to publish their own audit-instrument runs via PR.
  Materializes `LIMITATIONS.md` §2's request for ≥3 case studies.

All absorbed docs were updated for v0.1.1 conventions: tool names
(`cost-audit.sh` → `cost-audit.py`), flag names (`--days` →
`--window`), counts (`5 hooks` → `6 hooks`, `8 Laws` → `9 Laws`),
the `.session-state.md` convention from HANDBOOK §5, and the
sha256-pinned EVIDENCE.json numbers (`91.63%` cache, `71.76%`
sub-share, `~84×` leverage).

The integrity manifest in `README.md` is extended to cover the new
load-bearing files (`AUTHOR.md`, `tools/install.sh`,
`tools/uninstall.sh`, `commands/handoff.md`,
`output-styles/cognitive-claude.md`).

### Discipline (additions)

- The five canonical metric contracts now have a tool that fails
  loud (exit 4) when violated — `tools/cost-audit.py --invariants`.
  Closes the gap between *stated contract* and *machine-verified
  contract*.
- The L1↔L4 boundary now has a hook that surfaces violations at
  authorship time, not at audit time.
- The audit instrument now has its own end-to-end test (`stress-test.py`)
  alongside the existing unit test (`test_redaction.py`).

### Not changed

- The 91-line Constitution principle survives at 103 lines (still
  far below the 5k-line antipattern). Net additions follow §8
  meta-rule: every new line earns its keep against the cache tax.
- The five-phase loop (BOOT → EXECUTE → COMPACT → CLOSE → CALIBRATE)
  is unchanged.
- The metric definitions in `docs/MATH.md` Section 0 are unchanged
  (this release verifies them, does not redefine them).
- No schema changes to the evidence pack.
- No new external dependencies.

---

## [0.1.0] — 2026-04-28

Initial public release.

### Added

- **`CLAUDE.md`** — 91-line Cognitive Constitution: 8 Laws of Operation,
  9 Mode 2 triggers, 3 Decision Levels, 6 Protection Protocols, 9
  Cognitive Traps, output-discipline guidance, meta-rules.
- **`hooks/`** — 5 governance hooks for the Claude Code lifecycle:
  - `telemetry.sh` (PostToolUse) — append-only structured logs, with
    built-in regex redaction of common credential patterns
    (`gho_/ghp_/ghu_/ghs_/ghr_`, `github_pat_`, `sk-ant-`, `sk-`,
    `AKIA*`, HTTP `Bearer`/`token`/`Authorization` headers)
  - `cache-guard.sh` (PreToolUse on Bash/Edit/Write) — warns on
    cache-breaking operations (mid-session CLAUDE.md edits, MCP
    mutations, model swaps, settings.json field changes)
  - `token-economy-guard.sh` (PreToolUse on Write) — warns on rule
    files without `globs:` frontmatter (recurring tax pattern)
  - `token-economy-boot.sh` (SessionStart) — emits compact health
    status; fail-silent if optional companion tools absent
  - `token-economy-session-end.sh` (Stop) — closes the calibration
    feedback loop by appending the est-vs-real delta to history
- **`tools/cost-audit.py`** — 720-line stdlib-only Python instrument
  that reads `~/.claude/projects/**/*.jsonl` and reproduces every
  numerical claim in the README and `examples/` from operator-local
  data. Six modes: default summary, `--verbose` (7d/30d/90d/all
  side-by-side), `--charts` (ASCII sparklines), `--by-project`,
  `--json`, `--evidence` (machine-readable evidence pack).
- **`tools/audit.sh`** — boot-hook companion that emits one-line
  JSON status (`Boot:Ntok Grade:X Health:N/100 Profile:X`).
  Fail-silent if `cost-audit.py` is not on the expected path.
- **`tools/bridge.sh`** — session-end calibration loop. Emits the
  est-vs-real comparison the boot hook references.
- **`tools/test_redaction.py`** — stdlib `unittest` covering the
  documented redaction patterns and the most likely false-positive
  prefixes. 16 tests; ships green.
- **`docs/ARCHITECTURE.md`** — the full *why* behind every primitive,
  decision flows for "where should this rule live?" / "should this
  be a sub-agent?" / "code or LLM?" / "when do I `/clear`?", and
  the L0–L5 governance tier model.
- **`docs/MATH.md`** — Section 0 canonical metric definitions, then
  per-domain derivations (CLAUDE.md tax, MCP tax, hook vs rule
  math, cache break math, sub-agent math, model routing math, lazy
  skill math). Every claim derivable; reproducibility statement
  pins the formula to the instrument.
- **`docs/META_LEARNINGS.md`** — eleven generalizable lessons from
  running the system, each in `Pattern / Mechanism / Implication /
  Trust signal` format. The trust signals point back to specific
  metrics in `cost-audit.py`.
- **`docs/TRANSFER.md`** — adaptation recipes for five operator
  profiles (Sonnet-default, Pro-plan, Team, Casual, Different
  harness).
- **`docs/INSTALL.md`** — manual install fallback with exact JSON
  to paste, exact files to copy, exact backups, exact rollbacks.
- **`docs/LIMITATIONS.md`** — eight steelmen of the strongest
  counter-arguments stated by the framework's author, including:
  the leverage ratio is largely plan-vs-API arbitrage (not
  framework-induced savings); N=1 ceiling; output quality / time-
  to-completion / operator load are not measured; three concurrent
  platform changes confound clean attribution; the schema
  discontinuity makes pre-W13 sub-share an artifact; the framework
  has not been audited by a third party; the framework does not
  survive a hostile fork without operator literacy.
- **`SECURITY.md`** — threat model, telemetry capture and redaction
  disclosure, authorization model, reversal commands, and the
  prompt-injection warning for the Claude-native installer pattern.
- **`INSTALL_PROMPT.md`** — Claude-native installer protocol. The
  LLM running in the operator's terminal reads this file and
  installs the framework with explicit consent at every write.
- **`examples/case-study-2026-04-28/`** — one operator's 90-day
  snapshot with full forensic methodology, including:
  - `CASE_STUDY.md` with per-week timeseries, baseline-vs-bug-window
    cost split, schema discontinuity disclosure, cache-rate-during-
    regression mechanism, project concentration with double-count
    note for the `subagents/` directory, audit-of-own-claims table.
  - `EVIDENCE.json` — machine-readable evidence pack
    (sha256 `d17f121e8cfb6a1557229286911ff6c227d27e02ad3934564cd478a3384fef34`)
    containing per-window metrics, per-day timeseries, per-project
    cost concentration, scan stats. Project names anonymized A–N.
- **`README.md`** — TL;DR-first entry point, integrity manifest with
  SHA-256 of every load-bearing file, comparison table positioning
  the project relative to adjacent OSS work.
- **`.gitattributes`** — pins LF line endings repo-wide so the SHA
  manifest verifies on Windows clones.
- **`LICENSE`** — MIT.

### Discipline

- All numerical claims in any document trace to a formula in
  `docs/MATH.md` and a reproducible run of `tools/cost-audit.py`.
- The Constitution distributed in `CLAUDE.md` is byte-exact (modulo
  trailing newline) with the operator's own `~/.claude/CLAUDE.md`.
  "I run what I publish" is a verified property, not a claim.
- The integrity manifest in `README.md` is reproducible:
  `sha256sum` against the listed files yields the listed hashes
  on any platform thanks to `.gitattributes`.
- The redaction patterns in `hooks/telemetry.sh` are tested by
  `tools/test_redaction.py`; CI / pre-publish discipline can run
  the test to detect regression.
- `docs/LIMITATIONS.md` exists *because* the framework's defense
  must include the strongest counter-arguments stated by its
  author, not just praise from third parties.

---

[0.1.0]: https://github.com/l0z4n0-a1/cognitive-claude/releases/tag/v0.1.0
[0.1.1]: https://github.com/l0z4n0-a1/cognitive-claude/releases/tag/v0.1.1
