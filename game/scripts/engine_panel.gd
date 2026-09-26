extends PanelContainer
class_name EnginePanel

const PANEL_BG := Color("#13232d") # source: tasks/visual-design.md, authored interface palette
const CARD_BG := Color("#1c303b") # source: tasks/visual-design.md, authored interface palette
const BORDER := Color("#4b626b")
const BRASS := Color("#d0ad68")
const MUTED := Color("#91a7ab")
const ALERT := Color("#cf7257")

var engine
var status_label: Label
var cycle_label: Label
var lignite_stock_label: Label
var lignite_rate_label: Label
var anthracite_stock_label: Label
var anthracite_rate_label: Label
var regulator_value_label: Label
var speed_label: Label
var heat_label: Label
var pressure_label: Label
var brake_button: Button
var regulator_slider: HSlider


func _ready() -> void:
	_build_panel()
	refresh()


func bind_engine(value) -> void:
	engine = value
	refresh()


func refresh() -> void:
	if status_label == null:
		return
	if engine == null:
		status_label.text = "ENGINE MODEL NOT CONNECTED"
		return
	_refresh_stock_labels()
	_refresh_motion_labels()
	_refresh_status()


func _build_panel() -> void:
	add_theme_stylebox_override("panel", _panel_box(PANEL_BG, BORDER))
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 12)
	body.add_theme_stylebox_override("panel", _panel_box(PANEL_BG, BORDER))
	add_child(body)
	_add_heading(body)
	_add_stock_cards(body)
	_add_regulator(body)
	_add_readouts(body)
	_add_action_buttons(body)
	_add_footnote(body)


func _add_heading(body: VBoxContainer) -> void:
	var heading := Label.new()
	heading.text = "ENGINE ROOM"
	heading.add_theme_font_size_override("font_size", 21)
	heading.add_theme_color_override("font_color", Color("#e6d6b2"))
	body.add_child(heading)
	status_label = Label.new()
	status_label.add_theme_color_override("font_color", MUTED)
	body.add_child(status_label)
	cycle_label = Label.new()
	cycle_label.add_theme_font_size_override("font_size", 12)
	cycle_label.add_theme_color_override("font_color", MUTED)
	body.add_child(cycle_label)


func _add_stock_cards(body: VBoxContainer) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	body.add_child(row)
	var lignite := _make_stock_card("LIGNITE · BAKS")
	var anthracite := _make_stock_card("ANTHRACITE")
	row.add_child(lignite.card)
	row.add_child(anthracite.card)
	lignite_stock_label = lignite["stock"]
	lignite_rate_label = lignite["rate"]
	anthracite_stock_label = anthracite["stock"]
	anthracite_rate_label = anthracite["rate"]


func _make_stock_card(heading_text: String) -> Dictionary:
	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.add_theme_stylebox_override("panel", _panel_box(CARD_BG, BORDER))
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 4)
	card.add_child(content)
	var heading := Label.new()
	heading.text = heading_text
	heading.add_theme_font_size_override("font_size", 11)
	heading.add_theme_color_override("font_color", BRASS)
	content.add_child(heading)
	var stock := Label.new()
	stock.text = "—"
	stock.add_theme_font_size_override("font_size", 20)
	content.add_child(stock)
	var rate := Label.new()
	rate.text = "RATE —"
	rate.add_theme_color_override("font_color", MUTED)
	content.add_child(rate)
	return {"card": card, "stock": stock, "rate": rate}


func _add_regulator(body: VBoxContainer) -> void:
	var heading := Label.new()
	heading.text = "REGULATOR"
	heading.add_theme_color_override("font_color", BRASS)
	body.add_child(heading)
	regulator_slider = HSlider.new()
	regulator_slider.min_value = 0
	regulator_slider.max_value = 300
	regulator_slider.step = 1
	regulator_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	regulator_slider.value_changed.connect(_on_regulator_changed)
	body.add_child(regulator_slider)
	regulator_value_label = Label.new()
	regulator_value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	body.add_child(regulator_value_label)


func _add_readouts(body: VBoxContainer) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	body.add_child(row)
	speed_label = _add_readout(row, "SPEED")
	heat_label = _add_readout(row, "HEAT · INTERNAL VALUE")
	pressure_label = _add_readout(row, "STEAM RESERVE · INTERNAL VALUE")


func _add_readout(parent: HBoxContainer, title: String) -> Label:
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(column)
	var caption := Label.new()
	caption.text = title
	caption.add_theme_font_size_override("font_size", 10)
	caption.add_theme_color_override("font_color", MUTED)
	column.add_child(caption)
	var value := Label.new()
	value.add_theme_font_size_override("font_size", 18)
	column.add_child(value)
	return value


func _add_action_buttons(body: VBoxContainer) -> void:
	var fuel_row := HBoxContainer.new()
	fuel_row.add_theme_constant_override("separation", 10)
	body.add_child(fuel_row)
	var lignite_button := Button.new()
	lignite_button.text = "CYCLE LIGNITE LOAD · 0 / 1 / 2"
	lignite_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lignite_button.pressed.connect(_on_lignite_pressed)
	fuel_row.add_child(lignite_button)
	var anthracite_button := Button.new()
	anthracite_button.text = "CYCLE ANTHRACITE LOAD · 0 / 1 / 2"
	anthracite_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	anthracite_button.pressed.connect(_on_anthracite_pressed)
	fuel_row.add_child(anthracite_button)
	var controls := HBoxContainer.new()
	controls.add_theme_constant_override("separation", 10)
	body.add_child(controls)
	brake_button = Button.new()
	brake_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	brake_button.pressed.connect(_on_brake_pressed)
	controls.add_child(brake_button)
	var cycle_button := Button.new()
	cycle_button.text = "ADVANCE ONE SIMULATION CYCLE"
	cycle_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cycle_button.pressed.connect(_on_cycle_pressed)
	controls.add_child(cycle_button)
	var batch_button := Button.new()
	batch_button.text = "ADVANCE 10 CYCLES"
	batch_button.pressed.connect(_on_batch_pressed)
	controls.add_child(batch_button)


func _add_footnote(body: VBoxContainer) -> void:
	var note := Label.new()
	note.text = "Locomotive systems test · world travel and campaign not connected yet"
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.add_theme_font_size_override("font_size", 11)
	note.add_theme_color_override("font_color", MUTED)
	body.add_child(note)


func _refresh_stock_labels() -> void:
	lignite_stock_label.text = "%s BAKS" % _format_number(engine.lignite)
	lignite_rate_label.text = "RATE %s" % _format_number(engine.lignite_rate)
	anthracite_stock_label.text = _format_number(engine.anthracite)
	anthracite_rate_label.text = "RATE %s" % _format_number(engine.anthracite_rate)


func _refresh_motion_labels() -> void:
	regulator_slider.set_value_no_signal(clampf(float(engine.regulator), 0.0, 300.0))
	regulator_value_label.text = str(int(engine.regulator))
	speed_label.text = _format_number(engine.speed)
	heat_label.text = _format_number(engine.heat)
	pressure_label.text = _format_number(engine.pressure_reserve)
	brake_button.text = "RELEASE BRAKE" if engine.brake else "APPLY BRAKE"
	cycle_label.text = "CYCLE %d" % int(engine.cycles)


func _refresh_status() -> void:
	status_label.text = "EVENT REACHED · HANDLER NOT CONNECTED" if engine.event_pending else "SYSTEMS READY"
	status_label.add_theme_color_override("font_color", ALERT if engine.event_pending else MUTED)
	if engine.event_pending and not String(engine.event_message).is_empty():
		status_label.text += " · " + String(engine.event_message)


func _format_number(value: Variant) -> String:
	return str(value)


func _on_lignite_pressed() -> void:
	if engine != null:
		engine.cycle_lignite()
		refresh()


func _on_anthracite_pressed() -> void:
	if engine != null:
		engine.cycle_anthracite()
		refresh()


func _on_regulator_changed(value: float) -> void:
	if engine != null:
		engine.set_regulator(int(value))
		refresh()


func _on_brake_pressed() -> void:
	if engine != null:
		engine.toggle_brake()
		refresh()


func _on_cycle_pressed() -> void:
	if engine != null:
		engine.step_cycle()
		refresh()


func _on_batch_pressed() -> void:
	if engine == null:
		return
	for cycle in 10:
		engine.step_cycle()
	refresh()


func _panel_box(background: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(1)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	return style
