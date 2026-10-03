extends SceneTree
# MIT. Earned approach7087; checks execute in release without assertions.
const Stop = preload("res://scripts/reverse_contact_stop.gd")
const View = preload("res://scripts/travel_world.gd")
const Network = preload("res://scripts/rail_network.gd")
const Journey = preload("res://scripts/train_journey.gd")
var failures: Array[String] = []

class RestoreProbe extends "res://scripts/train_journey.gd":
	var restore_calls := 0
	var fail_on := 0
	func restore(data: Variant) -> bool:
		restore_calls += 1
		if restore_calls == fail_on: return false
		return super.restore(data)

func _initialize() -> void: call_deferred("_run")

func _run() -> void:
	var release_required := "--require-release" in OS.get_cmdline_user_args()
	if not check(not release_required or not OS.has_feature("debug"),"Required release runtime is actually release"):
		finish(); return
	print("RUNTIME: debug=",OS.has_feature("debug")," engine=",Engine.get_version_info().string)
	var saved: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://../reference-private/validation/reverse-obstacle-approach-earned.json"))
	if not check(saved is Dictionary,"Earned approach fixture available"):
		finish(); return
	var network = Network.new()
	if not check(network.load_bytes(FileAccess.get_file_as_bytes("res://../reference-private/CARTE.FIC")),"Original topology loads"):
		finish(); return
	if not check(network.restore(saved.network),"Earned network restores"):
		finish(); return
	var world = preload("res://scripts/world_data.gd").new()
	if not check(world.load_from_project(ProjectSettings.globalize_path("res://").trim_suffix("/")),"Original world data loads"):
		finish(); return
	network.set_city_anchors(world.city_anchors())
	var wagons = preload("res://scripts/train_wagons.gd").new()
	if not check(wagons.restore(saved.wagons),"Earned wagons restore"):
		finish(); return
	var view = View.new()
	root.add_child(view)
	view.consist.derive_from_wagons(wagons)
	if not check(view.train_renderer.load_assets(),"Actual renderer loads"):
		finish(); return
	var journey = make_journey(network,saved.journey)
	if journey == null: finish(); return
	approach(view,journey)
	if not failures.is_empty(): finish(); return
	check(journey.at_obstacle() and journey.obstacle_cell()==Vector2i(6,9),"Rear contact stops at original crevasse")
	check(journey.next_cell()!=journey.obstacle_cell(),"Physical stop precedes locomotive TIME boundary")
	# One initial restore, CHORD_ITERATIONS search restores, one accepted restore.
	var restore_count: int = Stop.SEARCH_STEPS+2
	check(journey.restore_calls==restore_count,"All restore side effects execute")
	var poses: Array = view.train_renderer.poses(view,journey,view.consist,0.0)
	var restored = Journey.new()
	restored.network=network
	check(restored.restore(journey.snapshot()),"Stopped snapshot restores")
	check(view.train_renderer.poses(view,restored,view.consist,0.0)==poses,"Stopped snapshot preserves every contact")
	check(restored.resume_after_works(),"Decline retry releases stop")
	Stop.advance(view,restored,300) # Actual earned regulator setting.
	check(restored.at_obstacle() and restored.obstacle_cell()==Vector2i(6,9),"Retry retains encountered obstacle")
	check(restored.reverse_direction(),"Reverse-away permitted")
	check(view.train_renderer.poses(view,restored,view.consist,0.0)==poses,"Reverser cannot move contacts")
	# Reject initial, first search, and accepted restore, respectively.
	for failure_call in [1,2,restore_count]:
		var rejected = make_journey(network,saved.journey)
		if rejected == null: continue
		rejected.fail_on=failure_call
		print("EXPECTED restore rejection at call ",failure_call)
		approach(view,rejected,false)
		check(rejected.restore_calls==failure_call,"Failed restore aborts remaining search")
		check(rejected.blocked and rejected.at_obstacle(),"Restore failure blocks travel")
		check(rejected.obstacle_cell()==Vector2i(6,9),"Restore failure retains actual obstacle")
		var before: Dictionary = rejected.snapshot()
		Stop.advance(view,rejected,300)
		check(rejected.snapshot()==before,"Blocked failure cannot advance again")
	check(network.repair(Vector2i(6,9)),"Actual obstacle repair succeeds")
	check(journey.resume_after_works(),"Repair releases physical stop")
	for tick in 100: # Same bounded existing reverse physical-stop regression.
		Stop.advance(view,journey,300)
		check(view.train_renderer.poses(view,journey,view.consist,0.0).size()==poses.size(),"Repair continuation retains all vehicles")
	check(journey.at_station() and journey.boundary_cell()==Vector2i(6,10),"Repaired continuation reaches Rum physically")
	view.queue_free()
	finish()

func make_journey(network, data: Dictionary):
	var journey = RestoreProbe.new()
	journey.network=network
	if not check(journey.restore(data),"Earned journey restores"): return null
	journey.restore_calls=0
	return journey

func approach(view, journey, require_full := true) -> void:
	var implementation = Stop
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--stop-script="):
			implementation=load(argument.trim_prefix("--stop-script="))
			if not check(implementation!=null,"Requested baseline implementation loads"): return
	for tick in 1000: # Existing earned7087 approach bound; no injected position.
		implementation.advance(view,journey,300)
		if require_full:
			if not check(view.train_renderer.poses(view,journey,view.consist,0.0).size()==view.consist.vehicles.size(),"No vehicle lost during reverse approach"):
				return
		if journey.blocked: return
	check(false,"Approach did not stop within regression bound")

func check(value: bool, message: String) -> bool:
	if not value: failures.append(message)
	return value

func finish() -> void:
	for failure in failures: push_error(failure)
	if failures.is_empty(): print("PASS: release-safe restores, exact rear stop, persistence, retry, reverser, repair, physical station and three restore rejection stages")
	quit(0 if failures.is_empty() else 1)
