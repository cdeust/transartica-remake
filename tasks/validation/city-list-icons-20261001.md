# Original city list icon integration, 1 October 2026

Primary sources: `tasks/evidence/original-visuals.md`, GLIEU comp26 goods grid
and comp105 workshop icons; `tools/build_commerce_data.py` derives original
private GLIEU commerce order; runtime CityTrade.goods_name resolves goods−1.

Source IDs 1..16: RAILS, MISSILES, LINE INSPECTION CARS, ANTIQUES, PLANTS,
ALCOHOL, WOOD, GASOLINE, OIL, FUR, WOLF MEAT, SALT, FISH, MAMMOTH DUNG,
CAVIAR, FISHING RODS.

CityScreen preserves the original rows, text, stock, prices and selection IDs.
Its ItemList now receives goods textures from the authored measured atlas and
wagon textures from TacticalWagonArt. A transparent 48×16 logical footprint
contains each silhouette with uniform nearest scaling and proportional padding.
Source goods icons are 48 px wide; source workshop icons are 64×16 cells. The
common footprint, retained detail area and ItemList scrolling are authored UI
adaptations. Exact original text/price positions remain unknown according to
the source note; this change does not claim an exact original trade screenshot.

The existing playable-trip native regression passes unchanged transaction
assertions with wagon icons. The new native test checks all 16 source goods IDs,
all 25 wagon silhouettes, unchanged goods row/text mapping, and actual focused
ItemList arrow selection. Native screenshots are retained alongside this note.

Final atlas is integrated. `city-list-icons-final-native-20261001.log` passes
all 16 goods IDs, all 25 wagon silhouettes, unchanged source row/text mapping and
actual native arrow selection. `city-list-icons-final-commerce-20261001.log`
passes actual commerce/cargo/mass and station save restoration. Both contain no
errors or warnings. Source and craftsmanship gates report zero errors/warnings.
Native goods and wagon screenshots were visually inspected: recognizable icons,
readable labels and prices, preserved full silhouettes and shared hero HUD.

The loader normalizes validated integral JSON IDs before integer membership.
Godot JSON decodes numbers as floats; direct membership of 1.0 in an integer
range rejected the completed atlas before this correction. Invalid fractional
or non-finite IDs are rejected before conversion; staged textures are committed
only after the complete source ID set validates.

Independent integration review covered GameplayInput modal ownership and mapped
commands, SessionSaves atomic write/stage/commit, SaveExtensions launcher/world/
audio staging and resumed UI gates, BoudoirSession named launcher load, GameBoot
layout/startup completion, and GameReset composed state. No critical defect found
in those paths. Review coverage is limited to those paths.
The updated mammoth fair, OPTIONS combat plaque and boudoir photographs were
inspected as authored assets and use the shared locomotive. Their direct runtime
consumers remain CityBackdrop, ReceptionScreen and BoudoirScreen. Exported
executable verification is a separate pending acceptance step.
