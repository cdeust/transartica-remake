extends "res://scripts/original_screen.gd"

# Full-frame inventory and click pagination: textek 0x2be7,0x3809.
signal closed
var report: Dictionary = {}
var page := 0
var _armed := false
var _pages: Array = []


func _ready() -> void:
	super._ready()
	hide()


func show_report(value: Dictionary) -> void:
	report = value
	page = 0
	_armed = false
	_pages = [[]]
	var y := 90
	for entry in report.lines:
		_append_line("%s: %d" % [String(entry.name).to_upper(), entry.count], y)
		y += 9
		if y > 181:
			_pages.append([])
			y = 30
		if not entry.contents.is_empty():
			_append_line("CONTAINING %d %s" % [entry.quantity, entry.contents], y)
			y += 9
			if y > 181:
				_pages.append([])
				y = 30
	if _pages[-1].is_empty() and _pages.size() > 1:
		_pages.pop_back()
	show()
	queue_redraw()


func _append_line(value: String, y: int) -> void:
	_pages[-1].append({"text": value, "y": y})


func _draw() -> void:
	frame()
	if report.is_empty():
		return
	begin_canvas()
	text_at(Vector2(38, 13), "DAY %d" % report.day)
	text_at(Vector2(125, 13), "INVENTORY")
	text_at(Vector2(254, 13), "PAGE %d" % (page + 1))
	if page == 0:
		text_at(Vector2(38, 31), "NUMBER OF WAGONS: %d" % report.wagon_count)
		text_at(Vector2(38, 40), "NO WAGONS DESTROYED" if report.destroyed == 0 else "DESTROYED WAGONS: %d" % report.destroyed)
		text_at(Vector2(38, 50), "PTAV: %d" % report.ptav)
		text_at(Vector2(38, 59), "PTAC: %d" % report.ptac)
		text_at(Vector2(38, 69), "TENDER CAPACITY: %d" % report.tender_capacity)
		text_at(Vector2(38, 79), "PRESENT CONTENTS: %d" % report.present_contents)
	for line in _pages[page]:
		text_at(Vector2(38, line.y), line.text)
	draw_set_transform(Vector2.ZERO)


func next_page() -> void:
	if page + 1 < _pages.size():
		page += 1
		queue_redraw()
	else:
		closed.emit()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_armed = true
		elif _armed:
			_armed = false
			next_page()
		accept_event()
