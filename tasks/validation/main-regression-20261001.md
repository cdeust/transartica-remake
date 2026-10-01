# Updated main regression review

Raw request: "Opus did the work and main was updated, since you finished off the game I'd like you verify nothing broke"

| Reference | Artifact | Evidence |
|---|---|---|
| Updated main | origin/main 6dca2521c360a3bc63a9bc4b1b1eed5e9f54908a | Fresh git fetch; PR #8 merge |
| Opus work | 34147f3, 2ff1eb7, ca198ac, 5b0db5e, bc3a1de | git log 79c80b2..origin/main |
| Previous game | 79c80b28a5a7a9bf227269dcceac4b015b11e182 | Previous published main; local checkout |
| Regression coverage | game/test.sh, tests/, native review fixtures | Repository runner and requires-native-renderer markers |

Symptom: the owner requests verification after main received the motion-design changes; no specific new failure is reported.
Goal: verify the exact merged source against automated regression suites and native flows, recording failures and verification limits.
Non-goals: new artistic direction, changes to accepted cadence, remote publication.

Strategy: context_engineering and verified_reasoning under /refine. External signals are test exit codes, PASS/error logs, native snapshots, exact reviewed SHA and independent static findings.

Plan:

- [x] Fetch exact main and preserve existing local work.
- [x] Extract its committed tree into a registered isolated snapshot.
- [x] Run full Godot and Python inventory.
- [x] Verify native combat/launch and save/load/reset effects paths.
- [x] Review changed scripts independently.
- [x] Preserve results and dispose owned scratch after stopping tests.

Owned scratch: `.cache/disk-hygiene-am3agoxk`. Historical private data and toolchain are linked; no data preparation through those links. Current main checkout remains unchanged except this review documentation.

## Results

Remote main still equals 6dca2521c360a3bc63a9bc4b1b1eed5e9f54908a at the final ls-remote check. All 278 merged script/shader files in the tested snapshot match their Git blobs. Production code was not edited or published.

Python: 33 tests pass. Current Godot inventory contains 63 suites including the core runner. First pass: 62 pass; test_boudoir fails its boiler-overload assertion. The runner correctly exits 1. Every remaining suite was executed sequentially with the runner's renderer requirements; none was skipped. The unchanged boudoir fixture passes on baseline 79c80b2 and on three subsequent updated-main runs. The original intermittent failure is retained, not overwritten or declared resolved.

Full campaign route passes: 10657 advance calls, 1713 entered cells, day23, fuel1067. The Mausoleum disk save/reload yields the same deterministic final outcome. Other passing suites include native controls, atomic save rejection, audio resume, source combat and launcher rules, renderer geometry and cadence independence.

The added isolated ignition lifecycle fixture passes 55 native assertions, including actual P pause, active-ignition save/restore, stale shader surface clearance and new-game cleanup. No script/shader error appeared in that run. This fixture extends the existing review only in the disposable snapshot; its exact source is preserved below.

## Confirmed defects

1. **Moving wagon selection, P2.** `game/scripts/tactical_scene.gd:327` uses raw state.offsets for selection. Display geometry uses shown_offset through `tactical_effects_geometry.gd:19`. Native reproduction at logical (193.5,50.04182) visibly targets wagon index2 but selects index1. Introduced by the new presentation interpolation in 34147f3 without matching input conversion. Accept correction when real clicks at moving body boundaries select the displayed wagon, with pause and camera scroll also checked.

2. **Destruction texture/crop mismatch, P2.** `tactical_scene.gd:151-156` primes the health0 cache from the original sprite; `tactical_effects_geometry.gd:13-15` later supplies wagon25 wreck bounds. `tactical_materials.gd:10-13` reuses the cache keyed only by side/wagon/health. A real model-planted charge destroys enemy wagon7: cached texture size637×204, requested wreck source667×220. Crop coordinates therefore belong to different pixels. This path came from my earlier ca1ece1 implementation, before the Opus motion commit. Accept correction when real destruction, rendering and support-profile lookup agree on the selected source texture; manually assigning health before a draw does not exercise the poisoning path.

3. **Partial shake transform, P2, static finding.** `tactical_scene.gd:177-185` establishes a shaken world transform. Player wagon labels at260 invoke `_label`, which invokes `OriginalScreen.text_at`; `original_screen.gd:43-46` resets the draw transform to the unshaken canvas. Subsequent geometry/common effects lose the shake while the additive layer at208-213 retains it. Input also ignores shake. Static review confirms the transform sequence; this review did not add a dedicated native shake assertion. Accept correction when body, weapon, flash and actor layers retain the same transform throughout a blast, with hit testing registered to the presented scene.

The native reproduction exits1 because it confirms defects1 and2. That expected diagnostic failure is separate from the existing suite's intermittent boiler failure.

## Measured effects cost

Existing native benchmark, Apple M4, four dense fields, 128 emitters and 2048 sparse particles, 120 advancing frames: CPU draw median3.764ms, p9510.698ms, maximum15.322ms; update median0.302ms, p952.067ms, maximum2.654ms. GPU frame time is excluded. This reproduces the tail-cost concern already recorded by Opus; it is not evidence of a stable whole-game frame budget.

No concrete source-state/RNG or campaign/save regression was found in the inspected diff and passing fixtures. This is bounded verification, not proof that every animation is correct. Windows execution and the current exported app were not tested in this source review.

## Evidence

[Preserved directory](main-regression-20261001/) contains the failing first pass, three successful boudoir repeats, baseline log, inventory JSON, source-integrity JSON, native reproduction capture and log, exact added reproduction/lifecycle fixtures and CPU benchmark JSON/log. The full original per-suite logs remain in the main checkout's review directory. Independent reviewer main_static_review examined the fetched commit read-only.

Cleanup retains this evidence and removes only the registered source snapshot and its generated imports/captures after verifying no owned test remains. Existing worktrees and unrelated files are protected.

Registered disposal succeeded and the scratch path is verified absent. Its
pre-disposal disk usage was966512KiB. Another Claude session was running tests
from the living-effects worktree; those processes and that checkout were left
untouched.
