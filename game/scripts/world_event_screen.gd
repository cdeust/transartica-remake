extends "res://scripts/original_screen.gd"

# MIT. Mine question TEXTEK72 and plaque71, YODA scene-22; scene2 works74..76.
# Authored scene geometry and palette, not original assets or gameplay constants.
const Backdrop = preload("res://scripts/city_backdrop.gd")

signal answer_requested(accept: bool)
signal dismissed

var mode := "mine"
var question := true
var _mine_phase := ""
var report: Dictionary = {}
var lines: Array = []
var _scene: Texture2D
var ambience = preload("res://scripts/worksite_ambience.gd").new()


func _ready() -> void:
	super._ready()
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	hide()


func open_mine(details: Dictionary) -> void:
	report = details.duplicate()
	_mine_phase = ""
	mode = "mine"
	question = true
	lines = ["YOU COME ACROSS A MINE", "PROSPECT?"]
	_load_scene()
	show()
	queue_redraw()


func show_mine() -> void:
	question = false
	lines = ["%s MINE OF THE YEAR %d" % [report.ore, report.year], "WEALTH INDEX: %d" % report.wealth]
	queue_redraw()


# Text72 plaque,41 available resources,42 result. Source TEXTEK click464c.
func show_mine_phase(world) -> void:
	_mine_phase = world.mine_phase
	show_mine()
	if world.mine_phase == "resources":
		lines = ["AVAILABLE RESOURCES:", "%d SLAVE(S)" % world.mine_resources.slaves,
			"%d MAMMOTH(S)  %d CRANE(S)" % [world.mine_resources.mammoths,world.mine_resources.cranes]]
	elif world.mine_phase == "result":
		lines = ["RESULT OF WORKINGS", "%d BAKS OF %s" % [world.mine_quantity,report.ore]]
	queue_redraw()


func open_works(work_kind: String, text_lines: Array, is_question: bool) -> void:
	mode = work_kind
	question = is_question
	lines = text_lines.duplicate()
	_load_scene()
	show()
	queue_redraw()


func _load_scene() -> void:
	ambience.clear()
	var name := "mine" if mode == "mine" else "track-works"
	var path := "res://assets/world-events/" + name + ".png"
	_scene = load(path) as Texture2D if ResourceLoader.exists(path) else null


func _physics_process(delta: float) -> void:
	# Roamer subclasses draw different plates and have no worksite emitters.
	if not visible or mode in ["nomads","mammoth-hunt"]: return
	var app = get_parent()
	if app != null and app.get("_boudoir_session") != null and app._boudoir_session.reception.visible:
		return
	# Owner5Oct: mine information screens do not display worksite plumes.
	var working: bool = not question and (mode != "mine" or _mine_phase == "result")
	var accepted: Variant = get("_ok_result")
	if accepted != null: working = accepted and int(get("countdown")) > 0
	ambience.advance(delta,mode,working)
	queue_redraw()


func _draw() -> void:
	begin_canvas()
	draw_rect(Rect2(0,0,320,149), Color("#0c1d27"))
	if _scene != null:
		_draw_scene(Rect2(0,39,320,110))
	draw_style_box(Backdrop.border(Color("#142d39"), GOLD), Rect2(1,1,318,37))
	var first_y: int = 11 if lines.size() > 2 else 15
	for index in lines.size():
		centered(first_y + index * 8, str(lines[index]), 6)
	# source: original TEXTEK resource11 NO(left)/OK(right), click zones y6..18
	# in its bottom-origin coordinates. Authored banner retains those two roles.
	if question:
		_draw_button(Rect2(120,124,32,14), "NO")
	_draw_button(Rect2(170,124,32,14), "OK")


func _draw_scene(box: Rect2) -> void:
	draw_texture_rect(_scene, box, false)
	ambience.draw(self,mode)


func _draw_button(box: Rect2, value: String) -> void:
	draw_style_box(Backdrop.border(Color("#3c3429"), GOLD), box)
	text_at(box.position + Vector2(7,10), value, 6)


func _gui_input(event: InputEvent) -> void:
	if not event is InputEventMouseButton or event.button_index != MOUSE_BUTTON_LEFT or not event.pressed:
		return
	var point := logical_point(event.position)
	if question and Rect2(120,124,32,14).has_point(point):
		answer_requested.emit(false)
	elif Rect2(170,124,32,14).has_point(point):
		if question:
			answer_requested.emit(true)
		else:
			dismissed.emit()
	accept_event()


func _has_point(point: Vector2) -> bool:
	return Rect2(0,0,320,149).has_point(logical_point(point))
