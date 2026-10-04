extends SceneTree

# MIT. Prepared comparison from an earned save; no campaign progression claim.
# Root owns native execution: --script res://tests/review_snow_master.gd -- SAVE_PATH
const Saves = preload("res://scripts/session_saves.gd")
var app


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if DisplayServer.get_name() == "headless" or args.size() != 1:
		push_error("Native renderer and exactly one earned save path required")
		quit(1)
		return
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.content_scale_size = Vector2i.ZERO
	# source: owner's1440×900 game screenshots; same viewport for both images.
	root.size = Vector2i(1440,900)
	app = load("res://main.tscn").instantiate()
	app.play_startup_intro = false
	app.save_path_override = args[0]
	root.add_child(app)
	await process_frame
	await process_frame # game_boot.restore_after_layout waits one frame.
	app.set_process(false)
	assert(Saves.restore(app,args[0]).ok, "Earned save must restore through production API")
	app._open_panel("map")
	app.world_view.set_process(false)
	app.game_audio.set_process(false)
	app.game_audio.reset()
	var before: Dictionary = Saves.snapshot(app)
	var directory := ProjectSettings.globalize_path("res://../output/imagegen/world-map-20261004/native-comparison")
	assert(DirAccess.make_dir_recursive_absolute(directory) == OK)
	for material in ["snow-material","snow-master"]:
		# Load raw PNGs without requiring a different production import configuration.
		var path := ProjectSettings.globalize_path("res://assets/travel/terrain/%s.png" % material)
		var image := Image.load_from_file(path)
		assert(not image.is_empty(), "Comparison material must exist")
		var world = app.world_view
		world._ice_field = ImageTexture.create_from_image(image)
		world._ground.texture = world._ice_field
		world._update_ground_shader()
		world.queue_redraw()
		await process_frame
		RenderingServer.force_draw(true)
		var capture: Image = root.get_texture().get_image()
		assert(not capture.is_empty() and capture.get_size() == root.size)
		assert(capture.get_pixel(0,0) != capture.get_pixel(capture.get_width()/2,capture.get_height()/2), "Visible scene must contain rendered pixels")
		assert(capture.save_png(directory+"/"+material+".png") == OK)
		assert(Saves.snapshot(app) == before, "Material observer must preserve earned state")
	app.queue_free()
	await process_frame
	print("PASS: same earned save captured with old/new snow; visual acceptance remains manual")
	quit()
