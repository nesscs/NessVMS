#!/usr/bin/env bash
# enable_persistent_journal.sh
#
# Enable or disable persistent systemd-journald with sensible caps for SSDs / USB DOMs.
# Writes a drop-in config to /etc/systemd/journald.conf.d/persistent.conf.
#
# ─────────────────────────────────────────────────────────────
# USAGE:
#   sudo bash enable_persistent_journal.sh [options]
#
# OPTIONS:
#   --status     Show current journald storage mode, config, and disk usage.
#   --dry-run    Show what changes would be made but do not apply them.
#   --verbose    Print extra diagnostic information while running.
#   --disable    Disable persistent storage (remove config and /var/log/journal).
#   --help       Show this header.
#
# ─────────────────────────────────────────────────────────────
# EXAMPLES:
#
#   Enable persistent storage (auto-detect SSD vs DOM caps):
#     sudo bash enable_persistent_journal.sh
#
#   Disable persistent storage (back to volatile in /run):
#     sudo bash enable_persistent_journal.sh --disable
#
#   Show current journald status:
#     sudo bash enable_persistent_journal.sh --status
#
#   Preview what would be written without applying changes:
#     sudo bash enable_persistent_journal.sh --dry-run
#
#   Enable with verbose logging:
#     sudo bash enable_persistent_journal.sh --verbose
#
# ─────────────────────────────────────────────────────────────
# NOTES:
#   • On SSDs, default cap ~400 MB.
#   • On USB DOMs or removable media ≤32 GB, tighter cap ~150 MB.
#   • After enabling, check with:
#       journalctl --header | grep -i '^Storage'
#       journalctl --disk-usage
#
#   • After disabling, journald will revert to volatile (RAM-only) logs.
#
# ─────────────────────────────────────────────────────────────

set -euo pipefail
shopt -s extglob

DRY_RUN=0
VERBOSE=0
SHOW_STATUS=0
DISABLE=0

# ---- parse args ----
while (( $# )); do
  case "$1" in
    --dry-run) DRY_RUN=1 ;;
    --verbose) VERBOSE=1 ;;
    --status)  SHOW_STATUS=1 ;;
    --disable) DISABLE=1 ;;
    --help) head -n 50 "$0"; exit 0 ;;
    *) echo "Unknown option: $1"; exit 2 ;;
  esac
  shift
done

log()  { echo "[vmslogs] $*"; }
vlog() { (( VERBOSE )) && echo "[vmslogs] $*"; }

must_root() { [[ $EUID -eq 0 ]] || { echo "Please run as root (sudo)."; exit 1; }; }
need() { command -v "$1" >/dev/null 2>&1 || { echo "Missing command: $1"; exit 1; }; }

CONF_DIR="/etc/systemd/journald.conf.d"
CONF_FILE="$CONF_DIR/persistent.conf"

status_only() {
  log "Journald storage mode:"
  journalctl --header 2>/dev/null | sed -n '1,15p' || echo "(could not read journald header)"
  echo
  if [[ -d /var/log/journal ]]; then
    log "/var/log/journal exists (persistent dir present)"
    journalctl --disk-usage || true
  else
    log "/var/log/journal does NOT exist (likely volatile logs)"
  fi
  echo
  log "Effective config (merged):"
  grep -Rns --color=never '^\s*\(Storage\|SystemMaxUse\|SystemMaxFileSize\|SystemMaxFiles\|SystemKeepFree\)' \
    /etc/systemd/journald.conf /etc/systemd/journald.conf.d/* 2>/dev/null || echo "(no overrides)"
  exit 0
}

disable_config() {
  must_root
  if (( DRY_RUN )); then
    log "DRY-RUN: would remove $CONF_FILE and /var/log/journal, restart journald"
    return 0
  fi
  if [[ -f "$CONF_FILE" ]]; then
    rm -f "$CONF_FILE"
    log "Removed $CONF_FILE"
  else
    log "No $CONF_FILE found (already disabled?)"
  fi
  rm -rf /var/log/journal
  log "Removed /var/log/journal directory (journald will stay volatile)"
  systemctl restart systemd-journald || true
  STORAGE_MODE=$(journalctl --header 2>/dev/null | awk -F': ' '/Storage/{print $2; exit}' || true)
  log "Now journald Storage=$STORAGE_MODE (expected 'volatile')"
  exit 0
}

apply_config() {
  must_root
  need findmnt

  ROOT_SRC=$(findmnt -no SOURCE / || true)
  PART=""
  case "$ROOT_SRC" in
    /dev/*) PART="${ROOT_SRC#/dev/}" ;;
    *)      PART="" ;;
  esac

  BASE="$PART"
  if [[ "$BASE" =~ ^(nvme[0-9]+n[0-9]+)p[0-9]+$ ]]; then
    BASE="${BASH_REMATCH[1]}"
  elif [[ "$BASE" =~ ^(mmcblk[0-9]+)p[0-9]+$ ]]; then
    BASE="${BASH_REMATCH[1]}"
  else
    BASE="${BASE%%+([0-9])}"
  fi

  SYSBLK="/sys/block/$BASE"
  ROT=0; REMOVABLE=0; SIZE_GB=0
  [[ -e "$SYSBLK/queue/rotational" ]] && ROT=$(<"$SYSBLK/queue/rotational")
  [[ -e "$SYSBLK/removable"    ]] && REMOVABLE=$(<"$SYSBLK/removable")
  if [[ -e "$SYSBLK/size" ]]; then
    SECT=$(<"$SYSBLK/size"); BYTES=$(( SECT * 512 ))
    SIZE_GB=$(( (BYTES + 1024*1024*1024 - 1) / (1024*1024*1024) ))
  fi

  if (( REMOVABLE == 1 || SIZE_GB <= 32 )); then
    PROFILE="dom"
    SystemMaxUse="150M"
    SystemMaxFileSize="16M"
    SystemMaxFiles="8"
    SystemKeepFree="100M"
  else
    PROFILE="ssd"
    SystemMaxUse="400M"
    SystemMaxFileSize="50M"
    SystemMaxFiles="8"
    SystemKeepFree="200M"
  fi

  log "Root device guess: /dev/${BASE:-unknown} (removable=$REMOVABLE rotational=$ROT size=${SIZE_GB}G) -> profile=$PROFILE"
  log "Caps: SystemMaxUse=$SystemMaxUse, SystemMaxFileSize=$SystemMaxFileSize, SystemMaxFiles=$SystemMaxFiles, SystemKeepFree=$SystemKeepFree"

  read -r -d '' CONTENT <<EOF || true
# Managed by enable_persistent_journal.sh
# Device: /dev/${BASE:-unknown}  (removable=$REMOVABLE, rotational=$ROT, size=${SIZE_GB}G, profile=$PROFILE)
[Journal]
Storage=persistent
Compress=yes
Seal=yes

SystemMaxUse=$SystemMaxUse
SystemMaxFileSize=$SystemMaxFileSize
SystemMaxFiles=$SystemMaxFiles
SystemKeepFree=$SystemKeepFree
EOF

  if (( DRY_RUN )); then
    echo
    log "DRY-RUN: would write $CONF_FILE with:"
    echo "------------------------------------------------------------"
    echo "$CONTENT"
    echo "------------------------------------------------------------"
    return 0
  fi

  mkdir -p "$CONF_DIR"
  printf "%s\n" "$CONTENT" > "$CONF_FILE"
  log "Wrote $CONF_FILE"

  mkdir -p /var/log/journal
  systemd-tmpfiles --create --prefix /var/log/journal || true
  systemctl restart systemd-journald || true

  STORAGE_MODE=$(journalctl --header 2>/dev/null | awk -F': ' '/Storage/{print $2; exit}' || true)
  log "Confirmed: journald Storage=$STORAGE_MODE"
}

# ----- main -----
if (( SHOW_STATUS )); then status_only; fi
if (( DISABLE )); then disable_config; fi
apply_config
