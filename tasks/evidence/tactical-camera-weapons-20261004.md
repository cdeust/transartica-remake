# Combat camera and weapon execution

Primary private WDECOR disassembly: 4fca computes camera minus field center; 4feb derives first visible player wagon from own offset minus that camera displacement; 5420 executes six player slots. The port checked a fixed screen window and froze guns visible after scrolling.

The correction saves optional camera_offset (legacy default zero), validates it during restore, synchronizes the scene camera, and executes the original six-slot window. Enemy weapons retain their existing execution.

Causal regression using the previous weapon helper fails for firing and slot membership. Corrected test_tactical_camera_weapons passes, as do tactical_combat and native tactical_registration. The exact exported macOS package passes the camera weapon regression. Source gate: zero errors; craftsmanship: zero blocking findings, existing scene file length warning. Logs: .cache/tactical-camera-before.log, .cache/tactical-camera-after.log, .cache/tactical-camera-package-test.log.

Native earned combat24376 restored through the normal BATTLEQA save book at24389; journey, wagons, session, calendar and world preserved. Subsequent real machine-gun bursts eliminated the first17 mammoths. Current24428 is paused, all own wagons intact, with remaining enemy units. Campaign and this battle remain unfinished.

The native input console omitted MouseMotion before MouseButton clicks. Inspection shows edge_scroll only resets on motion. Console now emits real pointer motion before clicks and wheel events, and accepts pointer movement; native replay verification remains pending.

Native corrected pointer replay24441(front camera502),24442(rear−521),24443..24464(MG9) and24469..24470(MG7) proves different scrolled weapons execute. All34 mounted units and7 field infantry eliminated; all own wagon hulls3. No camera drift when the pointer returns inside.24493 deploys18 soldiers from a scrolled barracks.

24500: all18 soldiers reach enemy roof.24520: native victory over additional slot8,5 own soldiers killed,all own wagons intact;640L loot,8workers and3 captured merchandise wagons.24521 closes report and pauses map in same batch:1389L0A,60workers13soldiers19wagons,26811steam. Three original enemies remain. Video combat-scroll-native-20261005.mp4 is a montage of actual native captures at1second per checkpoint, not a continuous recording.

Expanded native package retained in builds/macos and executed. Disposable duplicate export ZIP removed after verification: SHA256 c9147c02e87afc05d5f2c08cc2bf070c4cc194232f8bfce31ff50631b58a256f, 200598281 bytes.
