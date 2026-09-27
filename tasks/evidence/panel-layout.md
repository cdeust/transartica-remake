# Common ECS control strip

The original screen is 320 by 200 pixels. Its common strip occupies rows 149–199;
`tasks/evidence/original-visuals.md` records the palette split. Screen y equals
`199 - z`. New illustration coordinates are fitted to the same frame, preserving
its aspect ratio with letterboxing. The illustration is newly authored; no
original bitmap is distributed.

The decoded `yoda.alis` form table is at `0x6bd0` (resource directory `0x349e`,
long pointer at `+6`). Forms 8–11 at `0x6c42/0x6c4c/0x6c56/0x6c60` carry masks
6/7/8/9. The English manual, private
`reference-private/observations/combat-20260927/manual.txt`, lines 279–316,
independently describes the common controls. Coordinates below include both end
pixels, hence a region from x80 to x112 has width 33.

| Code | Control | x inclusive | y inclusive | Context |
|---|---|---|---|---|
| 2 | Clock | 5–42 | 164–192 | Both |
| 6 | Engine | 80–112 | 161–175 | Both |
| 8 | Boudoir | 118–144 | 162–175 | Both |
| 7 | General Quarters | 79–113 | 180–193 | Both |
| 9 | Missile launcher | 118–146 | 179–195 | Both |
| 1 | Map | 161–193 | 160–178 | Wagon |
| 4 | Detailed map | 162–193 | 160–178 | Map |
| 1 | Overall map / return | 197–228 | 160–178 | Map |
| 3 | Reverser | 162–193 | 180–198 | Map |
| 5 | Brake | 197–228 | 180–198 | Map |

The UI emits these codes without changing simulation state. Dispatch follows
`panel_hotspots.gd`: the clock switches time step 1/3, not pause. The inactive
map controls in wagon context cannot emit commands. Tooltips and the pointer
identify controls without rectangular hover overlays. Readouts use actual
engine reserves, speed and calendar time; their lettering and clock-hand lengths
are presentation choices for the new plate, not recovered game constants.

The train rail artwork remains without guessed per-wagon actions until their
form mapping is established. This is an explicit remaining fidelity gap.

The current generated plate is 2014 by 781 pixels, verified from the file itself.
Its active strip is sampled at y190–578. Source x0–1029 maps to logical x0–159;
x1100–1549 maps to logical x160–229; x1550–2013 maps to logical x230–319.
The separator x1030–1099 is omitted. These artwork measurements align icon groups
to the original command regions; the command coordinates remain unchanged.

Readout containment correction: the preceding native `boudoir-quarters.png`
capture showed x316 touching the right rivet. On the replacement plate the
measured numeric interiors are `(1840,298,120,55)`, `(1840,396,120,55)` and
`(1840,492,120,57)`. They exclude the left pictogram, curved frame and right
rivets. Lettering is inset another screen pixel and fitted using its full advance
width, font ascent/descent and one-pixel shadow. Both dimensions must fit.
Tests independently reconstruct the measured windows and check 0, 500, 2000 and
32767 (maximum fuel accepted by `EngineState.restore`) at 320x200, 1280x800,
1600x900 and 600x1000. An integer-baseline version lost the speed readout at
320x200; preserving its fractional vertical center fixed that regression.

Replacement source: imagegen `exec-74b0977c-4989-45b7-b4d7-50dca88cc2f4.png`.
It was copied without external resizing. This is an artwork iteration, not a
claim of owner acceptance or equivalence to another game's visual quality.
