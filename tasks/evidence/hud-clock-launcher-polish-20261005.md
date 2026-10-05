# Clock and missile command artwork

The owner rejected the thin missile icon and clock needles in native New Peking
capture45797. This changes presentation only; COMMON9, wagon13 availability,
calendar angles, Roman numeral positions and the actual cycle value remain.

The previous icon was the overhead travel wagon rotated90 degrees. Its long,
narrow silhouette fitted the slot width and left most of the button height empty.
The new transparent side-elevation illustration shows two silver/brass missiles,
a raised rack, undercarriage and wheels, matching the other three train buttons.
It is fitted uniformly to the measured train-button interior of the unchanged
original-panel-v2 raster (source rectangle750,430,226,130), independently of the
unchanged historical input rectangle. At1440×900 the painted alpha extent is
148.0063×74.21642 pixels, centred inside the illustrated button.

Clock hands are faceted brass lancets with dark outlines, separate hour/minute
widths and a turned spindle. Endpoints retain the exact existing calendar layout.
The cycle plate now sits immediately below the measured ivory dial on its lower
brass rim, so it no longer hides the spindle. Its value, caption and sizing logic
remain. Palette shading is an authored presentation choice, not a simulation rule.

## Provenance

`game/assets/interface/panel-launcher.png` was generated using the built-in image
generation tool on5October2026. References were the existing authored v2 panel
and authored wagon-catalogue13 missile wagon. The prompt requested a transparent
side elevation with two silver rockets, brass nose cones, dark blue steel,
steampunk undercarriage and no text or scene. It contains no historical pixels.
The generated alpha is preserved without image processing. SHA256:
`f3414612ffc265c34106ecc381373d873270ac6d4513fb93306ed0be3e0e67a6`.

## Verification

`test_original_panel.gd`, `test_clock_quality.gd` and `test_hud_polish.gd` pass.
The additional checks cover uniform aspect, unchanged command9, contained paint,
counter/spindle separation and numeral clearance. A real OpenGL renderer captured
0:00,3:15,6:30 and10:10 at1440×900 with no final rendering errors. Captures:
`tasks/validation/hud-polish-*-20261005.png`. The preview script is
`.cache/hud-polish-preview.gd`; final log `.cache/hud-polish-preview.log`.
Native campaign reload and owner artistic acceptance are separate verification.

Native verification6October2026: the rebuilt macOS DEBUG bundle passed codesign verification and launched through the normal game scene. The ordinary PANELQA save-book load restored the earned New Peking snapshot with campaign, journey, session, wagons, encounters, network, trade/RNG, works and launcher equal. Capture47074 shows the brass clock hands and full missile wagon inside its command plate. Capture47075 shows all six workshop goods and prices without clipping. The separate native city refusal/layout suite passes at1440×900 and1280×800. Root headless panel, clock, HUD and workshop suites all pass. Private captures remain in tasks/validation/continuous-play-20261003; no original data enters this change.
