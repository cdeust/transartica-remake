extends RefCounted

# MIT. PR7 composition moved without behavior changes; ECS layout is unchanged.
# Source: tasks/evidence/boudoir-layout.md, panel-layout.md, city-scripts.md.

static func _build_interface(app) -> void:
	app.theme = app.AtlasThemeScript.create_theme()
	app.room_art = app.RoomArtScript.new()
	app.room_art.engine = app.engine
	app.room_art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	app.add_child(app.room_art)
	app.room_controls = app.RoomControlsScript.new()
	app.room_controls.art = app.room_art
	app.room_controls.session = app.session
	app.room_controls.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	app.room_controls.requested.connect(app._open_panel)
	app.add_child(app.room_controls)
	app.instruments = preload("res://scripts/engine_instruments.gd").new()
	app.instruments.bind_session(app.session)
	app.instruments.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	app.instruments.requested.connect(app._open_panel)
	app.add_child(app.instruments)
	app.instruments.hide()
	app._build_modal()
	app._build_city_screen()
	app._build_works_dialog()
	app._boudoir_session.attach(app)
	app.boudoir = app._boudoir_session.view




static func _build_modal(app) -> void:
	app._modal = PanelContainer.new()
	app._modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var screen_style := StyleBoxFlat.new()
	screen_style.bg_color = Color("#0d1b23")
	screen_style.content_margin_left = 0
	screen_style.content_margin_right = 0
	screen_style.content_margin_top = 0
	screen_style.content_margin_bottom = 0
	app._modal.add_theme_stylebox_override("panel", screen_style)
	app.add_child(app._modal)
	var body := VBoxContainer.new()
	app._modal.add_child(body)
	app._modal_title = Label.new()
	body.add_child(app._modal_title)
	app._modal_title.hide()
	app._build_map(body)
	app._modal.hide()




static func _build_works_dialog(app) -> void:
	app.works_dialog = app.WorksDialogScript.new()
	app.works_dialog.journey = app.journey
	app.works_dialog.wagons = app.wagons
	app.works_dialog.rng = app._trade_rng
	if not app.works_dialog.load_texts(ProjectSettings.globalize_path("res://")):
		push_warning("TEXTEK texts unavailable (python3 tools/claude/export_textek.py); message ids shown instead.")
	app.works_dialog.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	app.works_dialog.finished.connect(app._on_works_finished)
	app.add_child(app.works_dialog)


# YODA 0x2390: the train stays braked in front of the cell; a repair lets TIME retry the entry.


static func _build_city_screen(app) -> void:
	app._city_panel = app.CityScreenScript.new()
	app._city_panel.trade = app.trade
	app._city_panel.wagons = app.wagons
	app._city_panel.engine = app.engine
	app._city_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	app._city_panel.depart_requested.connect(app.depart_from_city)
	app._city_panel.cargo_changed.connect(app._on_cargo_changed)
	app.add_child(app._city_panel)
	app._city_panel.hide()
