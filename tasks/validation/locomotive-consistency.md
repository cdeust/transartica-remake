# Shared locomotive — 1 October 2026

Owner direction: retain the original cover's massive futuristic locomotive across
illustrations, travel and combat. Reference: Rodney Matthews, The Heavy Metal Hero,
artist's licensed Transarctica cover listing. The reference stays private.

Canonical authored sheet: output/imagegen/locomotive-20261001/design-sheet.png.
Repeated features: pointed beaked armored nose and amber eye lamps, twin tall
flared stacks, ribbed dorsal plating, sweeping horned snowplow, gunmetal rivets,
brass pipework and a glowing rear furnace cab. No historical raster is bundled
as the player locomotive.

Measurements use Pillow to inspect generated RGBA alpha>=128, without modifying
the images. Side sprite2039×771 has opaque bounds(17,36)-(2017,707); runtime crop
adds one texel fringe, Rect2i(16,35,2002,673). Top sprite793×1983 has opaque
bounds(179,49)-(615,1933); crop Rect2(178,48,438,1886). Travel fits that drawing
uniformly into the existing front/rear contact length; rigid rotation, accepted
world dimensions and rail topology remain unchanged. Composition miniatures use
the same draw_frame path. Tactical presentation preserves aspect ratio.

Replaced actual scene assets: startup, slope, whale, Urga, Sun overcast/restored,
wolf/mole ambushes and nomads. The distant Urga engine was refined after the owner's
correction to make its twin stacks, nose and plow readable. The six-vehicle combat
source sheet itself was replaced, alongside the dedicated runtime side sprite.
Prompt records and generation filenames are retained in the imagegen directory.

Native review: review_shared_locomotive.gd captures travel, common composition
miniatures, combat with the leading locomotive on screen and seven story scenes.
locomotive-native.log is clean PASS; locomotive-*-native.png show loaded artwork.
This is presentation evidence, not earned progression. Earned campaign progression
is independently proved by campaign-route-cleanup-native-after-20261001.log.

HUD baked engine plaque refinement and final exported artifact evidence are
recorded by the completion report after the last asset import.

Final audit also replaced the HUD plaque, mammoth-fair background engine,
options combat icon and four framed boudoir photographs. Exact generation
records and hashes are in final-art.json. Goods icons are a measured4×4RGBA
atlas with all16original commerce identities; runtime proportional fit is
verified by native city input/capture fixtures. Mine/track-work scenes preserve
the source interaction geometry with newly authored material-rich panoramas.
