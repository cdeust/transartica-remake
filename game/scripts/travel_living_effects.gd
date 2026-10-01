extends RefCounted

# MIT. Plumes anchored through the very same rigid vehicle registration.
# Sources: train_renderer.draw and measured hero stack centers in the1886px
# crop: (149,1296),(287,1296). Recipe scale is authored, not game physics.
const Effects = preload("res://scripts/living_effects.gd")
const STACKS := [Vector2(149.0/438,1296.0/1886),Vector2(287.0/438,1296.0/1886)]
const PULSE := 15 # Same authored furnace pulse cadence, one every0.3seconds.
var effects = Effects.new()
var remainder := 0.0
var tick := 0
var journey_identity := 0


func advance(view, seconds: float) -> void:
	if view.journey == null or not is_finite(seconds) or seconds <= 0: return
	if journey_identity != view.journey.get_instance_id():
		effects.clear()
		remainder = 0
		tick = 0
		journey_identity = view.journey.get_instance_id()
	remainder += seconds
	while remainder >= Effects.STEP or is_equal_approx(remainder,Effects.STEP):
		remainder = maxf(0,remainder-Effects.STEP)
		effects.advance(Effects.STEP)
		tick += 1
		if tick % PULSE == 0 and view.session.engine.heat > 0:
			_emit(view)


func _emit(view) -> void:
	var lag: float = maxf(0,view.journey.distance_travelled()-view._visual_arc) if view._visual_initialized else 0.0
	for vehicle in view.train_renderer.poses(view,view.journey,view.consist,lag):
		if vehicle.kind != "locomotive": continue
		var frame: Dictionary = view.train_renderer.frame_for(vehicle.kind)
		var front: Vector2 = view._project(vehicle.front+Vector2(0.5,0.5))
		var rear: Vector2 = view._project(vehicle.rear+Vector2(0.5,0.5))
		var rotation := (front-rear).angle()-PI*0.5
		var factor: float = view.CELL_PIXELS*view.train_renderer.WAGON_CELL_RATIO/view.train_renderer.texels_per_cell
		var transform: Transform2D = view.train_renderer.registration(frame,(front+rear)*0.5,rotation,factor)
		var rect: Rect2 = frame.draw_rect
		for stack in STACKS:
			effects.add("smoke",transform*(rect.position+rect.size*stack),Vector2.UP,1.2)


func draw(view) -> void:
	var zoom: float = view._effective_zoom()
	view.draw_set_transform(view.size*0.5+view.offset-view._project(view.camera_world)*zoom,0,Vector2.ONE*zoom)
	effects.draw(view)
	view.draw_set_transform_matrix(Transform2D.IDENTITY)
