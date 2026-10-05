extends SceneTree
# requires-native-renderer
# MIT. Reproduce Paris33126 capacity refusal through the actual transaction.
const Trade = preload("res://scripts/city_trade.gd")
var failures: Array[String] = []
var screen

func _initialize() -> void:
	_run.call_deferred()

func _check(value: bool, label: String) -> void:
	if not value:
		failures.append(label)

func _run() -> void:
	OS.low_processor_usage_mode = false
	screen = preload("res://scripts/city_screen.gd").new()
	screen.trade = Trade.new()
	_check(screen.trade.load_from_project(ProjectSettings.globalize_path("res://")),"private commerce available")
	var rng := RandomNumberGenerator.new()
	rng.seed = 7 # Existing reproducible city commerce fixture.
	screen.trade.reset(rng)
	screen.wagons = preload("res://scripts/train_wagons.gd").new()
	screen.engine = preload("res://scripts/engine_state.gd").new()
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(screen)
	for viewport in [Vector2i(1440,900),Vector2i(1280,800)]:
		root.size = viewport
		root.content_scale_size = viewport
		await process_frame
		await _cases(viewport)
	screen.queue_free()
	await process_frame
	for failure in failures:
		push_error(failure)
	if failures.is_empty():
		print("PASS: native refusal, full three-line detail and workshop/menu notice separation at both resolutions")
	quit(0 if failures.is_empty() else 1)

func _cases(viewport: Vector2i) -> void:
	screen.wagons.reset()
	screen.wagons.wagons.append([18,0,15,33]) # Paris33126 caviar cargo.
	screen.engine.lignite = 4185 # Paris33126 actual currency.
	screen.engine.anthracite = 785 # Paris33126 actual fuel, shared tender5000.
	screen.open(34,"PARIS",Trade.COMMERCIAL,"")
	screen.start(Trade.SELL)
	for index in screen._rows.size():
		if screen._rows[index][0] == 15:
			screen._select_goods(index)
	screen.increment()
	_check(screen._quantity == 0 and screen._notice.text == screen.REFUSALS[Trade.NO_COAL_ROOM],"actual coal-room refusal")
	await _inspect("capacity",viewport)
	screen.open(13,"GDANSK",3,"")
	screen.start_workshop()
	screen._select_goods(0)
	screen.engine.lignite = 0
	screen.increment()
	_check(screen._notice.text == screen.REFUSALS[Trade.NO_MONEY],"actual workshop money refusal")
	await _inspect("workshop",viewport)
	screen.wagons.wagons = [[1,0,0,0],[21,0,0,0]]
	screen.open(8,"MOSCOW",Trade.GARRISON,"")
	screen.start(Trade.BUY)
	_check(screen._notice.text == screen.REFUSALS[Trade.NO_ROOM],"actual menu entry refusal")
	await _inspect("menu",viewport)

func _inspect(name: String, viewport: Vector2i) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var notice: Rect2 = screen._notice.get_global_rect()
	var detail: Rect2 = screen._detail.get_global_rect()
	if screen.in_transaction():
		_check(not detail.intersects(notice),name+" detail and notice do not overlap")
		_check(not screen._list.get_global_rect().intersects(detail),name+" list and detail do not overlap")
		_check(screen._detail.text.split("\n").size() == 3,name+" full three-line detail retained")
		_check(screen._detail.get_minimum_size().y <= detail.size.y,name+" detail height holds all lines")
		var detail_font: Font = screen._detail.get_theme_font("font")
		for line in screen._detail.text.split("\n"):
			_check(detail_font.get_string_size(line,HORIZONTAL_ALIGNMENT_LEFT,-1,screen._detail.get_theme_font_size("font_size")).x <= detail.size.x,name+" full detail line fits width")
	_check(screen.backdrop.screen_rect(Rect2(0,39,320,110)).encloses(notice),name+" notice stays above shared HUD")
	var font: Font = screen._notice.get_theme_font("font")
	var pixels: int = screen._notice.get_theme_font_size("font_size")
	for text in screen.REFUSALS.values()+["No price is recorded for this city.","No price is recorded for these goods."]:
		_check(font.get_string_size(text,HORIZONTAL_ALIGNMENT_LEFT,-1,pixels).x <= notice.size.x,"complete notice fits width")
	_check(screen._notice.get_minimum_size().y <= notice.size.y,name+" notice height holds text")
	print("LAYOUT ",viewport," ",name," detail=",detail," notice=",notice," overlap=",detail.intersection(notice).size.y)
	var stage := OS.get_cmdline_user_args()[0] if not OS.get_cmdline_user_args().is_empty() else "after"
	var folder := ProjectSettings.globalize_path("res://../tasks/validation/city-refusal-layout-20261005")
	DirAccess.make_dir_recursive_absolute(folder)
	_check(root.get_texture().get_image().save_png(folder.path_join("%s-%s-%d.png" % [stage,name,viewport.x])) == OK,"native capture saved")
