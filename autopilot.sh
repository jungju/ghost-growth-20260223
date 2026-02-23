#!/usr/bin/env bash
set -euo pipefail

# Run growth loop forever by default; set MAX_CYCLES to stop automatically.
MAX_CYCLES="${MAX_CYCLES:-0}"
SLEEP_SECONDS="${SLEEP_SECONDS:-60}"
FAIL_SLEEP_SECONDS="${FAIL_SLEEP_SECONDS:-$SLEEP_SECONDS}"
MAX_FAILURES="${MAX_FAILURES:-0}"
LOG_FILE="${LOG_FILE:-autopilot.log}"
GROWTH_SCRIPT="${GROWTH_SCRIPT:-./growth.sh}"
STOP_FILE="${STOP_FILE:-.autopilot.stop}"
LOCK_DIR="${LOCK_DIR:-.autopilot.lock.d}"

cycles=0
failures=0

if ! mkdir "$LOCK_DIR" 2>/dev/null; then
  echo "autopilot already running (lock: $LOCK_DIR)" >&2
  exit 1
fi

cleanup() {
  rmdir "$LOCK_DIR" 2>/dev/null || true
}
trap cleanup EXIT

while :; do
  if [[ -f "$STOP_FILE" ]]; then
    ts="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    printf '%s status=stopped reason=stop-file cycles=%s\n' "$ts" "$cycles" | tee -a "$LOG_FILE"
    break
  fi

  cycles=$((cycles + 1))
  ts="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  if out="$(bash "$GROWTH_SCRIPT" 2>&1)"; then
    failures=0
    printf '%s cycle=%s status=ok output=%s\n' "$ts" "$cycles" "$out" | tee -a "$LOG_FILE"
  else
    failures=$((failures + 1))
    printf '%s cycle=%s status=fail failure=%s output=%s\n' "$ts" "$cycles" "$failures" "$out" | tee -a "$LOG_FILE"
    if [[ "$MAX_FAILURES" -gt 0 && "$failures" -ge "$MAX_FAILURES" ]]; then
      echo "max failures reached: $failures" >&2
      exit 1
    fi
    sleep "$FAIL_SLEEP_SECONDS"
    continue
  fi

  if [[ "$MAX_CYCLES" -gt 0 && "$cycles" -ge "$MAX_CYCLES" ]]; then
    break
  fi

  sleep "$SLEEP_SECONDS"
done
