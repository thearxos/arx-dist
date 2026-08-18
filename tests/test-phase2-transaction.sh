#!/usr/bin/env bash
set -euo pipefail
bash -n arx-aur-phase2
! grep -nE -- '--skipinteg|--skippgpcheck' arx-aur-phase2
grep -q 'fetched' arx-aur-phase2
grep -q 'verified' arx-aur-phase2
grep -q 'building' arx-aur-phase2
grep -q 'built' arx-aur-phase2
grep -q 'installed' arx-aur-phase2
echo 'private ARX phase2 transaction smoke test: PASS'
