#!/usr/bin/env bash
# cost-audit.sh — Personalized waste report for your ~/.claude/.
# Reads existing files; writes nothing. Pure read-only.
# Computes the 5 success metrics from MATH.md against your real data.
#
# Usage:
#   bash tools/cost-audit.sh              # human-readable report (last 7 days)
#   bash tools/cost-audit.sh --json       # machine-readable
#   bash tools/cost-audit.sh --days 30    # widen telemetry window
#
# Requires: bash, python3 (3.8+), wc, grep, find, awk.
# Tested on: macOS 14, Ubuntu 22, WSL2, Git Bash on Windows 11.
#
# WARNING: First run may take 10-60s if ~/.claude/projects/ has
# 1000+ JSONL files. Use --days <N> to bound recent telemetry scope.
# Sub-agent ratio always scans full corpus (cheap; only counts turns).

set -uo pipefail
# Note: NOT using -e — counters legitimately produce 0 when paths don't exist;
# we want graceful zeros, not script death. Errors are caught explicitly below.

CLAUDE_DIR="${HOME}/.claude"
DAYS=7
OUTPUT_JSON=false

while [ $# -gt 0 ]; do
  case "$1" in
    --json) OUTPUT_JSON=true; shift ;;
    --days) DAYS="$2"; shift 2 ;;
    -h|--help) sed -n '2,17p' "$0"; exit 0 ;;
    *) echo "unknown arg: $1" >&2; exit 1 ;;
  esac
done

# STRUCTURAL COUNTERS — each guarded for missing paths
SKL=$(find "${CLAUDE_DIR}/skills" -maxdepth 3 -name SKILL.md 2>/dev/null | wc -l | tr -d '[:space:]')
CMD=$(find "${CLAUDE_DIR}/commands" -name "*.md" 2>/dev/null | wc -l | tr -d '[:space:]')
RUL=$(find "${CLAUDE_DIR}/rules" -name "*.md" 2>/dev/null | wc -l | tr -d '[:space:]')
MCP=$(grep -c -o '"mcp__[^"]*"' "${CLAUDE_DIR}/settings.json" 2>/dev/null | tr -d '[:space:]')
SKL="${SKL:-0}"
CMD="${CMD:-0}"
RUL="${RUL:-0}"
MCP="${MCP:-0}"
CMT=0
[ -f "${CLAUDE_DIR}/CLAUDE.md" ] && CMT=$(awk '{tot+=NF} END{printf "%d", tot*1.33}' "${CLAUDE_DIR}/CLAUDE.md" || echo 0)

# TELEMETRY (recent window) + SUB-AGENT RATIO (corpus, capped to 1000 most-recent files)
# Note: full corpus scans on >8000 jsonl files can hang Git Bash on Windows.
# Cap at 1000 most-recent files for tractability; tradeoff documented in docs/SMELL_TESTS.md.
TELEMETRY=$(python3 - "$DAYS" << 'PYEOF'
import json, sys
from pathlib import Path
from datetime import datetime, timedelta
days=int(sys.argv[1]); since=(datetime.now()-timedelta(days=days)).timestamp()
proj=Path.home()/".claude"/"projects"
s={"sessions":0,"turns":0,"input":0,"cache_read":0,"cache_create":0,
   "output":0,"cache_breaks":0,"main_corpus":0,"agent_corpus":0}
sids=set()
if proj.exists():
    # Filter by mtime FIRST to avoid sorting 8k+ files
    candidates = []
    for p in proj.rglob("*.jsonl"):
        try:
            mt = p.stat().st_mtime
            if mt >= since:
                candidates.append((mt, p))
        except Exception:
            continue
    # Now sort the small filtered set (recent only)
    candidates.sort(key=lambda x: x[0], reverse=True)
    for mt, p in candidates:
        is_ag = p.stem.startswith("agent-")
        try:
            for line in p.open(errors="ignore"):
                try: e = json.loads(line)
                except: continue
                u = (e.get("message", {}).get("usage") or e.get("usage") or {})
                if u:
                    if is_ag: s["agent_corpus"] += 1
                    else: s["main_corpus"] += 1
                    sid = e.get("sessionId") or e.get("session_id")
                    if sid: sids.add(sid)
                    s["turns"] += 1
                    s["input"] += u.get("input_tokens", 0)
                    s["output"] += u.get("output_tokens", 0)
                    s["cache_read"] += u.get("cache_read_input_tokens", 0)
                    cw = u.get("cache_creation_input_tokens", 0)
                    s["cache_create"] += cw
                    if cw > 5000: s["cache_breaks"] += 1
        except Exception:
            continue
s["sessions"]=len(sids)
print(json.dumps(s))
PYEOF
)
[ -z "$TELEMETRY" ] && TELEMETRY='{"sessions":0,"turns":0,"input":0,"cache_read":0,"cache_create":0,"output":0,"cache_breaks":0,"main_corpus":0,"agent_corpus":0}'

read SESS TURNS INPUT CR CW OUT BRK MAIN AG <<<"$(echo "$TELEMETRY" | python3 -c '
import sys,json; d=json.load(sys.stdin)
print(d["sessions"],d["turns"],d["input"],d["cache_read"],d["cache_create"],
      d["output"],d["cache_breaks"],d["main_corpus"],d["agent_corpus"])
')"

DENOM=$((INPUT+CR))
HIT="n/a"; [ "$DENOM" -gt 0 ] && HIT=$(awk "BEGIN{printf \"%.1f\",($CR/$DENOM)*100}")
TOTAL_CORPUS=$((MAIN+AG))
AGRATIO="n/a"; [ "$TOTAL_CORPUS" -gt 0 ] && AGRATIO=$(awk "BEGIN{printf \"%.1f\",($AG/$TOTAL_CORPUS)*100}")
TPT=0; [ "$TURNS" -gt 0 ] && TPT=$(( (INPUT+CR+OUT) / TURNS ))

if $OUTPUT_JSON; then
cat << EOF
{"structural":{"commands":$CMD,"skills":$SKL,"rules":$RUL,"mcps":$MCP,"claude_md_tokens":$CMT},
 "telemetry_recent_${DAYS}d":{"sessions":$SESS,"turns":$TURNS,"input":$INPUT,
   "cache_read":$CR,"cache_create":$CW,"output":$OUT,"cache_breaks":$BRK},
 "metrics":{"cache_hit_rate_pct":"$HIT","subagent_ratio_pct_full_corpus":"$AGRATIO",
   "tokens_per_turn":$TPT,"main_corpus_turns":$MAIN,"agent_corpus_turns":$AG}}
EOF
exit 0
fi

cat << EOF

cognitive-claude — cost audit
═══════════════════════════════════════════════════════════════

STRUCTURAL (your ~/.claude/ topology)
  CLAUDE.md tokens .... $CMT [target <1500]
  Skills .............. $SKL [target <25]
  Commands ............ $CMD [target <80]
  Rules ............... $RUL
  MCPs (active) ....... $MCP [target <3]

TELEMETRY (last $DAYS days)
  Sessions ............ $SESS
  Turns ............... $TURNS
  Cache breaks (>5k) .. $BRK

THE 5 METRICS (cited from docs/MATH.md)
  Cache hit rate ...... ${HIT}%   [target ≥90%]
  Sub-agent ratio ..... ${AGRATIO}%   [target ≥60%; full-corpus, all-time]
  Tokens per turn ..... $TPT     [flat-or-rising = no waste; rising = scope]
  Est/actual delta .... <run for 14d to compute; tools/calibrate.sh in v0.2>
  Cost per turn (Max) . <see MATH §2; depends on your model mix>

CORPUS CONTEXT (full history)
  main thread turns ... $MAIN
  sub-agent turns ..... $AG

NEXT STEPS
  - Out-of-target metrics: see docs/SMELL_TESTS.md for diagnosis
  - Cache hit < 90%: check cache-guard.sh installed (Phase 2)
  - Sub-agent ratio < 60%: see docs/ARCHITECTURE.md §3.5
  - Compare to docs/CASE_STUDY.md for one operator's intervention shape

EOF
