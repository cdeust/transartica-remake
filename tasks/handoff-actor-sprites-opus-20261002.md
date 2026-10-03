# Actor sprite designs for Opus

Owner request, 2 October: design troopers, wolves, mammoths, spies and identify
other elements needing the animation quality applied to combat trains. Opus
finalizes the artwork and motion. These are original design proposals; no
runtime animation or new gameplay is delivered by these sheets.

## Visual direction

Start with a readable silhouette at game size: big coat shapes, separated boots,
long wolf back and tail, massive mammoth shoulder and tusks. Use deliberate
pixel clusters, with detail concentrated on faces, hands, tusks and equipment.
Keep the established cold industrial world and current train/effect artwork.
The [official Noita reference](https://noitagame.com/press/index.html) describes
physical pixel effects. Our artistic interpretation is distinct body motion
with small event-driven dust, breath and cloth responses. It does not require
changing Transartica's simulation into Noita's physics system.

Existing actors-master.png has high-detail illustrations reduced to a small
display footprint. Avoid shrinking a detailed new illustration and treating
the result as finished pixel art. Opus should redraw/polish the selected
silhouette on the intended pixel lattice and review it beside actual wagons.
Generated sheets propose poses; equal cell sizes, frame consistency and exact
pixel geometry are not certified.

## Delivered references

Gallery: [actor sheets](../output/imagegen/actors-20261002/index.html).
Exact generation/edit prompts and PNG hashes: `output/imagegen/actors-20261002/manifest.json`.
Built-in image generation was used. Existing runtime assets remain intact.

Inspection: every sheet has an RGBA alpha channel and transparent empty space,
but many pixels are partially transparent; the human sheets also show soft
colored halos. The trooper cleanup attempt sharpened the drawing without
producing a certified clean mask. Opus should produce solid interior alpha and
clean sprite contours when finalizing. The mammoth sheet retains too much fur
texture for the small combat footprint and needs simplification. Run poses are
keys rather than verified consecutive frames; complete foot contacts and
missing directions before using them as animation.

| Family | Design sheet | Motion to finalize | Current integration |
| --- | --- | --- | --- |
| Troopers | Blue player / olive enemy, ready pose, run keys, crouched brace | Foot contacts, passing poses, coat drag, roof balance; climb, melee and demolition branches | Infantry combat actor |
| Wolves | Alert, trot, gallop, low pounce, rest | Flexing spine, fore/hind paw sequence, head leading, tail following | Campaign encounter plate |
| Mammoths | Bare and wooden-howdah variants, walking keys | Heavy planted contacts, body transfer, delayed trunk/tail, leather straps and riders following body | Mounted/bare combat actor plus separate herd/hunt plate |
| Spies | Charcoal coat, ochre scarf, satchel; walking, observing, map/report poses | Cautious gait, scarf drag, hand gestures tied to existing report/menu events | Records and menus; no dedicated sprite yet |

The spy costume is an artistic proposal, not a decoded ECS costume. Observation,
route-map and report poses communicate existing reconnaissance roles. They do
not establish new inventory items or interactions.

## Measured runtime constraints

`game/scripts/tactical_actor_art.gd:26` uses maximum bounds of 12×17 logical pixels
for infantry and 28×28 for mammoths. It fits the art uniformly and anchors it
at bottom centre. `original_screen.gd` supplies a 320×200 logical scene.
These are the existing presentation limits, not historically mandated sizes.
Retain them for the first integration review; any readability-driven size
change needs an in-scene comparison with overlap and picking checked.

`tactical_actor_art.gd:17` selects only idle/run by direction and bare/ridden by
count. The sheets do not imply new actor types. `tactical_combat.gd:83` records
id, side, x/y, count, mammoth, roof, direction and processed. Wolves/spies are
not tactical entity types in this implementation.

Current shallow elevated side presentation must remain consistent with the
train. Generated right-facing profiles are a first pose reference. Opus must
resolve the source eight-direction movement into consistent front/back/diagonal
views; reflecting a right-facing rifle or asymmetric satchel is not sufficient
proof of all headings. Do not change camera projection to accommodate sprites.

## Animation contracts

| Family | Source-backed triggers | Body response | Secondary response |
| --- | --- | --- | --- |
| Troopers | Move, stop, field/roof transition, melee, plant/defuse, count loss | Contact → passing → opposite contact; lean into travel; plant knee/hand before charge placement; controlled recovery after impact | Coat hem and satchel follow body; breath/dust remain separate layers |
| Mammoths | Move, stop, melee/collision, rider transfer, count loss | Slow weight transfer, planted feet, head/trunk following chest, coherent mount seat | Fur fringe, straps and riders follow movement; ground contact dust at feet |
| Wolves | Existing wolf encounter/report state | Quiet alert, trot/bound, crouch/pounce as encounter staging, then settle | Sparse snow at actual paw contacts; breath from muzzle |
| Spies | Aboard, travelling, posted, retrieved, observations and confirmation menus | Walk/observe/return/report gestures in the matching representation | Scarf and satchel; no persistent glow or invented attack ability |

`tactical_actors.gd:38` and `:120` implement movement, boarding, melee and
demolition. There is no independent infantry rifle-fire damage event. Keep
rifles as current costume/equipment; do not invent a combat firing rule merely
because the art depicts a rifle. If a future presentation-only fire gesture
is desired, first identify an existing event it can honestly represent.

`campaign_screen.gd:24` loads wolf/mole illustrations and `:95` draws a plate.
`roamer_screen.gd:4` draws nomad/hunt plates contained in their existing scene
box. For these encounters, separate foreground animals/figures from the plate,
repair the exposed background, and preserve composition and UI hit regions.
Do not overlay a moving cutout on a duplicate animal still painted underneath.

`campaign_spies.gd:22` and `:70` supply actual spy states. A map sprite would be
a new renderer integration: preserve the original visibility rules and avoid
revealing positions the player should not know. Design does not authorize
adding wolves or spies to the combat roster.

## Pivots and movement

- Use a stable contact anchor at the feet; keep a mammoth ground anchor stable
  across bare/ridden variants. A jumping wolf may leave its contact baseline,
  but its root stays on the encounter's planned path.
- Give each finished frame explicit trim bounds and pivot. Do not recalculate
  the pivot from changing alpha bounds: coat, tail and trunk motion must not
  slide the entire actor.
- Track hand, muzzle, knee, trunk, tusk tip and paw contacts as appropriate to
  the family. Emit particles from the displayed pose, using the same camera,
  roof registration and screen-shake transform as the body.
- Interpolate visible motion between the source positions. Reset interpolation
  at boarding, split/merge, removal, restore and other discontinuities rather
  than drawing a long slide between unrelated coordinate systems.
- Select gait from travelled distance and contact phase; stop on a planted
  pose. Keep presentation randomness separate from source RNG. Exact frame
  durations and amplitudes remain artistic tuning proposals until measured
  in native playback; no invented timing constants are prescribed here.
- Respect active pause, focus pause and restoration. New Game and restore must
  clear or restore transient animation state consistently, as with the existing
  effects. Count losses must not be delayed by a death animation.

## Remaining families found in the runtime inventory

| Family | Where it appears | Next design work |
| --- | --- | --- |
| Railway workers/miners | Static figures in worksite/mine scenes; environment effects already separate | Tool lift/contact/recovery, carrying, breathing; anchor dust to actual tool contact |
| Nomads/hunters | `assets/world-events/nomads.png`, `mammoth-hunt.png` | Separate figures, gestures, load/animal motion and herd poses without changing scene composition |
| Mole creatures | `assets/campaign/mole-ambush.png` | Emergence/staging keys, figure movement, separate ground/snow layers |
| Whale/harpoon scene | `assets/campaign/whale.png` | Body/water response and source-event staging; inspect original scene before defining an attack cycle |
| Captain/Kolotov, civilians and story characters | Boudoir, command, city and campaign plates | Scene-by-scene figure audit; restrained breath/gesture layers tied to existing actions |
| Map representations | `map_entities.gd:56` currently draws cities/enemy locomotives | Audit source visibility and icon scale before adding animated fauna or spy symbols |

The earlier master contains unused planting, climbing, wolf and worker poses.
They are useful costume references, not connected animation cycles. Source
`tasks/evidence/combat.md:33` documents unit actions and original sprite
coverage; it does not supply the final modern animation cadence.

## Opus completion and acceptance

1. Review these silhouettes with the owner, especially the new spy costume.
2. Redraw/polish frames at the actual target lattice; complete missing views,
   action branches and transitions. Reuse coherent body identity across poses.
3. Export clean RGBA sheets plus explicit frame rectangles, pivots and attachment
   metadata. Check anatomy, boots/paws, asymmetry, scale drift and alpha halos.
4. Wire presentation to actual runtime events and separate encounter layers.
   Preserve source rules, RNG and Opus's existing train/weapon motion design.
5. Capture full native loops in context: start/stop/turn, roof boarding, melee,
   demolition, group changes, pause/focus, save/restore and new game. Check
   picking against the displayed body and feet on the drawn roof/ground.
6. Compare identical source input/seed state with animation on/off and across
   tested display rates. Measure CPU/GPU costs at dense real encounters before
   stating any performance result. Show complete playback for artistic review.

This design pass leaves implementation and artistic acceptance to Opus and the
owner. No runtime test or Windows execution is claimed for new sheets.
