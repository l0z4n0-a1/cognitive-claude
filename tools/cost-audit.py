#!/usr/bin/env python3
"""
cognitive-claude / tools / cost-audit.py
==========================================

Reproducible audit of your own Claude Code telemetry.

Reads JSONL session logs from ~/.claude/projects/ and computes the
canonical metrics published in README.md and docs/MATH.md, using the
exact same definitions and formulas. Every claim in this repo is
derivable by running this script against your own data.

Usage:
    python3 tools/cost-audit.py                       # 90-day window, summary
    python3 tools/cost-audit.py --window 30           # 30-day window
    python3 tools/cost-audit.py --verbose             # 7d/30d/90d/all side-by-side
    python3 tools/cost-audit.py --charts              # ASCII charts of daily metrics
    python3 tools/cost-audit.py --by-project          # per-project cost breakdown
    python3 tools/cost-audit.py --json                # machine-readable output
    python3 tools/cost-audit.py --evidence            # full evidence pack JSON

No external dependencies. Python 3.8+ stdlib only.

Definitions (canonical):
  - turn         : assistant message with non-empty `usage` block
  - agent turn   : turn whose JSONL filename starts with `agent-`
                   (sub-agent context, stable across Claude Code versions)
  - main turn   : turn whose JSONL filename does not start with `agent-`
  - sub_share   : agent_turns / total_turns (the canonical "sub-agent work share")
  - cache_hit   : cache_read / (cache_read + input + cache_write)
  - cost (API)  : tokens × Anthropic public per-model price

Why filename-based sub-share, not isSidechain field:
  Around Claude Code v2.1.86 (week of 2026-03-23), the isSidechain
  field semantics changed. Pre-2.1.86 it was nearly always `true`
  for assistant turns; post-2.1.86 it became a real main/sub
  discriminator. Filename pattern is stable across all observed
  versions, so this script trusts filenames over flags.
  See examples/case-study-2026-04-28/CASE_STUDY.md Section 6.

Source of truth for pricing: https://docs.anthropic.com/en/docs/about-claude/pricing
Source of truth for platform incidents: https://www.anthropic.com/engineering/april-23-postmortem
"""

from __future__ import annotations

import argparse
import glob
import json
import os
import statistics
import sys
import time
from collections import defaultdict
from dataclasses import dataclass, field
from datetime import datetime, timezone
from typing import Any, Callable, Iterable


# -----------------------------------------------------------------------------
# Pricing — Anthropic public API rates, USD per million tokens
# Verify at: https://docs.anthropic.com/en/docs/about-claude/pricing
# -----------------------------------------------------------------------------

PRICING: dict[str, dict[str, float]] = {
    "opus":   {"input": 15.00, "output": 75.00, "cache_read": 1.50, "cache_write": 18.75},
    "sonnet": {"input":  3.00, "output": 15.00, "cache_read": 0.30, "cache_write":  3.75},
    "haiku":  {"input":  0.80, "output":  4.00, "cache_read": 0.08, "cache_write":  1.00},
}

# Known Anthropic platform incidents (publicly confirmed)
# Used by --phases to bucket data around incident windows.
KNOWN_EVENTS: dict[str, str] = {
    "2026-03-04": "Reasoning effort default lowered high → medium",
    "2026-03-13": "2x usage promotion START (off-peak weekdays + 24/7 weekends)",
    "2026-03-26": "Cache bug shipped (clear_thinking_20251015 + keep:1)",
    "2026-03-27": "2x usage promotion END",
    "2026-04-07": "Reasoning effort REVERTED to high",
    "2026-04-10": "Cache bug FIXED",
    "2026-04-16": "Verbosity-reduction prompt added (regression)",
    "2026-04-20": "All fixes live in v2.1.116",
    "2026-04-23": "Postmortem published",
}


def model_class(model_id: str) -> str | None:
    """Map Anthropic model id to pricing tier."""
    if not model_id:
        return None
    m = model_id.lower()
    if "opus" in m: return "opus"
    if "sonnet" in m: return "sonnet"
    if "haiku" in m: return "haiku"
    return None


def turn_cost(usage: dict[str, int], klass: str) -> float:
    """API-equivalent cost of one billable assistant turn."""
    p = PRICING[klass]
    return (
        usage.get("input_tokens", 0) * p["input"]
        + usage.get("output_tokens", 0) * p["output"]
        + usage.get("cache_read_input_tokens", 0) * p["cache_read"]
        + usage.get("cache_creation_input_tokens", 0) * p["cache_write"]
    ) / 1e6


# -----------------------------------------------------------------------------
# Aggregation
# -----------------------------------------------------------------------------


@dataclass
class WindowMetrics:
    label: str
    days_param: int

    sessions: set[str] = field(default_factory=set)
    days: set[str] = field(default_factory=set)
    turns_main: int = 0
    turns_agent: int = 0  # filename-based: file starts with agent-

    tokens_input: int = 0
    tokens_cache_read: int = 0
    tokens_cache_write: int = 0
    tokens_output: int = 0

    cost_api_eq: float = 0.0

    by_model: dict[str, dict[str, float]] = field(
        default_factory=lambda: defaultdict(lambda: {"turns": 0, "cost": 0.0, "tokens": 0})
    )
    turns_per_session: dict[str, int] = field(default_factory=lambda: defaultdict(int))

    # ---- derived metrics ----

    @property
    def turns_total(self) -> int:
        return self.turns_main + self.turns_agent

    @property
    def session_count(self) -> int:
        return len(self.sessions)

    @property
    def days_count(self) -> int:
        return len(self.days)

    @property
    def cache_hit_rate(self) -> float:
        denom = self.tokens_input + self.tokens_cache_read + self.tokens_cache_write
        return (self.tokens_cache_read / denom * 100) if denom else 0.0

    @property
    def sub_agent_share(self) -> float:
        return (self.turns_agent / self.turns_total * 100) if self.turns_total else 0.0

    @property
    def cost_per_turn_api(self) -> float:
        return (self.cost_api_eq / self.turns_total) if self.turns_total else 0.0

    @property
    def cost_per_day(self) -> float:
        return (self.cost_api_eq / self.days_count) if self.days_count else 0.0

    @property
    def turns_per_session_median(self) -> float:
        vals = list(self.turns_per_session.values())
        return statistics.median(vals) if vals else 0.0

    @property
    def turns_per_session_mean(self) -> float:
        vals = list(self.turns_per_session.values())
        return statistics.mean(vals) if vals else 0.0

    @property
    def total_tokens_billable(self) -> int:
        return self.tokens_input + self.tokens_cache_read + self.tokens_cache_write


@dataclass
class DayMetrics:
    date: str
    turns: int = 0
    turns_main: int = 0
    turns_agent: int = 0
    tokens_input: int = 0
    tokens_cache_read: int = 0
    tokens_cache_write: int = 0
    tokens_output: int = 0
    cost: float = 0.0

    @property
    def cache_hit(self) -> float:
        denom = self.tokens_input + self.tokens_cache_read + self.tokens_cache_write
        return (self.tokens_cache_read / denom * 100) if denom else 0.0

    @property
    def cost_per_turn(self) -> float:
        return (self.cost / self.turns) if self.turns else 0.0

    @property
    def sub_share(self) -> float:
        return (self.turns_agent / self.turns * 100) if self.turns else 0.0


# -----------------------------------------------------------------------------
# Core scan
# -----------------------------------------------------------------------------


def find_jsonl_files(projects_dir: str) -> list[str]:
    return glob.glob(os.path.join(projects_dir, "**", "*.jsonl"), recursive=True)


def scan_files(
    files: Iterable[str],
    windows: dict[str, int],
    snapshot_now: datetime | None = None,
) -> tuple[
    dict[str, WindowMetrics],     # per-window aggregates
    dict[str, DayMetrics],        # per-day timeseries
    dict[str, dict[str, Any]],    # per-project totals
    dict[str, Any],               # scan stats
]:
    """
    Walk JSONL files once, populate everything we need.
    Time filtering uses per-record `timestamp` (canonical), not file mtime.
    """
    now = snapshot_now or datetime.now(timezone.utc)
    metrics = {label: WindowMetrics(label, days) for label, days in windows.items()}
    per_day: dict[str, DayMetrics] = {}
    per_project: dict[str, dict[str, Any]] = defaultdict(lambda: {"cost": 0.0, "turns": 0})
    stats: dict[str, Any] = {
        "files": 0,
        "files_processed": 0,
        "lines_total": 0,
        "lines_malformed": 0,
        "records_assistant_with_usage": 0,
        "records_no_timestamp": 0,
        "max_record_timestamp": None,
        "min_record_timestamp": None,
    }
    max_ts: datetime | None = None
    min_ts: datetime | None = None

    for fp in files:
        stats["files"] += 1
        stats["files_processed"] += 1
        fname = os.path.basename(fp)
        is_agent_file = fname.startswith("agent-")
        project_name = os.path.basename(os.path.dirname(fp))

        try:
            f = open(fp, "r", encoding="utf-8", errors="ignore")
        except OSError:
            continue
        with f:
            for line in f:
                stats["lines_total"] += 1
                try:
                    rec = json.loads(line)
                except json.JSONDecodeError:
                    stats["lines_malformed"] += 1
                    continue

                msg = rec.get("message") or {}
                if msg.get("role") != "assistant":
                    continue
                usage = msg.get("usage") or {}
                if not usage:
                    continue
                stats["records_assistant_with_usage"] += 1

                ts_raw = rec.get("timestamp")
                if not ts_raw:
                    stats["records_no_timestamp"] += 1
                    continue
                try:
                    ts = datetime.fromisoformat(ts_raw.replace("Z", "+00:00"))
                except (ValueError, AttributeError):
                    stats["records_no_timestamp"] += 1
                    continue

                if max_ts is None or ts > max_ts:
                    max_ts = ts
                if min_ts is None or ts < min_ts:
                    min_ts = ts

                age_days = (now - ts).days
                relevant_windows = [
                    label for label, days in windows.items() if 0 <= age_days <= days
                ]
                if not relevant_windows:
                    continue

                klass = model_class(msg.get("model") or rec.get("model") or "")
                if klass is None:
                    continue

                sid = rec.get("sessionId") or ""
                date = ts.date().isoformat()

                ti  = int(usage.get("input_tokens") or 0)
                tcr = int(usage.get("cache_read_input_tokens") or 0)
                tcw = int(usage.get("cache_creation_input_tokens") or 0)
                to_ = int(usage.get("output_tokens") or 0)
                cost_dollars = turn_cost(usage, klass)

                # Per-day aggregation (always tracked, used by --charts)
                if date not in per_day:
                    per_day[date] = DayMetrics(date=date)
                D = per_day[date]
                D.turns += 1
                if is_agent_file:
                    D.turns_agent += 1
                else:
                    D.turns_main += 1
                D.tokens_input += ti
                D.tokens_cache_read += tcr
                D.tokens_cache_write += tcw
                D.tokens_output += to_
                D.cost += cost_dollars

                # Per-project aggregation
                P = per_project[project_name]
                P["cost"] += cost_dollars
                P["turns"] += 1

                # Per-window aggregation
                for label in relevant_windows:
                    M = metrics[label]
                    if sid:
                        M.sessions.add(sid)
                        M.turns_per_session[sid] += 1
                    M.days.add(date)
                    if is_agent_file:
                        M.turns_agent += 1
                    else:
                        M.turns_main += 1
                    M.tokens_input += ti
                    M.tokens_cache_read += tcr
                    M.tokens_cache_write += tcw
                    M.tokens_output += to_
                    M.cost_api_eq += cost_dollars

                    bm = M.by_model[klass]
                    bm["turns"] += 1
                    bm["cost"] += cost_dollars
                    bm["tokens"] += ti + tcr + tcw + to_

    stats["max_record_timestamp"] = max_ts.isoformat() if max_ts else None
    stats["min_record_timestamp"] = min_ts.isoformat() if min_ts else None
    return metrics, per_day, dict(per_project), stats


# -----------------------------------------------------------------------------
# Output formatters
# -----------------------------------------------------------------------------


def fmt_int(n: float | int) -> str:
    return f"{int(n):,}"


def fmt_money(n: float) -> str:
    return f"${n:,.2f}"


def fmt_pct(n: float) -> str:
    return f"{n:.2f}%"


def render_summary(M: WindowMetrics, plan_paid_usd: float, plan_months: int) -> str:
    lev_full = (M.cost_api_eq / plan_paid_usd) if plan_paid_usd else 0.0
    monthly_plan = plan_paid_usd / max(plan_months, 1)
    lev_month = (M.cost_api_eq / monthly_plan) if monthly_plan else 0.0
    lines = [
        f"  Window:                  {M.label} ({M.days_count} active days)",
        f"  Sessions:                {fmt_int(M.session_count)}",
        f"  Turns (assistant):       {fmt_int(M.turns_total)}",
        f"    main thread:           {fmt_int(M.turns_main)}",
        f"    inside sub-agents:     {fmt_int(M.turns_agent)}",
        f"  Sub-agent work share:    {fmt_pct(M.sub_agent_share)}  (filename-based)",
        f"  Turns/session:           median {M.turns_per_session_median:.0f}  mean {M.turns_per_session_mean:.1f}",
        "",
        f"  Tokens (total billable): {M.total_tokens_billable / 1e9:.2f}B",
        f"    fresh input:           {M.tokens_input / 1e6:.1f}M",
        f"    cache read:            {M.tokens_cache_read / 1e9:.2f}B",
        f"    cache write:           {M.tokens_cache_write / 1e9:.2f}B",
        f"    output:                {M.tokens_output / 1e6:.1f}M",
        f"  Cache hit rate:          {fmt_pct(M.cache_hit_rate)}",
        "",
        f"  API-equivalent cost:     {fmt_money(M.cost_api_eq)}",
        f"  Cost per turn (API):     ${M.cost_per_turn_api:.4f}",
        f"  Cost per active day:     ${M.cost_per_day:,.2f}",
        f"  Plan paid ({plan_months} months):  {fmt_money(plan_paid_usd)}",
        f"  Leverage (vs full term): {lev_full:.1f}x",
        f"  Leverage (vs 1 month):   {lev_month:.1f}x",
    ]
    return "\n".join(lines)


def render_per_model(M: WindowMetrics) -> str:
    lines = ["  Per-model breakdown:"]
    lines.append(f"    {'model':<8}{'turns':>10}{'share':>9}{'cost':>14}{'tokens':>12}")
    for k in ("opus", "sonnet", "haiku"):
        d = M.by_model.get(k, {"turns": 0, "cost": 0.0, "tokens": 0})
        share = (d["turns"] / M.turns_total * 100) if M.turns_total else 0.0
        lines.append(
            f"    {k:<8}{int(d['turns']):>10,}{share:>8.1f}%{fmt_money(d['cost']):>14}"
            f"{d['tokens'] / 1e9:>11.2f}B"
        )
    return "\n".join(lines)


# -----------------------------------------------------------------------------
# ASCII charts
# -----------------------------------------------------------------------------


# Block characters for sparklines: 8 levels
SPARK_LEVELS = " ▁▂▃▄▅▆▇█"


def sparkline(values: list[float], width: int | None = None) -> str:
    """Compact unicode sparkline."""
    if not values:
        return ""
    if width and len(values) > width:
        # Subsample
        step = len(values) / width
        sampled = [values[int(i * step)] for i in range(width)]
        values = sampled
    lo = min(values)
    hi = max(values)
    rng = hi - lo or 1
    n_levels = len(SPARK_LEVELS) - 1
    out = []
    for v in values:
        idx = int((v - lo) / rng * n_levels)
        out.append(SPARK_LEVELS[max(0, min(n_levels, idx))])
    return "".join(out)


def render_daily_chart(per_day: dict[str, DayMetrics], metric: str = "cost_per_turn") -> str:
    """Render a daily ASCII bar chart of a metric."""
    days = sorted(per_day.keys())
    if not days:
        return "(no data)"
    if metric == "cost_per_turn":
        values = [per_day[d].cost_per_turn for d in days]
        label = "$/turn"
    elif metric == "cache_hit":
        values = [per_day[d].cache_hit for d in days]
        label = "cache_hit %"
    elif metric == "cost":
        values = [per_day[d].cost for d in days]
        label = "$/day"
    elif metric == "sub_share":
        values = [per_day[d].sub_share for d in days]
        label = "sub-share %"
    else:
        return f"(unknown metric {metric})"
    out = [f"{label:>12}  {sparkline(values, 80)}"]
    out.append(f"{'first day':>12}  {days[0]}")
    out.append(f"{'last day':>12}  {days[-1]}")
    out.append(f"{'min':>12}  {min(values):.4f}")
    out.append(f"{'max':>12}  {max(values):.4f}")
    out.append(f"{'mean':>12}  {sum(values)/len(values):.4f}")
    return "\n".join(out)


def render_charts(per_day: dict[str, DayMetrics]) -> str:
    """All four key charts."""
    out = ["", "Daily timeseries (chronological, sparkline)", "=" * 96, ""]
    for metric in ("cost_per_turn", "cost", "cache_hit", "sub_share"):
        out.append(render_daily_chart(per_day, metric))
        out.append("")
    return "\n".join(out)


def render_by_project(per_project: dict[str, dict[str, Any]], top_n: int = 15) -> str:
    items = sorted(per_project.items(), key=lambda kv: -kv[1]["cost"])
    total = sum(p["cost"] for p in per_project.values()) or 1.0
    out = [f"Top {top_n} projects by API-equivalent cost", "=" * 80]
    out.append(f"  {'project':<55}{'cost':>10}{'share':>8}{'turns':>9}")
    out.append("  " + "-" * 78)
    for name, p in items[:top_n]:
        share = p["cost"] / total * 100
        truncated = name if len(name) <= 53 else name[:50] + "..."
        out.append(f"  {truncated:<55}{fmt_money(p['cost']):>10}{share:>7.1f}%{p['turns']:>9,}")
    out.append("  " + "-" * 78)
    out.append(f"  Total across {len(per_project)} projects: {fmt_money(total)}")
    return "\n".join(out)


# -----------------------------------------------------------------------------
# Evidence pack JSON
# -----------------------------------------------------------------------------


def build_evidence_pack(
    metrics: dict[str, WindowMetrics],
    per_day: dict[str, DayMetrics],
    per_project: dict[str, dict[str, Any]],
    stats: dict[str, Any],
    plan_paid_usd: float,
    plan_months: int,
) -> dict[str, Any]:
    out: dict[str, Any] = {
        "schema_version": "1.0",
        "generated_at": datetime.now(timezone.utc).isoformat(),
        "plan_paid_usd": plan_paid_usd,
        "plan_months": plan_months,
        "definitions": {
            "turn": "assistant message with non-empty usage block",
            "main_turn": "turn whose JSONL filename does not start with `agent-`",
            "agent_turn": "turn whose JSONL filename starts with `agent-` (sub-agent context)",
            "sub_agent_share_pct": "agent_turns / total_turns × 100 (filename-based, schema-stable)",
            "cache_hit_rate_pct": "cache_read / (cache_read + input + cache_write) × 100",
            "cost_api_equivalent": "tokens × Anthropic published per-model price",
        },
        "pricing": PRICING,
        "known_anthropic_events": KNOWN_EVENTS,
        "windows": {},
        "scan": {
            "files_total": stats["files"],
            "files_processed": stats["files_processed"],
            "lines_total": stats["lines_total"],
            "lines_malformed": stats["lines_malformed"],
            "records_assistant_with_usage": stats["records_assistant_with_usage"],
            "records_no_timestamp": stats["records_no_timestamp"],
            "min_record_timestamp": stats["min_record_timestamp"],
            "max_record_timestamp": stats["max_record_timestamp"],
        },
    }
    for label, M in metrics.items():
        lev_full = (M.cost_api_eq / plan_paid_usd) if plan_paid_usd else 0.0
        monthly = plan_paid_usd / max(plan_months, 1)
        out["windows"][label] = {
            "window_days": M.days_param,
            "active_days": M.days_count,
            "sessions": M.session_count,
            "turns_total": M.turns_total,
            "turns_main": M.turns_main,
            "turns_agent": M.turns_agent,
            "sub_agent_share_pct": round(M.sub_agent_share, 4),
            "turns_per_session_median": M.turns_per_session_median,
            "turns_per_session_mean": round(M.turns_per_session_mean, 2),
            "tokens": {
                "input_fresh": M.tokens_input,
                "cache_read": M.tokens_cache_read,
                "cache_write": M.tokens_cache_write,
                "output": M.tokens_output,
                "total_billable": M.total_tokens_billable,
            },
            "cache_hit_rate_pct": round(M.cache_hit_rate, 4),
            "cost_api_equivalent_usd": round(M.cost_api_eq, 2),
            "cost_per_turn_api_usd": round(M.cost_per_turn_api, 6),
            "cost_per_active_day_usd": round(M.cost_per_day, 2),
            "leverage_full_term": round(lev_full, 2),
            "leverage_per_month": round((M.cost_api_eq / monthly) if monthly else 0.0, 2),
            "by_model": {
                k: {
                    "turns": int(d["turns"]),
                    "share_pct": round(d["turns"] / M.turns_total * 100, 2) if M.turns_total else 0.0,
                    "cost_usd": round(d["cost"], 2),
                    "tokens": int(d["tokens"]),
                }
                for k, d in M.by_model.items()
            },
        }
    # Daily timeseries
    out["daily_timeseries"] = [
        {
            "date": D.date,
            "turns": D.turns,
            "turns_main": D.turns_main,
            "turns_agent": D.turns_agent,
            "cost_usd": round(D.cost, 2),
            "cost_per_turn_usd": round(D.cost_per_turn, 4),
            "cache_hit_pct": round(D.cache_hit, 2),
            "sub_share_pct": round(D.sub_share, 2),
            "tokens_billable": D.tokens_input + D.tokens_cache_read + D.tokens_cache_write,
        }
        for D in (per_day[d] for d in sorted(per_day.keys()))
    ]
    # Project concentration
    items = sorted(per_project.items(), key=lambda kv: -kv[1]["cost"])
    total = sum(p["cost"] for p in per_project.values())
    out["project_concentration"] = {
        "total_projects": len(per_project),
        "total_cost_usd": round(total, 2),
        "top_15": [
            {
                "project": name,
                "cost_usd": round(p["cost"], 2),
                "turns": p["turns"],
                "share_pct": round(p["cost"] / total * 100, 2) if total else 0.0,
            }
            for name, p in items[:15]
        ],
    }
    return out


# -----------------------------------------------------------------------------
# CLI
# -----------------------------------------------------------------------------


DEFAULT_PROJECTS_DIR = os.path.expanduser("~/.claude/projects")


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(
        prog="cost-audit",
        description="Audit your own Claude Code telemetry. Reproduces every README number.",
    )
    parser.add_argument(
        "--projects-dir",
        default=DEFAULT_PROJECTS_DIR,
        help="path to ~/.claude/projects (default: %(default)s)",
    )
    parser.add_argument(
        "--window",
        type=int,
        default=90,
        help="primary window in days (default: 90)",
    )
    parser.add_argument(
        "--plan-paid",
        type=float,
        default=500.0,
        help="USD paid for your plan over plan-months (default: 500)",
    )
    parser.add_argument(
        "--plan-months",
        type=int,
        default=3,
        help="number of months covered by --plan-paid (default: 3)",
    )
    parser.add_argument("--json", action="store_true", help="emit machine-readable JSON")
    parser.add_argument("--verbose", action="store_true", help="show 7d/30d/90d/all windows")
    parser.add_argument("--charts", action="store_true", help="render ASCII charts of daily metrics")
    parser.add_argument("--by-project", action="store_true", help="show per-project cost breakdown")
    parser.add_argument(
        "--evidence",
        action="store_true",
        help="emit full evidence pack JSON (suitable for embedding in a public audit)",
    )
    args = parser.parse_args(argv)

    if not os.path.isdir(args.projects_dir):
        print(f"error: projects dir not found: {args.projects_dir}", file=sys.stderr)
        return 2

    files = find_jsonl_files(args.projects_dir)
    if not files:
        print(f"error: no JSONL files under {args.projects_dir}", file=sys.stderr)
        return 3

    windows = (
        {"7d": 7, "30d": 30, "90d": 90, "all": 99999}
        if args.verbose or args.evidence or args.charts
        else {f"{args.window}d": args.window}
    )

    t0 = time.time()
    metrics, per_day, per_project, stats = scan_files(files, windows)
    elapsed = time.time() - t0

    if args.json or args.evidence:
        payload = build_evidence_pack(
            metrics, per_day, per_project, stats, args.plan_paid, args.plan_months
        )
        payload["scan"]["elapsed_seconds"] = round(elapsed, 2)
        payload["scan"]["projects_dir"] = args.projects_dir
        print(json.dumps(payload, indent=2, sort_keys=True))
        return 0

    print(f"cognitive-claude / cost-audit")
    print(f"  source:  {args.projects_dir}")
    print(f"  files:   {stats['files_processed']:,} of {stats['files']:,} processed")
    print(f"  scanned: {stats['lines_total']:,} lines  ({stats['lines_malformed']:,} malformed) in {elapsed:.1f}s")
    if stats.get("max_record_timestamp"):
        print(f"  span:    {stats['min_record_timestamp'][:10]}  to  {stats['max_record_timestamp'][:10]}")
    if stats.get("records_no_timestamp"):
        print(f"  warn:    {stats['records_no_timestamp']:,} records with usage but no timestamp (excluded)")
    print()

    if args.verbose:
        for label in ("7d", "30d", "90d", "all"):
            if label not in metrics:
                continue
            print(f"=== {label} ===")
            print(render_summary(metrics[label], args.plan_paid, args.plan_months))
            print(render_per_model(metrics[label]))
            print()
    else:
        primary_label = f"{args.window}d"
        if primary_label not in metrics:
            primary_label = list(metrics.keys())[0]
        print(render_summary(metrics[primary_label], args.plan_paid, args.plan_months))
        print()
        print(render_per_model(metrics[primary_label]))
        print()

    if args.charts:
        print(render_charts(per_day))

    if args.by_project:
        print(render_by_project(per_project))

    return 0


if __name__ == "__main__":
    sys.exit(main())
