# ARX Phase 2.2

Phase 2.2 connects resource scheduling to actual AUR build workers.

## Flow

AUR dependency resolution -> bounded queue -> package worker -> resource scheduler -> makepkg -> journal/resource history.

Each worker acquires a package-specific lock and chooses a concurrency level from the scheduler. Build state remains package-scoped so a failed worker can be retried without restarting completed packages.

The resource log records timestamp, package, observed memory pressure and free disk space. The historical estimator can use prior observations to improve future per-package RAM estimates.

This phase deliberately keeps package execution inside makepkg and retains Arch verification semantics.
