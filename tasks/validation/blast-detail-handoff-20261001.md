# Blast and Gatling motion handoff, 1 October 2026

Artistic acceptance: OPEN. Owner reports visible animation bugs and requests an
Opus motion-design review. Feature work is frozen. Functional tests do not certify
Noita visual quality.

Base commit: ca1ece1b896a724d6c652e21020cb300924a5418. Shared registered checkout:
.worktrees/living-effects. No commit or push performed. The owned code snapshot is
SHA256 d5390bc41a05c35877ab1b0adfebd2b34f511201cc7d2b8abb8446271d07e91e.
The complete owned patch is blast-detail-owned-20261001.patch, SHA256
f5f1b14726a5c37476486dd508df875bd61323393539cf221ac2334f6c9fc298.
Per-file hashes and ownership are in blast-detail-code-manifest-20261001.json.

## Ownership and current implementation

World recovery owns living_effects.gd, living_particles.gd, blast_pixel_volume.gd,
tactical_scene.gd, tactical_weapon_motion.gd, test_blast_detail.gd,
review_blast_detail.gd and benchmark_blast_detail.gd. Root owns shared assets and
canonical wagon art. Ambience validation owns launcher/rocket modules.
Those concurrent edits are excluded from the owned patch.

The common add/advance/draw/clear/fragments API remains compatible. Explosions use
small seeded moving gas parcels rasterized into cached textures. Parcels cool
through an authored fire palette into gas; fragments cool and continue falling.
The field pitch is 0.5 logical pixels, two native pixels at combat4x. Four local
fields with64parcels each bound dense blast work. This is an authored presentation
model, not a full Noita material engine or decoded source thermodynamics.
The official [Noita FAQ](https://noitagame.com/) describes simulated materials and
rising gases; its visual detail is the reference. No Noita art is shipped.

Actual machinegun source bursts drive three narrow fast tracer streaks and four
small brass ejecta. A procedural six-barrel rig spins and recoils at the current
cropped wagon roof registration. It is temporary. Root's new authored
assets/weapons/gatling.png has NOT been integrated.

Presentation runs at fixed50Hz between the original12.5Hz combat steps.
TacticalScene calls model.advance(delta) once, preserving its original float
accumulator and random draws. Existing tick-start callbacks advance presentation
to each frame-relative model boundary; events start there, then the elapsed frame
tail advances their ages. Batched model ticks retain every presentation event.
Pause and hidden scenes freeze all presentation. A new battle clears fields/rigs.

## Native comparison and exact source proof

- [Before animation](blast-detail-before-20261001.gif)
- [Frozen current animation](blast-detail-after-20261001.gif)
- [Frozen current video](blast-detail-after-20261001.mp4)

The same source-valid cannon/machinegun and planted-charge fixture captures180
native1280x800frames at50Hz over3.6source seconds. No timed visual condition decides
PASS. frame_post_draw synchronizes every capture. ffprobe verifies180video frames
and50/1rate. Root changed canonical art during this shared iteration; compare the
weapon/charge regions rather than unrelated train art when judging these videos.

Before and final complete model JSON files are byte-identical, SHA256
bae607f4fde999441336a2bdaff64e5834e4e035820e3ceb8cf8e681fb986106.
The new timing test verifies gas motion while source ticks remain zero, pause,
correct ages for batched births, exact state/RNG equivalence to one unchanged
model advance, and matching volume/rig states at30/60/144Hz. Existing living
invariance, tactical combat, art-cache and native source-audio fixtures pass.
All five final logs were checked for ERROR and WARNING.
Source/craftsmanship gates each report0errors and0warnings for the eight owned
files. The final source edit was a provenance comment, without runtime changes.

## CPU cost and remaining concerns

The first eight-field implementation reached39.795ms initial CPU drawing.
Direct byte writes reduced that to23.603ms. Reducing the dense budget to four
fields/64parcels lowered the cached-draw probe maximum to7.344ms.
These earlier probes mostly draw cached textures and are retained as iteration
records, not a claim about continuous animation cost.

The final benchmark advances and rasterizes on each of120native frames, with
128common emitters and2,048sparse particles at the start. Apple M4 CPU drawing:
median4.844ms, p956.955ms, maximum7.225ms. Update: median0.704ms, p951.687ms,
maximum1.769ms. JSON/log retain the exact scores. Drawing includes CPU raster work,
texture-update calls and command submission; GPU frame time is unmeasured.
The original historical living-effects benchmark JSON was restored after these
probes; this iteration's separate results are retained beside this report.

Known issues for the Opus review:

- The procedural Gatling rig visibly resembles an exposed vertical stalk. It
  appears only while the rig is active, then disappears40visual ticks after the
  last actual burst. It lacks the new authored turret's shape and mounting.
- Native .cache/blast-after/0030.png confirms the exposed upper Gatling assembly
  protrudes above the pit while its cone lies on/below the wagon body. Code uses
  rig base=roof-direction*recoil and barrel end=base+direction*8; muzzle birth
  uses roof+direction*8 without recoil. Side0's actual vectors point down, but
  the mounting reads upward and the visible anchors disagree. The muzzle volume
  also stays at its event world point while the rig follows the moving wagon.
- Roof actors visibly float above the authored body in that frame. Actor drawing
  still uses the source _roof_point y38/171, whereas the wagon/effect roof derives
  from cropped texture height. Rendering feet need the same actual body anchor;
  model actor coordinates and source input behavior need separate preservation.
- Sparse debris still rounds positions to whole logical pixels, producing four
  native pixel jumps. Volume parcels use the finer two-native-pixel grid.
- Actor and train positions retain source12.5Hz movement; they can visibly step
  while gas/rotor motion continues. No actor interpolation was implemented.
- Gas shading remains a small discrete palette. No depth lighting or physical
  material collision model exists in the new helper.
- The four-field cap can truncate older volumes under heavy concurrency. Source
  events still deliver their sparse projectiles/fragments within the common cap.
- No native Windows artifact or GPU frame budget was measured in this iteration.

Raw captures and intermediate animation copies remain in this registered
worktree's .cache until root preserves/disposes it. No owned test process remains.
