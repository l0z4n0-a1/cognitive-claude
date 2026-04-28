---
doc_type: source-verified-mechanics
audience: [maintainer, deep-investigator]
prerequisite: docs/MATH.md, docs/STABILITY_DISCLAIMER.md
authority: L4 (data, captured at point in time; see STABILITY_DISCLAIMER for versioning)
captured_against: Claude Code as observed 2026-04
last_verified: 2026-04-28
---

# INTERNALS.md — Source-verified Claude Code mechanics

> ⚠️ **Category-C content.** These are implementation details. Anthropic may
> change them without notice. See `docs/STABILITY_DISCLAIMER.md`.
> Last verified: 2026-04-28. Re-derive on each Claude Code minor version.

This is the apparatus. The arithmetic in `docs/MATH.md` derives from these
mechanics. If these change, the math needs re-derivation.

---

## 1. Prompt cache — 3-zone hierarchical

Cache is **not** a single byte-prefix match. It's three zones:

**Zone A — Tools array:** 1 cache_control marker. Extras appended after marker
(advisor pattern) don't invalidate the cached prefix.

**Zone B — System array:** up to 4 markers, server-capped. Built by
`splitSysPromptPrefix` (utils/api.ts). Three operating modes:

- **Mode 1** (any MCP active): 3 blocks, all org-level. **NO global cache** on system prompt.
- **Mode 2** (MCP-free + boundary found + flag): 4 blocks, with one
  `cacheScope:'global'` block **shared across all Claude Code users worldwide**.
  Target state.
- **Mode 3** (3P providers / boundary missing): 3 blocks, org-level only.

**Zone C — Messages array:** EXACTLY 1 marker at the last user message
(penultimate for fork children).

**THE #1 RULE:** MCP active → Mode 1 → kills global cache. Single biggest
lever: stay MCP-free for main sessions; add MCP only when needed for a task;
remove after.

### TTL tiers
- Default: ephemeral 5 min
- Extended: 1 h (opt-in via flag, latched per session)

### Sticky-on latches preserve cache stability across mid-session toggles
- AFK mode beta
- Cache-editing beta
- 1-h TTL eligibility
- Overage state
- Reset on `/clear` and `/compact`

---

## 2. Cache break detection — 12 triggers

The 12 triggers (per `promptCacheBreakDetection.ts`):

```
systemPromptChanged    toolSchemasChanged       modelChanged
fastModeChanged        cacheControlChanged      globalCacheStrategyChanged
betasChanged           autoModeChanged          overageChanged
cachedMCChanged        effortChanged            extraBodyChanged
```

**Cache break cost:** light 20k → heavy 70k tokens per event. Each break
re-pays the cache_creation rate (1.25x input). See `docs/MATH.md` §6.

---

## 3. Pricing model

Per Anthropic published rates:

| Operation | Multiplier vs input |
|---|---|
| input | 1.00x |
| cache_creation | 1.25x (paid once) |
| cache_read | 0.10x (paid every turn) |
| output | 5.00x |

**The single most important fact:** output costs 5x input. Constraining
output is the largest lever after cache.

---

## 4. Sub-agent architecture — Fork vs Typed

| Type | Cache | Cost minimum | Inheritance |
|---|---|---|---|
| **Fork** (`feature('FORK_SUBAGENT')`) | HIT | ~0 | byte-exact via `renderedSystemPrompt` |
| **Typed** (`subagent_type:Explore\|Plan\|...`) | MISS | ~12-15k | own system prompt |

Explore and Plan strip CLAUDE.md auto (`tengu_slim_subagent_claudemd=true`).
General-purpose and custom do **not**.

**Rule (corrected from naive "output > 5k → subagent"):**
1. Direct tools (Read/Glob/Grep) first.
2. Fork if available and parent context preserved.
3. Typed subagent only when: (a) recursive search in unknown territory,
   (b) parallel independent work, (c) in-parent cost clearly > 15k pollution.
4. Never invoke typed by reflex.

---

## 5. Deferred tools

```typescript
isDeferredTool(tool):
    if tool.alwaysLoad === true: return false
    if tool.isMcp === true: return true  // Always deferred
```

**MCP tools always deferred by default.** They load via ToolSearch on demand.
Each non-deferred tool: ~200-500 tokens permanent. The `alwaysLoad: true`
flag overrides deferral.

---

## 6. Tool concurrency

Read-only tools (Read, Glob, Grep): execute in **parallel**.
Write tools (Edit, Write, Bash): execute in **series**.

Strategy: read everything first, then edit.

---

## 7. Memory limits

```
MAX_MEMORY_LINES = 200
MAX_MEMORY_BYTES = 25,000
```

MEMORY.md truncation: lines first, then bytes. Each entry < 150 chars.
Memory files pointed from index ARE loaded into context. Each memory
file = additional token cost.

---

## 8. Hook system — 25 events

Lifecycle events documented:

| Category | Events |
|---|---|
| Session | SessionStart, Stop |
| Tool | PreToolUse, PostToolUse |
| Context | PreCompact, PostCompact |
| Agent | TeammateIdle, TaskCreated, TaskCompleted |
| File | FileChanged, CwdChanged |
| System | InstructionsLoaded, Notification |

### 4 hook types

| Type | Mechanism | Cost |
|---|---|---|
| command | Shell script | 0 tokens |
| prompt | LLM call | 0 context tokens (~60x cheaper than Opus on Haiku) |
| http | Webhook | 0 tokens |
| agent | Agentic verification | 0 context tokens |

### `once: true` pattern

Hook self-removes after first execution. Use for: setup tasks (git fetch,
env validation). Saves repeated execution cost.

---

## 9. Skills power features (frontmatter)

```yaml
paths: ["pattern/*"]     # auto-discovery on path match
effort: 1-10             # complexity hint
shell: "bash"            # explicit shell
hooks:                   # temporary, only during skill execution
  PostToolUse:
    - matcher: "Write"
      hooks:
        - type: command
          command: "echo 'written'"
```

**Inline shell:** `!git status --short` syntax executes at skill load time,
injects output.

**Env vars:** `${CLAUDE_SKILL_DIR}`, `${CLAUDE_SESSION_ID}`.

---

## 10. CLAUDE_CODE_SIMPLE mode

Reduces tool set to 3: Bash, Read, Edit. Removes Glob, Grep, Agent, Write,
NotebookEdit. Massive token savings for simple tasks.

---

## 11. The 11-phase ingestion model

Every Claude Code session assembles context in 11 sequential phases:

| Phase | What | Strategy | Tokens | Controllable? |
|---|---|---|---|---|
| F0 | Managed Policy | EAGER | ~500 | NO |
| F1 | User Settings | EAGER | ~200 | NO |
| F2 | Project Settings | EAGER | ~300 | NO |
| F3 | CLAUDE.md | EAGER | ~3,000 | YES (slim) |
| F4a | Rules (no globs) | EAGER | ~14,000 | YES (add globs) |
| F4b | Rules (with globs) | LAZY (JIT) | 0 | — |
| F5 | Auto-memory | EAGER | ~2,900 | YES (max 200L) |
| F6a | Skills metadata | EAGER | ~2,000 | YES |
| F6b | Skills body | LAZY | 0 | — |
| F7 | Commands | EAGER | ~22,900 | YES (delete) |
| F8 | Agents | EAGER | ~14,200 | YES (delete) |
| F9 | MCP schemas | EAGER | ~5,000 | YES (disable) |
| F10 | Git status | EAGER | ~800 | NO |
| F11 | System assembly | EAGER | ~1,500 | NO |

**85% of savings come from F6-F9** (variable cost zone). F0-F5 are mostly fixed.

---

## How to falsify this document

If a Claude Code release silently changes any of the above and the repo
doesn't update within 30 days of measurable change, this document is stale.
Open an issue.

The mechanics improve only by being challenged from data. Re-derivation
is cheaper than ignorance.
