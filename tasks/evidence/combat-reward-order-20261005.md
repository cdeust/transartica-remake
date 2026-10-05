# Tactical reward order

The decoded ECS WDECOR win path captures surviving merchandise at `0x5aa5..5bdf`, then rolls coal at `0x5be2` and workers at `0x5cab`, before survivor redistribution at `0x5de8..6053`. The listing is `reference-private/observations/combat-20260927/wdecor.txt`. Each capture consumes random draws for wagon type, goods, optional substituted goods and quantity. Calling capture after coal and workers changed the loot for the same battle RNG state.

`tactical_result.gd` now calls capture immediately after player damage writeback and destruction effects. Coal, workers and survivors follow in the source order. Captured damage, merchandise filtering, six-wagon limit and exactly-once settlement retain their existing behavior.

The focused `test_tactical_reward_order.gd` reconstructs the source draw sequence with the existing tactical seed420. Cases cover zero, one, two and seven surviving merchandise wagons, damaged captures, a dead merchandise wagon and a non-merchandise wagon. It compares the captured roster, coal, workers and final RNG state, and verifies a repeated commit leaves the result unchanged.

The identical test against the previous committed result implementation exits1 with10 rule failures; the corrected implementation exits0 with no rule failures. Logs are `.cache/tactical-reward-order-before.log` and `.cache/tactical-reward-order-after.log`. The existing `test_tactical_combat.gd` also exits0. Godot's pre-existing macOS certificate lookup message appears in both runs.

Native victory40337 had no surviving enemy merchandise, so this correction does not change its reward sequence. These checks establish source and regression behavior; a native victory with captured merchandise remains unverified after this change.
