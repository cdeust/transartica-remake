# Living effects acceptance, 1 October 2026

Common presentation API: `add(kind, point, direction, scale=1)`, `advance(seconds)`,
`draw(canvas, offset=Vector2.ZERO)`, `clear()` and `fragments(point, colors)`.
Coordinates are logical canvas pixels. Supported profiles include cannon/machinegun,
impact, destroy/dynamite/explosion/rocket-impact, rocket/rocket-exhaust, steam/smoke,
dust, snow, sparks, shot and melee. The root integrates other scenes separately.

The authored atlas contains 24 measured regions, plus explicit shock-1 and spark-1
aliases. `living_effects_atlas.gd` requires the 24 original frame identifiers and
validates finite integral regions within the image. Root owns the generated atlas
and its image-generation provenance under output/imagegen/living-effects-20261001.

Tactical source events now reach presentation before the next source tick clears
its event array. Every actual machinegun burst emits its visual event, including
misses. Cannon damage, random draws and reload clocks retain their source behavior.
Effects advance once before each source tick. Local presentation randomness never
uses the game RNG. Paused or hidden scenes freeze effects; OPTIONS continuation
retains them; opening another model clears them and disconnects the old model.

Tests compare complete combat snapshots with and without effects. Library and
actual tactical scene effect states match at 30/60/144 display Hz. Multi-tick
advances retain cannon, machinegun and impact events. Existing tactical combat and
art-cache tests pass. The audio fixture now supplies its matching original cannon
roster, as the existing train drawing requires; the native audio test passes
without script errors. Each retained test log was checked for ERROR and WARNING.

## Native visual evidence

Actual cropped body bounds register wagon effects using the same geometry as the
train drawing. Actor and dynamite control coordinates retain their source grid.
The muzzle base attaches to the gun roof and extends toward the opposing rail.

- [Cannon muzzle](living-cannon-muzzle-native-20261001.png)
- [Impact and machinegun](living-cannon-impact-machinegun-native-20261001.png)
- [Initial planted-dynamite destruction](living-dynamite-destruction-native-20261001.png)
- [Rolling flame at 0.24 seconds](living-dynamite-rolling-flame-native-20261001.png)
- [Persistent smoke at 2 seconds](living-persistent-smoke-native-20261001.png)

The native capture fixture uses actual source weapon and planted-charge events.
Its charge fixture positions the roof scanner for five successive source sweeps.
Rendering completion uses frame_post_draw; screenshot timing never decides PASS.

## Authored recipes and measurement

The 50 Hz presentation step follows the existing source cadence. Recipes are
visual authoring choices calibrated against the retained native captures:
explosion emitters last 150 ticks, impact emitters 50, gun emitters 30. Gun flashes
last six ticks. Explosion flame particles last 30 ticks; smoke lasts 100 ticks.
Flame extent is 40 by 40 logical pixels; destruction smoke starts at 18 by 18.
An explosion starts 48 particles and fracture events sample 24 actual wagon
material colors. Other bursts start 16 particles. Gravity and plume velocities
are presentation parameters; they do not claim decoded source physics.

Peak budgets are 128 emitters and 2,048 sparse particles. The Apple M4 native
benchmark measures 60 draw submissions and 120 fixed updates. Empty drawing has
median 1 microsecond and p95 2. Initial 20 by 24 flame and 10 by 10 smoke measured
peak drawing median 3,158 microseconds, p95 4,058; updates median 854, p95 1,422.
After enlarging flame to 40 by 40 and destruction smoke to 18 by 18, peak drawing
measured median 3,129 microseconds, p95 3,900; updates median 844, p95 1,432.
The small differences are measurement variation, with no claimed speedup.
Both JSON records are retained beside this report.

These measurements cover CPU command submission and sparse updates. They exclude
GPU frame time and the existing material mask's first fracture computation.
Source and craftsmanship checks report zero errors and zero warnings for the
owned presentation modules and their tests. Native captures and retained logs
bind this acceptance to the current tactical implementation.
