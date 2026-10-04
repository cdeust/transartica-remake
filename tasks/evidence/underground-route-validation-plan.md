# Underground traversal validation plan

Read-only source audit,4October2026. No native input, game mutation or traversal
occurred during this audit. Root owns the earned campaign and final route files.

## Sources and exact connections

CARTE.FIC is the original160x73 column-major map. RailGlyphs supplies reciprocal
ports; RailNetwork supplies TIME curve/heading rules and progress_speed. The
English manual, observations/combat-20260927/manual.txt586..591 and699..706,
describes dotted underground tracks, faster travel and Mole Men. See also
underground-rendering.md and its verified TABLE/TIME offsets.

There are exactly six source mouths. Following actual incoming headings through
curves and crossings gives these three pairs, in either physical direction:

| Mouth pair | Surface side / entering heading | Steps between mouth centers | Mole sites on this traversal |
| --- | --- | --- | --- |
|12,21 code58 ↔61,51 code53|12,21 from13,21 heading4;61,51 from61,52 heading8|83|5,28;50,44|
|30,58 code54 ↔105,23 code58|30,58 from29,58 heading6;105,23 from106,23 heading4|82|44,59;74,38;83,27|
|51,39 code54 ↔113,58 code58|51,39 from50,39 heading6;113,58 from114,58 heading4|64|66,40;92,57|

All six mouths share one reciprocal-port component once the underground axes
of crossings15/16 are included:230 cells, comprising220 original38..58 cells
and10 directional crossing cells. This does not create arbitrary interchange.
Diagonal crossings49 at59,47 and69,41 preserve heading. An undirected BFS could
turn there and invent mouth pairings; the directed traces above do not.
Each trace was independently followed backwards and returned to its paired mouth.

The shortest pair,51,39→113,58, follows these source waypoints:
51,39→52,39→53,39→54,40→68,40→69,41→81,53→81,54→81,55→82,56→91,56→92,57→94,59→110,59→111,58→112,58→113,58.
Ranges between those turning points follow the same reciprocal source rail,
not a straight shortcut across empty map. No underground switch choice occurs.

## Approach from the earned Berlin save

Read existing F5 save.json: position35,21, heading4, phase0, reverse=false,
21 vehicles. Detached directed search using the current saved map changes,
source turn rules and both authored switch states gives these approach costs:

| Target mouth | Source actions to reach it | First mouth encountered |
| --- | --- | --- |
|12,21|34|12,21|
|51,39|47|51,39|
|30,58|69|30,58|
|61,51|79|61,51|
|105,23|97|105,23|
|113,58|111|51,39|

Actions count cell moves, reverser actions and the planner's station-stop edge;
these are not seconds, fuel estimates or a promise of no enemy encounter.
No destroyed track, unported special cell or repair allowance was admitted.
Station visit/return behavior remains a real player interaction in the pilot.
The nearest entrance is12,21, but51,39 is the shorter complete-pair validation:
47+64=111 actions versus34+83=117. Its surface approach includes the ordinary
station at35,25. Route switching must use the pilot's pause/F5/replan protocol;
do not preselect a switch for multiple visits or after its turn phase passed.

The12,21 approach runs35,21→34,21→33,22→33,24→34,25, station35,25,
then west via33,25→32,25→31,24→15,24→14,23→14,20→14,19;
reverse at14,19 and return14,20→13,21→12,21. The repeated14,20 visit is
phase-dependent; this is why a geometric shortcut would be unsafe.

The literal Mausoleum53,32 is a source-hidden station record35, with52,32
record−123; it is not an ordinary road start. Do not substitute a guessed exit
or overwrite position. Plan again from its actual earned departure F5 state.
No shortest safe native departure is claimed from that station anchor here.

## Root's actual run after rebuilding

1. Restore the earned Berlin save through OPTIONS, pause andF5. Generate the
   actual current-phase itinerary with plan_player_leg.gd toward51,39. This
   replaces the detached audit distances if anything in the earned save changed.
2. Traverse from the west surface50,39 through mouth51,39, covered52,39 onward,
   then mouth113,58 and east surface114,58. Log real inputs and captures.
3. Prove the entire occupied train exits using every actual vehicle midpoint
   and front/rear contact. Do not stop at the first locomotive reaching114,58
   or assume a fixed wagon length. Find the turnaround through the source
   planner from the actual paused position; no teleport or injected direction.
4. Return through113,58 toward51,39. Cover both physical directions and both
   forward/reverse modes using earned approaches. After each reverser action,
   preserve contacts and plan from the actual new phase, not the old itinerary.

Acceptance per pass: mouth is visible and traversable, mouth vehicle opaque,
each underground vehicle uses its own sampled midpoint tint, surface vehicles
remain opaque, no missing pose/jump, all contacts retained through exit.
TIME doubles progress on38..52/55..57; mouth53/54/58 remains ordinary speed.
Crossing15 doubles only headings4/6 and16 only2/8. Compare observed physical
progress with those source conditions, not the fast-clock wall time alone.

Both66,40 and92,57 are original Mole sites on the preferred pair. Inspect their
real source encounter/cooldown outcomes; no attack is guaranteed by one pass.
The manual's bomb-line inspection car deterrence is a separate source case,
not permission to insert a wagon into this earned train. Full Mole-risk and
all six-mouth native coverage remain open until the required real runs exist.

## Earned11105: finish whole-train exit before reverse return

Root reports the actual forward pass51,39→113,58 completed. Existing native
11105 metadata/F5 is paused at114,58, heading6, phase0, reverse=false, with21
rendered vehicles. It is not a complete exit: locomotive front113.5,58 and
rear112.75,58; last spy rear98.175163,59. The twenty trailing vehicles still
occupy the tunnel. No further native traversal occurred during this audit.

The connected surface candidate is **132,63**, not an arbitrary eastward
coordinate. Original CARTE and RailNetwork.turn give:

114,58 code18 →115,58 code24 →116,58 code2 →117,58 code23 →118..126,58 code2
→127,58 code6 →128,59 code5 →129,60 code5 →130,61 code5 →131,62 code5
→132,63 code8.

Keep114,58 at18 for eastward straight travel. Select117,58 to22 while paused
before its source turn phase; its original23 would diverge south-east. The
surface path above contains no station, works frontier or underground tile.
The recorded map changes do not modify these cells. Original130,58 has no
rail; it is not an appropriate target. Use the existing read-only planner
`game/tests/plan_player_leg.gd` from the actual paused F5, target132,63. Pilot
must retain pause/F5/replan selection order; this table is not an input replay.

The actual21 kinds in11105 sum to20.88 authored LENGTHS units. Renderer
WAGON_CELL_RATIO0.75 makes the sum of rendered vehicle chords15.66 cells.
114,58 center to132,63 center follows13 ordinary east steps plus5 diagonal
steps:13+5√2=20.0710678 rail-cell units. Curves, source phase and visual lag
make this a planning estimate, not proof that the train is already outside.
At132,63, pause/F5 and inspect all21 actual midpoint/front/rear coordinates
and underground flags; every vehicle must be clear of covered rails before
turning around. Keep the exact geometry as the acceptance oracle.

For the reverse pass, reverse only through the real shared-panel control,
pause/F5 again, and plan from its newly recorded heading/phase. First target
113,58, then51,39: this forces the same tunnel pair rather than a shorter
surface itinerary. The surface approach is traversed back via131,62→130,61
→129,60→128,59→127,58→126..118,58→117,58→116,58→115,58→114,58→113,58.
Both approaches at117,58/114,58 are trailing headings4; RailNetwork preserves
westward travel there. Do not reuse pre-reversal source phases at132,63.

For complete western emergence, continue past mouth51,39 to50,39 code2 and
49,39 source switch21, connected reciprocally to51,39 code54. Select49,39
to20 for continued westward travel instead of its north-west divergence.
Use49,39 as the final native waypoint and verify every actual contact is west
of the mouth's surface port50.5,39; checking merely the leading tail at50,39
would again prove only a partial exit. No total-length approximation replaces
that contact check. This passage validation does not complete the Mausoleum
campaign objective, the other underground pairs or every Mole encounter.
