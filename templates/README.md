# Project Templates

Three starter templates for project-level `.claude/settings.json`.
Drop into `<your-repo>/.claude/settings.json` and adapt the deny
patterns to your stack.

| Template | Use when | Adds |
|---|---|---|
| **`project-simple.json`** | Most personal projects, side projects, MVPs | Conservative deny on destructive bash + env file reads |
| **`project-squad.json`** | Multi-agent / experimental AGENT_TEAMS work | Simple's deny + extended git deny + AGENT_TEAMS env flag |
| **`project-sensitive.json`** | Repos with secrets, credentials, private keys, production credentials | Reinforced deny on every common secret path + binary key formats |

## How to use

```bash
mkdir -p <your-repo>/.claude
cp templates/project-simple.json <your-repo>/.claude/settings.json
# (then edit to suit your specific stack)
```

## Why deny-only

Project templates ship deny patterns, not allow patterns. Reason:
the global `~/.claude/settings.json` already declares what tools the
operator allows; the project-level settings can only narrow that
allowance. **Deny is composable; allow is not.**

A project template that adds an allow pattern is asking for trouble:
either it duplicates the global (waste) or it widens it
(security regression). Stick to deny.

## What is intentionally NOT in any template

- **Hooks.** Project hooks risk drift between operators. Hooks live
  in the global setup. The repo's hooks (telemetry, cache-guard,
  tier-contradiction-guard, etc.) are installed once at the
  global level via `INSTALL_PROMPT.md` or `docs/INSTALL.md`.
- **Skills / agents.** Same reason. Project-level customization of
  cognitive behavior is footgun territory. The Constitution at
  global level provides the consistent reasoning across projects.
- **Allow patterns.** See above.

## Audit before you trust

Before pasting any of these into a project, read the file. Each
deny pattern should make sense for *your* stack. If you don't
recognize what `Bash(git clean -f*)` blocks, look it up. The
templates are starting points, not contracts.
