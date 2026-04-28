# examples/

Real operator case studies of `cognitive-claude` in production.

The framework lives in `/`. The receipts live here.

## Why this directory exists

The repo's README, `CLAUDE.md`, hooks, math, and instrument are
universal. They work for any operator running Claude Code with a
similar profile. They describe a methodology.

A methodology with no receipt is a tutorial. A methodology with one
operator's actual telemetry is a case study. A methodology with
*multiple* operators submitting their own evidence is a benchmark.

This directory is where the evidence lives. Each subdirectory is one
operator's snapshot of running this setup against their own
`~/.claude/projects/`, with all the platform incidents, drift, and
quirks that real telemetry contains.

## Contributing your own case study

If you have run `cognitive-claude` for ≥30 days and have telemetry
to back it up:

1. Run `python3 tools/cost-audit.py --evidence > evidence.json`
2. Create a directory `examples/case-study-<date>/`
3. Add `evidence.json` (or its sanitized form — strip personal project names)
4. Add `CASE_STUDY.md` documenting your snapshot, lessons learned,
   any platform anomalies you observed
5. Open a PR

The architecture improves when more people show their work.

## Current case studies

| Directory | Operator profile | Window | Plan paid | Notes |
|-----------|------------------|--------|-----------|-------|
| `case-study-2026-04-28/` | Heavy-Opus, multi-project, solo | 90 days | ~$500 | Includes Anthropic-confirmed cache-bug window (Mar 26–Apr 10) |

Add yours.
