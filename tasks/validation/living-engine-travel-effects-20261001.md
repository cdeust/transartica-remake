# Engine and travel effect validation

Pinned Godot4.5 `876b29033`, macOS native OpenGL4.1 on Apple M4.
The actual Main capture fixture uses1440×900, the current interface minimum.
No gameplay clock is advanced for visual observation tests.

```sh
.toolchain/Godot.app/Contents/MacOS/Godot --headless --path game --script res://tests/test_engine_travel_effects.gd
.toolchain/Godot.app/Contents/MacOS/Godot --path game --script res://tests/review_engine_travel_effects.gd
```

The model test produced:

```text
PASS: engine/travel effects 40 cadence and registration checks
```

At30,60 and144render updates per second, three simulated visual seconds produce
150visual ticks and identical emitter/particle dictionaries. Engine snapshots
remain unchanged. All eight moving rail headings register both stack centers
through the same rigid transform as the actual hero locomotive. Stack centers
come from the measured438×1886 hero crop:(149,1296) and(287,1296).

The native fixture verifies complete saved-state equality during visual-only
ticks, actual F6 OPTIONS blocking, hidden-travel freeze and camera/zoom mapping.
It synchronizes on rendering events before centering the locomotive, so deferred
map layout cannot invalidate the reviewed frame. Coroutine completion is checked
explicitly. Native captures show the actual engine-room valves and fire embers,
plus actual train smoke at zoom1 and2 and after a camera pan:

* [Furnace](living-engine-furnace-native-20261001.png)
* [Travel zoom1](living-travel-plume-zoom1-native-20261001.png)
* [Travel zoom2](living-travel-plume-zoom2-native-20261001.png)
* [Travel after pan](living-travel-plume-pan-native-20261001.png)

## Independent review and regression evidence

Travel initially emitted against the previous render frame's interpolation
pose. The implementation owner moved emission after `_advance_motion`, so new
plumes register against the pose that the current frame draws.

Before lifecycle correction, actual New Game and successful save restoration
left old furnace particles and world-space plumes alive. Added regression output:

```text
ERROR: restore clears unrecorded furnace transients
ERROR: restore clears old map-space transients
ERROR: new game discards prior boiler steam and embers
ERROR: new game discards prior world-space train smoke
FAIL: native engine/travel 4/27
```

That command exited4. The implementation owner added `presentation_reset.clear`
before New Game and at the end of successful save commit. Native revalidation on
the final implementation exits0:

```text
PASS: native engine/travel 27 checks
```

All four lifecycle regressions are resolved. Paused OPTIONS retains particles;
source-session replacement clears them. Module initialization binds the shared
visual clock after interface construction, once the actual view exists.

An adjacent renderer issue was reproduced with synthetic straight history
at(80,40): absolute projection and the last bisection sample could lose a valid
full-length chord through float rounding. The renderer owner corrected local
displacement projection and retained the closest valid sampled chord, keeping
the original acceptance tolerance. The effect test now runs all eight stack
registrations at(80,40) and passes40checks. Actual initial-journey registration
also succeeds. This test does not prove every world position or curve.

The worksite subclass `roamer_screen` overrode effect drawing but inherited
worksite advancement, allocating invisible dust emitters during reports.
The owner excluded nomads/mammoth-hunt modes from worksite advancement.

Final review verdict: no unresolved correctness finding in root-owned launcher,
worksite, furnace, travel-clock or session-reset integration inspected here.
Both native fixtures completed, exited0 and reported no script errors. Model
fixtures also exit0; their macOS headless certificate query emits the existing
platform `ret != noErr` diagnostic, separate from the passing assertions.

These checks do not measure CPU frame cost or prove Windows execution.
