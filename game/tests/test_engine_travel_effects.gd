extends SceneTree

# MIT. Frame-cadence and rigid-registration regressions. Reference measurements:
# authored hero438×1886 crop, stack centers(149,1296)/(287,1296).
const EngineState = preload("res://scripts/engine_state.gd")
const Furnace = preload("res://scripts/engine_living_effects.gd")
const Travel = preload("res://scripts/travel_living_effects.gd")
const World = preload("res://scripts/travel_world.gd")
const Renderer = preload("res://scripts/train_renderer.gd")
const Rails = preload("res://scripts/rail_network.gd")
var checks := 0

class History:
	extends RefCounted
	var heading := 0
	var origin := Vector2.ZERO
	func distance_travelled() -> float: return 0.0
	func sample_behind(distance: float) -> Dictionary:
		var direction := Vector2(Rails.DELTAS[heading]).normalized()
		return {"ok":true,"position":origin-direction*distance,"heading":heading}

class Session:
	extends RefCounted
	var engine

class View:
	extends RefCounted
	const CELL_PIXELS = World.CELL_PIXELS
	const WORLD_EAST = World.WORLD_EAST
	var journey = History.new()
	var session = Session.new()
	var train_renderer = Renderer.new()
	var consist = preload("res://scripts/train_consist.gd").new()
	var _visual_initialized := false
	var _visual_arc := 0.0
	func _project(point: Vector2) -> Vector2: return World.WORLD_EAST*point.x+World.WORLD_SOUTH*point.y

func _init() -> void:
	run.call_deferred()

func check(value: bool, label: String) -> void:
	assert(value,label)
	checks += 1

func run() -> void:
	var engine = EngineState.new()
	engine.heat = 1000
	engine.pressure_reserve = 500
	engine.lignite_rate = 1
	var before: Dictionary = engine.snapshot()
	var results := []
	for rate in [30,60,144]:
		var effect = Furnace.new()
		for frame in rate*3: effect.advance(1.0/rate,engine)
		check(engine.snapshot() == before,"furnace presentation cannot consume source fuel or pressure")
		check(effect.tick == 150,"three seconds gives original50Hz visual ticks")
		results.append([effect.effects.emitters.duplicate(true),effect.effects.particles.items.duplicate(true)])
	check(results[0] == results[1] and results[1] == results[2],"furnace particles identical at30/60/144Hz")
	var view = View.new()
	view.session.engine = engine
	check(view.train_renderer.load_assets(),"actual hero registration loaded")
	view.journey.origin = Vector2(80,40)
	for heading in Rails.DELTAS:
		if Rails.DELTAS[heading] == Vector2i.ZERO: continue
		view.journey.heading = heading
		var effect = Travel.new()
		effect.advance(view,0.3)
		check(effect.effects.emitters.size() == 2,"two registered stacks for heading"+str(heading))
		var pose: Dictionary = view.train_renderer.poses(view,view.journey,view.consist,0.0)[0]
		var frame: Dictionary = view.train_renderer.frame_for("locomotive")
		var front: Vector2 = view._project(pose.front+Vector2.ONE*0.5)
		var rear: Vector2 = view._project(pose.rear+Vector2.ONE*0.5)
		var factor: float = view.CELL_PIXELS*Renderer.WAGON_CELL_RATIO/view.train_renderer.texels_per_cell
		var transform: Transform2D = view.train_renderer.registration(frame,(front+rear)*0.5,(front-rear).angle()-PI/2,factor)
		for index in 2:
			var measured := Vector2((149.0 if index == 0 else 287.0)/438,1296.0/1886)
			var expected: Vector2 = transform*(frame.draw_rect.position+frame.draw_rect.size*measured)
			check(effect.effects.emitters[index].point.is_equal_approx(expected),"stack uses same rigid vehicle pose in heading"+str(heading))
		check(engine.snapshot() == before,"travel smoke preserves engine state")
	print("PASS: engine/travel effects ",checks," cadence and registration checks")
	quit(0)
