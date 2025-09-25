#!/usr/bin/env bash
# logs.sh — Bare-metal power timeline summariser for Ubuntu 22.04+
#
# Produces a human-readable timeline of BOOT/SHUTDOWN/REBOOT and
# hardware-related events (power loss, watchdog, thermal, PSU, RAID, OOM, etc.)
#
# Usage:
#   sudo ./logs.sh
#   sudo ./logs.sh --since "2025-09-20" --until "2025-09-26"
#   sudo ./logs.sh --boots 6
#
# Dependencies: systemd-journald, last(1); optional: ipmitool, apcupsd, NUT
#
# sudo wget -O - https://nesscs.com/logs | bash


set -euo pipefail

SINCE=""
UNTIL=""
BOOTS=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --since) shift; SINCE="--since=\"$1\"" ;;
    --until) shift; UNTIL="--until=\"$1\"" ;;
    --boots) shift; BOOTS="$1" ;;
    *) echo "Unknown arg: $1" >&2; exit 1 ;;
  esac
  shift || true
done

if [[ ! -d /var/log/journal ]]; then
  echo "NOTE: Journald persistence is OFF. Enable it to retain history:"
  echo "  sudo mkdir -p /var/log/journal && sudo systemd-tmpfiles --create --prefix /var/log/journal && sudo systemctl restart systemd-journald"
  echo
fi

host="$(hostnamectl --static 2>/dev/null || hostname)"
echo "==== Power Timeline for host: ${host} ===="
date -Is
echo

# --- WTMP summary
if command -v last >/dev/null 2>&1; then
  echo "---- last -xF (boots/shutdowns) ----"
  last -xF | egrep -i '(^reboot|^shutdown|system boot)' | sed 's/^/WTMP: /' | head -n 300
  echo
fi

# Build journalctl base command
J_CMD=(journalctl --system -o short-iso --no-pager)
# shellcheck disable=SC2206
[[ -n "$SINCE" ]] && J_CMD+=($(eval echo "$SINCE"))
# shellcheck disable=SC2206
[[ -n "$UNTIL" ]] && J_CMD+=($(eval echo "$UNTIL"))

# Per-boot mode
if [[ -n "${BOOTS}" ]]; then
  echo "---- journalctl per-boot timeline (last ${BOOTS}) ----"
  journalctl --list-boots | tail -n "$BOOTS" | while read -r idx bootid start rest; do
    echo "===== Boot ${idx} (${bootid}) started ${start} ====="
    journalctl -b "$idx" -o short-iso --no-pager | awk -f <(cat <<'AWK'
BEGIN{IGNORECASE=1}
{
  ts=$1" "$2; line=$0; label="";
  if (line ~ /(kernel: Linux version|systemd\[1\]: Started Journal Service|systemd\[1\]: Startup finished)/) label="BOOT";
  else if (line ~ /(systemd-shutdown|Reached target Reboot|reboot: Restarting system|Rebooting\.)/) label="REBOOT";
  else if (line ~ /(Powering off|Reached target Power-Off|Shutting down)/) label="POWEROFF";

  else if (line ~ /(EXT4-fs .* recovery required|recovering journal|clean, .* last mounted on)/) label="UNEXPECTED_POWERLOSS";

  else if (line ~ /(PM: suspend entry|Suspending system)/) label="SUSPEND";
  else if (line ~ /(PM: suspend exit|resumed from)/) label="RESUME";
  else if (line ~ /(hibernat)/) label="HIBERNATE";
  else if (line ~ /(rtcwake|RTC)/) label="RTCWAKE";

  else if (line ~ /(systemd-logind).*Power key pressed/) label="POWER_KEY";
  else if (line ~ /(ACPI:.*Power Button|power button)/) label="ACPI_POWER_BUTTON";
  else if (line ~ /(ACPI:.*Lid Switch|LID switch)/) label="ACPI_LID";

  else if (line ~ /(Kernel panic|not syncing:)/) label="KERNEL_PANIC";
  else if (line ~ /(watchdog:|hard LOCKUP)/) label="WATCHDOG";
  else if (line ~ /(mce:|Machine check events logged|Hardware Error)/) label="MCE";
  else if (line ~ /(EDAC .* corrected|uncorrected)/) label="EDAC";
  else if (line ~ /(thermal|CPU temperature)/) label="THERMAL";
  else if (line ~ /(psu|power supply|VRM|undervoltage|overvoltage)/) label="POWER_SUPPLY";
  else if (line ~ /(raid|megaraid|mpt3sas|ahci .* link is down|I\/O error)/) label="STORAGE/RAID";

  else if (line ~ /(Out of memory:|oom-killer)/) label="OOM";

  else if (line ~ /sudo: .* (shutdown|poweroff|reboot)/) label="SUDO_CMD";
  else if (line ~ /(systemctl .* (reboot|poweroff)|shutdown\[)/) label="CMD";

  if (label!="") printf("%s | %-20s | %s\n", ts, label, line);
}
AWK
)
    echo
  done
  exit 0
fi

# Default single-range mode
echo "---- journalctl condensed timeline ----"
"${J_CMD[@]}" | awk 'BEGIN{IGNORECASE=1}
{
  ts=$1" "$2; line=$0; label="";
  if (line ~ /(kernel: Linux version|systemd\[1\]: Started Journal Service|systemd\[1\]: Startup finished)/) label="BOOT";
  else if (line ~ /(systemd-shutdown|Reached target Reboot|reboot: Restarting system|Rebooting\.)/) label="REBOOT";
  else if (line ~ /(Powering off|Reached target Power-Off|Shutting down)/) label="POWEROFF";
  else if (line ~ /(EXT4-fs .* recovery required|recovering journal|clean, .* last mounted on)/) label="UNEXPECTED_POWERLOSS";
  else if (line ~ /(Kernel panic|not syncing:)/) label="KERNEL_PANIC";
  else if (line ~ /(watchdog:|hard LOCKUP)/) label="WATCHDOG";
  else if (line ~ /(mce:|Hardware Error)/) label="MCE";
  else if (line ~ /(thermal|CPU temperature)/) label="THERMAL";
  else if (line ~ /(psu|power supply|VRM|undervoltage|overvoltage)/) label="POWER_SUPPLY";
  else if (line ~ /(raid|megaraid|mpt3sas|ahci .* link is down|I\/O error)/) label="STORAGE/RAID";
  else if (line ~ /(Out of memory:|oom-killer)/) label="OOM";
  else if (line ~ /sudo: .* (shutdown|poweroff|reboot)/) label="SUDO_CMD";
  else if (line ~ /(systemctl .* (reboot|poweroff)|shutdown\[)/) label="CMD";
  if (label!="") printf("%s | %-20s | %s\n", ts, label, line);
}'
echo

# Optional hardware events
if command -v ipmitool >/dev/null 2>&1; then
  echo "---- IPMI SEL (power/thermal) ----"
  ipmitool sel elist 2>/dev/null | egrep -i 'power|psu|thermal|watchdog|reset|ac lost|ac restored' | tail -n 50 | sed 's/^/IPMI: /' || true
  echo
fi
