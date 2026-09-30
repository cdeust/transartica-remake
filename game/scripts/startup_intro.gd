extends "res://scripts/original_screen.gd"

# MIT. MAIN0x573..645, PRESENT and PRESENT2: original boot, before reception.
signal completed
const PUBLISHER_END := 252 # PRESENT9-cycle waits23 times, then45 one-cycle waits.
const TITLE_READY := 360 # PRESENT2 four-cycle waits27 times.
const TITLE_TIMEOUT := 30000 # MAIN0x5fc original title input timeout.
const EXIT_FADE := 60 # MAIN0x60b..612 after cdelmusic50.
var tick := 0
var _remainder := 0.0
var _exit_tick := -1
var _art: Texture2D
var _data: Dictionary = {}
var _audio


func _ready() -> void:
	super._ready()
	if ResourceLoader.exists("res://assets/campaign/startup.png"):
		_art = load("res://assets/campaign/startup.png")
	if FileAccess.file_exists("res://private-data/startup.json"):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://private-data/startup.json"))
		if parsed is Dictionary:
			_data = parsed
	set_process(false)
	hide()


func start(audio = null) -> void:
	_audio = audio
	tick = 0
	_remainder = 0
	_exit_tick = -1
	show()
	set_process(true)
	queue_redraw()


func _process(delta: float) -> void:
	_remainder += delta * 50 # Original ECS clock; per-entity wait divisors retained.
	while _remainder >= 1:
		_remainder -= 1
		advance_tick()
	queue_redraw()


func advance_tick() -> void:
	tick += 1
	if tick == 99 and _audio != null:
		_audio.effect("present", 0x3c)
	if tick == PUBLISHER_END and _audio != null:
		_audio.play_reception() # MAIN0x593 ECS BOPRES before PRESENT2.
	if _exit_tick < 0 and tick >= TITLE_READY + TITLE_TIMEOUT:
		request_exit()
	if _exit_tick >= 0 and tick - _exit_tick >= EXIT_FADE:
		hide()
		set_process(false)
		completed.emit()


func request_exit() -> bool:
	if tick < TITLE_READY or _exit_tick >= 0:
		return false
	_exit_tick = tick
	if _audio != null:
		_audio.fade_music(50) # MAIN0x608, original mv2_offmusic.
	return true


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		request_exit()
		accept_event()


func _unhandled_key_input(event: InputEvent) -> void:
	if visible and event is InputEventKey and event.pressed and event.physical_keycode in [KEY_SPACE, KEY_ENTER]:
		request_exit()
		get_viewport().set_input_as_handled()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color.BLACK)
	if _art != null:
		var half := _art.get_height() / 2.0
		var region := Rect2(0, 0 if tick < PUBLISHER_END else half, _art.get_width(), half)
		var bounds := canvas_rect()
		var factor := bounds.size.x / 320
		var lift := clampi((tick - 207) * 2, 0, 70) if tick < PUBLISHER_END else 0
		var image_rect := Rect2(bounds.position + Vector2(0, 60 - lift if tick < PUBLISHER_END else 0) * factor,
			Vector2(320, 80) * factor)
		var pose := clampi((tick - 99) / 9, 0, 8) if tick < PUBLISHER_END else 0
		var alpha := 1.0 - float(pose) / 8 if tick < PUBLISHER_END else 1.0
		draw_texture_rect_region(_art, image_rect, region, Color(1, 1, 1, alpha))
	begin_canvas()
	if tick < PUBLISHER_END:
		if tick >= 99:
			var letters := clampi((tick - 99) / 9 + 1, 0, 8)
			var title: String = _data.get("title", "")
			# Eight authored reveal poses follow source sprite30..37; no historical pixels.
			centered(140 - clampi((tick - 207) * 2, 0, 70), title.left(ceili(title.length() * float(letters) / 8)), 18)
	elif tick >= TITLE_READY - 4:
		centered(30, str(_data.get("title", "")), 23)
		var y := 100
		for credit in _data.get("credits", []):
			centered(y, str(credit), 8)
			y += 13
	draw_set_transform(Vector2.ZERO)
	if _exit_tick >= 0:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, float(tick - _exit_tick) / EXIT_FADE))
