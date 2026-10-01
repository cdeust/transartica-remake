extends RefCounted
# MIT. Presentation only: material occupancy from authored sprite alpha, fractures
# from authored effects-kit08. Original WDECOR health3/2/1/0 remains authoritative.
# Owner FIDELITE.md permits Noita-inspired debris/smoke/light, not new damage rules.
var instances := {}

func texture_for(source: Texture2D, side: int, wagon: int, health: int) -> Texture2D:
	if health >= 3:
		return source
	var key := "%d/%d/%d" % [side,wagon,health]
	# Regression evidence: main-regression-20261001.md, real charge destruction.
	# A slot/health can use the original hull for fragments and the authored wreck
	# for drawing. Only reuse material data for the same source texture.
	if instances.has(key) and instances[key].source == source:
		return instances[key].texture
	var image := source.get_image().duplicate() as Image
	if image.is_compressed(): image.decompress()
	image.convert(Image.FORMAT_RGBA8)
	var full := image.get_size()
	# Damage is decided at about the drawn resolution (sprites are3-4× oversampled),
	# then composited at full resolution with engine image operations.
	var step := maxi(1,full.x/WORK_WIDTH)
	var small := image.duplicate() as Image
	small.resize(full.x/step,full.y/step,Image.INTERPOLATE_NEAREST)
	var width := small.get_width()
	var height := small.get_height()
	var data := small.get_data()
	var occupancy := PackedByteArray()
	occupancy.resize(width*height)
	var hull_top := height
	var hull_bottom := 0
	for index in width*height:
		if data[index*4+3] >= 128: # solid material only; faint fringes never support
			occupancy[index] = 1
			hull_top = mini(hull_top,index/width)
			hull_bottom = maxi(hull_bottom,index/width+1)
	var states := PackedByteArray()
	states.resize(width*height)
	var craters := _craters(small,health,side,wagon)
	# Shells bite down from the roof: the upper crater opens to the sky, the
	# lower crater exposes the charred interior, the rim is scorched.
	for crater in craters:
		var reach: Vector2 = crater.radius*1.5
		var area := Rect2i(Vector2i(crater.centre-reach),Vector2i(reach*2)).intersection(Rect2i(0,0,width,height))
		for y in range(area.position.y,area.end.y):
			for x in range(area.position.x,area.end.x):
				var index := y*width+x
				if occupancy[index] == 1 and states[index] == 0:
					states[index] = _damage(Vector2(x,y),craters)
					if states[index] == OPEN: occupancy[index] = 0
	_drop_unsupported(width,height,occupancy,states,Rect2i(0,hull_top,width,maxi(1,hull_bottom-hull_top)))
	var removed: Array = []
	var open := Image.create(width,height,false,Image.FORMAT_RGBA8)
	var interior := Image.create(width,height,false,Image.FORMAT_RGBA8)
	var rim := Image.create(width,height,false,Image.FORMAT_RGBA8)
	var soot := Image.create(width,height,false,Image.FORMAT_RGBA8)
	for index in width*height:
		var state := states[index]
		if state == 0: continue
		var point := Vector2i(index%width,index/width)
		var at := index*4
		var original := Color8(data[at],data[at+1],data[at+2],255)
		if state == OPEN:
			removed.append({"point":point,"color":original})
			open.set_pixelv(point,Color.WHITE)
		elif state == INTERIOR:
			# Hull seen from inside: the sprite's own ribs/planks, deep in shadow,
			# lit by a few smouldering embers on fresh hits.
			var color := INTERIOR_DARK.lerp(original,0.22)
			if _hash(point.x*0.37+point.y*1.13,float(health)) > 0.996 and health > 0: color = EMBER
			interior.set_pixelv(point,color)
		elif state == RIM:
			rim.set_pixelv(point,Color.WHITE)
		elif state == SOOT:
			soot.set_pixelv(point,Color.WHITE)
	for mask in [open,interior,rim,soot]: mask.resize(full.x,full.y,Image.INTERPOLATE_NEAREST)
	var whole := Rect2i(Vector2i.ZERO,full)
	var sooted := image.duplicate() as Image
	sooted.adjust_bcs(0.72,1.0,0.7)
	image.blit_rect_mask(sooted,soot,whole,Vector2i.ZERO)
	var charred := image.duplicate() as Image
	charred.adjust_bcs(0.38,1.1,0.5)
	image.blit_rect_mask(charred,rim,whole,Vector2i.ZERO)
	# Interior only where the hull exists: mask its alpha by the original.
	var hull := image.duplicate() as Image
	hull.blit_rect_mask(interior,interior,whole,Vector2i.ZERO)
	image.blit_rect_mask(hull,interior,whole,Vector2i.ZERO)
	image.blit_rect_mask(Image.create(full.x,full.y,false,Image.FORMAT_RGBA8),open,whole,Vector2i.ZERO)
	if health == 0: image.adjust_bcs(0.78,1.05,0.6) # burnt-out wreck, still readable
	var texture := ImageTexture.create_from_image(image)
	# Front wall only (gutted interior removed): redrawn over a gun that fell in.
	var front := image.duplicate() as Image
	front.blit_rect_mask(Image.create(full.x,full.y,false,Image.FORMAT_RGBA8),interior,whole,Vector2i.ZERO)
	# Bearing surface per column: solid hull only (not the gutted interior wall).
	var support := PackedFloat32Array()
	for x in width:
		var top := float(full.y)
		for y in height:
			var index := y*width+x
			if occupancy[index] == 1 and states[index] != INTERIOR:
				top = float(y*step)
				break
		support.append(top)
	instances[key] = {"source":source,"texture":texture,"occupancy":occupancy,"removed":removed,"size":Vector2i(width,height),"support":support,"step":step,"front":ImageTexture.create_from_image(front)}
	return texture


func front_for(side: int, wagon: int, health: int) -> Texture2D:
	var key := "%d/%d/%d" % [side,wagon,health]
	return instances[key].front if instances.has(key) else null


# Bearing-surface top (source texel y) for each source column in used.
func support_profile(source: Texture2D, side: int, wagon: int, health: int, used: Rect2) -> PackedFloat32Array:
	texture_for(source,side,wagon,health)
	var instance: Dictionary = instances["%d/%d/%d" % [side,wagon,health]]
	if not instance.has("profiles"): instance.profiles = {}
	if instance.profiles.has(used): return instance.profiles[used]
	var profile := PackedFloat32Array()
	var support: PackedFloat32Array = instance.support
	for x in range(int(used.position.x),int(used.end.x)):
		profile.append(maxf(support[mini(support.size()-1,x/instance.step)],used.position.y))
	instance.profiles[used] = profile
	return profile


const WORK_WIDTH := 256 # source: drawn wagon width,64 logical × 4 native px.
const OPEN := 1
const INTERIOR := 2
const RIM := 3
const SOOT := 4
const INTERIOR_DARK := Color("#0e0a08")
const EMBER := Color("#ff7a2a")


static func _hash(value: float, seed: float) -> float:
	return fposmod(sin(value*12.9898+seed*78.233)*43758.5453,1.0)


# Deterministic crater layout per wagon/side (never RNG); one more per lost hull point.
func _craters(image: Image, health: int, side: int, wagon: int) -> Array:
	var width := image.get_width()
	var height := image.get_height()
	var slots := [0.3,0.68,0.5]
	var shift := ((wagon*5+side*3)%5-2)*0.03
	var result := []
	for hit in 3-health:
		var cx := clampi(int(width*(slots[(hit+wagon+side)%3]+shift)),0,width-1)
		var top := 0
		while top < height-1 and image.get_pixel(cx,top).a <= 0.5: top += 1
		var radius := height*(0.3+0.05*hit)*(1.3 if health == 0 else 1.0)
		result.append({"centre":Vector2(cx,top+radius*0.4),"radius":Vector2(radius*1.2,radius),"seed":float(wagon*13+side*7+hit*29)})
	return result


# Torn edge: value noise over24 angular bins (authored, deterministic).
func _edge(angle: float, seed: float) -> float:
	var bins := 24.0
	var at := (angle+PI)/TAU*bins
	var i := floorf(at)
	var a := _hash(fposmod(i,bins),seed)
	var b := _hash(fposmod(i+1.0,bins),seed)
	var fine := _hash(floorf(at*3.0),seed+5.0)
	return 0.72+0.4*lerpf(a,b,at-i)+0.08*fine


# Splintered break: smooth sag between plank ends plus narrow splinter spikes.
func _break_line(x: float, seed: float) -> float:
	var at := x/6.0
	var i := floorf(at)
	var sag := lerpf(_hash(i,seed),_hash(i+1.0,seed),smoothstep(0.0,1.0,at-i))
	var splinter := pow(_hash(floorf(x/2.0),seed+3.0),4.0)
	return -0.12+0.3*sag-0.14*splinter


func _damage(point: Vector2, craters: Array) -> int:
	var best := 0
	for crater in craters:
		var local: Vector2 = (point-crater.centre)/crater.radius
		var distance := local.length()/_edge(atan2(local.y,local.x),crater.seed)
		if distance < 1.0:
			# Roof and upper wall are blown away; below, the hull is gutted.
			if local.y < _break_line(point.x,crater.seed): return OPEN
			best = INTERIOR
		elif distance < 1.14 and best != INTERIOR:
			best = RIM
		elif distance < 1.45 and best == 0:
			best = SOOT
	return best


# Anything no longer joined to the chassis (bottom rows) falls off as debris.
func _drop_unsupported(width: int, height: int, occupancy: PackedByteArray, states: PackedByteArray, hull: Rect2i) -> void:
	var reached := PackedByteArray()
	reached.resize(width*height)
	var queue := PackedInt32Array()
	# Chassis: lowest15% of the opaque hull (sprites may carry transparent margins).
	for index in range((hull.end.y-maxi(1,int(hull.size.y*0.15)))*width,hull.end.y*width):
		if occupancy[index] == 1:
			reached[index] = 1
			queue.append(index)
	var head := 0
	while head < queue.size():
		var index := queue[head]
		head += 1
		var x := index%width
		for next in [index-width,index+width,index-1 if x > 0 else -1,index+1 if x < width-1 else -1]:
			if next >= 0 and next < width*height and occupancy[next] == 1 and reached[next] == 0:
				reached[next] = 1
				queue.append(next)
	for index in width*height:
		if occupancy[index] == 1 and reached[index] == 0:
			occupancy[index] = 0
			states[index] = OPEN


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
