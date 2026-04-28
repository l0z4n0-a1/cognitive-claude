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

### Three install paths, pick one

This document is the **manual** path: every command shown, paste them
yourself. ~15 minutes per phase. Maximum auditability.

Two faster alternatives ship in the repo:

| Path | Command | Time | Best when |
|------|---------|------|-----------|
| **Claude-native** | `claude` then say *"Read INSTALL_PROMPT.md and run Phase 1 only"* | ~5 min interactive | You already trust your Claude Code instance and want consent-at-each-write |
| **Script** | `bash tools/install.sh --phase=1 --apply` (then `--phase=2`, `--phase=3 --i-have-read-claudemd`) | ~2 min, idempotent | You prefer reading bash to JSON, and you want a uninstaller of equal rigor (`bash tools/uninstall.sh --apply`) |
| **Manual (this doc)** | Paste each command from the sections below | ~15 min | You want to see every byte that touches your `~/.claude/` |

All three paths produce byte-identical results. Pick whichever
matches your audit appetite.

### Verify the repo before you trust it (optional, ~10 sec)

Two stdlib-only tests guard the parts of the repo that cannot be
visually audited at a glance — the redaction regex and the audit
instrument's metric contracts:

```bash
cd ~/cognitive-claude
python3 tools/test_redaction.py    # 16 tests — secret-redaction patterns
python3 tools/stress-test.py       # 3 fixtures — instrument vs ideal/edge/malformed input
```

Both should print `OK` and exit zero. If either fails, you are looking
at modified code — do not install until you understand why. See
`docs/INVARIANTS.md` §2 for the contracts the second test verifies.

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

**4. Compute baseline (preferred path: use the audit instrument).**

The reproducible way to compute your numbers is the audit instrument
that ships with this repo:

```bash
python3 ~/cognitive-claude/tools/cost-audit.py --window 7
```

It reads `~/.claude/projects/**/*.jsonl`, applies the canonical metric
definitions in `docs/MATH.md` Section 0, and prints the same five
metrics shown in the README header — for *your* workload.

If you prefer to inspect the math yourself, here is the canonical
cache-hit-rate calculation as a one-liner:

```bash
python3 -c "
import glob, json, os
cr = inp = cw = 0
for fp in glob.glob(os.path.expanduser('~/.claude/projects/**/*.jsonl'), recursive=True):
    try: f = open(fp, 'r', encoding='utf-8', errors='ignore')
    except: continue
    for line in f:
        try: rec = json.loads(line)
        except: continue
        msg = rec.get('message') or {}
        u = msg.get('usage') or {}
        if not u: continue
        cr  += u.get('cache_read_input_tokens', 0) or 0
        inp += u.get('input_tokens', 0) or 0
        cw  += u.get('cache_creation_input_tokens', 0) or 0
    f.close()
denom = cr + inp + cw
print(f'cache_read:   {cr:,}')
print(f'input_fresh:  {inp:,}')
print(f'cache_write:  {cw:,}')
print(f'cache_hit:    {100*cr/denom:.2f}%' if denom else 'N/A')
"
```

The denominator includes `cache_creation_input_tokens` deliberately —
those are real prefix tokens paid for at write-time. A formula that
omits them overstates the hit rate. See `docs/MATH.md` Section 0 for
the definitional rationale.

Three numbers to read after Phase 1:

1. **Cache hit rate.** Below 85%? You have drift. (Run audit instrument
   to see by-window trend.)
2. **Sub-agent work share.** From `cost-audit.py --verbose`, the
   "Sub-agent work share" line — fraction of your assistant turns that
   ran inside sub-agent contexts. Below 30%? Over-using main thread.
3. **Cost per turn (API equivalent).** From the same audit output.
   Below your plan's effective per-turn cost means leverage is real.

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
cp ~/cognitive-claude/hooks/cache-guard.sh                ~/.claude/hooks/
cp ~/cognitive-claude/hooks/token-economy-guard.sh        ~/.claude/hooks/
cp ~/cognitive-claude/hooks/token-economy-boot.sh         ~/.claude/hooks/
cp ~/cognitive-claude/hooks/token-economy-session-end.sh  ~/.claude/hooks/
cp ~/cognitive-claude/hooks/tier-contradiction-guard.sh   ~/.claude/hooks/
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
      },
      {
        "matcher": "Edit",
        "hooks": [
          { "type": "command", "command": "bash ~/.claude/hooks/tier-contradiction-guard.sh" }
        ]
      },
      {
        "matcher": "Write",
        "hooks": [
          { "type": "command", "command": "bash ~/.claude/hooks/tier-contradiction-guard.sh" }
        ]
      },
      {
        "matcher": "NotebookEdit",
        "hooks": [
          { "type": "command", "command": "bash ~/.claude/hooks/tier-contradiction-guard.sh" }
        ]
      }
    ]
  }
}
```

The `tier-contradiction-guard.sh` (added in v0.1.1) warns when a
project-level `CLAUDE.md` write asserts language the global Constitution
explicitly negates. Heuristic, warn-only, fail-silent if the global is
absent. See `docs/INVARIANTS.md` §3.1 for the rationale.

If you already have entries in any of these arrays, append. Do not replace.

**3. Validate.**

Run a session that edits a file. The boot hook should print a status
line at session start. If you try to edit `~/.claude/CLAUDE.md`
mid-session, you should see a `[CACHE GUARD] WARNING` message.

The boot and session-end hooks invoke `tools/audit.sh` and `tools/bridge.sh`
respectively if reachable. They locate `cost-audit.py` via, in order:
`$COGNITIVE_CLAUDE_HOME/tools/cost-audit.py`,
`~/cognitive-claude/tools/cost-audit.py`, and
`~/.claude/cognitive-claude/tools/cost-audit.py`. If you cloned the repo
to a non-canonical path, export `COGNITIVE_CLAUDE_HOME` in your shell
rc so the calibration loop closes. If unset and no canonical path
matches, the hooks degrade silently — the session still starts.

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
rm ~/.claude/hooks/tier-contradiction-guard.sh
# Phase 1 telemetry hook kept
```

---

## Phase 3 — Constitution (30 min, requires reading)

### Goal

**Replace** your `~/.claude/CLAUDE.md` with the Cognitive Constitution
(~100 lines, 9 Laws). Your original is backed up.

This is the highest-leverage and highest-risk step. The Constitution
is **law**. It changes how the LLM reasons, not just how it operates.
You must read [`CLAUDE.md`](../CLAUDE.md) end-to-end before installing.

### Disclaimer (read before checklist)

> Removing or modifying any of the 9 Laws may produce LLM behavior the
> original Constitution does not predict or protect against. The Laws
> interlock: L1 (observe before acting) and L2 (execute and verify)
> form the empirical floor; L3-L8 are layered on top. Modify with
> intent, back up before doing, and tell yourself why if you change
> something. The audit trail is your future self's only defense.

### Pre-install checklist

- [ ] You have read `CLAUDE.md` in full
- [ ] You agree with all 9 Laws of Operation
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

1. **Do not delete** any of the 9 Laws. They interlock.
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

### Read the field manual

Once any Phase is installed and you have at least 5 sessions of
telemetry, read [`docs/HANDBOOK.md`](./HANDBOOK.md). It is the
practical companion to this install — the seven things that change in
your daily work, the boot ritual, the session-close ritual, the seven
trenches you will hit and the move for each. The install document
ends; the handbook begins where it ends.

### Weekly review

Run weekly:

```bash
python3 ~/cognitive-claude/tools/cost-audit.py --window 7
```

Compare against the prior week's run (save the JSON form for diff:
`python3 ~/cognitive-claude/tools/cost-audit.py --json > week-N.json`).

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

- **v0.2** — `tools/install.sh` (cross-platform automated installer);
  `skills/` directory with reference operationalizations of the
  Constitution; CI workflow for `bash -n` + `python3 tools/test_redaction.py`
  + `sha256sum` manifest verification.
- **v0.3** — Plugin contracts (formal interface specs for third-party
  hooks/skills); ships when 3+ operators ask.
- **v0.4** — Migration guide for Cursor / Aider / Continue; ships when
  one operator from each completes the migration.

Nothing in roadmap blocks v0.1 from being useful today.
