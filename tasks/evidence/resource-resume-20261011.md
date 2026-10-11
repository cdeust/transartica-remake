# Resource recovery, 11 October 2026

The owner reported a machine crash and requested bounded local work, removal of obsolete temporary files, and GitHub storage for publishable deliverables. The crash cause is unknown.

The previous local check runner monitored only its parent and could leave child processes running after the parent exited. The regression probe reproduced that leak. The corrected runner serializes checks across repository worktrees, samples summed RSS for its process group, lowers scheduling priority before launch, retains a bounded diagnostic preview, and cleans up its group on timeout, failure or interruption.

The existing 768 MiB default, 1 GiB maximum and 15-second default are retained from the owner's earlier local-check protocol. The 0.2-second sampling period and 2-second termination grace retain the earlier runner settings. The new diagnostic retention limit is 4096 bytes, reusing the old read-chunk size; the old transcript accumulated without a bound. These are operating budgets, not a claim of optimal settings. RSS sampling can miss short peaks; it is not a kernel memory limit or a CPU cap. Commands must remain in their launch process group. Unrelated applications are outside this guard's scope.

Validation: all 15 process tests pass in 5.527 seconds. macOS time reports 30,834,688 bytes maximum resident set size for the test command; this is not an aggregate peak for all descendants. Six deliberately broken variants were detected by their regression tests. Independent review found and corrected setup, interruption and stale-snapshot races. Source and craftsmanship checks report zero errors and zero warnings. Five existing world-plan data tests also passed under the guard. No Godot render or import was launched during this recovery.

Disk cleanup removed 633 unreferenced intermediate captures and 11 extracted build files whose payloads matched retained ZIP archives. Total removed: 1,891,677,010 logical bytes. The filesystem's immediate available-space increase was 1,849,716 KiB. A separate reviewer verified capture retention, including number ranges embedded in prose. Checks before deletion included tracked-file exclusion, hashes, unchanged file identities and no open handles. Existing capture references, states, saves, archives and unpublished work remain available locally. The detailed manifests stay local.

Available space after deletion was 39,301,084 KiB, about 40.24 GB. The owner's approximate 100 GB target is not met. System swap usage was subsequently measured at 39,555.06 MiB. No shared service was stopped without permission.

The full-world artwork remains unfinished and rejected for activation. This guard and cleanup do not establish visual acceptance, 140 fps, a Windows runtime result or a completed player campaign.
