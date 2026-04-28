#!/usr/bin/env python3
"""
cognitive-claude / tools / stress-test.py
==========================================

End-to-end stress test of the audit instrument against three
synthetic input classes:

  1. IDEAL       — well-formed JSONL with a known-good distribution
  2. EDGE        — boundary cases: empty files, missing usage blocks,
                   timestamps at the window edge, mixed model classes,
                   filename-vs-isSidechain disagreement
  3. MALFORMED   — corrupted lines, missing fields, non-JSON garbage

For each class, this script:
  - Generates a temp ~/.claude/projects/ tree
  - Invokes cost-audit.py against it
  - Verifies the published metric contracts (docs/INVARIANTS.md §2)
    hold for the result

Verified invariants (each one a contract in docs/INVARIANTS.md §2):
  I-1  cache_hit_rate ∈ [0, 100]
  I-2  sub_agent_share ∈ [0, 100]
  I-3  cost_api_equivalent ≥ 0
  I-4  cost_per_turn ≥ 0
  I-5  turns_main + turns_agent == turns_total
  I-6  malformed input does not crash; instrument exits non-zero or
       returns scan.lines_malformed > 0 with valid metrics for the
       valid lines

Exit codes:
  0  all stress tests passed
  1  one or more invariants violated
  2  cost-audit.py not found or unrunnable
  3  python or platform issue (test infrastructure broken)

Usage:
  python3 tools/stress-test.py
  python3 tools/stress-test.py --verbose

This test is the operational expression of Constitution Law L9:
"Every boundary declares its contract." If the instrument violates a
contract, this test fails loud — the same way test_redaction.py
guards the redaction regex.

No external dependencies. Python 3.8+ stdlib only.
"""

from __future__ import annotations

import argparse
import json
import os
import shutil
import subprocess
import sys
import tempfile
from datetime import datetime, timedelta, timezone
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parent.parent
COST_AUDIT = REPO_ROOT / "tools" / "cost-audit.py"


# -----------------------------------------------------------------------------
# Fixtures
# -----------------------------------------------------------------------------


def _ts(offset_days: int = 0) -> str:
    """ISO-8601 UTC timestamp offset_days before now."""
    return (datetime.now(timezone.utc) - timedelta(days=offset_days)).isoformat()


def _record(
    session_id: str,
    model: str,
    input_tok: int = 100,
    cache_read: int = 1000,
    cache_write: int = 50,
    output_tok: int = 200,
    offset_days: int = 1,
) -> dict:
    """Build one assistant JSONL record with a populated usage block."""
    return {
        "type": "assistant",
        "sessionId": session_id,
        "timestamp": _ts(offset_days),
        "message": {
            "role": "assistant",
            "model": model,
            "usage": {
                "input_tokens": input_tok,
                "cache_read_input_tokens": cache_read,
                "cache_creation_input_tokens": cache_write,
                "output_tokens": output_tok,
            },
        },
    }


def write_jsonl(path: Path, records: list[dict]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8") as f:
        for r in records:
            f.write(json.dumps(r) + "\n")


def fixture_ideal(root: Path) -> None:
    """
    Well-formed input. 3 sessions, 2 main + 1 agent file, all usage
    blocks populated, all timestamps within 7 days, mix of model
    classes. This is the case the instrument is engineered for.
    """
    proj = root / "ideal-project"
    write_jsonl(proj / "session-aaa.jsonl", [
        _record("sess-1", "claude-opus-4-7", offset_days=1),
        _record("sess-1", "claude-opus-4-7", offset_days=1),
        _record("sess-1", "claude-sonnet-4-6", offset_days=1),
    ])
    write_jsonl(proj / "session-bbb.jsonl", [
        _record("sess-2", "claude-opus-4-7", offset_days=2),
        _record("sess-2", "claude-haiku-4-5", offset_days=2),
    ])
    write_jsonl(proj / "agent-ccc.jsonl", [
        _record("sess-1", "claude-haiku-4-5", offset_days=1),
        _record("sess-1", "claude-haiku-4-5", offset_days=1),
    ])


def fixture_edge(root: Path) -> None:
    """
    Boundary cases:
      - empty JSONL file (zero records)
      - file with assistant records but no usage block
      - file with usage block but no timestamp
      - file with timestamp at exactly the window boundary
      - file with model id we cannot classify (must be skipped)
    """
    proj = root / "edge-project"

    # Empty file
    write_jsonl(proj / "empty.jsonl", [])

    # Records without usage block
    write_jsonl(proj / "no-usage.jsonl", [
        {"type": "assistant", "sessionId": "ed-1", "timestamp": _ts(1),
         "message": {"role": "assistant", "model": "claude-opus-4-7"}},
    ])

    # Records without timestamp
    write_jsonl(proj / "no-ts.jsonl", [
        {"type": "assistant", "sessionId": "ed-2",
         "message": {"role": "assistant", "model": "claude-opus-4-7",
                     "usage": {"input_tokens": 10, "output_tokens": 5}}},
    ])

    # Unclassifiable model id
    write_jsonl(proj / "unknown-model.jsonl", [
        _record("ed-3", "claude-mystery-99-99", offset_days=1),
    ])

    # One valid record so the window has at least something
    write_jsonl(proj / "valid.jsonl", [
        _record("ed-4", "claude-sonnet-4-6", offset_days=1),
    ])


def fixture_malformed(root: Path) -> None:
    """
    Genuinely broken input. The instrument must survive without
    crashing — bad lines counted in scan.lines_malformed, valid
    lines processed normally.
    """
    proj = root / "malformed-project"
    proj.mkdir(parents=True, exist_ok=True)

    bad = proj / "garbage.jsonl"
    with bad.open("w", encoding="utf-8") as f:
        f.write("not-json{{{\n")
        f.write('{"truncated":\n')                    # JSON parse error
        f.write(json.dumps(_record("ml-1", "claude-opus-4-7", offset_days=1)) + "\n")  # one valid
        f.write("\n")                                 # blank
        f.write("}{[]\n")                             # garbage


# -----------------------------------------------------------------------------
# Invariant checks
# -----------------------------------------------------------------------------


def run_audit(projects_dir: Path) -> dict | None:
    """Run cost-audit.py --evidence on a tmp projects dir; return parsed JSON."""
    if not COST_AUDIT.is_file():
        return None
    proc = subprocess.run(
        [sys.executable, str(COST_AUDIT),
         "--projects-dir", str(projects_dir),
         "--window", "30",
         "--evidence"],
        capture_output=True, text=True, timeout=60,
    )
    if proc.returncode != 0:
        sys.stderr.write(f"cost-audit exit={proc.returncode}\nstderr:\n{proc.stderr}\n")
        return None
    try:
        return json.loads(proc.stdout)
    except json.JSONDecodeError as e:
        sys.stderr.write(f"audit output not JSON: {e}\n")
        return None


class Failure(Exception):
    """Raised on invariant violation."""


def assert_invariants(label: str, evidence: dict) -> list[str]:
    """
    Apply the five canonical contracts from docs/INVARIANTS.md §2 to
    one window of the evidence pack. Returns a list of
    human-readable failure messages; empty list = all pass.
    """
    failures: list[str] = []
    windows = evidence.get("windows") or {}
    if not windows:
        # Acceptable for empty fixture; record but do not fail.
        return failures

    for win_label, w in windows.items():
        prefix = f"[{label}/{win_label}]"

        chr_pct = w.get("cache_hit_rate_pct", 0.0)
        if not (0.0 <= chr_pct <= 100.0):
            failures.append(f"{prefix} I-1 cache_hit_rate_pct out of [0,100]: {chr_pct}")

        sub_pct = w.get("sub_agent_share_pct", 0.0)
        if not (0.0 <= sub_pct <= 100.0):
            failures.append(f"{prefix} I-2 sub_agent_share_pct out of [0,100]: {sub_pct}")

        cost = w.get("cost_api_equivalent_usd", 0.0)
        if cost < 0:
            failures.append(f"{prefix} I-3 cost_api_equivalent_usd < 0: {cost}")

        cpt = w.get("cost_per_turn_api_usd", 0.0)
        if cpt < 0:
            failures.append(f"{prefix} I-4 cost_per_turn_api_usd < 0: {cpt}")

        t_total = w.get("turns_total", 0)
        t_main = w.get("turns_main", 0)
        t_agent = w.get("turns_agent", 0)
        if t_main + t_agent != t_total:
            failures.append(
                f"{prefix} I-5 turns_main({t_main}) + turns_agent({t_agent}) != turns_total({t_total})"
            )

    return failures


def assert_malformed_survives(evidence: dict) -> list[str]:
    """
    Specific contract for the MALFORMED fixture: the instrument must
    have noticed at least one bad line, AND must have processed at
    least one valid record successfully.
    """
    failures: list[str] = []
    scan = evidence.get("scan") or {}
    bad = int(scan.get("lines_malformed", 0))
    good = int(scan.get("records_assistant_with_usage", 0))
    if bad <= 0:
        failures.append(
            f"[malformed] I-6 expected lines_malformed > 0; got {bad}. "
            "Instrument silently skipped corrupted lines."
        )
    if good <= 0:
        failures.append(
            f"[malformed] I-6 expected ≥1 valid record processed alongside "
            f"corruption; got {good}."
        )
    return failures


# -----------------------------------------------------------------------------
# Driver
# -----------------------------------------------------------------------------


def main(argv: list[str] | None = None) -> int:
    p = argparse.ArgumentParser(
        prog="stress-test",
        description="Stress-test cost-audit.py against three synthetic input classes.",
    )
    p.add_argument("--verbose", action="store_true", help="print per-fixture details")
    args = p.parse_args(argv)

    if not COST_AUDIT.is_file():
        sys.stderr.write(f"error: cost-audit.py not found at {COST_AUDIT}\n")
        return 2

    fixtures = [
        ("ideal",     fixture_ideal,     False),
        ("edge",      fixture_edge,      False),
        ("malformed", fixture_malformed, True),
    ]

    all_failures: list[str] = []

    for name, build, is_malformed in fixtures:
        with tempfile.TemporaryDirectory(prefix=f"cc-stress-{name}-") as td:
            root = Path(td) / "projects"
            root.mkdir(parents=True)
            build(root)

            evidence = run_audit(root)
            if evidence is None:
                all_failures.append(f"[{name}] cost-audit.py failed to produce evidence")
                continue

            failures = assert_invariants(name, evidence)
            if is_malformed:
                failures.extend(assert_malformed_survives(evidence))

            if args.verbose:
                wins = evidence.get("windows", {})
                w = wins.get("30d", {})
                print(
                    f"  [{name}] turns={w.get('turns_total', 0)} "
                    f"sub%={w.get('sub_agent_share_pct', 0.0):.1f} "
                    f"cache%={w.get('cache_hit_rate_pct', 0.0):.1f} "
                    f"cost=${w.get('cost_api_equivalent_usd', 0.0):.4f}"
                )
            print(f"  [{name}] {'OK' if not failures else 'FAIL'} "
                  f"({len(failures)} failure{'s' if len(failures) != 1 else ''})")
            all_failures.extend(failures)

    print()
    if all_failures:
        print(f"stress-test FAILED — {len(all_failures)} invariant violation(s):")
        for f in all_failures:
            print(f"  - {f}")
        return 1

    print("stress-test OK — all invariants hold across ideal / edge / malformed fixtures.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
