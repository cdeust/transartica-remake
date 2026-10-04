# Underground presentation audit,4October2026

The English ECS manual, private observations/combat-20260927/manual.txt
lines586..591, describes dotted underground routes, sometimes double speed,
and Mole Men attacks. Lines699..706 describe the attackers and bomb inspection
cars discouraging attacks. These mechanics already exist in the remake.

TIME0x0486..575 reads the current absolute tile and doubles speed for38..52
and55..57, plus directional crossings15/16. RailNetwork.progress_speed mirrors
those conditions. Crossing15/16 is not globally classified as underground.
TABLE0x463..4b7 supplies seven mole sites:50,44;74,38;92,57;83,27;44,59;
5,28;66,40. Every one is on original tile38..41. CampaignHazards.player_mole
implements TIME0x2687 cooldown and rnd6; CampaignFaunaSession.before_fauna
invokes it before entry. No new risk probability or geography is added.

The decoded private CARTE atlas has explicit mouths53,54,58. Pixel inspection
and original neighbors establish orientation toward surface track:

| Code | Mouth faces | Original cells | Ice-covered neighbor |
| --- | --- | --- | --- |
|53|South|61,51|North52 at61,50|
|54|West|30,58 and51,39|East50 at31,58 and52,39|
|58|East|12,21;105,23;113,58|West56 at11,21;104,23;112,58|

These six mouths run at ordinary speed and remain opaque. The original map
contains220 tiles38..58 total; six are mouths. Remaining38..52/55..57 form
the underground/covered approach presentation set. Scenery80/147 is unrelated
decorative vertical passage artwork; it does not replace those six mouths.

Identified gaps: TravelWorld drew the underground set with identical full steel
rails;53/54/58 had rail ports but no terrain portal; TrainRenderer used white
opaque tint everywhere. The existing landmarks-master last frame depicts a
closed gate without entering track. Reusing it as an open rail mouth needs
artistic review; no claim that its gate is a traversable opening is made.

Owner requests slight transparency underground. No exact original alpha has
been established. UndergroundVisual classifies source tile sets; each vehicle
uses its actual sampled rail midpoint independently, so surface wagons remain
opaque while other wagons are underground. Registration/chord dimensions,
animation and shaders remain unchanged. Root inspected native prepared0.75/0.85 comparisons and selected0.75 on4Oct:
passage distinction was more visible while convoy shape remained legible. This
is an authored presentation choice, not original alpha evidence.

test_underground_visual checks source sets, six mouths/orientations, seven mole
sites and independent tints. test_train_renderer checks rigid pose history.
review_underground_transparency creates prepared native artwork comparisons
from an earned-save composition placed on source-map fixtures. It verifies
state and geometry remain unchanged; these captures do not prove traversal.
Actual full forward/reverse entry, tunnel and exit runs remain root-owned.


The new open-mouth master is copied byte-identically from the root-owned
image_gen atlas (2014×781, transparent), SHA256
3257c10443d3c9dc1832c29d1e373808a00d0079b4202b009aa7d65cebab3427.
Generated prompt/provenance are root-owned in output/imagegen/underground-20261004.
underground-mouths.json records the three inspected external rail sections,
selected highlight coordinates, centroids, gauges and authored floor anchors.
AtlasTexture regions clip only the external stub beyond its measured section,
so the neighboring full surface rail does not receive duplicate embedded track.
Similarity registration rotates each actual rail axis to its source orientation
and scales its perpendicular gauge to the existing20px rail gauge. Each measured
external section lands exactly on the original cell's surface port. No map,
source ports, vehicle chord or simulation rule changes.

TerrainPortals draws underground alignments with authored steel-colored stipple
along the same source center/port segments. TravelWorld skips full steel rails
only when this helper owns the drawing. Texture loading uses imported resources
in exported builds and a raw fallback for authorized pre-import comparison.
Headless registration tests passed exact section-to-port and20px gauge checks,
as did existing train renderer and terrain obstacle regressions. Corrected
prepared native captures showed all21earned-composition wagons after waiting
for actual map layout and constructing an explicit source-connected history.
Snapshots and rigid geometry are checked unchanged between alpha candidates.
This is artwork evidence; actual forward/reverse tunnel runs remain outstanding.


## Earned native forward passage,4October2026

Root drove the existing campaign through mouth51,39 to113,58 using actual
viewport inputs, without injected position or resources. Native10904 records
entry (52,39,cycles9233);10957 shows all21vehicles tinted underground at68,40.
11105 records locomotive emergence at114,58,cycles9434;20vehicles were still
underground, so this was not full emergence. Root then drove to132,63. Native
11193/11194 records cycles9518,21vehicles and all vehicle contacts on surface
track; the last rear contact is118.069,58, beyond the east mouth. All recorded
vehicle-frame tints are opaque. Root inspected11194.png.

Captured actions and screenshots are in tasks/validation/continuous-play-20261003;
actual F5 saves stay private under.cache/native-play/saves. The64-cell forward
tunnel passage encountered no Mole Men attack. Reverse traversal, the other
two passage pairs and native attack coverage remain open.


## Earned native reverse passage,4October2026

Root used the actual reverser at11195 after full east emergence. All21contacts
remain identical to11194; the spy wagon becomes the leading physical endpoint.
11300 records return to113,58 (cycles9634); the64source-cell itinerary reaches
51,39 at11437 (cycles9837), then49,39 at11447 (cycles9847). All21vehicles
remain rendered and opaque at11447; root inspected the native screenshot.
Their surface positions follow the unchanged source21 switch at49,39 through
48,38 and48,36 toward49,35. Both independent core reviewers confirmed this
is legitimate: the leading tail clears the mouth before the trailing locomotive.
Root initially mistook this order for an incorrect branch and withdrew that
diagnosis after comparing earned saves11194/11195/11300/11437/11447.

This validates one passage pair in both travel modes. No Mole Men encounter
occurred during this return. Other pairs, risk encounters and late changes to
already occupied switches still need coverage. Current party is paused11447.
