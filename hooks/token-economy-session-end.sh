#!/usr/bin/env bash
# cognitive-claude / hooks / token-economy-session-end.sh
#
# Stop hook. Closes the calibration feedback loop at session end.
# Runs the bridge: compares estimated vs actual token usage for the
# session, persists delta to history.
#
# Over time, the rolling delta_pct calibrates future estimates,
# making the audit increasingly accurate. This is the core of the
# closed-loop control architecture (see README "five-phase loop").
#
# Output: appends one JSON line to ~/.claude/cognitive-claude/bridge-history.jsonl
# Format: {date, est_boot, real_boot, delta_pct, cache_rate, sessions, turns}
#
# Never blocks session close. Background-safe.

set +e

CC_DIR="${HOME}/.claude/cognitive-claude"
BRIDGE_HISTORY="${CC_DIR}/bridge-history.jsonl"
BRIDGE_SCRIPT="${CC_DIR}/tools/bridge.sh"

mkdir -p "$CC_DIR"

# Bridge needs to exist; skip silently if not installed
if [ ! -f "$BRIDGE_SCRIPT" ]; then
  exit 0
fi

# Run bridge for last 1 day window in JSON mode
BRIDGE_JSON=$(BRIDGE_DAYS=1 bash "$BRIDGE_SCRIPT" 1 --json 2>/dev/null || echo '{}')

# Append compact summary to bridge history
echo "$BRIDGE_JSON" | python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
    out = {
        'date': d.get('date', ''),
        'est_boot': d.get('audit_estimate', {}).get('total', 0),
        'real_boot': d.get('real_usage', {}).get('avg_boot_tokens', 0),
        'delta_pct': d.get('comparison', {}).get('delta_pct', 0),
        'cache_rate': d.get('real_usage', {}).get('cache_hit_rate', 0),
        'sessions': d.get('real_usage', {}).get('sessions', 0),
        'turns': d.get('real_usage', {}).get('turns', 0),
    }
    with open(sys.argv[1], 'a') as f:
        f.write(json.dumps(out) + '\n')
except:
    pass
" "$BRIDGE_HISTORY" 2>/dev/null

exit 0
