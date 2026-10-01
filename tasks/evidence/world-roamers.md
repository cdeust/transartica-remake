# Roaming nomads and mammoth herds

Reference: English ECS `reference-private/unpacked/table.alis`, `time.alis`, `yoda.alis`, `textek.alis`; decoded with `tools/alis_disasm.py` in the campaign worktree. Implementation is MIT, independent of original raster assets.

TABLE4c5..54c initializes ten six-word herd records: dx=rnd130−30, y=rnd60+5, phase0, heading=rnd9+1, timer=rnd40+40, quantity=rnd45+5. TABLE56f selects the wolf from eleven sites; TABLE5b6 retries nomad selection until it differs from that wolf. WorldRoamers.initialize consumes these calls in that order and delegates the intervening wolf selection to CampaignFauna.initialize. Presence derives independently from records, leaving enemy bit16 and wolf bit8 unchanged.

TIME67e increments each active herd phase each callback and commits one cell at phase9. It decrements its timer, redirects west when dx>114, east when dx<−35, south when y<5, north when y>66, otherwise selects rnd9+1 when timer<0. Redirected timers become rnd40+30. Herd movement passes mover bit2, which skips TIME21d5 terrain bounce. TIME8ef increments the nomad callback counter, advances phase every fourth callback, commits at phase3, and turns at phase1. TIME1444 handles facing switches with rnd2 when no matching player history is provided. Wolves pass three source history entries; nomads pass none. The signed −113 case at TIME228c is unreachable after abs and is not treated as a positive113 obstacle.

TIME2221 trap scan belongs to the negative-tile, enemy-bit16 branch. Wolves and nomads skip that scan. TIME228c bounces them at absolute codes34,35,36,37,65,67,69,78,79,107,114,116,120. Movement returns the final cell even after bounce, preserving spy-observation dispatch. TIME2045 records herd code40+slot, nomad70, wolf60 through the existing spies.observe_enemy(code−1) field encoding.

TIME258a suppresses player herd encounter on switch codes38..49 or55. Herd question dispatch precedes nomads when both are present. YODA24d4..256d relocates the herd before TEXTEK23 is shown: dx=rnd140−30, y=rnd60+5, heading=rnd9+1, timer=rnd40+40; phase and quantity remain. YODA2746 relocates nomads after the question has been answered but before either answer branch. YES enters original city45 via2758..2762; NO returns without trading. Source city45 is a dynamic encounter, not a positive station. YODA811→864→927→18e3 reverses the player on leaving that scene.

TEXTEK73 at171b collects all type7 free capacity (three per wagon), slaves in types5/6, soldiers in23/24 without a STATE filter. Clicking its plaque dispatches83 at4682. TEXTEK83 at1e35 computes divisor10−floor((slaves+soldiers)/40), replaces divisor<=1 with2, and catches min(floor(herd/divisor)+1, freecapacity). It subtracts captured animals from the relocated herd before writing cargo. The original1fb2 branch skips subtraction when the destination wagon total is<=3, leaving the remaining count unchanged for another wagon; implementation preserves this source behavior rather than fixing it silently. Report strings and templates load from private campaign data.

TEXTEK1fee sets clock factor3 and1ff4 sets countdown24. TIME-independent text callbacks decrement only when countdown>0 at45e6. At zero they stop; the `<0` reset at45cd is unreachable from positive24 under that guard. The implemented result countdown follows that branch and does not invent an automatic factor1 reset on close. Questions reset the clock through source YODA2318; nomad accepted scene uses db2 factor1. The dialog clock adaptation pauses travel simulation, as existing city/works UI does.

`test_world_roamers.gd` passed native Godot headless on 2026-10-01: exact startup RNG sequence, herd pass-through versus nomad obstacle bounce, phase turning, JSON integer restoration, 130 resumed movement callbacks with matching RNG, atomic rejection, presence-based questions, both nomad answers, source hunting and reward idempotence. `test_restore_city.gd` covers the production nomad UI/disk restoration separately; its fixture does not claim an earned campaign run.

Production follow-up verification: native OpenGL `test_restore_city.gd` passes both nomad and hunting UI/disk regressions, including source24-tick report state and fractional callback remainder. `WorldUISave.validate` accepts that remainder only for a live works dialog or a staged `hunt_result`. The source-population campaign route and its earned midpoint save/reload pass at10657 advances/1713 cells/day23/lignite1067. The final verbose route run exits0 without ObjectDB leak diagnostics. All owned test processes exited; no commit or remote publication performed.


Recovery validation, 1 October 2026: actual native Main nomad/hunt encounter
questions preserve artwork aspect through uniform fitting. Their captures are
`tasks/validation/nomad-question-native-20261001.png` and
`mammoth-question-native-20261001.png`; viewport Return, cargo, interrupted disk
save and fractional text cadence pass in `world-recovery-roamer-native-20261001.log`.
The nomad foreground locomotive remains part of the owner's shared locomotive
art pass. Native cadence agrees at 30/60/144 Hz, including populations, fauna,
commerce RNG and campaign state, and the verbose host exits without allocation
leaks (`world-recovery-cadence-native-20261001.log`). The headless Dummy backend
reproduced an AudioStreamPlaybackWAV/WAV exit leak; the fixture now declares its
actual audio/render host requirement instead of treating Dummy playback as
native lifecycle proof. Source and craftsmanship checks on the recovered files
report zero errors and warnings. No new worktree, commit or publication created.
