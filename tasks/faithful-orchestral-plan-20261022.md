# Faithful orchestral score implementation plan

Goal: replace the five invented compositions with nine orchestral arrangements
derived from the historical score events.

Architecture: execute the original Amiga T.X player and sample decoder
through the pinned Musashi CPU adapter. Render recorded orchestral samples from the observed
event timeline. Keep native cue routing and package verified masters with their
provenance. No note recognition from a mixed recording is used as the score.

Spec: faithful-orchestral-design-20261022.md. Owner selected faithful orchestration.
Technology: original 68000 execution, Python/NumPy offline rendering,
existing VSCO2 CE recordings, native C++/SDL runtime.

## Global constraints

Worktree and scratch are owned and registered. Preserve other worktrees.
Run expensive operations serially, with the existing 1 Gio process-group guard.
Preserve all nine distinct cue identities and their original timing.
Record unsupported source effects explicitly and resolve their semantics before
claiming complete source fidelity. Do not invent a replacement melody.

## Tasks

- [x] Extract the nine resources with source addresses, order tables and raw rows.
  Add a bounded observer in tools/faithful_score/ against a copied ALIS source.
  Record every note trigger, per-tick frequency/volume and source-end event at
  generated-sample offsets. Keep source links and hashes in the trace header.
  Verify duplicate triggers survive, tempo changes remain exact and source
  bytes match the original resource. Compare observed cycle boundaries with
  reference-private/audio/music.json. Preserve raw effects 4/E for review.
- [x] Calibrate original tonal sample roots using their PCM and source playback
  rate. Preserve ambiguous or polyphonic samples as explicit unresolved inputs.
  Resolve them from source measurements before assigning orchestral pitches.
- [x] Render nine masters from the source timelines using author SFZ roots.
  Test event preservation, repeated notes and termination of source voices.
  Verify boundaries for cyclic cues and exact one-shot completion. Compare
  independent render hashes and check clipping. Artistic listening acceptance
  is separate from measured fidelity and actual device playback.
- [x] Replace the selected orchestral resources and update provenance/licensing.
  Keep each cue distinct in music.json. Add a regression that detects the old
  many-to-one substitutions. Verify C++ audio tests and packaging closure.
- [ ] Build a complete macOS package and test actual playback/scene transitions.
  Preserve evidence, then commit/push under existing publication authorization.
  Verify remote SHA and clean owned temporary files after preserving deliverables.
- [ ] Create a Windows setup.exe with bundled runtime dependencies and resources.
  Verify installation and executable launch on a Windows runner.
- [x] Create a macOS installation DMG containing the rebuilt application.
  Mount it, install the application outside the build tree and verify its launch.

## Resumed session contract

Owner request: "you were working on finishing the reorchestration of the music without inventing anything, just following the exact same partition but making it an orchestral version. Continue and finish this step as a resumed session. And then when the reorchestration is done, create a setup.exe for windows. And an installation dmg for mac."

| Reference | Artifact | Evidence |
|---|---|---|
| Same partition | Nine original-CPU traces in effects-review/amiga-final-v2/*-final | amiga-extraction-validation-20261022.json |
| Resumed orchestration | tools/faithful_score and calibration-reviewed-all.json | Uncommitted work retained on fix/faithful-orchestral-score |
| Complete executables | native-game/CMakeLists.txt and native-game/packaging | Resource delivery commit 00038e3 |

The delivered music currently consists of five newly authored compositions.
The goal is nine source-derived orchestral masters followed by both installers.
Rights-holder research follows game completion. Existing AGENTS.md and FIDELITE.md
remain binding. Planning and external verification govern execution: compare source
events and measured pitches, then inspect built artifacts and native launch results.

## Review focus

Repeated identical notes must not disappear when instrument and period match.
Effects and changes of tempo must survive empty pattern rows.
No rounded-MIDI conversion may silently transpose a historical sample.
Loop boundaries must include ongoing voices, without duplicating the opening.
A restored save must resolve its cue to the corresponding faithful arrangement.

## Later task

Research current Transarctica rights holders after the full game/executable is
complete, as requested. Do not infer rights ownership from repository licensing.
