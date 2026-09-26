# Train sprites for the remaining headings (to generate)

Reference style and train: `game/assets/travel/train-east.png` (prompt: `travel-train-prompt.txt`).
Map projection (`travel_world.gd`): world east = screen (180, 100), world south = screen (-180, 100).
Screen direction of each heading, and what already exists:

| Heading | Screen direction of travel | Source |
|---|---|---|
| E (6) | down-right, ~29° below horizontal | train-east.png (exists) |
| S (2) | down-left, ~29° below horizontal | horizontal mirror of E |
| W (4) | up-left, ~29° above horizontal | **train-west.png, to generate** |
| N (8) | up-right, ~29° above horizontal | horizontal mirror of W |
| SE (3) | straight down, towards the viewer | **train-southeast.png, to generate** |
| NW (7) | straight up, away from the viewer | **train-northwest.png, to generate** |
| NE (9) | straight right | **train-northeast.png, to generate** |
| SW (1) | straight left | horizontal mirror of NE |

Shared constraints (copy into every prompt): same train as the reference image, same camera
(orthographic oblique, elevated 35° down), same scale per car, same lighting from the upper left,
same palette. One locomotive and exactly five wagons in the same order (coal tender, sleeping car,
boxcar, observation carriage, armoured gun wagon). Premium hand-made pixel art, TRUE TRANSPARENT
background, no rails, no ground, no smoke, no text, 1536×1024 canvas, whole train inside the canvas.

- **train-west.png**: the convoy runs on an axis from lower-right to upper-left, ~29° above horizontal.
  The locomotive is at the UPPER LEFT and moves away from the viewer; we see the rear of the
  gun wagon at the lower right and the near sides and roofs of every car.
- **train-southeast.png**: the axis is vertical on screen. The locomotive is at the BOTTOM, facing the
  viewer (smokebox front and cow-catcher visible, strongly foreshortened); the wagons stack upward
  behind it, roofs visible.
- **train-northwest.png**: vertical axis. The locomotive is at the TOP, moving away; the gun wagon's
  rear end is nearest the viewer at the bottom.
- **train-northeast.png**: horizontal axis. Pure side view seen from above at 35°; the locomotive is
  at the RIGHT, the wagons trail to the left.

Integration: `TravelWorldView.train_pose()` will pick the sprite per heading, then mirror; the
rotation fallback used today for missing headings is removed once these files exist.
