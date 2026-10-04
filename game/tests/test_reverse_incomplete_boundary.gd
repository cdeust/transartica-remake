extends SceneTree
# MIT. Replay earned10646 plus actual10647 switch, not native progress.
const Rails=preload("res://scripts/rail_network.gd")
var errors: Array[String]=[]
func check(ok: bool, message: String) -> void:
	if not ok: errors.append(message)
func _initialize() -> void: _run.call_deferred()
func _run() -> void:
	var stop=load("res://../.cache/reverse-hidden-contact-fix-20261004/before-partial-stop.gd" if "--before" in OS.get_cmdline_user_args() else "res://scripts/reverse_contact_stop.gd")
	var saved=JSON.parse_string(FileAccess.get_file_as_string("res://../reference-private/validation/reverse-incomplete-departure-earned.json"))
	var data=preload("res://scripts/world_data.gd").new()
	check(data.load_from_project(ProjectSettings.globalize_path("res://")),"source map loads")
	var network=Rails.new()
	check(network.load_bytes(data.map_bytes),"source network loads")
	network.set_city_anchors(data.city_anchors())
	check(network.restore(saved.network),"earned network restores")
	var journey=preload("res://scripts/train_journey.gd").new()
	journey.network=network
	check(journey.restore(saved.journey),"earned10646 phase/path restores")
	var wagons=preload("res://scripts/train_wagons.gd").new()
	check(wagons.restore(saved.wagons),"earned21wagons restore")
	var view=preload("res://scripts/travel_world.gd").new()
	view.network=network
	view.journey=journey
	view.consist.derive_from_wagons(wagons)
	check(view.train_renderer.load_assets(),"actual vehicle frames load")
	check(view.train_renderer.poses(view,journey,view.consist,0).size()==9,"saved departure still hides12wagons inside original station")
	# Prepared transient stale-marker regression; earned geometry is unchanged.
	journey._render_refused_cell=Vector2i(31,37)
	journey._render_refused_heading=4
	stop.advance(view,journey,300)
	check(not journey.blocked,"old diagnostic marker cannot turn legitimate emergence into a new contact")
	check(journey.restore(saved.journey),"restore exact earned phase after stale-marker check")
	journey._render_refused_cell=Vector2i(-1,-1)
	check(network.toggle_switch(Vector2i(29,24)),"actual10647 switch follows recorded native action")
	var peak:=0
	var seen: Dictionary={}
	while not journey.blocked:
		var key=str([journey.position,journey.heading,journey.phase,journey.distance_ticks])
		if seen.has(key): check(false,"replay must not cycle");break
		seen[key]=true
		stop.advance(view,journey,300)
		peak=maxi(peak,view.train_renderer.poses(view,journey,view.consist,0).size())
	check(journey.physical_obstacle==Vector2i(31,37) and journey.stop_reason=="station","incomplete departure footprint stops at newly refused physical station")
	check(journey.position!=Vector2i(32,37),"cannot shrink from20 to1 before locomotive reaches station")
	check(peak>=20,"source reroute recovered actual20contacts before physical stop")
	var count: int=view.train_renderer.poses(view,journey,view.consist,0).size()
	check(count>=20,"physical refusal retains recovered contacts")
	var stable: Dictionary=journey.snapshot()
	stop.advance(view,journey,300)
	check(journey.snapshot()==stable,"blocked repeated step cannot advance TIME")
	var restored=preload("res://scripts/train_journey.gd").new()
	restored.network=network
	check(restored.restore(stable),"partial physical station stop persists through production validation")
	print("incomplete replay cell=",journey.position," physical=",journey.physical_obstacle," poses=",count," peak=",peak)
	view.free()
	await _check_main(stop)
	for error in errors: push_error(error)
	print("PASS: earned incomplete reverse departure cannot advance through newly refused station contact" if errors.is_empty() else "FAIL: partial physical boundary guard")
	quit(0 if errors.is_empty() else 1)

func _check_main(stop) -> void:
	var app=preload("res://scripts/main.gd").new()
	var path=ProjectSettings.globalize_path("res://../.cache/reverse-hidden-contact-fix-20261004/incomplete-roundtrip.SAV")
	app.save_path_override=ProjectSettings.globalize_path("res://../.cache/reverse-hidden-contact-fix-20261004/incomplete-unused.SAV")
	app.game_audio.effects_enabled=false
	app.game_audio.music_enabled=false
	root.add_child(app)
	app.set_process(false)
	await process_frame
	var saves=preload("res://scripts/session_saves.gd")
	var loaded=saves.restore(app,ProjectSettings.globalize_path("res://../reference-private/validation/reverse-incomplete-departure-earned.json"))
	check(loaded.ok,"actual Main restores earned10646 unchanged")
	if loaded.ok:
		app.game_audio.effects_enabled=false
		app.game_audio.music_enabled=false
		app.world_view.set_process(false)
		check(app.network.toggle_switch(Vector2i(29,24)),"actual Main repeats10647 switch")
		var seen: Dictionary={}
		while not app.journey.blocked:
			var key=str([app.journey.position,app.journey.heading,app.journey.phase,app.journey.distance_ticks])
			if seen.has(key): check(false,"Main replay cannot cycle");break
			seen[key]=true
			stop.advance(app.world_view,app.journey,300)
		preload("res://scripts/journey_session.gd")._handle_boundary(app,false)
		check(app.journey.physical_obstacle==Vector2i(31,37) and app.journey.position==Vector2i(29,24),"Main dispatch owns early physical contact")
		check(app._city_panel.visible and app.session.paused,"actual boundary callback opens Turin and pauses")
		check(saves.save(app,path).ok and saves.restore(app,path).ok,"early partial city visit saves/restores through production pipeline")
		check(app.journey.physical_obstacle==Vector2i(31,37) and app._city_panel.visible,"restore retains actual physical city")
		check(app.world_view.train_renderer.poses(app.world_view,app.journey,app.world_view.consist,0).size()>=20,"restore keeps recovered20contacts")
		app.game_audio.effects_enabled=false
		app.game_audio.music_enabled=false
		app.depart_from_city()
		check(not app.journey.blocked and not app.journey.reverse and app.journey.history_starts_in_station(),"actual departure resumes legitimate station emergence")
		var arrived=saves.restore(app,ProjectSettings.globalize_path("res://../reference-private/validation/reverse-incomplete-arrival-earned.json"))
		check(arrived.ok and app.journey.position==Vector2i(32,37),"already arrived earned10738 remains valid without relocation")
		check(app._city_panel.visible and app.journey.boundary_cell()==Vector2i(31,37),"earned10738 reload retains actual Turin city")
		check(app.world_view.train_renderer.poses(app.world_view,app.journey,app.world_view.consist,0).size()==1,"legacy arrival does not fabricate contacts through station")
	app.game_audio.reset()
	app.queue_free()
	await process_frame
	if FileAccess.file_exists(path): DirAccess.remove_absolute(path)
