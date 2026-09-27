# TRAIN COMBAT: reverse-engineering notes (2026-09-27)

Offsets are in `reference-private/unpacked/<script>.alis`.
The patched `xdisasm.py` adds opers 0x76/0xa4/0xa6/0xa8 and the `csound`/`ccancen` opcodes (`opernames.c:540,854`; `opcodes.c:3340,4444`). With it, all of wdecor's code (0x18–0x62ae) decodes.
Labels: **P** proven, **Pa** partial, **U** unknown.

## 1. Script (P)
The combat script is **wdecor.alis, id 33**. The bo* scripts are music.

## 2. Trigger (P)
- Enemy table `main[0x5eb4]`: 30 records, [0]=state, [1]=x−40, [2]=y, [7]=strength.
- Spawn (yoda 0x2af7) at one of 9 points: [7]=slot/2+difficulty(`+0x6539`)+1+rnd(2)+20·rnd(6), and map bit 16 in `main[0x3080]`. Every 12 h at difficulty 4, else every 4−difficulty days (0x33fe). Slot 29 is scripted (TIME 0x1d8b).
- TIME 0x261c: bit 16 on the next cell → `csend 16 <idx>` (0x28d7). Map movement (TIME 0x11a6–0x1961) is **U**.
- yoda msg 16 (0x1b5): if `+0x6537` (combat off; its writer is U) → auto-resolve (0x17f6). Otherwise scene −33 (0x1734) → `clive 33`, byte 13 = enemy index, then it waits for byte 12.

## 3. Screen (P, with one conflict)
- Side view: a 7-row grid `L[0x62]` of 16-px cells, plus 4 roof slots per wagon (`LOC 0x19a6`/`0x1cea`).
- Mouse bands (0x2b82–0x2d01): y 38–64 = **player** train, y ≥171 = **enemy** train, y 64–171 = field, y 27–38 = wagon bar.
- **Conflict:** the manual puts the enemy at the top; the code (and roof sprites, 0x2462) put it at the bottom. **Check in an emulator.**
- Controls: edge scrolling, bar-click centring (0x4afb), brake/inverter/return icons (0x4ca9); a dead locomotive means no movement.
- **No retreat**: offsets are clamped (0x299–0x2f2); combat ends only by win or loss.

## 4. Wagons (P, 0x434 and 0x67c)
- Class by type: locomotive 5 (+slot 25), GQ 22, boudoir 23, barracks/XL 1, cannon 2, machine gun 3, livestock 4, tender 8, merchandise 6. Other types are sprites only.
- Health = 3−state for every wagon. The two locomotive slots stay synced to the lower value (0x18f7). Scrap wagons become wrecks (class 7).
- **No armour bonus** was found, despite the manual. Losing the locomotive, GQ or boudoir clears the vital flag `8374` (0xab6).
- Enemy train: a=([7]/20)·4 and b=[7]%20+1.
  - n = rnd((a+b)/2)+(a+b)/2+1. The final count is n+2 (0x716).
  - Locomotive, tender, n·a/(a+b)+1 trading wagons, then random barracks (4·rnd(b)+b+1 soldiers), livestock (5·rnd(b)+b+1), machine gun or cannon (×2 weight).
  - Aggressiveness `8513` = 5b+1, capped at 99.
  - Each roof slot is manned with probability 8513/400, group size rnd(b)+1.

## 5. Player actions (P)
- Barracks panel (0x397c, 0x40d8): +/−, count and an arrow; groups of up to 30.
- Livestock: one mammoth per click, as a 2×2 unit (0x3fe1).
- Group panel (0x3f0a, 0x2e5e): 8 directions, STOP, and a split. Merge up to 30, or 31 on a mammoth (0x31f9).
- Leaving the grid edge puts the group on a roof (0x2fa2). On a roof, dynamite left or right replaces "up" (0x4606).
- **Cannon:** a click sets reload 23 (0x39ed). At 22 it shoots the facing wagon for −1 health (0x531f).
- **Machine gun:** a click sets 13 (0x3a07). It fires on even counts at the first unit in its column, friend or foe (0x522b).
- Only the 6 player wagons on screen run their weapons (0x5001).

## 6. Damage (P)
- 3 cannon hits destroy a wagon, killing its contents and roof occupants (0xab6/0xbef).
- Machine gun (0x2932): mammoth 2/3 chance of −rnd(3); enemy infantry −(rnd(7)+1); player infantry −(rnd(10)+1).
- Melee (0x24d6, roof 0x22e2): the attacker kills rnd(1+A/k), then survivors reply rnd(1+D/k); k=3 against mammoths.
- Dynamite: 5-sweep fuse (0x1b4b), defused when the other side walks onto it (0x1db4). The AI plants it at 8513/100 when crossing wagons, favouring the locomotive, boudoir or GQ (0x1c73).

## 7. Enemy AI (P, 0xf49; one wagon per tick; enemy weapons run for all wagons, 0x17b4)
- Barracks 8513/80 → rnd(30)+1 soldiers; cannon 8513/800; machine gun 8513/100 (cancelled if its column is occupied); livestock 8513/800 → mammoth ≤31.
- Train: new direction every rnd(100)+20 ticks, closing in when far (0xdeb).

## 8. End of combat (P)
- Per wagon cycle (0xef1):
  - **Win:** enemy guns ≤0 **and** enemy soldiers+mammoths ≤0 → byte 12 = 1.
  - **Loss:** your soldiers+mammoths ≤0 **or** vital flag 0 → byte 12 = 2. Your guns do not count.
- Loss (yoda 0xabb): texte2k 105 ("…CHIEF WAS CAUGHT AND SHOT…"), then mort.AO = **game over**.
- Win (0x589d): state = 3−health (locomotive 3−(h+h')/2, 0x58d9); counts are written back. A destroyed tender costs 5000 lignite (2/3) or anthracite; a destroyed SPY wagon kills its spies.
- Booty:
  - Up to 6 surviving trading wagons become MERCHANDISE or XL MERCHANDISE, with random goods and damage.
  - Lignite = (2n'+rnd(50))·10 (0x5be2), limited by 5000 per intact tender minus current stock; money is capped at 31000.
  - Slaves = 3n'+rnd(3n'), placed into PRISON (≤60) and ALCATRAZ (≤100).
  - Survivors go into BARRACKS (≤50) and XL BARRACKS (**≤100**, 0x5ee8; its description says 80). Mammoths go into livestock wagons (≤5). **Overflow is lost.**
- Report: textek 47 (0x54d4). yoda then removes the enemy (0xa56).

## 9. Auto-resolve (P, textek 0x49fc; French texte uses the same message numbers)
- P=(soldiers+20·mammoths+50·guns)/50 over non-scrap wagons; margin m=P−[7]/100.
- If m≤0 → message 105 and **game over** (0x5435).
- Otherwise:
  - Losses are x−x/(m+1) (0x4c11). As written, a larger margin kills *more*.
  - 9−m random wagons of types 4–20 are scrapped, and min(m,8) merchandise wagons are captured (0x5891).
  - Coal and slaves are like §8 but differ: +1 in coal (0x4de6), prison qty<30 (0x4f39), loop bound 0x4fec.
- The soldier debit tests `[3]==24` instead of the type (0x4d60). So XL barracks are never debited, and any wagon holding exactly 24 is.

## 10. Timing (Pa)
Timing is in ticks: reload 23, burst 13, fuse 5 sweeps, a 25-tick pause at the win. Real-time rate (`ctiming`) is **U**.

## 11. Graphics (P; do not extract)
Everything is in **wdecor's own table (0x62ae)**; `cputnat` uses the script's own resources (`opcodes.c:1323`). It has 260 entries (191 bitmaps): background #1 (320×164), panel #250, side-view wagons (player 167+class, enemy 134+class), 99 unit sprites (16×16), dynamite 243/244, icons 202–234, and flashes and impacts 207/208, 248/249 and 236/238. Sounds come from `csound`.

## 12. Portage — rules only, no visuals (2026-09-27, Opus)

Ported: `game/scripts/combat_setup.gd` (player roster, vital flag, enemy composition)
and `game/scripts/combat_outcome.gd` (§8 win/loss test, win booty write-back,
§9 auto-resolve). Tests: `game/tests/test_combat.gd` (13 checks, seeded RNG,
PASS). Every offset below is verified directly against
`reference-private/observations/combat-20260927/wdecor.txt` (regenerated
listing, not the summary above) and, for §9, against
`reference-private/observations/listings-20260927/textek.json` printed with
`tools/claude/alis_pretty.py`.

**Correction to §4 ("Class by type").** The numbers cited there
("locomotive 5", "GQ 22", "boudoir 23", "barracks/XL 1", "cannon 2",
"machine gun 3", "livestock 4", "tender 8", "merchandise 6") are wdecor's own
internal per-wagon combat **class** ids, assigned by a 25-case switch on
`main[0x2e1a][i][0]` at wdecor 0x0440-0x0592 — not wagon TYPE ids. Decoded
exactly: type1->class5(locomotive), type2->class22(**GQ**), type3->class23
(**boudoir**), type4->class14, type5->class10, type6->class9, type7->class4
(livestock), type8->class19, type9->class18, type10->class15, type11->class2
(**cannon**), type12->class3(**machine gun**), type13->class20, type14->class13,
type15->class11, type16->class17, type17/18->class6(merchandise), type19->
class12, type20->class21, type21->class8(tender), type22->class16, type23/24->
class1(barracks/XL), type25 and any unmatched type->class7(wreck; also forced
for any type whose health reaches 0, wdecor 0x05ec-0x05fc, before the class==5
companion-slot check at 0x0607 — so a destroyed locomotive gets no companion
slot). This means the starting 6-wagon train (`train_wagons.gd::INITIAL`,
types 1,21,2,3,17,23) is locomotive, tender, **GQ**, **boudoir**, merchandise,
barracks — confirming the GQ and boudoir are wagons 3 and 4 of the original
train, not separate from the cargo table as `captain-crew.md` left open.

**Correction to §4 ("machine gun or cannon (×2 weight)").** wdecor
0x07e5-0x0899: `rnd(5)` selects 0->barracks, 1->livestock, 2->machine gun,
3 **or** 4->cannon. Only cannon is doubled (weight 2/5); machine gun carries
the same weight as barracks and livestock (1/5 each). Ported exactly in
`Setup.enemy_composition`.

**New finding, not in §4: a trading-wagon placement collision oddity.**
wdecor 0x0743-0x079a: each of the `trading` merchandise wagons gets up to 2
random slot picks (1 retry if the first pick is already occupied). If both
picks collide, the code checks whether slot 2 is free, but if so it force-
writes merchandise to the **last tried slot** (`LOC8398`), not to slot 2 —
potentially clobbering whatever was assigned there. Ported exactly in
`Setup.enemy_composition`'s collision branch, cited at the call site.

**§8 win/loss test (wdecor 0xef1-0xf43):** structurally confirmed — an AND of
two `<=0` tests reaches the win jump (0x589d), an OR of a `<=0` test and the
vital-flag check (`olocb[8374]==0`) reaches the loss jump (0x609a) — but the
exact `LOCw[0x215a]`/`[0x2160]` array indices are printed as `?` by the
disassembler even in the regenerated listing (garbled operands, not a summary
shortcut). `Outcome.is_win`/`is_loss` are implemented from combat.md's stated
counts (enemy guns/soldiers/mammoths, player soldiers/mammoths, vital flag),
which is what the structure supports.

**§8 win write-back, confirmed exact (wdecor 0x58c9-0x6053):**
- Destroyed tender: `rnd(3)==0` -> anthracite -=5000, else lignite -=5000
  (2/3 lignite, 1/3 anthracite — combat.md's "5000 lignite (2/3) or
  anthracite" is now numerically exact, 0x5976-0x598b). Either pool can go
  negative and is covered from the other, floored at 0 (0x5992-0x59d9).
- Destroyed SPY wagon (type 22) clears aboard (state-1) spy records
  (0x59f0-0x5a2f). This codebase does not yet model the full 20-slot/
  15-field `main[0x5d84]` table (`captain-crew.md` §4); `apply_destruction`
  takes a simplified 0/1 "aboard" array (matching `city_trade.gd::spy_slots`)
  and clears matching entries — a documented simplification, not a guess at
  undecoded state.
- Any destroyed wagon (any type) has goods and quantity cleared
  (0x5a6b/0x5a79) — general rule, ported in `apply_destruction`.
- Lignite booty: `(n*2 + rnd(50)) * 10` (0x5be2), limited by 5000 per intact
  tender minus current lignite+anthracite, then `main+0x2fb6` (lignite) is
  clamped: if `<0 or >31000` -> set to **31000** (0x5c86-0x5c9d, the same
  clamp-to-cap-even-if-negative pattern `city_trade.gd::commit` already
  implements for the identical field).
- Slaves: `3n+rnd(3n)` (0x5cab), filled into PRISON (type5, gate and cap
  both 60) then ALCATRAZ (type6, gate and cap both 100), in wagon-table order,
  overflow lost (0x5ca4-0x5dc5).
- Survivors: BARRACKS (type23, cap 50) then XL BARRACKS (type24, cap **100**,
  0x5ee8) — confirms combat.md's named oddity exactly against the listing;
  the manual's "80" is simply wrong, not a rounding artefact.
- Mammoths: LIVESTOCK (type7), cap 5 per wagon (0x5f79-0x6053).
- Captured trading wagons: up to 6 (0x5aa5-0x5bad), type = 17+rnd(2)
  (MERCHANDISE/XL 50/50). The exact per-wagon **damage state** written at
  0x58d9/0x5af1 is not decoded — those two lines read garbled operands
  (`?`) even in the regenerated listing, not a shortcut taken here. `win`
  booty in this port uses `state=0`; the pool sizes for survivors and
  mammoths (originally `LOC8528`/`LOC8530`, accumulated by the tick-based
  destroy handler at 0xab6) are accepted as **inputs** to `win_survivors`/
  `win_mammoths` rather than computed, because they depend on
  `combat_state.gd`'s tick simulation (§10, deferred — see below).

**Goods/capacity sub-formula for captured trading wagons, resolved exactly**
(wdecor 0x5b0a-0x5b5a and textek 0x59a5-0x59ee, byte-identical structure):
`roll = rnd(16)+1` is always >= 1, so the `cswitch2` base -2 only ever
reaches 4 of its 8 branches; working through them, capacity is **always 40**
in every reachable path, and goods stays `roll` only when `roll==3`,
otherwise goods is replaced by `10+rnd(7)`. `capture_trading_wagons` is
shared verbatim between the win path and auto-resolve.

**§9 auto-resolve (textek 0x49fc), confirmed exact:**
- Pools (0x4a30-0x4a96): gate is `state<3`, switch on the raw wagon TYPE
  (not the wdecor class table): type7 -> mammoths += qty, type11/12 -> guns
  += 1 (unit count, not qty), type23/24 -> soldiers += qty.
- `P = (soldiers + mammoths*20 + guns*50) / 50` (0x4aab) — exact match.
- `a = strength/100`, `b = strength%100`,
  `n = rnd((a+b)/2) + (a+b)/2 + 1` (0x4ac8-0x4ae8) — same shape as wdecor's
  enemy generation but its own independent roll, on a /100,%100 basis
  (auto-resolve never spawns a real enemy-train record).
- `margin = P - a` (0x4b04) — exact match to combat.md's `m=P-[7]/100`.
- Game over: `(phase==44) & (margin<=0)` -> message 105 (0x5435) — exact.
- Casualties: `x - x/(margin+1)` (0x4c11/0x4c95) — exact; kept as written,
  including the "larger margin removes more" oddity (test asserts the
  direction explicitly rather than just the formula).
- Coal: `((n*2 + rnd(50)) + 1) * 10` (0x4de6) — the "+1" combat.md names is
  now pinned to exactly one extra unit inside the parenthesis, distinct
  from the win path's formula (no "+1").
- Slaves: `3n+rnd(3n)` (0x4eee), same as win, but the PRISON **entry gate**
  is `qty<30` (0x4f39) while the **fill target** is still 60 — confirmed
  byte-exact; this is a genuine original bug (a PRISON sitting between 30
  and 59 is skipped entirely by auto-resolve, but not by a real win), kept
  exactly and exercised by a dedicated test.
- Scrap: `9-margin` wagons (caller-side unrolled call sites to 0x5891,
  clamped at 0 here since no negative-count case is observable in the
  bytecode), each attempt filtered to types 4-20 exactly (`type>3 &
  type!=21 & type!=22 & type<23`, 0x58bc) with the exact 2-attempt/1-retry
  structure at 0x58a6-0x5973.
- Captured merchandise: `min(margin, 8)` (0x5891 phase-46 gate), reusing the
  shared `capture_trading_wagons` formula (0x5974-0x5a56, state always 0,
  unlike win's undecoded damage state).

## 13. Not ported (item 4, combat_state.gd) — deferred, not attempted

The tick-based grid simulation (cannon reload 23, machine-gun burst 13 with
column targeting, melee, dynamite fuse/defusal, per-wagon enemy AI §5-§7) is
**not ported in this slice**. Reasons, each a named gap rather than a guess:
- §3's own conflict (manual vs. code disagree on which end of the grid is the
  enemy train) is unresolved; combat.md itself says "check in an emulator".
- The roof-slot geometry (`LOC[0x19a6]`/`[0x1cea]`, 4 slots per wagon) and the
  grid-cell-to-screen mapping needed to make column targeting, melee ranges
  and dynamite placement meaningful are not decoded to the point of being
  portable as logic distinct from rendering.
- The win-booty survivor/mammoth pool sizes (`LOC8528`/`LOC8530`) and the
  captured-wagon damage state (0x58d9/0x5af1) are populated by this tick
  simulation; `combat_outcome.gd`'s win-path functions accept them as
  parameters so they compose cleanly once this item is picked up.
