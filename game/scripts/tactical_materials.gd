extends RefCounted
# MIT. Presentation only: material occupancy from authored sprite alpha, fractures
# from authored effects-kit08. Original WDECOR health3/2/1/0 remains authoritative.
# Owner FIDELITE.md permits Noita-inspired debris/smoke/light, not new damage rules.
const SCORCH := Color("#574632") # Authored existing workshop/steel palette; presentation only.
var instances := {}
var stencil: Image

func texture_for(source: Texture2D, side: int, wagon: int, health: int) -> Texture2D:
	if health >= 3:
		return source
	var key := "%d/%d/%d" % [side,wagon,health]
	if instances.has(key):
		return instances[key].texture
	if stencil == null:
		stencil = load("res://assets/combat/effects-kit-08.png").get_image()
	var image := source.get_image().duplicate() as Image
	var occupancy := PackedByteArray()
	occupancy.resize(image.get_width()*image.get_height())
	var removed: Array = []
	# Three authored fracture passes expose wreckage at original health0.
	# Scorch changes presentation only; original hull state remains authoritative.
	for y in image.get_height():
		for x in image.get_width():
			var color := image.get_pixel(x,y)
			if color.a <= 0:
				continue
			var cut := _fractured(Vector2i(x,y),image.get_size(),health,side,wagon)
			occupancy[y*image.get_width()+x] = 0 if cut else 1
			if health == 0 and not cut:
				image.set_pixel(x,y,color*SCORCH)
			if cut:
				removed.append({"point":Vector2i(x,y),"color":color})
				image.set_pixel(x,y,Color.TRANSPARENT)
	var texture := ImageTexture.create_from_image(image)
	instances[key] = {"texture":texture,"occupancy":occupancy,"removed":removed,"size":image.get_size()}
	return texture

func _fractured(point: Vector2i, extent: Vector2i, health: int, side: int, wagon: int) -> bool:
	# Stencil geometry is authored; arrangement varies per wagon and side, never RNG.
	var width := extent.x / 3 # Health has three original hull stages.
	var centre := extent.x / 2 + ((wagon + side) % 3 - 1) * width / 2
	for hit in 3-health:
		var start := centre-width/2 + hit*width/2
		var local := point-Vector2i(start,extent.y/3)
		var height := extent.y/2
		if local.x>=0 and local.x<width and local.y>=0 and local.y<height:
			var sample := Vector2i(local.x*stencil.get_width()/width,local.y*stencil.get_height()/height)
			if stencil.get_pixelv(sample).a >= 128.0/255.0:
				return true
	return false

func draw_debris(canvas: CanvasItem, key: String, bounds: Rect2, age: int) -> void:
	if not instances.has(key):
		return
	var material: Dictionary = instances[key]
	var count: int = material.removed.size()
	if count == 0:
		return
	# Authored six-fragment fan per source roof cell, sampled from removed texels.
	for index in 24:
		var fragment: Dictionary = material.removed[index*(count-1)/23]
		var point: Vector2 = bounds.position+Vector2(fragment.point)*bounds.size/Vector2(material.size)
		var drift := Vector2.from_angle(PI+(index+0.5)/24*PI)*(1+index%4)*age
		var fall := Vector2(0,age*age/4.0)
		canvas.draw_rect(Rect2(point+drift+fall,Vector2.ONE*2),fragment.color)


func fragment_colors(key: String) -> Array:
	if not instances.has(key) or instances[key].removed.is_empty(): return []
	var removed: Array = instances[key].removed
	var result := []
	for index in 24:
		result.append(removed[index*(removed.size()-1)/23].color)
	return result
