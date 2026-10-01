extends RefCounted

# MIT. Presentation observes BERTA/CARTE phases; never advances source state.
# Authored exhaust and impact scale calibrated in living-ambience-20261001.md.
const Effects = preload("res://scripts/living_effects.gd")
const Geometry = preload("res://scripts/launcher_geometry.gd")
var effects = Effects.new()
var ignition = preload("res://scripts/rocket_ignition.gd").new()
var model_identity := 0
var phase := ""
var cursor := -1
var ascent := -1
var map_space := false
var trail := Vector2.INF # last exhaust emission, map pixels


func observe(model, seconds: float, launch_point: Vector2, flight := Vector2.INF) -> void:
	var identity: int = model.get_instance_id()
	var next_map: bool = model.phase in ["flight","impact","report"]
	if identity != model_identity or next_map != map_space:
		effects.clear()
		ignition.clear()
		phase = ""
		cursor = -1
		ascent = -1
		trail = Vector2.INF
	model_identity = identity
	map_space = next_map
	effects.advance(seconds)
	ignition.observe(seconds,launch_point,model.phase in ["launch","ascent"])
	if flight != Vector2.INF:
		# Continuous trail from the glided missile: one puff per2 map px travelled.
		var direction := Vector2.from_angle(deg_to_rad(-Geometry.angle(model.bearing)))
		var world := flight+Vector2(model.camera)*16
		if trail == Vector2.INF: trail = world
		while trail.distance_to(world) >= 2.0:
			trail = trail.move_toward(world,2.0)
			effects.add("rocket-exhaust",trail-direction*6,-direction,0.3)
	if model.phase == phase and model.cursor == cursor and model.ascent == ascent:
		return
	var entering: bool = model.phase != phase
	phase = model.phase
	cursor = model.cursor
	ascent = model.ascent
	if phase == "flight" and flight == Vector2.INF:
		var point := Vector2(Geometry.screen(model.geometry,Vector2i.ZERO,maxi(0,cursor-1)))
		var direction := Vector2.from_angle(deg_to_rad(-Geometry.angle(model.bearing)))
		effects.add("rocket-exhaust",point-direction*6,-direction,0.3)
	elif phase == "impact" and entering:
		var point := Vector2(Geometry.screen(model.geometry,Vector2i.ZERO,0,true))
		effects.add("rocket-impact" if model.status == 2 else "impact",point,Vector2.UP,1.15)


func draw(canvas: CanvasItem, camera: Vector2i) -> void:
	effects.draw(canvas,-Vector2(camera)*16 if map_space else Vector2.ZERO)
	if canvas.has_method("render_ignition"):
		canvas.render_ignition(ignition)
