extends RefCounted

# MIT. Presentation recipes, calibrated by native living-effects captures.
# Visual50Hz derives from existing ALIS cadence; this never advances game state.
const STEP := 1.0/50.0 # source: existing ALIS50Hz visual cadence.
const MAX_EMITTERS := 128 # Authored peak budget; living-effects benchmark evidence.
const Particles = preload("res://scripts/living_particles.gd")
const Atlas = preload("res://scripts/living_effects_atlas.gd")
const Volume = preload("res://scripts/blast_pixel_volume.gd")
var volume = Volume.new()
var particles = Particles.new()
var atlas = Atlas.new()
var emitters: Array = []
var rng := RandomNumberGenerator.new()
var remainder := 0.0
var serial := 0
var emitted := 0
var clock := 0
var pending: Array = [] # Authored tracer arrivals: [step, point, material].
var shake := 0.0 # Presentation-only camera jolt, logical px.
var separate_light := false # Scene supplies an additive layer calling draw_light().


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
	volume.add(kind,point,direction.normalized(),scale)
	if explosive or kind in ["impact","sparks","shot","melee","snow"]:
		_burst(emitter,48 if explosive else 16)
	if explosive or kind == "impact":
		# White-hot first frames, additive bloom and a flattened ground shock.
		var size := 1.0 if explosive else 0.55
		particles.launch("flash",point,Vector2.ZERO,3,Vector2(16,12)*size*scale,Color.WHITE,scale,rng.randf_range(0,TAU))
		particles.items.back().radial = true
		particles.launch("glow",point,Vector2.ZERO,12 if explosive else 7,Vector2.ONE*30*size*scale,Color("#ffb45a"),scale)
		particles.launch("ring",point+Vector2(0,4)*scale,Vector2.ZERO,14,Vector2(30,9)*size*scale,Color("#fff1c2"),scale)
		for index in (8 if explosive else 3): # burning embers trailing soot
			var velocity := Vector2.from_angle(rng.randf_range(PI*1.1,PI*1.9))*rng.randf_range(40,95)*scale
			particles.launch("ember",point,velocity,rng.randi_range(45,80),Vector2.ONE*0.75*scale,Color("#ffb347"),scale)
			particles.items.back().trail = true
	# Machine-gun rounds come from the rotary rig (round()); source bursts add gas.
	if kind == "cannon":
		var aim := direction.normalized()
		particles.launch("flash",point,Vector2.ZERO,4,Vector2(9,7)*scale,Color.WHITE,scale,aim.angle())
		particles.launch("glow",point,Vector2.ZERO,6,Vector2.ONE*14*scale,Color("#ffb45a"),scale)
		particles.launch("ring",point,Vector2.ZERO,10,Vector2(16,6)*scale,Color("#fff1c2"),scale)
		particles.launch("projectile",point,aim*600*scale,12,Vector2(10,0.75)*scale,Color("#fff1c2"),scale)
		for puff in 6: # Muzzle-brake gas thrown sideways, then drifting.
			var side := Vector2(-1 if puff%2 == 0 else 1,0)
			particles.launch("steam",point+aim*2,(side*rng.randf_range(20,45)+aim*rng.randf_range(5,25)+Vector2(0,-6))*scale,rng.randi_range(60,95),Vector2(5,5)*scale,Color(0.84,0.85,0.88,0.6),scale)
	shake = minf(1.5,shake+{"destroy":1.5,"dynamite":1.25,"explosion":1.25,"rocket-impact":1.5,"cannon":0.6,"impact":0.9}.get(kind,0.0))
	_plume(emitter)


# One authored rotary-gun round: flash, tracer, brass and arrival ricochet.
func fire_round(point: Vector2, direction: Vector2, number: int, heat: float, floor_y: float, reach: float, armour: bool, breech := Vector2.INF) -> void:
	serial += 1
	rng.seed = hash(["round",point,serial])
	var aim := direction.normalized().rotated(rng.randf_range(-0.03,0.03)) # source: authored tracer cone.
	particles.launch("flash",point,Vector2.ZERO,2,Vector2(rng.randf_range(5,8),rng.randf_range(3,4.5)),Color.WHITE,1.0,aim.angle()+rng.randf_range(-0.4,0.4))
	particles.items.back().radial = direction.y > 0 # aimed at the viewer: seen head-on
	particles.launch("glow",point,Vector2.ZERO,3,Vector2.ONE*rng.randf_range(7,9),Color("#ffb45a"))
	var tracer := number%3 == 0 # source: authored one-in-three tracer loading.
	var speed := 900.0 # source: authored logical px/s, reads as a streak at50Hz.
	var life := maxi(1,ceili(reach/speed/STEP))
	particles.launch("projectile",point,aim*speed,life,Vector2(14 if tracer else 9,0.75 if tracer else 0.5),Color("#fff1c2") if tracer else Color(1,0.85,0.6,0.45))
	pending.append([clock+life,point+aim*reach,"sparks" if armour else "snow"])
	# Spent brass: thrown right from the breech, tumbling, bouncing on the roof.
	var eject := Vector2(rng.randf_range(14,32),rng.randf_range(-38,-22))
	var origin := breech if breech != Vector2.INF else point+Vector2(1.5,-1)
	particles.launch("casing",origin,eject,rng.randi_range(110,160),Vector2(1.75,0.75),Color("#d9a648"),1.0,rng.randf_range(0,TAU),floor_y+rng.randf_range(-0.5,0.5))
	if number%3 == 1 or heat > 0.6:
		particles.launch("steam",point,Vector2(rng.randf_range(-4,4),-rng.randf_range(5,10)),rng.randi_range(35,60),Vector2.ONE*(2.5+heat*2.5),Color(0.86,0.87,0.9,0.4))


func fragments(point: Vector2, colors: Array) -> void:
	# The actual removed wagon texels supply fragment material colors.
	for color in colors:
		particles.launch("debris",point,Vector2(rng.randf_range(-45,45),rng.randf_range(-65,-15)),75,Vector2(rng.randf_range(0.5,1.25),rng.randf_range(0.25,0.75)),color)


func advance(seconds: float, before_step := Callable()) -> void:
	if not is_finite(seconds) or seconds <= 0: return
	remainder += seconds
	while remainder >= STEP or is_equal_approx(remainder,STEP):
		remainder = maxf(0,remainder-STEP)
		# Same50Hz step drives rigs and particles, so births never depend on display rate.
		if before_step.is_valid(): before_step.call()
		clock += 1
		shake *= 0.8
		for hit in pending.filter(func(h):return h[0] <= clock):
			_ricochet(hit[1],hit[2])
		pending = pending.filter(func(h):return h[0] > clock)
		particles.step()
		volume.step()
		for emitter in emitters:
			emitter.age += 1
			if emitter.age % 4 == 0 and emitter.age < emitter.duration/2:
				_plume(emitter)
		emitters = emitters.filter(func(e):return e.age < e.duration)


func draw(canvas: CanvasItem, offset := Vector2.ZERO) -> void:
	if not atlas.loaded: atlas.load_art()
	volume.draw(canvas,offset)
	particles.draw(canvas,atlas,offset,separate_light)


func draw_light(canvas: CanvasItem, offset := Vector2.ZERO) -> void:
	particles.draw_light(canvas,offset)


func clear() -> void:
	emitters.clear()
	particles.items.clear()
	volume.clear()
	pending.clear()
	remainder = 0
	serial = 0
	emitted = 0
	clock = 0
	shake = 0


# Deterministic jolt from the visual clock; draw offset only, never input or rules.
func shake_offset() -> Vector2:
	if shake < 0.05: return Vector2.ZERO
	return (Vector2(sin(clock*2.7),cos(clock*3.3))*shake*4).round()/4


func _ricochet(point: Vector2, material: String) -> void:
	rng.seed = hash(["ricochet",point,clock])
	if material == "sparks":
		for spark in 5:
			particles.launch("spark",point,Vector2.from_angle(rng.randf_range(PI,TAU))*rng.randf_range(25,60),rng.randi_range(8,16),Vector2.ONE*0.5,Color("#ffd27a"))
	else:
		for grain in 4:
			particles.launch("snow",point,Vector2(rng.randf_range(-14,14),rng.randf_range(-30,-12)),rng.randi_range(20,35),Vector2.ONE*0.5,Color("#e8f0f5"))
		particles.launch("dust",point,Vector2(0,-4),30,Vector2.ONE*4,Color(1,1,1,0.5))


func _plume(emitter: Dictionary) -> void:
	if emitter.explosive or emitter.gun or emitter.kind == "impact": return
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
		particles.launch(material,emitter.point,velocity,45 if material == "spark" else 75,Vector2.ONE*rng.randf_range(0.25,0.75)*emitter.scale,Color("#ffd27a") if material == "spark" else Color("#dbe5ea"),emitter.scale)
