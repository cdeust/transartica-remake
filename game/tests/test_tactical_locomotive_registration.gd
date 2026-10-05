extends SceneTree
# MIT. Authored proportions: tasks/validation/locomotive-consistency.md.
# Source roster reserves companion25 only for the player's locomotive.
const Geometry = preload("res://scripts/tactical_effects_geometry.gd")
var failures: Array[String] = []

func _initialize() -> void:
	_run.call_deferred()

func check(value: bool, message: String) -> void:
	if not value: failures.append(message)

func _run() -> void:
	var state = preload("res://scripts/tactical_combat.gd").new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 420
	state.begin(preload("res://scripts/train_wagons.gd").new(),47,rng)
	var args := OS.get_cmdline_user_args()
	if not args.is_empty():
		var saved: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(args[0]))
		check(state.restore(saved.encounters.manual),"Earned combat restores read-only")
	check(state.trains[0][1].class == state.Setup.LOCOMOTIVE_COMPANION,"Player reserves companion slot")
	check(state.trains[1][1].class == 8,"Enemy next slot is a real tender")
	var scene = preload("res://scripts/tactical_scene.gd").new()
	root.add_child(scene)
	scene.open_battle(state)
	scene.hide()
	scene.paused = true
	var original := state.snapshot()
	print("Enemy body=%s tender=%s" % [Geometry.wagon(scene,1,0).rect,Geometry.wagon(scene,1,1).rect])
	for shift in [-64,0,64]: # source: one tactical wagon slot on either side
		state.offsets = [original.offsets[0]+shift,original.offsets[1]-shift]
		for camera in [-state.center_offset(),0,state.center_offset()]:
			scene.camera = camera
			for health in [3,2,1,0]:
				for side in 2:
					state.trains[side][0].health = health
					var before := state.snapshot()
					var geometry: Dictionary = Geometry.wagon(scene,side,0)
					var rect: Rect2 = geometry.rect
					var x: float = 320+scene.shown_offset(side)-scene.camera
					var rear := x-(128 if side == 0 else 64)
					check(is_equal_approx(rect.position.x,rear),"Rear registration side%d health%d camera%d" % [side,health,camera])
					check(is_equal_approx(rect.size.x/rect.size.y,geometry.used.size.x/geometry.used.size.y),"Uniform authored aspect")
					check(is_equal_approx(geometry.factor,minf(128/geometry.used.size.x,26/geometry.used.size.y)),"Accepted uniform scale unchanged")
					var next := 2 if side == 0 else 1
					var following: Rect2 = Geometry.wagon(scene,side,next).rect
					check(following.end.x <= rect.position.x,"Tender cannot mask locomotive or wreck")
					var event := {"side":side,"wagon":0}
					check(Geometry.event_point(scene,event).is_equal_approx(Vector2(rect.get_center().x,rect.position.y)),"Event follows registered body")
					check(is_equal_approx(Geometry.mount(scene,side,0).base.x,rect.get_center().x),"Mount follows registered body")
					check(Geometry.wagon_at(scene,side,rect.get_center().x) == 0,"Registered body resolves locomotive")
					check(state.snapshot() == before,"Geometry is read-only")
	state.trains[0][0].health = original.trains[0][0].health
	state.trains[1][0].health = original.trains[1][0].health
	state.offsets = original.offsets.duplicate()
	scene.camera = original.camera_offset
	check(state.snapshot() == original,"Presentation checks preserve all source battle fields")
	scene.queue_free()
	await process_frame
	for failure in failures: push_error(failure)
	if failures.is_empty(): print("PASS: both locomotive registrations, health0..3, camera extremes, unchanged aspect/scale/model, attached events/mounts")
	quit(0 if failures.is_empty() else 1)
