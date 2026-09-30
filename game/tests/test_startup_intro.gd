extends SceneTree

# requires-native-renderer
const Intro = preload("res://scripts/startup_intro.gd")
var failures: Array[String] = []
var completed := false


func _initialize() -> void:
	OS.low_processor_usage_mode = false
	call_deferred("run")


func check(value: bool, label: String) -> void:
	if not value:
		failures.append(label)


func run() -> void:
	var intro = Intro.new()
	root.add_child(intro)
	intro.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	intro.completed.connect(func(): completed = true)
	intro.start()
	intro.set_process(false)
	check(not intro.request_exit(), "source Earth-to-title animation cannot dismiss before title")
	for index in Intro.TITLE_READY:
		intro.advance_tick()
	check(intro.visible and not completed, "title remains pending original input")
	intro.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("res://../.cache/campaign")
	check(root.get_texture().get_image().save_png("res://../.cache/campaign/startup-native.png") == OK, "authored title rendered natively")
	check(intro.request_exit(), "source title accepts continue")
	for index in Intro.EXIT_FADE - 1:
		intro.advance_tick()
	check(not completed, "original exit wait retained")
	intro.advance_tick()
	check(completed and not intro.visible, "original intro completion returns to reception")
	intro.queue_free()
	await process_frame
	for failure in failures:
		push_error(failure)
	if failures.is_empty():
		print("PASS: original boot phases, input gate, exit wait and authored native title")
	quit(0 if failures.is_empty() else 1)
