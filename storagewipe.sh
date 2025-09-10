#!/bin/bash
# Format & mount all non-root disks >= 200 GB (HDD/SSD/NVMe) on Ubuntu 22+
# - Mount path: /mnt/<SERIAL> when available & unique, else /mnt/<UUID>
# - Safe boot flags: nofail,noatime,nosuid,nodev,x-systemd.device-timeout=5s
# DANGER: This will ERASE matching disks. Review the list before typing 'yes'.

set -euo pipefail

# ----- logging -----
LOG_DIR="/var/log"
LOG_FILE="${LOG_DIR}/nvr-drive-setup-$(date +%Y%m%d-%H%M%S).log"
mkdir -p "$LOG_DIR"
# Create the log file early so the next line can append to it
touch "$LOG_FILE"
chmod 600 "$LOG_FILE"
# Send stdout/stderr to both screen and log
exec > >(tee -a "$LOG_FILE") 2>&1

# Print header (lines 2–5)
echo "------------------------------------------------------------"
echo "Format & mount all non-root disks >= 200 GB (HDD/SSD/NVMe)"
echo "- Mount path: /mnt/<SERIAL> when available & unique, else /mnt/<UUID>"
echo "- Safe boot flags: nofail,noatime,nosuid,nodev,x-systemd.device-timeout=5s"
echo "DANGER: This will ERASE matching disks. Review the list carefully!"
echo "Log file: $LOG_FILE"
echo "------------------------------------------------------------"
echo

MIN_BYTES=200000000000   # 200 GB (decimal)
MOUNT_BASE="/mnt"
FSTAB="/etc/fstab"

require_cmd() { command -v "$1" >/dev/null 2>&1 || { echo "Missing: $1"; exit 1; }; }
require_cmd lsblk; require_cmd awk; require_cmd blkid; require_cmd mkfs.ext4
require_cmd mount; require_cmd findmnt; require_cmd sed

echo "Scanning for whole disks >= 200 GB (bytes) ..."

# Exclude the root OS disk (no matter SATA/NVMe)
ROOT_SRC=$(findmnt -n -o SOURCE /)                       # e.g. /dev/nvme0n1p2 or /dev/sda2
ROOT_DISK=$(lsblk -no PKNAME "$ROOT_SRC" 2>/dev/null || true)
[[ -z "${ROOT_DISK}" ]] && ROOT_DISK=$(basename "$ROOT_SRC")
echo "Detected root source: $ROOT_SRC (root disk: $ROOT_DISK)"

# Candidates: TYPE=disk, size >= threshold, not the root disk
mapfile -t CANDIDATES < <(
  lsblk -b -dn -o NAME,SIZE,TYPE | \
  awk -v min="$MIN_BYTES" -v root="$ROOT_DISK" \
      '$3=="disk" && $2>=min && $1!=root { print $1 }'
)

if ((${#CANDIDATES[@]}==0)); then
  echo "No eligible disks found (>= 200 GB and not the OS disk)."
  echo "Exiting. See log: $LOG_FILE"
  exit 0
fi

echo "The following disks will be formatted and ALL DATA WILL BE ERASED:"
for d in "${CANDIDATES[@]}"; do
  size=$(lsblk -dn -o SIZE "/dev/$d")
  model=$(lsblk -dn -o MODEL "/dev/$d" || true)
  serial=$(lsblk -dn -o SERIAL "/dev/$d" || true)
  rota=$(lsblk -dn -o ROTA "/dev/$d" || echo "?")
  media=$([[ "$rota" == "1" ]] && echo "HDD" || echo "SSD/NVMe")
  printf "  - /dev/%s  (%s)  %s  %s  [%s]\n" "$d" "$size" "${model:-}" "${serial:-}" "$media"
done
echo
read -r -p "Do you want to continue? (yes/no): " CONFIRM
if [[ "$CONFIRM" != "yes" ]]; then
  echo "Aborting. No changes made."
  echo "See log: $LOG_FILE"
  exit 1
fi

# Track serials we assign to avoid duplicates
declare -A USED_SERIALS=()

pick_mountpoint() {
  local serial="$1" uuid="$2"
  serial=$(printf "%s" "$serial" | sed -E 's/[^A-Za-z0-9._-]+/_/g')
  local name
  if [[ -z "$serial" || -n "${USED_SERIALS[$serial]:-}" ]]; then
    name="$uuid"
  else
    name="$serial"
  fi
  local mp="${MOUNT_BASE}/${name}"
  if [[ -e "$mp" ]]; then
    local short="${uuid:0:8}"
    if [[ "$name" != "$uuid" ]]; then
      mp="${MOUNT_BASE}/${name}-${short}"
    fi
    local i=1
    while [[ -e "$mp" ]]; do
      mp="${MOUNT_BASE}/${name}-${short}-${i}"
      i=$((i+1))
    done
  fi
  if [[ "$name" == "$serial" && -n "$serial" ]]; then
    USED_SERIALS["$serial"]=1
  fi
  printf "%s" "$mp"
}

for DRIVE in "${CANDIDATES[@]}"; do
  DEV="/dev/$DRIVE"

  if findmnt -S "$DEV" >/dev/null 2>&1; then
    echo "WARNING: $DEV appears to be mounted. Skipping."
    continue
  fi

  echo "Processing $DEV ..."
  mkfs.ext4 -F -m 0 "$DEV"

  UUID=$(blkid -s UUID -o value "$DEV")
  SERIAL_RAW=$(lsblk -dn -o SERIAL "$DEV" | tr -d '[:space:]' || true)
  if [[ -z "$UUID" ]]; then
    echo "ERROR: Could not read UUID for $DEV"; exit 1
  fi
  echo "  UUID: $UUID"
  echo "  SERIAL: ${SERIAL_RAW:-<none>}"

  MOUNTPOINT=$(pick_mountpoint "$SERIAL_RAW" "$UUID")
  mkdir -p "$MOUNTPOINT"
  echo "  Mount point: $MOUNTPOINT"

  FSTAB_LINE="UUID=${UUID}  ${MOUNTPOINT}  ext4  defaults,nofail,noatime,nosuid,nodev,x-systemd.device-timeout=5s  0  2"
  if ! grep -q "$UUID" "$FSTAB"; then
    echo "$FSTAB_LINE" | tee -a "$FSTAB" >/dev/null
    echo "  Added to /etc/fstab"
  else
    echo "  /etc/fstab already has an entry for $UUID; skipping append."
  fi

  mount "$MOUNTPOINT"
  echo "  Mounted $DEV at $MOUNTPOINT"
done

echo
echo "Done: formatted, added to /etc/fstab, and mounted."
echo "Verify with:"
echo "  lsblk -f"
echo "  grep UUID /etc/fstab"
echo "Log saved to: $LOG_FILE"
