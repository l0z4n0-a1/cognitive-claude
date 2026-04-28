#!/usr/bin/env bash
# cognitive-claude / hooks / cache-guard.sh
#
# PreToolUse hook on Bash, Edit, Write, NotebookEdit.
# Detects operations that break Anthropic's prompt-cache prefix
# mid-session and warns with cost estimate.
#
# Does NOT block — warns only, then proceeds. The goal is awareness
# and behavior change over time, not friction.
#
# Cache breaks observed in production telemetry to cost 20–70k tokens
# depending on accumulated session size. See docs/MATH.md Section 6.

TOOL_NAME="${CLAUDE_TOOL_NAME:-}"
TOOL_INPUT="${CLAUDE_TOOL_INPUT:-}"

# Parse tool input once; extract only the fields we need per tool type
PARSED=$(echo "$TOOL_INPUT" | python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
    print(d.get('command', ''))
    print(d.get('file_path', ''))
except: pass
" 2>/dev/null)
CMD=$(echo "$PARSED" | sed -n '1p')
FILE_PATH=$(echo "$PARSED" | sed -n '2p')

case "$TOOL_NAME" in
  Bash)
    [ -z "$CMD" ] && exit 0

    # MCP add/remove/enable/disable mid-session = cache break
    if echo "$CMD" | grep -qE "claude[[:space:]]+mcp[[:space:]]+(add|remove|enable|disable)"; then
      echo "[CACHE GUARD] WARNING: claude mcp mutation detected mid-session."
      echo "  This flips MCP schema state and busts ~50-70k tokens of cached prefix."
      echo "  Recommended: finish current task, /clear, then make MCP changes."
      echo "  Not blocking — proceeding."
    fi

    # Model swap mid-session = cache break
    if echo "$CMD" | grep -qE "/model[[:space:]]+\w"; then
      echo "[CACHE GUARD] WARNING: model swap mid-session busts cache (~20k tokens)."
    fi
    ;;

  Edit|Write|NotebookEdit)
    [ -z "$FILE_PATH" ] && exit 0

    # CLAUDE.md edits = highest-value catch
    # Lands in dynamic block post-boundary, invalidates session-level prefix cache
    if echo "$FILE_PATH" | grep -qiE "(^|[/\\])CLAUDE\.md$"; then
      echo "[CACHE GUARD] WARNING: CLAUDE.md mutation mid-session."
      echo "  This invalidates the dynamic system-prompt cache (~50-70k tokens)."
      echo "  If this is not an emergency, batch into a pre-session window."
      echo "  Not blocking — proceeding."
    fi

    # settings.json edits MAY break cache depending on which field changes
    # Soft warn only, don't spam with false positives
    if echo "$FILE_PATH" | grep -qiE "[/\\]\.claude[/\\]settings\.json$"; then
      echo "[CACHE GUARD] NOTE: settings.json edit — verify no change to:"
      echo "  enableAllProjectMcpServers, alwaysThinkingEnabled, effortLevel,"
      echo "  advisorModel, hooks. Those fields break cache."
    fi
    ;;
esac

exit 0
