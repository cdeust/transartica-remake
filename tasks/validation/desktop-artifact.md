# Native desktop artifact acceptance

Owned acceptance script: `game/tests/accept_desktop_artifact.gd` (MIT). It is passed as an
absolute `--script` path; all production dependencies preload from `res://scripts`.
Tests remain excluded from the exported PCK. The acceptance script rejects the editor
binary and bundled tests in artifact mode. No `--path` fallback is permitted for
artifact acceptance.

Run the exact exported macOS executable supplied by the export owner:

```sh
TRANSARTICA_ARTIFACT_EVIDENCE_DIR=/Users/cdeust/Developments/Transartica/.cache/desktop-artifact \
  /absolute/export.app/Contents/MacOS/Transartica \
  --script /Users/cdeust/Developments/Transartica/game/tests/accept_desktop_artifact.gd
```

The acceptance script records the actual executable SHA-256, renderer, private dataset
hashes, save location/hash, failures and result in `acceptance.json` outside the
application artifact. Native viewport screenshots are `boot-title.png`, `engine.png`,
`map-scroll.png`, `options.png`, `start.png` and `resumed.png` in that directory.

Assertions cover bundled CARTE.FIC bytes, 46 cities, live campaign JSON, commerce
JSON availability, authored HUD textures, absence of private YODA rasters, and
actual viewport key/mouse dispatch through engine controls, map, strip scroll,
OPTIONS, START, F5 save and LOAD/name typing/Enter resume. Engine, train, journey,
campaign, world and rail network snapshots must restore exactly. The simulation
is frozen while input is tested, avoiding elapsed-time noise. An explicit empty
wagon fixture exercises HUD overflow and is removed by the actual START plaque;
this fixture is not campaign inventory or progression evidence.

Source-debug recovery validation on 2026-10-01 passed with native macOS
OpenGL rendering (Apple M4). The acceptance script instantiates the actual `main.tscn`,
verifies its exclusive startup screen, advances to the source title-ready state,
and waits for the original boot completion before clicking OPTIONS START.
It then exercises engine/map/scroll/options/named SAVE and LOAD through the
viewport dispatcher. Log: `world-recovery-desktop-source-20261001.log`.
Its result is explicitly `SOURCE-DEBUG` and provides no packaged execution proof.

Exported macOS artifact execution passed on 1 October 2026 using the exact
`builds/macos/Transartica.app/Contents/MacOS/Transartica` executable, with native
macOS OpenGL rendering on Apple M4. It ran without `--path`, with source-debug
mode disabled. The log contains `EXPORTED-MACOS: PASS desktop artifact acceptance`
and no error or warning. The process exited 0. The native boot/title, OPTIONS,
map/HUD scroll and resumed state screenshots were visually inspected.

Executable SHA-256:
`10c9e1e9337de1d79e123cfbdc5958ef43e60518f55188d185691313c8194e56`.
Bundled PCK SHA-256:
`e4ff856b4fa281363d66a67cea5b2199d92a8047177e20f992e51a4cbe254853`.

Durable evidence: `desktop-artifact-20261001/acceptance.json` records bundled
private dataset hashes, save hash and zero failures. `artifact-identities.json`
records the executable/PCK/script hashes, exact arguments and retained capture
hashes. Four distinct screenshots are retained: boot-title, map-scroll, OPTIONS
and resumed. Log: `desktop-artifact-exported-20261001.log`.

The registered root-owned `.cache/disk-hygiene-eh9xxvpr` remains for the root's
cleanup procedure; this worker copied the minimal evidence and left it intact.
Windows native execution: **not performed; no Windows runtime claim**.
