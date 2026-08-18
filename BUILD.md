# ARX Package Manager — Developer Build & Architecture Guide

> **Private maintainer/developer documentation.** This document describes ARX from the implementation, build, testing, profiling, release, and maintenance perspective. Public users should use `README.md`, `arx --help`, and `arx help <command>` instead.

## 1. What ARX is

ARX is the native Rust package-management core for ARXOS. It is designed as a fast frontend/orchestration layer around Arch Linux's native `libalpm` package database and transaction machinery, with an AUR layer for discovery and source-package workflows.

The core rule is:

**Performance is a requirement; correctness is non-negotiable.**

ARX must never trade package identity, version, repository/source, dependency, signature, transaction, or filesystem accuracy for a benchmark improvement.

## 2. Repository structure

```text
arx/
├── arx-core/
│   ├── Cargo.toml
│   └── src/
├── tests/
├── .github/workflows/
├── install.sh
├── arx-front
└── README.md
```

`arx-front` is the compatibility/dispatch layer. `arx-core` is the native Rust/libalpm implementation. `install.sh` is the binary-first installation entry point.

## 3. Core components

### CLI and dispatch

The frontend accepts pacman-style short forms and explanatory/full forms. Examples:

```text
arx -S package
arx -Sync package
arx install package

arx -Rns package
arx -Remove --recursive --nosave package
arx remove --recursive --nosave package
```

Short and full spellings must resolve to the same semantic operation. Unknown arguments must be preserved rather than silently rewritten.

### libalpm integration

`alpm` provides the native Arch package database and transaction interface. ARX should delegate package transaction semantics to libalpm rather than implement a competing transaction engine.

This preserves Arch semantics for dependencies/conflicts, databases, transactions, hooks, signatures, package installation/removal, and filesystem conflicts.

### pacman configuration

`pacmanconf` and `alpm-utils` consume the existing Arch package-management environment rather than inventing an incompatible repository format.

### Repository synchronization

Repository synchronization uses bounded concurrency where network work can safely overlap. Package transactions remain serialized through libalpm.

### Unified search

Official repository and AUR discovery are separate sources. Results must preserve source classification and exact package metadata. Official packages should be preferred for exact official matches; AUR results must never masquerade as official metadata.

### AUR

The AUR layer provides search, metadata, source retrieval, PKGBUILD/build workflows, and eventual installation of built packages through libalpm. AUR operations remain explicitly distinguishable from official repository operations.

### Privilege handling

ARX starts unprivileged. Read-only commands such as query/search/info must not require sudo. Privilege escalation occurs only when a protected system operation actually needs it, as late as practical in the transaction lifecycle.

## 4. Build environment

The authoritative development environment is Arch Linux or an Arch-compatible container.

Typical dependencies:

```bash
pacman -S --needed base-devel git rust cargo clang pkgconf pacman
```

The libalpm development environment must be available because the Rust binding uses Arch's package-management library. Clang/Bindgen tooling is required when bindings are generated.

Verify the environment:

```bash
rustc --version
cargo --version
clang --version
pkg-config --modversion libalpm
pacman --version
```

CI must use the declared Rust requirements in `arx-core/Cargo.toml` and an Arch-native environment for package-manager validation.

## 5. Local build

From the repository root:

```bash
cd arx-core
cargo generate-lockfile
cargo build --release
```

The release profile is intentionally optimized:

```text
opt-level = 3
lto = true
codegen-units = 1
strip = true
panic = abort
```

Do not change release settings without a benchmark and correctness comparison.

## 6. Development build

For rapid iteration:

```bash
cd arx-core
cargo check
cargo test
cargo build
```

Release builds are mandatory for performance measurements. Debug builds are not valid production-performance baselines.

## 7. Test strategy

### Unit tests

Validate parsing, normalization, source classification, result merging, deduplication, ranking, and helper logic.

### Compatibility tests

Compare ARX with pacman/libalpm using semantic fixtures. Do not compare only exit codes. Where meaningful, compare:

- package names
- versions
- repositories/sources
- dependency sets
- transaction plans
- filesystem effects
- signature/verification outcomes
- stable stdout/stderr behavior

### CLI spelling tests

These spellings must be equivalent:

```text
-S       == -Sync       == --sync
-R       == -Remove     == --remove
-U       == -Upgrade    == --upgrade
-Q       == -Query      == --query
-F       == -Files      == --files
-D       == -Database   == --database
-T       == -Deptest    == --deptest
-V       == -Version    == --version
```

The test must also verify that trailing options and package targets survive normalization unchanged.

### Performance tests

Benchmark ARX against pacman, yay, and paru inside the same Arch environment and against the same workload. Report latency, result count, correctness, and peak RSS.

## 8. Benchmark rules

Never compare a debug ARX build with release pacman or AUR helpers.

Record at minimum:

```text
command
mean latency
median latency
p95/p99 when available
peak RSS
result count
source classification
```

A fast result that is incomplete or incorrect is a failed benchmark.

## 9. Profiling

Profile the real CLI path. Ensure arguments are placed correctly before measuring. A run that accidentally treats `--no-interactive` or another option as the query is invalid and must not become a performance baseline.

Use separate timing boundaries for:

```text
CLI parsing
configuration loading
ALPM initialization
sync database loading
actual database search
AUR network request
result normalization
sorting/deduplication
rendering
```

This prevents initialization cost from being confused with search cost.

## 10. Performance hot paths

Prioritize measured hotspots:

1. repeated libalpm/config/database initialization
2. unnecessary database loading
3. unnecessary allocations and string normalization
4. result cloning
5. sorting/deduplication
6. HTTP/TLS/DNS setup for AUR requests
7. unnecessary process spawning
8. rendering only if profiling proves it matters

Every optimization needs a before/after benchmark and correctness test.

## 11. Memory discipline

The target for ordinary read/search operations is approximately pacman-level RSS. Avoid duplicate long-lived ALPM handles, unnecessary metadata cloning, unbounded result collections, duplicate HTTP clients, and repeated process startup.

A memory optimization that causes stale, incomplete, or incorrect metadata is rejected.

## 12. Live help architecture

Help is part of the product API:

```bash
arx --help
arx help
arx help install
arx help remove
arx help sync
arx help query
arx help search
arx help aur
arx help mirrors
```

Each command's help should explain what it does, what it does not do, short/full syntax, relevant options, privilege behavior, pacman equivalence where applicable, and examples.

Help must be cheap. `arx --help` and `arx help <command>` must not initialize libalpm, load package databases, or contact the AUR unless a future help topic explicitly requires runtime-generated information.

Command metadata should have one source of truth so generated/live help and documentation cannot silently diverge.

## 13. Pacman compatibility policy

ARX is intended to cover the complete practical pacman package-management surface. Compatibility should be implemented through libalpm wherever possible.

Target areas include:

- sync/install
- remove
- upgrade/local package installation
- query
- files/ownership
- database operations
- cache management
- dependency tests
- repository synchronization
- mirror/configuration handling
- hooks
- signatures/keyrings
- package verification
- transaction flags
- ignore/hold behavior
- local and remote package handling

Command aliases alone are not compatibility. CI must verify semantic behavior.

## 14. AUR compatibility policy

ARX should provide the discovery/build capabilities users expect from AUR helpers while retaining official repository semantics.

AUR results must be explicitly labeled. Similar package names should be deterministic and numbered when interactive selection is enabled. Built packages must enter the final system through the normal libalpm installation path.

## 15. Build artifacts and releases

Release builds are produced by GitHub infrastructure. Normal users receive a verified prebuilt binary so they do not need Rust, a compiler, Bindgen, or dependency compilation.

`install.sh` is binary-first and may expose version/prefix overrides. Developers retain a manual source-build path.

Version `0.1.0` currently targets `x86_64-unknown-linux-gnu`; additional architectures require dedicated Arch-native CI and validation.

## 16. CI requirements

CI must run in an Arch environment and validate:

1. environment setup
2. dependency resolution
3. formatting/linting where configured
4. Rust unit tests
5. release build
6. CLI smoke tests
7. short/full command equivalence
8. pacman compatibility fixtures
9. AUR fixtures/mocks
10. benchmark
11. RSS measurement
12. release artifact generation

GitHub Actions workflows using Node must use Node 24.

## 17. Safe development rules

Never run destructive package transactions against a developer workstation during tests. Use an isolated Arch container/VM and disposable package databases for transaction tests.

Read-only tests may use the host package database only when explicitly configured. Benchmarks must record the package database and environment state.

## 18. Change acceptance checklist

Before merging a package-manager change:

- [ ] short/full syntax remains equivalent
- [ ] help text is accurate
- [ ] no unnecessary sudo prompt
- [ ] official package source remains accurate
- [ ] AUR source remains accurate
- [ ] package version is accurate
- [ ] dependencies are accurate
- [ ] signatures are not bypassed
- [ ] transaction semantics remain libalpm-compatible
- [ ] unit/compatibility tests pass
- [ ] performance benchmark passes
- [ ] memory regression is acceptable
- [ ] release build succeeds
- [ ] CI artifact is reproducible

## 19. Maintainer principle

The package manager has two absolute priorities:

**1. Surgical correctness.** Never install, remove, upgrade, classify, or report the wrong package.

**2. Extreme performance.** Once correctness is established, remove every unnecessary allocation, process, database initialization, network handshake, and serialization point that profiling identifies.

Performance is King, but incorrect package information makes performance worthless.
