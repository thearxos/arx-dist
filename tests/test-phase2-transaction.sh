#!/usr/bin/env bash
set -euo pipefail
f=./arx-aur-phase2
bash -n "$f"
# The source must not introduce verification bypasses.
! grep -nE -- '--skipinteg|--skippgpcheck' "$f"
# The state machine must contain resumable phases.
grep -q 'fetched' "$f"
grep -q 'verified' "$f"
grep -q 'building' "$f"
grep -q 'built' "$f"
grep -q 'installed' "$f"
echo 'phase2 transaction smoke test: PASS'
