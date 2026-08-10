#!/usr/bin/env bash
set -euo pipefail
bash -n arx-resource-scheduler
out=$(ARX_CPU_JOBS=8 ARX_MAX_JOBS=4 ARX_BUILD_RAM_MB=1024 ./arx-resource-scheduler jobs .)
case "$out" in 1|2|3|4) ;; *) echo "invalid scheduler result: $out" >&2; exit 1;; esac
./arx-resource-scheduler check . | grep -q recommended_jobs=
echo 'resource scheduler smoke test: PASS'
