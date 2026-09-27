extends RefCounted

# Private YODA resources, decoded by tools/export_panel_resources.py.
# Source: YODA0x3c7,0x732,0x1979 and0x2fc3; panel-layout.md.
const PATH := "res://../reference-private/panel-resources.json"
var resources := {}
var textures := {}
var available := false
var first_wagon := 0


func load_private(path: String = PATH) -> bool:
	if not FileAccess.file_exists(path):
		return false
	var data = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not data is Dictionary or data.get("version") != 1 or not data.get("resources") is Dictionary:
		return false
	resources = data.resources
	for key in resources:
		var entry: Dictionary = resources[key]
		if int(entry.kind) == 255:
			continue
		var pixels := Image.create(int(entry.width), int(entry.height), false, Image.FORMAT_RGBA8)
		for y in int(entry.height):
			for x in int(entry.width):
				var index := String(entry.pixels)[y * int(entry.width) + x].hex_to_int()
				var rgb: Array = data.palette[index]
				pixels.set_pixel(x, y, Color(float(rgb[0]) / 255, float(rgb[1]) / 255, float(rgb[2]) / 255,
					0.0 if int(entry.kind) == 0 and index == 0 else 1.0))
		textures[key] = ImageTexture.create_from_image(pixels)
	available = textures.has("0") and resources.has("5")
	return available


func _parts(index: int, x := 0, depth := 0, z := 0, flip := false) -> Array:
	var entry: Dictionary = resources[str(index)]
	if int(entry.kind) != 255:
		return [{"index": index, "x": x, "z": z, "depth": depth, "flip": flip}]
	var result: Array = []
	for part in entry.parts:
		var element := int(part[0])
		result.append_array(_parts(element & 32767, x + int(part[1]) * (-1 if flip else 1),
			depth + int(part[2]), z + int(part[3]), flip != (element < 0)))
	return result


func sprite(panel, index: int, x := 0, z := 0) -> void:
	var parts := _parts(index, x, 0, z)
	parts.sort_custom(func(a, b): return a.depth > b.depth)
	for part in parts:
		var texture: Texture2D = textures[str(part.index)]
		var extent := texture.get_size()
		var left := Vector2(part.x - ((int(extent.x) - 1) >> 1), 199 - part.z - ((int(extent.y) - 1) >> 1))
		var rect: Rect2 = panel.screen_rect(Rect2(left, extent))
		if part.flip:
			rect.size.x = -rect.size.x
		panel.draw_texture_rect(texture, rect, false)


func draw(panel) -> void:
	sprite(panel, 5)
	sprite(panel, (90 if panel.overview_context else 56) if panel.map_context else 57)
	if panel.app == null:
		return
	var app = panel.app
	sprite(panel, 20 + app.calendar.hour % 12)
	sprite(panel, 32 + app.calendar.minute / 5)
	# YODA0x7a4: launcher icon is covered until the launcher wagon is bought.
	if not app.wagons.wagons.any(func(w): return int(w[0]) == 13):
		sprite(panel, 91)
	if panel.map_context and app.engine.brake:
		sprite(panel, 120)
	_draw_composition(panel)


func wagon_width(wagon: Array) -> int:
	# YODA0x1a90: the short wagon types are explicitly listed.
	return 27 if int(wagon[0]) in [5, 10, 17, 21, 23, 25] else 33


func _draw_composition(panel) -> void:
	var wagons: Array = panel.app.wagons.wagons
	first_wagon = clampi(first_wagon, 0, wagons.size() - 1)
	var right := 300
	for index in range(first_wagon, wagons.size()):
		var wagon: Array = wagons[index]
		var width := wagon_width(wagon)
		if int(wagon[1]) == 3:
			width = 32
		var center := right - width / 2
		sprite(panel, 122 if int(wagon[1]) == 3 else 92 + int(wagon[0]) - 1, center, 45)
		if int(wagon[1]) == 1:
			sprite(panel, 121, center, 45)
		elif int(wagon[1]) == 2:
			sprite(panel, 121, center - 7, 45)
			sprite(panel, 121, center + 7, 45)
		right -= width
		if right < 14:
			break


func scroll(panel, logical: Vector2) -> bool:
	if logical.y < 149 or logical.y > 158 or panel.app == null:
		return false
	if logical.x > 304:
		first_wagon = maxi(0, first_wagon - 1)
	elif logical.x < 14:
		var width := 0
		for index in range(first_wagon, panel.app.wagons.count()):
			width += wagon_width(panel.app.wagons.wagons[index])
		if width > 286:
			first_wagon += 1
	else:
		return false
	panel.queue_redraw()
	return true
