# Living effects acceptance

Earlier approved main push verified at79c80b28a5a7a9bf227269dcceac4b015b11e182.
This visual iteration is local on feat/living-effects.

The full Godot runner reports63 PASS records with no script/shader errors.
All33 Python tests pass. Independent ambience review approved after correcting
current-frame attachment and successful restore/New Game transient cleanup.
Source/craft gates report zero errors and zero warnings.

The actual rebuilt macOS executable passes desktop input/save/load acceptance
and28 engine/travel effect checks with bundled resources. Artifact identities
are recorded in living-artifact-identities-20261001.json. The latter fixture is
a copy of review_engine_travel_effects.gd with output/save paths redirected to
registered scratch and an exported-executable assertion added. Two native
exported captures and both logs are retained.

The Windows EXE/PCK is exported and packaged; execution on Windows remains
unverified. Private preview packages contain historical datasets and must stay
local. The macOS application and Windows archive are retained as deliverables.

Combat-quality directional travel is feasible with new art and a matching
renderer. Uniform map scaling supplies size, but cannot supply side surfaces or
make every two-axis route horizontal. No directional travel-view migration is
implemented in this effects milestone. The optional owner preference remains
unanswered. See combat-view-feasibility-20261001.md.

The peak effects benchmark measures CPU submission and updates, excluding GPU
frame time and initial fracture masks. Renderer precision improves full-contact
correctness with a measured13microsecond median CPU difference per25vehicle pose
calculation; this is not a claimed speedup.

Cleanup verifies that native processes exited. Hash-verified redundant macOS
ZIP and unpacked Windows files removed410668647bytes. Registered artifact
scratch disposal requires evidence in the main checkout, outside all registered
worktrees. The cleanup receipt below records the actual result. The unpublished
worktree, local source checkpoint and current preview deliverables are retained.

The registered artifact scratch is confirmed absent after disposal. Its durable
main-checkout receipt is copied beside this report. All native test processes
exited; retained worktrees include other sessions and unpublished source.
