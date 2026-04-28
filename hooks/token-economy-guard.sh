#!/usr/bin/env bash
# cognitive-claude / hooks / token-economy-guard.sh
#
# PreToolUse hook. Refuses creation of bloated rule files.
# Catches the most common waste pattern: writing rules without glob
# patterns, which load every session as permanent tax (~930 tokens).
#
# Decision tree (cheapest to most expensive):
#   Hook (0 tokens, runs outside LLM)
#   Rule + glob pattern (0 tokens, JIT loaded only when matched)
#   CLAUDE.md line (~20 tokens, in persistent prefix)
#   Skill metadata (~100 tokens, lazy body)
#   Rule WITHOUT glob (~930 tokens, permanent tax — AVOID)
#
# Does NOT block — warns only. The point is to redirect future
# decisions, not to break workflows.

# Read tool-call JSON from stdin (Claude Code's hook contract).
# Per docs/INSTALL.md and the Anthropic hook spec, hooks receive
# {tool_name, tool_input, ...} as JSON on stdin, not as env vars.

set +e  # never fail the calling tool

INPUT=$(cat)

# json.dumps() preserves newlines as literal \n so multi-line content
# stays on one shell line, which means sed -n 'Np' picks the right field.
PARSED=$(echo "$INPUT" | python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
    ti = d.get('tool_input', {}) or {}
    print(d.get('tool_name', ''))
    print(ti.get('file_path', ''))
    # json.dumps() -> embedded newlines become literal '\\n' (escaped)
    # which keeps the content on a single shell line for sed and grep.
    print(json.dumps(ti.get('content', '')))
except Exception:
    print(''); print(''); print('')
" 2>/dev/null)

TOOL_NAME=$(echo "$PARSED" | sed -n '1p')
FILE_PATH=$(echo "$PARSED" | sed -n '2p')
CONTENT=$(echo "$PARSED" | sed -n '3p')

# Only inspect Write tool calls
if [ "$TOOL_NAME" != "Write" ]; then
  exit 0
fi

# Only inspect writes to .claude/rules/ directories
if ! echo "$FILE_PATH" | grep -qi '\.claude[/\\]rules[/\\]'; then
  exit 0
fi

# Check if content has globs frontmatter
if echo "$CONTENT" | grep -qi 'globs:'; then
  exit 0  # has globs, fine
fi

cat <<'EOF'
[COGNITIVE-CLAUDE GUARD] WARNING: rule file without glob pattern.

A rule without 'globs:' frontmatter loads every session as permanent
tax (~930 tokens). Across a heavy operator's monthly usage, this is
hundreds of dollars of API equivalent.

Add a glob to your frontmatter for JIT loading:

  ---
  globs: ["**/*.py", "**/*.js"]
  ---

Or consider whether a hook would be cheaper. Decision tree:

  Hook              0 tokens (runs outside LLM)
  Rule + glob       0 tokens (JIT-loaded only when matched)
  CLAUDE.md line   ~20 tokens (in persistent prefix)
  Skill metadata  ~100 tokens (lazy body)
  Rule no glob    ~930 tokens (permanent tax — AVOID)

Not blocking — proceeding.
EOF

exit 0
