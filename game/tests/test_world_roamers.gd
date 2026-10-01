extends SceneTree
const Roamers = preload("res://scripts/world_roamers.gd")
const Motion = preload("res://scripts/roamer_motion.gd")
const Rails = preload("res://scripts/rail_network.gd")
const Fauna = preload("res://scripts/campaign_fauna.gd")
const Wagons = preload("res://scripts/train_wagons.gd")
var failures := 0
func check(ok: bool, label: String) -> void:
	if not ok:
		failures += 1
		push_error(label)
func _initialize() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 714
	var expected := RandomNumberGenerator.new()
	expected.seed = 714
	var rows := []
	for index in 10:
		rows.append([expected.randi_range(0,129)-30,expected.randi_range(0,59)+5,0,expected.randi_range(1,9),expected.randi_range(0,39)+40,expected.randi_range(0,44)+5])
	var wolf: Vector2i = Roamers.STARTS[expected.randi_range(0,10)]
	var nomad := expected.randi_range(0,10)
	while Roamers.STARTS[nomad] == wolf:
		nomad = expected.randi_range(0,10)
	var model := Roamers.new()
	var fauna := Fauna.new()
	model.initialize(rng,fauna)
	check(model.herds == rows and fauna.cell == wolf and model.nomad_cell() == Roamers.STARTS[nomad] and rng.state == expected.state,"TABLE startup source draw order")
	var map := PackedByteArray()
	map.resize(Rails.WIDTH*Rails.HEIGHT)
	map.fill(2)
	var rails := Rails.new()
	rails.load_bytes(map)
	var obstacle := Vector2i(41,40)
	map[obstacle.x*Rails.HEIGHT+obstacle.y] = 35
	rails.load_bytes(map)
	check(Motion.step(Vector2i(40,40),6,4,rails).cell == Vector2i(40,40),"nomad bounces")
	check(Motion.step(Vector2i(40,40),6,2,rails).cell == obstacle,"herd skips terrain bounce")
	check(Motion.turn(obstacle,6,0,[],rails,rng) == 6,"phase zero never turns")
	var restored := Roamers.new()
	var saved: Dictionary = JSON.parse_string(JSON.stringify(model.snapshot()))
	check(restored.restore(saved),"JSON restore")
	var resumed_rng := RandomNumberGenerator.new()
	resumed_rng.seed = rng.seed
	resumed_rng.state = rng.state
	for cycle in 130:
		model.advance(rails,rng)
		restored.advance(rails,resumed_rng)
	check(model.snapshot() == restored.snapshot() and rng.state == resumed_rng.state,"restored movement deterministic")
	var before := restored.snapshot()
	saved.herds[0][3] = 0
	check(not restored.restore(saved) and restored.snapshot() == before,"malformed restore atomic")
	var cell := model.nomad_cell()
	check(model.encounter(cell,rails,rng) == "nomad_question","actual nomad presence opens question")
	var cargo := Wagons.new()
	check(model.answer(false,rng,cargo) and model.pending == "" and model.nomad_cell() in Roamers.STARTS,"decline relocates nomad")
	check(model.encounter(model.nomad_cell(),rails,rng) == "nomad_question" and model.answer(true,rng,cargo) and model.pending == "nomad_trade","accept nomads")
	model.close()
	var herd_cell := model.herd_cell(0)
	check(model.encounter(herd_cell,rails,rng) == "herd_question","actual herd presence opens question")
	cargo.wagons = [[1,0,0,0],[7,0,0,0],[23,0,0,10]]
	var quantity: int = model.herds[0][5]
	check(model.answer(true,rng,cargo),"commission hunting")
	check(model.finish_hunt(cargo) and model.caught == mini(quantity/10+1,3) and cargo.wagons[1][3] == model.caught,"source hunt capture and cargo")
	var hunt: Dictionary = model.snapshot()
	check(not model.finish_hunt(cargo) and model.snapshot() == hunt,"hunt cannot duplicate reward")
	var hunt_restored := Roamers.new()
	check(hunt_restored.restore(JSON.parse_string(JSON.stringify(hunt))) and not hunt_restored.finish_hunt(cargo),"resumed result cannot reward twice")
	print("PASS: world roamers startup, movement, encounters and atomic resume" if failures == 0 else "FAIL: world roamers %d" % failures)
	quit(failures)
