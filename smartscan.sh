#!/usr/bin/env bash
# smartscan.sh
# Scans all block devices of type "disk" and returns PASS/FAIL per device.
# Requires: sudo, smartctl (smartmontools)
# Usage: sudo ./smartscan.sh

set -euo pipefail

# Ensure running as root
if [[ $EUID -ne 0 ]]; then
  echo "Please run as root (sudo)."
  exit 2
fi

# Ensure smartctl exists, install if missing (Debian/Ubuntu)
if ! command -v smartctl >/dev/null 2>&1; then
  echo "smartctl not found. Installing smartmontools..."
  apt-get update -y && apt-get install -y smartmontools >/dev/null || {
    echo "Failed to install smartmontools. Please install it manually and re-run."
    exit 3
  }
fi

# Helper: normalize device path
normalize_dev() {
  local dev="$1"
  # if it already begins with /dev, return it
  if [[ "$dev" == /* ]]; then
    echo "$dev"
  else
    echo "/dev/$dev"
  fi
}

# Get list of block devices that are disks (exclude loop, ram, mmcblk? we include all type=disk)
mapfile -t DEVICES < <(lsblk -dn -o NAME,TYPE | awk '$2=="disk"{print $1}' )

if [ ${#DEVICES[@]} -eq 0 ]; then
  echo "No block devices of type 'disk' found."
  exit 0
fi

# Print header
printf "%-16s %-20s %-8s %s\n" "DEVICE" "MODEL" "RESULT" "REASON"

for d in "${DEVICES[@]}"; do
  devpath=$(normalize_dev "$d")

  # Skip if device node doesn't exist
  if [ ! -b "$devpath" ]; then
    printf "%-16s %-20s %-8s %s\n" "$devpath" "?" "SKIP" "device node not found"
    continue
  fi

  # Grab basic device info
  model=$(smartctl -i "$devpath" 2>/dev/null | awk -F: '/Model Family|Device Model|Product:|Model Number|Model/{print $2; exit}' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' || true)
  if [ -z "$model" ]; then
    model="$(lsblk -dn -o MODEL "$devpath" 2>/dev/null || echo "Unknown")"
  fi

  # Default status
  status="PASS"
  reason=""

  # Run quick overall health check
  # smartctl -H prints a human readable overall health line
  overall=$(smartctl -H "$devpath" 2>&1) || overall="$overall"

  # Prefer searching for PASSED/FAILED/UNKNOWN in output (case-insensitive)
  if echo "$overall" | grep -iq "failed\|failing"; then
    status="FAIL"
    reason="SMART overall-health: failed"
  elif echo "$overall" | grep -iq "passed"; then
    # still tentatively ok; continue to attribute checks
    :
  else
    # no explicit passed/failed text. treat as unknown but continue attribute checks
    if [ -z "$overall" ]; then
      reason="No SMART overall result"
      status="FAIL"
    else
      # annotate unknown but proceed to attribute parsing
      reason="SMART overall-health: unknown"
    fi
  fi

  # Gather full SMART attributes (some vendors show different names for nvme)
  smart_all=$(smartctl -a "$devpath" 2>/dev/null || true)

  # For NVMe devices, check for "critical_warning" or "Critical Warning" field
  # If present and non-zero -> FAIL
  if echo "$smart_all" | grep -qi "critical warning\|critical_warning"; then
    # find numeric value on same or nearby line
    crit=$(echo "$smart_all" | grep -i -m1 "critical warning\|critical_warning" | grep -oE '[0-9]+' || true)
    if [[ -n "$crit" && "$crit" != "0" ]]; then
      status="FAIL"
      reason+="; NVMe Critical Warning=$crit"
    fi
  fi

  # Common attributes to check for spinning disks and SSDs:
  # Reallocated_Sector_Ct (ID 5), Current_Pending_Sector (ID 197), Offline_Uncorrectable (ID 198)
  # Values vary by vendor; if RAW_VALUE > 0 -> suspicious
  # We'll attempt to parse them generically from smartctl -A output.
  # Search for presence of these attribute names and extract RAW value (last column).
  for attr in "Reallocated_Sector_Ct" "Reallocated_Sector_Count" "Reallocated_Event_Count" "Current_Pending_Sector" "Current_Pending_Sectors" "Offline_Uncorrectable" "Offline_Uncorrectable_Sector"; do
    raw=$(echo "$smart_all" | awk -v a="$attr" 'BEGIN{IGNORECASE=1} $0 ~ a {print $NF; exit}')
    if [[ -n "$raw" && "$raw" =~ ^[0-9]+$ ]]; then
      if [ "$raw" -gt 0 ]; then
        status="FAIL"
        reason+="; $attr=$raw"
      fi
    fi
  done

  # Also check for SMART error count (smartctl -l error / -l selftest)
  # If there are recent errors in self-test log, mark as warn/fail
  # Check for "errors" lines
  errcount=$(echo "$smart_all" | awk '/Error Count|Errors Recorded|Device does not support/d' | grep -Ei 'error count|errors recorded|read:|transport:|SMART Error' -m1 || true)
  # look for "Errors: [number]" patterns
  if echo "$smart_all" | grep -qiE 'Errors Recorded|Error Count'; then
    # try to extract last number on that line
    ec=$(echo "$smart_all" | grep -iE 'Errors Recorded|Error Count' -m1 | grep -oE '[0-9]+' || true)
    if [[ -n "$ec" && "$ec" != "0" ]]; then
      status="FAIL"
      reason+="; ErrorsRecorded=$ec"
    fi
  fi

  # If we haven't accumulated a reason and status is PASS, put a friendly message
  if [[ "$status" == "PASS" ]]; then
    if [[ -z "$reason" ]]; then
      reason="SMART ok"
    else
      # trim leading semicolon/space
      reason=$(echo "$reason" | sed 's/^; //; s/^;//')
    fi
  else
    # trim leading semicolon if present
    reason=$(echo "$reason" | sed 's/^; //; s/^;//')
  fi

  # Final fallback: if overall health explicitly unknown and no attribute corruption found, mark as UNKNOWN rather than PASS
  if echo "$overall" | grep -iq "unknown"; then
    if [[ "$status" == "PASS" && "$reason" == "SMART ok" ]]; then
      status="UNKNOWN"
      reason="SMART overall unknown; attributes OK"
    fi
  fi

  # Print single-line tidy result
  printf "%-16s %-20.20s %-8s %s\n" "$devpath" "${model:-Unknown}" "$status" "$reason"
done
