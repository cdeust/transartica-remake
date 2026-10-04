extends SceneTree

# MIT. Owner Turin11592 quantity wrap; actual font metrics on city resize fixtures.
func _initialize() -> void:
	call_deferred("run")


func run() -> void:
	var screen = preload("res://scripts/city_screen.gd").new()
	screen.trade = preload("res://scripts/city_trade.gd").new()
	assert(screen.trade.load_from_project(ProjectSettings.globalize_path("res://").trim_suffix("/")))
	var rng := RandomNumberGenerator.new()
	rng.seed = 7 # Existing reproducible test_city_presentation commerce fixture.
	screen.trade.reset(rng)
	screen.wagons = preload("res://scripts/train_wagons.gd").new()
	screen.engine = preload("res://scripts/engine_state.gd").new()
	root.add_child(screen)
	for viewport in [Vector2i(1440,900),Vector2i(1280,800),Vector2i(960,540),Vector2i(640,800)]:
		root.size = viewport
		root.content_scale_size = viewport
		await process_frame
		screen.open(24,"KUWAIT",2,"COMMERCIAL")
		screen.start(screen.CityTrade.BUY)
		await process_frame
		verify(screen)
		if viewport == Vector2i(1440,900):
			var font: Font = screen._list.get_theme_font("font")
			var pixels: int = screen._list.get_theme_font_size("font_size")
			var available: int = screen._list.fixed_column_width-2*screen._list.get_theme_constant("h_separation")
			assert(font.get_string_size("LINE INSPECTION CARS  61",HORIZONTAL_ALIGNMENT_LEFT,-1,pixels).x > available)
			assert(font.get_string_size("LINE INSPECTION CARS",HORIZONTAL_ALIGNMENT_LEFT,-1,pixels).x <= available)
			assert(font.get_string_size("61",HORIZONTAL_ALIGNMENT_LEFT,-1,pixels).x <= available)
		screen.open(10,"WORKSHOP",3,"")
		screen.start_workshop()
		await process_frame
		verify(screen)
		print("Measured city labels fit: %s, font%d, column%d" % [viewport,screen._list.get_theme_font_size("font_size"),screen._list.fixed_column_width])
	print("PASS: all source goods/wagon names and complete quantity lines fit measured columns")
	quit()


func verify(screen) -> void:
	var list: ItemList = screen._list
	assert(list.max_columns == 5 and list.max_text_lines == 2)
	var font := list.get_theme_font("font")
	var pixels := list.get_theme_font_size("font_size")
	var available := list.fixed_column_width-2*list.get_theme_constant("h_separation")
	for names in [screen.trade.data.goods_names,screen.trade.data.wagon_names]:
		for name in names:
			assert(font.get_string_size(name,HORIZONTAL_ALIGNMENT_LEFT,-1,pixels).x <= available)
	for index in list.item_count:
		var lines := list.get_item_text(index).split("\n")
		assert(lines.size() == 2 and lines[1].is_valid_int())
		assert(int(lines[1]) == int(screen._rows[index][1]))
		for line in lines:
			assert(font.get_string_size(line,HORIZONTAL_ALIGNMENT_LEFT,-1,pixels).x <= available)
