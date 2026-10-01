extends SceneTree

# MIT. Source-valid BERTA trajectory from test_launcher_model.gd; observers must
# leave model and enemy state unchanged at every original callback.
const Model = preload("res://scripts/launcher_model.gd")
const Enemies = preload("res://scripts/enemy_trains.gd")
const Rocket = preload("res://scripts/rocket_living_effects.gd")
const Worksite = preload("res://scripts/worksite_ambience.gd")
var checks := 0


func _init() -> void:
	run.call_deferred()


func check(value: bool, label: String) -> void:
	assert(value,label)
	checks += 1


func run() -> void:
	var enemies = Enemies.new()
	enemies.slots[0] = [1,40,33,2,0,0,0,10]
	var model = Model.new()
	model.action(107,Vector2i(80,40),enemies)
	for tick in 5: model.step()
	check(model.action(108,Vector2i(80,40),enemies),"source fixture launches")
	var rocket = Rocket.new()
	var seen := {}
	while true:
		var state: Dictionary = model.snapshot()
		var enemy_state: Dictionary = enemies.snapshot()
		rocket.observe(model,3.0/50.0,Vector2(141,103))
		check(state == model.snapshot() and enemy_state == enemies.snapshot(),"presentation preserves source callback and enemies")
		seen[model.phase] = true
		if model.phase == "report": break
		model.step()
	check(seen.has("launch") and seen.has("ascent") and seen.has("flight") and seen.has("impact"),"all source phases observed")
	check(rocket.effects.emitters.any(func(e):return e.kind == "rocket-impact"),"hit produces authored blast")
	var count: int = rocket.effects.emitted
	rocket.observe(model,0.02,Vector2.ZERO)
	check(rocket.effects.emitted == count,"report observation cannot replay impact")
	var work = Worksite.new()
	work.advance(0.02,"mine",false)
	check(work.effects.emitted == 0,"question does not imply mining work")
	work.advance(0.02,"mine",true)
	check(work.effects.emitters.size() == 1 and work.effects.emitters[0].kind == "dust","accepted mine dust")
	work.advance(0.02,"crevasse",true)
	check(work.effects.emitters.size() == 2,"accepted works dust and sparks")
	work.advance(0.02,"crevasse",false)
	check(work.effects.emitters.is_empty(),"inactive work clears old work bursts")
	print("PASS: ambience ",checks," source isolation and phase checks")
	quit(0)
