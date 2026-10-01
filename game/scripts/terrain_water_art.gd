extends RefCounted
# MIT. Material detail only; preserve the authored96px shoreline and its alpha.
# Source: build_travel_terrain.py palette water/waterlight B-R64, shore blue40,
# snow24. Grain changes all channels together, preserving that separation.
const ART_PIXELS := 96
const WATER_DELTA := 0x82-0x42
var master: Image
var textures := {}
var cache_budget := 0

func load_art() -> void:
	var texture=load("res://assets/travel/terrain/ice-master.png") as Texture2D
	master=texture.get_image() if texture!=null else null
	textures.clear()

static func supports(resource: int) -> bool:
	return (resource>=106 and resource<=115) or (resource>=134 and resource<=140) or resource==149

static func water_pixel(color: Color) -> bool:
	return color.a>0 and roundi(color.b*255)-roundi(color.r*255)==WATER_DELTA

func begin_frame(visible_cells: int) -> void:
	# Bound by the actual clipped visible-map working set, never atlas phase count.
	cache_budget=maxi(0,visible_cells)
	while textures.size()>cache_budget:textures.erase(textures.keys()[0])

func sample_pixel(cell: Vector2i, pixel: Vector2i) -> Color:
	return master.get_pixel(posmod(cell.x*ART_PIXELS+pixel.x,master.get_width()),posmod(cell.y*ART_PIXELS+pixel.y,master.get_height()))

func texture_for(source: Texture2D, resource: int, cell: Vector2i) -> Texture2D:
	if master==null or not supports(resource):return source
	var phase:=Vector2i(posmod(cell.x*ART_PIXELS,master.get_width()),posmod(cell.y*ART_PIXELS,master.get_height()))
	var key:="%d/%d/%d" % [resource,phase.x,phase.y]
	if textures.has(key):return textures[key]
	var image:Image=source.get_image().duplicate()
	for y in image.get_height():
		for x in image.get_width():
			var original:=image.get_pixel(x,y)
			if water_pixel(original):
				var material:=sample_pixel(cell,Vector2i(x,y))
				image.set_pixel(x,y,Color(material.r,material.g,material.b,original.a))
	var texture:=ImageTexture.create_from_image(image)
	if cache_budget>0:
		while textures.size()>=cache_budget:textures.erase(textures.keys()[0])
		textures[key]=texture
	return texture
