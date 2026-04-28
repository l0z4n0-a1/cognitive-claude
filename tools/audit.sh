#!/usr/bin/env bash
# cognitive-claude / tools / audit.sh
#
# Thin wrapper around tools/cost-audit.py that the boot/end hooks call.
#
# Goals:
#   - Be a safe no-op if cost-audit.py is missing
#   - Emit a one-line JSON record on stdout (consumed by token-economy-boot.sh)
#   - Optionally append to ~/.claude/cognitive-claude/audit-history.jsonl
#
# Usage:
#   bash tools/audit.sh             # 7d window, JSON to stdout
#   bash tools/audit.sh --history   # also append to audit-history.jsonl
#   bash tools/audit.sh --json      # alias for default behavior
#
# Output schema (one JSON object):
#   { "date": "YYYY-MM-DD", "total": <eager_token_estimate>,
#     "grade": "A-F", "health": <0-100>, "profile": "LIGHT|MEDIUM|HEAVY",
#     "cache_hit": <pct>, "cost_per_turn": <usd>, "sub_share": <pct> }

set +e

CC_DIR="${HOME}/.claude/cognitive-claude"
HISTORY_FILE="${CC_DIR}/audit-history.jsonl"
mkdir -p "$CC_DIR"

# Locate cost-audit.py. Search order, first hit wins:
#   1. $COGNITIVE_CLAUDE_HOME/tools/cost-audit.py    — explicit operator override
#   2. ~/cognitive-claude/tools/cost-audit.py        — canonical clone path
#   3. ~/.claude/cognitive-claude/tools/cost-audit.py — alternative under .claude/
# Operators who clone the repo to a non-canonical path can export
#   COGNITIVE_CLAUDE_HOME=/path/to/cognitive-claude
# in their shell rc to make the boot/end hooks find the instrument.
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
  # No instrument available; emit minimal record and exit 0 (hooks are no-fail)
  date_iso=$(date -u +%Y-%m-%d)
  echo "{\"date\":\"${date_iso}\",\"total\":0,\"grade\":\"?\",\"health\":0,\"profile\":\"?\",\"note\":\"cost-audit.py not found\"}"
  exit 0
fi

# Run cost-audit on a 7-day window (cheap and recent)
RAW=$(python3 "$COST_AUDIT" --window 7 --json 2>/dev/null)
if [ -z "$RAW" ]; then
  date_iso=$(date -u +%Y-%m-%d)
  echo "{\"date\":\"${date_iso}\",\"total\":0,\"grade\":\"?\",\"health\":0,\"profile\":\"?\",\"note\":\"cost-audit.py returned empty\"}"
  exit 0
fi

# Derive a compact one-line record from the evidence pack
RECORD=$(echo "$RAW" | python3 -c "
import sys, json
from datetime import datetime, timezone
try:
    d = json.load(sys.stdin)
    w = d.get('windows', {}).get('7d', {})
    cache = w.get('cache_hit_rate_pct', 0.0)
    cpt = w.get('cost_per_turn_api_usd', 0.0)
    sub = w.get('sub_agent_share_pct', 0.0)
    turns = w.get('turns_total', 0)
    # Heuristic grading — operator-tunable
    if cache >= 90: grade = 'A'
    elif cache >= 85: grade = 'B'
    elif cache >= 75: grade = 'C'
    elif cache >= 60: grade = 'D'
    else: grade = 'F'
    health = int(min(100, max(0, cache)))
    if turns > 5000: profile = 'HEAVY'
    elif turns > 1000: profile = 'MEDIUM'
    else: profile = 'LIGHT'
    out = {
        'date': datetime.now(timezone.utc).strftime('%Y-%m-%d'),
        'total': int(w.get('tokens', {}).get('total_billable', 0)),
        'grade': grade,
        'health': health,
        'profile': profile,
        'cache_hit': round(cache, 2),
        'cost_per_turn': round(cpt, 4),
        'sub_share': round(sub, 2),
    }
    print(json.dumps(out))
except Exception as e:
    print(json.dumps({'date': '', 'total': 0, 'grade': '?', 'health': 0, 'profile': '?', 'error': str(e)[:80]}))
" 2>/dev/null)

echo "$RECORD"

# Optional: append to history
if [ "$1" = "--history" ] || [ "$2" = "--history" ]; then
  echo "$RECORD" >> "$HISTORY_FILE"
fi

exit 0
