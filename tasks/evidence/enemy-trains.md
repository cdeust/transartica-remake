# Enemy trains on the map: spawn, movement, encounter (27 September 2026)

Offsets are in `reference-private/unpacked/{yoda,time,table,room}.alis`, decompiled with
`tools/claude/xdisasm.py` into `reference-private/observations/listings-20260927/*.json`
and rendered with `tools/claude/alis_pretty.py`. Labels: **P** proven (read directly from
the listing), **Pa** partial (one branch read, sibling branches not walked), **U** unknown
(not reached by any instruction found).

Enemy table `main[0x5eb4]`: 30 records (slots 0-29) of at least 8 fields:
`[0]` state, `[1]` x-40, `[2]` y, `[3]` heading (numeric-keypad, same convention as
`rail-network.md`), `[4]` phase (0-3, matches the player's TIME 0x0486 phase counter),
`[5]` distance remainder, `[6]` speed, `[7]` strength.

## 1. Spawn — YODA 0x2af7 (P)

```
0x2af7-0x2b21  scan L22b = 0..28 for main[0x5eb4][L22b][0] == 0 (first free slot,
               slot 29 excluded); no free slot -> cret, no spawn.
0x2b22         cswitch2 rnd(9) -> one of 9 spawn points (first random draw)
0x2b42..0x2c9a the 9 points, written to fields [1] (dx), [2] (y), [3] (heading):
               (-31,40,4) (-28,40,6) (-29,41,2) (75,25,6) (72,25,8) (73,26,4)
               (38,61,8) (35,61,4) (37,62,2)
0x2cc1         [0] = 1 (moving forward)
0x2cce         [4] = 2 (phase)
0x2cdb         [6] = 20 + slot/2 + difficulty (main+0x6539)      -- speed
0x2cf6         [7] = slot/2 + difficulty + 1 + rnd(2) + 20*rnd(6) -- strength
               (second random draw rnd(2), then third rnd(6); confirmed by reading
               the operand tree left-to-right, matching the ALIS stack machine's
               evaluation order)
0x2d1e         main[0x3080][x][y] |= 16   (x = [1]+40; marks the spawn cell)
```

Every game hour (YODA 0x33fe, already the driver for `game_calendar.gd`'s bridge
hooks): at difficulty 4, spawn fires when `hour % 12 == 0` (hour 0 and 12, checked
*after* `hour += 1` and *before* the day rollover, so it also fires at the instant
hour becomes 24 before wrapping to 0 — confirmed at 0x33fe-0x3417, which runs before
the `hour > 23` day-rollover branch at 0x341a). At any other difficulty, spawn fires
on day rollover when `new_day % (4 - difficulty) == 0` (0x3449-0x346c). `game_calendar.gd`
has no per-hour hook today; the integration must add one (see §6).

**Difficulty (`main+0x6539`) and combat-off (`main+0x6537`) writers (P for what exists,
U beyond it):** the only writer found across all 42 decompiled scripts is
`table.alis` 0x249/0x255, part of the new-game initializer (`TABLE 0x0231-0x025b`),
which sets both to **0**. `room.alis` 0x85f/0x867 only appears in a `cfwritev` run
(save-file field list, not a setter). No options/debug menu writer was found; the
"super mechant" debug case (`TABLE 0x063e`) only rebuilds the same 9-point table as
local scratch data and does not touch `main+0x6539`. So: **a new game starts at
difficulty 0 with combat on**, and nothing in the decompiled scripts changes either
value afterward — how the player would ever reach difficulty 4 is **U**.

## 2. Slot 29 — scripted train, TIME 0x1d8b (P)

Reached from the player's own candidate-cell check (`L36b == 1`, i.e. only when the
*player* commits into these cells) after the general story-zone gate at TIME 0x1bc9
(x 139-158, y 47-69 — already `STORY_CELLS` in `rail_network.gd`):

```
0x1d8b  player enters (152,66) and main[0x5eb4][29][0] != 2:
          [0]=-1, [1]=114, [2]=62, [3]=2, [7]=19   (fields [4..6] left at their
          existing value, normally 0 from a prior clear)
          main[0x3080][154][62] |= 16
0x1e1b  player enters (151,66):
          main[0x3080][154][62] &= 239   (clear bit 16)
          main[0x5eb4][29][0..7] = 0     (full clear, including state)
```

This is the level-triggered scripted enemy at the reversal-zone cells already in
`RailNetwork.STORY_CELLS`; it is independent of the periodic spawn (YODA 0x2af7 never
touches slot 29). Unlike the periodic spawn it starts at state **-1**, not 1.

## 3. Per-cycle movement — TIME 0x11a6-0x1961 (P for the mainline; two branches Pa)

Loop over slots 0..29 (`TIME 0x11a6-0x1443`):

```
|state| > 49:  state = sign(state); tile at own cell restored to abs() (unblock);
               fall through to the next slot. (No writer of a state this large was
               found in the traced spawn/removal/bounce paths; ported as read — Pa.)
5 <= |state| <= 49:  state -= 1 if state>0 else state += 1 (0x121a): a wait timer
               ticks toward zero. This is how the "hit damaged track" state (below)
               resolves without moving.
|state| == 1:  speed/phase step, then the candidate coordinate step:
```

Speed/phase (`0x1244-0x1358`, same shape as the player's TIME 0x0486 block in
`rail-network.md`, reusing `RailNetwork.progress_speed`'s doubling table for every
tile **except** codes 15/16): `L14 = field[6]` (speed) normally; for tile code 15 the
doubling reads **`main+0x2fbb`, the player's own heading field**, not the enemy's own
`field[3]` — checked directly in the listing (0x12aa/0x12d1) and ported as read, flagged
`# quirk: reads the player's heading, not the mover's own`. Cap 45, `field[5] += L14/2`,
overflow (`>22`) subtracts 23 and increments `field[4]` (phase); on phase reaching 3,
phase resets to 0 and the candidate coordinate is computed via the same 9-case delta
table as `RailNetwork.DELTAS` (TIME 0x1a25, byte-identical case list to
`navigation-next.md`'s table), **committed unconditionally** — no equivalent of the
player's `L3e` refusal gate exists on this path.

### Turn / switch choice (0x1444, shared subroutine with the player)

Curves use exactly `RailNetwork.CURVE_TILES`/`CURVE_RULES` (same dispatch table,
byte-identical case list, confirmed at 0x14c9). At switch tiles
(`RailNetwork.SWITCH_RULES`), the diverge test is:

```
diverge = (L37 >= 0 && tile_is_odd) || (L37 == -1 && rnd(2) == 1)
```

`tile_is_odd` is `RailNetwork.switch_diverges()`; when `L37 >= 0` this term makes the
enemy behave exactly like `RailNetwork.turn()` (follow the switch as currently set).
`L37` starts as `-1` when `field[7] < 0` (negative strength — never produced by the
spawn formulas above, so in practice unreachable for periodic/scripted spawns as
currently ported) and `1` otherwise. When `L37 == 1`, a preamble (0x1444-0x14a5)
checks the *candidate* cell against up to two entries of `main[0x306c]`, a 3-slot
history of **the player's own two most recent switch cells** (rotated by the shared
subroutine 0x199b, but the rotation only fires when *the player* is the mover —
confirmed by the caller passing `L37 = 0` for the player's own movement step, vs.
`±1` for enemies). No match resets `L37` to `-1` for that decision. Net rule: **an
enemy standing on a switch cell the player has recently used follows the switch as
set; otherwise it picks randomly** (`rnd(2)`). `main[0x306c]` is not tracked anywhere
in the ported code today (rail_network.gd/train_journey.gd do not expose it), so
`enemy_trains.gd` keeps its own 2-entry mirror, fed once per cycle from the player's
current cell (see §6) — this reproduces the trigger (player entering a switch cell)
without touching files this task does not own.

### Obstacles, edges, bounce (0x21d5, 0x228c-0x22da, 0x2352-0x2391)

```
0x21d5  candidate tile < 0 (a destroyed-track marker):
  -105 < tile < 0 (repairable damaged track, RailNetwork/TrackWorks range):
      state = 5 * sign(state); return WITHOUT committing the candidate or touching
      the map bit (the enemy waits; the movement loop's 5..49 branch above then
      ticks it back toward |state|==1 without re-entering this cell).
  tile <= -105 in the rectangle x 24-38, y 1-7: a lookup against main[0x64fa] (a
      mine-record table with a "closed" -1 marker). Not walked to a conclusion — Pa,
      not ported.
0x228c  otherwise: cswitch1 on abs(tile) against the same "event/obstacle" tile set
      documented in obstacles.md/rail_network.gd's EVENT_TILES/TrackWorks (13, 113,
      34-37, 65, 67, 69, 78, 79, 107, 114, 116, 120): on a match, call 0x22db.
0x22db  full 180 degree heading reversal (1<->9, 2<->8, 3<->7, 4<->6, 5 unchanged),
      restores position to the pre-candidate cell (L26w/L39b), and for the enemy
      case (L36==16): state = -state (0x2352), phase = abs(phase-2)-1 (0x2368),
      remainder = 23 (0x2384) — the enemy bounces off the obstacle and reverses.
```

### Map bit 16 — set/clear (0x1b5a-0x1b84, P)

After the obstacle checks pass (or don't apply), the shared subroutine clears bit 16
on the **old** cell and sets it on the **new** (committed) cell:
`main[0x3080][old] &= ~16; main[0x3080][new] |= 16`. This is the only writer of
bit 16 found besides spawn/removal/slot-29. It is gated on `L36 > 1` (the caller's
mask), so it never fires for the player's own `L36 == 1` movement — the player does
not carry a `main[0x3080]` presence bit through this path.

Two more checks in the same subroutine are read but not ported (log-only, no rule
effect): bit 64 (`0x2045`, an enemy-sighting log write into `main[0x6152]`, a 10-entry
rolling notification buffer) and bit 1 (`0x1af3-0x1b51`, the game's fixed start-position
marker, set once at `TABLE 0x0744` and never moved by this routine).

## 4. Encounter trigger for the player — TIME 0x261c/0x28d7 (P)

Inside the player's own candidate-cell check (`TIME 0x2392-0x266a`, `L36 == 1`),
after the story/city checks already ported into `RailNetwork.station_lookup`:

```
0x261c  if main[0x3080][candidate] & 16:
0x28d7      linear scan slots 0..29 for main[0x5eb4][slot][1]==candidate.x-40
            and [2]==candidate.y; first match wins (index = L31b).
0x2632      csend 1 LOC-40 16 <slot index>   -- message arg is the enemy slot.
```

`yoda.alis` 0x1b5 (message 16 handler) reads that argument (`L0x30w = oscan`) and, if
`main+0x6537` (combat off) is zero, writes it to `shimb[66,13]` (**byte 13 = enemy
index**, matching `combat.md`) before starting scene -33 (`wdecor.alis`). This confirms
`combat.md`'s already-proven description; the new fact here is the exact index lookup
(`0x28d7`) that `enemy_trains.gd` must reproduce for `encounter_at(cell)`.

## 5. Removal after combat — YODA 0xa56 (P, one caveat)

```
0xa56  main[0x3080][enemy_x][enemy_y] &= 239   (clear bit 16 at the enemy's own cell)
0xa92  main[0x5eb4][slot][1..7] = 0            (fields 1-7 zeroed, NOT field 0)
0xaae  main[0x5eb4][slot][0] = 2               (state = 2)
```

State 2 matches none of the movement loop's three branches (`>49`, `5..49`, `==1`), so
a removed slot sits inert on the map forever and is never re-selected by the spawn
scan (`0..28`, `state == 0` only). No writer of `state = 0` for an already-spawned
slot was found anywhere in the 42 listings except the slot-29 removal above and the
save-file load path (out of this task's scope). **This is read as intentional
attrition, not ported as a bug**: `enemy_trains.gd` sets removed slots to state 2 and
never recycles them, matching the source exactly.

## 6. Integration instructions for `main.gd` (not ported here; describes required call order)

1. Own the 30-slot table and the RNG stream (`EnemyTrains.new()`), separate from
   `TrainJourney`'s/`RailNetwork`'s state.
2. Per calendar hour (a new hook `game_calendar.gd`'s caller must raise, or main.gd
   detecting `hour` change itself — `game_calendar.gd` today reports `"new_day"` but
   no per-hour event): call `EnemyTrains.maybe_spawn(difficulty, rng)`.
3. Per remake cycle, **after** the player's `TrainJourney.advance()` commits a cell
   (so the player's position for that cycle is final) and **before** encounter
   detection: call `EnemyTrains.record_player_position(player.position, network)` (feeds
   the switch-history mirror from §3), then `EnemyTrains.advance_cycle(network, rng)`
   for every active slot's own candidate step.
4. After both trains have moved for the cycle: call
   `EnemyTrains.encounter_at(player.position)`. A non-negative return is the enemy
   slot index; main.gd must branch exactly as `combat.md` §2 describes: if
   `main+0x6537`-equivalent (combat-off flag main.gd already owns) is set, auto-resolve
   (owned by `combat_*` files); otherwise start the encounter scene with the slot index
   as its argument (`byte 13` in the original).
5. Snapshot/restore: `EnemyTrains.snapshot()`/`restore()` must be called alongside
   `RailNetwork`'s and `GameCalendar`'s in the save/load path, before any spawn call
   for that session (a restored game must not immediately re-spawn on its first hour
   tick if a slot is already occupied — the spawn scan already handles this correctly
   since it only fills `state == 0` slots).
6. After combat resolves (owned by `combat_*`/`main.gd`), call
   `EnemyTrains.remove(slot_index)` to reproduce YODA 0xa56.

## 7. What is not ported and why

- Mine-rectangle destroyed-track special case (`TIME 0x2221-0x228c`): read but not
  walked to a conclusion (Pa) — no gameplay claim can be made about it yet.
- Bit 64 enemy-sighting log (`0x2045`) and bit 1 start-marker check (`0x1af3-0x1b51`):
  proven no-ops for the movement/encounter rule set, UI/telemetry only — out of scope
  for "pure rules".
- `state > 49` branch: read as written; no producer of such a state was found, so its
  real trigger is **U**. Ported literally (harmless: it just clamps to `sign(state)`
  and unblocks the tile) rather than omitted, since omitting a reachable branch would
  be inventing behavior by silence.
- How `main+0x6539` (difficulty) ever becomes nonzero, and how `main+0x6537`
  (combat off) is ever set: **U** — no writer besides the new-game zero-initializer
  was found in any of the 42 decompiled scripts.
