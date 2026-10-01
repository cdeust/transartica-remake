extends "res://scripts/original_screen.gd"

# MIT. ECS scene navigation: YODA0xdae, SCENE3/4, TEXTEK story dispatch.
# Authored art from visual-coverage.md; preserves scene+bottom narrative composition.
signal continued
signal code_submitted(value: String)
signal answered(proceed: bool)
signal menu_selected(code: int)
var scene := ""
var lines: Array[String] = []
var input_code := ""
var entering_code := false
var question := false
var menu: Array[String] = []
var _art: Dictionary = {}
var finale := preload("res://scripts/finale_sequence.gd").new()
var _finale_art := preload("res://scripts/finale_art.gd").new()
var _finale_audio: AudioStreamPlayer
signal movie_finished


func _ready() -> void:
	super._ready()
	for name in ["urga", "oslo", "mausoleum", "sun-overcast", "sun-restored", "whale", "slope"]:
		_art[name] = load("res://assets/campaign/%s.png" % name)
	for name in ["wolf", "mole"]:
		_art[name] = load("res://assets/campaign/%s-ambush.png" % name)
	_finale_art.load_art()
	hide()


func present(name: String, message: Array, code := false, ask := false) -> void:
	stop_movie()
	scene = name
	lines.clear()
	for line in message:
		lines.append(str(line))
	entering_code = code
	question = ask
	menu = []
	input_code = ""
	show()
	queue_redraw()


func open_menu(labels: Array) -> void:
	scene = "crew"
	lines = []
	menu.clear()
	for label in labels:
		menu.append(str(label))
	question = false
	entering_code = false
	show()
	queue_redraw()


func start_movie() -> void:
	present("sun-restored", [])
	finale.start(randi())
	_resume_audio()
	queue_redraw()


func _process(delta: float) -> void:
	if visible and scene == "sun-restored" and finale.tick < finale.LAST:
		if finale.advance(delta):
			stop_movie()
			movie_finished.emit()
		queue_redraw()


func _resume_audio() -> void:
	var path := "res://private-data/finale.wav"
	if not FileAccess.file_exists(path):
		return
	if _finale_audio == null:
		_finale_audio = AudioStreamPlayer.new()
		add_child(_finale_audio)
	_finale_audio.stream = AudioStreamWAV.load_from_file(path)
	_finale_audio.play((finale.tick + finale.remainder) / finale.HZ)


func stop_movie() -> void:
	if _finale_audio != null:
		_finale_audio.stop()


func restore_movie(value: Dictionary) -> void:
	finale.restore(value)
	if visible and scene == "sun-restored" and finale.tick < finale.LAST:
		_resume_audio()


func _draw() -> void:
	if scene == "sun-restored":
		_finale_art.draw_on(self, finale)
		return
	draw_rect(Rect2(Vector2.ZERO, size), Color.BLACK)
	var key := "whale" if scene.begins_with("whale") else scene
	if key == "sun":
		key = "sun-overcast"
	if _art.has(key):
		draw_texture_rect(_art[key], canvas_rect(), false)
	elif scene in ["crew", "", "spy_pickup", "sabotage_confirm"]:
		draw_texture_rect(load("res://assets/boudoir/general-quarters.png"), canvas_rect(), false)
	if scene == "earth":
		draw_texture_rect(load("res://assets/interface/mort-earth.png"), canvas_rect(), false)
		return
	if scene in ["death", "report", "manual_quiz"]:
		frame()
		begin_canvas()
		# TEXTE2K0x2cd9 vertical anchors, boudoir-layout.md exact display.
		var anchors := [17, 34, 49, 64, 79, 94, 109, 124, 139, 154]
		for index in mini(lines.size(), anchors.size()):
			centered(anchors[index], lines[index])
		if entering_code:
			centered(137, input_code + "_")
		draw_set_transform(Vector2.ZERO)
		return
	begin_canvas()
	if not menu.is_empty():
		for index in menu.size():
			centered(57 + index * 25, "%d  %s" % [index + 1, menu[index]])
	else:
		draw_rect(Rect2(0, 159, 320, 41), Color.BLACK)
		for index in lines.size():
			centered(169 + index * 9, lines[index])
	if entering_code:
		centered(137, input_code + "_")
	if question:
		centered(145, "NO                         OK") # TEXTEK resource11 source obstacles-unknowns§2.
	draw_set_transform(Vector2.ZERO)


func handle_key(event: InputEventKey) -> void:
	if scene == "sun-restored" and finale.tick < finale.LAST:
		return
	if not menu.is_empty():
		var choice := event.physical_keycode - KEY_1
		if choice >= 0 and choice < menu.size():
			menu_selected.emit(choice)
		elif event.physical_keycode in [KEY_ESCAPE, KEY_F1]:
			menu_selected.emit(menu.size() - 1)
	elif entering_code:
		if event.physical_keycode == KEY_BACKSPACE:
			input_code = input_code.left(maxi(0, input_code.length() - 1))
		elif event.physical_keycode == KEY_ENTER:
			code_submitted.emit(input_code)
		elif scene == "manual_quiz" and event.unicode >= 65 and event.unicode <= 122 and char(event.unicode).to_upper() >= "A" and char(event.unicode).to_upper() <= "Z" and input_code.length() < 8:
			input_code += char(event.unicode).to_upper()
		elif scene != "manual_quiz" and event.unicode >= 48 and event.unicode <= 57 and input_code.length() < 5:
			input_code += char(event.unicode) # SCENE4 0x17e..206 digits limit5.
		queue_redraw()
	elif question:
		if event.physical_keycode in [KEY_ESCAPE, KEY_N]:
			answered.emit(false)
		elif event.physical_keycode in [KEY_ENTER, KEY_Y]:
			answered.emit(true)
	elif event.physical_keycode in [KEY_SPACE, KEY_ENTER, KEY_ESCAPE]:
		continued.emit()


func _gui_input(event: InputEvent) -> void:
	if not event is InputEventMouseButton or not event.pressed:
		return
	if scene == "sun-restored" and finale.tick < finale.LAST:
		accept_event()
		return
	var point := logical_point(event.position)
	if not menu.is_empty() and event.button_index == MOUSE_BUTTON_LEFT:
		var choice := floori((point.y - 44) / 25)
		if choice >= 0 and choice < menu.size():
			menu_selected.emit(choice)
	elif question:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			answered.emit(false)
		elif event.button_index == MOUSE_BUTTON_LEFT:
			answered.emit(point.x >= 160)
	elif not entering_code and event.button_index == MOUSE_BUTTON_LEFT:
		continued.emit()
	accept_event()
