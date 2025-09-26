#!/usr/bin/env bash
# vmslogs.sh - Summarise restart/power events with timestamp and reason (Ubuntu 18–24)
# Hosted at: https://nesscs.com/vmslogs
#
# Quick run (no install):
#   sudo wget -qO- https://nesscs.com/vmslogs | sudo bash
#
# With options (example: look back 7 days with debug enabled):
#   sudo wget -qO- https://nesscs.com/vmslogs | sudo bash -s -- --since 7days --debug
#
# Options:
#   --since <timespec>   e.g. 7days, "2025-01-01"
#   --until <timespec>   end of window
#   --debug              show matching journal lines
#   --help               show this usage message

set -euo pipefail

# ---- Configurable look-back/around windows ----
AROUND_BEFORE_MIN=${AROUND_BEFORE_MIN:-10}  # minutes to search BEFORE an event
AROUND_AFTER_MIN=${AROUND_AFTER_MIN:-5}     # minutes to search AFTER an event
OOM_LOOKBACK_MIN=${OOM_LOOKBACK_MIN:-60}    # longer look-back for OOMs

SINCE=""
UNTIL=""
DEBUG=0

show_help() {
  cat <<EOF
Usage:
  sudo wget -qO- https://nesscs.com/vmslogs | sudo bash -s -- [options]

Options:
  --since <timespec>   e.g. 7days, "2025-01-01"
  --until <timespec>   end of window
  --debug              show matching journal lines
  --help               show this message

Examples:
  # Show all restarts/shutdowns:
  sudo wget -qO- https://nesscs.com/vmslogs | sudo bash

  # Look back 7 days with debug enabled:
  sudo wget -qO- https://nesscs.com/vmslogs | sudo bash -s -- --since 7days --debug
EOF
}

# If running in a pipe (wget|bash or curl|bash), print a hint
if [[ -t 1 && -p /dev/stdin ]]; then
  echo "# Running vmslogs.sh from stream"
  echo "# Tip: use --help for usage info"
  echo
fi

# --- Parse args ---
while [[ $# -gt 0 ]]; do
  case "$1" in
    --since) shift; SINCE="${1:-}";;
    --until) shift; UNTIL="${1:-}";;
    --debug) DEBUG=1;;
    --help) show_help; exit 0;;
    *) echo "Unknown arg: $1"; echo "Use --help for usage."; exit 1;;
  esac
  shift || true
done

# --- Helpers / prerequisites ---
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
if [[ $JOURNALCTL_OK -eq 1 && ! -d /var/log/journal ]]; then
  echo "# Note: /var/log/journal is missing (journal not persistent)."
  echo "# You may only see current-boot details. To persist:"
  echo "#   mkdir -p /var/log/journal && systemd-tmpfiles --create --prefix /var/log/journal"
  echo
fi

# Convert "Mon Sep 23 10:11:12 2025" -> "2025-09-23 10:11:12"
to_iso() {
  date -d "$1" +"%Y-%m-%d %H:%M:%S" 2>/dev/null || echo "$1"
}

# Post-filter by --since/--until (if set)
within_bounds() {
  local t_iso="$1"
  if [[ -n "$SINCE" ]]; then
    local s; s=$(date -d "$SINCE" +%s 2>/dev/null || echo 0)
    local ts; ts=$(date -d "$t_iso" +%s 2>/dev/null || echo 0)
    (( ts < s )) && return 1
  fi
  if [[ -n "$UNTIL" ]]; then
    local u; u=$(date -d "$UNTIL" +%s 2>/dev/null || echo 32503680000)
    local ts; ts=$(date -d "$t_iso" +%s 2>/dev/null || echo 0)
    (( ts > u )) && return 1
  fi
  return 0
}

# Classification using journalctl (preferred)
journal_reason() {
  local t_iso="$1"       # "YYYY-MM-DD HH:MM:SS"
  local event_type="$2"  # reboot|shutdown
  local start_win end_win start_oom

  start_win=$(date -d "$t_iso - ${AROUND_BEFORE_MIN} minutes" +"%Y-%m-%d %H:%M:%S")
  end_win=$(date -d "$t_iso + ${AROUND_AFTER_MIN} minutes" +"%Y-%m-%d %H:%M:%S")
  start_oom=$(date -d "$t_iso - ${OOM_LOOKBACK_MIN} minutes" +"%Y-%m-%d %H:%M:%S")

  if [[ $JOURNALCTL_OK -ne 1 ]]; then
    echo "unknown"
    return 0
  fi

  local J
  J="$(journalctl -o short-iso --no-pager --since "$start_win" --until "$end_win" 2>/dev/null || true)"

  if grep -Eiq 'systemd-shutdown\[[0-9]+\]: Powering down\.' <<<"$J"; then
    [[ $DEBUG -eq 1 ]] && echo "# DEBUG matched: systemd-shutdown Powering down." >&2
    echo "clean poweroff"; return 0
  fi
  if grep -Eiq 'systemd-shutdown\[[0-9]+\]: Rebooting\.' <<<"$J"; then
    [[ $DEBUG -eq 1 ]] && echo "# DEBUG matched: systemd-shutdown Rebooting." >&2
    echo "clean reboot"; return 0
  fi
  if grep -Eiq '\breboot: Restarting system\b' <<<"$J"; then
    [[ $DEBUG -eq 1 ]] && echo "# DEBUG matched: reboot: Restarting system" >&2
    echo "clean reboot"; return 0
  fi
  if grep -Eiq 'systemd\[1\]: (Starting|Reached target) (Reboot|Power-Off)' <<<"$J"; then
    [[ $DEBUG -eq 1 ]] && echo "# DEBUG matched: systemd[1] Reboot/Power-Off target" >&2
    [[ "$event_type" == "shutdown" ]] && { echo "clean poweroff"; return 0; }
    [[ "$event_type" == "reboot" ]] && { echo "clean reboot"; return 0; }
  fi

  if grep -Eiq 'systemd-logind\[[0-9]+\]: (Power key pressed|Power Button)' <<<"$J"; then
    [[ $DEBUG -eq 1 ]] && echo "# DEBUG matched: logind power button" >&2
    echo "power button"; return 0
  fi
  if grep -Eiq 'dbus-daemon\[[0-9]+\]: .* (Shutdown|Reboot) scheduled' <<<"$J"; then
    [[ $DEBUG -eq 1 ]] && echo "# DEBUG matched: dbus-daemon Shutdown/Reboot scheduled" >&2
    [[ "$event_type" == "shutdown" ]] && echo "clean poweroff" || echo "clean reboot"
    return 0
  fi

  if grep -Eiq '(apcupsd|apcdaemon|upsmon|nut)\[.*\].*(on battery|LOWBATT|shutdown|power off)' <<<"$J"; then
    [[ $DEBUG -eq 1 ]] && echo "# DEBUG matched: UPS/NUT/APC" >&2
    echo "UPS initiated"; return 0
  fi

  if grep -Eiq 'Kernel panic|panic:|Oops:|BUG: unable to handle kernel' <<<"$J"; then
    [[ $DEBUG -eq 1 ]] && echo "# DEBUG matched: kernel panic/oops" >&2
    echo "kernel panic"; return 0
  fi
  if grep -Eiq 'watchdog.*(hard LOCKUP|reboot|NMI watchdog)' <<<"$J"; then
    [[ $DEBUG -eq 1 ]] && echo "# DEBUG matched: watchdog" >&2
    echo "watchdog reset"; return 0
  fi
  if grep -Eiq '(Thermal|thermal).* (critical|overheat|overheated|shutdown)' <<<"$J"; then
    [[ $DEBUG -eq 1 ]] && echo "# DEBUG matched: thermal" >&2
    echo "thermal protection"; return 0
  fi

  local JOOM
  JOOM="$(journalctl -o short-iso --no-pager --since "$start_oom" --until "$end_win" 2>/dev/null || true)"
  if grep -Eiq 'Out of memory: Killed process' <<<"$JOOM"; then
    [[ $DEBUG -eq 1 ]] && echo "# DEBUG matched: OOM (lookback)" >&2
    echo "out-of-memory"; return 0
  fi

  if grep -Eiq 'EXT4-fs .*recovering journal|xfslog.*Mounting|dirty log' <<<"$J"; then
    [[ $DEBUG -eq 1 ]] && echo "# DEBUG matched: fs recovery suggests prior unclean" >&2
    echo "unclean shutdown (likely power loss)"; return 0
  fi

  if [[ $DEBUG -eq 1 ]]; then
    echo "# DEBUG no signature matched for $t_iso ($event_type); window below:" >&2
    echo "$J" >&2
  fi
  echo "unknown"
}

# --- Build list of events from `last -xF`, oldest -> newest ---
mapfile -t EVENTS < <(
  last -xF \
  | awk '
      BEGIN { OFS="|" }
      tolower($1) ~ /^(reboot|shutdown)$/ {
        n = NF
        year = $(n)
        time = $(n-1)
        day  = $(n-2)
        mon  = $(n-3)
        dow  = $(n-4)
        gsub(/,/, "", dow); gsub(/,/, "", mon); gsub(/,/, "", day); gsub(/,/, "", time); gsub(/,/, "", year)
        start = dow" "mon" "day" "time" "year
        printf "%s|%s\n", tolower($1), start
      }
    ' \
  | tac
)

# --- Output ---
for line in "${EVENTS[@]}"; do
  IFS='|' read -r etype start_raw <<<"$line"
  t_iso="$(to_iso "$start_raw")"
  within_bounds "$t_iso" || continue
  reason="$(journal_reason "$t_iso" "$etype")"
  printf "%s  %s\n" "$t_iso" "$reason"
done
