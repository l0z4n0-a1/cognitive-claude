#!/usr/bin/env bash
# cognitive-claude / hooks / tier-contradiction-guard.sh
#
# PreToolUse hook on Edit, Write, NotebookEdit. Materializes the
# governance boundary L1↔L4 (global Constitution ↔ project CLAUDE.md)
# documented declaratively in docs/ARCHITECTURE.md §3.7 and
# docs/INVARIANTS.md §3.1.
#
# Rule (Constitution §7 meta-rule, paraphrased):
#   Project CLAUDE.md may extend, but never contradict, the global
#   Constitution at ~/.claude/CLAUDE.md.
#
# This hook applies a heuristic check: when the operator (or Claude)
# writes a project-level CLAUDE.md, we scan the new content for
# language the global negates and warn. Heuristic — not a parser.
# False positives are accepted; the cost of missing a contradiction
# is higher than the cost of a stray warning.
#
# Does NOT block — warns only. The point is to surface the boundary,
# not to gate authorship.
#
# Fail-silent on any error (set +e + 2>/dev/null on parse). Hooks
# must never break the calling tool.
#
# Implementation note: the heuristic engine is delegated to a small
# embedded Python script piped via stdin (heredoc). This avoids the
# bash → python3 -c quoting hazard that would otherwise mangle the
# regex backslashes.

set +e

# Skip cleanly if global Constitution is absent (fresh install,
# non-Claude-Code environment, etc.)
GLOBAL_CONSTITUTION="${HOME}/.claude/CLAUDE.md"
[ ! -f "$GLOBAL_CONSTITUTION" ] && exit 0

INPUT=$(cat)

# Stage 1: parse tool-call envelope.
#
# We pass INPUT via env (HOOK_INPUT) instead of stdin because the
# embedded Python uses a heredoc, which would itself capture stdin
# and shadow the upstream pipe. Env-passthrough avoids that hazard
# and avoids shell-quote pitfalls in tool-call payloads.
PARSED=$(HOOK_INPUT="$INPUT" python3 <<'PYEOF' 2>/dev/null
import os, json
raw = os.environ.get('HOOK_INPUT', '')
try:
    d = json.loads(raw) if raw else {}
    ti = d.get('tool_input', {}) or {}
    print(d.get('tool_name', ''))
    print(ti.get('file_path', ''))
    # Edit tool uses 'new_string'; Write/NotebookEdit use 'content'.
    # json.dumps preserves embedded newlines as escaped \n so the
    # value stays on a single shell line for sed.
    print(json.dumps(ti.get('content', '') or ti.get('new_string', '')))
except Exception:
    print(''); print(''); print('')
PYEOF
)

TOOL_NAME=$(echo "$PARSED" | sed -n '1p')
FILE_PATH=$(echo "$PARSED" | sed -n '2p')
CONTENT=$(echo "$PARSED" | sed -n '3p')

# Only inspect Edit / Write / NotebookEdit
case "$TOOL_NAME" in
  Edit|Write|NotebookEdit) ;;
  *) exit 0 ;;
esac

# Only inspect writes targeting a file named CLAUDE.md
if ! echo "$FILE_PATH" | grep -qiE "(^|[/\\])CLAUDE\.md$"; then
  exit 0
fi

# Resolve absolute paths; bail if either resolution fails or paths match
# (writing the global Constitution itself is out of scope for this hook —
# cache-guard.sh already covers that case).
ABS_FILE_PATH=$(python3 -c "import os,sys; print(os.path.realpath(sys.argv[1]))" "$FILE_PATH" 2>/dev/null)
ABS_GLOBAL=$(python3 -c "import os,sys; print(os.path.realpath(sys.argv[1]))" "$GLOBAL_CONSTITUTION" 2>/dev/null)
if [ -z "$ABS_FILE_PATH" ] || [ "$ABS_FILE_PATH" = "$ABS_GLOBAL" ]; then
  exit 0
fi

# Stage 2: heuristic contradiction check.
#
# Strategy: extract negation phrases from the global Constitution
# ("never X", "must not X", "do not X", "forbidden X") and test
# whether the project CLAUDE.md asserts any of those tokens in a
# non-negated local context.
#
# Heuristic by design — false positives are tolerated because we
# warn-only and false negatives are tolerable because the operator
# is the final arbiter (Constitution §7 meta-rule).
HITS=$(GLOBAL_PATH="$GLOBAL_CONSTITUTION" CONTENT="$CONTENT" python3 <<'PYEOF' 2>/dev/null
import os, json, re, sys

global_path = os.environ.get('GLOBAL_PATH', '')
content_raw = os.environ.get('CONTENT', '')

# CONTENT was passed through json.dumps in the parser stage, so unwrap.
# On an empty/missing field, fall back to literal "".
try:
    content = json.loads(content_raw) if content_raw else ''
except Exception:
    content = content_raw

if not content or not global_path or not os.path.exists(global_path):
    sys.exit(0)

try:
    with open(global_path, 'r', encoding='utf-8', errors='ignore') as f:
        global_text = f.read()
except OSError:
    sys.exit(0)

NEG_PATTERNS = [
    re.compile(r'(?i)\bnever\s+([a-z][a-z0-9 \-_/]{4,40})'),
    re.compile(r'(?i)\bmust\s+not\s+([a-z][a-z0-9 \-_/]{4,40})'),
    re.compile(r'(?i)\bforbidden[:\s]+([a-z][a-z0-9 \-_/]{4,40})'),
    re.compile(r'(?i)\bdo\s+not\s+([a-z][a-z0-9 \-_/]{4,40})'),
]

candidates = set()
for p in NEG_PATTERNS:
    for m in p.findall(global_text):
        token = m.strip().rstrip('.,;:').lower()
        if 4 <= len(token) <= 40:
            candidates.add(token)

content_lower = content.lower()
NEG_LOCAL = re.compile(r'\b(never|not|forbidden|avoid|skip)\b')

hits = []
for token in candidates:
    idx = content_lower.find(token)
    if idx < 0:
        continue
    before = content_lower[max(0, idx - 30):idx]
    if NEG_LOCAL.search(before):
        continue  # asserted in a negated local context — not a contradiction
    hits.append(token)

# Cap output volume so a noisy global cannot flood the operator's terminal.
for h in hits[:5]:
    print(h)
PYEOF
)

if [ -n "$HITS" ]; then
  cat <<'EOF'
[TIER GUARD] WARNING: project CLAUDE.md may contradict the global Constitution.

The global ~/.claude/CLAUDE.md contains directives that appear to be
asserted (rather than negated) in the new content. Heuristic match —
review and confirm intent.

Possibly contradicted phrases in your project CLAUDE.md:
EOF
  echo "$HITS" | sed 's/^/  - /'
  cat <<'EOF'

Per the Constitution's meta-rule (Section 7): "Project CLAUDE.md may
extend but never contradict the global. In conflict, global prevails."

If this is intentional (overriding for this project only), document
why in a header comment. If unintentional, revise.

Not blocking — proceeding.
EOF
fi

exit 0
