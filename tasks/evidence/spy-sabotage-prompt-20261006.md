# Spy sabotage confirmation ordering

MIT. Bounded correction; native campaign completion and broader spy QA belong to
the main playthrough evidence.

## Native trigger

Earned save10022 was loaded through the normal book as SPYQA at native47128.
The spy was sent to34,21 at47131 and arrived at47133. Confirmed sabotage at47136
changed rail7 to−7 and set spy field13 to100. Selecting DYNAMITE again at47138
incorrectly displayed another confirmation. The model already refused its action.

## Primary reference

Private decoded CARTE listing, reproduced with:

```sh
python3 tools/claude/alis_pretty.py reference-private/observations/listings-20260927/carte.json 27a4 2840
```

- `0x27ae`: travelling state2 OR field13 greater than99.
- `0x27ce`: return when that predicate is true.
- `0x27f9`: display image238 only after passing the guard.
- `0x2805`: form2 confirmation.
- `0x2821`: accepted action adds100 to field13.

`campaign_session.present` now performs the same guard before braking, changing
clock factor, pausing, leaving the room, hiding controls, or playing scene audio.
It clears the temporary confirmation event and returns to quarters. Valid posted
spies with field13 at most99 retain the existing confirmation flow.

## Validation

`test_spy_sabotage_prompt.gd` exercises used fields100/123, travelling state2,
and usable fields99/0. Each case checks presentation, audio, simulation, motion,
clock, room transition, pending-event handling and charge preservation.

Before correction:21 failed assertions, exit1. After correction:40 checks passed,
exit0. Existing `test_campaign.gd` also passed, exit0. The macOS headless system
certificate diagnostic appeared in both passing runs; neither run used the live
native window. Native rebuilt macOS verification47195: loading the earned spent-spy save through the normal book and choosing DYNAMITE returned to quarters without a confirmation. Pending event was empty, presentation hidden and field13 remained100. The train was stationary; its simulation and clock were unchanged by this refused action.
