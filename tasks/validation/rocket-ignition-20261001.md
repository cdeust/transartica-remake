# Rocket ignition handoff, 2026-10-01

Status: frozen local iteration after owner-reported animation bugs. Visual acceptance remains OPEN. No commit or push was performed by this agent. Base: ca1ece1b896a724d6c652e21020cb300924a5418.

## Exact implementation

- Modified `game/scripts/rocket_living_effects.gd` and `game/scripts/launcher_scene.gd`.
- Added `game/scripts/rocket_ignition.gd`, `game/scripts/rocket_ignition_canvas.gd`, and `game/shaders/rocket_ignition.gdshader`.
- Added `game/tests/test_rocket_ignition.gd` and `game/tests/review_rocket_ignition.gd`.

The ignition field advances on an independent 50 Hz visual clock, including frames where the original BERTA launch cursor does not advance. The shader receives that explicit clock rather than shader TIME. It draws a continuous granular hot core and lateral deck smoke at the measured logical deck y105. Original launch offsets and nozzle trajectory remain unchanged. Launch and ascent no longer emit the earlier small exhaust atlas; flight and impact retain their existing effects.

The shader's pigment lattice, turbulence and smoke lobes are authored appearance recipes. Their coefficients were adjusted through native phase-frame inspection; they are not physical equations, CFD, or independently established motion parameters. This iteration has no owner approval or final constant-source gate acceptance.

## Existing measured evidence

Pinned native tool: `.toolchain/Godot.app/Contents/MacOS/Godot`, Godot 4.5, macOS OpenGL 4.1, Apple M4.

- Headless `test_rocket_ignition.gd`: `PASS: rocket ignition continuous clock, source isolation and map transition`.
- Native `review_rocket_ignition.gd --before`: 43 assertions passed.
- Native `review_rocket_ignition.gd`: 48 assertions passed, including actual P-key pause and coroutine completion.
- Original BERTA callback snapshots: before 35, after 35, exact JSON equality true. Snapshots include launcher model, engine, wagons, enemies and gameplay RNG.
- Visual helper reaches the same tick 100 after two seconds at 30, 60 and 144 Hz. It advances independently while the source cursor stays unchanged.
- `git diff --check`: exit 0.

Native fixtures run the production Main launcher, source ARM callbacks and FIRE action. Phase captures are synchronized after native draw completion. Existing logs are `.cache/rocket-ignition-before.log` and `.cache/rocket-ignition-after.log`; the checks above are the retained compact results.

Before captures: [00](rocket-ignition-before-step00.png), [03](rocket-ignition-before-step03.png), [08](rocket-ignition-before-step08.png), [15](rocket-ignition-before-step15.png), [18](rocket-ignition-before-step18.png), [23](rocket-ignition-before-step23.png).

After captures: [00](rocket-ignition-after-step00.png), [03](rocket-ignition-after-step03.png), [08](rocket-ignition-after-step08.png), [15](rocket-ignition-after-step15.png), [18](rocket-ignition-after-step18.png), [23](rocket-ignition-after-step23.png), [pause](rocket-ignition-after-pause.png).

Source sequence: [before](rocket-ignition-before-states.json), [after](rocket-ignition-after-states.json).

Inspection of step08 shows a continuous nozzle-to-deck bright core, orange deck deflection and denser rolling granular smoke near the rocket. Controls remain visible in this frame. Six phase stills do not establish animation quality or resolve the owner's reported animation bugs.

## OPEN checks and limitations

- Full animation proof and owner motion-design acceptance are OPEN. No 60 Hz recording was created or reviewed.
- New shader CPU/GPU cost is unmeasured. Earlier common-effect timings do not measure this shader.
- Native save/restore and restart lifecycle for the newly added shader child are OPEN. Earlier reset tests predate this helper.
- The rocket body/nozzle still follows the original discrete 60 ms source callbacks. Presentation interpolation has not been implemented.
- Smoke is a procedural lobe field rather than persistent material simulation. It clears when the source enters the fullscreen map; lingering smoke across that transition is absent.
- The precise causes of the owner-reported animation bugs remain unresolved for the Opus handoff.

Recording-directory creation first returned `protected: overlapping registered paths`. Automatic approval review rejected the attempted shared-main-cache alternative: "The prior registration failed because the target overlaps registered paths; retrying in the shared main-cache area could mutate another session's protected workspace instead of using an isolated owned parent." Parent explicitly directed no retry or escalation. No further capture attempts were made.

Final process check: `pgrep -fl '/Godot.*review_rocket_ignition.gd'` returned exit 1 with empty output. No owned rocket native capture process remains. Shared worktree and uncommitted deliverables are retained for the root-owned `tasks/handoff-motion-design-opus-20261001.md` handoff.
