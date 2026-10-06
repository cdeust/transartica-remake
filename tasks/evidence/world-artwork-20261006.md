# World artwork registration

Owner6October2026 requests exterior and menu map artwork coherent with city scenes. The original CARTE map spans160×73 cells (FORMAT-CARTE.md). Exterior preserves its existing square cell projection and all rail/vehicle transformations. The menu preserves original source mapping(2x+2,2y+3), its incomplete static routes and interactions.

The registration guide reads source terrain associations already documented in world-terrain.md: mountains86..105/142..146, water106..115/135..140, forest116..132, city footprints71..76. It contains no original pixel art. The generated world painting follows that guide and uses the accepted industrial city as a style reference. No rails or buildings are baked into the ground. Interactive layers remain source-registered above it.

The finite ground painting and menu version use the same master. Generated artwork is a visual interpretation; exact shoreline and special obstacle logic remain in separate source-registered layers. Native comparison and measurements are recorded below.


## Delivered registration and native verification

Production uses the full1857×847 master (SHA25691f2ec05ab73f54da25a8e0c5f45bad475cd30e8c18fb849aea9d23f7c4987b4) and all eight1312×1199 v2 regions. The v1 regional generations were rejected. Production v2 copies match the supplied files byte-for-byte and are imported by Godot. The original-source registration measurement is retained locally in the Claude review folder. Coarse masks additionally bind to imported RGBA hashes; invalid metadata preserves the source relief. Of1796 source forest/mountain cells,1012 receive measured artwork replacement and784 keep legacy relief, including partial-row and feather borders. Dark masks cannot distinguish forest from rock or establish exact silhouettes. Regional edges fade over16 texture pixels onto the master; this reduces contrast without proving seamless joins.

The148 focused artwork checks load actual imported textures and exercise stale hashes and missing metadata. Five existing travel/overview/discovery suites pass. The independent reviewer approved source integration and exported resource contents. Both public packs contain782 files, all new textures and authored JSON, no forbidden private paths and no matching original-payload hashes.

Native prepared scenes cover snow, mountains, lake, forest, city and overview. Their captures are under tasks/validation/world-artwork-native-20261006. Prepared foreground comparisons use the unchanged earned46342 composition with connected source histories, not a new campaign playthrough. Actual changed pixels beneath train alpha at the six mouths are224,199,199,221,221,221; forest32,11 gives4785. Save snapshots, network bytes, train poses and the input-file SHA remain unchanged. Root visually inspected the forest and south-mouth captures. The foreground tool fails on hidden/modal views or zero covered train pixels; its low-processor mode is disabled only for capture synchronization.

The actual exported macOS binary was launched with a project-local private pack. Normal OPTIONS/book input restored FINALQG at(152,66), cycle43123,23 vehicles. Exterior input47213 and menu toggle47215 displayed both artworks. Captures public-exterior.png and public-menu.png are retained beside the prepared scenes. The music preference switched off/on through actual OPTIONS input47218/47219. This does not establish a Windows executable launch.

Visual acceptance remains pending. Close exterior zoom exposes coarse painted pixels and retained relief can appear superimposed on painted hills. Regional joins and approximate registration require Claude/owner review. Menu input and source routes remain operational; these technical checks do not claim city-level artistic quality.
