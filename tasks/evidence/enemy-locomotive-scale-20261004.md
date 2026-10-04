# Enemy locomotive close-up correction

Owner saw oversized locomotive appearances3–4times during the native campaign. Root cause: `map_entities.gd` registered the original normalized sprite anchors but drew the full replacement hero texture with `draw_texture`. The travel renderer already uses `draw_frame`, which maps the same hero crop into the registered locomotive rectangle. Enemy visibility determines when the bad drawing appears.

Correction: use the existing shared `draw_frame` in the enemy symbol path, with unchanged positions, visibility, heading, zoom and art. No gameplay or simulation rule changed.

Regression extends `test_map_entities.gd`: actual hero assets, eight headings, zoom0.5/1/2, cell-center pixel alignment, expected cell-relative locomotive length and rigid aspect ratio. It fails before the correction and passes after. `test_train_renderer.gd` also passes. Source/craft checks both report0blocking and0warnings.

Native isolated rendering captures (not campaign progression): `tasks/validation/enemy-locomotive-before-20261004.png`, `enemy-locomotive-after-20261004.png`, and `enemy-locomotive-package-20261004.png`. Before shows the large enemy; after and exact exported package show equal locomotive sizes. Fixture `.cache/enemy_locomotive_native.gd` remains to reproduce.

Live playthrough paused24142 at94,29. Actual F524145 preserved749lignite,0anthracite,29870steam,16wagons. Rebuilt DEBUG macOS package and normal bookSCALEQA reload24154: journey,wagons,session,calendar,encounters,world all exactly match acquired24145. Initial attemptSCALESAVE exceeded the original eight-character slot limit and failed; no reconstructed state. Short name succeeds. Replanned54actions to freshA120,40. Native appsession96575; travel controllersession12339,reg60, stopunknownBAKU/TASKENT. Full campaign still unfinished.

Export ZIP SHA256: 955718b829c0de3e51d7ad4c80ec8cd73eca8a06e9a32046239cbe29c918eefa. Expanded native application retained; duplicate ZIP removed after native verification.
