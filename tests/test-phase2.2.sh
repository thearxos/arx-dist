#!/usr/bin/env bash
set -euo pipefail
for f in arx-resource-scheduler arx-build-worker arx-build-queue arx-resource-history; do bash -n "$f"; done
! grep -nE -- '--skipinteg|--skippgpcheck' arx-build-worker
echo 'phase2.2 shell validation: PASS'
