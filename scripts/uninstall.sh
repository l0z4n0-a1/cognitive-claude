#!/usr/bin/env bash
# uninstall.sh — Reverse a cognitive-claude install cleanly.
# Idempotent. Read-only by default; --apply to actually remove.
# Restores from ~/.claude/.backups/ if present.
#
# Usage:
#   bash scripts/uninstall.sh                       # dry-run
#   bash scripts/uninstall.sh --apply               # remove + restore
#   bash scripts/uninstall.sh --apply --keep-telemetry
#                                                   # remove hooks, keep logs

set -euo pipefail

CLAUDE_DIR="${HOME}/.claude"
BACKUP_DIR="${CLAUDE_DIR}/.backups"
APPLY=false
KEEP_TELEMETRY=false

for arg in "$@"; do
  case "$arg" in
    --apply) APPLY=true ;;
    --keep-telemetry) KEEP_TELEMETRY=true ;;
    -h|--help) sed -n '2,12p' "$0"; exit 0 ;;
    *) echo "unknown arg: $arg" >&2; exit 1 ;;
  esac
done

log() { printf '[uninstall] %s\n' "$*"; }

# 1. Restore settings.json from latest backup
LATEST_SETTINGS=""
[ -d "$BACKUP_DIR" ] && LATEST_SETTINGS=$(ls -1t "$BACKUP_DIR"/settings.json.* 2>/dev/null | head -1 || true)
if [ -n "$LATEST_SETTINGS" ]; then
  if $APPLY; then
    cp "$LATEST_SETTINGS" "${CLAUDE_DIR}/settings.json"
    log "restored settings.json from $LATEST_SETTINGS"
  else
    log "would restore: ${CLAUDE_DIR}/settings.json from $LATEST_SETTINGS"
  fi
else
  log "WARNING: no settings.json backup found in $BACKUP_DIR"
  log "         your hooks block must be edited manually"
  log "         search for: bash ~/.claude/hooks/{telemetry,cache-guard,token-economy-*}.sh"
fi

# 2. Restore CLAUDE.md if backup found (Phase 3 only)
LATEST_CLAUDE_MD=""
[ -d "$BACKUP_DIR" ] && LATEST_CLAUDE_MD=$(ls -1t "$BACKUP_DIR"/CLAUDE.md.* 2>/dev/null | head -1 || true)
if [ -n "$LATEST_CLAUDE_MD" ]; then
  if $APPLY; then
    cp "$LATEST_CLAUDE_MD" "${CLAUDE_DIR}/CLAUDE.md"
    log "restored CLAUDE.md from $LATEST_CLAUDE_MD"
  else
    log "would restore: ${CLAUDE_DIR}/CLAUDE.md from $LATEST_CLAUDE_MD"
  fi
fi

# 3. Remove hooks
log "--- removing hooks ---"
for h in telemetry.sh cache-guard.sh token-economy-guard.sh \
         token-economy-boot.sh token-economy-session-end.sh; do
  path="${CLAUDE_DIR}/hooks/${h}"
  if [ -f "$path" ]; then
    if $APPLY; then rm "$path" && log "removed: $path"
    else log "would remove: $path"; fi
  else
    log "not present: $path"
  fi
done

# 4. Telemetry directory
TELE_DIR="${CLAUDE_DIR}/telemetry"
if [ -d "$TELE_DIR" ]; then
  if $KEEP_TELEMETRY; then
    log "keeping telemetry/ (--keep-telemetry)"
  elif $APPLY; then
    mv "$TELE_DIR" "${TELE_DIR}.removed.$(date +%Y%m%d-%H%M%S)"
    log "moved telemetry/ to ${TELE_DIR}.removed.<ts> (not deleted)"
  else
    log "would move: $TELE_DIR -> ${TELE_DIR}.removed.<ts>"
  fi
fi

log "--- summary ---"
if $APPLY; then
  log "uninstall complete. Backups preserved in $BACKUP_DIR"
  log "to fully purge backups: rm -rf $BACKUP_DIR (after verifying no rollback needed)"
else
  log "DRY RUN. Re-run with --apply to execute."
fi
