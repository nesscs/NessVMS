#!/bin/bash
# Auto-detect, format, and mount disks >= 200 GB (HDD or SSD), excluding the root OS disk.
# Mount points are created at /mnt/<UUID>.
# DANGER: This will ERASE matching disks. Review the candidate list before typing 'yes'.

set -euo pipefail

MIN_BYTES=200000000000      # 200 GB in bytes (decimal)
MOUNT_BASE="/mnt"
FSTAB="/etc/fstab"

require_cmd() { command -v "$1" >/dev/null 2>&1 || { echo "Missing: $1"; exit 1; }; }
require_cmd lsblk
require_cmd awk
require_cmd blkid
require_cmd mkfs.ext4
require_cmd mount
require_cmd findmnt

echo "Scanning for disks >= 200 GB (bytes) ..."

# Identify the root filesystem's parent disk to exclude it safely
ROOT_SRC=$(findmnt -n -o SOURCE /)                                # e.g. /dev/nvme0n1p2 or /dev/sda2
ROOT_DISK=$(lsblk -no PKNAME "$ROOT_SRC" 2>/dev/null || true)     # e.g. nvme0n1 or sda
if [[ -z "${ROOT_DISK}" ]]; then
  ROOT_DISK=$(basename "$ROOT_SRC")  # If no PKNAME, ROOT_SRC might already be the disk
fi

# Candidates: whole disks only, >= 200 GB, not the root OS disk (include HDD and SSD/NVMe)
mapfile -t CANDIDATES < <(
  lsblk -b -dn -o NAME,SIZE,TYPE | \
  awk -v min="$MIN_BYTES" -v root="$ROOT_DISK" '
    $3=="disk" && $2>=min && $1!=root { print $1 }'
)

if ((${#CANDIDATES[@]}==0)); then
  echo "No eligible disks found (>= 200 GB, not the OS disk)."
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
  exit 1
fi

for DRIVE in "${CANDIDATES[@]}"; do
  DEV="/dev/$DRIVE"

  # Safety: refuse to operate if the device is currently mounted
  if findmnt -S "$DEV" >/dev/null 2>&1; then
    echo "WARNING: $DEV appears to be mounted. Skipping."
    continue
  fi

  echo "Processing $DEV ..."

  # Create filesystem (wipe existing). -F forces; -m 0 reserves 0% for root on data disk
  mkfs.ext4 -F -m 0 "$DEV"

  # Fetch UUID after mkfs
  UUID=$(blkid -s UUID -o value "$DEV")
  if [[ -z "$UUID" ]]; then
    echo "ERROR: Could not read UUID for $DEV"
    exit 1
  fi

  MOUNTPOINT="${MOUNT_BASE}/${UUID}"
  mkdir -p "$MOUNTPOINT"

  # fstab line: safe boot + perf + security; mount by UUID; mountpoint = /mnt/<UUID>
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
done

echo "All selected drives formatted, added to /etc/fstab, and mounted."
echo "Verify with:"
echo "  lsblk -f | grep -E \"$(printf '%s|' "${CANDIDATES[@]/#/.*}"; echo)\""
echo "  tail -n +1 /etc/fstab | grep -E 'UUID='"
