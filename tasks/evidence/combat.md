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
