# Interactive wagon masks

## Current revision after renewed owner rejection

The previous masks were rejected again as approximate. Their earlier visual
review was insufficient: authored vertices were inside clothing or outside
objects, and freezing a polygon's eroded interior prevented correction.
Historical GrabCut sections below describe the superseded attempt.

All eight current masks use measured source-pixel anchors and edge paths
between adjacent anchors. Source PNGs and the chaufferie shader are unchanged.
The OpenCV IntelligentScissorsMB defaults are used without tuned thresholds;
API and default-feature evidence: https://docs.opencv.org/4.12.0/df/d6b/classcv_1_1segmentation_1_1IntelligentScissorsMB.html .
Search radii and locked low-contrast edges are authoring guides, preserved in
`tools/wagon-mask-guides.json`. Clipped canvas boundaries are straight; pipe
and officer occlusions are subtracted before lossless binary SVG output.

- Kolotov: restore outer white sleeve, trousers, cuffs and shoe; exclude wood
  at the neck and chair at the trousers. Remove an invalid internal book anchor.
- Open book: recover the upper right page and cover; remove wood above the page.
- Revolver: retain the sight, hammer, silver trigger and black grip rim.
- Operator: remove floor by the front toe and trace visible boot edges. Restore
  the dark rear boot shaft; exclude only the narrow confirmed floor sliver.
- Map: recover the outside wooden right frame and correct the two snow peaks.
- Officer: recover complete epaulette and outer fur edge; retain window gap.
- Both stoups: trace stepped rims and bodies; retain the pipe exclusion.

Source-coordinate regressions now fail on the old masks and pass on the new:

| Mask | Source point | Required coverage |
| --- | --- | --- |
| Operator |175,772| Black: floor beside toe |
| Book |1350,634| Black: wood above page |
| Book |1430,630| White: upper right page |
| Kolotov |422,488| White: outer sleeve |
| Kolotov |364,419| Black: wood beside neck |
| Map |1195,575| White: wooden outer frame |

Before: native test exit1 with these six contour failures, saved in
`validation/wagon-hover-contour-before-20261002.log`.
After: native test exit0, including eight highlights, two viewport sizes and
existing click/clear/modal assertions, saved in `validation/wagon-hover-native-20261002.log`.
The final boot-shaft sample256,698 is also white in the native test; the old
mask was black there. This additional before/after pixel measurement is in
the report. Enlarged boot review prevents confusing dark leather with a gap.
Fourteen native source/shader crops were regenerated and visually inspected.
All eight output hashes match a second generation after the final code edit;
binary coverage, source hashes and changed pixel counts are recorded in
`validation/wagon-mask-measurements-20261002.json`.

Owner visual review is still required before the requested commit. Neither
these sampled points nor an automatic edge path establish a complete
pixel-perfect ground-truth silhouette.

Final source/craftsmanship gates report zero findings. The revised gallery was
opened for the requested pre-commit review; images carry content-hash queries
to avoid stale captures. No files were staged or committed. The registered41MB
temporary directory `.cache/disk-hygiene-lzeq2ee1` was disposed after preserving
evidence; its absence and absence of owned test/capture processes were verified.
Existing worktrees and other sessions' files were retained.

Raw request: "While he works on this, you can create the masks for the boudoir, and the other interactive wagon"

## Binding

| Reference | Actual artifact | Evidence |
| --- | --- | --- |
| Boudoir | `game/scripts/boudoir_screen.gd`, `game/assets/boudoir/captain-boudoir.png` | Renderer loads that PNG; regions10–13 address stoup, Kolotov, revolver and save book |
| Other interactive wagon | `game/scripts/general_quarters.gd`, `game/assets/boudoir/general-quarters.png` | Renderer loads the command-table interior; regions10–13 dispatch to `quarters_actions.gd` |
| Existing selection masks | `game/assets/engine-room/engineer-mask.png`, `interface-mask.png` | `engine_room_art.gd` builds hover overlays; `object_hover.gdshader` reads mask red-channel coverage |
| Possible animation masks/layers | People and objects painted into the same two interior PNGs | The images contain no separate runtime layers; previous actor handoff describes extracting subjects and repairing plates |
| Opus work in parallel | Actor animation finalization in `tasks/handoff-actor-sprites-opus-20261002.md` | Owner's preceding request; preserve existing gameplay and motion design |

Owner clarification: "all of them should have the same surbrillance layer that
the chaufferie is having". Produce hover-highlight silhouettes for all eight
interactive subjects and integrate them with the existing chaufferie shader.
Animation cutouts are not part of this request.

Symptom: both wagon interiors currently use broad rectangular hit regions on
flattened artwork, with no corresponding silhouette masks.
Goal: supply registered masks for the existing interactive subjects in both
interiors and show the same golden hover outline/fill as the chaufferie.
Non-goals: new gameplay actions, altered original story, unrelated actor work,
remote publication or replacing the existing interior composition.

## Prior evidence and constraints

`tasks/evidence/boudoir-layout.md` distinguishes the actual boudoir from General
Quarters: the command-map room must not replace the captain's room. Original
bitmaps remain private; the supplied remake PNGs are the production references.
`output/imagegen/engineer-mask-prompt.txt` requires masks at the exact original
canvas coordinates, including visible occlusions. The existing shader expects
coverage in the red channel, not transparency alone.

Cortex recall tools are unavailable in this session. The supplied project
instructions, local memory registry and repository evidence were consulted.
Relevant history: 4221c39 established the quarters navigation/interior redraw;
f589e4f completed campaign and shared locomotive presentation.

Strategy: context_engineering binds the real textures and consumers;
verified_reasoning checks measured image dimensions and registration against
those source pixels. Acceptance must include an actual image/tool comparison,
not a claim that a generated silhouette is automatically exact.

## Source object inventory

| Scene | Code | Existing action | Visible subject |
| --- | --- | --- | --- |
| Boudoir | 10 | Stoup | Small cup at the far lower left |
| Boudoir | 11 | Inventory/Kolotov | Seated secretary, with visible clothing, hands and held book |
| Boudoir | 12 | Revolver confirmation | Revolver on foreground desk |
| Boudoir | 13 | Save | Open book on foreground desk |
| General Quarters | 10 | Stoup | Metal cup at lower left |
| General Quarters | 11 | Spy menu | Radio operator at left |
| General Quarters | 12 | Overall map | Central relief map/table |
| General Quarters | 13 | Inspection-car menu | Foreground officer at right |

The regions encode runtime actions. Inclusion of chairs, table rims, carried
items and decorative lamps must follow the selected use and actual source
silhouettes; do not add interactive decoration merely because it is visible.

## Plan

- [x] Bind scenes, actions, existing shader and source PNGs.
- [x] Confirm mask purpose with owner: same hover highlight as chaufferie.
- [x] Create registered subject masks/layers without changing source art.
- [x] Measure dimensions, channels and subject bounds; inspect overlays.
- [x] Integrate the existing highlight shader and validate native resize/input.
- [x] Preserve authoring guides, source hashes and inspection results for Opus.

## Acceptance contract

Owner rejects approximate masks: "les masques sont tres approximatifs, on doit
mieux calquer aux elements". Stop treating coarse silhouettes as completed;
inspect enlarged source/mask overlays and refine visible subject edges.

Every output must match its source canvas size, be linked to the exact source
hash and have a clear action/object identity. Inspect mask-on-source overlays
for shifted outlines, unintended furniture and occlusions. For selection masks,
the image coverage must be suitable for the existing red-channel shader.
For animation cutouts, extracted art and any repaired plate must register to
the source before an animator moves anything. No exact-pixel or runtime success
claim without the corresponding measured/image/native evidence.

## Review — 2 October 2026

Eight masks are integrated under `game/assets/boudoir/masks/`. Both interiors
use `wagon_hover.gd` with the unchanged `object_hover.gdshader`. The existing
click regions/actions are retained. Hover clears on click, exit, hide and
blocking boudoir sheets.

The rejected outlines were replaced by source-coordinate guides and source
segmentation. Authoring is reproducible with `tools/refine_wagon_masks.cjs`
and `tools/wagon-mask-guides.json`. The original PNGs retain their initial
SHA256 hashes. Each mask covers the full source canvas with opaque black/white
pixels; the SVG encodes each pixel run without smoothing or simplified paths.

Segmentation uses the OpenCV GrabCut API, initialized with foreground/background
guides. Model dimensions and five iterations follow the
[OpenCV example](https://docs.opencv.org/4.x/d8/d83/tutorial_py_grabcut.html).
Brush radii and exclusion strokes are authoring choices recorded in the JSON,
not claimed optimal parameters. Explicit corrections exclude papers below the
book, the officer from the map and furniture around the operator. The operator
was retraced at enlarged scale after segmentation lost hair, fingers and boots.

Reproduce in an owned project-local dependency directory:

```sh
npm install --prefix <directory> --cache <directory>/npm-cache @techstark/opencv-js@5.0.0-release.1 @resvg/resvg-js@2.6.2 pngjs@7.0.0
node tools/refine_wagon_masks.cjs <directory>
```

The foreground officer is generated before the map that excludes him. Optional
third argument selects one mask; regenerate its occluder first when changed.

Verification:

- Native `test_wagon_hover.gd`: PASS at1440×900 and1000×800; eight rendered
  highlights, unchanged shader, GUI handlers, clicks, clears and modal blocking.
  OS GUI routing is disabled in this fixture to isolate explicit handler events.
- Native full-app `test_boudoir.gd`: PASS; real injected input, inventory,
  save/load, navigation, pause and revolver end-game.
- `test_quarters.gd`: PASS; existing action/menu and stoup contracts.
- Eight regenerated mask hashes identical; final operator regeneration also
  identical after its last contour correction. Opaque binary channels, sizes,
  source hashes and subject bounds measured in
  `validation/wagon-mask-measurements-20261002.json`.
- Eight final source/overlay crops inspected. Review them in
  [the comparison gallery](../output/wagon-masks-20261002/index.html).

Native evidence: `validation/wagon-hover-native-20261002.log`,
`validation/boudoir-masks-regression-20261002.log` and
`validation/quarters-masks-regression-20261002.log`. Full-room captures are
`validation/wagon-hover-{boudoir,quarters}-{10,11,12,13}-20261002.png`.

Artistic acceptance remains with the owner. This revision has been inspected,
but no independently measured pixel-perfect ground truth exists for painted
shadow transitions. Changes are local and unpublished.

Source-discipline and craftsmanship checkers pass with zero findings. Final
regeneration matches all eight hashes in the measurement report. The registered
43MB temporary directory `.cache/disk-hygiene-4iizwj2q` was disposed after the
gallery and evidence were preserved. Its absence and absence of owned test/
inspection processes were verified; existing worktrees were retained.

## Renewed contour review after premature stopping

Owner correction: "et pourquoi t'etre arreter en chemin ?". Functional test
success had been treated as a stopping point despite remaining visual errors.
All eight source/overlay comparisons were reopened.

| Subject | Visual review outcome |
| --- | --- |
| Boudoir stoup | Rim/body follows cup; wall outside silhouette is excluded |
| Kolotov | Clothing, hands and held book retained; armchair excluded |
| Revolver | Barrel, grip and trigger guard retained; trigger opening excluded |
| Save book | Pages, cover, ribbon and overhanging pen retained; loose papers excluded |
| Quarters stoup | Pipe exclusion extended through the visible cup interior; dark left body and outside right lip retraced at3× |
| Radio operator | Enlarged guide review retains hair, fingers, both boots and the gap between legs; stool excluded |
| Relief map | Map/frame retained with officer exclusion regenerated; guide extended to canvas edge. Previous output already reached row863, so no former output truncation is claimed |
| Foreground officer | Wood between sleeve and coat was incorrectly covered; corrected contour and explicit background seed remove it |

Two enlarged evidence crops were added to the gallery: `officer-gap-detail.png`
and `stoup-detail.png`. Negative pixel assertions in the native hover test now
check that the window wood and occluding pipe remain black while adjacent coat
and cup body remain white. The final test passes with those assertions, eight
rendered highlights, two window sizes and the existing clear/modal checks.

Source/overlay images are visual inspection evidence, not a numerical claim of
pixel-perfect ground truth. Updated output hashes and binary coverage are in
the measurement report. Missing trooper-pose generation proceeds separately
under `tasks/handoff-trooper-poses-codex-20261002.md`.
