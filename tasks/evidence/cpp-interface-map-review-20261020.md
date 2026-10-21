# Native interface and map review, 20 October 2026

The nine prepared interface scenarios were exercised through real keyboard and
mouse input in the macOS SDL2/Metal application. The map review is complete with
defects. Map acceptance fails because two camera views terminate the renderer
and Turin has a visible horizontal artwork break at close zoom.

The owner leaves the remaining implementation and distribution work to Claude.
No runtime source, historical asset, launcher, or Git history was changed.

## Artifact and evidence

Application: `disk-hygiene-54i1ct98/TransarticaValidation.app`.
Executable SHA-256:
`4ce7914ca18b88b4be3418fb74ea0d6e7f871731c53e08488df606ef2daf8126`.
The bundle directory `game/assets/travel/artwork/world-hd` contains the eight
current `world-hd-portals-a` region PNGs, verified by matching hashes. The
standard directory name does not mean that the older artwork is loaded.

Private captures, reproduction saves and logs are retained in
`reference-private/verification-cpp-20261020/`, with `sha256.json`.
All player inputs used the native computer-use tool. F12 saved application
captures. Prepared saves isolate scenes and camera locations; loading them does
not constitute an earned campaign journey.

## Interface observations

| Save | Real input and observed result | Limit |
|---|---|---|
| CITY | Kuwait: bought one rail for 4 lignite; fuel 2000 to 1996, stock 23 to 22, aboard 0 to 1. F5 saved; SESSION reload restored the purchase. | Fixture is not at a real station departure. F9 requires suspending the city through the cabin footer. F5 works in the modal but its notice is hidden. |
| WORKS | Accepted crevasse work, saw report for 18 rails and 15 slaves. Saved the paid report, completed it, reloaded, completed again. Final archive has 2 rails from 20; slaves remain 15. | This verifies no second rail debit across this report reload. |
| MINE | Accepted the mine, advanced plaque and result: 43 anthracite added, HUD 500 to 543. Dismissed to cabin. | One prepared mining outcome. |
| HERD | Accepted herd encounter with 10 soldiers. Report: herd 20, capacity 0, recovered 0. Dismissed to cabin. | Zero-capacity branch only. |
| NOMAD | Entered nomad commerce, opened antiques stock of 38, exited trade and city. | No transaction performed; commerce uses the standard station background. |
| LAUNCH | ARM displayed ARMED. FIRE entered flight view, then NO ENEMY OBJECTIVE HIT. Dismissed result. Final archive has 1 missile from 2. | Miss outcome only. |
| QUIZ | Entered prepared answer POURRA for word 3, line 1, page 22. Reached Abu Dhabi garrison. | Correct-answer branch only. |
| TACTIC | Resumed and paused moving trains; selected rear wagon, deployed 10 soldiers with Return, commanded movement toward enemy train, observed damage. F5 saved; F6 then SESSION reload restored paused battle and deployed soldiers. | No complete battle victory. |
| FINALE | Advanced power-station intro, observed animation and automatic return to options, repeated and saved during playback. CoreAudio finale cursor advanced to 20480 without an error. | Device cursor is not an assessment of audible quality. |

Capture mapping in `captures/`: native-1 city, 2 works, 3 mine, 4 herd,
5 nomad, 6 launcher, 7 quiz, 8 restored tactical scene, 9 finale animation,
10 returned options. `state.log` records save/load events. The before/after
archives preserve the rail and missile quantity checks.

## Map defects and reproduction

1. Renderer failure. Start the retained application with `--save-dir` pointing
   to the retained `saves` directory. After startup, F9, V4, Return loads camera
   (40,55), density 16 pixels/cell. The native error dialog says:
   `Registered world passage: Values of 'uv' out of bounds 1.000000 0.194444 at 1/4`.
   The guarded process exits 1. `verified-map-runtime.log` contains the error.
   H2, camera (60,37), density 30, independently produces the same dialog.
   The focused runner also exits 1; its stdout was truncated by the guard, so
   the second exact error is supported by the observed native dialog.
   Inspect `native-game/view/world_passages.cpp` and the registered quad UV
   submission. The cause has not been established or repaired by this review.

2. Turin artwork break. F9, TURIN, Return. At 96 pixels/cell a horizontal
   discontinuity crosses the building at world y37. In
   `focused-captures/native-2.png`, the break is around image y250, spanning
   the building and nearby texture. The smaller seam overview hid its severity.
   Keep the original footprint (28,36,3,2) and anchor (30,37) when correcting it.

3. Residual join texture. V5/V6 and H3 retain broad sharp, granular snow strips.
   V1/V3 retain speckled tree or rock edges. The detailed capture findings below
   identify locations for an artwork pass.

4. Tunnel composition. All six existing `portal-render-a/mouth-*-crown.png`
   captures were inspected. The rails meet their mouths. At (12,21), (30,58),
   (105,23) and (113,58), the small portal still reads as an isolated object
   against the snow, with limited contact with the painted rock mass.
   (51,39) has the strongest cliff contact; (61,51) sits at a rocky mound.
   This is a visual review finding, not a change request to move rail ports.

## Complete seam coverage

An independent explorer visually inspected all 33 files in
`disk-hygiene-54i1ct98/world-joins-all-b/`; every file hash matches
`world-joins.json`. These are terrain captures at 33 pixels/cell.

| Boundary | Files | Finding |
|---|---|---|
| V1 | V1-1 to V1-3 | No empty join; speckled silhouettes near x120 to 150 in segments 1 and 3. |
| V2 | V2-1 to V2-3 | Connected terrain; no clear hard split. |
| V3 | V3-1 to V3-3 | Fragmentary tree/rock edges near central x132 column. |
| V4 | V4-1 to V4-3 | Continuous terrain, rougher corridor texture. Live overview crashes. |
| V5 | V5-1 to V5-3 | Perceptible bright granular retouched snow strip. |
| V6 | V6-1 to V6-3 | Broad gritty snow around x80 to 170; corridors connect. |
| H1 | H1-1 to H1-3 | Terrain continuity at this scale. Turin fails the closer live inspection. |
| H2 | H2-1 to H2-3 | Connected silhouettes; uncertain small lake-rim fragments in segment 3. Live view crashes. |
| H3 | H3-1 to H3-3 | Speckled snow around y120 to 170; fissure remains connected. |
| H4 | H4-1 to H4-3 | No clear terrain break at y132. |
| Corner 1 | corner-1 | No blank quadrant; sharp/speckled detail near center and upper right. |
| Corner 2 | corner-2 | Corridor connects; granular snow around x115 to 180/y130 to 200. |
| Corner 3 | corner-3 | No rectangular split; fragmentary rock and granular snow around center. |

Lineage: all eight portal composition source hashes match joins-b. The
composition receipt declares exact pixels outside edit footprints. Every seam
line lies outside those footprints; 31 of the 33 capture rectangles are wholly
outside. H2-1 and H2-2 overlap the local (51,39) patch below the seam. This is
receipt and file-hash evidence; no independent full decoded-pixel diff ran.
Current live V1 to V3 were also inspected and captured in `map-captures/`.

## Rail and tunnel checks

Amsterdam: live camera (25.5,24.5), density 96, shows the broken rail ends at
(25,24) and no stray railway on the geological continuation at (25,25)/(26,26).
Evidence: `focused-captures/native-1.png`.

Serov: live camera (108.5,4.5), density 96, shows the west station approach and
the surrounding rail alignment. No disconnected ordinary-rail join was visible.
Evidence: `focused-captures/native-7.png`. Anchor (108,4) comes from bundle
`private-data/villes-decoded.data`, source index 3; guide (107,3) is distinct.

Tunnel (12,21): loaded prepared train geometry, enabled stokers with L and A,
opened regulator with Right, resumed with Space. Observed the train emerge east
from the mouth, follow the northeast curve, and bring its last visible wagon
onto the surface. Paused and saved at cycle 68, position (14,19.1666666667),
speed 105, regulator 105, blocked=0. `tunnel-after.native` and `focused-state.log`
retain this state. Captures 3 to 6 show before/during/after. Some small train
fragments remain visible along the underground route during the transition;
their exact coverage rule still needs close inspection. A complete journey
between both ends of the tunnel was not performed.

## Validation limits and handoff

The interface run exited 0, peak owned-process-group RSS 185328 KiB. V4 review
exited 1 at 228112 KiB; focused review exited 1 at 202800 KiB. All used the
existing serial 1 GiB guard. No suite was rerun because runtime source was
unchanged; the earlier 17/17 CTest result is recorded in the preceding audit.

Claude should first reproduce the UV failure and repair it, then repeat V4/H2
and ordinary pan/zoom. Turin needs a close-zoom artwork correction. The retained
fixtures and screenshot hashes support those checks. Full SDL campaign play,
Windows execution and distribution remain outside this review.

Cleanup: the registered `disk-hygiene-s56yfk94` scratch was removed after
preserving the 34,385,667-byte private evidence set. It occupied 35,144 KiB on
disk before removal. No game or guard process remained in the process check.
The existing worktrees and `disk-hygiene-54i1ct98` were retained for Claude.
