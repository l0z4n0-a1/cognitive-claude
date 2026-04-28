# INSTALL_PROMPT.md — Claude-Native Installer

This file is **not for humans to read sequentially**. It is a prompt
for Claude Code to read and execute as installer.

The setup that ships in this repo is installed by the very tool it
optimizes. That is the meta-test: if the architecture is sound, the
LLM running in your terminal can install it by reading this file.

---

## How the operator runs this

1. Clone the repo:
   ```
   git clone https://github.com/l0z4n0-a1/cognitive-claude.git
   cd cognitive-claude
   ```

2. Open Claude Code in this directory:
   ```
   claude
   ```

3. Say one of:
   - `Read INSTALL_PROMPT.md and run Phase 1 only` (visibility, zero risk)
   - `Read INSTALL_PROMPT.md and run Phase 1 + Phase 2` (visibility + discipline)
   - `Read INSTALL_PROMPT.md and run all three phases` (full install, requires reading CLAUDE.md first)

4. Claude will follow the protocol below, with consent at each step.

---

## Protocol for Claude (read this entire section before acting)

You are about to install `cognitive-claude` into the operator's
`~/.claude/` directory. This affects how every future Claude Code
session in their environment behaves. Treat this with the seriousness
of a system-level configuration change.

### Pre-flight (mandatory, no exceptions)

Before touching anything:

1. **Confirm intent.** Tell the operator exactly what you are about
   to do, in their language. Quote the phases requested. Wait for
   explicit confirmation before any write.

2. **Detect platform.**
   ```bash
   uname -s   # Darwin / Linux / MINGW (Windows)
   echo $HOME
   which python3
   which bash
   ```
   If python3 is missing or bash is below 4.0, abort with a clear
   message — telemetry hook depends on both.

3. **Verify Claude Code is installed and working.**
   ```bash
   claude --version
   ```
   If this fails, abort. The operator is in the wrong terminal.

4. **Inspect existing setup.**
   ```bash
   ls -la ~/.claude/
   [ -f ~/.claude/CLAUDE.md ] && wc -l ~/.claude/CLAUDE.md
   [ -f ~/.claude/settings.json ] && python3 -c "import json; d=json.load(open('$HOME/.claude/settings.json')); print('hooks:', list(d.get('hooks',{}).keys()))"
   ```
   Tell the operator what already exists. **Do not overwrite without backup.**

5. **Backup mandatory.** Before any edit:
   ```bash
   DATE=$(date +%Y%m%d-%H%M%S)
   mkdir -p ~/.claude/.backups
   cp ~/.claude/settings.json ~/.claude/.backups/settings.json.$DATE 2>/dev/null
   [ -f ~/.claude/CLAUDE.md ] && cp ~/.claude/CLAUDE.md ~/.claude/.backups/CLAUDE.md.$DATE
   echo "Backed up to ~/.claude/.backups/ at $DATE"
   ```

6. **Show backup paths to operator** so they can restore manually if anything breaks.

---

### Phase 1 — Visibility (10 min, zero behavior change)

Goal: install telemetry hook, start logging, no other changes.

**Steps:**

1. **Copy the hook:**
   ```bash
   mkdir -p ~/.claude/hooks
   cp hooks/telemetry.sh ~/.claude/hooks/
   chmod +x ~/.claude/hooks/telemetry.sh
   ```

2. **Patch settings.json — add PostToolUse hook.** Use this exact
   approach (do not regenerate the entire file):

   ```bash
   python3 <<'EOF'
   import json, os
   path = os.path.expanduser('~/.claude/settings.json')
   try:
       with open(path) as f: d = json.load(f)
   except FileNotFoundError:
       d = {}

   d.setdefault('hooks', {})
   d['hooks'].setdefault('PostToolUse', [])

   # Check if our hook is already registered
   already = any(
       any('telemetry.sh' in h.get('command', '') for h in entry.get('hooks', []))
       for entry in d['hooks']['PostToolUse']
   )

   if not already:
       d['hooks']['PostToolUse'].append({
           'matcher': '',
           'hooks': [{
               'type': 'command',
               'command': 'bash ~/.claude/hooks/telemetry.sh'
           }]
       })

   with open(path, 'w') as f:
       json.dump(d, f, indent=2)
   print('Phase 1 hook registered.' if not already else 'Hook already present, no changes.')
   EOF
   ```

3. **Validate the JSON did not corrupt:**
   ```bash
   python3 -c "import json; json.load(open('$HOME/.claude/settings.json')); print('settings.json valid')"
   ```

4. **Confirm to operator:**
   - Show what was added
   - Show the backup location
   - Explain: "Your next session will start logging to `~/.claude/telemetry/`. Run 5 sessions, then ask me to compute your baseline."

5. **Stop here.** Do not proceed to Phase 2 unless operator explicitly asked.

---

### Phase 2 — Discipline (15 min, low risk, warn-only hooks)

Goal: install 4 more hooks that warn on cache breaks and bloated rules.
None of them block — they print warnings to terminal.

**Pre-flight:** Confirm Phase 1 is in place. If not, run Phase 1 first.

**Steps:**

1. **Copy the hooks:**
   ```bash
   cp hooks/cache-guard.sh           ~/.claude/hooks/
   cp hooks/token-economy-guard.sh   ~/.claude/hooks/
   cp hooks/token-economy-boot.sh    ~/.claude/hooks/
   cp hooks/token-economy-session-end.sh ~/.claude/hooks/
   chmod +x ~/.claude/hooks/*.sh
   ```

2. **Patch settings.json — add SessionStart, Stop, and PreToolUse hooks.**

   ```bash
   python3 <<'EOF'
   import json, os
   path = os.path.expanduser('~/.claude/settings.json')
   with open(path) as f: d = json.load(f)
   d.setdefault('hooks', {})

   def ensure_hook(event, matcher, command, timeout=None):
       d['hooks'].setdefault(event, [])
       for entry in d['hooks'][event]:
           if entry.get('matcher') == matcher:
               for h in entry.get('hooks', []):
                   if command in h.get('command', ''):
                       return False
               hook_obj = {'type': 'command', 'command': command}
               if timeout: hook_obj['timeout'] = timeout
               entry['hooks'].append(hook_obj)
               return True
       hook_obj = {'type': 'command', 'command': command}
       if timeout: hook_obj['timeout'] = timeout
       d['hooks'][event].append({'matcher': matcher, 'hooks': [hook_obj]})
       return True

   added = []
   if ensure_hook('SessionStart', '', 'bash ~/.claude/hooks/token-economy-boot.sh', 3000):
       added.append('SessionStart -> token-economy-boot.sh')
   if ensure_hook('Stop', '', 'bash ~/.claude/hooks/token-economy-session-end.sh', 5000):
       added.append('Stop -> token-economy-session-end.sh')
   if ensure_hook('PreToolUse', 'Bash', 'bash ~/.claude/hooks/cache-guard.sh'):
       added.append('PreToolUse(Bash) -> cache-guard.sh')
   if ensure_hook('PreToolUse', 'Edit', 'bash ~/.claude/hooks/cache-guard.sh'):
       added.append('PreToolUse(Edit) -> cache-guard.sh')
   if ensure_hook('PreToolUse', 'Write', 'bash ~/.claude/hooks/cache-guard.sh'):
       added.append('PreToolUse(Write) -> cache-guard.sh')
   if ensure_hook('PreToolUse', 'Write(*.claude/rules/*)', 'bash ~/.claude/hooks/token-economy-guard.sh'):
       added.append('PreToolUse(rules) -> token-economy-guard.sh')

   with open(path, 'w') as f:
       json.dump(d, f, indent=2)

   print(f'Phase 2 added {len(added)} hooks:')
   for a in added: print(f'  + {a}')
   EOF
   ```

3. **Validate:**
   ```bash
   python3 -c "import json; json.load(open('$HOME/.claude/settings.json')); print('settings.json valid')"
   ```

4. **Confirm to operator:**
   - Show the list of hooks added
   - Explain: "Cache breaks will now print warnings. Edits to rules without globs will be flagged. None of these block your work — they just inform."
   - Tell them to run 5 sessions before evaluating, then ask you to compute the cache hit rate delta.

---

### Phase 3 — Constitution (30 min, requires operator to read first)

Goal: replace `~/.claude/CLAUDE.md` with the 91-line Cognitive Constitution.

**This is the highest-impact change in the entire install.** Treat with maximum care.

**Pre-flight:**

1. **Refuse to proceed unless operator confirms they have read CLAUDE.md.** Ask:
   > "Phase 3 replaces your global `~/.claude/CLAUDE.md` with the 91-line Cognitive Constitution from this repo. The Constitution changes how Claude Code reasons in every future session — not just how it behaves operationally. Have you read `CLAUDE.md` in this repo end-to-end? Type 'yes, I have read it' to proceed."

   If they do not type that exact phrase, abort. Tell them to open `CLAUDE.md` in their editor and re-invoke the install when they are ready.

2. **Show diff if they have an existing CLAUDE.md:**
   ```bash
   if [ -f ~/.claude/CLAUDE.md ]; then
     diff ~/.claude/CLAUDE.md CLAUDE.md | head -50
     wc -l ~/.claude/CLAUDE.md CLAUDE.md
   fi
   ```
   Ask: "Your current CLAUDE.md is N lines. The new one is 91 lines. Above is the first 50 lines of difference. Continue?"

**Steps:**

1. **Backup (already done in pre-flight, but verify):**
   ```bash
   ls -la ~/.claude/.backups/CLAUDE.md.* 2>/dev/null | tail -1
   ```

2. **Install:**
   ```bash
   cp CLAUDE.md ~/.claude/CLAUDE.md
   ```

3. **Verify:**
   ```bash
   wc -l ~/.claude/CLAUDE.md   # should be 92 (91 lines + final newline)
   ```

4. **Cache notice to operator:**
   > "Constitution installed. This is a cache-breaking change — your next session will have one expensive boot turn (~5k–20k tokens) as Claude rebuilds its prefix cache. Subsequent turns will benefit from the smaller stable prefix. Run 10 sessions before evaluating impact. To compute impact, ask me later: 'compute my cache hit rate trend over the last 14 days'."

---

### Post-install — what to tell the operator

After whichever phases ran, end with:

```
Install complete. Three things to do:

1. Run 5–10 normal Claude Code sessions over the next few days.
2. Then come back and ask me: "compute my cognitive-claude impact"
   — I will read your telemetry logs and show you the delta.
3. If something feels wrong, your backups are in ~/.claude/.backups/.
   Restore with: cp ~/.claude/.backups/<file>.<DATE> ~/.claude/<file>
```

---

### When operator asks "compute my cognitive-claude impact"

Use the audit instrument that ships with the repo. It applies the
canonical metric definitions from `docs/MATH.md` Section 0:

```bash
python3 ~/cognitive-claude/tools/cost-audit.py --window 14 --verbose
```

If the operator did not clone the repo to `~/cognitive-claude`, adapt
the path. The script is dependency-free Python 3.8+.

Then explain the numbers in plain language. Tell them what the targets
are (cache hit ≥90%, sub-agent work share ≥50%, cost/turn under their
plan equivalent) and where they stand.

If they have not run cognitive-claude long enough to see signal, say
so honestly. The instrument output prints the time span it scanned —
use that to ground your assessment.

---

### Failure modes — handle gracefully

| Symptom | Diagnosis | Action |
|---|---|---|
| `python3` not found | Platform missing dep | Abort Phase 1, tell operator to install python3 |
| `settings.json` malformed JSON | Corrupted file | Abort, tell operator to fix manually or restore backup |
| Hook script not executable | chmod failed | Try `chmod +x` again, fail if denied |
| `~/.claude/` does not exist | Claude Code never run | Abort, tell operator to run `claude` once first |
| Existing hook with same name | Already installed | Skip, do not duplicate |
| Operator says "yes" without "I have read it" | Did not actually read CLAUDE.md | Refuse Phase 3, ask them to read |

---

### Constraints on you, Claude

- **Never run `rm -rf` anywhere in this protocol.** Removal is operator's choice, not yours.
- **Never modify files outside `~/.claude/`.** This installer's scope is bounded.
- **Always show before writing.** Operator approves each write.
- **Always backup before modifying.** No exceptions.
- **Refuse Phase 3 if Phase 2 is incomplete.** Order matters.
- **If anything fails, stop.** Do not retry blindly. Report and ask.

---

### Why this file exists in this format

The cognitive-claude project teaches a discipline: trust the cheapest
instrument that solves the problem. The cheapest instrument that can
install this project on the operator's machine is the LLM that the
operator is already running. Writing a portable bash installer that
works on macOS, Linux, WSL, with various shell quirks, with various
backup conventions, with various existing setups — would be expensive
and brittle.

This file is the install script. The LLM is the runtime.

If the operator wants automation that does not require typing into
Claude, the manual install at `docs/INSTALL.md` is fully documented
and runs in about 15 minutes per phase.
