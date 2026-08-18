#!/bin/sh
set -eu

VERSION="${ARX_VERSION:-0.1.1}"
PREFIX="${ARX_PREFIX:-/usr/local}"
REPO="${ARX_GITHUB_REPO:-thearxos/arx}"
ARCH="$(uname -m)"
MODE="${ARX_INSTALL_MODE:-}"

case "$ARCH" in
  x86_64) TARGET="x86_64-unknown-linux-gnu" ;;
  *) echo "ARX installer: unsupported architecture: $ARCH" >&2; exit 1 ;;
esac

case "$MODE" in
  binary|source|) ;;
  *) echo "ARX installer: ARX_INSTALL_MODE must be binary or source" >&2; exit 2 ;;
esac

ROOT="$(CDPATH= cd -- "$(dirname "$0")" && pwd)"
if [ -f "$ROOT/installer/components.env" ]; then
  # shellcheck disable=SC1091
  . "$ROOT/installer/components.env"
fi
VERSION="${ARX_VERSION:-$VERSION}"

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT INT TERM

say() { printf '%s\n' "$*"; }

need_root() {
  if [ "$(id -u)" -eq 0 ]; then return 0; fi
  if command -v sudo >/dev/null 2>&1; then
    sudo "$@"
  elif command -v doas >/dev/null 2>&1; then
    doas "$@"
  else
    echo "ARX installer: administrator privileges are required; install sudo-rs or run as root" >&2
    exit 1
  fi
}

install_sudo_rs() {
  say "[ARX] ensuring sudo-rs is installed"
  if command -v sudo >/dev/null 2>&1 && sudo --version 2>/dev/null | grep -qi 'sudo-rs'; then
    say "[ARX] sudo-rs already active"
    return 0
  fi
  if command -v pacman >/dev/null 2>&1; then
    need_root pacman -S --needed --noconfirm sudo-rs
  else
    echo "ARX installer: pacman is required to provision sudo-rs on Arch-based systems" >&2
    exit 1
  fi
}

fetch() {
  if command -v curl >/dev/null 2>&1; then
    curl -fsSL "$1" -o "$2"
  elif command -v wget >/dev/null 2>&1; then
    wget -qO "$2" "$1"
  else
    echo "ARX installer: curl or wget is required" >&2
    exit 1
  fi
}

install_bundle_files() {
  src="$1"
  need_root install -Dm755 "$src/arx" "${PREFIX}/bin/arx"
  need_root install -Dm755 "$src/arx-pacman" "${PREFIX}/lib/arxos/arx-pacman"
  need_root install -Dm755 "$src/arx-aur" "${PREFIX}/bin/arx-aur"
  need_root install -Dm755 "$src/arx-recover" "${PREFIX}/bin/arx-recover"
  need_root install -Dm755 "$src/arx-core" "${PREFIX}/lib/arxos/arx-core"
  [ -f "$src/tools.db" ] && need_root install -Dm644 "$src/tools.db" /usr/share/arxos/tools.db
  [ -f "$src/arxos-askpass" ] && need_root install -Dm755 "$src/arxos-askpass" "${PREFIX}/bin/arxos-askpass"
  [ -f "$src/badpass.txt" ] && need_root install -Dm644 "$src/badpass.txt" /usr/share/arxos/badpass.txt
  [ -f "$src/arxos-run-tool" ] && need_root install -Dm755 "$src/arxos-run-tool" "${PREFIX}/bin/arxos-run-tool"
}

install_binary() {
  ASSET="arx-${VERSION}-${TARGET}.tar.gz"
  BASE="https://github.com/${REPO}/releases/download/v${VERSION}"
  say "[ARX] installing prebuilt release ${VERSION} (${ARCH})"
  fetch "${BASE}/${ASSET}" "${TMP}/${ASSET}"
  rm -rf "$TMP/bundle"
  mkdir -p "$TMP/bundle"
  tar -xzf "${TMP}/${ASSET}" -C "$TMP/bundle"
  for required in arx arx-pacman arx-aur arx-recover arx-core install.sh installer/components.env; do
    test -e "$TMP/bundle/$required" || { echo "ARX installer: release missing $required" >&2; exit 1; }
  done
  install_bundle_files "$TMP/bundle"
}

install_source() {
  say "[ARX] building ARX ${VERSION} from source"
  command -v cargo >/dev/null 2>&1 || {
    if command -v pacman >/dev/null 2>&1; then
      need_root pacman -S --needed --noconfirm base-devel rust cargo clang pkgconf git
    else
      echo "ARX installer: source mode requires cargo/rust and Arch build dependencies" >&2
      exit 1
    fi
  }
  cargo build --manifest-path "${ROOT}/arx-core/Cargo.toml" --release
  test -x "${ROOT}/arx-core/target/release/arx-core" || { echo "ARX installer: source build did not produce arx-core" >&2; exit 1; }
  need_root install -Dm755 "${ROOT}/arx-front" "${PREFIX}/bin/arx"
  need_root install -Dm755 "${ROOT}/arx" "${PREFIX}/lib/arxos/arx-pacman"
  need_root install -Dm755 "${ROOT}/arx-aur" "${PREFIX}/bin/arx-aur"
  need_root install -Dm755 "${ROOT}/arx-recover" "${PREFIX}/bin/arx-recover"
  need_root install -Dm755 "${ROOT}/arx-core/target/release/arx-core" "${PREFIX}/lib/arxos/arx-core"
  [ -f "$ROOT/tools.db" ] && need_root install -Dm644 "$ROOT/tools.db" /usr/share/arxos/tools.db
  [ -f "$ROOT/arxos-askpass" ] && need_root install -Dm755 "$ROOT/arxos-askpass" "${PREFIX}/bin/arxos-askpass"
  [ -f "$ROOT/badpass.txt" ] && need_root install -Dm644 "$ROOT/badpass.txt" /usr/share/arxos/badpass.txt
  [ -f "$ROOT/arxos-run-tool" ] && need_root install -Dm755 "$ROOT/arxos-run-tool" "${PREFIX}/bin/arxos-run-tool"
}

say "ARX ${VERSION} installer"
say ""
say "This installer supports two installation modes:"
say "  1) Prebuilt GitHub release binary (recommended)"
say "  2) Build from the current source repository"
say ""
say "Both modes provision the ARX runtime foundation, including sudo-rs."
say ""

if [ -z "$MODE" ]; then
  if [ -t 0 ]; then
    printf 'Select installation mode [1=binary, 2=source]: '
    read -r choice
    case "$choice" in
      1) MODE=binary ;;
      2) MODE=source ;;
      *) echo "ARX installer: invalid selection" >&2; exit 2 ;;
    esac
  else
    MODE=binary
  fi
fi

install_sudo_rs
case "$MODE" in
  binary) install_binary ;;
  source) install_source ;;
esac

say "[ARX] verifying installation"
"${PREFIX}/bin/arx" --version
"${PREFIX}/bin/arx-core" --version 2>/dev/null || true
say "[ARX] installation complete"
