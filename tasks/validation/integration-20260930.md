# Local integration evidence

The starting tree is merged PR7, `bf9f9501711a05a6d4a1b1eca318ac4d0263dcf6`.
New commits remain local; no publication is authorized by this run.

The expanded PR7 baseline passes26 Godot suites. The integrated tree on30
September passes41 Godot suites without engine errors in
`full-completion-current-20260930.log`. The Python decoder and asset suite passes32
tests without skips. Save recovery now checks interrupted manual combat,
campaign pages, mines and workshops, legacy saves and atomic invalid-state
rejection in the actual application. Later source/art changes require another
run before final acceptance.

Native OpenGL evidence is distinct from headless model tests:

- `rail-art-native-20260930.png`: authored rail materials in the real map view.
- `world-workshop-repair.png`, `world-mine-question.png`, `world-mine-plaque.png`:
  workshop repair input and mine NO/OK transitions tested by native viewport input.
- `tactical-native-20260930.png`: actual native combat rendering. Review found
  rail/wagon alignment and footer clipping defects, subsequently corrected.
  The current impact capture is `tactical-impacts-native-20260930.png`; sprite
  crop review remains in progress.

The original calendar and gameplay rules remain tied to the private ECS sources.
The works text scheduler uses48 logical tours per original engine cycle:
ALIS `script.c905` initializes `wait_cycles=1`; `alis.c1196` resets the scheduler
counter; normal YODA runs16 tours per minute and each engine cycle advances
three game minutes. The wall-clock duration still uses the pre-existing,
explicitly provisional host engine cadence. Expiry restores normal clock speed;
it does not dismiss the works result or commit map repair.

Unproved requirements include a reachable complete campaign route, ending sequence integration, final visual coverage,
and native Windows execution. These remain open in `tasks/todo.md`.
