#!/usr/bin/env bash
# vmslogs.sh - Summarise restart/power events with timestamp and reason (Ubuntu 18–24)
# Usage: sudo ./vmslogs.sh [--since <timespec>] [--until <timespec>]
# Examples:
#   sudo ./vmslogs.sh
#   sudo ./vmslogs.sh --since 30days
#   sudo ./vmslogs.sh --since "2025-01-01" --until "2025-09-26"
#
# sudo wget -O - https://nesscs.com/vmslogs | bash

set -euo pipefail

# ---- Configurable look-back/around windows ----
AROUND_BEFORE_MIN=10    # minutes to search BEFORE an event
AROUND_AFTER_MIN=5      # minutes to search AFTER an event
OOM_LOOKBACK_MIN=60     # longer look-back for OOMs which can precede the reset

SINCE=""
UNTIL=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --since) shift; SINCE="$1";;
    --until) shift; UNTIL="$1";;
    *) echo "Unknown arg: $1" >&2; exit 1;;
  esac
  shift || true
done

require_cmd() { command -v "$1" >/dev/null 2>&1 || { echo "Missing command: $1" >&2; exit 1; }; }
require_cmd last
require_cmd awk
require_cmd date

JOURNALCTL_OK=1
if ! command -v journalctl >/dev/null 2>&1; then
  JOURNALCTL_OK=0
fi

if [[ $EUID -ne 0 ]]; then
  echo "Please run as root (sudo) so journal entries are accessible." >&2
  exit 1
fi

# Warn if persistent journal is not enabled
if [[ $JOURNALCTL_OK -eq 1 ]]; then
  if [[ ! -d /var/log/journal ]]; then
    echo "# Note: /var/log/journal is missing (journal not persistent)."
    echo "# You may only see current-boot details. To persist: mkdir -p /var/log/journal && systemd-tmpfiles --create --prefix /var/log/journal"
    echo
  fi
fi

# Parse `last -xF` into a unified list of events with absolute timestamps.
# We’ll capture both 'reboot' and 'shutdown' records.
build_last_query() {
  local q="last -xF"
  # Filter by --since/--until if provided (we'll just post-filter by date if needed).
  echo "$q"
}

# Convert "Mon Sep 23 10:11:12 2025" to ISO "2025-09-23 10:11:12"
to_iso() {
  date -d "$1" +"%Y-%m-%d %H:%M:%S" 2>/dev/null || echo "$1"
}

# Extract full timestamp (start) from a `last -xF` line.
# Example `last -xF` line (reboot):
# reboot   system boot  5.15.0-122-generic Mon Sep 23 10:11:12 2025   still running
# Example shutdown:
# shutdown system down  5.15.0-122-generic Mon Sep 23 10:08:03 2025 - Mon Sep 23 10:11:06 2025
parse_last_line() {
  # We need to reconstruct the "Mon Sep 23 10:11:12 2025" which begins at field after kernel.
  # Strategy: find the last 5 fields that are Day Mon DD HH:MM:SS YYYY
  # We'll do this with awk in the caller.
  :
}

# Grep journal around a time window for patterns; return a short reason token.
journal_reason() {
  local t_iso="$1"             # ISO time "YYYY-MM-DD HH:MM:SS"
  local event_type="$2"        # reboot|shutdown
  local start_win end_win start_oom

  # Compute windows
  start_win=$(date -d "$t_iso - ${AROUND_BEFORE_MIN} minutes" +"%Y-%m-%d %H:%M:%S")
  end_win=$(date -d "$t_iso + ${AROUND_AFTER_MIN} minutes" +"%Y-%m-%d %H:%M:%S")
  start_oom=$(date -d "$t_iso - ${OOM_LOOKBACK_MIN} minutes" +"%Y-%m-%d %H:%M:%S")

  # If journalctl not available, we cannot classify; return unknown.
  if [[ $JOURNALCTL_OK -ne 1 ]]; then
    echo "unknown"
    return 0
  fi

  # Helper to search journal in a window
  jgrep() {
    journalctl --no-pager --since "$1" --until "$2" 2>/dev/null
  }

  # Check for explicit clean actions first (very reliable):
  if jgrep "$start_win" "$end_win" | grep -Eiq 'systemd\[1\]: Starting (Reboot|Power-Off)|systemd: Reached target (Reboot|Power-Off)|systemd-shutdown: (Powering down|Rebooting)|reboot: Restarting system'; then
    if [[ "$event_type" == "shutdown" ]]; then
      echo "clean poweroff"
      return 0
    else
      echo "clean reboot"
      return 0
    fi
  fi

  # Power button pressed
  if jgrep "$start_win" "$end_win" | grep -Eiq 'systemd-logind.*(Power key pressed|Power Button)|ACPI.*Power Button'; then
    echo "power button"
    return 0
  fi

  # UPS/NUT/APC daemon initiated
  if jgrep "$start_win" "$end_win" | grep -Eiq '(apcupsd|apcdaemon|upsmon|nut).* (shutdown|power off|on battery)'; then
    echo "UPS initiated"
    return 0
  fi

  # Kernel panic / oops
  if jgrep "$start_win" "$end_win" | grep -Eiq 'Kernel panic|panic:|Oops:|BUG: unable to handle kernel'; then
    echo "kernel panic"
    return 0
  fi

  # Watchdog-induced
  if jgrep "$start_win" "$end_win" | grep -Eiq 'watchdog.*(hard LOCKUP|reboot|NMI watchdog)'; then
    echo "watchdog reset"
    return 0
  fi

  # Thermal
  if jgrep "$start_win" "$end_win" | grep -Eiq '(Thermal|thermal).* (critical|overheat|overheated|shutdown)'; then
    echo "thermal protection"
    return 0
  fi

  # OOM within a longer look-back
  if jgrep "$start_oom" "$end_win" | grep -Eiq 'Out of memory: Killed process'; then
    echo "out-of-memory"
    return 0
  fi

  # Filesystem journal recovery at next boot implies unclean/power loss
  # Look just AFTER the event for ext4/xfs journal recovery messages
  if jgrep "$t_iso" "$end_win" | grep -Eiq 'EXT4-fs .*recovering journal|EXT4-fs .*mounted filesystem with ordered data mode|xfslog.*Mounting|dirty log'; then
    echo "unclean shutdown (likely power loss)"
    return 0
  fi

  # If nothing matched, return unknown
  echo "unknown"
}

# Post-filter by --since/--until (if set)
within_bounds() {
  local t_iso="$1"
  if [[ -n "$SINCE" ]]; then
    local s=$(date -d "$SINCE" +%s 2>/dev/null || echo 0)
    local ts=$(date -d "$t_iso" +%s 2>/dev/null || echo 0)
    if (( ts < s )); then return 1; fi
  fi
  if [[ -n "$UNTIL" ]]; then
    local u=$(date -d "$UNTIL" +%s 2>/dev/null || echo 32503680000) # year 3000
    local ts=$(date -d "$t_iso" +%s 2>/dev/null || echo 0)
    if (( ts > u )); then return 1; fi
  fi
  return 0
}

# Build a list of reboot/shutdown events from `last -xF`, oldest -> newest
mapfile -t EVENTS < <(
  $(build_last_query) \
  | awk '
      BEGIN { OFS="|" }
      # We only care about lines that begin with reboot or shutdown
      tolower($1) ~ /^(reboot|shutdown)$/ {
        # Find the last 5 fields which form the start timestamp (Day Mon DD HH:MM:SS YYYY)
        # We will reconstruct by searching from the end.
        n = NF
        year = $(n)
        time = $(n-1)
        day  = $(n-2)
        mon  = $(n-3)
        dow  = $(n-4)
        # Some locales may insert commas; strip punctuation.
        gsub(/,/, "", dow); gsub(/,/, "", mon); gsub(/,/, "", day); gsub(/,/, "", time); gsub(/,/, "", year)
        # Join start timestamp
        start = dow" "mon" "day" "time" "year
        printf "%s|%s\n", tolower($1), start
      }
    ' \
  | tac  # make oldest first
)

# Print header
# (No header in final output per request of "date stamp and reason", so we omit column names.)

for line in "${EVENTS[@]}"; do
  IFS='|' read -r etype start_raw <<<"$line"
  t_iso="$(to_iso "$start_raw")"

  # Boundaries filter
  if ! within_bounds "$t_iso"; then
    continue
  fi

  reason="$(journal_reason "$t_iso" "$etype")"
  printf "%s  %s\n" "$t_iso" "$reason"
done
