# Visual iteration contract

Owner request:
> Once pushed.
> Check the feasability to use the quality of the train look in combat mode, to be the actual look everywhere in the game, meaning scaling the map, and everything to have the combat mode view for all the game.
> If it's not possible say so, and move on to improve graphical effects of explosion, cannon shooting, missile shooting, mine, everything having an impact or having an animation to make it noita like in terms of quality of living effect. Meaning making it much more beautiful and impressive.

| Reference | Actual artifact | Evidence |
| --- | --- | --- |
| Combat train look | tactical_scene.gd `_train`, tactical_wagon_art.gd, assets/combat/locomotive-hero.png | Native locomotive-combat capture, measured side crop |
| Map scale and travel | travel_world.gd `_project`, `_effective_zoom`; train_renderer.gd rigid registration; train_camera_fit.gd | Native travel capture, source map contacts, eight-heading tests |
| Explosions and shooting | tactical_scene.gd `_effect`; tactical_weapons.gd source reload/impact/destroy paths; tactical_actors.gd charges | Real source ticks/events and audio cues |
| Missile launch/impact | launcher_scene.gd `_draw_rocket`, `_map`; launcher_model.gd source continuation | Native launcher test, source phase/cursor |
| Mine and work animations | world_event_screen.gd; works_dialog.gd; world_session.gd | Actual question/accepted/result flow and source commit ordering |
| Material effects | pixel_field.gd; tactical_materials.gd | Existing falling-cell tests and native material captures |

Symptom: travel presents fewer visible side surfaces than combat, and impacts have brief sparse keyposes.
Goal: determine whether combat presentation can serve travel, then execute the selected visual milestone with native proof.
Scope: presentation changes preserve source geography, game rules and save/input behavior. New remote publication is not inferred.

Strategy: context engineering plus verified reasoning; measured projection/contact geometry and actual rendered output are external signals.

- [x] Verify approved push: origin/main equals79c80b2.
- [x] Assess fixed side projection, map scale and directional-art requirements.
- [x] Leave unanswered travel preference explicit; proceed with reusable effects.
- [x] Implement effects milestone in this registered worktree.
- [x] Verify native captures, source-state equality and pause/resume behavior.
- [x] Measure native CPU draw submission and updates at the bounded peak; GPU frame time remains unmeasured.
- [x] Run applicable tests, gates and independent review.
- [x] Preserve native artifact evidence and clean owner scratch/redundant build outputs; unpublished worktree retained.

Feasibility evidence: combat-view-feasibility-20261001.md. A scale-only change cannot supply missing side perspective. Direction-correct combat-quality travel is feasible with directional art and matching depth/contact rendering; the preference question is pending.
