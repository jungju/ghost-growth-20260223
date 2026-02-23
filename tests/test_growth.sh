#!/usr/bin/env bash
set -euo pipefail

out="$(bash ./growth.sh)"
if [[ "${out}" != "build-small-public-artifacts" ]]; then
  echo "unexpected output: ${out}" >&2
  exit 1
fi

rm -f ./autopilot.log
MAX_CYCLES=2 SLEEP_SECONDS=0 bash ./autopilot.sh > /tmp/autopilot.out
cycles="$(wc -l < /tmp/autopilot.out | tr -d ' ')"
if [[ "${cycles}" != "2" ]]; then
  echo "unexpected cycle lines: ${cycles}" >&2
  exit 1
fi

if [[ ! -f ./autopilot.log ]]; then
  echo "autopilot log file missing" >&2
  exit 1
fi

echo "ok"
