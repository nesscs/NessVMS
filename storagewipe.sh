#!/bin/bash
# Auto-detect, format, and mount HDDs larger than 1.1TB for NVR storage

MOUNT_BASE="/mnt/storage"
FSTAB="/etc/fstab"

echo "Scanning for drives larger than 1TB..."

# Get list of non-NVMe block devices >1.1TB
DRIVES=$(lsblk -ndo NAME,SIZE,TYPE | awk '$3=="disk" && $2+0 > 1100 {print $1}' | grep -v nvme)

if [ -z "$DRIVES" ]; then
  echo "No HDDs larger than 1TB found."
  exit 0
fi

echo "The following drives will be formatted and ALL DATA WILL BE ERASED:"
for DRIVE in $DRIVES; do
  DEV="/dev/$DRIVE"
  SIZE=$(lsblk -ndo SIZE "$DEV")
  echo "  - $DEV ($SIZE)"
done

echo ""
read -p "Do you want to continue? (yes/no): " CONFIRM

if [ "$CONFIRM" != "yes" ]; then
  echo "Aborting. No changes made."
  exit 1
fi

COUNT=1
for DRIVE in $DRIVES; do
  DEV="/dev/$DRIVE"

  echo "Processing $DEV..."

  # Create a new ext4 filesystem (wipe existing!)
  mkfs.ext4 -F -L "storage$COUNT" "$DEV"

  # Get UUID
  UUID=$(blkid -s UUID -o value "$DEV")

  # Create mount point
  MOUNTPOINT="${MOUNT_BASE}${COUNT}"
  mkdir -p "$MOUNTPOINT"

  # Add to fstab if not already present
  if ! grep -q "$UUID" "$FSTAB"; then
    echo "UUID=$UUID  $MOUNTPOINT  ext4  defaults,nofail,noatime,nosuid,nodev,x-systemd.device-timeout=5s  0  2" | tee -a "$FSTAB"
  fi

  # Mount immediately
  mount "$MOUNTPOINT"

  echo "$DEV mounted at $MOUNTPOINT"
  COUNT=$((COUNT+1))
done

echo "All drives processed."
