extends RefCounted

# MIT. Authored goods and existing wagon art, never private historical sprites.
# Source footprint: GLIEU comp26/105, tasks/evidence/original-visuals.md.
const MANIFEST := "res://assets/cities/goods-icons.json"
const FOOTPRINT := Vector2i(48,16) # Source goods width48 and workshop height16.
var goods: Dictionary = {}
var wagons = preload("res://scripts/tactical_wagon_art.gd").new()
var wagon_icons: Dictionary = {}


func load_goods() -> bool:
	if not FileAccess.file_exists(MANIFEST):
		return false
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST))
	if not data is Dictionary or not data.get("frames") is Array:
		return false
	var path: String = "res://assets/cities/" + str(data.get("file",""))
	if not ResourceLoader.exists(path):
		return false
	var texture = load(path) as Texture2D
	var staged: Dictionary = {}
	for frame in data.frames:
		if not frame is Dictionary:
			return false
		var id: Variant = frame.get("id")
		# Godot JSON decodes numeric IDs as floats; validate before canonicalizing.
		if not typeof(id) in [TYPE_INT,TYPE_FLOAT] or not is_finite(float(id)) or id != floor(id):
			return false
		if not int(id) in range(1,17) or staged.has(int(id)):
			return false
		if not frame.get("region") is Array or frame.region.size() != 4:
			return false
		var region := Rect2i(frame.region[0],frame.region[1],frame.region[2],frame.region[3])
		if not region.has_area() or not Rect2i(Vector2i.ZERO,texture.get_size()).encloses(region):
			return false
		staged[int(frame.id)] = fitted(texture.get_image().get_region(region))
	if staged.size() != 16:
		return false
	goods = staged
	return true


func goods_for(kind: int) -> Texture2D:
	return goods.get(kind)


func wagon_for(kind: int) -> Texture2D:
	if not wagon_icons.has(kind):
		wagon_icons[kind] = fitted(wagons.texture_for(kind).get_image())
	return wagon_icons[kind]


static func fitted(image: Image) -> Texture2D:
	# Native IN SALAH capture130,3Oct: shrinking to48x16 then enlarging4.5x
	# loses the authored detail. Keep every source pixel; ItemList owns display
	# size, while proportional transparent padding owns the shared row aspect.
	var factor := ceili(maxf(float(image.get_width())/FOOTPRINT.x,float(image.get_height())/FOOTPRINT.y))
	var extent := FOOTPRINT * factor
	image.convert(Image.FORMAT_RGBA8)
	var canvas := Image.create(extent.x,extent.y,false,Image.FORMAT_RGBA8)
	canvas.fill(Color.TRANSPARENT)
	canvas.blit_rect(image,Rect2i(Vector2i.ZERO,image.get_size()),(extent-image.get_size())/2)
	return ImageTexture.create_from_image(canvas)
