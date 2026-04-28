# Changelog

All notable changes to `cognitive-claude` are documented here.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).
Versioning follows [SemVer](https://semver.org/) once we leave `0.x`; until
then, `0.MAJOR.MINOR` increments at architectural changes (`MAJOR`) or
substantive additions / corrections (`MINOR`).

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
