extends SceneTree
const Journey = preload("res://scripts/train_journey.gd")
const Rails = preload("res://scripts/rail_network.gd")
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)

func _run() -> void:
	var network = Rails.new()
	var bytes := PackedByteArray()
	bytes.resize(Rails.WIDTH * Rails.HEIGHT)
	for x in range(1, 100):
		bytes[x * Rails.HEIGHT + 62] = 2
	network.load_bytes(bytes)
	for start_phase in range(3):
		var journey = Journey.new()
		journey.network = network
		journey.phase = start_phase
		journey.distance_ticks = 7
		var head: Vector2 = journey.fractional_position()
		var tail: Dictionary = journey.sample_behind(3.0)
		check(journey.reverse_direction(), "reverse accepted")
		check(journey.reverse and journey.heading == 4, "flag and heading reverse")
		check(journey.phase == absi(start_phase - 2) - 1 and journey.distance_ticks == 23, "exact source phase and remainder")
		check(journey.fractional_position().is_equal_approx(head), "head does not teleport")
		check(journey.sample_behind(3.0).position.is_equal_approx(tail.position), "convoy does not flip")
		var loaded = Journey.new()
		loaded.network = network
		check(loaded.restore(journey.snapshot()), "reverse save restores all phases")
		check(loaded.reverse and loaded.fractional_position().is_equal_approx(head), "save retains direction and geometry")
		for _cycle in range(12):
			journey.advance(450)
			loaded.advance(450)
		check(journey.position.x < 12 and journey.fractional_position().x < head.x, "logical and displayed travel west")
		check(journey.snapshot() == loaded.snapshot(), "replay identical after save")
		var before: Vector2 = journey.fractional_position()
		journey.reverse_direction()
		check(not journey.reverse and journey.heading == 6, "second toggle returns forward")
		check(journey.fractional_position().is_equal_approx(before), "second toggle does not teleport")
		journey.advance(450)
		check(journey.fractional_position().x > before.x, "forward resumes east")
	var blocked = Journey.new()
	blocked.network = network
	blocked.blocked = true
	blocked.stop_reason = "station"
	blocked.phase = 2
	var stopped: Vector2 = blocked.fractional_position()
	blocked.reverse_direction()
	check(not blocked.blocked and blocked.stop_reason.is_empty(), "reversal clears blocked state")
	check(blocked.fractional_position().is_equal_approx(stopped), "blocked reversal preserves head")
	if failures.is_empty():
		print("PASS: reverser phases, movement, convoy geometry, repeated toggle and persistence")
	else:
		for failure in failures:
			push_error(failure)
	quit(0 if failures.is_empty() else 1)
