extends VBoxContainer
class_name TravelControls

const PANEL_BG := Color("#13232d") # source: tasks/visual-design.md; shared authored interface palette.
const CARD_BG := Color("#1c303b") # source: tasks/visual-design.md; shared authored interface palette.
const BORDER := Color("#4b626b")
const BRASS := Color("#d0ad68")
const MUTED := Color("#91a7ab")
const ALERT := Color("#cf7257")

var session
var status_label: Label
var cycle_label: Label
var stocks_label: Label
var rates_label: Label
var speed_label: Label
var heat_label: Label
var reserve_label: Label
var regulator_label: Label
var pause_button: Button
var brake_button: Button
var regulator_slider: HSlider

signal requested(panel: String)
signal follow_requested


func _ready() -> void:
	_build_controls()
	refresh()


func bind_session(value) -> void:
	session = value
	refresh()


func refresh() -> void:
	if status_label == null:
		return
	if session == null:
		status_label.text = "DRIVING MODEL NOT CONNECTED"
		return
	_refresh_status()
	_refresh_readouts()
	_refresh_buttons()


func _build_controls() -> void:
	add_theme_stylebox_override("panel", _panel_style(PANEL_BG, BORDER))
	add_theme_constant_override("separation", 9)
	_add_heading()
	_add_fuel_controls()
	_add_regulator_control()
	_add_motion_readouts()
	_add_action_controls()
	_add_navigation_controls()


func _add_heading() -> void:
	var title := Label.new()
	title.text = "DRIVING CONTROLS"
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", BRASS)
	add_child(title)
	status_label = Label.new()
	status_label.add_theme_color_override("font_color", MUTED)
	add_child(status_label)
	cycle_label = Label.new()
	cycle_label.add_theme_font_size_override("font_size", 11)
	cycle_label.add_theme_color_override("font_color", MUTED)
	add_child(cycle_label)


func _add_fuel_controls() -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	add_child(row)
	var lignite := _make_button("LIGNITE LOAD")
	lignite.pressed.connect(_on_lignite_pressed)
	row.add_child(lignite)
	var anthracite := _make_button("ANTHRACITE LOAD")
	anthracite.pressed.connect(_on_anthracite_pressed)
	row.add_child(anthracite)
	stocks_label = _make_readout()
	rates_label = _make_readout()
	stocks_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rates_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	stocks_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rates_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(stocks_label)
	add_child(rates_label)


func _add_regulator_control() -> void:
	var caption := Label.new()
	caption.text = "REGULATOR · 0–300"
	caption.add_theme_color_override("font_color", BRASS)
	add_child(caption)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	add_child(row)
	regulator_slider = HSlider.new()
	regulator_slider.min_value = 0
	regulator_slider.max_value = 300
	regulator_slider.step = 1
	regulator_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	regulator_slider.value_changed.connect(_on_regulator_changed)
	row.add_child(regulator_slider)
	regulator_label = _make_readout()
	regulator_label.custom_minimum_size.x = 42
	row.add_child(regulator_label)


func _add_motion_readouts() -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	add_child(row)
	speed_label = _add_readout(row, "SPEED")
	heat_label = _add_readout(row, "HEAT · INTERNAL")
	reserve_label = _add_readout(row, "RESERVE · INTERNAL")


func _add_readout(parent: HBoxContainer, title: String) -> Label:
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(column)
	var heading := Label.new()
	heading.text = title
	heading.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	heading.add_theme_font_size_override("font_size", 10)
	heading.add_theme_color_override("font_color", MUTED)
	column.add_child(heading)
	var value := _make_readout()
	value.add_theme_font_size_override("font_size", 17)
	column.add_child(value)
	return value


func _add_action_controls() -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	add_child(row)
	pause_button = _make_button("PAUSE")
	pause_button.pressed.connect(_on_pause_pressed)
	row.add_child(pause_button)
	brake_button = _make_button("APPLY BRAKE")
	brake_button.pressed.connect(_on_brake_pressed)
	row.add_child(brake_button)
	var instruments := _make_button("INSTRUMENTS")
	instruments.pressed.connect(_on_instruments_pressed)
	row.add_child(instruments)


func _add_navigation_controls() -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	add_child(row)
	var follow := _make_button("FOLLOW TRAIN")
	follow.pressed.connect(_on_follow_pressed)
	row.add_child(follow)


func _make_button(label: String) -> Button:
	var button := Button.new()
	button.text = label
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.add_theme_stylebox_override("normal", _panel_style(CARD_BG, BORDER))
	button.add_theme_color_override("font_color", Color("#e5dcc7"))
	return button


func _make_readout() -> Label:
	var label := Label.new()
	label.text = "—"
	label.add_theme_color_override("font_color", Color("#e5dcc7"))
	return label


func _refresh_status() -> void:
	var engine = session.engine
	if engine.event_pending:
		status_label.text = "EVENT · " + String(engine.event_message)
		status_label.add_theme_color_override("font_color", ALERT)
	elif session.paused:
		status_label.text = "SIMULATION PAUSED"
		status_label.add_theme_color_override("font_color", MUTED)
	else:
		status_label.text = "SIMULATION RUNNING"
		status_label.add_theme_color_override("font_color", MUTED)
	cycle_label.text = "CYCLE %d" % int(engine.cycles)


func _refresh_readouts() -> void:
	var engine = session.engine
	stocks_label.text = "LIGNITE %d BAKS   ·   ANTHRACITE %d" % [engine.lignite, engine.anthracite]
	rates_label.text = "LIGNITE %s\nANTHRACITE %s" % [_rate_name(engine.lignite_rate), _rate_name(engine.anthracite_rate)]
	regulator_slider.set_value_no_signal(clampf(float(engine.regulator), 0.0, 300.0))
	regulator_label.text = str(int(engine.regulator))
	speed_label.text = str(int(engine.speed))
	heat_label.text = str(int(engine.heat))
	reserve_label.text = str(int(engine.pressure_reserve))


func _refresh_buttons() -> void:
	pause_button.text = "RESUME" if session.paused else "PAUSE"
	brake_button.text = "RELEASE BRAKE" if session.engine.brake else "APPLY BRAKE"


func _rate_name(rate: int) -> String:
	return ["OFF", "NORMAL", "FAST"][clampi(rate, 0, 2)]


func _on_pause_pressed() -> void:
	session.paused = not session.paused
	refresh()


func _on_brake_pressed() -> void:
	session.engine.toggle_brake()
	refresh()


func _on_regulator_changed(value: float) -> void:
	session.engine.set_regulator(value)
	refresh()


func _on_lignite_pressed() -> void:
	session.engine.cycle_lignite()
	refresh()


func _on_anthracite_pressed() -> void:
	session.engine.cycle_anthracite()
	refresh()


func _on_instruments_pressed() -> void:
	requested.emit("instruments")


func _on_follow_pressed() -> void:
	follow_requested.emit()


func _panel_style(background: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(1)
	style.content_margin_left = 9
	style.content_margin_right = 9
	style.content_margin_top = 7
	style.content_margin_bottom = 7
	return style
