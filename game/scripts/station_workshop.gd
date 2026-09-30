extends "res://scripts/original_screen.gd"

# MIT. GLIEU0x21ea..2b10: named station, action banner, clickable train strip,
# wagon card and confirmation. Existing authored city and wagon art is reused.
const Renderer = preload("res://scripts/train_renderer.gd")
const Consist = preload("res://scripts/train_consist.gd")
const Backdrop = preload("res://scripts/city_backdrop.gd")
# source: GLIEU0x23a3 choice codes; decoded ECS menu order.
const ACTIONS := {50: "MOVE", 51: "WAGON", 52: "REPAIR", 53: "REMOVE"}
# source: authored banner/painting layout follows GLIEU y45 train strip and city39..149.
const STRIP := Rect2(20, 40, 280, 24)
const CELL_WIDTH := 28
const MENU := Rect2(20, 22, 280, 15)

signal depart_requested
signal cargo_changed

var management
var trade
var title := ""
var selected := -1
var action := 51
var scroll := 0
var moving := -1
var confirmation := false
var notice := ""
var renderer = Renderer.new()
var _background: Texture2D


func _ready() -> void:
	super._ready()
	renderer.load_assets()
	_background = load("res://assets/cities/city-industrial-workshop.png") as Texture2D
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	hide()


func open(at: Vector2i) -> void:
	title = management.station_name(at)
	selected = -1
	scroll = 0
	moving = -1
	confirmation = false
	notice = ""
	show()
	queue_redraw()


func _draw() -> void:
	begin_canvas()
	draw_rect(Rect2(0, 0, 320, 149), Color("#10212b"))
	if _background != null:
		draw_texture_rect(_background, Rect2(0, 39, 320, 110), false)
	draw_rect(Rect2(0, 39, 320, 110), Color(0.02, 0.06, 0.09, 0.68))
	draw_style_box(Backdrop.border(Color("#162e39"), GOLD), Rect2(1, 1, 318, 19))
	centered(14, title, 8)
	for code in ACTIONS:
		var slot: int = int(code) - 50
		var box := Rect2(MENU.position + Vector2(slot * 56, 0), Vector2(55, 15))
		draw_style_box(Backdrop.border(Color("#574632") if action == code else Color("#233a42"), GOLD), box)
		text_at(box.position + Vector2(3, 11), ACTIONS[code], 6)
	text_at(Vector2(249, 33), "EXIT", 6)
	_draw_train()
	_draw_card()
	centered(144, notice, 6)


func _draw_train() -> void:
	text_at(Vector2(5, 55), "‹", 9)
	text_at(Vector2(306, 55), "›", 9)
	for slot in range(scroll, mini(scroll + 10, management.wagons.count())):
		var box := Rect2(STRIP.position + Vector2((slot - scroll) * CELL_WIDTH, 0), Vector2(CELL_WIDTH - 1, STRIP.size.y))
		draw_style_box(Backdrop.border(Color("#3b4850") if slot == selected else Color("#152b34"), GOLD if slot == selected else Color("#4d8493")), box)
		var kind: String = Consist.TYPE_TO_KIND[management.wagons.wagons[slot][0]]
		_draw_wagon(kind, box.get_center(), Vector2(24, 17))


func _draw_wagon(kind: String, center: Vector2, extent: Vector2) -> void:
	var wagon: Dictionary = renderer.frame_for(kind)
	if wagon.is_empty():
		return
	var texture: Texture2D = wagon.texture
	var factor := minf(extent.x / texture.get_height(), extent.y / texture.get_width())
	var canvas := canvas_rect()
	var canvas_scale := canvas.size.x / CANVAS.x
	draw_set_transform(canvas.position + center * canvas_scale, -PI / 2, Vector2.ONE * factor * canvas_scale)
	draw_texture(texture, -texture.get_size() / 2)
	begin_canvas()


func _draw_card() -> void:
	if selected < 0 or selected >= management.wagons.count():
		centered(101, "SELECT A WAGON IN THE TRAIN", 7)
		return
	var wagon: Array = management.wagons.wagons[selected]
	var kind: String = Consist.TYPE_TO_KIND[wagon[0]]
	_draw_wagon(kind, Vector2(82, 96), Vector2(115, 58))
	text_at(Vector2(150, 79), trade.wagon_name(wagon[0]), 7)
	text_at(Vector2(150, 92), "TARE: %d   STATE: %d" % [management.wagons.BASE_WEIGHT[wagon[0] - 1], wagon[1]], 6)
	var cargo: String = trade.goods_name(wagon[2]) if wagon[2] > 0 else ""
	text_at(Vector2(150, 105), "TRANSPORT: %d %s" % [wagon[3], cargo], 6)
	if confirmation:
		centered(124, "REPAIR: %d LIGNITE" % management.repair_price(selected) if action == 52 else "REMOVE THIS WAGON?", 6)
		text_at(Vector2(120, 137), "NO", 6)
		text_at(Vector2(180, 137), "OK", 6)


func choose_wagon(index: int) -> void:
	if index < 0 or index >= management.wagons.count():
		return
	if moving >= 0:
		management.move(moving, index)
		moving = -1
		action = 51 # source: GLIEU0x26be resets choice after the completed action.
		cargo_changed.emit()
	selected = index
	confirmation = false
	notice = ""
	if action == 50:
		moving = index
		notice = "SELECT THE DESTINATION WAGON"
	elif action in [52, 53]:
		var refusal: int = management.repair_refusal(index) if action == 52 else management.remove_refusal(index)
		confirmation = refusal == 0
		if refusal != 0:
			notice = {35: "THIS WAGON IS UNDAMAGED", 50: "NOT ENOUGH LIGNITE", 87: "THIS WAGON IS DESTROYED", 88: "YOU CANNOT REMOVE THIS WAGON"}.get(refusal, "")
	queue_redraw()


func confirm(accept: bool) -> void:
	if not confirmation:
		return
	var changed: bool = management.repair(selected, accept) if action == 52 else management.remove(selected, accept)
	confirmation = false
	if changed:
		selected = -1
		cargo_changed.emit()
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if not event is InputEventMouseButton or event.button_index != MOUSE_BUTTON_LEFT or not event.pressed:
		return
	var point := logical_point(event.position)
	if confirmation and point.y >= 124 and point.y < 141:
		confirm(point.x >= 170 and point.x <= 202)
	elif MENU.has_point(point):
		var slot := int((point.x - MENU.position.x) / 56)
		if slot == 4:
			depart_requested.emit()
		else:
			action = slot + 50
			moving = -1
			confirmation = false
	elif STRIP.has_point(point):
		choose_wagon(scroll + int((point.x - STRIP.position.x) / CELL_WIDTH))
	elif point.y >= 40 and point.y <= 64:
		scroll = clampi(scroll + (1 if point.x > 300 else -1), 0, maxi(0, management.wagons.count() - 10))
	queue_redraw()
	accept_event()


func _has_point(point: Vector2) -> bool:
	var logical := logical_point(point)
	return Rect2(0, 0, 320, 149).has_point(logical)
