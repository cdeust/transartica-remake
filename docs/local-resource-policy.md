# Local resources and GitHub storage

Use GitHub branches and pull requests for source changes and compact review evidence. Check the exact remote commit before treating local work as backed up. Use GitHub Releases for redistributable delivery archives and retained CI artifacts for temporary build outputs. Verify uploaded checksums before deleting a local deliverable. An upload is not proof that a build works on its target platform.

Historical game assets, derived full datasets, private data packs and builds containing them remain private. They must not enter this public repository, its releases or its public workflow artifacts. Preserve their necessary local source copy; remove a duplicate only after verifying an equivalent retained copy.

For local verification, use tools/run_map_check.py with a bounded command, for example:

    python3 tools/run_map_check.py --seconds 15 --memory-mib 128 -- python3 -c "print('bounded check')"

The shared lock allows one local check at a time. The default budget is 768 MiB and 15 seconds, with a 1 GiB maximum. The guard monitors its own process group and terminates it on failure or budget overrun. Sampling permits transient overshoot. Low scheduling priority does not cap CPU usage or protect against memory used by other applications.

Before a render, import or export, inspect host memory and available disk space. The owner requests about 100 GB available; the recovery on 11 October remained below that target. Avoid heavy local jobs while host memory pressure is unresolved. Keep screenshot capture explicit and preserve only evidence needed for acceptance or diagnosis after reviewing references.

Register disposable directories and new worktrees with the workspace disk-hygiene procedure. On completion, preserve compact review evidence, verify the remote head, stop owned test processes and remove proven disposable copies. Keep a dirty or unpublished worktree until its unique work is safely preserved. Never delete another active session's files or stop its services as part of routine cleanup.
