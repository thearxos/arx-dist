# ARX — Fast Arch Package Manager for ARXOS

ARX is the native package manager for ARXOS, built in Rust around Arch Linux's native `libalpm` package-management engine.

**Performance is King. Accuracy is non-negotiable.**

ARX is designed to combine pacman-compatible package transactions with a fast, integrated AUR workflow while keeping memory usage low and command behavior understandable.

## Quick start

```bash
arx --help
arx help
arx help install
```

Normal users install the prebuilt release binary; developers can build from source using the private maintainer build guide.

## Commands — short and full forms

ARX accepts pacman-style short commands and readable full forms.

```text
arx -S package
arx -Sync package
arx --sync package
```

These use the same sync/install operation.

```text
arx -R package
arx -Remove package
arx remove package
```

These use the same removal operation.

Other compatible forms include:

```text
-S / -Sync / --sync
-R / -Remove / --remove
-U / -Upgrade / --upgrade
-Q / -Query / --query
-F / -Files / --files
-D / -Database / --database
-T / -Deptest / --deptest
-V / -Version / --version
```

## The important distinction: `-S` vs `install`

```bash
arx -S firefox
```

Pacman-compatible sync/install operation. It uses the configured repository databases according to pacman's `-S` semantics.

```bash
arx install firefox
```

Convenient ARX install operation using the current package databases. It does not intentionally force a repository refresh first.

For an explicit refresh and full system upgrade:

```bash
arx -Syu
```

or the readable form:

```bash
arx -Sync --refresh --sysupgrade
```

ARX deliberately documents these differences instead of pretending that every similarly named command has identical semantics.

## Removing packages

Simple removal:

```bash
arx -R package-name
arx -Remove package-name
arx remove package-name
```

Recursive dependency cleanup and configuration-file removal:

```bash
arx -Rns package-name
arx -Remove --recursive --nosave package-name
arx remove --recursive --nosave package-name
```

This is the easy ARX equivalent of the common shell-heavy workflow:

```bash
sudo pacman -Rns "$(pacman -Qq package-name)"
```

For exact package removal, command substitution is normally unnecessary with ARX.

## Querying installed packages

```bash
arx -Q package-name
arx -Query package-name
```

Check whether the package is installed and display local package information.

Useful pacman-compatible query patterns include:

```bash
arx -Qe
arx -Qs pattern
arx -Qo /path/to/file
arx -Ql package-name
```

## Search

```bash
arx search package-name
arx -Search package-name
```

ARX can search official repositories and AUR sources while explicitly identifying where each result comes from.

AUR results are categorized as AUR packages rather than being presented as official repository packages. Similar package names can be presented with deterministic numbered choices for interactive selection.

## Package information

```bash
arx info package-name
arx -Info package-name
```

Displays package metadata such as version, architecture, repository/source, dependencies, size, and installation state.

## Files and ownership

```bash
arx -F package-name
arx -Qo /path/to/file
```

Use these to inspect package files and determine which installed package owns a filesystem path.

## Mirrors and synchronization

ARX uses Arch-compatible repository configuration and libalpm semantics while allowing the network synchronization layer to use bounded concurrency where safe.

Mirror-related commands are exposed through ARX's command/help interface. Package transactions remain serialized through libalpm to preserve transaction correctness.

## AUR

ARX integrates AUR discovery and source-package workflows into the same package-manager experience.

AUR functionality includes:

- search
- package information
- source/PKGBUILD retrieval
- dependency-aware build planning
- package building
- verification
- installation through libalpm
- upgrade detection
- similar-package discovery
- deterministic numbered selection

Official repository packages and AUR packages remain explicitly distinguishable.

## Privilege model

ARX normally starts without `sudo`.

Read-only operations such as:

```bash
arx -Q firefox
arx search firefox
arx info firefox
```

do not need administrator privileges.

When an operation actually modifies protected system state, ARX requests elevation at the point it is required.

This avoids making users run the entire package manager as root while keeping package transactions protected.

## Accuracy policy

ARX is designed around native Arch package semantics rather than a custom approximation.

Where package transactions are concerned, libalpm remains the authority for:

- dependency resolution
- conflict handling
- package databases
- transactions
- hooks
- signatures
- package installation/removal
- filesystem conflict handling

Performance optimizations must not alter those semantics.

## Performance

ARX separates measurable concerns:

```text
CLI parsing
    ↓
configuration / ALPM setup
    ↓
official repository search
    ↓
AUR discovery when required
    ↓
result normalization
    ↓
transaction planning
    ↓
libalpm transaction
```

Network work may be concurrent where safe. Package transactions remain serialized through libalpm.

ARX benchmarks are run in Arch environments against pacman, yay, and paru with memory usage measured separately from latency.

## Development

The Rust core is located in `arx-core/`.

```bash
cd arx-core
cargo check
cargo test
cargo build --release
```

For maintainer architecture, environment setup, release builds, testing, profiling, compatibility work, and CI details, use the **private `BUILD.md` maintainer guide**.

## Releases

Version `0.1.0` is designed for Arch Linux x86_64 and is distributed as a prebuilt native binary so normal users do not need to compile ARX.

The release/build pipeline is designed to use GitHub infrastructure for reproducible Arch-native builds and release artifacts.

## Project principle

ARX has one rule that overrides every benchmark:

> **A package manager that is fast but gives inaccurate package information is not fast. It is wrong.**

The project therefore optimizes only after correctness is established and measured.
