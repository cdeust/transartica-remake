extends SceneTree

const Model = preload("res://scripts/launcher_model.gd")
const Geometry = preload("res://scripts/launcher_geometry.gd")
const Snapshot = preload("res://scripts/launcher_snapshot.gd")
const Enemies = preload("res://scripts/enemy_trains.gd")
const Wagons = preload("res://scripts/train_wagons.gd")
var checks := 0


func _init() -> void:
	call_deferred("run")


func check(value: bool) -> void:
	assert(value)
	checks += 1


func run() -> void:
	var enemies = Enemies.new()
	var wagons = Wagons.new()
	wagons.wagons.append([13,0,0,0])
	wagons.wagons.append([14,0,2,2])
	var origin := Vector2i(80,40)
	var model = Model.new()
	check(model.distance() == 50)
	check(model.action(101,origin,enemies) and model.bearing == 31)
	check(model.action(102,origin,enemies) and model.bearing == 0)
	check(not model.action(108,origin,enemies))
	for index in 4:
		for tick in 10:
			model.action(103+index,origin,enemies)
	check(model.distance() == 50)
	for bearing in 32:
		check(Geometry.ANGLES.has(Geometry.angle(bearing)))
	check(Geometry.angle(0) == 90 and Geometry.angle(8) == 0 and Geometry.angle(16) == 270 and Geometry.angle(24) == 180)
	enemies.slots[0] = [1,40,33,2,0,0,0,10]
	enemies.slots[1] = [1,40,33,2,0,0,0,20]
	var hit := Geometry.calculate(0,50,origin,enemies)
	check(hit.target == 0 and hit.delta == [0,112] and hit.count == 14)
	enemies.slots[0][0] = 2
	check(Geometry.calculate(0,50,origin,enemies).target == 1)
	enemies.slots[0] = [0,40,33,0,0,0,0,0]
	check(Geometry.calculate(0,50,origin,enemies).target == 0) # source includes STATE0.
	enemies.slots[0] = [1,40,33,2,0,0,0,10]
	model = Model.new()
	model.action(107,origin,enemies)
	for tick in 5: model.step()
	check(model.phase == "armed" and not model.action(103,origin,enemies))
	model.action(107,origin,enemies)
	for tick in 5: model.step()
	check(model.phase == "aim")
	model.action(107,origin,enemies)
	for tick in 5: model.step()
	check(model.action(108,origin,enemies))
	while true:
		var data := {"version":1,"active":true,"visible":true,"paused":false,"state":model.snapshot()}
		check(Snapshot.validate(JSON.parse_string(JSON.stringify(data)),wagons,enemies,origin))
		var resumed = Model.new()
		resumed.restore(Snapshot.normalized(data.state))
		check(resumed.snapshot() == model.snapshot())
		if model.phase == "report": break
		model.step()
		if model.phase in ["impact","report"] and not model.removed:
			enemies.remove(model.geometry.target)
			model.removed = true
	check(model.status == 2 and enemies.slots[0] == [2,0,0,0,0,0,0,0] and wagons.wagons[-1][3] == 2)
	var outcomes := []
	for rate in [30,60,144]:
		var flight = Model.new()
		flight.phase = "armed"
		flight.action(108,origin,Enemies.new())
		for frame in rate*30: flight.advance(1.0/rate)
		var state := flight.snapshot()
		state.erase("accumulator")
		outcomes.append(state)
	check(outcomes[0] == outcomes[1] and outcomes[1] == outcomes[2])
	print("PASS: launcher model ",checks," source geometry/phase/restore/cadence assertions")
	quit()
