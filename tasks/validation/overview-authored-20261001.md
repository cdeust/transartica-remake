# Authored original static overview

Default: newly authored cold paper/material, metal ink routes, blue town marks
and chart frame. Historical resource192 RGB only draws with
TRANSARTICA_REFERENCE_UI=1. Its exact decode/load/hash API remains unchanged.

The initial complete-CARTE rendering was rejected and removed before acceptance:
the static overview deliberately omits routes. Current helper never consumes
CARTE.FIC, live rail ports, live city anchors or discovered cells.

## Source inventory

Primary evidence: map-orientation-audit.md, private decoded-general-map-screen.png,
CARTE resource192/palette196 and private general-plan.json. Coordinates remain
320x149 east-right/south-down; marker(2*x+2,2*y+3), lens and click offsets unchanged.

Inspection measured index10 winding olive route strokes;11 compartment lines;
14 has45 filled5x3 town boxes,206 isolated dotted-route marks, ten9px symbols,
and69px scale cartouche(41,136,26,11). Classification combines viewed original
and measured shapes; palette14 alone is not labeled as water/towns. Symbol,
depot and underground meanings are not inferred. Dark marks are measured
separately; town shadows, original scale lettering and compass bounds
(291,104,29,27) are excluded from replacement-site marks.

tools/export_overview_geometry.py collapses collinear route/compartment strokes,
retains static town/dot/symbol bounds and source SHA256. Its ignored output is
reference-private/overview-geometry.json, containing947 route vectors, no RGB,
palette, rows or CARTE bytes. Reconstruction tests compare every route/grid
source point exactly: no omitted/added static geometry. No missing route is
inferred from the detailed map. Full derived geometry remains private.

The supplied1774x887 chart master is copied byte-identically. Full-master overlay
hid edge towns in the first native review; measured straight bars now fit the
original3px border, with authored compass in the measured original footprint.
No plan shrinking/movement. Ice material/inks are authored presentation assets,
not gameplay constants or a recolored source bitmap.

## Verification

- overview-reference-api-20261001.log: unchanged RGB hash/schema/marker API PASS.
- overview-geometry-test-20261001.log: source vector inventory reconstruction PASS.
- overview-authored-test-20261001.log: absent RGB/static towns/dots/marker/lens
  and immutable gameplay network PASS.
- overview-pck-build/runtime-20261001.log: actual isolated PCK executes with
  private vectors/authored textures and BOTH original plan paths absent.
  This proves packaged loading, not Windows executable execution.
- overview-authored-native-20261001.log and authored-overview-native-20261001.png:
  actual root app native, source start marker26,127, lower instrument strip.
  Initial unsized capture was blank despite false PASS; replaced after explicit
  1280x720 size and blank-body assertion. No acceptance relies on that capture.

Builder: run private plan exporter, run tools/export_overview_geometry.py,
copy only overview-geometry.json into ignored game/private-data. Never package
the original RGB plan. Whole visual inventory, Windows runtime and full Noita
material physics remain outside this bounded proof.
