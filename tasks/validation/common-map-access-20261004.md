# Common panel map access, 4 October 2026

Owner correction: the overall-map icon to the right of the detailed-map icon
is blank in the paused engine room. Both maps must be accessible from the
shared train rooms, with a return to the caller.

| Binding | Evidence |
|---|---|
| Blank right slot | OriginalPanel._draw explicitly covered MAP_COMMANDS[1] in wagon context |
| Missing icon | _draw_map_commands existed but had no caller |
| Wrong room action | BoudoirSession._panel_action code1 selected detailed map outside map context |
| Return caller | BoudoirSession.last_room and Main._open_panel existing room dispatch |
| Slots | tasks/evidence/panel-layout.md, decoded ECS x162..193 and x197..228 |

This is an owner-requested presentation adaptation: the modern panel makes both
map slots available in engine, boudoir and quarters as on detailed travel map.
The private ECS reference branch keeps its original wagon-context command.
Reverser and brake remain active only in map context. Map topology, actor
positions, campaign state and elapsed game time are outside this change.

Plan and acceptance:

- [x] Use the existing two slots and authored icon atlas; stop blanking overall map.
- [x] Open overall map from modern shared rooms and remember the visible caller.
- [x] Return with its panel button or Escape to that caller.
- [x] Headless input/controller regression: room/map matrix and resize coordinates.
- [x] Root native acceptance: while paused in engine, click the right map icon,
  inspect overall map, click return; engine must reappear with pause retained.
  Repeat from boudoir, quarters and detailed travel map; verify icon appearance.

Headless controller tests are prepared UI fixtures, not campaign gameplay or
visual acceptance. Native inputs remain exclusively owned by the root agent.

Root rebuilt and launched the actual private macOS bundle. Native viewport
inputs/captures10476..10478 prove engine to overall map and Escape back;
10482..10484 prove quarters to overall map and back (capture10482 shows quarters;
the older observer calls this screen engine);10487..10489 prove boudoir to
overall map and panel-button return. Native10497..10498 prove detailed map to
overall map and panel-button return. All remain paused with identical logical
position and game cycles. The map icon is visible in each shared panel.

Verification: test_common_map_access, test_original_panel, test_ecs_panel and
test_panel_works_modal pass with Godot4.5 headless. The Main fixture emits the
existing macOS system-certificate error and ObjectDB exit warning; there are no
script errors. test_boudoir's native expectation now checks return to detailed
map when that was the caller; its native run remains pending with root.
