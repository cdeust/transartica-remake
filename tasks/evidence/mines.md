# Mines: creation, depletion, prospecting (27 September 2026)

Static decode. Listings: `reference-private/observations/listings-20260927/{yoda,table,time,mine,carte,textek}.json`
(produced by `tools/claude/xdisasm.py`); pretty view via
`python3 tools/claude/alis_pretty.py <listing> <start_hex> <end_hex>`. Every reader of the
mine table was found with a structural scan (walk each listing's instruction tree for an
`omaintc` opcode whose immediate argument is `24706` = `0x6082`, the encoding `yoda.json`
itself uses at `0x1e31` etc.) — not a substring match on `"6082"`, which false-positives on
unrelated instruction byte-offsets. Real readers: `yoda.json` (creation/depletion/prospect),
`table.json` (zero-fill), `time.json` (slot lookup on tile-78 approach), `carte.json` (map
legend icon), and `textek.json`/`texte.json`/`texted.json` (three language builds of the same
UI text, identical instruction shape: "OPEN/CLOSED \<ORE\> MINE" atlas legend, a
"DISCOVERY OF A MINE"/"CLOSURE OF A MINE" bulletin, and the prospected mine's own
"\<ORE\> MINE OF THE YEAR 2714" plaque). The text scripts also contain the
resource-granting extraction handler (§6), missed by the earlier display-only interpretation. `glieu.json`'s and `room.json`'s hits on the substring
`6082` are confirmed to be coincidental byte-offset matches, not `omaintc[24706]` reads — the
structural scan finds zero hits in either file.

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
- **The decrement itself is guarded**: `0x1e40` tests `field[3] > 0` first; if not, the slot is
  skipped entirely — no decrement, no write, straight to the next slot (`0x1e4e` branches to
  `0x1ea0`). Only then: `field[3] -= 5` (`0x1e52`).
- If `field[3] < 1` after the decrement (`0x1e5f`): the mine cell `(field[0]+40, field[1])` is
  set to tile `79` (`0x1e7e`) and `main+0x614b = 1` is raised (a shared "special event today"
  flag also set by other story/obstacle handlers; not mine-specific, out of scope for this
  port).
- **Consequence of the guard**: the tile-79 write fires exactly once — the tick where the
  decrement first crosses below 1. Every later tick, `0x1e40` sees `field[3] <= 0` and skips
  the slot outright (no further decrement, no further write). A depleted or prospected slot is
  never freed (`field[2]` is only ever written at creation, `main[0x6082]` writes traced
  exhaustively across `yoda.json`, see §6's scan methodology) and never reconsidered by
  depletion again. The reachable floor is therefore the one-time -5 undershoot from a creation
  value in `[40, 49]`: **`[-4, 0]`** (worked out per residue mod 5), or exactly `-1` from
  `prospect()` YES (§4), never lower.
- The routine also calls `YODA 0x1d1a` with the depleted slot's index — a bounded (max 10)
  FIFO notification queue (`main+0x614f`, `main[0x6152]`) that drives a status-bar icon
  (`shimb[74,13]=3`) or an on-screen actor call (`clive 19`/`clive 4`), read back by the
  TEXTEK "DISCOVERY OF A MINE"/"CLOSURE OF A MINE" bulletin (§0). This is UI presentation, not
  a map/record rule; **not ported**.

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
   test tile `== 3` (§3b). Any other tile value is skipped. Tile `2`/`3` are ordinary track
   tiles used throughout the real map (e.g. `test_train_journey.gd`'s starting cell (11,62) is
   a `2`) — not rare reserved placeholders; the search hits real track constantly.
4. **Branch semantics verified against source** (`reference-private/alis-source/src/opcodes.c`
   `cbz24`: `offset = varD7 ? 3 : script_read24()` then unconditional jump — i.e. it branches to
   the encoded target exactly when the tested accumulator is **zero**, falls through to the next
   instruction otherwise). This is load-bearing for every corner test below: a `cbz24` guarding
   an `==`/`OR` block branches to its target when the condition is **false**.
5. **Tile `2` (horizontal family)** (`0x1f0e`–`0x2092`): for each corner
   `(dx, dy) ∈ {(-1,-1), (-1,1), (1,-1), (1,1)}`, grouped by `dx` (`-1` group first, `1` group
   second), in that order:
   - Skip unless the diagonal cell `(x+dx, y+dy)` is "empty" — tile `== 0`, `> 85`, or `< -124`
     (`0x1f0e`; the fourth disjunct in the raw OR, `value > -107 & value < -113`, is
     unsatisfiable as written — confirmed from the raw operand dump, not just the pretty-print;
     dead code, kept dead in the port rather than "corrected" to a guessed live range per
     FIDELITE.md). If not empty: **try the other `dy` in the same `dx` group** (continue).
   - If empty, check the **horizontal** neighbor `(x+dx, y)` (same row, shifted by `dx`, not
     the diagonal cell). If it is **already** one of the codes below (an existing switch of
     that specific pair), the site is refused and **the whole `dx` group is abandoned —
     including the other `dy`** (`0x1fb4`/`0x1feb`/`0x2036`/`0x2071` jump straight to the
     outer `L0x18b` loop increment, past the second corner's own test): move on to the other
     `dx`. Otherwise (neighbor is anything else, including empty background) place:
     | Corner (dx,dy) | Neighbor refuses when it is | New switch code at (x,y) |
     |---|---|---|
     | (-1,-1) | 18 or 19 | 20 |
     | (-1,1) | 22 or 23 | 24 |
     | (1,-1) | 20 or 21 | 18 |
     | (1,1) | 24 or 25 | 22 |
6. **Tile `3` (vertical family)** (`0x20c2`–`0x2256`): identical structure — same `dx`-group
   abandon-on-refusal behavior, same corner order — but the neighbor checked is **vertical**
   `(x, y+dy)` (same column, shifted by `dy`):
   | Corner (dx,dy) | Neighbor refuses when it is | New switch code at (x,y) |
   |---|---|---|
   | (-1,-1) | 28 or 29 | 32 |
   | (-1,1) | 32 or 33 | 28 |
   | (1,-1) | 26 or 27 | 30 |
   | (1,1) | 30 or 31 | 26 |
7. On the first successful corner (`0x2281`):
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

**On the task brief's paraphrase** ("a straight track tile next to an off-track diagonal
becomes a switch"): confirmed correct at the level of intent — the candidate that becomes the
switch is an ordinary track cell (`2` or `3`), and its diagonal neighbor is the one converted
into the mine. The refinement this decode adds: the *governing* neighbor check is a
**refusal** condition on the perpendicular cell (must not already be a switch of the specific
complementary pair), not a requirement that a switch already be present, and a refusal on the
first corner of a `dx` group silently forfeits the second corner of that group too.

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
  - **The YODA close path itself writes no cargo; TEXTEK has already credited coal before this close (§6).**
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
it without re-deriving the format. `CARTE.FIC` ships **no** pre-placed tile `78` or `79`
(counted directly: `78` → 0 occurrences, `79` → 0), so this 50-row scan never runs past a
freshly-created record on a normal day-1 start; the width mismatch (§1) is real but unreachable
until at least one mine has been created.

**Post-answer tail: resolved (4 October 2026).** YES negates question22 and
YODA0x0de9 explicitly stores−22 into main0x2faa. After the text72→41→42 flow
(§6),62c0 becomes0 and YODA writes tile79/wealth−1 before0x2687→0x811. The
cswitch2 at0x817 adds33 to−22, selecting target index11,0x9ee. That routine
unloads MINE and calls0x18e3 for reversal, leaving brakes engaged.

## 6. Mine exploitation: corrected from original TEXTEK handlers (4 October 2026)

The earlier conclusion "no resource path exists" was false. It classified TEXTEK
as display-only and scanned mine-record readers without following their dynamic
click transitions. A structural scan of all listing operands for economy fields
0x2fb6 and0x2fc8 identifies actual credits in TEXTEK, reproduced in TEXTE and TEXTED.
MINE has only19 palette instructions; that does not establish absence in TEXTEK.

YODA0x259a..25ba opens scene−22 and sends text72 with the mine slot. TEXTEK0x464c
click dispatch changes72→41 at0x4679, then41→42 at0x4670;0x46e1 returns to the
text dispatcher0x84. Text41 (0xfbe) sums slaves from wagon types5/6 field3,
mammoths type7 field3 and counts cranes type16 with statefield1<3. Text42
(0x10fb..12df) calculates and credits extraction:

- Capacity adds5000 per coal wagon type21 whose statefield1!=3, with signed-word
  overflow. If the accumulated capacity is negative, replace it with32000.
- Free capacity is the signed word capacity−(anthracite+lignite).
- Work is the signed word slaves+30×mammoths, then +150 if at least one crane.
- Negative mine wealth becomes0; otherwise use record[3]. Quantity is the signed
  word `(wealth+1)*(integer(work/5)+1)`. Negative quantity becomes30000, then
  quantity is capped by free capacity. There is no additional clamp to zero.
- Negative signed creation day selects anthracite: main0x2fc8 +=quantity at0x1263.
  Otherwise lignite: main0x2fb6 +=quantity at0x12bb. The resulting signed-word
  total is replaced with31000 if negative or>31000.

Word stores/adds are confirmed in ALIS storenames.c:sdirw and addnames.c:adirw/
amainw; integer division is opernames.c:odiv. The constants above are bytecode
operands, not estimated gameplay values. Crew counts are captured at text41;
capacity and current coal are read on entry to42. Credit occurs before dismissal.

Text42 sets main0x2fce=1, clock factor3 and countdown60 (0x12df..12eb). TEXTEK
0x45e6..462d calls0x45c8 only while the counter is positive.0x45c8 tests
negative after decrement; the reachable zero therefore never normalizes the
clock. Click cleanup0x4641/4646 restores normal clock. Click remains necessary. ALIS script.c initializes each
script's wait_cycles=1; the remake reuses its existing provisional TEXTEK host
scheduler,48 ticks per engine cycle. Original elapsed wall duration is unmeasured.

After result dismissal,62c0 becomes0; YODA0x25c2 continues to0x25e2, marks tile79
and wealth−1. Scene−22 selects0x9ee in0x811; it calls0x18e3 to reverse, leaving
brakes engaged. Main0x2faa is explicitly set to−22 in0x0de9 after YES.

The remake now persists question/plaque/resources/result phases with the captured
crew and result. It credits only on resources→result, closes only from result,
and restores legacy accepted scenes at the uncredited plaque. Prepared production
fixtures verify phase persistence; they do not prove native earned campaign play.

## 7. Historical integration handoff (27 September 2026)

- `TIME 0x2509` slot lookup, message dispatch, and the tile-78 approach hook itself — belongs
  to `rail_network.gd`/`travel_*.gd` integration (see report to orchestrator).
- `main+0x614b`/`main+0x651b` flags — shared cross-event flags, not mine-specific state.
- `YODA 0x1d1a` notification queue — UI icon/status only.
- Question/scene presentation (TEXTEK composite, `mine.alis` palette) — rendering, not a rule.
- The post-YES reversal (`YODA 0x2687`→`0x811`, §5) — inherited from the shared scene-close
  dispatch, not decided by this table.

## 8. Historical `rail_network.gd` integration handoff (27 September 2026)

`RailNetwork.restore()`'s `_is_saved_change(original, value)` needs new branches for the map
writes this table produces, precisely:
- `original` was a code-2 candidate (before any switch existed) → `value` may be any of
  `{18, 19, ..., 25}` (the full horizontal switch family, not just the placed base — the new
  switch is toggled like any other afterward).
- `original` was a code-3 candidate → `value` may be any of `{26, 27, ..., 33}` (vertical
  family), same reasoning.
- `original` was background (`0`, `> 85`, or `< -124`, §3 step 5) → `value` may be `78` (a
  mine was created there) or `79` (created and already depleted/prospected in the same saved
  game). `78 → 79` as a *change from the initial map* only appears once at least one mine has
  been created; it never appears as a change from a `CARTE.FIC`-shipped `78`, because there are
  none (§5).
`RailNetwork.station_lookup`/`entry_boundary`/`EVENT_TILES` already special-case tile `78` as
an event site (`rail_network.gd:33`) and would need the tile-78→slot lookup (§5) wired to
`MineTable.slot_for_cell` before dispatching to `prospect()`.
