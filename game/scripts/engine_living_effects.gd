extends RefCounted

# MIT. Authored furnace ambience on EngineRoomArt's1600×1000 composition.
# Source: FIRE_OPENING and original steam valves(416,270)/(1119,270).
# Pulse and extent choices are visual recipes, reviewed in native captures.
const Effects = preload("res://scripts/living_effects.gd")
const PULSE := 15 # Authored one pulse every0.3seconds at visual50Hz.
var effects = Effects.new()
var remainder := 0.0
var tick := 0


func advance(seconds: float, engine) -> void:
	if engine == null or not is_finite(seconds) or seconds <= 0: return
	remainder += seconds
	while remainder >= Effects.STEP or is_equal_approx(remainder,Effects.STEP):
		remainder = maxf(0,remainder-Effects.STEP)
		effects.advance(Effects.STEP)
		tick += 1
		if tick % PULSE != 0: continue
		if engine.pressure_reserve > 0:
			for point in [Vector2(416,270),Vector2(1119,270)]:
				effects.add("steam",point,Vector2.UP,3.0)
		if engine.heat > 0 and engine.lignite_rate+engine.anthracite_rate > 0:
			# Embers start inside the fire opening, not on the stoker's face.
			effects.particles.launch("ember",Vector2(800,650),Vector2(-35,-100),40,Vector2(3,3),Color("#ffc675"),3.0)
			effects.particles.launch("ember",Vector2(850,650),Vector2(45,-130),35,Vector2(3,3),Color("#ffb54e"),3.0)


func draw(canvas: CanvasItem) -> void:
	effects.draw(canvas)
