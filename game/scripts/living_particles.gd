extends RefCounted

# MIT. Sparse visual particles: no whole-screen falling-sand grids per emitter.
# Gases rise and falling fragments accelerate as in the existing PixelField.
# Recipe magnitudes are authored logical-pixel animation, not damage physics.
const LIMIT := 2048 # Authored peak working set, measured by native benchmark.
const STEP := 1.0/50.0
const GRAVITY := 100.0 # Authored screen acceleration, native capture calibration.
const LIGHT_ONLY := ["glow","ring"]
static var _halo: GradientTexture2D


# Soft radial falloff for additive halos (hard discs read as pale bubbles).
static func halo() -> GradientTexture2D:
	if _halo != null: return _halo
	var ramp := Gradient.new()
	ramp.set_color(0,Color(1,1,1,1))
	ramp.set_color(1,Color(1,1,1,0))
	ramp.add_point(0.35,Color(1,1,1,0.45))
	_halo = GradientTexture2D.new()
	_halo.gradient = ramp
	_halo.fill = GradientTexture2D.FILL_RADIAL
	_halo.fill_from = Vector2(0.5,0.5)
	_halo.fill_to = Vector2(1,0.5)
	_halo.width = 64
	_halo.height = 64
	return _halo
var items: Array = []


func launch(kind: String, point: Vector2, velocity: Vector2, lifetime: int, extent: Vector2, color: Color, scale := 1.0, angle := 0.0, floor_y := INF) -> void:
	if items.size() >= LIMIT: items.pop_front()
	var item := {"kind":kind,"point":point,"velocity":velocity,"age":0,"life":lifetime,"extent":extent,"color":color,"scale":scale,"angle":angle}
	if is_finite(floor_y): item.floor = floor_y
	if kind == "projectile": item.origin = point
	items.append(item)


func step() -> void:
	var trails := []
	for particle in items:
		particle.age += 1
		if particle.get("trail",false) and particle.age < particle.life*0.8:
			trails.append(particle.point+Vector2(sin(particle.age*2.3),cos(particle.age*1.7))*0.5)
		if particle.kind in ["snow","spark","debris","ember","casing"]:
			particle.velocity.y += GRAVITY*(2.5 if particle.kind == "casing" else 1.0)*STEP*particle.scale
			particle.angle += particle.velocity.x*STEP*(1.4 if particle.kind == "casing" else 0.1)
		particle.point += particle.velocity*STEP
		# Brass bounces on the drawn roof, then settles (authored restitution).
		if particle.has("floor") and particle.point.y > particle.floor and particle.velocity.y > 0:
			particle.point.y = particle.floor
			particle.velocity = Vector2(particle.velocity.x*0.55,-particle.velocity.y*0.35)
			if absf(particle.velocity.y) < 6:
				particle.velocity = Vector2.ZERO
				particle.angle = round(particle.angle/PI)*PI # comes to rest lying flat
	items = items.filter(func(p):return p.age < p.life)
	for point in trails: # Soot specks left behind burning fragments.
		launch("soot",point,Vector2(0,-4),36,Vector2.ONE*0.5,Color(0.2,0.2,0.22,0.75))


func draw(canvas: CanvasItem, atlas, offset := Vector2.ZERO, separate_light := false) -> void:
	for particle in items:
		var progress: float = float(particle.age)/particle.life
		var color: Color = particle.color
		if particle.kind in ["spark","ember","debris"]:
			var heat := maxf(0,1.0-progress*3.0)
			var incandescent := Color("#fff1b5").lerp(Color("#e55b20"),1-heat)
			color = color.lerp(incandescent,heat)
		color.a *= 1-progress
		var point := _snap(particle.point+offset)
		var name: String = particle.kind
		if name in ["smoke","flame","rocket"]:
			name += "-%d" % mini(3,int(progress*4))
		else: name += "-0"
		var extent: Vector2 = particle.extent
		if particle.kind in ["smoke","steam"]: extent *= 1+progress*2
		if particle.kind in LIGHT_ONLY: continue
		if particle.kind == "flash":
			_flash(canvas,point,particle,progress,1.0)
		elif particle.kind == "casing":
			_casing(canvas,point,particle,progress)
		elif particle.kind == "projectile":
			canvas.draw_line(_tail(particle,point,offset),point,color,extent.y)
		elif particle.kind == "soot":
			var grown: float = extent.x*(1+progress*3.0)
			canvas.draw_rect(Rect2(point-Vector2.ONE*grown/2,Vector2.ONE*grown),Color(color.lerp(Color(0.55,0.56,0.6),progress),color.a))
		elif particle.kind in ["debris","snow","spark","ember"]:
			if particle.kind in ["spark","ember"]:
				canvas.draw_line(point-particle.velocity.normalized()*3,point,Color(color, color.a*0.35),particle.scale*0.5)
			if particle.kind == "debris":
				var corners := PackedVector2Array()
				for corner in [Vector2.ZERO,Vector2(1,0),Vector2.ONE,Vector2(0,1)]:
					corners.append(point+((corner-Vector2.ONE/2)*extent).rotated(particle.angle))
				canvas.draw_colored_polygon(corners,color)
			else: canvas.draw_rect(Rect2(point,extent),color)
		else:
			atlas.draw(canvas,name,point,extent,color,particle.angle)
	if not separate_light: draw_light(canvas,offset)


# Additive pass: halos only brighten what lies beneath (dark armour, smoke).
func draw_light(canvas: CanvasItem, offset := Vector2.ZERO) -> void:
	for particle in items:
		var progress: float = float(particle.age)/particle.life
		var fade := 1.0-progress
		var point := _snap(particle.point+offset)
		var extent: Vector2 = particle.extent
		match particle.kind:
			"glow":
				var radius: float = extent.x*(1+progress*0.5)
				canvas.draw_texture_rect(halo(),Rect2(point-Vector2.ONE*radius,Vector2.ONE*radius*2),false,Color(particle.color,0.6*fade))
			"flash":
				_flash(canvas,point,particle,progress,1.6)
			"ring":
				var radius: Vector2 = extent*(0.3+progress*0.7)
				var ring := PackedVector2Array()
				for index in 25: ring.append(point+Vector2(cos(TAU*index/24)*radius.x,sin(TAU*index/24)*radius.y))
				canvas.draw_polyline(ring,Color(particle.color,0.45*fade*fade),0.5)
			"projectile":
				canvas.draw_line(_tail(particle,point,offset),point,Color(1,0.55,0.2,particle.color.a*0.45),extent.y*3)
			"spark","ember":
				if progress < 0.4: canvas.draw_circle(point,1.0,Color(1,0.6,0.25,0.35*(1-progress/0.4)))


func _snap(point: Vector2) -> Vector2:
	# One native pixel (1/4 logical) grid: smooth motion without sub-pixel blur.
	return (point*4).round()/4


func _tail(particle: Dictionary, point: Vector2, offset: Vector2) -> Vector2:
	# Streak never extends behind its muzzle: length grows with distance flown.
	var travelled: float = (particle.point-particle.get("origin",particle.point)).length()
	return point-particle.velocity.normalized()*minf(particle.extent.x,travelled)


# Procedural muzzle flash: hot core, tongue and irregular spikes. A radial
# flash is seen head-on (gun aimed at the viewer): spikes all round, no tongue.
func _flash(canvas: CanvasItem, point: Vector2, particle: Dictionary, progress: float, bloom: float) -> void:
	var size: Vector2 = particle.extent*(1.0-progress*0.4)*bloom
	var forward := Vector2.from_angle(particle.angle)
	var side := forward.orthogonal()
	var radial: bool = particle.get("radial",false)
	var fade := (1.0-progress)*(1.0 if bloom <= 1.0 else 0.35)
	var spikes := PackedVector2Array()
	var count := 12 if radial else 10
	for index in count:
		var spoke := Vector2.from_angle(TAU*index/count)
		var reach: float
		if radial: reach = size.x*(0.55 if index%2 == 0 else 0.22)*(1.0 if index%4 == 0 else 0.75)
		elif index%2 == 0: reach = size.x*(1.0 if spoke.x > 0.6 else 0.45)
		else: reach = size.y*0.25
		spikes.append(point+(forward*spoke.x+side*spoke.y*(1.0 if radial else 0.7))*reach)
	canvas.draw_colored_polygon(spikes,Color(1,0.62,0.2,0.85*fade))
	if not radial:
		canvas.draw_colored_polygon(PackedVector2Array([point-side*size.y*0.35,point+forward*size.x*0.7,point+side*size.y*0.35]),Color(1,0.9,0.55,fade))
	canvas.draw_circle(point,size.y*(0.4 if radial else 0.3),Color(1,0.98,0.88,fade))


# Spent cartridge: brass tube, dark open mouth, rim, one moving glint.
func _casing(canvas: CanvasItem, point: Vector2, particle: Dictionary, progress: float) -> void:
	var alpha := clampf((1.0-progress)*4.0,0,1) # settles, then fades at the end
	var along := Vector2.from_angle(particle.angle)
	var across := along.orthogonal()
	var half: Vector2 = particle.extent/2
	var shell := PackedVector2Array([point-along*half.x-across*half.y,point+along*half.x-across*half.y,point+along*half.x+across*half.y,point-along*half.x+across*half.y])
	canvas.draw_colored_polygon(shell,Color("#b98a3c",alpha))
	canvas.draw_line(point-along*half.x-across*half.y*0.4,point+along*half.x*0.6-across*half.y*0.4,Color("#ffe39a",alpha),0.25)
	canvas.draw_line(point+along*half.x*0.75-across*half.y,point+along*half.x*0.75+across*half.y,Color("#3a2a14",alpha),0.35)
	canvas.draw_line(point-along*half.x-across*half.y*1.2,point-along*half.x+across*half.y*1.2,Color("#8c6326",alpha),0.3)
	if particle.velocity != Vector2.ZERO and int(particle.angle*3)%2 == 0: # tumbling glint
		canvas.draw_rect(Rect2(point-Vector2.ONE*0.25,Vector2.ONE*0.5),Color(1,0.95,0.75,alpha))
