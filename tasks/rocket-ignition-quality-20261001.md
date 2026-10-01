# Rocket ignition and effect detail

> The rocket launch should look like more or less the ignition of a real rocket. effects should be real detailed effects. Look at noita effects on explosion and other magic, it's really looking incredible

| Reference | Actual artifact | Evidence |
| --- | --- | --- |
| Rocket launch | launcher_scene.gd _exhaust_point/_physics_process; rocket_living_effects.gd observe | BERTA source launch/ascent cursor and nozzle registered in native capture |
| Real ignition appearance | NASA Artemis I high-speed film KSC-20221116-MH-GEB01-High_Speed_Film_Artemis_I_ML_Tower_WON-3327395 | Official NASA footage; reference-only |
| Noita explosions and magic | Nolla Games noitagame.com official trailer/press screenshots | Visual reference; no imported game artwork |
| Current effect detail | living_effects.gd _plume/_burst; living_particles.gd step/draw; living_effects_atlas.gd | Local ca1ece1 baseline and native captures |

Symptom: launch appears as a small isolated flame and discrete puffs; the user rejects its detail and ignition character.
Goal: a continuous nozzle-attached ignition/plume with convincing bright core, changing turbulent pixels and ground smoke; improve blast detail from the same visual reference.
Non-goals: change missile damage, source launch/ascent clocks, scenery equipment or map projection.

Strategy: context engineering and verified reasoning, using fetched primary visual references, actual animation captures and state/clock tests. Original 50Hz visual updates and original BERTA phases remain. Appearance recipes are authored and calibrated against native video, not claimed CFD physics.

- [ ] Inspect official Noita effects and real rocket ignition footage.
- [ ] Replace isolated launch puff with continuous detailed ignition/exhaust and pad smoke.
- [ ] Improve burst turbulence and material detail while preserving existing source rules/RNG.
- [ ] Capture native ignition, early lift, ascent and missile impact sequence; inspect motion and UI legibility.
- [ ] Verify source-state equality, pause/restart/load, display-rate behavior and bounded performance.
- [ ] Independent visual/code review, gates, local checkpoint and preview refresh.

The previous ca1ece1 tests prove state isolation and attachment, not owner acceptance of visual quality.

## Canonical locomotive correction

Owner points to main/game/assets/combat/wagon-01.png as the old locomotive.
Binding: this committed image still holds the former streamliner; runtime kind1
uses tactical_wagon_art.HERO from locomotive-hero.png. Goal: wagon-01 itself
contains the accepted massive locomotive, with consumers using that canonical
file. No new locomotive design is requested. Strategy: reuse inspected accepted
image bytes, update exact references and verify native crop/bounds and asset hash.

## Gatling steering

> Les effets du wagon gattling, sont vraiment pauvres, il doit y avoir moyen d'avoir une animation beaucoup plus qualitatif que ca

Binding: original wagon12 / combat Setup.MACHINE_GUN; tactical_weapons._machine_gun emits the presentation event, tactical_scene registers its wagon point, living_effects renders muzzle/tracer. Goal: a visibly animated sustained Gatling burst with variable muzzle heat and fine moving ejecta/tracers. Original burst cadence, RNG and damage remain unchanged. Native before/after firing sequence is the external acceptance signal.

## Modern presentation direction

> Ma volonte d'avoir une DA beaucoup plus actuelle c'etait justement pour redonner un interet au jeu, d'avoir aussi des scenes de combats plus realistes, et plus nerveuses. La pour le moment on tente de faire un peu mieux en se bridant a cause du systeme de l'amiga.

The Amiga reference establishes content and world rules. It is not an animation
ceiling. Decouple high-frequency effects and weapon motion from12.5Hz combat
callbacks. Original gameplay snapshots can remain intact while authored
sub-bursts, recoil and plume motion continue at visual cadence.

> la trace de flamme marche, mais la fumee contre le plateau du wagon devrait etre pareil que pour l'ignite d'une fusee avec la fumee qui s'accumule contre le sol et proche de la fusee

Acceptance now specifically requires accumulating dense smoke against the fixed
wagon deck near the nozzle, then outward deflection and dissipation after lift.
The working flame trail remains; uniformly rising detached smoke is rejected.
