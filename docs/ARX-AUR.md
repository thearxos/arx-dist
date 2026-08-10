# ARX AUR and transaction recovery

ARXOS now treats the AUR as a first-class package source without requiring yay or paru at runtime.

## Flow

```text
arx
 ├─ official repository package -> arx-pacman -> pacman/libalpm
 ├─ AUR package                -> arx-aur -> AUR RPC/git -> makepkg
 └─ Weapons/category install   -> arx-recover -> arx-pacman -> pacman
```

`arx-aur` owns AUR discovery, metadata, source caching and build orchestration. `makepkg` remains the Arch-defined build boundary because a PKGBUILD is executable package-build code and replacing makepkg would create a second, incompatible Arch packaging implementation.

`arx-recover` journals transactions and classifies common failures into network, disk, cache/integrity, keyring, lock and dependency classes. Transient classes receive a bounded exponential retry. Disk failures intentionally do not trigger destructive cache cleanup.

## AUR trust boundary

AUR packages are source packages. `makepkg` executes PKGBUILD code, so ARX does not represent AUR packages as equivalent to signed repository binaries. ARX keeps a `PKGBUILD.arx-snapshot` beside the checked-out source to make the exact build recipe visible for local review.

## Performance strategy

The design avoids repeatedly spawning yay/paru. Metadata requests are direct RPC calls, AUR sources use shallow git clones and existing clones are fast-forwarded/reset to `origin/master`. The resolver delegates actual Arch dependency semantics to makepkg/pacman instead of maintaining a second dependency database.

Performance claims should be made from benchmarks, not assumptions. Future native Rust work can move the AUR RPC/cache/dependency graph into `arx-core` once the interface is stable.
