# Codex cleanup probe

This draft PR exercises the native Codex disk-hygiene workflow. It changes no
game behavior and is not intended to merge.

Acceptance requires the pushed commit to remain on GitHub while the registered
local worktree and branch are removed automatically. The test also checks native
SessionEnd and SessionStart delivery and whether pending session files are removed
only after Cortex finishes processing them.

Results are recorded separately in the main checkout under tasks/validation.
The existing game edits and the earlier cleanup test PR are outside this test.
