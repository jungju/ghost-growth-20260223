#!/usr/bin/env bash
set -euo pipefail

# Run growth loop forever by default; set MAX_CYCLES to stop automatically.
MAX_CYCLES="${MAX_CYCLES:-0}"
SLEEP_SECONDS="${SLEEP_SECONDS:-60}"
LOG_FILE="${LOG_FILE:-autopilot.log}"

cycles=0
while :; do
  cycles=$((cycles + 1))
  out="$(bash ./growth.sh)"
  ts="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  printf '%s cycle=%s output=%s\n' "$ts" "$cycles" "$out" | tee -a "$LOG_FILE"

  if [[ "$MAX_CYCLES" -gt 0 && "$cycles" -ge "$MAX_CYCLES" ]]; then
    break
  fi

  sleep "$SLEEP_SECONDS"
done
