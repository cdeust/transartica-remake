extends SceneTree

# MIT. Prepared artwork comparisons, not earned traversal or campaign acceptance.
# Composition comes from the supplied earned save; source-map fixtures move it
# solely for rendering candidates. Root owns native execution and visual choice.
const Saves = preload("res://scripts/session_saves.gd")
var app


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if DisplayServer.get_name() == "headless" or args.size() != 1:
		push_error("Native renderer and earned save argument required")
		quit(1)
		return
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.content_scale_size = Vector2i.ZERO
	root.size = Vector2i(1440,900) # source: owner's native comparison viewport.
	app = load("res://main.tscn").instantiate()
	app.play_startup_intro = false
	app.save_path_override = args[0]
	root.add_child(app)
	await process_frame
	await process_frame
	app.set_process(false)
	assert(Saves.restore(app,args[0]).ok)
	app._open_panel("map")
	await process_frame
	await process_frame
	assert(app.world_view.size.x > 0 and app.world_view.size.y > 0, "Map layout must exist before prepared framing")
	app.world_view.set_process(false)
	app.game_audio.set_process(false)
	app.game_audio.reset()
	var directory := ProjectSettings.globalize_path("res://../output/underground-review-20261004")
	assert(DirAccess.make_dir_recursive_absolute(directory) == OK)
	# source: exact CARTE cells, underground39 / mouth54 / ice-covered50.
	for site in [{"name":"underground","cell":[47,59]}, {"name":"mouth","cell":[51,39]}, {"name":"covered","cell":[52,39]}]:
		# Fresh fixture history cannot retain a saved render arc from the earned location.
		var fixture = preload("res://scripts/train_journey.gd").new()
		fixture.network = app.network
		assert(fixture.restore({"version":1,"position":site.cell,"heading":6,"distance_ticks":0,"phase":0,"blocked":false}))
		_seed_source_route(fixture,site.name)
		app.journey = fixture
		app.world_view.journey = fixture
		app.world_view._snap_visual_position(fixture.fractional_position())
		var geometry: Array = app.world_view.train_renderer.poses(app.world_view,app.journey,app.world_view.consist,0.0)
		assert(geometry.size() == app.world_view.consist.vehicles.size() and not geometry.is_empty(), "Prepared comparison requires the entire visible train")
		var world_bounds := Rect2(geometry[0].front,Vector2.ZERO)
		for vehicle in geometry:
			world_bounds = world_bounds.expand(vehicle.front).expand(vehicle.rear)
		app.world_view.camera_world = world_bounds.get_center()+Vector2.ONE*0.5
		app.world_view.offset = Vector2.ZERO
		app.world_view.zoom = preload("res://scripts/train_camera_fit.gd").initial_zoom(app.world_view)
		var before: Dictionary = Saves.snapshot(app)
		# Explicit visual-design candidates authorized4Oct; no source alpha claim.
		for strength in [1.0,0.75,0.85]:
			app.world_view.train_renderer.underground_alpha = strength
			app.world_view.queue_redraw()
			await process_frame
			RenderingServer.force_draw(true)
			var capture: Image = root.get_texture().get_image()
			assert(not capture.is_empty() and capture.get_size() == root.size)
			assert(capture.get_pixel(0,0) != capture.get_pixel(capture.get_width()/2,capture.get_height()/2))
			assert(capture.save_png(directory+"/%s-%.2f.png" % [site.name,strength]) == OK)
			assert(Saves.snapshot(app) == before, "Artwork comparison cannot advance campaign state")
			assert(app.world_view.train_renderer.poses(app.world_view,app.journey,app.world_view.consist,0.0) == geometry, "Opacity cannot change train geometry")
	# Prepared close-ups inspect each orientation; camera placement is diagnostic.
	for mouth in [{"code":53,"cell":Vector2i(61,51)}, {"code":54,"cell":Vector2i(51,39)}, {"code":58,"cell":Vector2i(105,23)}]:
		app.world_view.camera_world = Vector2(mouth.cell)+Vector2.ONE*0.5
		app.world_view.offset = Vector2.ZERO
		app.world_view.zoom = 1.0 # authored1:1 world presentation inspection scale.
		app.world_view.train_renderer.underground_alpha = 0.75 # root-selected design candidate.
		app.world_view.queue_redraw()
		await process_frame
		RenderingServer.force_draw(true)
		var close: Image = root.get_texture().get_image()
		assert(not close.is_empty())
		assert(close.save_png(directory+"/portal-%d-close.png" % mouth.code) == OK)
	app.queue_free()
	await process_frame
	print("PASS: prepared underground alpha candidates captured with unchanged state/rigid geometry; visual choice pending")
	quit()


func _seed_source_route(fixture, name: String) -> void:
	# An explicitly prepared historical route resolves trailing switch ambiguity.
	# Every segment uses exact source rail ports and the existing TIME turn rule.
	var route: Array = []
	if name == "underground":
		for x in range(20,32):
			route.append([Vector2i(x,58),6,6])
		route.append([Vector2i(32,58),6,3])
		route.append([Vector2i(33,59),3,6])
		for x in range(34,48):
			route.append([Vector2i(x,59),6,6])
	else:
		for x in range(28,fixture.position.x+1):
			route.append([Vector2i(x,39),6,6])
	for record in route:
		var ports: Array[Vector2] = preload("res://scripts/rail_glyphs.gd").ports_for_code(fixture.network.tile(record[0]))
		assert(-Vector2(fixture.RailNetworkScript.DELTAS[record[1]])*0.5 in ports)
		assert(Vector2(fixture.RailNetworkScript.DELTAS[record[2]])*0.5 in ports)
		# Prior traversed switches may differ from their saved current setting;
		# the explicit history records source-connected contacts, not future turns.
		fixture._render_path.append_tile(record[0],record[1],record[2])
	# phase0 sits at the incoming port, one full tile before the appended end.
	fixture._render_cursor = fixture._render_path.length-1.0
	fixture._render_origin = fixture._render_cursor
	fixture._render_end_cell = fixture.position
	fixture._render_end_heading = fixture.heading
