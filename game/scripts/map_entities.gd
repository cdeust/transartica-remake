extends RefCounted

const Enemies = preload("res://scripts/enemy_trains.gd")
const Wagons = preload("res://scripts/train_wagons.gd")
const Rails = preload("res://scripts/rail_network.gd")
const Art = preload("res://scripts/ecs_panel_art.gd")
const MAP_ART := "res://../reference-private/map-resources.json"
var art = Art.new()
var _loaded := false


# GLIEU 0x27c3..2832: only state < 3 contributes; type4 outranks type10.
# CARTE 0x305..34f: inclusive square, not Euclidean distance or saved fog.
static func observation_radius(wagons) -> int:
	var radius := 1
	if wagons != null:
		for wagon in wagons.wagons:
			if wagon[Wagons.STATE] >= 3:
				continue
			if wagon[Wagons.TYPE] == 4:
				return 4
			if wagon[Wagons.TYPE] == 10:
				radius = 2
	return radius


static func visible_enemies(enemies, position: Vector2i, wagons) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if enemies == null:
		return result
	var radius := observation_radius(wagons)
	for slot in Enemies.SLOT_COUNT:
		if not enemies.is_active(slot):
			continue
		var cell: Vector2i = enemies.cell(slot)
		var delta := cell - position
		if absi(delta.x) <= radius and absi(delta.y) <= radius:
			result.append({"slot": slot, "cell": cell, "heading": int(enemies.slots[slot][Enemies.HEADING])})
	return result


func draw_city_tile(view, cell: Vector2i, code: int) -> bool:
	if not _loaded:
		art.load_private(MAP_ART)
		_loaded = true
	var texture: Texture2D = art.textures.get(str(absi(code)))
	if texture == null:
		return false
	# CARTE cdefmap0x128:16px cells; retain resource size and tile origin.
	var origin: Vector2 = view._world_to_screen(Vector2(cell))
	var cell_size: float = (view._world_to_screen(Vector2.RIGHT) - view._world_to_screen(Vector2.ZERO)).length()
	view.draw_texture_rect(texture, Rect2(origin, texture.get_size() * cell_size / 16.0), false)
	return true


func draw(view) -> void:
	_draw_cities(view)
	if view.encounters == null or view.journey == null:
		return
	# Read live owner each frame: restore replaces encounters.enemies.
	var frame: Dictionary = view.train_renderer.frame_for("locomotive")
	if frame.is_empty():
		return
	var scale: float = view.train_renderer.texel_scale(view)
	for enemy in visible_enemies(view.encounters.enemies, view.journey.position, view.wagons):
		var center: Vector2 = view._world_to_screen(Vector2(enemy.cell) + Vector2(0.5, 0.5))
		var direction: Vector2 = Vector2(Rails.DELTAS.get(enemy.heading, Vector2i.ZERO))
		var angle := direction.angle() - PI * 0.5
		view.draw_set_transform_matrix(view.train_renderer.registration(frame, center, angle, scale))
		# One locomotive symbol: no inferred enemy consist, troop count or strength.
		view.train_renderer.draw_frame(view, frame, Color.WHITE)
	view.draw_set_transform_matrix(Transform2D.IDENTITY)


func _draw_cities(view) -> void:
	if view.world_data == null:
		return
	var occupied: Array[Rect2] = []
	for index in view.world_data.cities.size():
		var city: Dictionary = view.world_data.cities[index]
		var cell := Vector2i(city.x, city.y)
		var center: Vector2 = view._city_screen_point(city)
		if not Rect2(Vector2.ZERO, view.size).has_point(center):
			continue
		var code: int = view._tile_code(cell.x, cell.y)
		if not draw_city_tile(view, cell, code):
			# Explicit authored fallback until private original resources are supplied.
			view._draw_town_sprite(center, index == view.selected_city)
		if index == view.selected_city:
			view._draw_selected_city(center, String(city.name))
		elif Rect2(Vector2.ZERO, view.size).has_point(center):
			view._draw_city_label(center, String(city.name), occupied)


func draw_player_heading(view) -> void:
	if view.journey == null:
		return
	# Owner visibility contract; native raw10361 measured665/1232 hero pixels
	# covered by the old cue. Use the same drawn convoy bounds, including lag.
	var direction := Vector2(Rails.DELTAS.get(view.journey.heading, Vector2i.ZERO)).normalized()
	if direction == Vector2.ZERO:
		return
	var center: Vector2 = view._world_to_screen(view._visual_position + Vector2(0.5, 0.5))
	var heading: String = preload("res://scripts/train_journey.gd").HEADING_NAMES.get(view.journey.heading,"")
	var caption := "%s · %s" % ["REVERSE" if view.journey.reverse else "FORWARD",heading]
	var font := ThemeDB.fallback_font
	var extent := font.get_string_size(caption,HORIZONTAL_ALIGNMENT_LEFT,-1,14)
	var lag: float = maxf(0,view.journey.distance_travelled()-view._visual_arc) if view._visual_initialized else 0.0
	var occupied: Rect2 = view.train_renderer.screen_bounds(view,view.journey,view.consist,lag)
	var layout: Dictionary = heading_overlay_layout(center,direction,extent,occupied,Rect2(Vector2.ZERO,view.size))
	if not layout.points.is_empty():
		view.draw_polyline(layout.points, Color("#17242b"), 7.0, true)
		view.draw_polyline(layout.points, Color("#ffe4a5"), 3.0, true)
	var label: Rect2 = layout.label
	if label.has_area():
		view.draw_rect(label,Color("#17242b"))
		view.draw_string(font,label.position+Vector2(4,font.get_ascent(14)+3),caption,HORIZONTAL_ALIGNMENT_LEFT,-1,14,Color("#ffe4a5"))


static func heading_overlay_layout(center: Vector2, direction: Vector2, extent: Vector2, occupied: Rect2, viewport: Rect2) -> Dictionary:
	# Keep the existing authored cue dimensions/gap; translate only the overlay.
	var tip := center + direction * 32.0
	var side := direction.orthogonal()
	var points := PackedVector2Array([tip-direction*12.0+side*7.0,tip,tip-direction*12.0-side*7.0])
	var arrow := Rect2(points[0],Vector2.ZERO)
	for point in points: arrow=arrow.expand(point)
	arrow=arrow.grow(7.0) # Existing outer stroke, conservatively include antialiasing.
	var safe_arrow := _clear_overlay_box(arrow,occupied,viewport)
	if safe_arrow.has_area():
		var shift := safe_arrow.position-arrow.position
		for index in points.size(): points[index]+=shift
	else:
		points=PackedVector2Array()
	var anchor := tip-Vector2(extent.x*0.5,extent.y+24.0)
	if absf(direction.y)>absf(direction.x): anchor=tip+Vector2(24.0,-extent.y*0.5)
	var label := _clear_overlay_box(Rect2(anchor,extent+Vector2(8,6)),occupied,viewport)
	return {"points":points,"arrow":safe_arrow,"label":label}


static func _clear_overlay_box(preferred: Rect2, occupied: Rect2, viewport: Rect2) -> Rect2:
	if preferred.size.x>viewport.size.x or preferred.size.y>viewport.size.y: return Rect2()
	var candidates: Array[Vector2] = [preferred.position]
	if occupied.has_area():
		# Existing24px caption gap is shared by the arrow to separate the cue
		# from the drawn convoy; no change to vehicle geometry or camera.
		candidates.append(Vector2(occupied.position.x-preferred.size.x-24.0,preferred.position.y))
		candidates.append(Vector2(occupied.end.x+24.0,preferred.position.y))
		candidates.append(Vector2(preferred.position.x,occupied.position.y-preferred.size.y-24.0))
		candidates.append(Vector2(preferred.position.x,occupied.end.y+24.0))
	for corner in [viewport.position,Vector2(viewport.end.x-preferred.size.x,viewport.position.y),viewport.end-preferred.size,Vector2(viewport.position.x,viewport.end.y-preferred.size.y)]:
		candidates.append(corner)
	var best := Rect2()
	var distance := INF
	for candidate in candidates:
		var rect := Rect2(candidate.clamp(viewport.position,viewport.end-preferred.size),preferred.size)
		if occupied.has_area() and rect.intersects(occupied): continue
		var travel := rect.position.distance_squared_to(preferred.position)
		if travel<distance:
			best=rect
			distance=travel
	# No overlay can fit when the occupied bounds cover the viewport. Leave
	# the separate direction instrument visible rather than painting the train.
	return best
