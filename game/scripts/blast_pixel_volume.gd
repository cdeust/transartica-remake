extends RefCounted
# MIT. Authored granular blast volumes; no source damage or game RNG.
# Material motion follows the Noita FAQ's rising gases and cooling matter.
# Source: https://noitagame.com/ ; recipes calibrated by native blast-detail captures.
const LIMIT := 4 # Authored texture budget reduced after23.6ms eight-field raster.
const CELL := 0.5 # Authored fine pixel pitch: two native pixels at combat4x.
const STEP := 1.0/50.0 # Existing ALIS presentation cadence.
# Ordered4x4 Bayer thresholds: crisp dithered gas instead of soft alpha bubbles.
const BAYER: PackedFloat32Array = [0.0,0.5,0.125,0.625,0.75,0.25,0.875,0.375,0.1875,0.6875,0.0625,0.5625,0.9375,0.4375,0.8125,0.3125]
const PALETTE := [Color("#272d35"),Color("#663627"),Color("#cc4c20"),Color("#f58a27"),Color("#ffd66b"),Color("#fff4cd")]
var fields: Array = []
var rng := RandomNumberGenerator.new()
var serial := 0

func add(kind: String, point: Vector2, direction: Vector2, scale: float) -> void:
	serial += 1
	rng.seed = hash([kind,point,serial])
	var blast := kind in ["destroy","dynamite","explosion","rocket-impact"]
	var gun := kind in ["cannon","muzzle"] # rotary rounds draw their own flash and smoke
	if not blast and not gun and kind != "impact": return
	if fields.size() >= LIMIT:
		var replace := fields.find(fields.filter(func(f):return not f.blast).front()) if fields.any(func(f):return not f.blast) else 0
		fields.remove_at(replace)
	var size := Vector2i(96,128) if blast else Vector2i(64,64)
	var anchor := Vector2(size.x/2,size.y/2 if gun else size.y-18)
	var field := {"kind":kind,"point":point,"direction":direction,"scale":scale,"blast":blast,"gun":gun,"age":0,"life":180 if blast else 65,"size":size,"anchor":anchor,"motes":[],"texture":null,"dirty":true,"bytes":PackedByteArray()}
	field.bytes.resize(size.x*size.y*4)
	var amount := 64 if blast else (32 if kind == "cannon" else 16)
	for i in amount: field.motes.append(_mote(field,i))
	fields.append(field)

func _mote(field: Dictionary, index: int) -> Dictionary:
	var angle := rng.randf_range(-PI,PI)
	var radial := Vector2.from_angle(angle)
	var speed := rng.randf_range(14,55) if field.blast else rng.randf_range(12,45)
	var velocity: Vector2 = radial*speed
	# Gun gas: a short radial puff biased along the bore, rising (head-on guns
	# otherwise smear their whole plume across the wagon body).
	if field.gun: velocity = (field.direction*0.35+radial).normalized()*speed*0.5+Vector2(0,-6)
	var point: Vector2 = radial*rng.randf_range(0,3)
	if field.gun: point = field.direction*rng.randf_range(0,6)+field.direction.orthogonal()*rng.randf_range(-1,1)
	var radius := rng.randi_range(3,7) if field.blast else rng.randi_range(1,3)
	var mask: Array[Vector2i] = []
	var rim := PackedFloat32Array() # per-cell distance²/radius², precomputed for raster
	for y in range(-radius,radius+1):
		for x in range(-radius,radius+1):
			var distance := Vector2(x,y).length()/radius
			if distance < rng.randf_range(0.72,1.08):
				mask.append(Vector2i(x,y))
				rim.append(float(x*x+y*y))
	# source: authored cooling distribution, native blast-detail animation.
	return {"point":point,"velocity":velocity,"phase":angle,"mask":mask,"heat":rng.randf_range(0.75,1.0) if not field.gun else rng.randf_range(0.2,0.55),"cool":rng.randf_range(0.012,0.035) if not field.gun else rng.randf_range(0.06,0.12),"shade":index%3,"pale":field.gun,"rim":rim,"life":rng.randi_range(100,180) if field.blast else rng.randi_range(20,50)} # source: authored cooling/lifetime recipe, native blast-detail animation.

func step() -> void:
	for field in fields:
		field.age += 1
		field.dirty = true
		for mote in field.motes:
			mote.heat = maxf(0,mote.heat-mote.cool)
			# Authored counter-rotating eddies break the radial front into fingers.
			var phase: float = field.age*0.09+mote.phase
			var drift := Vector2(cos(phase)*9,sin(phase*0.7)*4-9)
			mote.velocity = mote.velocity*0.95+drift*STEP
			mote.point += (mote.velocity+drift)*STEP
		field.motes = field.motes.filter(func(m):return field.age < m.life)
	fields = fields.filter(func(f):return f.age < f.life)

func draw(canvas: CanvasItem, offset: Vector2) -> void:
	for field in fields:
		if field.dirty: _raster(field)
		var extent: Vector2 = Vector2(field.size)*CELL*field.scale
		var origin: Vector2 = ((field.point+offset-field.anchor*CELL*field.scale)*4).round()/4 # native-pixel grid, as particles
		canvas.draw_texture_rect(field.texture,Rect2(origin,extent),false)

func _raster(field: Dictionary) -> void:
	var data: PackedByteArray = field.bytes
	data.fill(0)
	var width: int = field.size.x
	var height: int = field.size.y
	# Cold gas behind the incandescent front; shade varies per tiny parcel.
	for hot in [false,true]:
		for mote in field.motes:
			if (mote.heat > 0.25) != hot: continue
			var point := Vector2i((field.anchor+mote.point/CELL).round())
			var radius_sq := float(mote.mask.size())/PI # mask area → radius²
			var rim: PackedFloat32Array = mote.rim
			var mask: Array = mote.mask
			if hot:
				# Palette dither between neighbouring heat levels.
				var level: float = mote.heat*(PALETTE.size()-1)
				var spread := 0.6/radius_sq
				for i in mask.size():
					var cell: Vector2i = mask[i]
					var x: int = point.x+cell.x
					var y: int = point.y+cell.y
					if x < 0 or y < 0 or x >= width or y >= height: continue
					var index := clampi(int(level*(1.0-rim[i]*spread)+BAYER[(y&3)*4+(x&3)]-0.25),0,5)
					var at := (y*width+x)*4
					var color: Color = PALETTE[index]
					data[at] = color.r8
					data[at+1] = color.g8
					data[at+2] = color.b8
					data[at+3] = 235
				continue
			var fade: float = 1.0-float(field.age)/mote.life
			var base := _color(mote,field.age)
			var radius := sqrt(radius_sq)
			# Sunlit crown, sooty underside: authored two-tone gas shading per row.
			var dark := PackedByteArray([int(base.r*255),int(base.g*255),int(base.b*255)])
			var lit := PackedByteArray([int(clampf(base.r+0.1,0,1)*255),int(clampf(base.g+0.1,0,1)*255),int(clampf(base.b+0.11,0,1)*255)])
			var limit := fade*1.7
			for i in mask.size():
				var cell: Vector2i = mask[i]
				var x: int = point.x+cell.x
				var y: int = point.y+cell.y
				if x < 0 or y < 0 or x >= width or y >= height: continue
				# Coverage erodes from the rim inward as the parcel dilutes.
				if limit-rim[i]/radius_sq <= BAYER[(y&3)*4+(x&3)]: continue
				var tone := lit if cell.y < -radius*0.3 else dark
				var at := (y*width+x)*4
				data[at] = tone[0]
				data[at+1] = tone[1]
				data[at+2] = tone[2]
				data[at+3] = 225
	field.bytes = data
	if field.age < 9 and field.blast: _front(field)
	var image := Image.create_from_data(field.size.x,field.size.y,false,Image.FORMAT_RGBA8,field.bytes)
	if field.texture == null: field.texture = ImageTexture.create_from_image(image)
	else: field.texture.update(image)
	field.dirty = false

func _color(mote: Dictionary, age: int) -> Color:
	var heat: float = mote.heat
	if heat <= 0.25:
		# Soot thins and greys as it dilutes; gun gas starts pale. Authored ash palette.
		var shade: float = (0.5 if mote.get("pale",false) else 0.15)+mote.shade*0.035+0.28*float(age)/mote.life
		return Color(shade,shade+0.012,shade+0.028,0.5*(1.0-float(age)/mote.life)) # source: authored cool gas opacity/tint, native blast-detail animation.
	var index := mini(PALETTE.size()-1,int(heat*(PALETTE.size()-1)))
	var color: Color = PALETTE[index]
	color.a = 0.9
	return color

func _front(field: Dictionary) -> void:
	var radius: float = (field.age+1)*4.0
	for index in 96:
		var angle: float = TAU*index/96.0
		var ripple := 1.0+sin(index*7.0+field.age)*0.09
		var point := Vector2i((field.anchor+Vector2.from_angle(angle)*radius*ripple).round())
		_write(field,point,Color(1,0.78,0.35,0.75*(1-field.age/9.0)))

func _write(field: Dictionary, point: Vector2i, color: Color) -> void:
	if point.x < 0 or point.y < 0 or point.x >= field.size.x or point.y >= field.size.y: return
	var offset: int = (point.y*field.size.x+point.x)*4
	field.bytes[offset] = color.r8
	field.bytes[offset+1] = color.g8
	field.bytes[offset+2] = color.b8
	field.bytes[offset+3] = color.a8

func clear() -> void:
	fields.clear()
	serial = 0

func snapshot() -> Array:
	var result := []
	for field in fields:
		result.append([field.kind,field.point,field.age,field.motes])
	return result
