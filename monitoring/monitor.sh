#!/usr/bin/env bash
# monitor.sh - CPU / RAM / disk / uptime monitor with thresholds and logging.
#
# Config (environment variables, all optional):
#   CPU_THRESHOLD=80  MEM_THRESHOLD=80  DISK_THRESHOLD=80   (percent)
#   DISK_PATH=/       filesystem to check
#   LOG_FILE=<repo>/logs/monitor.log
#   STATUS_FILE=      if set, a JSON snapshot is written there (used by the dashboard)
# Exit codes: 0 = all OK, 10 = threshold warning(s), 1 = error.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CPU_THRESHOLD="${CPU_THRESHOLD:-80}"
MEM_THRESHOLD="${MEM_THRESHOLD:-80}"
DISK_THRESHOLD="${DISK_THRESHOLD:-80}"
DISK_PATH="${DISK_PATH:-/}"
LOG_FILE="${LOG_FILE:-$SCRIPT_DIR/../logs/monitor.log}"
STATUS_FILE="${STATUS_FILE:-}"

die() { echo "ERROR: $*" >&2; exit 1; }

is_int() { [[ "$1" =~ ^[0-9]+$ ]]; }
for v in CPU_THRESHOLD MEM_THRESHOLD DISK_THRESHOLD; do
  is_int "${!v}" || die "$v must be a whole number (got '${!v}')"
  (( ${!v} >= 1 && ${!v} <= 100 )) || die "$v must be between 1 and 100"
done
[[ "$(uname -s)" == "Linux" ]] || die "This script needs Linux (/proc). Run it on Ubuntu/EC2 or WSL."
[[ -r /proc/stat && -r /proc/meminfo && -r /proc/uptime ]] || die "/proc files not readable"
command -v df >/dev/null || die "df not found"

mkdir -p "$(dirname "$LOG_FILE")" 2>/dev/null || die "cannot create log directory for $LOG_FILE"
touch "$LOG_FILE" 2>/dev/null || die "cannot write to log file $LOG_FILE"

# --- CPU: sample /proc/stat twice, 1 second apart ---
read_cpu() { awk '/^cpu /{idle=$5+$6; total=0; for(i=2;i<=NF;i++) total+=$i; print idle, total}' /proc/stat; }
read -r idle1 total1 < <(read_cpu)
sleep 1
read -r idle2 total2 < <(read_cpu)
dt=$(( total2 - total1 )); di=$(( idle2 - idle1 ))
if (( dt > 0 )); then CPU=$(( (100 * (dt - di)) / dt )); else CPU=0; fi

# --- RAM ---
mem_total_kb=$(awk '/^MemTotal:/{print $2}' /proc/meminfo)
mem_avail_kb=$(awk '/^MemAvailable:/{print $2}' /proc/meminfo)
[[ -n "$mem_total_kb" && -n "$mem_avail_kb" && "$mem_total_kb" -gt 0 ]] || die "cannot read memory info"
mem_used_kb=$(( mem_total_kb - mem_avail_kb ))
MEM=$(( 100 * mem_used_kb / mem_total_kb ))
MEM_TOTAL_MB=$(( mem_total_kb / 1024 )); MEM_USED_MB=$(( mem_used_kb / 1024 ))

# --- Disk ---
disk_line=$(df -P -k "$DISK_PATH" 2>/dev/null | awk 'NR==2{print $2, $3, $4, $5}') || true
[[ -n "$disk_line" ]] || die "df failed for $DISK_PATH"
read -r _dtotal _dused disk_avail_kb disk_pct_raw <<<"$disk_line"
DISK="${disk_pct_raw%\%}"
DISK_FREE_GB=$(awk -v k="$disk_avail_kb" 'BEGIN{printf "%.1f", k/1024/1024}')

# --- Uptime ---
UPTIME_SEC=$(awk '{printf "%d", $1}' /proc/uptime)
UPTIME_H="$(( UPTIME_SEC / 86400 ))d $(( (UPTIME_SEC % 86400) / 3600 ))h $(( (UPTIME_SEC % 3600) / 60 ))m"

TS="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
HOST="$(hostname 2>/dev/null || echo unknown)"

warnings=()
(( CPU  >= CPU_THRESHOLD  )) && warnings+=("CPU ${CPU}% >= ${CPU_THRESHOLD}%")
(( MEM  >= MEM_THRESHOLD  )) && warnings+=("RAM ${MEM}% >= ${MEM_THRESHOLD}%")
(( DISK >= DISK_THRESHOLD )) && warnings+=("Disk ${DISK}% >= ${DISK_THRESHOLD}%")

# --- Readable output ---
cat <<OUT
=== Server Monitor | $HOST | $TS ===
CPU usage   : ${CPU}%  (warn at ${CPU_THRESHOLD}%)
RAM usage   : ${MEM}%  (${MEM_USED_MB}/${MEM_TOTAL_MB} MB, warn at ${MEM_THRESHOLD}%)
Disk usage  : ${DISK}%  on ${DISK_PATH} (warn at ${DISK_THRESHOLD}%)
Disk free   : ${DISK_FREE_GB} GB
Uptime      : ${UPTIME_H}
OUT

# --- Log ---
{
  echo "$TS host=$HOST cpu=${CPU}% mem=${MEM}% disk=${DISK}% disk_free_gb=${DISK_FREE_GB} uptime_s=${UPTIME_SEC}"
  for w in "${warnings[@]+"${warnings[@]}"}"; do echo "$TS WARNING $w"; done
} >> "$LOG_FILE" || die "failed to write log"

# --- Optional JSON status for the dashboard (atomic write) ---
if [[ -n "$STATUS_FILE" ]]; then
  wjson=""
  for w in "${warnings[@]+"${warnings[@]}"}"; do wjson+="\"$w\","; done
  wjson="[${wjson%,}]"
  tmp="${STATUS_FILE}.tmp.$$"
  printf '{"timestamp":"%s","host":"%s","cpu_percent":%d,"mem_percent":%d,"mem_used_mb":%d,"mem_total_mb":%d,"disk_percent":%d,"disk_free_gb":%s,"uptime_seconds":%d,"thresholds":{"cpu":%d,"mem":%d,"disk":%d},"warnings":%s}\n' \
    "$TS" "$HOST" "$CPU" "$MEM" "$MEM_USED_MB" "$MEM_TOTAL_MB" "$DISK" "$DISK_FREE_GB" "$UPTIME_SEC" \
    "$CPU_THRESHOLD" "$MEM_THRESHOLD" "$DISK_THRESHOLD" "$wjson" > "$tmp" 2>/dev/null \
    && mv "$tmp" "$STATUS_FILE" && chmod 644 "$STATUS_FILE" \
    || echo "WARNING: could not write STATUS_FILE $STATUS_FILE" >&2
fi

if (( ${#warnings[@]} > 0 )); then
  for w in "${warnings[@]}"; do echo "WARNING: $w" >&2; done
  exit 10
fi
echo "Status: OK"
exit 0
