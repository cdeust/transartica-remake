extends SceneTree
# MIT. Detached earned11437, production commands; no native gameplay claim.
var errors: Array[String] = []
const Stop = preload("res://scripts/reverse_contact_stop.gd")
func check(ok: bool, label: String) -> void:
	if not ok: errors.append(label)
func _initialize() -> void:
	_run.call_deferred()
func make_view(saved, data):
	var view = preload("res://scripts/travel_world.gd").new()
	view.discovery_enabled=false # Prepared map fixture uses actual travel visibility policy.
	view.network = preload("res://scripts/rail_network.gd").new()
	check(view.network.load_bytes(data.map_bytes),"source rails load")
	view.network.set_city_anchors(data.city_anchors())
	check(view.network.restore(saved.network),"earned network restores")
	view.journey = preload("res://scripts/train_journey.gd").new()
	view.journey.network = view.network
	check(view.journey.restore(saved.journey),"earned journey restores")
	var wagons = preload("res://scripts/train_wagons.gd").new()
	check(wagons.restore(saved.wagons),"earned wagons restore")
	view.consist.derive_from_wagons(wagons)
	check(view.train_renderer.load_assets(),"actual frame geometry loads")
	return view
func _run() -> void:
	var saved = JSON.parse_string(FileAccess.get_file_as_string("res://../reference-private/validation/reverse-occupied-switch-earned.json"))
	var data = preload("res://scripts/world_data.gd").new()
	check(data.load_from_project(ProjectSettings.globalize_path("res://")),"source map loads")
	var control = make_view(saved,data)
	var switched = make_view(saved,data)
	var before = switched.train_renderer.poses(switched,switched.journey,switched.consist,0)
	check(before.size()==21,"earned fixture has all21contacts")
	check(switched.toggle_switch_at(Vector2i(49,39)),"real switch command changes occupied49,39")
	check(switched.journey.reverse_switches.get("49,39",0)==7,"command captures physically occupied outgoing branch before toggle")
	check(switched.train_renderer.poses(switched,switched.journey,switched.consist,0)==before,"switch alone never moves occupied contacts")
	var commanded: Dictionary = JSON.parse_string(JSON.stringify(switched.journey.snapshot()))
	check(switched.journey.restore(commanded),"command latch restores atomically before any movement")
	check(switched.train_renderer.poses(switched,switched.journey,switched.consist,0)==before,"restored occupied command preserves all contacts")
	var invalid: Dictionary = commanded.duplicate(true)
	invalid.reverse_switches["49,39"]=6
	var stable: Dictionary = switched.journey.snapshot()
	check(not switched.journey.restore(invalid) and switched.journey.snapshot()==stable,"wrong branch latch is rejected without changing state")
	var seen: Dictionary = {}
	var max_shift := 0.0
	while control.journey.position != Vector2i(48,38) and not control.journey.blocked:
		var key = str([control.journey.position,control.journey.phase,control.journey.distance_ticks])
		if seen.has(key): check(false,"replay cannot cycle");break
		seen[key]=true
		Stop.advance(control,control.journey,300)
		Stop.advance(switched,switched.journey,300)
		var a = control.train_renderer.poses(control,control.journey,control.consist,0)
		var b = switched.train_renderer.poses(switched,switched.journey,switched.consist,0)
		check(a.size()==21 and b.size()==21,"occupied switch retains21contacts")
		if a.size()==b.size():
			for index in a.size():
				max_shift=maxf(max_shift,a[index].front.distance_to(b[index].front))
				max_shift=maxf(max_shift,a[index].rear.distance_to(b[index].rear))
	check(is_zero_approx(max_shift),"late occupied switch cannot reroute any occupied contact")
	check(switched.journey.position==control.journey.position and switched.journey.heading==control.journey.heading,"locomotive follows branch already traversed by leading tail")
	check(switched.network.tile(Vector2i(49,39))!=control.network.tile(Vector2i(49,39)),"command remains effective for future visit")
	var restored=preload("res://scripts/train_journey.gd").new()
	restored.network=switched.network
	check(restored.restore(switched.journey.snapshot()),"occupied path remains persistable")
	Stop.advance(switched,switched.journey,300)
	check(switched.journey.reverse_switches.is_empty(),"branch latch retires once the whole body has cleared outgoing port")
	print("late-switch maximum contact divergence=",max_shift," control=",control.journey.position," switched=",switched.journey.position)
	control.free()
	switched.free()
	# Prepared one-locomotive composition puts49,39 ahead of the leading rear.
	# A prior draw predicts its branch, but that forecast is not occupied track.
	var early=make_view(saved,data)
	early.consist.vehicles=early.consist.vehicles.slice(0,1)
	check(early.train_renderer.poses(early,early.journey,early.consist,0).size()==1,"prepared short convoy draws before command")
	check(early.toggle_switch_at(Vector2i(49,39)),"unoccupied switch command succeeds")
	check(early.journey.reverse_switches.is_empty(),"unoccupied forecast never creates a branch latch")
	seen.clear()
	while early.journey.position.x>48 and not early.journey.blocked:
		var key=str([early.journey.position,early.journey.phase,early.journey.distance_ticks])
		if seen.has(key): check(false,"short replay cannot cycle");break
		seen[key]=true
		Stop.advance(early,early.journey,300)
		var early_poses=early.train_renderer.poses(early,early.journey,early.consist,0)
		check(early_poses.size()==1 and is_equal_approx(early_poses[-1].rear.y,39),"leading contact follows changed unoccupied straight branch before locomotive reaches switch")
	check(early.journey.position==Vector2i(48,39),"unoccupied switch follows new straight branch despite previous draw forecast")
	print("early unoccupied switch exit=",early.journey.position)
	early.free()
	var partial_saved=JSON.parse_string(FileAccess.get_file_as_string("res://../reference-private/validation/reverse-refusal11686-earned.json"))
	var partial=make_view(partial_saved,data)
	var known=partial.train_renderer.poses(partial,partial.journey,partial.consist,0)
	check(known.size()==15,"earned11686 has exactly15proved contacts before hidden pre-entry")
	check(partial.toggle_switch_at(Vector2i(42,32)),"actual11687 command changes partial occupied42branch")
	check(partial.journey.reverse_switches.get("42,32",0)==9,"known occupied interval captures42branch without inventing unknown rear contacts")
	check(partial.train_renderer.poses(partial,partial.journey,partial.consist,0)==known,"partial command conserves all15known contacts")
	check(partial.journey.restore(JSON.parse_string(JSON.stringify(partial.journey.snapshot()))),"partial occupied branch persists through atomic restore")
	partial.free()
	await check_main()
	for error in errors: push_error(error)
	print("PASS: occupied reverse branch continuity" if errors.is_empty() else "FAIL: occupied reverse branch continuity")
	quit(0 if errors.is_empty() else 1)

func check_main() -> void:
	var app=preload("res://scripts/main.gd").new()
	var path=ProjectSettings.globalize_path("res://../.cache/reverse-occupied-switch-20261004/command-roundtrip.SAV")
	app.save_path_override=path
	app.game_audio.effects_enabled=false
	app.game_audio.music_enabled=false
	root.add_child(app)
	app.set_process(false)
	await process_frame
	app.world_view.set_process(false)
	var saves=preload("res://scripts/session_saves.gd")
	var loaded=saves.restore(app,ProjectSettings.globalize_path("res://../reference-private/validation/reverse-occupied-switch-earned.json"))
	check(loaded.ok,"actual Main restore accepts unchanged11437")
	if loaded.ok:
		app.game_audio.effects_enabled=false
		app.game_audio.music_enabled=false
		check(app.world_view.toggle_switch_at(Vector2i(49,39)),"actual Main command captures occupied switch")
		var before=app.world_view.train_renderer.poses(app.world_view,app.journey,app.world_view.consist,0)
		check(saves.save(app,path).ok and saves.restore(app,path).ok,"actual Main command saves/restores through staged production pipeline")
		check(app.journey.reverse_switches.get("49,39",0)==7,"full reload retains proved occupied branch")
		check(app.world_view.train_renderer.poses(app.world_view,app.journey,app.world_view.consist,0)==before,"full reload preserves21physical contacts")
		var stable: Dictionary=saves.snapshot(app)
		var invalid: Dictionary=stable.duplicate(true)
		invalid.journey.reverse_switches["49,39"]=6
		check(not saves._restore_parsed(app,invalid).ok and saves.snapshot(app)==stable,"full staged restore rejects wrong occupied branch atomically")
	app.game_audio.reset()
	app.queue_free()
	await process_frame
	if FileAccess.file_exists(path): DirAccess.remove_absolute(path)
