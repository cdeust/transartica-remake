# Integrated completion review — 1 October 2026

Base: merged PR7 bf9f9501711a05a6d4a1b1eca318ac4d0263dcf6. Later changes are local;
no remote publication is implied. This report supersedes the September25 coverage
snapshot for the implemented systems. It does not certify untested source variants.

| Original system | Integrated implementation | Evidence |
| --- | --- | --- |
| Driving, regulator, brake, reversal, gauges and accelerated calendar | Engine/session, instruments and original control regions | test_engine_controls, test_engine_instruments, test_engine_session, test_application_cadence |
| Original world, switches, concealed story routes and stations | Original private map with source entry gates and shared train geometry | test_train_journey, test_campaign_route; earned original-start route reaches Sun |
| Two maps and common composition panel | Authored detail terrain and source static overview geometry; authored train strip, scrolling and launcher miniature | test_authored_overview, test_ecs_panel; native chart/terrain captures |
| Cities, commerce, personnel and wagon management | Source goods/capacity/stock transactions, seven scene families, workshop reorder/repair/scrap | test_city_trade, test_world_actions; campaign_route_ui |
| Mines, drill, bridges and track works | Source map writes, deferred text close, original countdown, mine depletion/bulletins and reversals | test_mines, test_works_commit, test_world_actions |
| Boudoir, command room, journal, inventory, crew, spies and inspection cars | Source controls, private source texts, retrieval/sabotage/observations and car hazards | test_boudoir, test_campaign, test_campaign_encounters, test_captain_crew |
| Enemy schedule, automatic and manual combat | Original enemy slots, tactics, weapons, outcomes, cargo transfer and resumable battle | test_world_encounters, test_tactical_combat, test_save_extensions |
| Story, original manual quizzes and six death causes | Urga/Oslo/mausoleum/whale/Sun states, interrupted input, source protection questions | test_campaign, test_campaign_session, test_campaign_visuals |
| Ending | Source-timed authored station blast/cloud animation and private source audio | test_finale; native finale captures and earned campaign route |
| Startup and recurring audio | Original boot, all81 signed PCM cues, nine scores, native pitch/first-Oslo/footer/combat and source music-loop boundaries | test_startup_intro, test_game_audio; audio-recovery-source-20261001.md |
| Atomic saves | Staged full session, campaign/world/dialogue/battle/movie states; schema9 audio, commerce RNG, roamers and launcher | test_save_extensions; earned Mausoleum disk replay matches continuous ending |

## Artistic review

The original map/story/gameplay remain the reference. The authored art uses the
owner-approved overhead travel vehicles and side-view combat wagons. Noita guides
material detail, pixel readability, impact debris and lighting; engine parity is
not claimed. Terrain masters, rail atlas, six landmark families, actor sprites and
all25 tactical wagon types are integrated. Native captures exposed and corrected
neighbor-sprite leakage, wheel/coupler crop loss, stale battle masks and duplicate
3×2 city painting. Water detail preserves measured source shore masks.

Native evidence: terrain-start/forest/mountains/lake/city.png;
tactical-actors-native-20260930.png, tactical-wagon-impacts-native-20260930.png,
tactical-wreck-native-20260930.png, authored-overview-native-20261001.png.
The source/static chart preserves its deliberately incomplete original geography;
it does not draw the complete live rail network. Historical RGB reference paths
are absent from the isolated chart PCK verification.

## Remaining acceptance

Final full inventory passes (56test scripts plus core runner);33Python tests and
static-plan roundtrip pass. Staged source/craft gates have zero findings. Independent
integration review found no critical defect in inspected connections. The exact
exported macOS application passes native input and save/load acceptance. Native Windows execution needs
a Windows host and is not proved by exporting on macOS. Physical Amiga audio timing,
exhaustive source visual variants remain
separate fidelity questions; prior source-helper or screenshot tests do not close
them. Source fauna/roamer audit and default-enemy earned route are now verified: campaign-fauna-source-20261001.md and campaign-route-cleanup-20261001.md.

## Final authored integration

Shared massive locomotive replaces the actual train master, dedicated travel and
combat sprites, composition miniatures, HUD engine plaque, nine illustrated
event/startup scenes, mammoth fair, options combat plaque and four boudoir photos.
Exact prompts, generation names and canonical hashes: output/imagegen/locomotive-20261001/.
Native scene proof: locomotive-native.log and locomotive-*-native.png.
Authored mine/track-work plates and16goods atlas complete their runtime scene
families. City native visual/input proof: city-list-icons-20261001.md.

The full original-start campaign uses default enemies and source fauna, earned
cargo, actual story choices and Minotaur resolution. Both continuous play and
Mausoleum disk resume finish after10 657callbacks/1 713cells onday23 with1 067
lignite. This is source-data/application proof; physicalAmiga hardware equivalence
and undiscovered historical visual variants remain outside the measured evidence.
