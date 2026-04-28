---
doc_type: pre-install-diagnostic
audience: [prospective-operator]
prerequisite: README.md
authority: L2 (extends, never contradicts)
reading_time: 3 minutes
execution_time: 90 seconds
---

# SMELL_TESTS.md — Should you install this?

Five one-liners. Run them in your terminal. Decide in 90 seconds whether
`cognitive-claude` solves a problem you actually have, or whether it
would be cargo-cult adoption.

**No installation required.** These tests read your existing `~/.claude/`
directory. Read-only. Zero side effects.

If your output matches the "🟢 GREEN" pattern across all five, the
install will move ~1-3% on your bottleneck. **Save the install time;
read `docs/ARCHITECTURE.md` for the principles, skip the install.**

If you hit "🔴 RED" on three or more, install Phase 1 today.

**Requires:** `python3` (3.8+). Already a prerequisite of `hooks/telemetry.sh`,
so installing later does not add a new dependency.

---

## Test 1 — True cache breaks (last 5 sessions)

What it asks: are you breaking your prompt cache often?

```bash
python3 -c "
import json
from pathlib import Path
files=sorted((Path.home()/'.claude'/'projects').rglob('*.jsonl'),
             key=lambda p:p.stat().st_mtime, reverse=True)[:5]
breaks=turns=0
for f in files:
  for line in f.open(errors='ignore'):
    try: u=(json.loads(line).get('message',{}).get('usage') or {})
    except: continue
    if u: turns+=1
    if u.get('cache_creation_input_tokens',0)>5000: breaks+=1
print(f'true_breaks:{breaks}  turns:{turns}  rate:{100*breaks/turns:.1f}%' if turns else 'no_data')
"
```

| break_rate | Verdict |
|---|---|
| 0–10% | 🟢 disciplined |
| 11–25% | 🟡 `cache-guard.sh` would warn at right moments |
| 26%+ | 🔴 chronic breaks; you pay 50k+ per break × this rate |

> Threshold tuned from author's setup. Cache break = `cache_creation_input_tokens > 5000`
> per turn. Thresholds may need tuning for your workload — open an issue with your data.

---

## Test 2 — Skill catalog tax

What it asks: is your skill catalog inflating system prompt?

```bash
find ~/.claude -maxdepth 3 -name SKILL.md 2>/dev/null | wc -l
```

| Output | Verdict |
|---|---|
| 0–8 | 🟢 lean |
| 9–25 | 🟡 worth auditing for lazy/eager split |
| 26+ | 🔴 silent killer; ~5–15k tokens of always-loaded metadata |

> Cross-ref: `docs/MATH.md` §9 — Lazy Skill Math.

---

## Test 3 — MCP tax

What it asks: are MCP tool schemas eating your prefix every turn?

```bash
grep -o '"mcp__[^"]*"' ~/.claude/settings.json 2>/dev/null \
  | sort -u | wc -l
```

| Output | Verdict |
|---|---|
| 0–2 | 🟢 minimal MCP tax |
| 3–6 | 🟡 weekly-use audit per MCP |
| 7+ | 🔴 ~7k+ permanent tax; MCP active also kills global cache |

> Cross-ref: `docs/MATH.md` §4 — MCP Tax Math. See `docs/INTERNALS.md` for
> why MCP active forces Mode 1 (no global cache).

---

## Test 4 — Constitution weight

What it asks: is your CLAUDE.md a constitution or a README?

```bash
[ -f ~/.claude/CLAUDE.md ] \
  && wc -w ~/.claude/CLAUDE.md \
       | awk '{ printf "claude_md_words:%d (~%d tokens)\n", $1, int($1*1.33) }' \
  || echo "no_global_CLAUDE.md (this is fine)"
```

| Tokens | Verdict |
|---|---|
| 0–1500 | 🟢 already constitution-shaped |
| 1500–4000 | 🟡 review against this repo's `CLAUDE.md` for what to cut |
| 4000+ | 🔴 README-as-CLAUDE.md anti-pattern; ~600k tokens/session |

> Cross-ref: `docs/MATH.md` §3 — CLAUDE.md Tax.

---

## Test 5 — Sub-agent delegation rate (full corpus)

What it asks: are you using sub-agents at all?

```bash
python3 -c "
import json
from pathlib import Path
proj=Path.home()/'.claude'/'projects'
main=ag=0
for p in proj.rglob('*.jsonl'):
  is_ag=p.stem.startswith('agent-')
  cnt=0
  for line in p.open(errors='ignore'):
    try:
      if (json.loads(line).get('message',{}).get('usage') or {}): cnt+=1
    except: pass
  if is_ag: ag+=cnt
  else: main+=cnt
total=main+ag
print(f'sub_agent_ratio:{100*ag/total:.1f}% (main:{main} agent:{ag})' if total else 'no_data')
"
```

> First run may take 5–60 seconds depending on history size. Read-only.

| Ratio | Verdict |
|---|---|
| 60%+ | 🟢 strong delegation discipline |
| 30–59% | 🟡 healthy; room to delegate more verbose ops |
| 10–29% | 🟡 main thread doing more than ideal |
| 0–9% | 🔴 minimal delegation; ~94% savings unused on verbose tasks |

> Cross-ref `docs/MATH.md` §7.

### Test 5 — Quick variant (sample of 100 recent files)

If full-corpus is too slow:

```bash
python3 -c "
import json
from pathlib import Path
files=sorted((Path.home()/'.claude'/'projects').rglob('*.jsonl'),
             key=lambda p:p.stat().st_mtime, reverse=True)[:100]
main=ag=0
for p in files:
  is_ag=p.stem.startswith('agent-')
  cnt=0
  for line in p.open(errors='ignore'):
    try:
      if (json.loads(line).get('message',{}).get('usage') or {}): cnt+=1
    except: pass
  if is_ag: ag+=cnt
  else: main+=cnt
total=main+ag
print(f'sub_agent_ratio_sample100:{100*ag/total:.1f}%' if total else 'no_data')
"
```

**Caveat:** Recent samples can skew because operators alternate between
"main thread heavy" and "sub-agent heavy" weeks. The full-corpus number
is more honest. Use --quick if friction matters; full if accuracy matters.

---

## Decision matrix

```
🟢 across 5 tests       → Read principles, skip install. Save 30 min.
🟡 on 1-2 tests          → Phase 1 only (telemetry). Re-test after 30 days.
🔴 on 1-2 tests          → Phase 1+2. Specific hooks address your bottleneck.
🔴 on 3+ tests           → Full install (Phase 1→3). High leverage available.
Mixed                    → Read docs/ARCHITECTURE.md §6 (transfer test) first.
```

---

## What this is NOT

- **Not a benchmark.** It's a smell test — directional, not measured.
- **Not a substitute for telemetry.** After install, real numbers > heuristics.
- **Not a guarantee.** 🔴 doesn't guarantee install fixes it; install is required to *find out*.
- **Not normative across profiles.** See `docs/TRANSFER.md` for adaptations.

## How to falsify this document

Run the tests. Install Phase 1. Run for 14 days. If your real telemetry
contradicts the verdict your smell tests predicted, **open an issue with
both numbers**. Thresholds get tuned from data, not opinion.
