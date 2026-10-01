extends RefCounted

# MIT. Sparse visual particles: no whole-screen falling-sand grids per emitter.
# Gases rise and falling fragments accelerate as in the existing PixelField.
# Recipe magnitudes are authored logical-pixel animation, not damage physics.
const LIMIT := 2048 # Authored peak working set, measured by native benchmark.
const STEP := 1.0/50.0
const GRAVITY := 100.0 # Authored screen acceleration, native capture calibration.
var items: Array = []


func launch(kind: String, point: Vector2, velocity: Vector2, lifetime: int, extent: Vector2, color: Color, scale := 1.0, angle := 0.0) -> void:
	if items.size() >= LIMIT: items.pop_front()
	items.append({"kind":kind,"point":point,"velocity":velocity,"age":0,"life":lifetime,"extent":extent,"color":color,"scale":scale,"angle":angle})


func step() -> void:
	for particle in items:
		particle.age += 1
		if particle.kind in ["snow","spark","debris","ember"]:
			particle.velocity.y += GRAVITY*STEP*particle.scale
		particle.point += particle.velocity*STEP
	items = items.filter(func(p):return p.age < p.life)


func draw(canvas: CanvasItem, atlas, offset := Vector2.ZERO) -> void:
	for particle in items:
		var progress: float = float(particle.age)/particle.life
		var color: Color = particle.color
		color.a *= 1-progress
		var point: Vector2 = (particle.point+offset).round()
		var name: String = particle.kind
		if name in ["smoke","flame","rocket"]:
			name += "-%d" % mini(3,int(progress*4))
		elif name == "steam": name += "-0"
		else: name += "-0"
		var extent: Vector2 = particle.extent
		if particle.kind in ["smoke","steam"]: extent *= 1+progress*2
		if particle.kind == "projectile":
			canvas.draw_line(point-particle.velocity.normalized()*8,point,color,1)
		elif particle.kind in ["debris","snow","spark","ember"]:
			if particle.kind in ["spark","ember"]:
				canvas.draw_line(point-particle.velocity.normalized()*3,point,Color(color, color.a*0.5),2)
			canvas.draw_rect(Rect2(point,extent),color)
		else:
			atlas.draw(canvas,name,point,extent,color,particle.angle)
