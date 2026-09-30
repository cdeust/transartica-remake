# Tactical combat checkpoint

Base: origin/main bf9f950 (PR7). Worker owns tactical modules, scene, crops,
world_encounters wiring and combat regressions. Root owns main/session_saves,
calendar integration, tasks/todo, native capture/review and publication.

Primary evidence read: private combat-20260927/wdecor.txt, source ALIS
sys/sys_sdl2.c58,279 and opcodes.c2393. Timing multiplier4 over50Hz gives
0.08s fixed steps; scan budget max(columns/4,40), seven rows,16px cells,
64px wagon slots, four roof positions. The grid's row6 is the upper player
edge and row0 the lower enemy edge. Code placement takes precedence over
contradictory manual wording; emulator verification remains separate.

Implemented domain: wagon combat rosters, fixed steps and scan cursor, train
movement and per-wagon AI, weapon reloads, first occupied-column machine-gun
fire including friendlies, deployment, group directions/STOP, split and merge,
roof boarding, melee, dynamite fuse/defusal, battle finish and exactly-once
victory write-back. JSON preserves roster, actors, fuse state, RNG, AI,
scan cursor and fractional clock; malformed saves reject before mutation.

Dedicated side-view presentation uses authored20260927 background,25 wagon
crops, infantry/mammoth poses and impact/flame/embers/smoke keyposes. Scars
and debris are presentation; original three-hit wagon damage remains.
Equipment master has an opaque atmospheric background and is not composited
as a rectangular overlay. Crop builder reproduces retained assets without
original sprites or public original datasets.

Before: Godot reported missing res://scripts/tactical_combat.gd. Its process
returned0 despite startup error, so process exit alone did not prove a gate.
After: test_tactical_combat.gd returned0 with explicit PASS for weapons,
actors, dynamite, vital defeat/victory, exactly-once payout, interrupted JSON
resume, equal12-second outcomes at30/60/144Hz and scene key actions.
world_encounters regression returned0 with explicit PASS for calendar,
pending save/restore, automatic option, win/loss and no duplicate loot.
The latter was rerun with root's minimal main/manual-key and session_saves/
resume_pending integration applied locally; those two files are excluded
from the worker commit and root must apply them on integration.

Controls: click barracks then Enter deploys group; +/- adjusts count. Click
unit, arrows (Shift for diagonals) set direction, Space stops, S splits selected
count. Click cannon/machine gun then Enter fires. Q/E plants adjacent dynamite
on roofs. With no unit selected, left/right changes convoy direction, Space
brakes. P pauses, F5 saves, F6 opens options. Mouse edges scroll and wagon bar
click centres the corresponding wagon.

Verification limits: automated headless scene handlers are not a native
window action transcript, no aesthetic acceptance is claimed. Root must
review the integrated scene in its isolated native test window. This is not
an emulator equivalence benchmark of the full ECS script: mounted groups,
AI random-stream equivalence and edge cases need original comparative review.
