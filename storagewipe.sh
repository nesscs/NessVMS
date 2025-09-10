#!/bin/bash
# Auto-detect, format, and mount HDDs >= 1 TiB for NVR storage (Ubuntu 22.04+)
# DANGER: This will ERASE matching disks. Review the candidate list before typing 'yes'.

set -euo pipefail

MIN_BYTES=1099511627776   # 1 TiB in bytes
MOUNT_BASE="/mnt/storage"
FSTAB="/etc/fstab"

require_cmd() { command -v "$1" >/dev/null 2>&1 || { echo "Missing: $1"; exit 1; }; }
require_cmd lsblk
require_cmd awk
require_cmd blkid
require_cmd mkfs.ext4
require_cmd mount
require_cmd findmnt

echo "Scanning for rotational HDDs >= 1 TiB (bytes) ..."

# Identify the root filesystem's parent disk to exclude it safely
ROOT_SRC=$(findmnt -n -o SOURCE /)               # e.g. /dev/nvme0n1p2 or /dev/sda2
ROOT_DISK=$(lsblk -no PKNAME "$ROOT_SRC" 2>/dev/null || true)  # e.g. nvme0n1 or sda
if [[ -z "${ROOT_DISK}" ]]; then
  # If PKNAME empty, maybe ROOT_SRC itself is a disk (no partition). Strip /dev/
  ROOT_DISK=$(basename "$ROOT_SRC")
fi

# Build candidate list:
# - TYPE=disk (whole disks only)
# - ROTA=1 (rotational HDDs)
# - SIZE >= 1 TiB (bytes)
# - Exclude OS/root disk
# We use -b (bytes) so comparisons are numeric
mapfile -t CANDIDATES < <(
  lsblk -b -dn -o NAME,SIZE,TYPE,ROTA | \
  awk -v min="$MIN_BYTES" -v root="$ROOT_DISK" '
    $3=="disk" && $4==1 && $2>=min && $1!=root { print $1 }'
)

if ((${#CANDIDATES[@]}==0)); then
  echo "No eligible HDDs found (rotational, >= 1 TiB, not the OS disk)."
  exit 0
fi

echo "The following disks will be formatted and ALL DATA WILL BE ERASED:"
for d in "${CANDIDATES[@]}"; do
  size=$(lsblk -dn -o SIZE "/dev/$d")
  model=$(lsblk -dn -o MODEL "/dev/$d" || true)
  serial=$(lsblk -dn -o SERIAL "/dev/$d" || true)
  printf "  - /dev/%s  (%s)  %s  %s\n" "$d" "$size" "${model:-}" "${serial:-}"
done
echo
read -r -p "Do you want to continue? (yes/no): " CONFIRM
if [[ "$CONFIRM" != "yes" ]]; then
  echo "Aborting. No changes made."
  exit 1
fi

# Determine next mount index to avoid clobbering existing /mnt/storageN
next_index() {
  local n=1
  while [[ -e "${MOUNT_BASE}${n}" ]]; do n=$((n+1)); done
  echo "$n"
}

COUNT=$(next_index)

for DRIVE in "${CANDIDATES[@]}"; do
  DEV="/dev/$DRIVE"
  MOUNTPOINT="${MOUNT_BASE}${COUNT}"

  echo "Processing $DEV -> $MOUNTPOINT ..."

  # Create filesystem (wipe existing). -F forces, -m 0 reserves 0% for root on data disk
  mkfs.ext4 -F -m 0 -L "storage${COUNT}" "$DEV"

  # Fetch UUID after mkfs
  UUID=$(blkid -s UUID -o value "$DEV")
  if [[ -z "$UUID" ]]; then
    echo "ERROR: Could not read UUID for $DEV"
    exit 1
  fi

  # Create mount point
  mkdir -p "$MOUNTPOINT"

  # fstab line (safe boot + perf + security)
  FSTAB_LINE="UUID=${UUID}  ${MOUNTPOINT}  ext4  defaults,nofail,noatime,nosuid,nodev,x-systemd.device-timeout=5s  0  2"

  # Add to fstab if not already present
  if ! grep -q "$UUID" "$FSTAB"; then
    echo "$FSTAB_LINE" | sudo tee -a "$FSTAB" >/dev/null
  else
    echo "An /etc/fstab entry for $UUID already exists; skipping append."
  fi

  # Mount it now
  mount "$MOUNTPOINT"
  echo "Mounted $DEV at $MOUNTPOINT"

  COUNT=$((COUNT+1))
done

echo "All selected drives formatted, added to /etc/fstab, and mounted."
echo "Verify with: lsblk -f | grep -E 'storage[0-9]+'  &&  cat /etc/fstab | tail -n +1"
