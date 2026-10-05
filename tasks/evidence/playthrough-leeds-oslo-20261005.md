# Native Leeds to Oslo continuation, 5 October 2026

This records the continuing player-input campaign. Step IDs refer to the local
native journal; historical assets, full decoded datasets and private captures
are excluded from this document. The campaign ending remains unverified.

At Leeds, native step36017 repairs the damaged TYPE17 carrying 20 rails for 10 lignite.
Steps36018..36024 remove seven empty TYPE17/18 wagons. Steps36025..36036 reorder
the remaining 22 wagons into:

```text
1,21,12,2,11,3,17,11,23,22,12,5,16,11,18,17,9,11,18,13,18,8
```

Four cannons and two machine guns occupy positions 2,4,7,10,13,17; drill TYPE8 is
last. Cargo, spy, crane and harpoon are retained. The saved36036 roster verifies
this exact order. Repair pricing and unchanged-index insertion are implemented
in `train_management.gd:33–37,74–82`; this is rearrangement evidence, not proof
of combat effectiveness.

The wolf encounter36105/36106 costs 8 soldiers and 10 workers, leaving 41/50.
Its saved report declares no material losses. Harpoon encounter36555/36556
clears the whale flag. The earned36556 state retains 22 wagons and two missiles.

Combat36694 against enemy10 remains paused and was abandoned without resumed
ticks. Intro36699 temporarily creates a new game without F5. Normal named-book
restore36701 recovers earned36556. Direct comparison verifies identical nine
blocks: journey, wagons, session, calendar, world, campaign, encounters, trade and trade_rng.
Missile36705 then launches at bearing 7, distance0307, target10. Report36706
records enemy10 STATE2; dismissal36707 debits one missile, leaving one.
`launcher_session.gd:67–91` implements removal and delayed ammunition debit.

The Copenhagen detour is explained by reverse rear contact. Saves36257/36688
place the locomotive at20,10, but record physical station34,12 and heading2.
The saved path and production chord solver place the final rear contact at
34,11.5. EXIT36689 consequently emerges at34,11, as prescribed by
`train_journey.gd:149–170`. City selection does not cause this movement.
This is the remake's physical-contact and station-emergence adaptation.

Oslo37485 opens its dialogue. Quiz37486 selects VIKING index6; DEPLACE is
accepted37487. Code58947 is accepted37488, displaying the Geiger message and
setting delivery_open=true. Departure37489 clears the pending dialogue.
Sources: `campaign_session.gd:59–60`, `manual_quiz.gd:12–23`, and
`campaign_state.gd:137–150`. Saved37489 confirms the completed delivery branch.

The exact b014725 DEBUG export runs natively as PID20244, including the
Oslo input sequence above. Headless
export exited0; ZIP integrity passed. Artifact
`builds/Transartica-macOS-playthrough-b014725.zip` SHA256 is
`e7a892bc967b4ef91ce2014d737aa59f08d5d02d1c5cad0583a49d02b57b32bd`.
Export log: `.cache/export-macos-playthrough-b014725.log`; its sole error is the
existing macOS certificate lookup diagnostic. Export success alone is not native
campaign validation.

At37489, boiler25 is absent and scripted enemy29 remains STATE0. Its spawn,
destruction and the Sun ending are still unchecked. Omsk equipment purchases
and its separate VIKING city quiz remain pending.
