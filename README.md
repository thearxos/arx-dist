# arx, the ArxOS package manager

`arx` is the single package manager for ArxOS. It does everything the standard Arch
tools do, and the things you would normally reach for a helper to do, in one command
that is fast, safe, and clear.

It is **pure Rust**. `arx` talks to libalpm in-process instead of spawning `pacman`
for every query, so the read paths are immediate. On the ArxOS reference VM (median of
7 runs) a repository search returns in **10 ms** against pacman's **399 ms**, and a
package info lookup in **16 ms** against **381 ms**: no process to spawn and no
database to re-read each time.

**Performance is the priority. Accuracy is never traded for it.** Package names,
versions, sources, dependencies, and transactions are always exact.

## What it does

- **Its own transaction engine.** Installs, removals and upgrades run through libalpm
  in-process, so dependency resolution, conflicts, signatures and hooks are decided
  exactly as pacman decides them. The downloads are arx's own: every file resumes where
  it stopped, tries every mirror, keeps going while bytes still arrive on a slow link,
  and runs sandboxed as the `alpm` user (Landlock and seccomp, as pacman 7 does).
  Ctrl-C stops a download cleanly and changes nothing; once packages are being written,
  arx finishes first, because a stopped upgrade can leave a system that cannot boot.
  After an upgrade it tells you if a reboot is needed and which services still run
  the old libraries.
- **Official repositories and the AUR in one tool.** No second helper to install.
  `arx` searches, builds, and installs from both, and always tells you which source a
  package comes from. AUR build files are scanned for risky patterns first, and it
  refuses to auto-build anything that looks unsafe. Build dependencies and the built
  packages go through the same engine, and no `-debug` package is built.
- **Ask for several packages at once and arx sorts them.** It shows what is in the
  repositories, what needs building from the AUR, and what was not found, then lets
  you proceed with all, pick a few, or stop.
- **Installs more than Arch packages.** It reads `.deb`, `.rpm`, `.AppImage`, and
  archive files by their magic bytes, not their extension, maps their dependencies to
  Arch packages (including resolving a library by its soname through the files
  database), and installs them cleanly. Maintainer scripts that run as root are scanned
  and refused if they are dangerous.
- **Native kernel management.** `arx kernels list`, `arx kernel install <flavor>`, and
  `arx kernel remove <flavor>` handle the ArxOS kernels, verified against the published
  manifest with a fail-closed checksum, and never let you remove the running or the
  last kernel.
- **A dependency doctor so a tool never lands with a missing package.** `arx doctor`
  checks the database with libalpm's own dependency check (the one `pacman -Dk` uses),
  scans every installed ArxOS tool for a runtime library the loader cannot find and
  installs the owning package, and removes write access from any system directory
  that its package does not grant.
- **Repairs itself.** Keyring, mirror, lock, and database problems are classified and
  fixed on their own, with a bounded retry, so a routine update rarely stops with an
  error. A lock held by another running operation is waited for, never deleted.
- **One update for everything.** The system, the kernel, and the ArxOS tools update
  together; `arx` keeps itself current and re-applies ArxOS hardening after an upgrade
  so a package update can never silently revert it.
- **Full pacman flag compatibility.** `-S`, `-R`, `-Q`, `-U`, `-F`, `-Ss`, `-Si`,
  `-Syu`, `-Sc`, `-Qo`, `-Ql`, and more are accepted directly, alongside readable
  aliases (`install`, `remove`, `search`, `info`, `upgrade`, `owns`, `files`).

## Community catalog

`arx pub list`, `arx pub search <text>`, and `arx pub info <name>` read the
packaged `/usr/share/arxos/community.db` without a network request. If that
snapshot is missing, arx fetches the public catalog. An unreadable, non-UTF-8,
or oversized snapshot returns an error instead of silently fetching a replacement.

The catalog is a packaged snapshot, not a live feed. `ARXOS_COMMUNITY_DB=<URL>`
explicitly selects another catalog source and takes precedence over the snapshot.
Neither path writes a cache or requires sudo. Catalog reads are limited to 4 MiB.
Offline browsing does not make package installation offline; community installation
still requires opt-in and access to its source and dependencies.

## Install

```bash
sudo bash install.sh
```

Fresh ArxOS systems already have it, and it updates itself with everything else.

## Updates that cannot break arx

arx is how every fix reaches an ArxOS machine, so it is built never to strand one:

- arx carries the shared libraries it needs in `/usr/local/lib/arx`. A system upgrade that changes
  a library's version cannot stop arx from starting.
- A new arx runs from a staging copy before it replaces the old one. If the installed copy does not
  start, the previous one is put back.
- arx updates itself before any other tool.
- After every package transaction a hook checks that arx starts. If it does not,
  `sudo arx-rescue` reinstalls it from the ArxOS release index with only curl, sha256sum, tar and
  zstd, and the archive is checked before anything in it runs.

## Usage

```bash
arx search <name>          # search the repos and the AUR
arx install <name|file>    # from the repos, the AUR, or a .deb/.rpm/.AppImage
arx upgrade                # the system, the kernel, and the ArxOS tools, together
arx kernels list           # installed and available ArxOS kernels
arx doctor                 # database check, dependency healing, directory permissions
arx --help                 # everything else
ARX_ENGINE=pacman arx ...  # run transactions with the pacman binary instead of the engine
```

---

<sub><b>arx</b> is part of the <b>ArxOS</b> project, built by <b>Stingray Labs</b>.</sub>
