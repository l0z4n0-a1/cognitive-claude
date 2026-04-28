#!/usr/bin/env bash
# cognitive-claude / tools / bridge.sh
#
# Closes the calibration loop at session end. Compares the audit's
# expected token usage against actual measured usage, persists the
# delta to bridge-history for future calibration.
#
# Usage:
#   bash tools/bridge.sh           # 1-day window, human-readable
#   bash tools/bridge.sh 1 --json  # 1-day window, JSON for hook consumption
#   bash tools/bridge.sh 7         # 7-day window
#
# Output (--json):
#   { "date": "...", "audit_estimate": {"total": <int>},
#     "real_usage": { "avg_boot_tokens": <int>, "cache_hit_rate": <float>,
#                     "sessions": <int>, "turns": <int> },
#     "comparison": { "delta_pct": <float> } }

set +e

# Help shortcut — show the usage block above and exit before touching anything.
for arg in "$@"; do
  case "$arg" in
    -h|--help) sed -n '2,17p' "$0"; exit 0 ;;
  esac
done

WINDOW_DAYS="${1:-1}"
WANT_JSON=0
for arg in "$@"; do
  if [ "$arg" = "--json" ]; then WANT_JSON=1; fi
done

CC_DIR="${HOME}/.claude/cognitive-claude"
HISTORY_FILE="${CC_DIR}/audit-history.jsonl"
mkdir -p "$CC_DIR"

# Locate cost-audit.py. Search order, first hit wins:
#   1. $COGNITIVE_CLAUDE_HOME/tools/cost-audit.py    — explicit operator override
#   2. ~/cognitive-claude/tools/cost-audit.py        — canonical clone path
#   3. ~/.claude/cognitive-claude/tools/cost-audit.py — alternative under .claude/
COST_AUDIT=""
CANDIDATES=()
[ -n "$COGNITIVE_CLAUDE_HOME" ] && CANDIDATES+=("${COGNITIVE_CLAUDE_HOME}/tools/cost-audit.py")
CANDIDATES+=(
  "${HOME}/cognitive-claude/tools/cost-audit.py"
  "${HOME}/.claude/cognitive-claude/tools/cost-audit.py"
)
for candidate in "${CANDIDATES[@]}"; do
  if [ -f "$candidate" ]; then
    COST_AUDIT="$candidate"
    break
  fi
done

if [ -z "$COST_AUDIT" ]; then
  if [ $WANT_JSON -eq 1 ]; then
    echo "{}"
  else
    echo "bridge: cost-audit.py not found — install incomplete"
  fi
  exit 0
fi

# Pull this-window real usage
RAW=$(python3 "$COST_AUDIT" --window "$WINDOW_DAYS" --json 2>/dev/null)

# Pull last audit-history entry (the prior boot's estimate)
LAST_AUDIT="{}"
if [ -f "$HISTORY_FILE" ]; then
  LAST_AUDIT=$(tail -1 "$HISTORY_FILE" 2>/dev/null)
fi

# Build the bridge JSON. Pass RAW + LAST_AUDIT via env to avoid shell-quote
# pitfalls (backslashes in Windows paths break heredoc-quoted Python).
RESULT=$(RAW="$RAW" LAST_AUDIT="$LAST_AUDIT" python3 -c "
import sys, json, os
from datetime import datetime, timezone
raw = os.environ.get('RAW', '') or '{}'
last = os.environ.get('LAST_AUDIT', '') or '{}'
try:
    d = json.loads(raw) if raw.strip() else {}
    last_audit = json.loads(last) if last.strip() else {}
    w_key = next(iter(d.get('windows', {})), None)
    w = d.get('windows', {}).get(w_key, {}) if w_key else {}
    real = {
        'avg_boot_tokens': 0,  # not directly measurable from JSONL
        'cache_hit_rate': round(w.get('cache_hit_rate_pct', 0.0), 2),
        'sessions': w.get('sessions', 0),
        'turns': w.get('turns_total', 0),
    }
    estimate = {
        'total': last_audit.get('total', 0),
    }
    delta_pct = 0.0
    if estimate['total'] > 0 and real['turns'] > 0:
        # Crude proxy: how does last boot's eager-token estimate compare
        # to the realized billable tokens normalized by turns
        billable = w.get('tokens', {}).get('total_billable', 0)
        if billable and real['turns']:
            avg_per_turn = billable / real['turns']
            delta_pct = round((avg_per_turn - estimate['total']) / max(estimate['total'], 1) * 100, 2)
    out = {
        'date': datetime.now(timezone.utc).strftime('%Y-%m-%d'),
        'audit_estimate': estimate,
        'real_usage': real,
        'comparison': {'delta_pct': delta_pct},
    }
    print(json.dumps(out))
except Exception as e:
    print(json.dumps({'date': '', 'audit_estimate': {'total': 0}, 'real_usage': {}, 'comparison': {'delta_pct': 0}, 'error': str(e)[:80]}))
" 2>/dev/null)

if [ $WANT_JSON -eq 1 ]; then
  echo "$RESULT"
else
  # Human-readable summary
  echo "$RESULT" | python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
    r = d.get('real_usage', {})
    print(f\"bridge ({d.get('date','')}) — sessions {r.get('sessions',0)} turns {r.get('turns',0)} cache {r.get('cache_hit_rate',0)}%  delta {d.get('comparison',{}).get('delta_pct',0)}%\")
except: pass
" 2>/dev/null
fi

exit 0
