extends SceneTree
# requires-native-renderer
# Source: actual Main starts AudioStreamPlayer; headless Dummy leaves WAV playback
# allocations alive at exit (world-recovery-cadence-after-20261001.log). Run the
# native audio/render host so lifecycle verification exercises supported playback.
# MIT. Authored same-input fixture exercises the actual host at30/60/144Hz.
# Source: EngineSession cycle accumulator; engine TIME rules and seeded encounters.
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var results: Array = []
	for rate in [30,60,144]:
		var app = load("res://scripts/main.gd").new()
		app.save_path_override = ProjectSettings.globalize_path("res://../.cache/cadence-unused.json")
		root.add_child(app)
		app.set_process(false)
		await process_frame
		app._trade_rng.seed = 7 # Authored reproducible fixture seed, not a gameplay constant.
		app._restart_engine()
		app.encounters.rng.seed = 11 # Independent encounter fixture stream.
		app.room_controls.activate("lignite")
		app.engine.set_regulator(100)
		for frame in rate*60: # Same60 simulated seconds, no wall-clock performance claim.
			app._process(1.0/rate)
		results.append({"engine":app.engine.snapshot(), "calendar":app.calendar.snapshot(),
			"cell":app.journey.position,"heading":app.journey.heading,"phase":app.journey.phase,
			"remainder":app.journey.distance_ticks,"map":app.network.snapshot(),
			"roamers":app.roamers.snapshot(),"world":app.world.snapshot(),"campaign":app.campaign.state.snapshot(),
			"encounters":app.encounters.snapshot(),"trade_rng":str(app._trade_rng.state)})
		if app.engine.cycles == 0 or app.journey.position == Vector2i(12,62):
			failures.append("Fixture must consume fuel and move the actual train at%dHz" % rate)
		app.queue_free()
		await process_frame
	if results[0] != results[1] or results[1] != results[2]:
		failures.append("Same inputs and seeds must preserve game state at30/60/144Hz")
	for failure in failures: push_error(failure)
	if failures.is_empty(): print("PASS: actual engine/journey/calendar/world/campaign/encounters state at30/60/144Hz")
	quit(0 if failures.is_empty() else 1)
