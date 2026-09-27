# Automatic combat transaction — 2026-09-27

`AutomaticCombat.resolve(wagons, engine, strength, rng)` assembles TEXTEK
phases44→45→46 into one synchronous rules transaction. It does not implement
interactive battle. The automatic-combat option is attested by the private
manual, `reference-private/observations/combat-20260927/manual.txt`, lines264–266.

Primary source: `reference-private/observations/listings-20260927/textek.json`,
read with `tools/claude/alis_pretty.py` at the narrow ranges below. Wagon input
must be a nonempty valid train and strength nonnegative. Caller owns UI and
enemy removal. A loss returns epitaph105 without changing wagons or engine.

## Exact order and retained oddities

1. Pools: intact type23/24 soldiers, type7 mammoths, type11/12 gun counts;
   potential and margin use existing `combat_outcome` formulas (0x4a30–0x4b04).
2. Enemy count `n=rnd((a+b)/2)+(a+b)/2+1`, a=strength/100,b=strength%100
   (0x4ae8). The phase44 report then consumes three additional random calls:
   gun split0x52a1, soldier count0x52d5, mammoth denominator0x52e8. These
   presentation draws precede the game-over test0x5435 and affect later rolls.
3. On margin<=0, return loss. No casualties, scrap or loot occurs.
4. Phase45 announces aggregate losses `pool-pool/(margin+1)` then debits
   wagons in order (0x4c11/0x4c95/0x4d10–0x4dcd). The debit loop has no
   damage-state filter. Soldier debit matches type23 **or quantity24**, not
   type24. Thus an XL barracks with quantity24 is debited; others escape.
5. A further source oddity: debit budget changes only after an underflow,
   becoming the positive remainder while the wagon is zeroed. If a wagon
   can pay, that budget is **not cleared** and is debited again from later
   matching wagons. This applies to soldiers and mammoths. Returned
   `soldiers_lost`/`mammoths_lost` are original announced aggregates, not a
   claim that actual troop differences equal those numbers.
6. Scrap target is max(0,9−margin) (0x5140). There are up to **eight unrolled
   calls**, stopping when enough wagons were actually destroyed
   (0x51d1–0x53fe). A failed pick does not decrement the target; successful
   scrap decrements it at0x5969. The wrapper reuses the existing scrap helper
   one call at a time, retaining its original type filter and one retry.
7. Phase46 draws coal0x4de6 and slaves0x4eee, using the existing capacity
   helpers. This is **after scrap**; a scrapped prison cannot receive slaves.
   Finally it attempts min(margin,8) captured wagons, capped at100.

Randomness uses the remake's existing injected Godot RNG convention. It is
repeatable for the same Godot seed and state, not binary-compatible with the
original ALIS generator. `_rnd(0)` still advances once: original `ornd`
updates its state before multiplying by the bound (`opernames.c`433–437).

## Captured-goods correction local to this transaction

The existing shared `capture_trading_wagons` helper and combat.md's earlier
interpretation of its goods switch are incorrect. Primary VM `cswitch2`
(`opcodes.c`744) **adds the signed switch base**, so TEXTEK0x59b0's base−2
maps rolls2..9 to all eight entries, not just four reachable entries:

- roll2/3: capacity10, keep goods (0x59ca);
- roll5/6/8/9: replace goods with10+rnd(7), capacity40 (0x59d3);
- other rolls: keep goods, capacity40 (0x59e9).

Type17 draws quantity `rnd(capacity/2)+1`; type18 uses `rnd(capacity)+1`
(0x59fc–0x5a3e). New automatic-only `_capture` follows this switch exactly.
The older shared helper and its incompatible tests were not changed because
they are outside this implementation's ownership. Interactive win behavior
must not be claimed corrected by this automatic transaction.

## Result contract

Result fields: `won`, `margin`, `potential`, `enemy` report pools,
`soldiers_lost`, `mammoths_lost`, `coal_gained`, `slaves_gained`,
`scrapped_indices`, `wagons_captured`, and copied `captured` wagon records.
Loss additionally supplies `epitaph_id=105`. Success updates engine train mass
from the final wagon table. Save persistence remains the caller's responsibility.

## Verification

Godot4.5 headless `test_automatic_combat.gd` passed, exit0, covering:
zero/negative-margin loss with no mutation; ordered debit underflow, repeated
budgets, quantity24 and XL bugs; independent expected RNG sequence including
eight unsuccessful scrap attempts; exact seeded replay;100-wagon cap;
remaining tender space; prison29→60 versus skipped30; alcatraz99→100; and
the corrected captured-goods/capacity switch.

Log: registered scratch `.cache/automatic-combat.log` in world-loop worktree.
An initial relative Godot log path crashed the engine logger before tests;
subsequent runs used the absolute registered log path and exited normally.
No combat UI, native encounter or original-ALIS RNG equivalence is claimed here.
