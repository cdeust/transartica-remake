extends SceneTree

# MIT. Owner captures3Oct: denied inspection/spies stretched the GQ room
# from149 to200 lines and erased the train bar. Layout sources:
# tasks/evidence/captain-crew.md and boudoir-layout.md TEXTEK0x273f..2774.
const Screen = preload("res://scripts/campaign_screen.gd")
const Quarters = preload("res://scripts/general_quarters.gd")
const SharedPanel = preload("res://scripts/original_panel.gd")
var failures: Array[String] = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var screen = Screen.new()
	var quarters = Quarters.new()
	root.add_child(screen)
	root.add_child(quarters)
	await process_frame
	for extent in [Vector2(320, 200), Vector2(1440, 900), Vector2(1800, 900)]:
		screen.size = extent
		quarters.size = extent
		for name in ["", "crew", "spy_pickup", "sabotage_confirm"]:
			screen.scene = name
			var frame: Rect2 = quarters.canvas_rect()
			var expected := Rect2(frame.position, frame.size * Vector2(1, SharedPanel.STRIP.position.y / quarters.CANVAS.y))
			check(screen.scene_art_rect().is_equal_approx(expected), "GQ notice/menu matches underlying room at %s: %s" % [extent, name])
			var bar_start: float = frame.position.y + SharedPanel.STRIP.position.y * frame.size.y / quarters.CANVAS.y
			check(is_equal_approx(screen.scene_art_rect().end.y, bar_start), "room ends before shared train bar")
		screen.scene = "urga"
		check(screen.scene_art_rect().is_equal_approx(screen.canvas_rect()), "campaign scene retains its full original canvas")
	var continued := [0]
	screen.continued.connect(func(): continued[0] += 1)
	for message in ["YOU HAVE NO LINE INSPECTION CARS", "YOU DON'T HAVE ANY SPIES"]:
		screen.present("", [message, "AND YOU CANNOT ACCESS THIS MENU"])
		check(screen.lines[0] == message and not screen.question and screen.menu.is_empty(), "denied notice retains text and dismissal mode")
		var key := InputEventKey.new()
		key.physical_keycode = KEY_ENTER
		screen.handle_key(key)
	check(continued[0] == 2, "Return dismisses both notices")
	screen.queue_free()
	quarters.queue_free()
	await process_frame
	for failure in failures:
		push_error(failure)
	if failures.is_empty():
		print("PASS: denied GQ notices retain room149, shared train bar, source banner and dismissal")
	quit(0 if failures.is_empty() else 1)


func check(ok: bool, label: String) -> void:
	if not ok:
		failures.append(label)
