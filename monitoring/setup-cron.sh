#!/usr/bin/env bash
# setup-cron.sh - install (or remove) a cron job that runs monitor.sh periodically.
# Usage: ./setup-cron.sh [interval_minutes]   (default 5)
#        ./setup-cron.sh --remove
# Optional env: STATUS_FILE, LOG_FILE, CPU_THRESHOLD, MEM_THRESHOLD, DISK_THRESHOLD
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MONITOR="$SCRIPT_DIR/monitor.sh"
MARKER="# devops-platform-monitor"

command -v crontab >/dev/null || { echo "ERROR: crontab not found. Install: sudo apt install -y cron" >&2; exit 1; }
[[ -f "$MONITOR" ]] || { echo "ERROR: $MONITOR not found" >&2; exit 1; }
chmod +x "$MONITOR"

current="$(crontab -l 2>/dev/null || true)"
cleaned="$(printf '%s\n' "$current" | grep -vF "$MARKER" || true)"

if [[ "${1:-}" == "--remove" ]]; then
  printf '%s\n' "$cleaned" | sed '/^$/d' | crontab -
  echo "Cron job removed."
  exit 0
fi

INTERVAL="${1:-5}"
[[ "$INTERVAL" =~ ^[0-9]+$ ]] && (( INTERVAL >= 1 && INTERVAL <= 59 )) \
  || { echo "ERROR: interval must be 1-59 minutes" >&2; exit 1; }

envs=""
for v in STATUS_FILE LOG_FILE CPU_THRESHOLD MEM_THRESHOLD DISK_THRESHOLD; do
  [[ -n "${!v:-}" ]] && envs+="$v=${!v} "
done

line="*/$INTERVAL * * * * ${envs}$MONITOR >/dev/null 2>&1 $MARKER"
{ printf '%s\n' "$cleaned" | sed '/^$/d'; echo "$line"; } | crontab -

echo "Installed cron job (every $INTERVAL min):"
echo "  $line"
echo "Verify with: crontab -l   and   tail -f \"\${LOG_FILE:-$SCRIPT_DIR/../logs/monitor.log}\""
