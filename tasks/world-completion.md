# World completion checkpoint

Base: origin/main bf9f9501711a05a6d4a1b1eca318ac4d0263dcf6.
Owner: world worker; root integrates main/session saves.

External gate: native Godot tests must prove mine map writes and save/resume,
map repair only after the TEXTEK close click, and station management costs/actions.

- [ ] Mine map mutation validation and session API.
- [ ] TEXTEK works labour/countdown and close-time map commit.
- [ ] Station management move/repair/remove and wagon cards.
- [ ] Foreuse candidate mutation and empty station stopping.
- [ ] TOWN information/visited state.
- [ ] Native action and persistence tests, source evidence, integration handoff.

Source audit: YODA 0x25c2 waits until TEXTEK ends before writing repaired map.
TIME 0x1c31 accepts THE DRILL only at either end for (32,67), tile35->2.
Station without city is YODA msg34/TEXTEK16, not glieu management. Tile65
opens glieu with city index -1; its 0x21ea management entry provides move,
repair, remove and wagon information. Spy/cars effects belong to campaign.
