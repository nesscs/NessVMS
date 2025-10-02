#!/usr/bin/env bash
# vmslogs.sh — Minimal restart timeline for Ubuntu 22.04 bare metal
#
# Stream and run directly with:
#   sudo wget -qO- https://nesscs.com/vmslogs | sudo bash
#
# Output lines: "YYYY-MM-DD HH:MM:SS — REASON (optional cause)"
# Reasons: REBOOT, POWEROFF, UNEXPECTED_POWERLOSS
# Causes (if detected within 15m before shutdown/reboot):
#   KERNEL_PANIC, WATCHDOG, MCE, OOM, POWER_KEY, CMD
# Also flags UNEXPECTED_POWERLOSS if a boot occurs with no shutdown logged beforehand.
#
# Usage:
#   sudo ./vmslogs.sh
#   sudo ./vmslogs.sh --since "2025-09-20" --until "2025-09-26"
#   sudo ./vmslogs.sh --boots 10

set -euo pipefail

SINCE="" UNTIL="" BOOTS=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --since) shift; SINCE="--since=\"$1\"" ;;
    --until) shift; UNTIL="--until=\"$1\"" ;;
    --boots) shift; BOOTS="$1" ;;
    *) echo "Unknown arg: $1" >&2; exit 1 ;;
  esac
  shift || true
done

# Build journalctl source
J_CMD=(journalctl --system -o short-iso --no-pager)
[[ -n "$SINCE" ]] && J_CMD+=($(eval echo "$SINCE"))
[[ -n "$UNTIL" ]] && J_CMD+=($(eval echo "$UNTIL"))

# If user asked for N boots, concatenate those boots in order
if [[ -n "${BOOTS}" ]]; then
  journalctl --list-boots | tail -n "$BOOTS" | while read -r idx bootid start rest; do
    journalctl -b "$idx" -o short-iso --no-pager
  done
else
  "${J_CMD[@]}"
fi | awk '
BEGIN{
  IGNORECASE=1
}
function to_epoch(dt,  d,t,Y,M,D,h,m,s,a){
  split(dt,a," "); d=a[1]; t=a[2]
  split(d,a,"-"); Y=a[1]; M=a[2]; D=a[3]
  split(t,a,":"); h=a[1]; m=a[2]; s=a[3]
  return mktime(sprintf("%d %d %d %d %d %d",Y,M,D,h,m,s))
}
function print_event(ts, reason, cause, now,   out){
  out=ts" — "reason
  if (cause_t && now-cause_t<=900 && cause!="") out=out" ("cause")"
  print out
}
{
  ts=$1" "$2; line=$0
  # Track boots so we can infer "no shutdown logged"
  if (line ~ /(kernel: Linux version|systemd\[1\]: Started Journal Service|systemd\[1\]: Startup finished)/) {
    if (seen_boot && !had_clean_shutdown_since_boot) {
      if (!flagged_powerloss_at_boot[ts]) {
        print ts" — UNEXPECTED_POWERLOSS (no shutdown logged)"
      }
    }
    had_clean_shutdown_since_boot=0
    seen_boot=1
    next
  }

  # Capture possible causes
  if (line ~ /(Kernel panic|not syncing:)/)                     { cause="KERNEL_PANIC"; cause_t=to_epoch(ts); next }
  if (line ~ /(watchdog:|hard LOCKUP)/)                         { cause="WATCHDOG";    cause_t=to_epoch(ts); next }
  if (line ~ /(mce:|Machine check|Hardware Error)/)             { cause="MCE";         cause_t=to_epoch(ts); next }
  if (line ~ /(Out of memory:|oom-killer)/)                     { cause="OOM";         cause_t=to_epoch(ts); next }
  if (line ~ /(systemd-logind).*Power key pressed/)             { cause="POWER_KEY";   cause_t=to_epoch(ts); next }
  if (line ~ /(sudo: .* (shutdown|poweroff|reboot)|systemctl .* (reboot|poweroff)|shutdown\[)/) { cause="CMD"; cause_t=to_epoch(ts); next }

  # Filesystem recovery hints (ext4, xfs, btrfs, zfs, f2fs)
  if (line ~ /(EXT4-fs .* (recovery required|recovering journal)|EXT4-fs .* was not properly unmounted)/ ||
      line ~ /(XFS \(.*\): (log recovery|dirty log|Unclean shutdown detected))/ ||
      line ~ /(BTRFS( info| warning) .* (transaction aborted|forced readonly|log replay))/ ||
      line ~ /(ZFS:.*pool .* was last accessed inconsistently|ZFS:.*rewinding log)/ ||
      line ~ /(F2FS-fs\(.*\): recovery|F2FS-fs\(.*\): mounted with checkpoint=disable)/ ) {
    print ts" — UNEXPECTED_POWERLOSS"
    flagged_powerloss_at_boot[ts]=1
    next
  }

  # Clean reboot
  if (line ~ /(systemd-shutdown|Reached target Reboot|reboot: Restarting system|Rebooting\.)/) {
    now=to_epoch(ts); print_event(ts,"REBOOT",cause,now)
    had_clean_shutdown_since_boot=1; cause=""; cause_t=0; next
  }

  # Clean poweroff
  if (line ~ /(Powering off|Reached target Power-Off|Shutting down)/) {
    now=to_epoch(ts); print_event(ts,"POWEROFF",cause,now)
    had_clean_shutdown_since_boot=1; cause=""; cause_t=0; next
  }
}
' | sort
