# Mine turnaround itinerary projection

Earned native42991 is paused at115,2 heading4 phase2 with a23-wagon train after the Omsk boiler purchase. Cell115,2 is straight tile2, not the previous curve at116,2. Its next114,2 is reachable. The timed bridge110,33 is closed (`-120`). The previous Omsk–Balkhach itinerary crosses that bridge twice, so replanning correctly rejects those crossings at the current hour.

The itinerary aid also omitted the mine exit. `RailNetwork.EVENT_TILES` recognizes mine78 and workshop65. `world_session.gd:47..58` dispatches their native screens. Registered mines reverse through `world_actions.close_mine`, following YODA scene-22 → `0x9ee` → `0x18e3`; workshops reverse through `world_session._close_workshop`. These handlers use physical `reverse_direction`. This is a mine event, not a claim that all78 cells use masked city emergence. Unregistered reversal events have a separate fallback.

`campaign_route_planner.gd` now projects mine78 like its existing workshop65 branch. It preserves the current-cell reversal and fresh phase0 itinerary convention. No gameplay code, native save, network tile, resource or train state was changed.

From exact42991, the updated aid finds154 actions to Balkhach121,32 without crossing the closed bridge or requesting an operator midtrack reverse. The mine arrival is action144:112,33 heading4, switch21, outgoing7 toward111,32. Its projected exit returns112,33 heading3, then switch20 sends it east. This is a logical itinerary projection; the mine close and physical rear contacts require actual native inspection, then a fresh plan from the earned departure state.

`test_planner_mine_turnaround.gd` restores exact42991, checks mine78 against a detached65 contrast, verifies the closed bridge remains unused and confirms planning preserves the network. The identical test against the previous planner exits1 with two failures; the corrected planner exits0. Existing `test_planner_reversal_phase.gd` exits0. Logs are `.cache/planner-mine-turnaround-{before,after,phase}.log`.

Prepared aids are `.cache/native-play/earned42991-mine-arrival.json` (145 actions) and `earned42991-mine-balkhach-projection.json` (154 actions). They are route proposals from this paused save, not completed playthrough evidence. The native pilot must inspect the registered mine and its resource requirements before continuing.
