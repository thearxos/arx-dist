#!/usr/bin/env bash
set -euo pipefail
bash -n arx-weapons
bash -n arx-front
bash -n arx-recover
grep -q 'repo_has' arx-weapons
grep -q 'PKGBUILD' arx-weapons
grep -q 'arx-aur' arx-weapons
grep -q 'tee -a.*>&3' arx-recover
echo 'private Weapons/recovery smoke test: PASS'
