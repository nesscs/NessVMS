#!/usr/bin/env bash
# Enable persistent systemd-journald with conservative caps for SSD/USB DOM
# Usage:
#   sudo bash enable_persistent_journal.sh
#   sudo bash enable_persistent_journal.sh --dry-run

set -euo pipefail

DRY_RUN=0
[[ "${1:-}" == "--dry-run" ]] && DRY_RUN=1

must_root() { [[ $EUID -eq 0 ]] || { echo "Please run as root (sudo)."; exit 1; }; }
has() { command -v "$1" >/dev/null 2>&1; }

must_root
has findmnt || { echo "Missing 'findmnt' (util-linux)."; exit 1; }

# Figure out the block device for /
ROOT_SRC=$(findmnt -no SOURCE /)
# Handle cases like /dev/sda2, /dev/nvme0n1p2, /dev/mmcblk0p2
case "$ROOT_SRC" in
  /dev/*) PART="${ROOT_SRC#/dev/}";;
  *) echo "Unexpected root source: $ROOT_SRC"; PART="";;
esac

# Derive the base disk (strip partition suffix)
BASE="$PART"
if [[ "$BASE" =~ ^(nvme[0-9]+n[0-9]+)p[0-9]+$ ]]; then
  BASE="${BASH_REMATCH[1]}"
elif [[ "$BASE" =~ ^(mmcblk[0-9]+)p[0-9]+$ ]]; then
  BASE="${BASH_REMATCH[1]}"
else
  BASE="${BASE%%[0-9]*}"
fi

SYSBLK="/sys/block/$BASE"
ROT=0; REMOVABLE=0; SIZE_GB=0

if [[ -e "$SYSBLK/queue/rotational" ]]; then ROT=$(<"$SYSBLK/queue/rotational"); fi
if [[ -e "$SYSBLK/removable" ]];    then REMOVABLE=$(<"$SYSBLK/removable"); fi
if [[ -e "$SYSBLK/size" ]]; then
  # sectors * 512 -> bytes -> GiB (rounded)
  SECT=$(<"$SYSBLK/size")
  BYTES=$(( SECT * 512 ))
  SIZE_GB=$(( (BYTES + 1024*1024*1024 - 1) / (1024*1024*1024) ))
fi

# Choose caps: tighter for removable/small devices (typical USB DOMs), looser for SSDs
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

CONF_DIR="/etc/systemd/journald.conf.d"
CONF_FILE="$CONF_DIR/persistent.conf"

read -r -d '' CONTENT <<EOF
# Managed by enable_persistent_journal.sh
# Device: /dev/$BASE  (removable=$REMOVABLE, rotational=$ROT, size=${SIZE_GB}G, profile=$PROFILE)
[Journal]
Storage=persistent
Compress=yes
Seal=yes

# Disk usage caps (tuned for $PROFILE)
SystemMaxUse=$SystemMaxUse
SystemMaxFileSize=$SystemMaxFileSize
SystemMaxFiles=$SystemMaxFiles
SystemKeepFree=$SystemKeepFree

# Optional: tame bursts a little (keep defaults if you prefer)
#RateLimitIntervalSec=30s
#RateLimitBurst=10000
EOF

echo "Root device: /dev/$BASE   removable=$REMOVABLE  rotational=$ROT  size=${SIZE_GB}G  -> profile=$PROFILE"
echo "Planned journald caps: SystemMaxUse=$SystemMaxUse, SystemMaxFileSize=$SystemMaxFileSize, SystemMaxFiles=$SystemMaxFiles, SystemKeepFree=$SystemKeepFree"
echo

if (( DRY_RUN )); then
  echo "----- DRY RUN: $CONF_FILE -----"
  echo "$CONTENT"
  exit 0
fi

mkdir -p "$CONF_DIR"
printf "%s\n" "$CONTENT" > "$CONF_FILE"

# Ensure persistent dir exists (even if tmpfs is current storage)
mkdir -p /var/log/journal
if has systemd-tmpfiles; then
  systemd-tmpfiles --create --prefix /var/log/journal || true
fi

# Restart journald to apply
if has systemctl; then
  systemctl restart systemd-journald
else
  echo "No systemctl found; not restarting journald automatically."
fi

# Sanity ping + show disk usage
has logger && logger -t journald-setup "Enabled persistent journald ($PROFILE caps) on /dev/$BASE"
if has journalctl; then
  journalctl --disk-usage || true
  echo
  echo "journald storage state:"
  journalctl --header | sed -n '1,12p' || true
fi

echo "Done. Config: $CONF_FILE"
