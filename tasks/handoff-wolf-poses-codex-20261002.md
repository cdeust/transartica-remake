# Wolf poses for Codex (2 October 2026)

Owner direction: « Les mammouths doivent avoir une animation par sprite comme
c'est le cas pour les troopers et espions. Ça sera ensuite la même
problématique avec les loups. » Wolves must be animated from generated sprite
frames in the trooper sheets' art direction
(`output/imagegen/actors-20261002/troopers-concept-v2.png`, `trooper-poses.html`).
No hand-drawn or ASCII draft will be accepted. Mammoths come first. This request
follows them.

## Verified inventory

- `game/assets/campaign/wolf-ambush.png` (1836×857) is the only runtime wolf art.
  It is one static plate loaded by `campaign_screen.gd` for the wolf ambush
  (`campaign_fauna_session.gd`, TIME wolf code 60; messages 77/81/79). It shows a
  frontal view from the locomotive's beak: five wolves charge toward the viewer
  along the track at three depths, under a dusk sky.
- `output/imagegen/actors-20261002/wolves-concept-v1.png`: side-view concept keys
  (stand, 3 trot, 2 gallop, lunge, lying). These are concept only: uneven cells and
  soft partial alpha. They are not integrated.
- Wolves are not tactical actors. No rule is added; this is presentation of the
  existing ambush event only.

## Request

### Plate 1: clean background
The same composition as `wolf-ambush.png` (sky, mountains, track, locomotive beak
and stacks in the foreground) with NO wolves, at the same size and
registration, so wolves can be animated over it.

### Sheet 1: frontal charge, 3 depth sizes, 8 frames each
Grey wolf running straight at the viewer (head-on, slight 3/4 left and right
variants allowed). Planted-paw gallop cycle: gather, extension, suspension,
landing. The loop closes. Snow kicked up is a separate small layer per frame.
Sizes: near (as the two flanking wolves on the plate), mid, far.

### Sheet 2: frontal 3/4 left and right, 8 frames each, near size
For the wolves flanking the track.

### Sheet 3: attack/leap at the viewer, 6 frames
Last bound toward the camera, jaws open, filling the near size.

### Sheet 4 (optional): side gallop 8, trot 8, lunge 4, hit 2, death 6
Right-facing, for any later side-view use. Same scale family.

Transparent background, solid interior alpha, no halo, equal cells, a common
baseline per size, same lighting as the plate (dusk back-light, cold fill).
Record prompts, hashes and alpha measurements in
`output/imagegen/actors-20261002/manifest.json`. Claude cuts the frames and
animates them over the clean plate along the track perspective.
