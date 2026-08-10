#!/usr/bin/env bash
set -euo pipefail

f=./arx-aur-phase2.sh
[ -x "$f" ] || { echo "phase2 runner missing or not executable" >&2; exit 1; }

bash -n "$f"

# Policy guard: the orchestration layer must never introduce verification bypasses.
if grep -nE -- '--skipinteg|--skippgpcheck|--nocheck' "$f"; then
  echo "unsafe makepkg verification bypass found" >&2
  exit 1
fi

echo "phase2 makepkg policy smoke test: PASS"
