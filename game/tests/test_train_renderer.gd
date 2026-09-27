extends SceneTree

# Regression for PR #3: a full-size wagon requires a complete route chord.
# Source: tasks/lessons.md constant screen gabarit; observed short-history
# failure documented in tasks/validation/pr3-review-20260927.md.
const Renderer = preload("res://scripts/train_renderer.gd")
const Consist = preload("res://scripts/train_consist.gd")

class TestProjection:
	extends RefCounted
	# Same authored projection as travel_world.gd.
	const WORLD_EAST := Vector2(180.0, 100.0)
	const WORLD_SOUTH := Vector2(-180.0, 100.0)

	func _project(point: Vector2) -> Vector2:
		return WORLD_EAST * point.x + WORLD_SOUTH * point.y

class LimitedHistory:
	extends RefCounted
	var available := 0.0

	func sample_behind(distance: float) -> Dictionary:
		if distance > available:
			return {"ok": false}
		return {"ok": true, "position": Vector2(-distance, 0), "heading": 6}


func _initialize() -> void:
	var failures: Array[String] = []
	var renderer = Renderer.new()
	var view = TestProjection.new()
	var journey = LimitedHistory.new()
	# Reviewer reproduction: 0.6 cells cannot hold the one-cell locomotive.
	journey.available = 0.6
	var rear: Dictionary = renderer._bisected_rear(view, journey, 0.0, Vector2.ZERO, "locomotive")
	_check(not rear.ok, "short history rejects a full-size vehicle", failures)
	var consist = Consist.new()
	_check(renderer.poses(view, journey, consist, 0.0).is_empty(), "no partial vehicle pose is emitted", failures)
	# Exactly one authored locomotive length must remain sufficient.
	journey.available = Consist.LENGTHS.locomotive
	rear = renderer._bisected_rear(view, journey, 0.0, Vector2.ZERO, "locomotive")
	_check(rear.ok, "exact vehicle-length history is accepted", failures)
	if rear.ok:
		_check(is_equal_approx(view._project(rear.position).length(), view.WORLD_EAST.length()), "accepted chord matches the rigid sprite", failures)
		_check(journey.sample_behind(rear.distance).position == rear.position, "reported distance identifies the returned sample", failures)
	# A complete locomotive plus the same incomplete tail must draw only one.
	journey.available += 0.6
	var poses: Array[Dictionary] = renderer.poses(view, journey, consist, 0.0)
	_check(poses.size() == 1 and poses[0].kind == "locomotive", "complete front vehicle survives incomplete tail", failures)
	journey.available = consist.length_world()
	_check(renderer.poses(view, journey, consist, 0.0).size() == consist.vehicles.size(), "complete history supplies the whole consist", failures)
	if failures.is_empty():
		print("PASS: short route history cannot emit incomplete rigid vehicle poses")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)


func _check(condition: bool, label: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(label)
