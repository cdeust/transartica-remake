# Launcher and worksite ambience validation

Pinned Godot4.5 (`876b29033`), native macOS OpenGL4.1 renderer on Apple M4,
1280×800 viewport. Source base `79c80b2`; living-effects worktree changes local.

Commands, executed from the worktree:

```sh
.toolchain/Godot.app/Contents/MacOS/Godot --headless --path game --script res://tests/test_ambience.gd
.toolchain/Godot.app/Contents/MacOS/Godot --path game --script res://tests/review_ambience.gd
```

Measured results:

```text
PASS: ambience 72 source isolation and phase checks
PASS: native ambience 30 checks
```

The model test traverses original arming, launch, ascent, flight, impact and
report callbacks. Every observation preserves launcher and enemy snapshots.
The real Main fixture opens purchased launcher equipment, arms and fires through
production actions, reaches a homing impact and checks that presentation alone
preserves the complete session snapshot, including gameplay RNG and cargo.
Actual F6 input opens OPTIONS and freezes launcher particles and emitter ages.
Mine and accepted crevasse work screens freeze their visual clocks under OPTIONS.
Work presentation preserves rail debit, countdown and the complete saved state.
Question screens emit no work particles; accepted work emits dust and sparks.

Successful save restoration of a visible paused launcher clears old missile
transients while preserving its source pause state. Before correction this
regression reported `FAIL: native ambience 1/30`; after adding launcher cache
reset to successful restore/New Game, the native command exits0 with30checks.

The mine report uses illustrative report data in the production screen. This
fixture does not prove prospecting economy. Existing world-actions tests own that
source behavior. The crevasse fixture uses actual cell(83,67), original rail/slave
requirements and production ask/accept, with supplied fixture cargo. It does not
claim that equipment was earned through campaign play.

Native captures:

* [Launch](living-rocket-launch-native-20261001.png)
* [Ascent](living-rocket-ascent-native-20261001.png)
* [Flight](living-rocket-flight-native-20261001.png)
* [Impact](living-rocket-impact-native-20261001.png)
* [Report](living-rocket-report-native-20261001.png)
* [Mine work](living-mine-work-native-20261001.png)
* [Track work](living-track-work-native-20261001.png)

Direct inspection finds missile exhaust attached beneath its body and a
white-hot impact with amber sparks and dark smoke. Worksite lamps match the
illustrations. Track-work sparks initially appeared below the deck. Their
anchor was moved to measured deck contact(158,105), then recaptured and inspected.

## Authored animation recipes

Worksite art uses the existing320×149 logical canvas. Lantern anchors were
measured in the authored plates: mine(61,82),(170,96),(264,96),
works(46,84),(209,81). Work dust/sparks attach to deck contact(158,105).
Dust pulses occur every0.75s; lantern keyposes use8Hz,
matching the existing engine-room fire-keypose rate. These are artistic choices,
not mining, labour or resource simulation parameters. Emission scale0.55 for
dust and0.35 for sparks keeps activity sparse at native scale.

Launcher emission anchors follow existing BERTA launch offsets and body base
y103. Flight trails use CARTE map coordinates and the existing16pixel camera
offset. Exhaust scale0.85 for launch and0.3 for map flight differentiates the two
existing presentation scales. Impact scale1.15 produces the inspected bright
burst. These scales do not alter source geometry, hit probability or damage.

This validation measures behavior and rendered attachment. It provides no frame
cost benchmark, Windows execution proof or physical Amiga comparison.
