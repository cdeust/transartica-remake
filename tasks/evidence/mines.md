# Mines: creation, depletion, prospecting (27 September 2026)

Static decode. Listings: `reference-private/observations/listings-20260927/{yoda,table,time,mine}.json`
(produced by `tools/claude/xdisasm.py`); pretty view via
`python3 tools/claude/alis_pretty.py <listing> <start_hex> <end_hex>`. Cross-checked with
`grep`-equivalent scan of every listing for the mine-table address (`6082`): only `yoda.json`,
`table.json` and `time.json` touch it for game logic; the other hits (`carte`, `glieu`, `room`,
`texte*`) are coincidental matches on unrelated instruction offsets, verified individually.

## 1. Table shape and slot usage: **proven**

- `main[0x6082]` is a 50×4 record array. `TABLE 0x00e7` zero-fills all 50 rows (`table.json`
  `0xe2`–`0x112`, outer bound `L0x32w <= 49`).
- `YODA 0x1e2a` (depletion) and `YODA 0x1ec7` (creation) both loop `L0x16b` from 0 to **35**
  only (`0x1ead`: `L0x16b <= 35`). Rows 36–49 are zero-filled at startup but never read or
  written by these routines — dead capacity in the original game, not a gap in this port.
- `TIME 0x2509` (mine-tile approach, see §5) scans **0 to 49** for the slot matching a cell,
  the full 50 rows. This is a real asymmetry in the original bytecode: the lookup range is
  wider than the range creation/depletion ever populate. Not a decode error; reproduced as-is
  in the evidence, not silently narrowed.
- Fields: `[0]` = mine-cell x − 40, `[1]` = mine-cell y, `[2]` = ±(day of creation) — sign
  encodes ore (`<0` anthracite, `>=0` lignite; day is always ≥1 so the sign is unambiguous),
  `[3]` = "wealth index" (TEXTEK `0x1675` label). `field[2] == 0` is the free-slot sentinel
  (a day value can never be 0).

## 2. Depletion (day%3==0 rollover): **proven**

`YODA 0x1e2c`–`0x1eb8`, driven by the day-rollover gate at `YODA 0x3446` (`day % 3 == 0`,
already wired into `game/scripts/game_calendar.gd`'s `"mines"` event). For each slot 0..35
with `field[2] != 0` (occupied):
- `field[3] -= 5` (`0x1e52`).
- If `field[3] < 1` (`0x1e5f`): the mine cell `(field[0]+40, field[1])` is set to tile `79`
  (`0x1e7e`) and `main+0x614b = 1` is raised (a shared "special event today" flag also set by
  other story/obstacle handlers; not mine-specific, out of scope for this port).
- The routine also calls `YODA 0x1d1a` with the depleted slot's index — a bounded (max 10)
  FIFO notification queue (`main+0x614f`, `main[0x6152]`) that drives a status-bar icon
  (`shimb[74,13]=3`) or an on-screen actor call (`clive 19`/`clive 4`). This is UI
  presentation, not a map/record rule; **not ported**.

## 3. Creation (same tick, after depletion): **proven**

Gated by `YODA 0x1eb9`: if `main+0x2fb2` (day) `> 127`, no creation this tick. Also gated by
slot availability: the depletion loop above already walks 0..35 and exits early to the
creation code only when it finds a slot with `field[2] == 0`; if all 36 are occupied the
routine returns without generating coordinates at all.

1. Random center: `cx = rnd(138) + 11` (11..148), `cy = rnd(50) + 11` (11..60) (`0x1ec7`,
   `0x1ed3`; `rnd(n)` = 0..n−1, `opernames.c:433`). These two `rnd` calls happen **before**
   the placement search, in this order.
2. Search a 21×21 window `x ∈ [cx−10, cx+10]`, `y ∈ [cy−10, cy+10]`, **x outer, y inner**
   (`0x1ee8`–`0x227d`), first match wins, no further scanning once a placement is committed.
3. For each `(x, y)` in the window: test tile `== 2` first (§3a); if that yields no placement,
   test tile `== 3` (§3b). Any other tile value is skipped.
4. **Tile `2` (horizontal family)** (`0x1f0e`–`0x2092`): for each corner
   `(dx, dy) ∈ {(-1,-1), (-1,1), (1,-1), (1,1)}`, in that order:
   - Skip unless the diagonal cell `(x+dx, y+dy)` is "empty" — tile `== 0`, `> 85`, `< -124`,
     or strictly between `-113` and `-107` (`0x1f0e`, four-way OR).
   - Then check the **horizontal** neighbor `(x+dx, y)` (same row, shifted by `dx`, not the
     diagonal cell) for one of a specific switch pair:
     | Corner (dx,dy) | Neighbor must be | New switch code at (x,y) |
     |---|---|---|
     | (-1,-1) | 18 or 19 | 20 |
     | (-1,1) | 22 or 23 | 24 |
     | (1,-1) | 20 or 21 | 18 |
     | (1,1) | 24 or 25 | 22 |
5. **Tile `3` (vertical family)** (`0x20c2`–`0x2256`): same corner order, but the "empty"
   test is the diagonal cell as before, and the neighbor check is the **vertical** neighbor
   `(x, y+dy)` (same column, shifted by `dy`):
   | Corner (dx,dy) | Neighbor must be | New switch code at (x,y) |
   |---|---|---|
   | (-1,-1) | 28 or 29 | 32 |
   | (-1,1) | 32 or 33 | 28 |
   | (1,-1) | 26 or 27 | 30 |
   | (1,1) | 30 or 31 | 26 |
6. On the first successful corner (`0x2281`):
   - `map[x][y] = new_switch_code`.
   - `map[x+dx][y+dy] = 78` (the mine tile).
   - `record[slot] = [ (x+dx) - 40, y+dy, ±day, rnd(10)+40 ]` — the coordinates recorded are
     the **mine (diagonal) cell's**, not the switch cell's, matching `tasks/evidence/
     obstacles-unknowns.md` §6's "(x−40, y, ±day, rnd(10)+40)".
   - Ore sign: `rnd(2) == 0` → anthracite (`field[2] = -day`); else lignite
     (`field[2] = day`). This `rnd(2)` call happens **after** placement, then `rnd(10)` for
     the wealth index (`40..49`), in that order.
   - The same slot-index notification queue as depletion (`YODA 0x1d1a`) runs; not ported
     (UI only).

**Correction to the task brief's paraphrase**: the neighbor that must already exist is not a
generic "straight track tile" — it must be one specific member of an existing switch pair
(18–33). The candidate center cell itself must be a placeholder tile `2` or `3` (not a literal
"off-track diagonal" tile in the general sense); these two codes select which axis (horizontal
vs vertical) the new switch/mine pair uses. This new switch and the mine tile are physically
adjacent diagonal/orthogonal cells of that placeholder, not any arbitrary off-track diagonal.

## 4. Prospecting (YES/NO): **proven**

`YODA 0x200`: entry point for tile `78` (message 78 from `TIME 0x2509`, see §5). Sets
`L0x1fb = 22` (question id) and `L0x30w` = the record index (word), then falls into the shared
obstacle-question handler `YODA 0x2390` — the *same* entry crevasse (24), lake (25), and
destroyed-track (26) questions use. The shared prelude brakes the train
(`obstacles-unknowns.md` §1). The branch at `0x2397` (`L0x1fb ∈ {24,25,26}`) is false for the
mine's `22`, so the rails/slaves shortage check (`track_works.gd`) is **skipped entirely for
mines** — matches `obstacles.md`'s "conditions: aucune" row.

- Question drawn: TEXTEK resource 11 composite (`obstacles-unknowns.md` §2), scene `-22`
  (`mine.AO`), text 72 "YOU COME ACROSS A MINE / PROSPECT?".
- **OK/YES** (`L0x20b == 0`, `0x258c` jumps to `0x259a`) → `YODA 0x25e2`:
  - `map[record.x+40][record.y] = 79` (mine cell becomes the dead-end tile).
  - `main+0x614b = 1` (shared story/event flag, as in depletion).
  - `record[3] = -1` (wealth forced negative; the next depletion tick's `field[3] < 1` test
    is already true, so this is a "confirm depleted" sentinel, not a second write path).
  - **No wagon, cargo, or goods write of any kind occurs on this path.**
- **NO** (`L0x20b == 1`) → falls straight through to `0x2593`/`0x2599`: clears the brake flag
  only. No map write, no record write, no scene change (matches the general NO behavior
  documented in `obstacles-unknowns.md` §1). The mine stays tile `78`; the question is asked
  again on a later approach.

## 5. Tile 78 approach and slot resolution: **proven**

`TIME 0x24ed`/`0x2509`/`0x2565` (the shared obstacle-approach block, `time.json`): on reaching
tile `78`, `TIME` linear-scans `main[0x6082][0..49]` for the record whose `(field[0], field[1])`
matches `(cell.x − 40, cell.y)`, then sends `YODA` message 78 with **that slot index** (not the
cell coordinates — unlike crevasse/lake/destroyed, which send `x,y`). This lookup and the
message dispatch belong to `TIME`/`rail_network.gd` territory (owned elsewhere); `mines.gd`
only exposes the pure record scan (`slot_for_cell`) so the orchestrator's integration can call
it without re-deriving the format.

## 6. Mine exploitation ("what does mining actually give you"): **decoded — no resource path exists**

`mine.alis` (`reference-private/observations/listings-20260927/mine.json`, only 19
instructions) is a **pure palette/background selection scene**: it reads one flag
(`L0x0c`, presumably ore kind) and selects between two background palettes, then sleeps and
exits. No wagon, goods, or economy write anywhere in it.

Scanning every listing for the mine-table address (`6082`) found no other game-logic reader:
`glieu.json`'s hits are coincidental byte-offset matches, verified individually to be unrelated
instructions.

**Conclusion**: prospecting a mine (§4 YES) has exactly one effect — the map/record write
above. There is no decoded formula for lignite/anthracite quantity, no slave/mammoth/crane
term, and no wagon interaction for mines specifically. The "wealth index" (`field[3]`) is
consumed purely as a countdown to depletion; nothing reads it to produce goods. `DOSSIER.md`'s
manual description ("mines exploited with slaves, mammoths and cranes") matches the *track
works* mechanic (`track_works.gd`, crevasse/lake/destroyed track — genuinely rails+slaves,
sped up by mammoths/cranes), not the mine tile itself. This is the same discrepancy
`obstacles.md` already flagged for track works generally; it is now confirmed to extend to
mines: the manual's mental model and the bytecode do not match for mine exploitation, and no
undecoded resource-formula code exists to reconcile them. **Owner decision required before any
resource-granting behavior is added** (per `FIDELITE.md`); this port implements only the
decoded map/record effect.

## 7. Not ported (owned elsewhere or out of scope)

- `TIME 0x2509` slot lookup, message dispatch, and the tile-78 approach hook itself — belongs
  to `rail_network.gd`/`travel_*.gd` integration (see report to orchestrator).
- `main+0x614b`/`main+0x651b` flags — shared cross-event flags, not mine-specific state.
- `YODA 0x1d1a` notification queue — UI icon/status only.
- Question/scene presentation (TEXTEK composite, `mine.alis` palette) — rendering, not a rule.
