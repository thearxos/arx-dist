# ARX Phase 2: faster and safer makepkg

ARX should optimize the orchestration around `makepkg`, not replace Arch's trusted package-build semantics.

## Speed

1. **Parallel compilation**
   - Derive `MAKEFLAGS=-j$(nproc)` with a configurable cap.
   - Propagate equivalent parallelism to Ninja/CMake projects where supported.
   - Never assume every package benefits from maximum parallelism; allow package overrides.

2. **Persistent caches**
   - Keep AUR source clones and build metadata under `$XDG_CACHE_HOME/arx/aur`.
   - Use compiler caches such as ccache when installed and supported.
   - Cache AUR RPC metadata with a TTL.
   - Rebuild only when the PKGBUILD/source/dependency inputs changed.

3. **Dependency graph scheduling**
   - Resolve repo + AUR dependencies before builds begin.
   - Build independent AUR nodes concurrently, subject to CPU/RAM limits.
   - Serialize packages that depend on one another.

4. **Avoid unnecessary work**
   - Detect installed package versions before starting a build.
   - Skip a no-op upgrade.
   - Reuse an existing clean source checkout when the source revision is unchanged.

## Safety

1. **Never disable verification**
   - Do not use `--skipinteg` or `--skippgpcheck` automatically.
   - Preserve makepkg checksum and PGP verification.

2. **Sandbox the build**
   - Build as an unprivileged user.
   - Keep the build root separate from `/` and package installation paths.
   - Only escalate privileges for the final pacman installation transaction.

3. **Review PKGBUILDs**
   - Parse metadata before execution.
   - Display source URLs, checksums, dependencies and install scripts.
   - Flag suspicious constructs for explicit user confirmation rather than silently modifying them.

4. **Atomic installation**
   - Never call `pacman -U` until all requested packages have successfully built and passed verification.
   - Install the resulting package set through one controlled transaction where possible.

5. **Reproducibility metadata**
   - Record package name/version, AUR commit, PKGBUILD hash, dependency graph, makepkg version, architecture and build flags in the ARX transaction journal.

## Important boundary

`makepkg` remains the package builder. ARX owns scheduling, caching, dependency planning, recovery, auditing and transaction orchestration. This gives ARX speed without creating a second, incompatible Arch packaging implementation.
