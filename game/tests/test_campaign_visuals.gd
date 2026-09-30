extends SceneTree

# requires-native-renderer
# Native rendering gate: no blank scene body in campaign encounters or crew UI.
const Screen = preload("res://scripts/campaign_screen.gd")
const State = preload("res://scripts/campaign_state.gd")
var failures: Array[String] = []

func _initialize() -> void:
	OS.low_processor_usage_mode = false
	call_deferred("_run")

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://../.cache/campaign"))
	root.size = Vector2i(1280, 800)
	var state = State.new()
	state.load_data()
	var screen = Screen.new()
	screen.size = Vector2(1280, 800)
	root.add_child(screen)
	await process_frame
	for scene in ["urga", "oslo", "mausoleum", "whale_question", "whale_harpoon", "slope", "death", "earth", "crew", "sun", "sun-restored"]:
		if scene == "crew":
			screen.open_menu(["SEND SPY", "DYNAMITE", "EXIT"])
		else:
			screen.present(scene, state.message(104, true) if scene == "death" else state.message(18), false, scene == "whale_question")
		await process_frame
		await RenderingServer.frame_post_draw
		var capture: Image = root.get_texture().get_image()
		var detail := 0
		# Coarse grid catches a black placeholder without pixel-perfect art assertions.
		for y in range(80, 600, 40):
			for x in range(80, 1200, 40):
				var pixel: Color = capture.get_pixel(x, y)
				if pixel.r + pixel.g + pixel.b > 0.03:
					detail += 1
		if detail == 0:
			failures.append(scene + " has no rendered scene body")
		var saved := capture.save_png(ProjectSettings.globalize_path("res://../.cache/campaign/" + scene + "-native.png"))
		if saved != OK:
			failures.append(scene + " native capture could not be saved")
	screen.start_movie()
	screen.set_process(false)
	for tick in [0, 30, 50, 120, 156, 320, 361]:
		screen.finale.tick = tick
		screen.queue_redraw()
		await process_frame
		await RenderingServer.frame_post_draw
		var capture: Image = root.get_texture().get_image()
		var saved := capture.save_png(ProjectSettings.globalize_path("res://../.cache/campaign/finale-%03d-native.png" % tick))
		if saved != OK:
			failures.append("finale capture could not be saved at tick%d" % tick)
	screen.stop_movie()
	screen.queue_free()
	await process_frame
	for failure in failures:
		push_error(failure)
	if failures.is_empty():
		print("PASS: native rendered Urga, Oslo, mausoleum, whale, slope, death, Earth, crew and both Sun states; captures retained")
	quit(0 if failures.is_empty() else 1)
