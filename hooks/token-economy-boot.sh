#!/usr/bin/env bash
# cognitive-claude / hooks / token-economy-boot.sh
#
# SessionStart hook. Restores cache discipline at session boot.
# Runs the cost audit and prints compact one-line status.
#
# Output format (stdout):
#   Boot:<estimated_tokens>tok Grade:<A-F> Health:<0-100>/100 Profile:<LIGHT|MEDIUM|HEAVY>
#
# Status is also persisted to ~/.claude/cognitive-claude/last-boot-status.txt
# for use by other tools (statusline, dashboards).
#
# Never fails hard — silent on any error so session always starts.

set +e

CC_DIR="${HOME}/.claude/cognitive-claude"
STATUS_FILE="${CC_DIR}/last-boot-status.txt"
HISTORY_FILE="${CC_DIR}/audit-history.jsonl"
AUDIT_SCRIPT="${CC_DIR}/tools/audit.sh"

mkdir -p "$CC_DIR"

# Run the audit if available (v0.2 roadmap — fails silent in v0.1)
if [ -f "$AUDIT_SCRIPT" ]; then
  bash "$AUDIT_SCRIPT" --json --history > /dev/null 2>&1
fi

# Extract compact status from latest history entry, if it exists
if [ -f "$HISTORY_FILE" ]; then
  LAST=$(tail -1 "$HISTORY_FILE" 2>/dev/null)
  if [ -n "$LAST" ]; then
    TOTAL=$(echo "$LAST" | python3 -c "import sys,json;print(json.load(sys.stdin).get('total',0))" 2>/dev/null || echo "?")
    GRADE=$(echo "$LAST" | python3 -c "import sys,json;print(json.load(sys.stdin).get('grade','?'))" 2>/dev/null || echo "?")
    HEALTH=$(echo "$LAST" | python3 -c "import sys,json;print(json.load(sys.stdin).get('health',0))" 2>/dev/null || echo "?")
    PROFILE=$(echo "$LAST" | python3 -c "import sys,json;print(json.load(sys.stdin).get('profile','?'))" 2>/dev/null || echo "?")

    STATUS="Boot:${TOTAL}tok Grade:${GRADE} Health:${HEALTH}/100 Profile:${PROFILE}"
    echo "$STATUS" > "$STATUS_FILE"
    echo "$STATUS"
  fi
fi

# v0.1 minimum-viable status: confirms hook ran without depending on
# audit/bridge tools. Once v0.2 lands, the block above takes over.
if [ ! -f "$HISTORY_FILE" ]; then
  TELEMETRY_DIR="${HOME}/.claude/telemetry"
  if [ -d "$TELEMETRY_DIR" ]; then
    TOOL_LOG="${TELEMETRY_DIR}/tool-freq-$(date +%Y-%m).log"
    if [ -f "$TOOL_LOG" ]; then
      RECENT=$(wc -l < "$TOOL_LOG" 2>/dev/null || echo "0")
      echo "cognitive-claude: telemetry active (${RECENT} tool calls logged this month)"
    else
      echo "cognitive-claude: hooks installed, telemetry not yet capturing — run any tool to confirm"
    fi
  fi
fi

exit 0
