# Scoped staged integration review

Reviewer: world_recovery, independent of the root integration owner. Review on
2026-10-01 found no critical defect in the inspected staged runtime connections.
This report describes its inspected scope; it does not claim line-by-line review
of every changed file.

The staged file inventory contained 113 code paths. Direct diff inspection covered
main/main_interface, gameplay_input, boudoir_session, game_boot/game_reset,
journey_session, campaign_session/fauna_session/ambush_snapshot/campaign_snapshot,
world_session/world_ui_save/world_encounters, session_saves/session_save_extensions,
launcher_session/launcher_snapshot, game_audio/game_audio_routes/audio_cue,
engine_room_controls, original_panel/ecs_overview, overview_chart_art, rail_art,
terrain_landmarks/terrain_water_art/travel_terrain, train_renderer,
tactical_scene/tactical_actor_art/tactical_wagon_art, city_screen/city_list_icons,
export_presets/project/main.tscn and the private-data preparation tools.

The model-to-UI checks confirmed source entry handlers run before travel commits,
pending world/campaign/launcher screens block simulation, OPTIONS owns keyboard
input and configured keys retain context-sensitive original actions. START resets
composed state. The actual main scene enables the original boot before OPTIONS.

The save review confirmed candidate state is validated before live commit. Schema9
preserves independent commerce RNG, roaming populations and launcher continuation.
Launcher validation replays its finite source continuation and validates removed
enemy records. Restoring a city reopens presentation without rerolling stock; audio
restores after scene selection. Source ambush reports preserve the already-applied
loss stage, avoiding repeat losses after loading.

The art review confirmed travel/HUD share the hero crop registration and tactical
locomotive uses the matching hero asset. Wagon and actor regions preserve measured
silhouettes; goods use their measured authored regions. Terrain and the static chart
draw authored pixels over preserved source semantics. General map historical RGB
requires an explicit reference environment setting and is absent from the package.

No reference-private, game/private-data, builds or .cache paths appeared in the
staged public file inventory. Both private export presets include private-data and
exclude save and tests. Private historical data/audio remain confined to those
ignored exports; the packages are private development artifacts.

Validation supporting this scope includes the root's completed 57-suite run,
the clean earned continuous/disk-resumed campaign proof and actual exported macOS
acceptance recorded in `desktop-artifact.md`. The last fixture-only audio cleanup
passed three sequential native repetitions without changing packaged runtime code.

Staged diff identity is recorded separately after the integration owner stages the
last fixture and evidence, so the review identifier describes the final snapshot.
