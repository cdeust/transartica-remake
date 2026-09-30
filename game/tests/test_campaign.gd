extends SceneTree

const Campaign = preload("res://scripts/campaign_state.gd")
const Session = preload("res://scripts/campaign_session.gd")
const Wagons = preload("res://scripts/train_wagons.gd")
const Stoup = preload("res://scripts/stoup_messages.gd")
const Car = preload("res://scripts/inspection_car.gd")
var failures: Array[String] = []

class TestNetwork extends RefCounted:
	var cells := {}
	func tile(cell: Vector2i) -> int:
		return cells.get(cell, 2)
	func set_campaign_tile(cell: Vector2i, code: int) -> bool:
		cells[cell] = code
		return true
	func turn(_cell: Vector2i, heading: int) -> int:
		return heading

class Trade extends RefCounted:
	var spy_slots: Array = []
	func _init() -> void:
		spy_slots.resize(20)
		spy_slots.fill(0)

func _init() -> void:
	var state = Campaign.new()
	var network = TestNetwork.new()
	var wagons = Wagons.new()
	var stoup = Stoup.new()
	_check(state.load_data(), "private campaign source data loaded")
	_check(not state.submit_code("58947").accepted, "delivery number accepted only at Oslo")
	_check(state.station(-2, network).messages == [86, 87] and state.urga_key, "first Urga meeting gives key")
	state.dismiss()
	_check(state.station(-2, network).messages == [88], "repeat Urga has repeat dialogue")
	state.dismiss()
	_check(state.station(-4, network).messages == [51], "mausoleum supplies delivery number")
	state.dismiss()
	state.station(-3, network)
	_check(not state.submit_code("59847", stoup).accepted, "wrong delivery code has no effect")
	var checkpoint: Dictionary = JSON.parse_string(JSON.stringify(state.snapshot()))
	var resumed = Campaign.new()
	resumed.data = state.data
	_check(resumed.restore(checkpoint) and resumed.snapshot() == state.snapshot(), "interrupted Oslo restored exactly")
	_check(resumed.submit_code("58947", stoup).accepted and resumed.delivery_open and stoup.pop().message_id == 126, "ECS code opens delivery and SOS")
	resumed.dismiss()
	resumed.station(-3, network)
	_check(resumed.submit_code("58947", stoup).accepted and not stoup.has_pending(), "repeat code does not duplicate SOS")
	resumed.dismiss()
	_check(not resumed.prepare_entry(Vector2i(11, 10), 6, wagons, network).is_empty(), "whale without intact harpoon asks before death")
	resumed.choose_whale(false)
	_check(resumed.ending == "", "whale decline survives")
	wagons.wagons.append([9, 0, 0, 0])
	_check(resumed.prepare_entry(Vector2i(11, 10), 6, wagons, network).get("reverse", false) and not resumed.whale_present, "intact harpoon removes whale and reverses")
	resumed.dismiss()
	_check(resumed.prepare_entry(Vector2i(11, 10), 6, wagons, network).is_empty(), "whale does not repeat")
	_check(resumed.prepare_entry(Vector2i(152, 48), 1, wagons, network).scene == "slope", "loaded six-plus wagon train needs boiler")
	resumed.dismiss()
	wagons.wagons.append([25, 3, 0, 0])
	_check(resumed.prepare_entry(Vector2i(152, 48), 1, wagons, network).is_empty(), "original boiler test does not check damage")
	var trade = Trade.new()
	trade.spy_slots[0] = 1
	wagons.wagons.append([22, 0, 0, 1])
	var slot: int = resumed.send_spy(Vector2i(65, 20), Vector2i(64, 20), wagons, trade)
	_check(slot == 0 and resumed.spies[0][0] == 2 and wagons.wagons.back()[3] == 0, "first aboard spy departs and load decremented")
	_check(resumed.sabotage(slot, network, stoup).is_empty(), "travelling spy cannot dynamite")
	resumed.advance_spies(network, trade, stoup)
	resumed.advance_spies(network, trade, stoup)
	_check(resumed.spies[0][0] == 2, "spy movement waits original three calls")
	checkpoint = JSON.parse_string(JSON.stringify(resumed.snapshot()))
	var travel_resume = Campaign.new()
	travel_resume.data = state.data
	_check(travel_resume.restore(checkpoint), "interrupted spy journey restores")
	travel_resume.advance_spies(network, trade, stoup)
	_check(travel_resume.spies[0][0] == 3 and network.tile(Vector2i(65, 20)) == -124 and stoup.pop().message_id == 127, "arrival discovers central and announces127")
	_check(travel_resume.sabotage(0, network, stoup).central and stoup.pop().message_id == 125, "posted spy destroys central and announces125")
	_check(travel_resume.sabotage(0, network, stoup).is_empty(), "same spy cannot duplicate dynamite")
	network.cells[Vector2i(157, 68)] = 36
	travel_resume.prepare_entry(Vector2i(157, 68), 6, wagons, network)
	_check(network.tile(Vector2i(157, 68)) == 3, "central flag opens Gycode on entry")
	_check(travel_resume.station(-5, network).messages == [19] and travel_resume.ending == "sun", "power station restarts Sun")
	var death = Campaign.new()
	death.prepare_entry(Vector2i(11, 10), 6, Wagons.new(), network)
	_check(death.choose_whale(true).epitaph == 104 and death.ending == "death", "unsafe whale continuation original death104")
	for reason in range(100, 106):
		_check(death.die(reason).epitaph == reason, "death reason preserved")
	var before: Dictionary = travel_resume.snapshot()
	var invalid := before.duplicate(true)
	invalid.spies[0][0] = 4
	_check(not travel_resume.restore(invalid) and travel_resume.snapshot() == before, "invalid restore atomic")
	var session = Session.new()
	var session_data: Dictionary = session.snapshot()
	_check(Session.validate_snapshot(session_data), "session staged validation pure")
	session_data.presentation.input_code = "589"
	_check(session.restore(session_data), "partial delivery code accepted in snapshot")
	_test_car(network)
	for failure in failures:
		push_error(failure)
	if failures.is_empty():
		print("PASS: ECS campaign gate sequence, interrupted code/spy save-resume, central sabotage, Sun and six death causes, inspection cars")
	quit(0 if failures.is_empty() else 1)


func _test_car(network) -> void:
	var wagons = Wagons.new()
	wagons.wagons.append([17, 0, 3, 2])
	wagons.wagons.append([17, 0, 2, 1])
	network.cells[Vector2i(13, 62)] = 67
	var result: Dictionary = Car.launch(Vector2i(12, 62), 6, 0, 6, true, wagons, network)
	_check(result.message == 10 and result.cell == [13, 62], "missile car hits obstacle at exact next cell")
	_check(wagons.wagons[-2][3] == 1 and wagons.wagons[-1][3] == 0 and wagons.wagons[-1][2] == 0, "car+missile debit and empty goods clear")
	network.cells.clear()
	result = Car.launch(Vector2i(12, 62), 6, 0, 6, false, wagons, network)
	_check(result.message == 11 and result.path.size() == 33, "original100 cycles self destruct after33 steps")


func _check(ok: bool, label: String) -> void:
	if not ok:
		failures.append(label)
