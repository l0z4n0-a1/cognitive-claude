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

TOOL_NAME="${CLAUDE_TOOL_NAME:-}"
TOOL_INPUT="${CLAUDE_TOOL_INPUT:-}"

# Only inspect Write tool calls
if [ "$TOOL_NAME" != "Write" ]; then
  exit 0
fi

# Only inspect writes to .claude/rules/ directories
if ! echo "$TOOL_INPUT" | grep -qi '\.claude[/\\]rules[/\\]'; then
  exit 0
fi

# Check if content has globs frontmatter
if echo "$TOOL_INPUT" | grep -qi 'globs:'; then
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
