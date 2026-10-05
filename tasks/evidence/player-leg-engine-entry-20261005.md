# Paused engine entry in the native travel pilot

Actual observation 30619 returns to the engine room after a victory modal while travel is paused. The driver formerly rejected that entry before moving. It now sends the normal M and F5 inputs, requiring a paused map, before regulator setup or travel resumption. Moving engine/map entries and paused combat/city entries remain rejected without navigation inputs.

The preparation sequence is extracted into `prepare_drive` to keep the driver within the existing craftsmanship function-length gate. The previous regulator, loaded-lignite cutoff, brake and clock actions retain their ordering.

Mock protocol regression: before the production correction, `python3 -m unittest discover -s tests -p test_play_player_leg.py` runs 17 tests and exits 1 with the engine-entry test raising `Begin from the actual saved, paused map`. After correction it exits 0 with all 17 tests passing. The existing `test_player_travel.py` also passes. These are protocol fixtures, not native campaign progression. No game console input was used during this implementation.

The detached Godot `test_planner_reversal_phase.gd` exits 0. Source and craftsmanship checks for the two assigned files report zero errors and zero warnings; diff whitespace checks pass.

Independent review of the wider pending pilot changes found a fifth `continue_travel` parameter exceeding the unchanged craftsmanship limit of four. With ownership extended by root, the internal wrapper now accepts a fourth options dictionary containing transit and regulator. CLI arguments are unchanged. Its two mock tests verify completed-waypoint termination with the default regulator and propagation of a selected regulator. Both exit 0; all 17 driver tests still pass.

Source and craftsmanship checks on all six pilot/planner files report zero errors and zero warnings after this correction. The forward-only planner restriction is an operator constraint, and does not rewrite source rail turns. No global regulator setting was introduced.

Root native verification: real paused map30824 opened the engine through the locomotive HUD30825. Updated pilot30826 sent M,F5 and captured the paused map at the same position60,42 and cycle27067;30827 set regulator60,30828 resumed,30829 observed speed5 in normal travel. No save/resource fields were edited. Route toKiev uses the retained forward-only restriction. Root reran all19 Python tests: exit0.

The published pilot also retains the owner4October fuel policy: anthracite only, stop stokers when the visible fire reaches EngineRoomArt.FIRE_HEAT_REFERENCE600, and coast on stored steam. The reheating reserve follows the TIME boiler/drive equations documented in tasks/evidence/locomotive-rules.md. This is a player-input policy, not a new engine rule or proof of a decoded ECS maximum fire stage. Earned travel25819..30824 preserves lignite except actual purchases/sales/loot; anthracite903->813 records actual fuel use.
