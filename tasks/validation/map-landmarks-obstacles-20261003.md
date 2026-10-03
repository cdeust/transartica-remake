# Map landmark and obstacle integration

Local implementation; native map review remains with the active game owner.

Original identities were checked in `reference-private/map-resources.json` and
`reference-private/validation/map-landmark-source-20261003.png`. Resources 77,
81–85 and148 are snow/ice relief, not buildings;80 and147 are vertical ice/rail
passages. They use existing modern mountain/tunnel frames. Source blank and
concealed resources remain blank. Forests, traversal and map bytes are unchanged.

`terrain_obstacles.gd` draws 67/69 broken crevasses and 63/64 repaired bridges,
with source lake states 114/140 and 139/135. The existing isolated modern
crevasse/lake material remains a rail-free fallback. Valid authored frames own
their rail artwork; the world rail consumer must consult `handles_rail(code)`.

The six-frame generated atlas is copied byte-for-byte from
`output/imagegen/world-map-20261003/obstacles-master.png` to the terrain assets.
SHA256: `bb2942a78ed9a9892f0cca7cceda3ce0729dccd6154bd7304a42cdc5151ea174`.
It has 605026 alpha-zero pixels of 1572864; gutters/corners sampled alpha-zero.
Subjects mostly alpha 251–253, maximum 254. No threshold, matte removal or
redrawing was performed. Alpha counts and source rail samples are retained in
`obstacles-atlas-alpha-20261003.json` and
`obstacles-rail-source-pixels-20261003.json`.

## Registration format

`game/assets/travel/terrain/obstacles.json` gives each crop `[x,y,width,height]`,
two **crop-relative** source rail ports and measured rail-head center spacing.
Ports map to the source tile's two opposite rail boundaries. Across-axis scale
maps measured gauge to the existing 20px world rail gauge; along-axis scale maps
the actual opposing rail ends to one tile. Frame centers are never anchors.

Measured EW rail heads: top 221/bottom 251 on three top frames, spacing 30px;
lower lake 711/740, spacing 29px. NS heads 243/278 and744/780 give 35/36px.
Rail endpoints were checked against source alpha and RGB. Top EW end ranges
32..482,535..992,1047..1506; bottom lake 1026..1509. NS ends begin 493/494 and
finish963. Crops split at y480, preserving NS rail ends that a nominal 512px
row split would cut. NS lakes reuse their corresponding EW artwork by rotating
the measured registration; lighting rotates with it and awaits native review.

## Verification

Godot 4.5 headless import completed. `test_terrain_obstacles.gd` passes actual
atlas load and registration, visible states, malformed metadata rejection,
source relief identity, blank exclusions and unchanged map bytes.
`test_travel_terrain.gd` passes existing scenery coverage and rail separation.
Both runs emitted the sandbox macOS system CA-certificate diagnostic, with no
script errors and exit 0. These tests do not establish native visual acceptance.

Water, snow ground and station refinements belong to the parent/coordinated
owners. This pass is not a claim that the full world art review is complete.
