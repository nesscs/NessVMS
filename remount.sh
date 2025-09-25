#!/bin/bash
# Migrate legacy /etc/fstab mounts that use /dev/disk/by-id/wwn-* to the new method.
# - New method: mount by UUID to /mnt/<SERIAL> (fallback: /mnt/<UUID>)
# - Adds options: defaults,nofail,noatime,nosuid,nodev,x-systemd.device-timeout=5s
# - Backs up /etc/fstab, comments legacy lines, appends new lines.
# - Attempts to unmount the old mountpoint and mount at the new one.
# - NO formatting or data changes.
#
# wget -O - https://nesscs.com/remount | sudo bash

set -euo pipefail

# ---------- args ----------
YES=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    -y|--yes) YES=1 ;;
    *) echo "Unknown option: $1"; exit 2 ;;
  esac
  shift
done

# ---------- logging ----------
LOG_DIR="/var/log"
LOG_FILE="${LOG_DIR}/nvr-migrate-wwn-$(date +%Y%m%d-%H%M%S).log"
mkdir -p "$LOG_DIR"
touch "$LOG_FILE"
chmod 600 "$LOG_FILE"
exec > >(tee -a "$LOG_FILE") 2>&1

echo "------------------------------------------------------------"
echo "Migrate legacy fstab entries using by-id/wwn-* to UUID mounts"
echo "- New mountpoint: /mnt/<SERIAL> (fallback /mnt/<UUID>)"
echo "- Options: defaults,nofail,noatime,nosuid,nodev,x-systemd.device-timeout=5s"
echo "This is NON-DESTRUCTIVE (no formatting). Log: $LOG_FILE"
echo "------------------------------------------------------------"
echo

# ---------- prereqs ----------
require_cmd() { command -v "$1" >/dev/null 2>&1 || { echo "Missing: $1"; exit 1; }; }
require_cmd awk; require_cmd sed; require_cmd grep; require_cmd findmnt
require_cmd lsblk; require_cmd blkid; require_cmd realpath; require_cmd mount; require_cmd umount

if [[ $EUID -ne 0 ]]; then
  echo "Please run as root."
  exit 1
fi

FSTAB="/etc/fstab"
TS="$(date +%Y-%m-%dT%H:%M:%S)"
FSTAB_BAK="/etc/fstab.bak.$(date +%Y%m%d-%H%M%S)"

# ---------- find legacy WWN entries ----------
# Match non-comment lines whose first field contains /dev/disk/by-id/wwn-
mapfile -t LEGACY_LINES < <(awk '!/^[[:space:]]*#/ && $1 ~ /\/dev\/disk\/by-id\/wwn-/' "$FSTAB" || true)

if ((${#LEGACY_LINES[@]}==0)); then
  echo "No legacy /dev/disk/by-id/wwn-* entries found in $FSTAB. Nothing to do."
  exit 0
fi

echo "Found ${#LEGACY_LINES[@]} legacy entry/entries:"
printf '  %s\n' "${LEGACY_LINES[@]}"
echo

if [[ $YES -ne 1 ]]; then
  read -r -p "Proceed with migration? (yes/no): " CONFIRM
  [[ "$CONFIRM" == "yes" ]] || { echo "Aborting. No changes made."; exit 1; }
else
  echo "Auto-confirm enabled (--yes). Proceeding..."
fi
echo

# ---------- helpers ----------
declare -A USED_SERIALS=()

sanitize_name() {  # allow letters, numbers, dot, dash, underscore
  printf "%s" "$1" | sed -E 's/[^A-Za-z0-9._-]+/_/g'
}

pick_mountpoint() {
  local serial="$1" uuid="$2"
  serial="$(sanitize_name "$serial")"
  local name mp short i
  if [[ -n "$serial" && -z "${USED_SERIALS[$serial]:-}" ]]; then
    name="$serial"
  else
    name="$uuid"
  fi
  mp="/mnt/$name"
  if [[ -e "$mp" ]]; then
    short="${uuid:0:8}"
    [[ "$name" != "$uuid" ]] && mp="/mnt/${name}-${short}"
    i=1
    while [[ -e "$mp" ]]; do
      mp="/mnt/${name}-${short}-${i}"
      i=$((i+1))
    done
  fi
  [[ "$name" == "$serial" && -n "$serial" ]] && USED_SERIALS["$serial"]=1
  printf "%s" "$mp"
}

comment_out_legacy_lines() {
  echo "Backing up $FSTAB to $FSTAB_BAK"
  cp -a "$FSTAB" "$FSTAB_BAK"

  # Create a temp file with legacy lines commented with a MIGRATED tag
  local tmpf
  tmpf="$(mktemp)"
  while IFS= read -r line; do
    if [[ "$line" =~ ^[[:space:]]*/dev/disk/by-id/wwn- ]]; then
      echo "# MIGRATED $TS $line" >> "$tmpf"
    else
      echo "$line" >> "$tmpf"
    fi
  done < "$FSTAB"
  cat "$tmpf" > "$FSTAB"
  rm -f "$tmpf"
}

# ---------- process each legacy line ----------
declare -a NEW_ENTRIES=()
declare -a ACTIONS=()

for entry in "${LEGACY_LINES[@]}"; do
  # Parse fstab fields (device src, mountpoint, fstype). Options not reused.
  # Handle arbitrary spacing/tabs.
  src="$(awk '{print $1}' <<<"$entry")"
  old_mp="$(awk '{print $2}' <<<"$entry")"
  fs_type_from_fstab="$(awk '{print $3}' <<<"$entry")"

  # Resolve real device node (may be ...-part1 symlink)
  if ! real_src="$(realpath -e "$src" 2>/dev/null)"; then
    echo "WARN: $src does not exist on this system. Skipping."
    ACTIONS+=("SKIP: missing device for $src")
    continue
  fi

  # Determine blkid info for the real device (partition or whole device)
  uuid="$(blkid -s UUID -o value "$real_src" || true)"
  fs_type="$(blkid -s TYPE -o value "$real_src" || true)"
  [[ -z "$fs_type" ]] && fs_type="$fs_type_from_fstab"

  if [[ -z "$uuid" || -z "$fs_type" ]]; then
    echo "WARN: Could not determine UUID/fs type for $real_src. Skipping."
    ACTIONS+=("SKIP: missing UUID/TYPE for $real_src")
    continue
  fi

  # Get serial from the parent disk (PKNAME)
  parent="$(lsblk -no PKNAME "$real_src" 2>/dev/null || true)"
  [[ -z "$parent" ]] && parent="$(basename "$real_src")"   # if already a disk
  serial="$(lsblk -dn -o SERIAL "/dev/$parent" 2>/dev/null | tr -d '[:space:]' || true)"

  # Choose new mountpoint
  new_mp="$(pick_mountpoint "$serial" "$uuid")"
  mkdir -p "$new_mp"

  # Compose new fstab line
  new_opts="defaults,nofail,noatime,nosuid,nodev,x-systemd.device-timeout=5s"
  new_line="UUID=${uuid}  ${new_mp}  ${fs_type}  ${new_opts}  0  2"

  # Queue addition (we append after commenting legacy lines)
  NEW_ENTRIES+=("$new_line")
  ACTIONS+=("MIGRATE: $src  ->  $new_mp  (UUID=$uuid, TYPE=$fs_type)")

  # Attempt to remount: unmount old (if mounted), then mount new
  # Find current mount(s) of this device
  current_targets="$(findmnt -n -o TARGET -S "$real_src" || true)"
  if [[ -n "$current_targets" ]]; then
    echo "  Detected current mounts for $real_src:"
    echo "$current_targets" | sed 's/^/    - /'
    if grep -qx "$old_mp" <<<"$current_targets"; then
      echo "  Trying to unmount old mountpoint: $old_mp"
      if umount "$old_mp"; then
        echo "  Unmounted $old_mp"
      else
        echo "  WARN: Could not unmount $old_mp (busy?). Skipping remount for this device."
        echo "        You may stop services using $old_mp and run: umount $old_mp && mount $new_mp"
        ACTIONS+=("RETRY NEEDED: $real_src old busy at $old_mp")
        continue
      fi
    fi
  fi

  # Mount the new target (will work after we write new fstab)
  # We will actually mount after writing fstab for all entries.
done

# ---------- write fstab changes ----------
comment_out_legacy_lines

echo "Appending ${#NEW_ENTRIES[@]} new fstab entries:"
for line in "${NEW_ENTRIES[@]}"; do
  echo "  $line"
  echo "$line" >> "$FSTAB"
done
echo

# ---------- mount the new targets ----------
echo "Mounting new targets..."
for line in "${NEW_ENTRIES[@]}"; do
  # second field is the mountpoint
  mp="$(awk '{print $2}' <<<"$line")"
  if mount "$mp"; then
    echo "  Mounted $mp"
  else
    echo "  WARN: Could not mount $mp now. Try: mount $mp"
  fi
done

echo
echo "Migration summary:"
printf '  %s\n' "${ACTIONS[@]}"
echo
echo "Done. Backup of fstab: $FSTAB_BAK"
echo "Log saved to: $LOG_FILE"
