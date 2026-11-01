#!/bin/sh
# arx installer (binary-only). Downloads the prebuilt ArxOS package manager and
# installs it. No compiler, no build tools, no source. Run as root.
set -eu

# the newest release unless ARX_VERSION names one (it used to be pinned to 0.1.1, so every
# install got that build no matter what was released after it)
VERSION="${ARX_VERSION:-latest}"
PREFIX="${ARX_PREFIX:-/usr/local}"
REPO="${ARX_GITHUB_REPO:-thearxos/arx-dist}"
if [ "$VERSION" = latest ]; then BASE="https://github.com/${REPO}/releases/latest/download"
else BASE="https://github.com/${REPO}/releases/download/v${VERSION#v}"; fi
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
# the full bundle: arx, the libraries it ships with (so a system library update can never stop it
# from starting), its rescue tool and its self-check hook. It must match the release's checksum list
# before anything in it runs as root.
fetch "${BASE}/arx-x86_64-linux.tar.gz" "$TMP/arx.tar.gz"
fetch "${BASE}/SHA256SUMS" "$TMP/SHA256SUMS"
want="$(awk '$2 == "arx-x86_64-linux.tar.gz" || $2 == "*arx-x86_64-linux.tar.gz" {print $1}' "$TMP/SHA256SUMS")"
have="$(sha256sum "$TMP/arx.tar.gz" | cut -d' ' -f1)"
[ -n "$want" ] && [ "$want" = "$have" ] || { echo "arx installer: the bundle does not match SHA256SUMS; nothing installed"; exit 1; }
mkdir "$TMP/b" && tar -xzf "$TMP/arx.tar.gz" -C "$TMP/b" --no-same-owner
[ -f "$TMP/b/install.sh" ] && [ -f "$TMP/b/arx-core" ] || { echo "arx installer: the bundle is incomplete; nothing installed"; exit 1; }
(cd "$TMP/b" && ARX_PREFIX="$PREFIX" bash install.sh </dev/null)
echo "[arx] done. run: arx --help"
