#!/bin/sh
# arx installer (binary-only). Downloads the prebuilt ArxOS package manager and
# installs it. No compiler, no build tools, no source. Run as root.
set -eu

VERSION="${ARX_VERSION:-0.1.1}"
PREFIX="${ARX_PREFIX:-/usr/local}"
REPO="${ARX_GITHUB_REPO:-thearxos/arx-dist}"
BASE="https://github.com/${REPO}/releases/download/v${VERSION}"
RAW="https://raw.githubusercontent.com/${REPO}/main"

[ "$(id -u)" = 0 ] || { echo "arx installer: run as root (sudo sh install.sh)"; exit 1; }
case "$(uname -m)" in x86_64) ;; *) echo "arx installer: only x86_64 is published"; exit 1;; esac

fetch() {
  if command -v curl >/dev/null 2>&1; then curl -fsSL "$1" -o "$2"
  elif command -v wget >/dev/null 2>&1; then wget -qO "$2" "$1"
  else echo "arx installer: need curl or wget"; exit 1; fi
}

TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT

echo "[arx] downloading ${VERSION}"
fetch "${BASE}/arx-core" "$TMP/arx-core"
fetch "${RAW}/tools.db" "$TMP/tools.db" || true   # arsenal data (lives in the repo, not the release)

# atomic install: write beside the target then rename, so a running arx keeps its
# inode and the swap is never half-applied.
ai() { # mode src dest
  d="$(dirname "$3")"; mkdir -p "$d"
  install -m"$1" "$2" "$d/.$(basename "$3").new.$$"
  mv -f "$d/.$(basename "$3").new.$$" "$3"
}

echo "[arx] installing"
ai 755 "$TMP/arx-core" "${PREFIX}/bin/arx"          # the binary IS arx
ln -sf arx "${PREFIX}/bin/arx-core"                 # compatibility name
[ -f "$TMP/tools.db" ] && ai 644 "$TMP/tools.db" /usr/share/arxos/tools.db

# package-manager I/O tune (keeps the sync databases hot in RAM)
cat > /etc/sysctl.d/30-arxos-pkg.conf <<'SYSCTL'
vm.vfs_cache_pressure = 50
SYSCTL
sysctl --system >/dev/null 2>&1 || true

echo "[arx] verifying"
"${PREFIX}/bin/arx" --version
echo "[arx] done. run: arx --help"
