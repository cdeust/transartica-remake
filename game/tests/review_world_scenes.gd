extends SceneTree

# Native renderer/input review; root performs final integrated gameplay review.
const Workshop = preload("res://scripts/station_workshop.gd")
const Management = preload("res://scripts/train_management.gd")
const Wagons = preload("res://scripts/train_wagons.gd")
const EngineState = preload("res://scripts/engine_state.gd")
const Trade = preload("res://scripts/city_trade.gd")
const EventScreen = preload("res://scripts/world_event_screen.gd")

var changes := 0
var answers: Array[bool] = []

func _initialize() -> void:
	OS.low_processor_usage_mode = false
	call_deferred("_run")

func _run() -> void:
	var wagons = Wagons.new()
	wagons.wagons[4][1] = 2
	var engine = EngineState.new()
	engine.lignite = 500
	var trade = Trade.new()
	if not trade.load_from_project(ProjectSettings.globalize_path("res://")):
		push_error("commerce unavailable for native review")
		quit(1)
		return
	var management = Management.new()
	management.attach(wagons,engine)
	var scene = Workshop.new()
	scene.management = management
	scene.trade = trade
	scene.size = root.get_visible_rect().size
	scene.cargo_changed.connect(func(): changes += 1)
	root.add_child(scene)
	scene.open(Vector2i(83,40))
	await _click(scene,Vector2(145,29))
	await _click(scene,Vector2(145,50))
	await _capture("world-workshop-repair.png")
	await _click(scene,Vector2(185,134))
	if changes != 1 or wagons.wagons[4][1] != 0 or engine.lignite != 480:
		push_error("native viewport repair input failed")
		quit(1)
		return
	scene.queue_free()
	await process_frame
	var event_scene = EventScreen.new()
	event_scene.size = root.get_visible_rect().size
	root.add_child(event_scene)
	event_scene.answer_requested.connect(func(accept): answers.append(accept))
	event_scene.open_mine({"ore":"ANTHRACITE","year":2714,"wealth":45})
	await _capture("world-mine-question.png")
	await _click(event_scene,Vector2(135,131))
	await _click(event_scene,Vector2(185,131))
	if answers != [false,true]:
		push_error("native viewport mine NO/OK input failed")
		quit(1)
		return
	event_scene.show_mine()
	await _capture("world-mine-plaque.png")
	event_scene.queue_free()
	await process_frame
	print("PASS: native viewport repair and mine question clicks, three scene captures")
	quit(0)

func _click(scene,logical: Vector2) -> void:
	var point: Vector2 = scene.canvas_rect().position + logical * scene.canvas_rect().size.x / 320
	for pressed in [true,false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		event.position = point
		event.global_position = point
		root.push_input(event)
	await process_frame

func _capture(filename: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://../tasks/validation/"+filename))
