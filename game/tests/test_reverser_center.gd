extends SceneTree

const Journey = preload("res://scripts/train_journey.gd")
const Rails = preload("res://scripts/rail_network.gd")
var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var network = Rails.new()
	var bytes := PackedByteArray()
	bytes.resize(Rails.WIDTH * Rails.HEIGHT)
	for x in range(1, 100):
		bytes[x * Rails.HEIGHT + 62] = 2
	bytes[12 * Rails.HEIGHT + 62] = 18
	network.load_bytes(bytes)
	var journey = Journey.new()
	journey.network = network
	journey.reverse_direction()
	journey.fractional_position()
	check(journey.incoming_heading == 0, "trailing switch genuinely has two possible incoming ports")
	check(journey._entry_position() == Vector2(journey.position), "ambiguous entry starts at the center")
	var saved = Journey.new()
	saved.network = network
	check(saved.restore(journey.snapshot()), "center-seeded reversal snapshot restores")
	var before: float = journey._render_cursor
	journey.advance(450)
	saved.advance(450)
	var fraction := float(450 / 20) / float(Journey.PHASES_PER_TILE * Journey.DISTANCE_STEP)
	check(is_equal_approx(journey._render_cursor, before - fraction * 0.5), "center-seeded rendering advances over the known outgoing half")
	check(journey.snapshot() == saved.snapshot(), "saved center-seeded reversal replays identically")
	if failures.is_empty():
		print("PASS: center-seeded switch reversal advances and restores without invented incoming rail")
	else:
		for failure in failures:push_error(failure)
	quit(0 if failures.is_empty() else 1)


func check(ok: bool, message: String) -> void:
	if not ok:failures.append(message)
