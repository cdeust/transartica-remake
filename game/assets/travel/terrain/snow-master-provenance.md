# Authored snow master

New image_gen artwork generated4October2026, copied without edits from candidate
`output/imagegen/world-map-20261004/snow-master-v2-candidate.png`.
SHA256: `e4889d41b250181b99ae20f8e678133edac056dcb5092f6e514dfc6677c91b41`.
Dimensions1254×1254, fully opaque. No historical pixels supplied or sampled.
The terrain builder verifies the committed master rather than regenerating snow.
The unchanged travel_ground.gdshader repeats the image in world coordinates and
multiplies its palette; raw PNG colors therefore differ from displayed colors.

Source and byte-identical production have measured opposite-edge mean RGB
channel differences8.543062200956937 horizontal and9.807814992025518 vertical,
versus interior adjacency5.074783411890145 and5.082164739765445.
These are observations on0..255 RGB channels, not acceptance thresholds.
Seamless repetition and suitability behind the train require native inspection.
The former256px procedural material measured0.1640625 horizontal wrap and
0.13541666666666666 vertical wrap, versus0.20881331699346406 and
0.7568525326797385 interior adjacency. Candidate and production are independently
measured in output/imagegen/world-map-20261004/integration-measurements.json.
The former snow-material.png remains for historical reference and comparison;
export logs and its import descriptor still reference that path.

## Generation prompt

Use case: stylized-concept. Asset type: one production candidate square repeating terrain tile for a modern detailed pixel-art train strategy game. Primary request: packed snow seen directly overhead in orthographic top-down view, filling every pixel edge to edge. Calm cool blue-gray snow palette, warm ivory highlights, muted slate-blue shallow shadows, consistent with highly detailed dark steel-and-brass pixel-art trains. Crisp deliberately placed pixel clusters, fine granular ice and occasional tiny glints, subtle wind-shaped drifts and small shallow depressions. Rich restrained material detail without becoming visually busy; gentle even illumination, no focal object. The four edges must tile seamlessly, horizontal and vertical periodic continuation, consistent tonal density across opposite edges; no vignette or border. Avoid trees, rails, rocks, buildings, footprints, tracks, horizon, sky, text, symbols, regular diagonal grids, aggressive noise, deep pits, smooth painted gradients, photographic texture. Opaque background, snow only. Deliver one square texture, not a sheet or tiled preview.
