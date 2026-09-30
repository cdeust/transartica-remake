# World integration evidence, 30 September 2026

Base origin/main bf9f9501711a05a6d4a1b1eca318ac4d0263dcf6. Private original
listings were read directly with tools/claude/alis_pretty.py.

Source -> implementation -> verification:

| Source | Behaviour | Verification |
|---|---|---|
| YODA0x1e2a..2317 / TIME0x2509 | Mine generation/depletion, exact switch/mine map writes, slot lookup | test_world_actions.gd and test_mines.gd |
| YODA0x25c2..2611 / scene-22 close0x9ee | Mine YES waits for scene dismissal, wealth=-1, tile79, reversal; no cargo reward | test_world_actions.gd pending save/close test |
| YODA0x25c2..2671 | Works spends rails before result and writes map after dismissal | test_works_commit.gd fails before fix, passes after |
| TEXTEK0x4200..4406 | Slaves +30*mammoths +150 with any crane; computed countdown | track_works.gd work_report |
| ALIS storenames.c42 / opernames.c114 | L0x16b countdown is signed byte; overflow reproduced | test_works_commit.gd |
| TEXTEK0x42bd | Exact zero rail quantity retains goods1, only undershoot clears goods | test_works_commit.gd |
| TIME0x1c31..1c75 | End-position THE DRILL opens (32,67), tile35->2 | test_world_actions.gd |
| YODA0x225 | Station without city brakes and shows TEXTEK16, no management | Root integration required |
| GLIEU0x21ea..2b10 | Tile65 station workshop: coordinate title, four-field insertion, repair price*damage, protected removal | test_world_actions.gd including native click callbacks |
| GLIEU0x20e | TOWN options50/51 -> texte2k1..14 | test_world_actions.gd and CityScreen signal |
| GLIEU0x33 | Persistent visited city mark independent of kind | test_world_actions.gd |
| CARTE0x1dc9 / TIME0x0b43 | Spy record state0..3 accepted by trade saves; free-file capacity bounded | test_city_trade.gd + campaign integration |

Commands on the delivered tree: Godot4.5 --headless --path game --script
res://tests/test_{works_commit,world_actions,train_journey,city_trade,mines}.gd.
Each printed PASS and exited0. The macOS sandbox prints a system certificate
error from get_system_ca_certificates before these suites; it is not a script
failure and must be resolved by root's native-host environment before claiming
a fully clean launcher log. No Window/Windows execution claim is made.

Source and craftsmanship tools in zetetic-gates1.1.0 returned zero findings
for modified scripts/tests/scene painter before local commit.

## Root integration contract

WorldActions.attach(journey,wagons,engine,trade,rng). Call before_entry(candidate)
before journey.advance. On calendar mines event call tick_mines(day). On city
arrival call visit_city(index). Save snapshot. For atomic load, stage a WorldActions
against the candidate journey/network/wagons/engine/trade/rng and call restore;
commit only once all extension and base validations pass.

Mine screen: WorldEventScreen.open_mine(world.ask_mine(cell)); answer_requested
calls world.answer_mine(accept). YES calls screen.show_mine(); NO hides scene and
leaves blocked brake. dismissed calls world.close_mine(), hides scene, refreshes
map/convoy. Restored pending_mine/mine_accepted reconstructs this screen.

Station65: StationWorkshop.management=world.management, trade=trade; add full
viewport Control, open(journey.position). cargo_changed rebuilds consist/mass;
depart_requested uses journey.depart_from_station(), keeps engine brake on and
speed0. StationWithoutCity result-1 instead calls works_dialog.inform(16), keeps
stop without reversal.

TOWN: connect CityScreen.town_message_requested to campaign.show_town(id);
campaign.message(id,true) supplies private TEXTE2K texts.

WorksDialog now draws WorldEventScreen authored worksite and preserves _yes,
_no,_ok native Button targets. Save snapshot; validate_snapshot(value,network)
is pure and needs no live Control. After successful staged validation, rebind
journey/wagons/rng and restore. textek_tick() reduces countdown, returns true only
at expiry to restore normal calendar factor; it never auto-dismisses.

## Artwork

New mine/track-works plates are authored MIT640x220 artwork; build_world_scenes.py
uses no source assets. WorldEventScreen preserves scene39..148 and shared HUD
149..199 with NO/OK roles. StationWorkshop uses existing authored industrial
painting and all25 authored train textures, preserving their aspect ratio.
These scenes require root's integrated native visual review before artistic
coverage is marked complete.

## Campaign boundary and bulletin followup

Runtime `network.campaign_entry_enabled=true` removes legacy `STORY_CELLS` stops only after host installs campaign pre-entry evaluation. It is not save data; staged/restored networks need the capability reapplied. All station, works, mine, concealed-region and timed-bridge boundaries remain. Tile79 source TIME0x2565→YODA0x23a uses TEXTEK17; tile65 TIME0x24d0 dispatch retains the workshop reversal flow.

`world.tick_mines(day,stoup)` atomically queues source one-based mine slot IDs after map commit, ordered depletion then discovery (YODA0x1e71/1e7b and0x230a/2314). Replayed ticks emit no bulletin. `world.mines.report(slot,private_phrases)` formats closure/discovery, ore, actual coordinates and signed creation-day magnitude (TEXTEK0x48cc..49fb); campaign owns private phrase extraction and bulletin display. Native Godot `test_world_actions.gd` passes cleanly, including capability defaults, concealed slope refusal, one-based discovery ID, formatter, and no replay notification.
