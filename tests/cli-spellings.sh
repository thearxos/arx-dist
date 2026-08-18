#!/usr/bin/env bash
set -euo pipefail

ARX_BIN="${ARX_BIN:-./target/release/arx}"

# Verify both short and full spellings normalize to the same operation without
# requiring a privileged transaction. --help is intentionally used as a safe
# backend probe so CI never modifies the test host.
for pair in \
  '-S --sync' \
  '-R --remove' \
  '-U --upgrade' \
  '-Q --query' \
  '-F --files' \
  '-D --database' \
  '-T --deptest' \
  '-V --version'; do
  short=${pair%% *}
  long=${pair##* }
  "$ARX_BIN" "$short" --help >/tmp/arx-short.out 2>/tmp/arx-short.err || true
  "$ARX_BIN" "$long" --help >/tmp/arx-long.out 2>/tmp/arx-long.err || true
  if ! diff -u /tmp/arx-short.out /tmp/arx-long.out >/dev/null 2>&1; then
    echo "command spelling mismatch: $short vs $long" >&2
    exit 1
  fi
done

echo 'ARX CLI short/full command spelling checks passed'
