#!/usr/bin/env bash
# cognitive-claude / hooks / telemetry.sh
#
# PostToolUse hook. Logs every tool call to ~/.claude/telemetry/ in
# structured pipe-delimited format. Zero context cost (runs outside LLM).
#
# Reads JSON from stdin. Writes append-only logs.
# Never fails the calling tool — exits 0 on any error.
#
# Logs produced:
#   tools-YYYY-MM.log          all tool calls (monthly rotation)
#   tool-freq-YYYY-MM.log      tool frequency counter
#   skills.log                 skill invocations
#   departments.log            skill department (prefix before colon)
#   agents.log                 sub-agent dispatches with model
#   file-ops.log               file Read/Write/Edit operations
#   activity-hours.log         hourly activity heatmap
#   models.log                 model usage tracking
#
# Read by: tools/telemetry-engine.py (dashboard)

set -e

DIR="${HOME}/.claude/telemetry"
mkdir -p "$DIR"

INPUT=$(cat)

DATE=$(date +%Y-%m-%d)
TS=$(date +%Y-%m-%dT%H:%M:%S)
HOUR=$(date +%H)
MONTH=$(date +%Y-%m)

# Single python3 call to extract all fields at once (faster than multiple calls)
PARSED=$(echo "$INPUT" | python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
    ti = d.get('tool_input', {})
    tn = d.get('tool_name', '')
    sid = d.get('session_id', 'unknown')
    model = d.get('model', '')
    tij = json.dumps(ti)[:300]
    skill = ti.get('skill', '') if tn == 'Skill' else ''
    atype = ti.get('subagent_type', 'general') if tn == 'Agent' else ''
    adesc = ti.get('description', '') if tn == 'Agent' else ''
    amodel = ti.get('model', '') if tn == 'Agent' else ''
    fpath = ti.get('file_path', '') if tn in ('Read','Write','Edit') else ''
    print(f'{tn}|{sid}|{tij}|{skill}|{atype}|{adesc}|{fpath}|{model}|{amodel}')
except:
    print('||||||||||')
" 2>/dev/null)

IFS='|' read -r TOOL_NAME SESSION_ID TOOL_INPUT_JSON SKILL AGENT_TYPE AGENT_DESC FILE_PATH MODEL AGENT_MODEL <<< "$PARSED"

# 1. Raw tool log (monthly rotation to keep file sizes manageable)
echo "${TS}|${TOOL_NAME}|${SESSION_ID}|${TOOL_INPUT_JSON}" >> "$DIR/tools-${MONTH}.log"

# 2. Tool frequency (monthly rotation)
echo "${TS}|${TOOL_NAME}" >> "$DIR/tool-freq-${MONTH}.log"

# 3. Skills tracking (with department prefix if colon-separated)
if [ -n "$SKILL" ]; then
  echo "${TS}|${SKILL}" >> "$DIR/skills.log"
  DEPT=$(echo "$SKILL" | cut -d: -f1)
  echo "${TS}|${DEPT}" >> "$DIR/departments.log"
fi

# 4. Sub-agent dispatches with model (critical for cost analysis)
if [ "$TOOL_NAME" = "Agent" ] || [ "$TOOL_NAME" = "Task" ]; then
  echo "${TS}|${AGENT_TYPE}|${AGENT_DESC}|${AGENT_MODEL}" >> "$DIR/agents.log"
fi

# 5. File operations (extension tracking helps spot codebase patterns)
if [ -n "$FILE_PATH" ]; then
  EXT="${FILE_PATH##*.}"
  echo "${TS}|${TOOL_NAME}|${EXT}|${FILE_PATH}" >> "$DIR/file-ops.log"
fi

# 6. Hourly activity heatmap
echo "${DATE}|${HOUR}" >> "$DIR/activity-hours.log"

# 7. Model usage
if [ -n "$MODEL" ]; then
  echo "${TS}|${MODEL}" >> "$DIR/models.log"
fi

exit 0
