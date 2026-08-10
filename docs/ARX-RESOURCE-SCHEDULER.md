# ARX Resource-Aware AUR Scheduler

The scheduler prevents parallel AUR builds from exhausting RAM, CPU or disk.

## Inputs

- CPU count from `nproc`
- `MemAvailable` from `/proc/meminfo`
- free disk space from `df -Pm`
- configurable per-build RAM estimate
- configurable maximum build concurrency

## Policy

`recommended_jobs = min(cpu_limit, ram_available / estimated_build_ram)` with a hard minimum of one job when disk space is sufficient.

The scheduler must refuse to start new work when free disk space falls below the configured safety threshold. It must not delete caches automatically to make room.

## Environment

- `ARX_CPU_JOBS`: CPU concurrency ceiling
- `ARX_MAX_JOBS`: absolute build concurrency ceiling
- `ARX_MAX_RAM_MB`: optional RAM budget
- `ARX_BUILD_RAM_MB`: estimated RAM per build
- `ARX_MIN_FREE_MB`: minimum free disk space

This is deliberately conservative. Package-specific resource hints can be added later from observed build history.
