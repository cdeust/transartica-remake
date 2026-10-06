extends RefCounted
# MIT. Owner6Oct finite authored master; tasks/evidence/world-artwork-20261006.md.
# Source registration: CARTE160x73, ECSOverview.map_point/CARTE1ece.
const Data = preload("res://scripts/world_data.gd")
const PATH := "res://assets/travel/terrain/world-artwork.png"
const REGISTRATION_PATH := "res://assets/travel/terrain/world-registration.json"
var texture: Texture2D
var regions: Array[Dictionary] = []
var layer: Control
var master_rect: TextureRect
var regional_rects: Array[TextureRect] = []
const FEATHER_PIXELS := 16.0 # source: owner6Oct authored regional edge transition.
const EDGE_SHADER := "shader_type canvas_item; uniform vec2 image_size; uniform float feather_pixels; void fragment(){ vec2 edge=min(UV,vec2(1.0)-UV)*image_size; COLOR.a*=smoothstep(0.0,feather_pixels,min(edge.x,edge.y)); }" # source: owner6Oct edge alpha over unchanged master.
# Owner6Oct art subdivision: four columns/two rows, independent of game rules.
const REGION_COLUMNS := 4 # source: owner6Oct regional artwork grid, world-artwork-20261006.
const REGION_ROWS := 2 # source: owner6Oct regional artwork grid, world-artwork-20261006.

func load_art(with_regions: bool = true) -> bool:
	if is_instance_valid(layer): layer.queue_free()
	layer = null
	texture = load(PATH) as Texture2D if ResourceLoader.exists(PATH) else null
	regions.clear()
	if not with_regions: return available()
	var registration = JSON.parse_string(FileAccess.get_file_as_string(REGISTRATION_PATH)) if FileAccess.file_exists(REGISTRATION_PATH) else null
	for index in REGION_COLUMNS*REGION_ROWS:
		var path := "res://assets/travel/terrain/world-region-%d.png" % index
		if ResourceLoader.exists(path):
			var regional := load(path) as Texture2D
			if regional != null:
				var mask := _registered_mask(registration,index,regional)
				regions.append({"texture":regional,"world":region_rect(index),"mask":mask,"index":index})
	return available()

static func _registered_mask(document,index: int,image_texture: Texture2D) -> String:
	if index < 0 or index >= REGION_COLUMNS*REGION_ROWS: return ""
	if not document is Dictionary or document.get("schema") != 1 or not document.get("regions") is Array: return ""
	var entries: Array = document.regions
	if entries.size() != REGION_COLUMNS*REGION_ROWS or not entries[index] is Dictionary: return ""
	var entry: Dictionary = entries[index]
	if not _measured(entry): return ""
	var rows := int((index/REGION_COLUMNS+1)*extent().y/REGION_ROWS)-int((index/REGION_COLUMNS)*extent().y/REGION_ROWS)
	if entry.get("index") != index or not _size_matches(entry.get("grid_size"),Vector2i(40,rows)): return ""
	var mask = entry.get("dark_mask")
	if not mask is String or mask.length() != 40*rows or mask.replace("0","").replace("1","") != "": return ""
	if not _size_matches(entry.get("size"),Vector2i(image_texture.get_width(),image_texture.get_height())): return ""
	var hash := texture_hash(image_texture)
	if hash.is_empty() or entry.get("rgba_sha256") != hash: return ""
	return mask

static func _measured(entry: Dictionary) -> bool:
	for key in ["corr_master","relief_iou","chance"]:
		if typeof(entry.get(key)) not in [TYPE_INT,TYPE_FLOAT]: return false
	# source: Claude6Oct supplied correlation criterion and above-chance relief test.
	return entry.corr_master >= 0.5 and entry.corr_master <= 1 and entry.relief_iou > entry.chance and entry.relief_iou <= 1 and entry.chance >= 0

static func _size_matches(value,expected: Vector2i) -> bool:
	if not value is Array or value.size() != 2: return false
	return typeof(value[0]) in [TYPE_INT,TYPE_FLOAT] and typeof(value[1]) in [TYPE_INT,TYPE_FLOAT] and value[0] == expected.x and value[1] == expected.y

static func texture_hash(image_texture: Texture2D) -> String:
	var image := image_texture.get_image()
	if image == null or image.is_empty(): return ""
	if image.is_compressed() and image.decompress() != OK: return ""
	image.convert(Image.FORMAT_RGBA8)
	var hash := HashingContext.new()
	hash.start(HashingContext.HASH_SHA256)
	hash.update(image.get_data())
	return hash.finish().hex_encode()

func covers_relief(cell: Vector2i,resource: int) -> bool:
	# Coarse registered relief only; the dark classifier cannot distinguish trees/rock.
	if not ((resource >= 86 and resource <= 105) or (resource >= 116 and resource <= 132) or resource in [142,143,144,145,146]): return false
	for region in regions:
		var mask: String = region.get("mask","")
		if mask.is_empty(): continue
		var world: Rect2 = region.world
		var feather: Vector2 = Vector2.ONE*FEATHER_PIXELS/region.texture.get_size()*world.size
		var solid := Rect2(world.position+feather,world.size-2*feather)
		if not solid.encloses(Rect2(Vector2(cell),Vector2.ONE)): continue
		var index: int = region.index
		var y0 := int((index/REGION_COLUMNS)*extent().y/REGION_ROWS)
		var pixel := (cell.y-y0)*40+cell.x-int(world.position.x)
		return pixel >= 0 and pixel < mask.length() and mask[pixel] == "1"
	return false

func available() -> bool:
	return texture != null

static func extent() -> Vector2:
	return Vector2(Data.MAP_WIDTH,Data.MAP_HEIGHT)

static func travel_rect(view) -> Rect2:
	var origin: Vector2 = view._world_to_screen(Vector2.ZERO)
	return Rect2(origin,view._world_to_screen(extent())-origin)

static func overview_rect() -> Rect2:
	return Rect2(Vector2(2,3),extent()*2) # CARTE1ece: (2*x+2,2*y+3).

static func region_rect(index: int) -> Rect2:
	var size := extent()/Vector2(REGION_COLUMNS,REGION_ROWS)
	return Rect2(Vector2(index%REGION_COLUMNS,index/REGION_COLUMNS)*size,size)

func draw_travel(view) -> bool:
	if not available(): return false
	if view is Control and not view.discovery_enabled:
		_draw_layer(view)
		return true
	if is_instance_valid(layer): layer.hide()
	_draw_registered(view,texture,Rect2(Vector2.ZERO,extent()))
	var visible: Rect2i = view._visible_world_bounds()
	var visible_rect := Rect2(Vector2(visible.position),Vector2(visible.size))
	for region in regions:
		if visible_rect.intersects(region.world):
			_draw_registered(view,region.texture,region.world)
	return true

func _draw_layer(view: Control) -> void:
	if not is_instance_valid(layer):
		_make_layer()
		_attach_layer.call_deferred(view)
	layer.show()
	_set_rect(master_rect,view,Rect2(Vector2.ZERO,extent()))
	var visible: Rect2i = view._visible_world_bounds()
	var bounds := Rect2(Vector2(visible.position),Vector2(visible.size))
	for index in regional_rects.size():
		var rect := regional_rects[index]
		rect.visible = bounds.intersects(regions[index].world)
		_set_rect(rect,view,regions[index].world)

func _make_layer() -> void:
	layer = Control.new()
	layer.name = "WorldArtwork"
	layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.show_behind_parent = true
	master_rect = _image_rect(texture)
	layer.add_child(master_rect)
	regional_rects.clear()
	var shader := Shader.new()
	shader.code = EDGE_SHADER
	for region in regions:
		var rect := _image_rect(region.texture)
		var material := ShaderMaterial.new()
		material.shader = shader
		material.set_shader_parameter("image_size",region.texture.get_size())
		material.set_shader_parameter("feather_pixels",FEATHER_PIXELS)
		rect.material = material
		layer.add_child(rect)
		regional_rects.append(rect)

func _attach_layer(view: Control) -> void:
	if not is_instance_valid(view):
		if is_instance_valid(layer) and layer.get_parent() == null: layer.free()
		return
	if layer.get_parent() == null: view.add_child(layer)
	# WorldGround is already behind the parent; artwork follows it in sibling order.
	var ground := view.get_node_or_null("WorldGround")
	if ground != null: view.move_child(layer,ground.get_index()+1)
	view.queue_redraw()

func _image_rect(image: Texture2D) -> TextureRect:
	var rect := TextureRect.new()
	rect.texture = image
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_SCALE
	rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return rect

func _set_rect(rect: TextureRect,view,world: Rect2) -> void:
	var origin: Vector2 = view._world_to_screen(world.position)
	rect.position = origin
	rect.size = view._world_to_screen(world.end)-origin

func _draw_registered(view, image: Texture2D, world: Rect2) -> void:
	if not view.discovery_enabled:
		var origin: Vector2 = view._world_to_screen(world.position)
		view.draw_texture_rect(image,Rect2(origin,view._world_to_screen(world.end)-origin),false)
	else:
		# Preserve optional discovery by painting only already visible cells.
		var bounds: Rect2i = view._visible_world_bounds().intersection(Rect2i(Vector2i.ZERO,Vector2i(extent())))
		for x in range(bounds.position.x,bounds.end.x):
			for y in range(bounds.position.y,bounds.end.y):
				if not view._cell_is_visible(x,y): continue
				var cell := Rect2(Vector2(x,y),Vector2.ONE).intersection(world)
				if not cell.has_area(): continue
				var origin: Vector2 = view._world_to_screen(cell.position)
				var destination := Rect2(origin,view._world_to_screen(cell.end)-origin)
				var source := Rect2((cell.position-world.position)/world.size*image.get_size(),cell.size/world.size*image.get_size())
				view.draw_texture_rect_region(image,destination,source)

func draw_overview(canvas) -> bool:
	if not available(): return false
	canvas.draw_texture_rect(texture,overview_rect(),false)
	return true
