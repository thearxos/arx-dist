#!/usr/bin/env bash
set -euo pipefail
bash -n arx-resource-scheduler arx-build-worker
! grep -nE -- '--skipinteg|--skippgpcheck' arx-build-worker
grep -q 'MAKEFLAGS' arx-build-worker
echo 'private phase2.2 validation: PASS'
