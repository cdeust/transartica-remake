extends RefCounted

# MIT. CARTE resources65..151 inspected in tasks/evidence/world-terrain.md.
# All pixels are newly authored by build_travel_terrain.py, never reference copies.
const ART_ROOT := "res://assets/travel/terrain/" # source: authored asset directory.
const CELL_ART_PIXELS := 96.0 # source: authored raster-cell size in build_travel_terrain.py.
var textures: Dictionary = {}


func load_art() -> bool:
	textures.clear()
	for code in range(65, 152):
		var path := ART_ROOT + str(code) + ".png"
		if ResourceLoader.exists(path):
			textures[code] = load(path) as Texture2D
	return not textures.is_empty()


static func resource_code(code: int) -> int:
	# CARTE.FIC byte resource number, not the absolute signed traversal code.
	return code + 256 if code < -104 else absi(code)


func draw_tile(view, cell: Vector2i, code: int) -> bool:
	var texture: Texture2D = textures.get(resource_code(code))
	if texture == null:
		return false
	var origin: Vector2 = view._world_to_screen(Vector2(cell))
	var extent: Vector2 = view._world_to_screen(Vector2(cell) + Vector2.ONE) - origin
	view.draw_texture_rect(texture, Rect2(origin, extent), false)
	return true


func draw(view) -> void:
	if view.world_data == null:
		return
	var cells: Rect2i = view._visible_world_bounds()
	for x in range(maxi(0, cells.position.x), mini(view.WorldDataScript.MAP_WIDTH, cells.end.x)):
		for y in range(maxi(0, cells.position.y), mini(view.WorldDataScript.MAP_HEIGHT, cells.end.y)):
			if view._cell_is_visible(x, y):
				draw_tile(view, Vector2i(x, y), view._tile_code(x, y))
