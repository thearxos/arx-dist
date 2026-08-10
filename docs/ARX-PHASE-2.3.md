# ARX Phase 2.3

Phase 2.3 adds two user-facing/core resolver behaviors:

## Exact package selection

When a query returns multiple packages, ARX displays the exact package names returned by the resolver and lets the user select by number. Multiple numbers and ranges are accepted. A unique match is selected without an unnecessary prompt.

The selected package name is preserved unchanged into the transaction journal and resolver, avoiding alias/label mismatches.

## Dependency DAG

AUR/repository dependencies are represented as a directed graph. A package becomes runnable only after all of its dependencies are complete. Independent branches can therefore enter the Phase 2.2 resource-aware worker pool concurrently.

Cycles or missing dependencies fail explicitly rather than being scheduled incorrectly.

The intended pipeline is:

query -> exact-name selection -> dependency graph -> DAG-ready nodes -> resource scheduler -> build workers -> atomic install transaction.
