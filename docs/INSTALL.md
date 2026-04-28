# INSTALL.md — Manual Install Guide (v0.1)

This project ships in three independent phases. Each phase has a
measurable outcome before you move to the next. Stop anywhere.

v0.1 is **manual install**. An automated `install.sh` is on the
v0.2 roadmap. The reason for manual: scripts that touch `~/.claude/`
across macOS, Linux, and WSL need cross-platform testing the operator
has not done yet. Honest beats broken.

---

## Before you start

### Prerequisites

- Claude Code installed and working (`claude --version` returns a version)
- `bash` (any modern version)
- `python3` (3.8+, only used inside `telemetry.sh` for one parsing step)
- `git` (for clone and version pinning)
- A working `~/.claude/` directory with at least one prior session

### Backup first (mandatory)

Before any phase, snapshot your current setup:

```bash
DATE=$(date +%Y%m%d-%H%M%S)
mkdir -p ~/.claude/.backups
cp ~/.claude/settings.json     ~/.claude/.backups/settings.json.$DATE
[ -f ~/.claude/CLAUDE.md ] && cp ~/.claude/CLAUDE.md ~/.claude/.backups/CLAUDE.md.$DATE
echo "Backed up to ~/.claude/.backups/"
```

If anything goes wrong, restore is one `cp` away.

### What gets touched

| Phase | Files modified                             | Reversible?         |
|-------|--------------------------------------------|---------------------|
| 1     | `~/.claude/settings.json` (hooks block)    | Yes, restore backup |
| 2     | `~/.claude/settings.json` (more hooks)     | Yes, restore backup |
| 3     | `~/.claude/CLAUDE.md` (replaced)           | Yes, backup kept    |

Nothing is deleted. Nothing is overwritten without backup.

---

## Phase 1 — Visibility (10 min, zero risk)

### Goal

Install the telemetry hook. Start logging every tool call. Get
visibility into your real cache hit rate, sub-agent ratio, and cost
per turn. No behavior changes yet.

### Steps

**1. Clone and copy the hook.**

```bash
git clone https://github.com/l0z4n0-a1/cognitive-claude.git ~/cognitive-claude
mkdir -p ~/.claude/hooks
cp ~/cognitive-claude/hooks/telemetry.sh ~/.claude/hooks/
chmod +x ~/.claude/hooks/telemetry.sh
```

**2. Register the hook in `~/.claude/settings.json`.**

Open `~/.claude/settings.json` in your editor. Find the `hooks` block.
If it does not exist, create it. Add:

```json
{
  "hooks": {
    "PostToolUse": [
      {
        "matcher": "",
        "hooks": [
          {
            "type": "command",
            "command": "bash ~/.claude/hooks/telemetry.sh"
          }
        ]
      }
    ]
  }
}
```

If you already have hooks in `PostToolUse`, add this entry to the
existing array. Do not replace.

**3. Validate.**

Run one Claude Code session. Then check the log:

```bash
ls -la ~/.claude/telemetry/
# Should show: tools-2026-04.log, tool-freq-2026-04.log, etc.

tail -3 ~/.claude/telemetry/tools-$(date +%Y-%m).log
# Should show recent tool calls in format: TIMESTAMP|TOOL_NAME|SESSION_ID|...
```

If logs appear, Phase 1 works. If not, see Troubleshooting below.

**4. Compute baseline (manual, until v0.2 tools land).**

After 5–10 sessions, calculate your cache hit rate from session JSONL
files. Anthropic stores them in `~/.claude/projects/<project>/<session>.jsonl`.
Each turn record includes `usage.input_tokens`, `usage.cache_read_input_tokens`,
`usage.cache_creation_input_tokens`.

Cache hit rate formula:

```
cache_hit_rate = sum(cache_read_tokens) / (sum(cache_read_tokens) + sum(input_tokens))
```

A one-liner:

```bash
find ~/.claude/projects -name "*.jsonl" -mtime -7 | xargs cat | python3 -c "
import sys, json
cr = inp = 0
for line in sys.stdin:
    try:
        d = json.loads(line)
        u = d.get('usage', {})
        cr += u.get('cache_read_input_tokens', 0)
        inp += u.get('input_tokens', 0)
    except: pass
total = cr + inp
print(f'Cache reads: {cr:,}')
print(f'Input tokens: {inp:,}')
print(f'Cache hit rate: {100*cr/total:.1f}%' if total else 'N/A')
"
```

Three numbers to read:

1. **Cache hit rate.** Below 85%? You have drift.
2. **Sub-agent ratio.** Count `"Task"` or `"Agent"` calls in `tool-freq-*.log` vs total. Below 30%? Over-using main thread.
3. **Cost per turn (API equivalent).** Compute via formulas in `docs/MATH.md` Section 1.

Knowing these is Phase 1's only goal.

### Rollback

```bash
cp ~/.claude/.backups/settings.json.<DATE> ~/.claude/settings.json
rm ~/.claude/hooks/telemetry.sh
# Telemetry logs in ~/.claude/telemetry/ are kept; delete manually if desired
```

---

## Phase 2 — Discipline (15 min, low risk)

### Goal

Add three more hooks that warn (not block) on the most expensive
mistakes: cache breaks, bloated rules, mid-session config edits.
Plus add session-boundary hooks for boot and close.

### Steps

**1. Copy the hooks.**

```bash
cp ~/cognitive-claude/hooks/cache-guard.sh           ~/.claude/hooks/
cp ~/cognitive-claude/hooks/token-economy-guard.sh   ~/.claude/hooks/
cp ~/cognitive-claude/hooks/token-economy-boot.sh    ~/.claude/hooks/
cp ~/cognitive-claude/hooks/token-economy-session-end.sh ~/.claude/hooks/
chmod +x ~/.claude/hooks/*.sh
```

**2. Register them in `~/.claude/settings.json`.**

Add to the existing `hooks` block:

```json
{
  "hooks": {
    "SessionStart": [
      {
        "matcher": "",
        "hooks": [
          { "type": "command", "command": "bash ~/.claude/hooks/token-economy-boot.sh", "timeout": 3000 }
        ]
      }
    ],
    "Stop": [
      {
        "matcher": "",
        "hooks": [
          { "type": "command", "command": "bash ~/.claude/hooks/token-economy-session-end.sh", "timeout": 5000 }
        ]
      }
    ],
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          { "type": "command", "command": "bash ~/.claude/hooks/cache-guard.sh" }
        ]
      },
      {
        "matcher": "Edit",
        "hooks": [
          { "type": "command", "command": "bash ~/.claude/hooks/cache-guard.sh" }
        ]
      },
      {
        "matcher": "Write",
        "hooks": [
          { "type": "command", "command": "bash ~/.claude/hooks/cache-guard.sh" }
        ]
      },
      {
        "matcher": "Write(*.claude/rules/*)",
        "hooks": [
          { "type": "command", "command": "bash ~/.claude/hooks/token-economy-guard.sh" }
        ]
      }
    ]
  }
}
```

If you already have entries in any of these arrays, append. Do not replace.

**3. Validate.**

Run a session that edits a file. The boot hook should print a status
line at session start. If you try to edit `~/.claude/CLAUDE.md`
mid-session, you should see a `[CACHE GUARD] WARNING` message.

The boot and session-end hooks degrade silently if their optional
sub-tools (`tools/audit.sh`, `tools/bridge.sh`) are absent. They are
roadmap and will land in v0.2; the hooks are forward-compatible.

**4. Compare.**

Run 5+ sessions. Re-run the cache hit rate one-liner from Phase 1.
Expected delta: 5–15 points improvement on cache hit rate. Tokens per
turn drops 20–40% on average sessions.

If your numbers got worse, **stop and investigate**. Something in your
existing setup conflicts with a hook. Restore the backup and open
an issue with the output of `bash -x ~/.claude/hooks/cache-guard.sh`.

### Rollback

```bash
cp ~/.claude/.backups/settings.json.<DATE> ~/.claude/settings.json
rm ~/.claude/hooks/cache-guard.sh
rm ~/.claude/hooks/token-economy-guard.sh
rm ~/.claude/hooks/token-economy-boot.sh
rm ~/.claude/hooks/token-economy-session-end.sh
# Phase 1 telemetry hook kept
```

---

## Phase 3 — Constitution (30 min, requires reading)

### Goal

**Replace** your `~/.claude/CLAUDE.md` with the 91-line Cognitive
Constitution. Your original is backed up.

This is the highest-leverage and highest-risk step. The Constitution
is **law**. It changes how the LLM reasons, not just how it operates.
You must read [`CLAUDE.md`](../CLAUDE.md) end-to-end before installing.

### Disclaimer (read before checklist)

> Removing or modifying any of the 8 Laws may produce LLM behavior the
> original Constitution does not predict or protect against. The Laws
> interlock: L1 (observe before acting) and L2 (execute and verify)
> form the empirical floor; L3-L8 are layered on top. Modify with
> intent, back up before doing, and tell yourself why if you change
> something. The audit trail is your future self's only defense.

### Pre-install checklist

- [ ] You have read `CLAUDE.md` in full
- [ ] You agree with all 8 Laws of Operation
- [ ] You understand Mode 2 triggers
- [ ] You understand Decision Levels and the Ambiguity rule
- [ ] You have a backup of your current CLAUDE.md (mandatory)

### Steps

**1. Backup (mandatory).**

```bash
cp ~/.claude/CLAUDE.md ~/.claude/.backups/CLAUDE.md.$(date +%Y%m%d-%H%M%S) 2>/dev/null \
  || echo "No existing CLAUDE.md to back up — fresh install"
```

**2. Install the Constitution.**

```bash
cp ~/cognitive-claude/CLAUDE.md ~/.claude/CLAUDE.md
```

**3. Verify.**

```bash
wc -l ~/.claude/CLAUDE.md
# Should output: 92 ~/.claude/CLAUDE.md
```

**4. Cache notice.**

This is a cache-breaking change. Your next session will have one
expensive boot turn (~5k–20k tokens). Subsequent turns benefit from
the smaller stable prefix.

Run 10 sessions before evaluating impact.

### Customizing the Constitution

The Constitution is **opinionated**. Some operators will want to
extend or modify. Recommended approach:

1. **Do not delete** any of the 8 Laws. They interlock.
2. **Add** project-specific extensions in your **project-level**
   CLAUDE.md (`<project>/.claude/CLAUDE.md`), not in global.
3. **Override with caution.** A project CLAUDE.md may extend but
   never contradict. Section 7 of the Constitution is the meta-rule.

If you find yourself needing to remove a Law, open an issue
explaining the case.

### Rollback

```bash
cp ~/.claude/.backups/CLAUDE.md.<DATE> ~/.claude/CLAUDE.md
```

---

## After all three phases

### Weekly review (manual until v0.2)

Run weekly:

```bash
# Cache hit rate over last 7 days
find ~/.claude/projects -name "*.jsonl" -mtime -7 | xargs cat | python3 -c "
import sys, json
cr = inp = co = 0
for line in sys.stdin:
    try:
        d = json.loads(line)
        u = d.get('usage', {})
        cr += u.get('cache_read_input_tokens', 0)
        inp += u.get('input_tokens', 0)
        co += u.get('output_tokens', 0)
    except: pass
total = cr + inp
print(f'Last 7 days:')
print(f'  Cache hit rate: {100*cr/total:.1f}%' if total else 'N/A')
print(f'  Total input:    {(inp+cr)/1e6:.1f}M tokens')
print(f'  Total output:   {co/1e6:.1f}M tokens')
"
```

If cache hit rate drops below your established baseline by more than
5 points week-over-week, audit recent changes to CLAUDE.md, settings,
or skills.

### Monthly review

Look at session sizes. Sessions that deviate >2× from your normal
are worth investigating — may indicate scope creep, drift, or a
genuinely productive new pattern worth replicating.

### Per-harness-update review

When Claude Code releases a new version:

1. Check that hook contracts still apply (settings schema may have
   changed). The official changelog will note breaking changes.
2. Re-test cache hit rate post-update. New harness versions sometimes
   change how prompt caching is invoked.

---

## Troubleshooting

### Hook not firing

Most common causes:
- Shebang missing on the script
- Executable bit not set: `chmod +x ~/.claude/hooks/*.sh`
- `settings.json` JSON syntax error: `python3 -c "import json; json.load(open('~/.claude/settings.json'))"`
- Hook timeout too low (default is 60s if unspecified)

Debug a single hook:

```bash
echo '{}' | bash -x ~/.claude/hooks/telemetry.sh
```

### Cache hit rate dropped after install

Did you install Phase 3 mid-session? Cache breaks. That is expected
once. Wait one full fresh session for the new prefix to stabilize,
then re-measure.

If cache hit rate stays low across multiple fresh sessions, your
existing `CLAUDE.md` was significantly larger than 1.3k tokens, and
the change in prefix is causing other artifacts (skills, rules) to
lose their cache anchor. Investigate skill loading patterns.

### Telemetry log growing too large

Default location: `~/.claude/telemetry/`. After 90 days of heavy use,
expect ~150MB. Compress logs older than 30 days:

```bash
find ~/.claude/telemetry -name "tools-*.log" -mtime +30 -exec gzip {} \;
```

### "I want to start over"

```bash
# Restore everything from your latest backup
cp ~/.claude/.backups/settings.json.<DATE> ~/.claude/settings.json
cp ~/.claude/.backups/CLAUDE.md.<DATE>     ~/.claude/CLAUDE.md
rm -rf ~/.claude/hooks/telemetry.sh
rm -rf ~/.claude/hooks/cache-guard.sh
rm -rf ~/.claude/hooks/token-economy-guard.sh
rm -rf ~/.claude/hooks/token-economy-boot.sh
rm -rf ~/.claude/hooks/token-economy-session-end.sh
# Telemetry logs in ~/.claude/telemetry/ stay unless you delete them
```

Your `~/.claude/` returns to pre-install state.

---

## Getting help

- **Bugs:** [github.com/l0z4n0-a1/cognitive-claude/issues](https://github.com/l0z4n0-a1/cognitive-claude/issues)
- **Math questions:** see `docs/MATH.md` first; if a formula is wrong,
  open issue with your calculation
- **Setup edge cases:** include the output of `bash -x` for the
  failing hook in the issue
- **Conceptual questions:** the README and the Constitution cover
  the why; if still unclear, open a discussion

---

## Roadmap (not vapor — order is opinionated)

- **v0.2** — `install.sh` automated, `tools/cost-audit.sh`,
  `tools/telemetry-engine.py` (sanitized dashboard generator)
- **v0.3** — Plugin contracts (formal interface specs for third-party
  hooks/skills); ships when 3+ operators ask
- **v0.4** — Migration guide from common harnesses (Cursor, Aider);
  ships when one operator from each completes the migration

Nothing in roadmap blocks v0.1 from being useful today.
