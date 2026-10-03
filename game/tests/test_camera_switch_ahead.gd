extends SceneTree
# MIT. Native6350 switched88,16 only after TIME turn;6355 is the earned pause.
# Regression fixture, not player acceptance. Preserve fixed zoom (FIDELITE.md).
const View = preload("res://scripts/travel_world.gd")

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var saved = JSON.parse_string(FileAccess.get_file_as_string(
		"res://../reference-private/validation/switch-visible-after-turn-earned.json"))
	var network = preload("res://scripts/rail_network.gd").new()
	network.load_bytes(FileAccess.get_file_as_bytes("res://../reference-private/CARTE.FIC"))
	assert(network.restore(saved.network))
	var journey = preload("res://scripts/train_journey.gd").new()
	journey.network = network
	assert(journey.restore(saved.journey))
	var wagons = preload("res://scripts/train_wagons.gd").new()
	assert(wagons.restore(saved.wagons))
	var view = View.new()
	root.add_child(view)
	view.size = Vector2(1440,670) # Actual native6350 travel viewport, before panel.
	view.journey = journey
	view.network = network
	view.consist.derive_from_wagons(wagons)
	assert(view.train_renderer.load_assets())
	view.zoom = saved.zoom
	view.camera_world = Vector2(saved.travel_camera.x,saved.travel_camera.y)
	view.offset = Vector2(saved.offset_x,saved.offset_y)
	view._snap_visual_position(journey.fractional_position())
	# Reconstruct the observed pre-turn frame from its visible rail anchor and
	# recorded head. The later F5 supplies the unchanged traveled rail history.
	var observed = JSON.parse_string(FileAccess.get_file_as_string(
		"res://../reference-private/validation/switch-before-turn-observation.json"))
	var head := Vector2(87.5,16.0) # Native6346 logical_head, before switch88 turn.
	view._visual_arc -= journey.fractional_position().distance_to(head)
	view._visual_position = head
	var anchor: Dictionary = observed.switches[0]
	view.offset += Vector2(anchor.click[0],anchor.click[1])-view._world_to_screen(Vector2(anchor.cell[0],anchor.cell[1])+Vector2(0.5,0.5))
	view._keep_train_in_view()
	var ahead: Vector2 = view._world_to_screen(Vector2(journey.next_cell())+Vector2(0.5,0.5))
	var okay: bool = Rect2(Vector2.ZERO,view.size).has_point(ahead) and view.zoom == saved.zoom
	var camera: Vector2 = view.camera_world
	var offset: Vector2 = view.offset
	view._keep_train_in_view()
	okay = okay and camera == view.camera_world and offset == view.offset
	if not okay: push_error("Earned13-wagon camera hides next rail decision or changes zoom/recenters every frame")
	else: print("PASS: earned13-wagon framing exposes next rail decision at fixed zoom without repeated recenter")
	view.queue_free()
	quit(0 if okay else 1)
