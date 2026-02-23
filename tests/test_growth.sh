#!/usr/bin/env bash
set -euo pipefail

out="$(bash ./growth.sh)"
if [[ "${out}" != "build-small-public-artifacts" ]]; then
  echo "unexpected output: ${out}" >&2
  exit 1
fi

echo "ok"
