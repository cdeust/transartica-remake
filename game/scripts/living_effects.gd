extends RefCounted

# MIT. Presentation recipes, calibrated by native living-effects captures.
# Visual50Hz derives from existing ALIS cadence; this never advances game state.
const STEP := 1.0/50.0 # source: existing ALIS50Hz visual cadence.
const MAX_EMITTERS := 128 # Authored peak budget; living-effects benchmark evidence.
const Particles = preload("res://scripts/living_particles.gd")
const Atlas = preload("res://scripts/living_effects_atlas.gd")
var particles = Particles.new()
var atlas = Atlas.new()
var emitters: Array = []
var rng := RandomNumberGenerator.new()
var remainder := 0.0
var serial := 0
var emitted := 0


func add(kind: String, point: Vector2, direction := Vector2.RIGHT, scale := 1.0) -> void:
	if not is_finite(scale) or scale <= 0: return
	serial += 1
	emitted += 1
	rng.seed = hash([kind,point,serial]) # Local visual identity, never gameplay RNG.
	if emitters.size() >= MAX_EMITTERS:
		emitters.pop_front()
	var explosive := kind in ["destroy","dynamite","explosion","rocket-impact"]
	var gun := kind in ["cannon","machinegun","muzzle"]
	var duration := 150 if explosive else (50 if kind == "impact" else 30)
	if kind in ["steam","smoke","dust"]: duration = 75
	var emitter := {"kind":kind,"point":point,"direction":direction.normalized(),"age":0,"duration":duration,"explosive":explosive,"gun":gun,"scale":scale}
	emitters.append(emitter)
	if explosive or kind in ["impact","sparks","shot","melee","snow"]:
		_burst(emitter,48 if explosive else 16)
	if gun:
		particles.launch("projectile",point,direction.normalized()*180*scale,10,Vector2(8,1)*scale,Color("#fff1c2"),scale)
	_plume(emitter)


func fragments(point: Vector2, colors: Array) -> void:
	# The actual removed wagon texels supply fragment material colors.
	for color in colors:
		particles.launch("debris",point,Vector2(rng.randf_range(-45,45),rng.randf_range(-65,-15)),75,Vector2(2,2),color)


func advance(seconds: float) -> void:
	if not is_finite(seconds) or seconds <= 0: return
	remainder += seconds
	while remainder >= STEP or is_equal_approx(remainder,STEP):
		remainder = maxf(0,remainder-STEP)
		particles.step()
		for emitter in emitters:
			emitter.age += 1
			if emitter.age % 4 == 0 and emitter.age < emitter.duration/2:
				_plume(emitter)
		emitters = emitters.filter(func(e):return e.age < e.duration)


func draw(canvas: CanvasItem, offset := Vector2.ZERO) -> void:
	if not atlas.loaded: atlas.load_art()
	for emitter in emitters:
		var point: Vector2 = emitter.point+offset
		if emitter.age < 8 and (emitter.explosive or emitter.kind == "impact"):
			var diameter: float = float(emitter.age+1)*6*emitter.scale
			atlas.draw(canvas,"shock-0",point,Vector2.ONE*diameter,Color(1,0.82,0.42,1.0-emitter.age/8.0))
		if emitter.gun and emitter.age < 6:
			var tip: Vector2 = point+emitter.direction*11*emitter.scale
			atlas.draw(canvas,"muzzle-%d" % mini(3,emitter.age/2),tip,Vector2(22,14)*emitter.scale,Color.WHITE,emitter.direction.angle())
	particles.draw(canvas,atlas,offset)


func clear() -> void:
	emitters.clear()
	particles.items.clear()
	remainder = 0
	serial = 0
	emitted = 0


func _plume(emitter: Dictionary) -> void:
	var rocket: bool = emitter.kind in ["rocket","rocket-exhaust"]
	var smoke: bool = emitter.explosive or emitter.gun or rocket or emitter.kind in ["impact","smoke","steam","dust"]
	var scale: float = emitter.scale
	if smoke:
		var name: String = emitter.kind if emitter.kind in ["steam","dust"] else "smoke"
		var extent := Vector2(18,18) if emitter.explosive else Vector2(10,10)
		particles.launch(name,emitter.point+Vector2(rng.randf_range(-4,4),-2)*scale,Vector2(rng.randf_range(-6,6),rng.randf_range(-16,-8))*scale,100,extent*scale,Color.WHITE,scale)
	if emitter.explosive and emitter.age < 30:
		particles.launch("flame",emitter.point+Vector2(rng.randf_range(-7,7),-3)*scale,Vector2(rng.randf_range(-4,4),-8)*scale,30,Vector2(40,40)*scale,Color.WHITE,scale)
	if rocket:
		particles.launch("rocket",emitter.point,emitter.direction*20*scale,12,Vector2(9,22)*scale,Color.WHITE,scale,emitter.direction.angle()-PI/2)


func _burst(emitter: Dictionary, amount: int) -> void:
	for index in amount:
		var material := "snow" if index%3 == 0 or emitter.kind == "snow" else "spark"
		var velocity: Vector2 = Vector2.from_angle(rng.randf_range(PI,TAU))*rng.randf_range(20,70)*emitter.scale
		particles.launch(material,emitter.point,velocity,45 if material == "spark" else 75,Vector2(2,2)*emitter.scale,Color("#ffd27a") if material == "spark" else Color("#dbe5ea"),emitter.scale)
