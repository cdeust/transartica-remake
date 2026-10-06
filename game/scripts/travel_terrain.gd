extends RefCounted

# MIT. CARTE resources65..151 inspected in tasks/evidence/world-terrain.md.
# Pixels are newly authored terrain rasters and imagegen masters, never reference copies.
const ART_ROOT := "res://assets/travel/terrain/" # source: authored asset directory.
const CELL_ART_PIXELS := 96.0 # source: authored raster-cell size in build_travel_terrain.py.
var textures: Dictionary = {}
var forest: Texture2D
var mountains: Texture2D
var water = preload("res://scripts/terrain_water_art.gd").new()
var landmarks = preload("res://scripts/terrain_landmarks.gd").new()
var obstacles = preload("res://scripts/terrain_obstacles.gd").new()
var portals = preload("res://scripts/terrain_portals.gd").new()
var artwork = preload("res://scripts/world_artwork.gd").new()


func load_art() -> bool:
	textures.clear()
	artwork.load_art()
	landmarks.load_art()
	obstacles.load_art()
	portals.load_art()
	water.load_art()
	forest = load(ART_ROOT + "forest-master.png") as Texture2D
	mountains = load(ART_ROOT + "mountains-master.png") as Texture2D
	for code in range(65, 152):
		var path := ART_ROOT + str(code) + ".png"
		if ResourceLoader.exists(path):
			textures[code] = load(path) as Texture2D
	return not textures.is_empty()


static func resource_code(code: int) -> int:
	# CARTE.FIC byte resource number, not the absolute signed traversal code.
	return code + 256 if code < -104 else absi(code)


func draw_tile(view, cell: Vector2i, code: int) -> bool:
	var resource := resource_code(code)
	if "cover" in view and view.cover != null and view.cover.handles_mouth(cell,code): return true
	if portals.draw_tile(view,cell,code):
		return true
	var origin: Vector2 = view._world_to_screen(Vector2(cell))
	var extent: Vector2 = view._world_to_screen(Vector2(cell) + Vector2.ONE) - origin
	if obstacles.draw_tile(view,cell,code):
		return true
	if landmarks.draw_tile(view,cell,resource,Rect2(origin,extent)):
		return true
	# Painted relief replaces generic forest/mountain cells; exact water stays live.
	if artwork.available() and artwork.covers_relief(cell,resource):
		return true
	var texture: Texture2D = textures.get(resource)
	if texture == null:
		return false
	var atlas: Texture2D
	if resource >= 116 and resource <= 132:
		atlas = forest
	elif (resource >= 86 and resource <= 105) or resource in [142,143,144,145,146]:
		atlas = mountains
	if atlas != null:
		# Source: authored1536x1024 terrain masters, six equal512px cells.
		# Variants and offsets are presentation only; source geography is fixed.
		var index := posmod(resource+cell.x+cell.y*3,6)
		var source_size := atlas.get_size() / Vector2(3,2)
		var source := Rect2(Vector2(index%3,index/3)*source_size,source_size)
		var offset := Vector2(posmod(cell.x,3)-1,posmod(cell.y,3)-1)*extent*0.025 # source: authored quarter-pixel offset at ten-pixel tile zoom.
		view.draw_texture_rect_region(atlas,Rect2(origin+offset,extent),source)
		return true
	texture = water.texture_for(texture,resource,cell)
	view.draw_texture_rect(texture, Rect2(origin, extent), false)
	return true


func draw(view) -> void:
	if view.world_data == null:
		return
	artwork.draw_travel(view)
	var cells: Rect2i = view._visible_world_bounds()
	# Authored towns span source3x2 cells; include offscreen origins whose art is visible.
	cells.position -= Vector2i(2,1)
	cells.size += Vector2i(2,1)
	var visible:=cells.intersection(Rect2i(0,0,view.WorldDataScript.MAP_WIDTH,view.WorldDataScript.MAP_HEIGHT))
	water.begin_frame(visible.get_area())
	for x in range(maxi(0, cells.position.x), mini(view.WorldDataScript.MAP_WIDTH, cells.end.x)):
		for y in range(maxi(0, cells.position.y), mini(view.WorldDataScript.MAP_HEIGHT, cells.end.y)):
			if view._cell_is_visible(x, y):
				draw_tile(view, Vector2i(x, y), view._tile_code(x, y))
