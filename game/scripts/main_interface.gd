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
	preload("res://scripts/keyboard_settings.gd").attach(app)
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
	_build_map(app, body)
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


static func _build_map(app, body: VBoxContainer) -> void:
	app._map_panel = VBoxContainer.new()
	app._map_panel.add_theme_constant_override("separation", 0)
	app._map_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(app._map_panel)
	app.world_view = app.WorldViewScript.new()
	app.world_view.world_data = app.world_data
	app.world_view.session = app.session
	app.world_view.network = app.network
	app.world_view.switch_toggled.connect(app._on_switch_toggled)
	app.world_view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	app.world_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	app.world_view.city_picked.connect(app._on_chart_city_picked)
	app._map_panel.add_child(app.world_view)
	app.travel_controls = preload("res://scripts/travel_hud.gd").new()
	app.travel_controls.bind_session(app.session)
	app.travel_controls.journey = app.journey
	app.travel_controls.requested.connect(app._open_panel)
	app.travel_controls.follow_requested.connect(app.world_view.follow_train)
	app._map_panel.add_child(app.travel_controls)
	app.travel_controls.hide()
	_build_hidden_city_index(app)


static func _build_hidden_city_index(app) -> void:
	# Keep the city selection model available without a dashboard beside the app.world.
	var index_container := VBoxContainer.new()
	app._map_panel.add_child(index_container)
	app.search_box = LineEdit.new()
	app.search_box.text_changed.connect(app._filter_cities)
	index_container.add_child(app.search_box)
	app.city_list = ItemList.new()
	app.city_list.item_selected.connect(app._on_city_selected)
	index_container.add_child(app.city_list)
	app.status_label = Label.new()
	index_container.add_child(app.status_label)
	index_container.hide()
	app._filter_cities("")


# Arrival scene for TIME message 76 (tasks/evidence/station-arrival.md): the
# glieu menu and its transactions (tasks/evidence/city-scripts.md), in city_screen.gd.
# YODA 0x104 (-120): brake, TEXTEK 52, then the 0x18e3 reversal with speed 0.


static func show_city(app, index: int) -> void:
	# Presentation-only reopening: visits mutate nomad stock and source flags.
	var city: Dictionary = app.world_data.cities[index]
	# Adaptation: the remake clock pauses during the city scene.
	app.session.paused = true
	app._city_panel.open(index,String(city.name),int(city.kind),String(city.type))
	app._city_panel.position = (app.size-app._city_panel.size)*0.5
	app.world_view.selected_city = index
	app.room_controls.announce("Arrived at %s" % String(city.name))
