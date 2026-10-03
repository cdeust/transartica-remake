# Overview presentation correction, 3 October

Owner screenshot23:31:33 shows the actual general-plan panel: blue material,
thin cyan rails, flat blue town boxes and unreadable dark source components.
The correction is confined to overview_chart_art.gd and its screen-space scale
label call in ecs_overview.gd. No input, calendar, discovery or network code changes.

The paper is an AtlasTexture of the unchanged modern panel clock interior
(source rectangle60,320,200,180, measured in clock-quality-20261003.md).
Dark ink and brass reuse the modern panel palette. Rail endpoints stay exactly
as exported; only their authored strokes change. The existing landmarks master
supplies one neutral town silhouette, fitted inside each measured town box.
Unknown source components receive generic chart studs inside their bounds.
These studs do not claim that an undecoded component is a mine, depot or city.
No city name is inferred from proximity to a live map anchor.

The private resource192 geometry remains unchanged:947 routes,1046 compartment
strokes,45 town boxes,206 dotted marks,10 symbols and114 other components.
It remains the deliberately incomplete original static plan. The helper does
not read CARTE railway topology or discovery state. The original marker axes,
lens clamp, inspection offsets,3px border and compass footprint are preserved.
The scale label retains its measured cartouche and now draws at screen font size.

## Verification

- test_overview_materials-modern-chart.log: PASS, unchanged inventory and town
  centers, artwork confined to source bounds, existing authored paper and resize.
- test_authored_overview-modern-chart.log: PASS, absent original RGB, static
  inventory, marker axes, lens input and immutable live network.
- test_ecs_overview-modern-chart.log: PASS, unchanged historical RGB API/schema/hash.

Logs are private under reference-private/validation. Godot's first material-test
run exited0 despite a GDScript type-inference parse error; that run is excluded.
The test was corrected and rerun with an explicit PASS confirmed in its log.
The macOS certificate warning remains unrelated to these rendering tests.

Native visual acceptance is pending root's reload and actual general-map click
from the earned campaign. These headless checks do not prove visual quality,
all world routes, complete campaign play or Windows execution.
