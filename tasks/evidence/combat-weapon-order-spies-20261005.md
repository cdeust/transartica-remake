# Enemy weapon order and destroyed spy wagons

The private ECS listing `reference-private/observations/combat-20260927/wdecor.txt` starts enemy weapon execution at the last slot (`0x17b4`) and decrements the slot index (`0x1979..198c`). Player visible weapon execution ascends slots (`0x5001..5420`). `tactical_weapons.gd` previously ascended both trains. It now descends only enemy slots, retaining enemy-before-player execution and the existing player camera window.

Destroyed spy wagons scan records from slot0 (`0x59f0`). An aboard record clears all15 fields (`0x59f6..5a2d`). The quantity decrement (`0x5a35`) executes even when the record is not aboard; the loop stops when the decremented byte reaches zero or after slot19 (`0x5a43..5a69`). Thus quantity1 scans one slot, quantity2 scans two, and quantity0 underflows and scans all20. This original oddity is preserved with signed byte arithmetic, following ALIS `amaintc`, `addnames.c157..162` and `mem.c182..185`. The wagon quantity is then cleared at `0x5a6b`.

`combat_outcome.gd` previously cleared every aboard spy slot regardless of the destroyed wagon quantity. It now passes that quantity to the source slot scan. The commerce slot list remains the integration boundary: `campaign_session.gd:208` calls `sync_recruits` before advancing spies, and `campaign_spies.gd:13..19` clears the full record when its aboard slot was cleared. No missing full-record cleanup was found in that path.

`test_combat_source_order_spies.gd` checks enemy descending and player ascending cannon presentation order and one reload update per weapon. Spy cases cover quantities0/1/2, a surviving second spy wagon, complete15-field record synchronization and a posted spy in the first slot. The posted record survives, while still consuming one scanned slot as the listing specifies.

The identical test using the previous committed weapon/outcome modules exits1 with76 rule failures. Corrected modules exit0. Existing `test_combat.gd`, `test_tactical_combat.gd` and `test_campaign.gd` also exit0. Logs are `.cache/combat-source-order-spies-{before,after,combat,tactical,campaign}.log`. Both versions produce the pre-existing Godot macOS certificate lookup message.

This establishes source and regression behavior. Native simultaneous enemy fire and native spy-wagon destruction after these changes remain unverified. The earlier mammoth footprint boundary remains documented separately.
