extends SceneTree
# requires-native-renderer
# MIT. Actual goods/workshop list controls, source IDs and rendered authored icons.
const Trade = preload("res://scripts/city_trade.gd")
var failures: Array[String] = []
var app

func _initialize() -> void:
	_run.call_deferred()

func check(value: bool, label: String) -> void:
	if not value:
		failures.append(label)

func _run() -> void:
	root.size = Vector2i(1280,800)
	app = load("res://scripts/main.gd").new()
	app.save_path_override = ProjectSettings.globalize_path("res://../.cache/city-list-icons-unused.SAV")
	app.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(app)
	app.set_process(false)
	await process_frame
	await process_frame
	app.game_audio.set_process(false)
	var panel = app._city_panel
	check(panel.list_icons.goods.size() == Trade.GOODS_KINDS,"all source goods IDs have authored atlas icons")
	for kind in range(1,Trade.GOODS_KINDS+1):
		var icon: Texture2D = panel.list_icons.goods_for(kind)
		check(icon != null and icon.get_size() == Vector2(panel.list_icons.FOOTPRINT),"goods%d keeps padded source-width footprint" % kind)
		if icon != null:
			check(icon.get_image().get_used_rect().has_area(),"goods%d icon has visible authored pixels" % kind)
	for kind in range(1,26):
		var icon: Texture2D = panel.list_icons.wagon_for(kind)
		check(icon.get_image().get_used_rect().has_area(),"wagon%d uses actual full silhouette" % kind)
	panel.open(24,"WAREHOUSE",Trade.COMMERCIAL,"")
	panel.start(Trade.BUY)
	check(panel._list.item_count == panel._rows.size(),"goods icons do not change source list rows")
	for index in panel._rows.size():
		var row: Array = panel._rows[index]
		check(panel._list.get_item_icon(index) == panel.list_icons.goods_for(row[0]),"goods row keeps its original ID")
		check(panel._list.get_item_text(index) == "%s  %d" % [app.trade.goods_name(row[0]),row[1]],"goods text/stock remain unchanged")
	await capture("city-goods-icons-native-20261001.png")
	panel._list.select(0)
	panel._list.grab_focus()
	await key(KEY_RIGHT)
	check(panel._list.get_selected_items()[0] == 1 and panel._offer.goods == panel._rows[1][0],"native arrow selects same goods with its icon")
	panel.open(10,"IN SALAH",0,"")
	panel.start_workshop()
	for index in panel._rows.size():
		check(panel._list.get_item_icon(index) == panel.list_icons.wagon_for(panel._rows[index][0]),"workshop row preserves source wagon type")
	await capture("city-wagon-icons-native-20261001.png")
	panel._list.select(0)
	panel._list.grab_focus()
	await key(KEY_RIGHT)
	check(panel._entry == panel._rows[1],"native arrow selects same priced wagon with its icon")
	app.game_audio.reset()
	await create_timer(AudioServer.get_time_to_next_mix()).timeout
	app.queue_free()
	await process_frame
	for failure in failures:
		push_error(failure)
	if failures.is_empty():
		print("PASS: authored goods16/wagons25 icons, unchanged source rows/text and native list selection")
	quit(0 if failures.is_empty() else 1)

func key(code: int) -> void:
	var event := InputEventKey.new()
	event.pressed = true
	event.physical_keycode = code
	event.keycode = code
	Input.parse_input_event(event)
	await process_frame
	event = event.duplicate()
	event.pressed = false
	Input.parse_input_event(event)
	await process_frame

func capture(filename: String) -> void:
	await process_frame
	app.queue_redraw()
	await RenderingServer.frame_post_draw
	var path := ProjectSettings.globalize_path("res://../tasks/validation/"+filename)
	check(root.get_texture().get_image().save_png(path) == OK,"native city screenshot saved")
