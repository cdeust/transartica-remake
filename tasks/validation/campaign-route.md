# Original campaign route acceptance

Owner: world agent. The native deterministic replay completes the reference campaign from the original TABLE start through the Sun finale. It uses earned supplies and actual journey steps; there is no teleport, inserted cargo, injected fuel, hand-written quest flag or fabricated battle outcome.

## Reproduce

Build the ignored private map/commerce/campaign data with the project packaging tools, then run:

```sh
.toolchain/Godot.app/Contents/MacOS/Godot --headless --path game --script tests/test_campaign_route.gd
```

The test writes the full action ledger to `.cache/campaign-route/replay.log` and the actual pre-encounter state to `.cache/campaign-route/encounter.json`. Commerce and encounter RNGs both start with test seed1. Gameplay difficulty remains the original TABLE default0; enemy spawning, movement, player switch history, scripted slot29 and spy observations run normally.

Native Godot4.5 result, zero errors or warnings:

```
ACTUAL ADVANCE calls=10565 entered=1713
PASS: TABLE-start earned campaign, source story/quiz/spy/workshop/reception inputs,
default enemies, actual Minotaur result, Sun finale to OPTIONS; day23 fuel1207
```

The route planner reads exact rail ports, original turns, switch alternatives and documented hidden-region records. Its predicted reveals never survive planning: each detached tile lookup restores the live tile immediately. Only the actual world/campaign pre-entry handlers make gameplay map writes. Every entered cell comes from `TrainJourney.advance`; every cycle executes the engine, calendar, mine, spy and enemy rules.

The SceneTree host adapts presentation callbacks and binds the actual gameplay objects to real campaign, reception, workshop and combat-report controls. Story buttons and manual answers go through their source key handlers; reception and workshop actions go through mouse handlers. The test observes the ending transition rather than setting it. It does not replace the separate native main-scene, visual-quality or Windows executable checks.

## Earned shopping and actions

| Stage | Actual source transaction or action |
|---|---|
| Start | Position(12,62), heading6, original six wagons,2000 lignite/500 anthracite. |
| Initial trade | Granada38 buys20 fur at2; Amsterdam31 sells20 at60. Ruhr11 buys XL merchandise18 for400. Granada buys38 fur; Amsterdam sells38. Ruhr buys a second XL merchandise18 for400. The tender limit correctly refuses a40-fur sale in the exploratory run. |
| Works and Drill | In Salah10 buys prison5 for150; Louxor4 buys15 slaves at12. Turin35 buys29 rails at4 (actual stock29 refuses30). Real crevasse repairs at(25,24) and(6,9) consume the complete29 rails. Rum15 buys Drill8 for800 at the tail. |
| Real enemy avoidance | Marrakesh41 and Louxor4 are actual station waypoints after Rum, avoiding the real slot0 encounter on the shorter route. No enemy or RNG state is weakened or removed. |
| Urga | Arrive at station(23,67) from(24,67),day11,fuel1912. The actual Urga dialogue sets the key after station refusal/lookup. |
| Spy | Gdansk13 buys spy wagon22 for500. Berlin8's SOLEIL manual control is answered through its real dispatcher. Its source garrison recruits one spy at the actual zero price. The real spy menu sends that recruit from(35,21) to(65,20); calendar calls move it one cell every third call until posted. |
| Mausoleum | Arrive at(53,32) from(54,32),day14,fuel905. Read the actual document containing delivery code58947 through the story screen. |
| Further trade | Copenhagen27 buys50 rails at3 and30 wolf meat at10. Kiev32 sells30 meat at50. Baku16 buys harpoon9 for600 and oil wagon15 for300. Kiev buys20 gasoline at12; Turin sells20 at80. Gdansk buys cannon11 for450 only after those sales finance it. Actual lake repair costs are paid from the purchased rails. |
| Whale and Oslo | The intact harpoon clears the whale and immediately invokes the source reversal before message53 is dismissed. Actual switches return toward Oslo. Arrive at(35,4),day19,fuel1063. The VIKING manual control and58947 input run through the real Oslo dispatcher; delivery_open must be true. |
| Central sabotage | The source spy menu selects DYNAMITE, selects the posted spy at(65,20), displays the real confirmation and accepts Y. The resulting central flag is asserted. |
| Train preparation | Reach the actual Leeds workshop tile65 at(12,17). Its REMOVE menu, train-strip scrolling, wagon selection and YES controls remove completed-quest freight and barracks, retaining the original four protected wagons plus the earned cannon. Count5 satisfies the original slope rule without buying Boiler25. |
| Combat option | A real click on the reception COMBAT plaque changes the original preference to automatic. Default difficulty0 remains unchanged. |

Engine firing uses actual lever APIs: exhausted fuel is turned off, the source32000 pressure cap closes firing, and the source1500 driving threshold reopens available fuel. Stops/reversals use source brakes and zero speed. No artificial heat, pressure or movement speed is supplied.

## Final map gates and battle

The actual source route records:

```
(157,68) heading8 wagons5 fuel797 tile3
(152,48) heading1 wagons5 fuel797
(151,66) heading6 wagons5 fuel636 slot29state0
(152,66) heading6 wagons5 fuel631 slot29state-1
actual encounter at(154,62), slot29 strength19
```

The live Gycode tile becomes3 through TIME0x1e98 after confirmed central sabotage. The slope check at TIME0x1f53 sees five wagons. Crossing151,66 first clears the scripted slot; crossing152,66 then creates it through TIME0x1d8b, and its actual movement produces the encounter. The test does not bypass the Minotaur.

The real automatic resolver produces potential1 and margin1, wins, grants640 lignite, scraps the earned cannon at index4 and captures one XL merchandise wagon. Its real report is closed with Return. The encountered slot must have the source REMOVED state afterward. This automatic/manual asymmetry is original: TEXTEK computes potential from guns/soldiers and subtracts strength/100, while WDECOR's manual composition uses a different strength decomposition. No invented balancing replaces it.

The train then refuses entry to the actual Sun station(148,60) from(148,61),day23,fuel1207. CampaignSession displays the Sun dialogue; Return starts the authored IFEBO sequence. Its original120 intro ticks plus241 cloud ticks advance at50Hz and emit movie_finished. The real session transition reaches OPTIONS, hides the movie, empties pending dialogue and retains ending=sun. The test asserts every final map gate, slot removal and transition.

## Primary evidence

- TABLE initialization, TIME0x0486..067d phases/progress and0x14c9..1913 heading/switch rules: `tasks/evidence/rail-network.md`.
- Commerce, stock, prices, storage refusals and GLIEU workshop0x1d64..21e7: `tasks/evidence/city-scripts.md` and private commerce tables.
- Works shortage, consumption, close-time map writes and TEXTEK timer: `tasks/evidence/obstacles.md` and `world-completion.md`.
- YODA0x18e3 reversal; YODA0x1479/1487 harpoon clearance and reversal; TIME0x1f53 slope: private ECS listings and `campaign-completion.md`.
- CARTE0x1dc9/1de0 spy dispatch, TIME0x976 travel,0xbc9..c64 central discovery; CARTE0x27a4..28cc confirmed sabotage; TIME0x1e98 Gycode: `campaign-completion.md` and private listings.
- YODA0xe80/ec8 SOLEIL control; SCENE4d5..3b5 VIKING/Oslo control: `campaign-completion.md`.
- TIME0x1d8b/1e1b scripted slot; TABLE default difficulty0; original scheduler and encounter ordering: `tasks/evidence/enemy-trains.md`.
- TEXTEK phases44..46 automatic result, casualties, scrap, booty and captures: `tasks/evidence/automatic-combat-integration.md`.
- IFEBO0x24d..346 intro waits and0xa2..141 clouds/palettes, original50Hz cadence: `campaign-completion.md` and `finale_sequence.gd`.

## Bugs exposed by actual replay

The early geographic planner did not prove completion. Default enemy movement exposed a real encounter; the shorter route was replaced by actual source station waypoints, and earned commerce subsequently financed the actual Minotaur battle.

The Oasis corridor was incorrectly blocked as a special frontier. TIME0x1ccd writes(29,67)=-114 and0x1cfe writes(30,67)=-113; the turn table retains heading for absolute113/114. Disclosed neighbors28,67=54,31,67=2 and Drill32,67=2 establish E-W ports. Commit54673c4 permits only those exact coordinates/codes with installed campaign pre-entry capability. The original TABLE-start replay failed before at3879 calls/580 cells and passed after at4730 calls/716 cells; the focused corridor regression retains standalone/unrevealed boundaries.

Commit9c9c1c6 fixes center-seeded reversal rendering: the actual Gdansk/Berlin leg exposed incoming_heading0 at a trailing switch, which _advance_render incorrectly indexed. Native regression fails before and passes after; no incoming track is fabricated. See `center-seeded-reversal.md`.

Actual source spy-menu inputs exposed CampaignScreen.open_menu's typed Array argument mismatch, hidden by isolated model calls. Campaign owner's931ffef fixes it and supplies its own regression. The final route requires that fix and the source finale commit.

Both source and craftsmanship checkers report zero errors and warnings for the route test/helpers. Borrowed campaign/combat modules and authored assets used to validate the isolated worktree are verification dependencies only and are excluded from this commit. No remote publication or Windows runtime claim is made.
