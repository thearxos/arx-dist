#!/usr/bin/env bash
set -euo pipefail
ROOT=$(cd "$(dirname "$0")/.." && pwd)

bash -n "$ROOT/arx-aur"
bash -n "$ROOT/arx-recover"
bash -n "$ROOT/arx-front"
bash -n "$ROOT/install.sh"

# The classifier must distinguish representative failure classes without executing repairs.
tmp=$(mktemp); trap 'rm -f "$tmp"' EXIT
printf '%s\n' 'curl: (6) Could not resolve host: mirror.example' > "$tmp"
[ "$(ARX_JOURNAL_DIR=/tmp/arx-test-journal "$ROOT/arx-recover" --classify "$tmp")" = network ]
printf '%s\n' 'error: invalid or corrupted package' > "$tmp"
[ "$(ARX_JOURNAL_DIR=/tmp/arx-test-journal "$ROOT/arx-recover" --classify "$tmp")" = cache ]
printf '%s\n' 'error: unable to lock database' > "$tmp"
[ "$(ARX_JOURNAL_DIR=/tmp/arx-test-journal "$ROOT/arx-recover" --classify "$tmp")" = lock ]

printf 'arx transaction smoke tests: PASS\n'
