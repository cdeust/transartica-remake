# Campaign route acceptance checkpoint

Owner: world agent. Full campaign route replay is in progress; do not treat the preliminary route planner as a victory proof.

## Verified TABLE-start to Urga

Original start(12,62), heading6, original6wagons, 2000lignite/500anthracite; no teleport, inserted cargo, heading assignment or fuel injection. EngineState handles every simulation cycle; source firing levers are turned off at the original32000pressure cap and reopened at the original1500drive threshold. Every map movement uses TrainJourney.advance with campaign/world pre-entry checks. Calendar advances normally and applies timed bridge/mines/spy hooks. Seed1 reproduces commerce stocks and mine creation.

Replay finances inventory through actual source commerce: buy20fur city38 unit2, sell20city31 unit60; buyXLmerchandise18 atRuhr11 price400; buy38fur city38/sell38city31 (40would correctly refuse the tender's storage limit); buyprison5 atInSalah10 price150; buy15slaves atLouxor4 unit12; buy29rails atcity35 unit4 (30correctly refuses actualstock29). Repaircrevasse25,24 consuming18rails, then6,9 spendingremaining11 according to the original minimum10entry requirement; buyDrill8 atRum15 price800, positioned at the tail by its actual purchase. ReachUrga23,67 from24,67 onday10 with2703lignite. 4730actualadvance calls,716enteredcells, including real switches, manual reversals and station departures. The Urga event setsits originalkey only after actualstation refusal/lookup.

## Route bug fixed

Before the fix, planner/replay stopped at Oasis code-113/-114: these were blanket special frontiers and had no rail ports. TIME0x1ccd writes(29,67)=-114 and0x1cfe writes(30,67)=-113. TIME0x14aa takes absolute code;0x14c9 turn table has cases6..57, so113/114 retainheading. Original disclosed neighbors28,67=54 and31,67=2 plus Drill32,67=2 establishtheE-W corridor. Entry now permits only those exact coordinates/codes with installedcampaignpreentry capability; standalone networks and unrevealed-115 locations remain blocked. RailGlyphs uses adjoining E-W geometry. No blanket bypass of special sites.

Remaining acceptance: actualshopping/replay forspy transport+recruitment; Mausoleum/Oslo/manualquiz+code; centralspytravel+confirmed sabotage; Gycode/slope/Minotaur/finale/Sun. Random enemy and manual battle acceptance remain separate root/combat-owned flows and are not inferred from this model route checkpoint.

Native measured regression, same seed/model driver and original start:

```
BEFORE EXIT 1
STOP No supplied-resource route to (23,67); frontier includes (30,67):-113
ACTUAL ADVANCE calls=3879 entered=580
AFTER EXIT 0
ARRIVE city=-2 ahead=(23,67) from=(24,67) day=10 fuel=2703/0
ACTUAL ADVANCE calls=4730 entered=716
```

The before run temporarily removed only the corridor entry/glyph behavior, executed native Godot, and restored both owned files in a `finally` block. Native test_campaign_corridor passes both E-W advance directions and retains standalone/unrevealed boundaries. Original CARTE contains no bytes142/143; none of the three hidden-region record sets supplies these values. Their only verified map writers are the fixed Oasis reveal instructions above. Final staged craftsmanship and source checks report zero errors and zero warnings.
