#!/usr/bin/env bash
D=$(cd "$(dirname "$0")" && pwd)

# Keep the mature ARX CLI as a compatibility backend. The front controller owns
# AUR routing and transaction recovery, so yay/paru are not runtime dependencies.
sudo install -Dm755 "$D/arx" /usr/local/lib/arxos/arx-pacman
sudo install -m755 "$D/arx-front" /usr/local/bin/arx
sudo install -m755 "$D/arx-aur" /usr/local/bin/arx-aur
sudo install -m755 "$D/arx-recover" /usr/local/bin/arx-recover

# ship the ARXOS arsenal taxonomy so `arx weapons` works out of the box
[ -f "$D/tools.db" ] && sudo install -Dm644 "$D/tools.db" /usr/share/arxos/tools.db

# native Rust/libalpm core (instant search/list). Install only if it passes its ABI selftest
# on THIS machine; arx-pacman auto-falls back to pacman if it's missing or the libalpm ABI shifted.
if [ -x "$D/arx-core/dist/arx-core" ] && "$D/arx-core/dist/arx-core" --selftest >/dev/null 2>&1; then
  sudo install -Dm755 "$D/arx-core/dist/arx-core" /usr/lib/arxos/arx-core && echo "arx-core installed (native query core)"
fi

echo "arx installed ($([ -f /usr/share/arxos/tools.db ] && grep -cE "^[A-Za-z0-9._+-]+\|[OBDR]\|" /usr/share/arxos/tools.db) arsenal tools)"
echo "native AUR client: arx-aur (yay/paru not required)"
echo "transaction recovery: arx-recover (bounded retry + failure classification)"

# GUI sudo askpass helper + our own custom bad-password message pool
[ -f "$D/arxos-askpass" ] && sudo install -m755 "$D/arxos-askpass" /usr/local/bin/arxos-askpass
[ -f "$D/badpass.txt" ] && sudo install -Dm644 "$D/badpass.txt" /usr/share/arxos/badpass.txt
# arsenal menu tool launcher (run if installed / offer to install if missing)
[ -f "$D/arxos-run-tool" ] && sudo install -m755 "$D/arxos-run-tool" /usr/local/bin/arxos-run-tool

# Password UX: show * as the password is typed (pwfeedback) + a custom bad-password message.
# Validated with visudo before install so a malformed file can never lock out sudo.
if command -v visudo >/dev/null 2>&1 && [ ! -f /etc/sudoers.d/20-arxos-pw ]; then
  _pw=$(mktemp) || _pw=""
  if [ -n "$_pw" ]; then
    printf '%s\n' '# ArxOS: asterisk password feedback + a custom bad-password message' \
      'Defaults pwfeedback' \
      'Defaults badpass_message="oh the mighty have fallen again, lock in twin"' > "$_pw"
    sudo visudo -cf "$_pw" >/dev/null 2>&1 && sudo install -m440 "$_pw" /etc/sudoers.d/20-arxos-pw
    rm -f "$_pw"
  fi
fi

# XFCE "Weapons" arsenal menu: a category submenu whose entries each open
# `arx weapons <group>` in a terminal. Idempotent; never blocks the install.
[ -f "$D/weapons-menu.sh" ] && bash "$D/weapons-menu.sh" || true

# Cache sudo credentials per-user (not per-tty) so `arx update`'s helper scripts - which
# run in their own pseudo-terminals - reuse the single authentication instead of each
# re-prompting (and hanging) for the password. Validated with visudo before install so a
# malformed file can NEVER lock the user out of sudo.
if command -v visudo >/dev/null 2>&1 && [ ! -f /etc/sudoers.d/10-arxos-sudo ]; then
  _sd=$(mktemp) || _sd=""
  if [ -n "$_sd" ]; then
    printf '# ArxOS: per-user sudo credential caching for the unified updater\nDefaults timestamp_type=global\n' > "$_sd"
    sudo visudo -cf "$_sd" >/dev/null 2>&1 && sudo install -m440 "$_sd" /etc/sudoers.d/10-arxos-sudo
    rm -f "$_sd"
  fi
fi
