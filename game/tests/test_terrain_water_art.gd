extends SceneTree
# MIT. Verify exact shoreline/alpha preservation and world-continuous detail.
const Water=preload("res://scripts/terrain_water_art.gd")
func _initialize() -> void:
	var water=Water.new()
	water.load_art()
	water.begin_frame(4) # Review fixture's actual2x2 visible tile set.
	assert(water.master!=null)
	assert(Water.water_pixel(Color("#426e82")) and Water.water_pixel(Color("#6e9cae")))
	assert(not Water.water_pixel(Color("#b1c4c9")) and not Water.water_pixel(Color("#829eaa")))
	for resource in [106,107,108,109,110,111,112,113,114,115,134,135,136,137,138,139,140,149]:
		var source=load("res://assets/travel/terrain/%d.png" % resource) as Texture2D
		var original=source.get_image()
		var before=original.get_data()
		var altered=water.texture_for(source,resource,Vector2i(13,5)).get_image()
		assert(altered.get_size()==Vector2i(96,96))
		for y in 96:
			for x in 96:
				var color=original.get_pixel(x,y)
				assert(altered.get_pixel(x,y).a==color.a)
				if not Water.water_pixel(color):assert(altered.get_pixel(x,y)==color)
		assert(source.get_image().get_data()==before)
		assert(water.textures.size()<=4)
	for y in 96:
		assert(water.sample_pixel(Vector2i(13,5),Vector2i(96,y))==water.sample_pixel(Vector2i(14,5),Vector2i(0,y)))
		assert(water.sample_pixel(Vector2i(13,5),Vector2i(y,96))==water.sample_pixel(Vector2i(13,6),Vector2i(y,0)))
	var data=preload("res://scripts/world_data.gd").new()
	assert(data.load_from_project(ProjectSettings.globalize_path("res://")))
	var map_before=data.map_bytes.duplicate()
	var terrain=preload("res://scripts/travel_terrain.gd").new()
	assert(terrain.load_art())
	for x in data.MAP_WIDTH:
		for y in data.MAP_HEIGHT:
			var resource:int=terrain.resource_code(data.map_code(x,y))
			if Water.supports(resource):water.texture_for(terrain.textures[resource],resource,Vector2i(x,y))
	assert(data.map_bytes==map_before and water.textures.size()<=4)
	water.begin_frame(0)
	assert(water.textures.is_empty())
	print("PASS:18 water groups exact alpha/shore/source pixels and map unchanged, coherent global phase, bounded visible-tile cache")
	quit()
