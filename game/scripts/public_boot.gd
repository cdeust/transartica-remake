extends Control
# MIT. Public-only data gate: main is loaded only after validated private ZIP mount.
const DataPack := preload("res://scripts/public_data_pack.gd")
var status: Label
var picker: FileDialog

func _ready() -> void:
	var result := DataPack.mount()
	if result.ok:
		_start_game.call_deferred()
		return
	_build_menu(result.message)

func _build_menu(message: String) -> void:
	var background := ColorRect.new()
	background.color = Color("#0c222c") # Existing panel/city dark blue palette.
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left","right","top","bottom"]:
		margin.add_theme_constant_override("margin_"+side,32)
	add_child(margin)
	var center := CenterContainer.new()
	margin.add_child(center)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation",24)
	center.add_child(column)
	var title := Label.new()
	title.text = "TRANSARTICA"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size",48)
	title.add_theme_color_override("font_color",Color("#ffe1a0"))
	column.add_child(title)
	var description := Label.new()
	description.text = "To begin, choose your original-data.zip file."
	description.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	description.add_theme_font_size_override("font_size",24)
	column.add_child(description)
	status = Label.new()
	status.text = message
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status.add_theme_font_size_override("font_size",20)
	column.add_child(status)
	var choose := Button.new()
	choose.text = "Choose data ZIP"
	choose.add_theme_font_size_override("font_size",24)
	choose.pressed.connect(func(): picker.popup_centered())
	column.add_child(choose)
	var quit := Button.new()
	quit.text = "Quit"
	quit.add_theme_font_size_override("font_size",24)
	quit.pressed.connect(func(): get_tree().quit())
	column.add_child(quit)
	picker = FileDialog.new()
	picker.access = FileDialog.ACCESS_FILESYSTEM
	picker.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	picker.filters = PackedStringArray(["*.zip ; Original game data"])
	picker.use_native_dialog = true
	picker.file_selected.connect(_install)
	add_child(picker)
	choose.grab_focus()

func _install(path: String) -> void:
	status.text = "Checking game data…"
	var result := DataPack.install(path)
	if result.ok: _start_game()
	else: status.text = result.message

func _start_game() -> void:
	# No main preload: original data must be mounted before main scripts initialize.
	var error := get_tree().change_scene_to_file("res://main.tscn")
	if error != OK:
		if status != null: status.text = "The game could not be started."
		else: _build_menu("The game could not be started.")
