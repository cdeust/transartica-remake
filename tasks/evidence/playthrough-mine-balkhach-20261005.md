# Native mine extraction and Balkhach workshop - 5 October 2026

Runtime: published game code `8c3e3e5`; travel aid `94be5a0`. Inputs and F5 archives: `tasks/validation/continuous-play-20261003/actions.jsonl` and private `.cache/native-play/saves/`.

- Registered mine 111,32 reached at44001 after the north loop. Normal prospecting and extraction44002–44005 yielded779 anthracite:311→1090. Lignite remained 717. The 50 workers and crane were present; no resources were injected.
- Mine exit44006 retained the occupied rail geometry. The projected workshop route diverged at 116,33, and the controller stopped44078 at 117,32. Normal reverser44079 and travel reached the closed bridge44143. Its normal message dismissal44145 created the source departure to the east. A first drive rejected an unpaused starting screen and paused/saved44148; the next drive reached Balkhach44241.
- Repairs: cannon slot 7 state 2→0 cost 100 lignite44243; spy slot 9 state 1→0 cost 60 at 44245; machine gun slot 10 state 1→0 cost 40 at 44247. Actual cost 200, remaining 517. The earlier estimate 40 was wrong: GLIEU 0x2a48 prices in train_management.gd multiply the type price by state.
- Normal MOVE44248–44249 placed drill type 8 after boiler 25, last in the 23 wagon train. Every wagon now has state 0. Departure44250 and ordinary pause/F5 gave44251 at120,32, heading4, phase−1, reverse=true.
- Additional enemies 7 and 14 were destroyed through native missile reports44011/44016, leaving 5 missiles. These are distinct from the four story enemies. The final story enemy 29 and the Sun ending remain pending.

This proves the native mine and workshop flow, including the failed projection and recovery. It does not prove final campaign completion or complete original combat parity.
