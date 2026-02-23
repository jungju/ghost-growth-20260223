#!/usr/bin/env bash
set -euo pipefail

out="$(bash ./growth.sh)"
if [[ "${out}" != "build-small-public-artifacts" ]]; then
  echo "unexpected output: ${out}" >&2
  exit 1
fi

rm -f ./autopilot.log
rm -f /tmp/self-evolve-test.md
MAX_CYCLES=2 SLEEP_SECONDS=0 SELF_EVOLVE_REPORT=/tmp/self-evolve-test.md bash ./autopilot.sh > /tmp/autopilot.out
cycles="$(wc -l < /tmp/autopilot.out | tr -d ' ')"
if [[ "${cycles}" != "2" ]]; then
  echo "unexpected cycle lines: ${cycles}" >&2
  exit 1
fi
if ! rg -q "evolve=ok" /tmp/autopilot.out; then
  echo "expected evolve=ok in autopilot output" >&2
  exit 1
fi

if [[ ! -f ./autopilot.log ]]; then
  echo "autopilot log file missing" >&2
  exit 1
fi
if [[ ! -f /tmp/self-evolve-test.md ]]; then
  echo "self evolve report missing" >&2
  exit 1
fi
if ! rg -q "### Retrospective" /tmp/self-evolve-test.md; then
  echo "self evolve retrospective missing" >&2
  exit 1
fi
if ! rg -q "### Structure Scores" /tmp/self-evolve-test.md; then
  echo "self evolve score section missing" >&2
  exit 1
fi

touch ./.autopilot.stop.test
STOP_FILE=./.autopilot.stop.test LOG_FILE=./autopilot-stop.log bash ./autopilot.sh > /tmp/autopilot.stop.out
rm -f ./.autopilot.stop.test
if ! rg -q "status=stopped reason=stop-file" /tmp/autopilot.stop.out; then
  echo "missing stop-file status output" >&2
  exit 1
fi

cat > /tmp/flaky-growth.sh << 'EOF'
#!/usr/bin/env bash
set -euo pipefail
if [[ ! -f /tmp/flaky-growth.once ]]; then
  touch /tmp/flaky-growth.once
  echo "transient error" >&2
  exit 1
fi
echo "recovered"
EOF
chmod +x /tmp/flaky-growth.sh
rm -f /tmp/flaky-growth.once
LOG_FILE=./autopilot-flaky.log MAX_CYCLES=2 SLEEP_SECONDS=0 FAIL_SLEEP_SECONDS=0 GROWTH_SCRIPT=/tmp/flaky-growth.sh SELF_EVOLVE_REPORT=/tmp/self-evolve-flaky.md bash ./autopilot.sh > /tmp/autopilot.flaky.out
if ! rg -q "status=fail" /tmp/autopilot.flaky.out; then
  echo "expected at least one failure cycle" >&2
  exit 1
fi
if ! rg -q "status=ok evolve=ok output=recovered" /tmp/autopilot.flaky.out; then
  echo "expected recovered success cycle" >&2
  exit 1
fi

cat > /tmp/always-fail-growth.sh << 'EOF'
#!/usr/bin/env bash
set -euo pipefail
echo "hard error" >&2
exit 1
EOF
chmod +x /tmp/always-fail-growth.sh
if LOG_FILE=./autopilot-hardfail.log MAX_CYCLES=2 SLEEP_SECONDS=0 FAIL_SLEEP_SECONDS=0 MAX_FAILURES=1 GROWTH_SCRIPT=/tmp/always-fail-growth.sh SELF_EVOLVE_REPORT=/tmp/self-evolve-hardfail.md bash ./autopilot.sh > /tmp/autopilot.hardfail.out 2>/tmp/autopilot.hardfail.err; then
  echo "expected autopilot hard failure exit" >&2
  exit 1
fi
if ! rg -q "max failures reached: 1" /tmp/autopilot.hardfail.err; then
  echo "missing max failure error message" >&2
  exit 1
fi

echo "ok"
