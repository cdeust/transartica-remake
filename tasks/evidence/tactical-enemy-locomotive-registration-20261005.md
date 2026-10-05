# Enemy locomotive hidden by tender

Owner reported the enemy locomotive hidden by its tender in paused native40283. In the earned save, enemy slots0/1 are locomotive5 and tender8; player slots0/1 are locomotive5 and reserved companion25. `combat_setup.gd` reproduces these source rosters. The private WDECOR listing at0614..0652 reserves the player companion;0723/072d sets the enemy locomotive and real tender.

The shared geometry fitted the accepted authored engine uniformly to77.34324×26 logical pixels, but anchored every locomotive128 pixels behind its slot front. At40283 its rectangle began at133.5, exactly where the64-pixel tender began. `TacticalScene._train` draws the tender afterwards, covering that engine region.

The correction in `tactical_effects_geometry.gd` retains the texture crop and uniform scale. A locomotive without a reserved companion now starts at its own rear slot boundary,64 pixels behind the front, extending into the clear space ahead. At40283 the engine begins197.5, the tender ends197.5, and their rectangles no longer overlap. The player keeps its existing128-pixel registration. An enemy engine wreck uses the same corrected rear boundary.

Focused headless test `test_tactical_locomotive_registration.gd` accepts an optional read-only earned save. It checks both sides at health0..3, camera extremes and offsets shifted one source wagon slot in either direction. Assertions cover unchanged aspect and scale, tender separation, body lookup, attached events/mounts and unchanged complete battle snapshots.

Using the exact final test with a detached copy retaining the old registration gives exit1:36 enemy rear-registration failures and36 tender-overlap failures. `.cache/tactical-locomotive-registration-before.log` records the old engine rectangle `(133.5,166,77.34324,26)`. With production correction, exit0 and `PASS`; `.cache/test_tactical_locomotive_registration-40283.log` records `(197.5,166,77.34324,26)`.

Headless `test_tactical_combat`, `test_tactical_camera_weapons`, `test_tactical_actor_motion` and `test_tactical_art_cache` also pass, exit0. Logs use `.cache/test_tactical_*-40283.log`. The pre-existing macOS certificate lookup message appears before each PASS. Source/craft checks report0 blocking errors and0 warnings on the scoped files.

These are source and headless geometry regressions. No active native controls, build or restart were performed. Root will capture the corrected paused battle after its normal-book restore of40283.

Native package verification: DEBUG macOS export rebuilt and normal book COMBATQF loaded the byte-identical earned40283 archive at40297. Every prior save block and every prior encounter field remains equal; only source counters are added: own survivors41S/0M, armies[41,34]. Native40297 shows the engine fully ahead of its tender, with the accepted proportions retained. Combat remains paused, ticks122, all resource stocks preserved. The first package exposed raw JSON float membership omitting aboard troops; an actual40283 army assertion fails before int-class normalization and passes after. No combat resumed with the bad counters.
