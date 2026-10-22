# Standalone forward-session core

MIT C++20. No engine SDK, scripting runtime, graphics or JSON dependency.
`session.hpp` is the shared app/view interface. Read the existing private
`CARTE.FIC`; no original map bytes are embedded in public source files.

The port covers the decoded engine cycle, signed column-major map, rail ports,
curves and switches, the three-phase forward journey, connected half-cell route
history, the six initial wagon records, their mass and authored visual lengths.
`Session` owns these states together. Controls change the actual engine; the
engine's resulting speed drives the actual rail traversal.

Sources and limits:

- `FORMAT-CARTE.md` defines the 160 by 73 column-major signed-byte layout.
- `tasks/evidence/locomotive-rules.md` gives original initial stocks, mass 1266,
  integer heating/pressure/consumption equations and one/twelve-cycle vectors.
- `game/scripts/engine_state.gd` also contains the approved progressive service
  brake adaptation. This port keeps it; it is not the original instant brake.
- `tasks/evidence/rail-network.md` and `game/scripts/rail_network.gd` define
  keypad headings, curves, switch transitions, speed factors and boundaries.
- `game/scripts/train_journey.gd` and `train_path.gd` define forward phases,
  source half-cell geometry, seeding and route sampling. The renderer receives
  Euclidean map-unit samples; missing history is explicit, never extrapolated.
- `train_wagons.gd` defines original records/mass; `train_consist.gd` contains
  authored atlas length proportions and the approved type-to-art mapping.
- `game/tests/test_train_journey.gd` supplies real-map route oracles: initial
  branch stops before the crevasse at (83,67), and switching (54,67) reaches
  station (138,71). Tests neither repair nor bypass these unported handlers.

This is a **forward mechanics subset**. No reversal, occupied reverse-switch
history, repairs, station departure, campaign calendar handlers, roaming entities, hidden
site reveal, combat or economic handlers are claimed. Boundary entry pauses the
native session and stops the engine, retaining the reason for visible UI. The
one-second cadence remains the remake's provisional setting. Schema 2 accepts
only that setting, preventing malformed tiny cadences from hanging catch-up.
The cadence equality tolerance retains the previous EngineSession contract
(`engine_session.gd`; the then-SDK `math_defs.hpp` CMP_EPSILON was 0.00001).
Coordinates use standard double arithmetic and `std::hypot`. They do not claim
bit-for-bit compatibility with the former engine's float-vector implementation.

Native schema 2 is a versioned, locale-independent text format. It contains the
complete original map identity, allowed switch mutations, engine and clock,
wagons, decoded calendar (day/hour/minute/factor), current journey and full retained half-cell path. Loading builds and
validates a detached candidate before assignment. Path validation checks actual
rail ports and center/port connectivity, permitting either historical switch
branch after a live toggle. It does not import legacy engine saves or the earlier native schema 1: deriving
calendar time from cycle count would invent missing state because the engine
cycle that raises an event does not advance the calendar.

`GameCalendar` follows `game_calendar.gd`: initial day 1 at 00:00, factors 1/3,
three game minutes per completed remake cycle, noon bridge opening and 14:00
closure, midnight and third-day mine hook names. The application multiplies
elapsed real time by the factor once (`main.gd:108`); the core never multiplies
again. Calendar advancement follows a successful engine cycle and precedes
journey movement (`journey_session.gd:20`). The timed bridge writes are applied
and persisted; enemy spawning, day handlers, mines and other campaign effects
remain unported. The footer clock does not claim those systems are complete.

Saving claims an exclusive sibling `.pending` directory, writes/closes the
complete file, then replaces the destination on the same filesystem. Existing
staging owners are preserved. On POSIX the commit uses `filesystem::rename`;
on Windows it uses `MoveFileExW` with replacement. This is atomic replacement,
not a power-loss durability guarantee. Input files are bounded to 16 MiB as a
serialization allocation policy within the task's 1-GiB total memory budget.

The test executable takes `CARTE.FIC EXISTING_SCRATCH_DIRECTORY`. It writes only
its newly claimed `core-tests` child and removes its files after a normal run.
Compilation, execution, measurements and platform claims belong to the root
integration receipts; source code existing here is not evidence of execution.
