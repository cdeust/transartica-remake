extends SceneTree
# MIT. Translation regression from native review at world (80,40), 1 October 2026.
const Renderer = preload("res://scripts/train_renderer.gd")
const Consist = preload("res://scripts/train_consist.gd")
const Rails = preload("res://scripts/rail_network.gd")
const World = preload("res://scripts/travel_world.gd")

class TestProjection:
	extends RefCounted
	const WORLD_EAST = World.WORLD_EAST
	const WORLD_SOUTH = World.WORLD_SOUTH
	func _project(point: Vector2) -> Vector2:
		return WORLD_EAST*point.x+WORLD_SOUTH*point.y

class Straight:
	extends RefCounted
	var origin := Vector2.ZERO
	var heading := 6
	var available := INF
	func sample_behind(distance: float) -> Dictionary:
		if distance > available: return {"ok":false}
		var direction := Vector2(Rails.DELTAS[heading]).normalized()
		return {"ok":true,"position":origin-direction*distance,"heading":heading}

func _initialize() -> void:
	var renderer = Renderer.new()
	var view = TestProjection.new()
	var journey = Straight.new()
	var consist = Consist.new()
	consist.vehicles.clear()
	for kind in Consist.LENGTHS: consist.vehicles.append(kind)
	var failures: Array[String] = []
	for origin in [Vector2.ZERO,Vector2(80,40),Vector2(159,72)]:
		journey.origin = origin
		for heading in Rails.DELTAS:
			if heading == 5: continue
			journey.heading = heading
			journey.available = INF
			var target: float = 0.75*view.WORLD_EAST.length()
			var sample: Dictionary = journey.sample_behind(0.75)
			var absolute_chord: float = view._project(origin).distance_to(view._project(sample.position))
			var relative_chord: float = view._project(sample.position-origin).length()
			print("first chord target=%.12f absolute=%.12f relative=%.12f" % [target,absolute_chord,relative_chord])
			var poses: Array[Dictionary] = renderer.poses(view,journey,consist,0)
			print("precision origin=",origin," heading=",heading," vehicles=",poses.size(),"/",consist.vehicles.size())
			if poses.size() != consist.vehicles.size(): failures.append("complete translated train heading %d origin %s" % [heading,origin])
			for i in poses.size():
				var chord: float = view._project(poses[i].front-poses[i].rear).length()
				var expected: float = Consist.LENGTHS[poses[i].kind]*renderer.WAGON_CELL_RATIO*view.WORLD_EAST.length()
				if not is_equal_approx(chord,expected): failures.append("rigid chord changed")
				if i > 0 and poses[i].front != poses[i-1].rear: failures.append("contacts must remain shared")
			journey.available = 0.6 # Existing rejected short-history reproduction.
			if not renderer.poses(view,journey,consist,0).is_empty(): failures.append("short history accepted")
	if failures.is_empty():
		print("PASS: all 25 rigid vehicle kinds retain translated full-route contacts across eight headings; 0.6-cell history rejected")
		quit(0)
	else:
		for failure in failures: push_error(failure)
		quit(1)
