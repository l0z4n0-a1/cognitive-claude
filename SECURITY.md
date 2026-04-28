# SECURITY.md

This project installs hooks and a CLAUDE.md into your `~/.claude/`
directory. Hooks are bash scripts that run on every tool call, every
session boundary, every compaction. You should know what they do
before installing them.

This document is short on purpose.

---

## Audit before installing

Before clone, before paste, before letting Claude install anything:

```bash
# 1. Inspect every hook with a code linter
shellcheck hooks/*.sh

# 2. Read every hook end to end
for f in hooks/*.sh; do
  echo "=== $f ==="
  cat "$f"
  echo
done

# 3. Read the Constitution
cat CLAUDE.md
```

If you cannot read bash and Markdown comfortably, do not install.
The point of this project is operator literacy — adopting it
without reading it defeats the purpose.

---

## Threat model (what these hooks can and cannot do)

### What hooks can do

- Read any file on your filesystem the shell user can read
- Write to `~/.claude/telemetry/` (telemetry hook does this)
- Print to stdout/stderr (warnings, status messages)
- Run any subprocess your shell can run

### What hooks in this repo actually do

| Hook | What it touches |
|---|---|
| `telemetry.sh` | Writes append-only logs to `~/.claude/telemetry/`. Reads tool-call JSON from stdin. |
| `cache-guard.sh` | Reads tool input. Prints warnings. Writes nothing. |
| `token-economy-guard.sh` | Reads tool input. Prints warnings. Writes nothing. |
| `token-economy-boot.sh` | Reads optional `~/.claude/cognitive-claude/` files if present. Prints status. |
| `token-economy-session-end.sh` | Reads optional `~/.claude/cognitive-claude/` files. Appends to bridge-history JSONL. |

### What hooks in this repo do NOT do

- Do not call external APIs
- Do not exfiltrate data
- Do not modify files outside `~/.claude/`
- Do not require root/admin
- Do not auto-update
- Do not phone home

You can verify all of the above with `shellcheck` plus a careful read.
If you find behavior that contradicts this list, that is a security
bug — open an issue immediately.

---

## What you authorize when you install

When you copy these hooks into `~/.claude/hooks/` and register them
in `settings.json`, you authorize Claude Code to execute them on
every matching event in every future session.

This authorization is reversible at any time:

```bash
# Remove all cognitive-claude hooks
rm ~/.claude/hooks/telemetry.sh
rm ~/.claude/hooks/cache-guard.sh
rm ~/.claude/hooks/token-economy-guard.sh
rm ~/.claude/hooks/token-economy-boot.sh
rm ~/.claude/hooks/token-economy-session-end.sh

# Restore your settings.json from backup
cp ~/.claude/.backups/settings.json.<DATE> ~/.claude/settings.json
```

---

## Reporting issues

For non-security bugs: open a GitHub issue.

For anything that affects how the hooks touch your filesystem,
read your data, or behave unexpectedly in security-sensitive ways:

1. Do not open a public issue first
2. Open a private security advisory on GitHub:
   https://github.com/l0z4n0-a1/cognitive-claude/security/advisories/new
3. Include: which hook, which platform (macOS/Linux/WSL), which
   Claude Code version, exact reproduction steps

Response target: 7 days for acknowledgment. No bounty program — this
is a personal project with public source.

---

## Special warning: `INSTALL_PROMPT.md` is a prompt-injection surface

The Claude-native install path lets your own Claude Code instance read
`INSTALL_PROMPT.md` and execute the install. This is convenient, but
it has a real failure mode you must understand:

**If you clone a fork of this repo, you are letting Claude execute
whatever the fork's `INSTALL_PROMPT.md` tells it to.** A malicious
fork could replace install instructions with anything Claude can
execute on your machine — file reads, shell commands, network calls.

Mitigations:

1. **Clone only from `github.com/l0z4n0-a1/cognitive-claude`** unless
   you trust the fork author personally.
2. **Read `INSTALL_PROMPT.md` before invoking it.** It is 361 lines.
   Skim time: 5 minutes. Worth it.
3. **Run `git log --oneline -20` and check commit history** before
   trusting a fork.
4. **Use the manual install path** (`docs/INSTALL.md`) if you cannot
   verify the fork. Manual install is auditable line-by-line.

The Claude-native installer is a feature, not a contract. You are
authorizing your Claude to act on a markdown file. Treat that
authorization with the same care as `curl | bash`.

---

## Trust boundary

This project is one operator's setup, made public.

- The author runs all of these hooks in production every day
- The hooks are MIT-licensed; you may modify or replace any of them
- The Constitution is opinionated; you may extend in your project-level
  CLAUDE.md but it warns against contradiction (Section 7 of the file)
- No telemetry is sent anywhere external. All data stays local.

If you do not trust the author, fork the repo, audit the hooks, and
run the fork. That is exactly what the architecture is designed to
support.
