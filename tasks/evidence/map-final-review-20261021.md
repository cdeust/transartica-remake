# Map join review, 2026-10-21

## Final result after renderer correction

The Turin defect is resolved in the inspected accelerated helper H1-3 and native
`live-boundary-captures/native-1.png`. The vertical pipes and outer wall remain
continuous at image y250. The source-texel checks below were valid, but their
earlier interpretation was incomplete: exact stored texels do not establish
correct interpolation between independently clamped textures.

An independent pixel comparison covered all 33 images in `area-metal-captures`
versus `boundary-captures`, with identical world windows and Metal backend.
It found 139109 changed pixels and **zero changed pixels outside** the union of:

- Exact reconstruction interval `37-37/(2*1206) <= world_y < 37+36/(2*1190)`.
- Existing Turin edit rectangle `[27.515151515151516,35.515151515151516,3.9696969696969697,2.9696969696969697]`.

The comparison decoded PNG channels using Python standard-library zlib and PNG
row-filter reversal. It compared every pixel, locating pixel centres using the
receipt's world window and 96px/cell density. No tolerance or expanded mask was
used. It ran read-only and exited0. Output was retained in the session tool log;
no comparison JSON was created.

The changed-pixel counts, in capture order, were:

```text
V4-1 744; V4-2 0; V4-3 0; V1-1 0; V1-2 0; V1-3 733
V2-1 0; V2-2 0; V2-3 722; V3-1 0; V3-2 0; V3-3 668
V5-1 729; V5-2 0; V5-3 0; V6-1 691; V6-2 0; V6-3 0
H1-1 2616; H1-2 2765; H1-3 100317
H2-1 2737; H2-2 2723; H2-3 2921
H3-1 2689; H3-2 2582; H3-3 2790
H4-1 2627; H4-2 2812; H4-3 2956
corner-1 1477; corner-2 1451; corner-3 1359
```

Final boundary captures H1-3, H2-1..3, H3-1..3, H4-1..3 and corner-1..3 were
visually inspected. No new clipped contour or exposed gap was found. The
earlier complete 33-image review remains applicable outside the measured band
and local city edit.

Final boundary receipt SHA256:
`e1f133f056e3c8175aeea2a8ea5de5f132ec08d93d3e15553bcc7aeecf87984a`.
Artwork manifest SHA256:
`af395bffada3efba7a4063ffdbab7757edfc7bb88c8ad67a2adf1d7dfdc70186`.
Inspected native-boundary screenshot SHA256:
`22c1c9d4b714f82094c2a4a8077f9307687126b2d57c020d57cbde5f71e7bafa`.

### Measured renderer cause

On the final factory artwork before renderer correction, RGB mean absolute
differences across native x460..639 were:

| Projection | y248 to249 | y249 to250 | y250 to251 |
| --- | ---: | ---: | ---: |
| Native screenshot | 0.102 | 13.576 | 0.307 |
| Independent bilinear model with separate edge clamp | 0.120 | 13.607 | 0.312 |
| Same two grids extended from authored source | 4.366 | 6.105 | 4.172 |
| Continuous north grid extended from authored source | 4.366 | 4.450 | 4.315 |

The clamped model matches native pixels within approximately0.25 RGB units on
sampled rows247,249,250,252. Independent edge clamping creates flat rows followed
by a hard transition. The unequal horizontal source grids contribute a smaller
phase difference. The runtime fix interpolates between adjacent boundary row
centres over their exact world interval, preserving each row's horizontal
registration. It does not mutate source artwork or choose a blur radius.

Regression test source: `native-game/tests/world_painting_join_tests.cpp`.
It uses opaque PNG crops with guard pixels, differing source densities, an
analytic color ramp, exact exterior comparisons and an underground world clip.
Root subsequently corrected fixture edge sampling and added fixture cleanup.
Root reports20/20 CTest plus accelerated fixture success. The software fixture
exposed SDL's constant-v quad optimization; root changed submission to separate
triangles. Root owns those build results and the final delivered-package launch
evidence (`live-delivered-captures/native-1.png`, exit0).

## Earlier review and diagnosis, retained as provenance

## Scope and artifact identity

Read-only visual inspection covered all 33 PNGs in project-root
`disk-hygiene-1rt4a5v8/area-captures`, at 96 pixels per world cell.
The receipt is `world-joins.json`, SHA256
`d3421aa9bd81b261a1b7734c830fab39916cffa7632e3c83eba9c5e8cebaba79`.
It identifies artwork manifest SHA256
`d483712b17eaffdd8a656a593afd375613fe9413105cd9b69e264e3b5e316f57`.
All 33 capture hashes matched the receipt. The helper renderer was software.

This review establishes visible continuity of these rendered joins. It does not
establish original Amiga artwork fidelity or gameplay acceptance. Root owns the
native UI checks and final package verification.

## Visual findings

Vertical joins are at image x384; horizontal joins are at y384. The corner
intersection is (384,384). All filenames below have suffix `.png`.

| Captures individually inspected | Finding |
| --- | --- |
| V1-1, V1-2, V1-3 | No severed tree/rock contour or exposed vertical gap. Comparison with previous 96px V1-3 shows reduced extra fleck aliasing. |
| V2-1, V2-2, V2-3 | Snow corridors and adjacent rock/tree silhouettes cross the join without a hard vertical cut. |
| V3-1, V3-2, V3-3 | Central rock column retains its contour. Small painted stones remain; extra jagged fragments are reduced against previous 96px V3-3. |
| V4-1, V4-2, V4-3 | Terrain and corridors remain continuous through the join. This terrain-only capture does not test the tunnel foreground renderer. |
| V5-1, V5-2, V5-3 | Central stippled snow remains visible. Compared with previous 96px V5-2, area sampling reduces additional aliasing without shifting silhouettes. No black gap or displaced terrain found. |
| V6-1, V6-2, V6-3 | Brighter grain along the join remains, including source-painted white stipples verified in the authored V6-2 patch. Extra aliasing is reduced against previous 96px V6-2. No severed contour found. |
| H1-1, H1-2 | Mountain/forest contours remain continuous at y384. |
| H1-3 | Turin's middle wall/roof step remains visibly awkward. It is present in the authored patch and both helper/native output. Root is replacing this local city artwork; this capture does not accept that replacement. See numeric investigation below. |
| H2-1, H2-2, H2-3 | Rock/tree groups and open snow are continuous at y384. No horizontal gap or clipped lake bank found. Portal gameplay is outside these terrain-only images. |
| H3-1, H3-2, H3-3 | Rock contours and blue crevasse remain continuous. H3-2/H3-3 retain snow stipples but no horizontal discontinuity at y384. |
| H4-1, H4-2, H4-3 | Crevasse and forest silhouettes cross the join continuously. No exposed edge in the large H4-2 forest. |
| corner-1, corner-2, corner-3 | No cross-shaped cut or exposed gap at (384,384). The diagonal corridor in corner-2 and bend in corner-3 remain connected. |

The only remaining visual blocker identified by this review is the local Turin
appearance in H1-3. All other captures remain applicable if the final edit is
restricted to the existing Turin repair mask.

## Turin: source alignment investigation

Native screenshot: project-root
`disk-hygiene-1rt4a5v8/live-captures/native-3.png`, SHA256
`8a479769728fb8a09855c947916f13ed40fe14f7ae8bf8cdaa78c06536fe7114`.

An independent Python standard-library PNG decoder compared native RGB samples
with `area-captures/H1-3.png`. Sampling every fourth pixel, searching integer
translation dx8..24, dy-145..-121:

| Native crop, half-open pixel bounds | Best helper-to-native translation | Mean absolute RGB error, 0..255 |
| --- | --- | --- |
| Upper city [420,150,640,240] | (+16,-134) | 1.088 |
| Lower city [420,260,640,330] | (+16,-134) | 0.549 |

Both halves have the same best translation. The nearest horizontal alternatives
have errors at least 5.646 above and 6.338 below. World y37 is native y250 and
helper y384. This rejects an additional live-only horizontal displacement of
the lower city. The native city annotation code
`native-game/view/world_visual_cities.cpp` draws labels and a small fallback
house; it does not overpaint a historical city image.

An independent area integration probe then decoded authored patch
`disk-hygiene-54i1ct98/art-generated-horizontal/H1-3.png` and final region-00/04.
Patch registration is world [24,33,16,8], raster1774x887, so world y37 maps to
source y443.5. For every destination texel with x index from
`ceil(28.1*region_width/40)` through `floor(30.9*region_width/40)-1`, the probe
integrated exact source-pixel overlap over the inverse-mapped world footprint.
It rounded RGB averages to nearest integer, matching the compositor contract.

| Region boundary checked | Texels | Maximum channel error | Nonmatching channels |
| --- | --- | --- | --- |
| region-00, final three rows | 270 | 0 | 0 |
| region-04, first three rows | 276 | 0 | 0 |

Thus the stored boundary city texels exactly reproduce the authored repair
source. The remaining step is not a corrupted composition or a misplaced
lower painting. Linear texture-edge clamping can still affect less than half a
source texel at the boundary; it does not explain a large horizontal shift.

Root subsequently generated a local city edit at
`/Users/cdeust/.codex/generated_images/01a15ad8-29f2-7303-af88-f927261cc9d6/exec-0bd3f9ef-bfb1-496e-b84a-f0ef1f8b1013.png`.
This was the intermediate candidate. The final result and subsequent measured
renderer diagnosis above supersede its pending status.
