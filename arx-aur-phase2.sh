#!/usr/bin/env bash
# Phase 2 AUR build policy: faster builds without weakening Arch package verification.
set -u -o pipefail

ARX_BUILD_ROOT="${ARX_BUILD_ROOT:-${XDG_CACHE_HOME:-$HOME/.cache}/arx/aur/build}"
ARX_MAKEFLAGS="${ARX_MAKEFLAGS:-$(nproc 2>/dev/null || echo 2)}"

run_makepkg() {
  local dir="$1"; shift
  cd "$dir" || return 1

  # Never use --skipinteg, --skippgpcheck, or equivalent trust bypasses.
  # makepkg remains responsible for source hashes, PGP verification and packaging.
  export MAKEFLAGS="-j${ARX_MAKEFLAGS#-j}"
  export NINJAFLAGS="-j${ARX_MAKEFLAGS#-j}"

  # Reuse a stable compiler/package cache when supported by the toolchain.
  export CCACHE_DIR="${CCACHE_DIR:-${XDG_CACHE_HOME:-$HOME/.cache}/arx/ccache}"
  mkdir -p "$CCACHE_DIR"

  # Clean-build isolation is controlled by the caller. Do not reuse arbitrary
  # files from another PKGBUILD/source tree.
  env HOME="${HOME}" makepkg --syncdeps --cleanbuild --clean "$@"
}

case "${1:-}" in
  build) shift; run_makepkg "$@" ;;
  *) echo "usage: arx-aur-phase2.sh build <build-directory> [makepkg args...]" >&2; exit 2 ;;
esac
