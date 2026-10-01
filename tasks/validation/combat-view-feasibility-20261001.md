# Combat-style travel feasibility

Read-only assessment of commit `79c80b28a5a7a9bf227269dcceac4b015b11e182`.
No runtime changes or publication. Existing native captures were inspected:
`locomotive-travel-native.png` and `locomotive-combat-native.png`, both 1280×800.

Combat-quality travel is technically feasible. Enlarging the existing map alone
cannot reproduce the combat perspective across its railway directions. A coherent
replacement needs directional vehicle artwork and a world renderer with matching
rail contacts. The original geography can remain unchanged.

## Measured differences

| Evidence | Travel | Combat |
| --- | --- | --- |
| Projection | Square map axes, 205.9126 pixels/cell before zoom | Horizontal trains on fixed logical baselines y=63 and y=192 |
| Vehicle placement | Individual front/rear contacts sampled from traveled route | Fixed wagon index spacing of 64 logical pixels |
| Hero crop | 438×1886, top view | 2002×673, side view |
| Hero displayed footprint | At zoom1: 154.434×35.865 pixels, rotated rigidly | 77.343×26 logical pixels; at 1280-wide screen: 309.373×104 pixels |

These footprints come directly from `TrainRenderer.texel_scale`, its hero crop,
and `TacticalScene._train`, including the uniform height limit of26. The native
travel capture visibly bends the convoy around a switch while the combat capture
shows side silhouettes on parallel horizontal rails.

At travel zoom2 the hero becomes 308.869×71.731 pixels. It nearly matches combat
length, but its top-view width remains about32 pixels smaller than combat height.
The differing aspect ratios prevent one uniform scale from matching both axes.
The existing zoom cap is2; a new zoom cap does not supply missing side surfaces.

The source map is160×73 cells. At zoom1 its projected extent is approximately
32946×15032 pixels; at zoom2 both extents double and a fixed viewport sees one
quarter of its previous world area. Enlarging the map renderer preserves logical
geography. Resampling CARTE or changing tile distances in simulation would affect
source rules and is unnecessary.

## Direction and camera constraints

`RailNetwork.DELTAS` contains eight moving headings. `_project` is an invertible
two-axis transform and `_screen_to_world` supplies switch hit-testing. Multiplying
it by a positive zoom preserves all directions. It cannot turn every rail tangent
into the horizontal tangent required by a literal side portrait: a transform
collapsing both independent map axes into one line loses invertibility and merges
distinct world positions.

A fixed world camera can show direction-correct train sides if each vehicle has
matching directional views. A side sprite rotated through90° becomes an upright
side portrait; it does not reveal the front or rear of that vehicle. The current
top sprites rotate rigidly without that inconsistency. Drawing a horizontal sprite
over a vertical track would detach its wheel/coupler axis from the rail contacts.

The current tests cover25 vehicle kinds at eight sampled rotation angles with
equal orthogonal scale. `test_camera_scale.gd` additionally covers all eight rail
headings and a curve at three viewport shapes, asserting that camera fitting does
not change network bytes. The final suite's `test_travel_world` PASS is recorded
at line181 of `full-completion-final-20261001.log`.

Curves require per-car orientation: a leading locomotive can be diagonal while
the tail is still eastbound. `TrainPath` retains the traveled branch, so changing
a past switch cannot redirect the tail. `reverse_direction` changes traction
while preserving wagon orientation. A replacement renderer must preserve these
contracts; rotating the whole convoy around its locomotive is a known failed
approach recorded in `tasks/lessons.md`.

## Viable implementation scope

For a fixed-camera world with combat-level vehicle detail, author a matching
directional catalogue for the25 source vehicle kinds. Eight headings imply200
poses before animation or equipment variations, although validated symmetries
could reduce newly drawn assets. Since vehicle tangents vary continuously on
curves, eight views also need a tested transition policy. A stylized2.5D model
rendered into sprites is another feasible production method. Keep rigid dimensions
and verify contact anchors at switches; the owner previously rejected perspective
shortening and changes in wagon size between headings. A conventional foreshortened
isometric catalogue would conflict with that requirement.

The world presentation would need matching rail/terrain treatment, depth ordering
and an invertible click transform. Preserve the160×73 source data and traveled
polyline; render decorative height separately. Begin with a one-vehicle turn proof
before producing the catalogue. This is a renderer/art milestone, not a scale fix.

A dedicated side-view journey screen could reuse combat sprites while a separate
strategic map keeps original switches. It would show local route progression rather
than the complete fixed world projection. That is a different navigation design
requiring an explicit choice. A camera that rotates the world to face the train
would also change the established fixed-camera behavior.

If that milestone is deferred, the existing combat material/effect modules provide
a bounded place to improve Noita-like impact visuals. Current debris draws four
representative removed pixels per wagon event, and smoke/light effects last23
source ticks. More material fragments and better smoke progression could improve
the visible effect density while leaving source hull/damage rules intact. Acceptance
would need native impact captures and measured frame cost on the same host; this
assessment supplies no performance result for an unimplemented effect change.
