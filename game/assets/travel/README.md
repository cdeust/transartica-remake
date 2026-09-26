# Travel artwork

New generated assets for this project; no original game image copied into these textures.
Prompts: output/imagegen/travel-ground-prompt.txt and travel-train-prompt.txt.

ice-field.png: tiled glacial surface without a rail network.
train-east.png: transparent six-vehicle convoy, facing lower-right. The current
sprite is an artistic representation, not evidence for initial wagon equipment;
individual wagon composition/art and other headings remain separate work.

The world renderer projects original map coordinates. The ground shader uses
world-anchored texture coordinates; knowledge comes from MapDiscovery. Rails
and city markers are filtered by that same discovery model. Terrain outside it
is generic authored scenery and cannot reveal an unknown rail or location.

The train is currently one sprite. Independent wagon movement through curves,
train reorganisation and combat animations are not implemented by this asset.

vehicles-overhead.png/json: current travel-view atlas, one rigid top-down drawing
per original wagon type 1-25, built by tools/build_overhead_atlas.py from the
remake art masters in output/imagegen/wagon-catalogue-20260926/ (remake
silhouettes, not reconstructed original sprites). The older per-heading
vehicles-*.png sheets and train-east.png are no longer drawn by the renderer.
