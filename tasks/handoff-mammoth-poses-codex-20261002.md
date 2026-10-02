# Mammoth poses for Codex (2 October 2026)

Claude audit of `tasks/validation/mammoth-actions-20261002.mp4` (fixture
`game/tests/review_mammoth_actions.gd`): the mammoth is one static painted
image, so its feet slide, it dies by fading and its riders never move. The
missing poses must be generated in the same art direction as
`output/imagegen/actors-20261002/troopers-concept-v2.png` and the trooper pose
sheets (`trooper-poses.html`), NOT in the softer painted style of the current
`actors-kit-08/09`. No hand-drawn or ASCII draft will be accepted.

## Verified inventory (what exists)

- `game/assets/combat/actors-master.png` (1448x1086) holds the two in-game
  mammoths: bare at (11,776) 410x295 and ridden at (432,747) 393x324. They are
  single frames facing right; this is all the runtime draws
  (`tactical_actor_art.gd`, poses 8 and 9). `actors-kit-08/09.png` are crops of
  the same two and are not used at runtime.
- `output/imagegen/actors-20261002/mammoths-concept-v1.png`: 4 bare and 4 ridden
  walk keys in a brown, soft-fur render with blue riders in a wooden howdah.
  Walk-cycle direction is right, but the sheet is concept only (uneven cells,
  halo in the tusk, riders blurred, no olive riders, fur colour and tusk do not
  match the master). It is a reference for gait, not usable frames.
- Nothing exists for: planted-foot walk cycle, stop, melee/trunk, hit reaction,
  death, rider motion, dismount, olive riders.

## Common requirements

Same render as the troopers: pixel-hard edges, the dark outline and cool snow
light of `troopers-concept-v2`, fur drawn in the same palette family as the
master mammoth (dark grey-brown, snow in the fur, cream tusks, leather harness
with ring). Right-facing profile (the game mirrors it). Transparent
background, solid interior alpha, no halo, no neighbouring fragments in a cell.
One pose per equal cell of 560x440 source px, all feet on one common baseline,
the same scale as the master mammoth (bare body about 410 px long, 295 px tall;
standing trooper about 336 px, so a rider is about the size already in
`actors-master.png`). Order and file names below; cells never overlap.

## Request

### Sheet 1: bare mammoth (no rider), 24 cells
1. Walk, 8 frames: contact, down, passing, up for each side; diagonal pairs of
   feet alternate, each planted foot stays flat on the baseline for its
   half-cycle, trunk and ears swing, body rises about 6 px at passing. The loop
   must close (frame 8 leads into frame 1).
2. Stop, 2 frames: standing weight settled, then trunk lowered and ear flick.
3. Melee, 4 frames: head lowered, tusk swipe or trunk swat (wind-up, strike,
   follow-through, recover). The foe is to the right.
4. Hit reaction, 2 frames: head jerked back, forefeet shifted.
5. Death, 8 frames: stagger, forelegs buckle, front end down, roll onto the
   flank, trunk falls, lying still (2 lying frames). The animal dies falling to
   its left side, away from the viewer, and stays on the baseline. A second
   lying frame with the trunk curled.

### Sheet 2: mammoth with howdah, blue riders (player), 19 cells
Same body as sheet 1 with the wooden howdah, lantern and machine gun from the
master ridden pose. Riders are drawn as a separate layer in the same cell
(two riders: spotter with binoculars, gunner) so the game can show 0, 1 or 2.
1. Walk 8, stop 2, hit 2, melee 4: the howdah rocks with the gait and the
   riders sway with it; body frames must match sheet 1 for each key.
2. Death 5 frames: the animal falls and the howdah slides; riders thrown clear
   (they are exported separately, see below).
3. Layers per walk frame: howdah and body with NO rider, plus rider layer.

### Sheet 3: olive enemy riders and howdah, 19 cells
Same as sheet 2 with the olive coats, red armbands, ushanka and the enemy
howdah in dark wood (same cell order). The bare mammoth is shared.

### Sheet 4: dismount, 5 cells per side (blue and olive)
Rider on the howdah rim stands, swings a leg over, drops, lands crouched; one
cell each: stand, leg over, hang from rim, drop, land. Same scale as the
trooper standing frame (336 px) so the trooper run frames can take over from
the landing. The howdah carrying this rider is the empty/one-rider variant.

Record prompts, hashes and alpha measurements in
`output/imagegen/actors-20261002/manifest.json`. Claude cuts the frames,
normalises pivots and integrates them into `tactical_actor_motion.gd`. Until a
frame exists, the single pose stays; nothing is claimed integrated.

## Source constraints (no invented rules)

A bare mammoth is a count of 1; the howdah shows when a group counts more than
one (`tactical_actor_art.pose_for`). The player only deploys one mammoth per
click, so a ridden player group is a merge (limit 31, 0x31f9); an enemy group
can be up to the wagon's livestock. Original facing and in-between motion are
not decoded (see `FIDELITE.md`): all of this is authored presentation.
