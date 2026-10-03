extends SceneTree
# MIT. Earned player approach7087; model regression, not native acceptance.
const Stop = preload("res://scripts/reverse_contact_stop.gd")
const View = preload("res://scripts/travel_world.gd")
func _initialize() -> void:
	call_deferred("_run")
func _run() -> void:
	var saved = JSON.parse_string(FileAccess.get_file_as_string("res://../reference-private/validation/reverse-obstacle-approach-earned.json"))
	var network = preload("res://scripts/rail_network.gd").new()
	assert(network.load_bytes(FileAccess.get_file_as_bytes("res://../reference-private/CARTE.FIC")))
	assert(network.restore(saved.network))
	var world = preload("res://scripts/world_data.gd").new()
	assert(world.load_from_project(ProjectSettings.globalize_path("res://").trim_suffix("/")))
	network.set_city_anchors(world.city_anchors())
	var journey = preload("res://scripts/train_journey.gd").new()
	journey.network = network
	assert(journey.restore(saved.journey))
	var wagons = preload("res://scripts/train_wagons.gd").new()
	assert(wagons.restore(saved.wagons))
	var view = View.new()
	root.add_child(view)
	view.consist.derive_from_wagons(wagons)
	assert(view.train_renderer.load_assets())
	for tick in 1000:
		Stop.advance(view,journey,300) # Earned player regulator300.
		var poses: Array = view.train_renderer.poses(view,journey,view.consist,0.0)
		if poses.size() != view.consist.vehicles.size():
			push_error("Reverse obstacle approach loses vehicles at tick%d" % tick)
			quit(1)
			return
		if journey.at_obstacle(): break
	assert(journey.at_obstacle(),"must stop at physical tail")
	assert(journey.obstacle_cell() == Vector2i(6,9),"actual blocked crevasse")
	assert(journey.next_cell() != journey.obstacle_cell(),"earlier physical stop than TIME locomotive")
	var poses: Array = view.train_renderer.poses(view,journey,view.consist,0.0)
	var restored = preload("res://scripts/train_journey.gd").new()
	restored.network = network
	assert(restored.restore(journey.snapshot()))
	assert(restored.obstacle_cell() == Vector2i(6,9))
	assert(view.train_renderer.poses(view,restored,view.consist,0.0) == poses)
	# Refusing works and releasing the brake retries this same obstacle.
	assert(restored.resume_after_works())
	Stop.advance(view,restored,300)
	assert(restored.at_obstacle() and restored.obstacle_cell() == Vector2i(6,9))
	assert(restored.reverse_direction())
	assert(view.train_renderer.poses(view,restored,view.consist,0.0) == poses,"reverser cannot move contacts")
	assert(restored.physical_obstacle == Vector2i(-1,-1))
	assert(network.repair(Vector2i(6,9)))
	assert(journey.resume_after_works())
	for tick in 100:
		Stop.advance(view,journey,300)
		if view.train_renderer.poses(view,journey,view.consist,0.0).size() != poses.size():
			print("LOSS ",tick," ",journey.snapshot()," cell ",journey._render_refused_cell)
			quit(1)
			return
	assert(journey.at_station() and journey.boundary_cell() == Vector2i(6,10))
	assert(journey.station_result() >= 0)
	assert(journey.depart_from_station())
	assert(journey.position == Vector2i(6,9) and journey.heading == 8)
	assert(journey.physical_obstacle == Vector2i(-1,-1))
	print("PASS: exact rear-contact stop, persisted obstacle, refused retry, reverser continuity, repaired travel, Rum arrival/departure")
	view.queue_free()
	quit(0)
