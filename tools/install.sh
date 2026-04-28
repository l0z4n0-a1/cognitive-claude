#!/usr/bin/env bash
# tools/install.sh — cognitive-claude installer (v0.1.1)
#
# Idempotent. Phase-gated. Backs up before any write. Dry-run by default.
#
# Usage:
#   bash tools/install.sh                                    # dry-run, shows the plan
#   bash tools/install.sh --phase=1 --apply                  # Phase 1 (telemetry only)
#   bash tools/install.sh --phase=2 --apply                  # Phase 2 (5 more hooks, warn)
#   bash tools/install.sh --phase=3 --apply --i-have-read-claudemd
#                                                            # Phase 3 (replace CLAUDE.md)
#
# Phase 3 requires --i-have-read-claudemd flag. By design.
#
# This script copies hooks; settings.json registration is manual
# (see docs/INSTALL.md). Reason: settings.json mutation is high-risk
# and the operator should paste the JSON block consciously, after
# reading what they are pasting.
#
# Companion: tools/uninstall.sh (byte-exact restore from backup).

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CLAUDE_DIR="${HOME}/.claude"
BACKUP_DIR="${CLAUDE_DIR}/.backups"
PHASE=0
APPLY=false
ACK_CONSTITUTION=false

while [ $# -gt 0 ]; do
  case "$1" in
    --phase=*) PHASE="${1#*=}"; shift ;;
    --apply) APPLY=true; shift ;;
    --i-have-read-claudemd) ACK_CONSTITUTION=true; shift ;;
    -h|--help) sed -n '2,20p' "$0"; exit 0 ;;
    *) echo "unknown arg: $1" >&2; exit 1 ;;
  esac
done

log()  { printf '[install] %s\n' "$*"; }
warn() { printf '[install] WARN: %s\n' "$*" >&2; }
die()  { printf '[install] FATAL: %s\n' "$*" >&2; exit 1; }

# Preconditions
command -v bash    >/dev/null || die "bash required"
command -v python3 >/dev/null || warn "python3 not found; telemetry hook fails at runtime"
[ -d "$CLAUDE_DIR" ] || die "$CLAUDE_DIR does not exist; run 'claude' once first"
[ "$PHASE" -ge 1 ] && [ "$PHASE" -le 3 ] || die "specify --phase=1, 2, or 3"

DATE=$(date +%Y%m%d-%H%M%S)
mkdir -p "$BACKUP_DIR"

backup_file() {
  local f="$1"
  [ -f "$f" ] || return 0
  # Idempotency: skip if a previous backup has identical content.
  local sha existing existing_sha
  sha=$(sha256sum "$f" 2>/dev/null | awk '{print $1}' || md5sum "$f" 2>/dev/null | awk '{print $1}' || echo "")
  if [ -n "$sha" ]; then
    existing=$(ls -1t "$BACKUP_DIR/$(basename "$f")".* 2>/dev/null | head -1 || true)
    if [ -n "$existing" ]; then
      existing_sha=$(sha256sum "$existing" 2>/dev/null | awk '{print $1}' || md5sum "$existing" 2>/dev/null | awk '{print $1}' || echo "")
      if [ "$existing_sha" = "$sha" ] && [ -n "$existing_sha" ]; then
        log "skip backup (identical exists): $existing"
        return 0
      fi
    fi
  fi
  if $APPLY; then
    cp "$f" "$BACKUP_DIR/$(basename "$f").$DATE"
    log "backed up: $f -> $BACKUP_DIR/$(basename "$f").$DATE"
  else
    log "would backup: $f -> $BACKUP_DIR/$(basename "$f").$DATE"
  fi
}

install_hook() {
  local name="$1"
  local src="${REPO_DIR}/hooks/${name}"
  local dst="${CLAUDE_DIR}/hooks/${name}"
  [ -f "$src" ] || die "missing source: $src"
  if $APPLY; then
    mkdir -p "${CLAUDE_DIR}/hooks"
    cp "$src" "$dst" && chmod +x "$dst"
    log "installed: $dst"
  else
    log "would install: $src -> $dst"
  fi
}

log "=== Phase 1: telemetry (zero-risk visibility) ==="
backup_file "${CLAUDE_DIR}/settings.json"
install_hook telemetry.sh
log "  -> next: register PostToolUse hook in settings.json (see docs/INSTALL.md)"
log "  -> after 14 days: python3 tools/cost-audit.py --window 14 --verbose"

if [ "$PHASE" -ge 2 ]; then
  log ""
  log "=== Phase 2: enforcement (warn-only) ==="
  install_hook cache-guard.sh
  install_hook token-economy-guard.sh
  install_hook tier-contradiction-guard.sh
  install_hook token-economy-boot.sh
  install_hook token-economy-session-end.sh
  log "  -> register PreToolUse / SessionStart / Stop hooks (see docs/INSTALL.md Phase 2)"
fi

if [ "$PHASE" -ge 3 ]; then
  log ""
  log "=== Phase 3: Constitution (high-impact, requires reading) ==="
  if ! $ACK_CONSTITUTION; then
    die "Phase 3 requires reading CLAUDE.md first.
         Re-run with --i-have-read-claudemd
         after you have actually read ${REPO_DIR}/CLAUDE.md end-to-end."
  fi
  backup_file "${CLAUDE_DIR}/CLAUDE.md"
  if $APPLY; then
    cp "${REPO_DIR}/CLAUDE.md" "${CLAUDE_DIR}/CLAUDE.md"
    log "installed: ${CLAUDE_DIR}/CLAUDE.md  (backup in $BACKUP_DIR)"
  else
    log "would install: ${REPO_DIR}/CLAUDE.md -> ${CLAUDE_DIR}/CLAUDE.md"
  fi
fi

if ! $APPLY; then
  log ""
  log "DRY RUN. Nothing was written. Re-run with --apply to execute."
fi
