# arx, the ArxOS package manager

`arx` is the single package manager for ArxOS. It does everything the standard Arch
tools do, and the things you would normally reach for a helper to do, in one command
that is fast, safe, and clear.

It is **pure Rust**. `arx` talks to libalpm in-process instead of spawning `pacman`
for every query, so the read paths are immediate. On the same machine a repository
search returns in about **14 ms** against pacman's **413 ms**, and a package info
lookup in about **11 ms** against **395 ms** — roughly **30x** faster on the hot path,
because there is no process to spawn and no database to re-read each time.

**Performance is the priority. Accuracy is never traded for it.** Package names,
versions, sources, dependencies, and transactions are always exact.

## What it does

- **Official repositories and the AUR in one tool.** No second helper to install.
  `arx` searches, builds, and installs from both, and always tells you which source a
  package comes from. AUR build files are scanned for risky patterns first, and it
  refuses to auto-build anything that looks unsafe.
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
  checks the database, then scans every installed ArxOS tool for a runtime library the
  loader cannot find and installs the owning package automatically.
- **Repairs itself.** Keyring, mirror, lock, and database problems are classified and
  fixed on their own, with a bounded retry, so a routine update rarely stops with an
  error.
- **One update for everything.** The system, the kernel, and the ArxOS tools update
  together; `arx` keeps itself current and re-applies ArxOS hardening after an upgrade
  so a package update can never silently revert it.
- **Full pacman flag compatibility.** `-S`, `-R`, `-Q`, `-U`, `-F`, `-Ss`, `-Si`,
  `-Syu`, `-Sc`, `-Qo`, `-Ql`, and more are accepted directly, alongside readable
  aliases (`install`, `remove`, `search`, `info`, `upgrade`, `owns`, `files`).

## Install

```bash
sudo bash install.sh
```

Fresh ArxOS systems already have it, and it updates itself with everything else.

## Usage

```bash
arx search <name>          # search the repos and the AUR
arx install <name|file>    # from the repos, the AUR, or a .deb/.rpm/.AppImage
arx upgrade                # the system, the kernel, and the ArxOS tools, together
arx kernels list           # installed and available ArxOS kernels
arx doctor                 # database check + dependency healing
arx --help                 # everything else
```

---

<sub><b>arx</b> is part of the <b>ArxOS</b> project, built by <b>Stingray Labs</b>.</sub>
