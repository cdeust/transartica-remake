extends SceneTree
# MIT. New Peking45797: actual ItemList cells, not only label widths.
const Trade = preload("res://scripts/city_trade.gd")
var failures: Array[String] = []

func _initialize() -> void:
	_run.call_deferred()

func _check(value: bool, label: String) -> void:
	if not value:
		failures.append(label)

func _run() -> void:
	var screen = preload("res://scripts/city_screen.gd").new()
	screen.trade = Trade.new()
	_check(screen.trade.load_from_project(ProjectSettings.globalize_path("res://")),"commerce loaded")
	var rng := RandomNumberGenerator.new()
	rng.seed = 7 # source: existing reproducible city refusal fixture.
	screen.trade.reset(rng)
	screen.wagons = preload("res://scripts/train_wagons.gd").new()
	screen.wagons.reset()
	screen.engine = preload("res://scripts/engine_state.gd").new()
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(screen)
	for viewport in [Vector2i(1440,900),Vector2i(1280,800),Vector2i(960,540),Vector2i(640,800)]:
		root.size = viewport
		root.content_scale_size = viewport
		await process_frame
		for city in screen.WORKSHOP_CITIES:
			screen.open(city,screen.trade.data.city_names[city-1],3,"")
			screen.start_workshop()
			await process_frame
			screen._list.force_update_list_size()
			var list: ItemList = screen._list
			var panel := list.get_theme_stylebox("panel")
			var content := Rect2(panel.get_offset(),list.size-panel.get_minimum_size())
			for index in list.item_count:
				var rect := list.get_item_rect(index)
				_check(content.encloses(rect),"%s city%d item%d fully visible" % [viewport,city,index])
				_check(is_equal_approx(rect.position.y,list.get_item_rect(index/list.max_columns*list.max_columns).position.y),"five columns per row")
				var font := list.get_theme_font("font")
				var pixels := list.get_theme_font_size("font_size")
				for line in list.get_item_text(index).split("\n"):
					_check(font.get_string_size(line,HORIZONTAL_ALIGNMENT_LEFT,-1,pixels).x <= rect.size.x-2*list.get_theme_constant("h_separation"),"whole name and price fit cell")
			_check(list.get_v_scroll_bar().max_value <= list.get_v_scroll_bar().page,"all workshop rows fit without scrolling") # source: Godot ItemList scroll max/page.
			_check(not list.get_global_rect().intersects(screen._detail.get_global_rect()),"detail separate")
			_check(not screen._detail.get_global_rect().intersects(screen._notice.get_global_rect()),"notice separate")
			if city == 14: # source: commerce.json, original NEW PEKING city14.
				_check(list.item_count == 6 and list.get_item_text(5) == "CANNON\n500","actual New Peking cannon price")
				print("WORKSHOP ",viewport," font=",list.get_theme_font_size("font_size")," first=",list.get_item_rect(0)," fifth=",list.get_item_rect(4)," cannon=",list.get_item_rect(5)," page=",list.get_v_scroll_bar().page," max=",list.get_v_scroll_bar().max_value)
		await _commercial(screen)
	for failure in failures:
		push_error(failure)
	if failures.is_empty():
		print("PASS: all seven workshops retain five columns and complete names/prices; commercial cells scroll fully into view at four resolutions")
	screen.queue_free()
	quit(0 if failures.is_empty() else 1)

func _commercial(screen) -> void:
	# Actual source merchandise names and quantities; commercial lists may scroll.
	screen.open(34,"PARIS",Trade.COMMERCIAL,"")
	screen.start(Trade.BUY)
	screen._workshop = false
	screen._list.clear()
	for index in screen.trade.data.goods_names.size():
		screen._list.add_item("%s\n61" % screen.trade.data.goods_names[index],screen.list_icons.goods_for(index)) # source: earned Turin11592 quantity61.
	screen._layout()
	await process_frame
	var list: ItemList = screen._list
	list.force_update_list_size()
	var panel := list.get_theme_stylebox("panel")
	var content := Rect2(panel.get_offset(),list.size-panel.get_minimum_size())
	for index in list.item_count:
		list.select(index)
		list.ensure_current_is_visible()
		await process_frame
		var rect := list.get_item_rect(index)
		_check(is_equal_approx(rect.position.y,list.get_item_rect(index/list.max_columns*list.max_columns).position.y),"scrolling commercial list retains five columns")
		var visible_rect := rect
		visible_rect.position.y -= list.get_v_scroll_bar().value
		_check(content.encloses(visible_rect),"commercial item and quantity fully visible after scroll")
