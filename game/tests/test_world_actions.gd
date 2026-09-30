extends SceneTree

const World = preload("res://scripts/world_actions.gd")
const Network = preload("res://scripts/rail_network.gd")
const Journey = preload("res://scripts/train_journey.gd")
const Wagons = preload("res://scripts/train_wagons.gd")
const EngineState = preload("res://scripts/engine_state.gd")
const Trade = preload("res://scripts/city_trade.gd")
const Data = preload("res://scripts/world_data.gd")
const Workshop = preload("res://scripts/station_workshop.gd")
const CityScreen = preload("res://scripts/city_screen.gd")

var failures: Array[String] = []
var changed := 0
var town_id := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var data = Data.new()
	_check(data.load_from_project(ProjectSettings.globalize_path("res://").trim_suffix("/")), "reference map loads")
	if not failures.is_empty():
		_finish()
		return
	var network = Network.new()
	network.load_bytes(data.map_bytes)
	_check(network.entry_boundary(Vector2i(11, 10)) == "story trigger", "standalone network retains uninstalled whale boundary")
	network.campaign_entry_enabled = true
	_check(network.entry_boundary(Vector2i(11, 10)).is_empty(), "campaign pre-entry capability permits resolved whale step")
	_check(network.entry_boundary(Vector2i(152, 48)) == "special site", "campaign capability retains unrevealed slope tile boundary")
	_check(network.entry_boundary(Vector2i(32, 67)) == "station", "capability preserves unresolved drill station dispatch")
	network.campaign_entry_enabled = false
	var journey = Journey.new()
	journey.network = network
	var wagons = Wagons.new()
	var engine = EngineState.new()
	var trade = Trade.new()
	_check(trade.load_from_project(ProjectSettings.globalize_path("res://").trim_suffix("/")), "commerce loads")
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	trade.reset(rng)
	var world = World.new()
	world.attach(journey, wagons, engine, trade, rng)
	_test_mines(world, network)
	_test_management(world, wagons, engine)
	_test_map_writes(network, world, wagons)
	await _test_ui(world, trade, wagons, engine)
	_test_town(trade, wagons, engine)
	_finish()


func _test_mines(world, network) -> void:
	var stoup = preload("res://scripts/stoup_messages.gd").new()
	_check(world.tick_mines(3, stoup), "day3 tick applies to actual map")
	_check(stoup.pop().message_id == 1, "source discovery queues one-based mine slot")
	var phrases := {"title_closed": "CLOSED", "title_open": "OPEN", "ore_anthracite": " ANTHRACITE", "ore_lignite": " LIGNITE", "coordinates": "X:%s Y:%s", "date": "DAY:%s"}
	var report: Array[String] = world.mines.report(0, phrases)
	_check(report.size() == 3 and report[1] == "X:%s Y:%s" % [world.mines.records[0][0] + 40, world.mines.records[0][1]] and report[2] == "DAY:3", "mine report uses source coordinates and absolute creation day")
	var cell: Vector2i = world.mines.mine_cell(world.mines.records[0])
	_check(network.tile(cell) == 78, "actual mine cell enters map")
	var saved_network: Dictionary = network.snapshot()
	var saved_world: Dictionary = world.snapshot()
	var random_state: int = world.rng.state
	_check(not world.tick_mines(3, stoup) and world.rng.state == random_state and not stoup.has_pending(), "same-day replay cannot re-deplete/create, enqueue, or consume randomness")
	_check(not world.ask_mine(cell).is_empty() and world.engine.brake, "mine approach brakes and presents source question")
	_check(world.answer_mine(false) and network.tile(cell) == 78, "NO leaves mine record/map unchanged")
	world.ask_mine(cell)
	_check(world.answer_mine(true) and network.tile(cell) == 78, "YES waits for scene close")
	var pending: Dictionary = world.snapshot()
	_check(world.restore(pending) and world.close_mine(), "pending scene save resumes at close")
	_check(network.tile(cell) == 79 and world.mines.records[0][3] == -1, "close writes depleted mine and wealth sentinel")
	_check(not world.close_mine(), "close cannot repeat reversal")
	_check(network.restore(saved_network) and world.restore(saved_world), "map and mine table restore together")
	var serialized: Variant = JSON.parse_string(JSON.stringify(saved_world))
	_check(world.restore(serialized) and world.snapshot() == saved_world, "JSON roundtrip restores integral mine day without float modulo")
	var bad: Dictionary = saved_world.duplicate(true)
	bad.last_mine_day = 3.5
	_check(not world.restore(bad) and world.snapshot() == saved_world, "fractional snapshot rejected atomically")
	bad = saved_world.duplicate(true)
	bad.visited_cities = [46]
	_check(not world.restore(bad), "unknown city rejected")
	world.visit_city(17)
	world.visit_city(17)
	_check(world.visited_cities == [17], "visited city mark idempotent")


func _test_management(world, wagons, engine) -> void:
	wagons.wagons = [[1,0,0,0], [21,0,0,0], [8,1,0,0], [13,2,0,0], [17,3,1,0]]
	engine.lignite = 500
	var management = world.management
	_check(management.repair_price(2) == 60 and management.repair_price(3) == 160, "GLIEU price times damage")
	_check(not management.repair(2, false) and engine.lignite == 500, "repair NO no charge")
	_check(management.repair(2, true) and engine.lignite == 440 and wagons.wagons[2][1] == 0, "repair OK charges once")
	_check(not management.repair(2, true) and engine.lignite == 440, "undamaged wagon cannot charge again")
	_check(management.repair_refusal(4) == 87, "scrap irreparable")
	engine.lignite = 1
	_check(management.repair_refusal(3) == 50 and not management.repair(3, true), "no money no repair")
	_check(management.remove_refusal(0) == 88 and management.remove_refusal(1) == 88, "locomotive and nonquantity3 tender protected")
	_check(management.move(2, 0) and wagons.wagons[0][0] == 8, "move inserts all four fields at destination")
	_check(management.move(0, 3) and wagons.wagons[3][0] == 8, "forward move mirrors unchanged destination index")
	_check(management.remove(4, true) and wagons.count() == 4, "remove shrinks consist")
	_check(management.equipment_flags().launcher, "intact launcher prepares missile access")
	_check(not management.move(-1,0) and not management.remove(-1,true), "invalid selection cannot mutate")


func _test_map_writes(network, world, wagons) -> void:
	wagons.wagons = [[1,0,0,0], [8,0,0,0]]
	_check(world.before_entry(Vector2i(32,67)) and network.tile(Vector2i(32,67)) == 2, "THE DRILL at end opens exact tunnel cell")
	_check(not world.before_entry(Vector2i(32,67)), "drill mutation once")
	_check(network.set_campaign_tile(Vector2i(28,67),54), "verified campaign reveal accepted")
	_check(not network.set_campaign_tile(Vector2i(100,60),66), "unverified arbitrary tile write rejected")
	var saved: Dictionary = network.snapshot()
	_check(network.restore(saved), "drill/campaign mutations persist")
	var before: Dictionary = network.snapshot()
	_check(not network.apply_mine_writes({Vector2i(12,62):20, Vector2i(-1,0):78}) and network.snapshot() == before, "invalid mine batch is atomic")
	var bad: Dictionary = saved.duplicate(true)
	bad.switches["12,62"] = 2.5
	_check(not network.restore(bad), "map rejects fractional tile values")


func _test_ui(world, trade, wagons, engine) -> void:
	wagons.wagons = [[1,0,0,0], [21,0,0,0], [8,1,0,0], [13,0,0,0]]
	engine.lignite = 500
	var scene = Workshop.new()
	scene.management = world.management
	scene.trade = trade
	scene.size = Vector2(1280,800)
	scene.cargo_changed.connect(func(): changed += 1)
	root.add_child(scene)
	await process_frame
	scene.open(Vector2i(100,40))
	_check(scene.title == "BALKHACH STATION", "source coordinate station title")
	_click(scene, Vector2(145,29)) # REPAIR banner.
	_click(scene, Vector2(90,50)) # slot2.
	_check(scene.confirmation and scene.selected == 2, "native click opens repair confirmation")
	_click(scene, Vector2(185,134))
	_check(changed == 1 and engine.lignite == 440, "native confirm emits cargo change and debits")
	_click(scene, Vector2(30,29)) # MOVE.
	_click(scene, Vector2(120,50)) # slot3.
	_click(scene, Vector2(35,50)) # slot0.
	_check(wagons.wagons[0][0] == 13 and changed == 2, "native move changes actual consist")
	scene.queue_free()
	await process_frame


func _test_town(trade, wagons, engine) -> void:
	var scene = CityScreen.new()
	scene.trade = trade
	scene.wagons = wagons
	scene.engine = engine
	scene.town_message_requested.connect(func(id): town_id = id)
	scene.city = 17
	scene.kind = 1
	scene.town_information(50)
	_check(town_id == 1, "TOWN option50 exact texte2k mapping")
	scene.city = 23
	scene.town_information(51)
	_check(town_id == 14, "TOWN option51 exact last-town mapping")
	scene.free()


func _click(scene, point: Vector2) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	event.position = scene.canvas_rect().position + point * scene.canvas_rect().size.x / 320
	scene._gui_input(event)


func _check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)


func _finish() -> void:
	for failure in failures:
		push_error(failure)
	if failures.is_empty():
		print("PASS: real-map mines, close/resume, drill, management costs, native workshop actions and TOWN")
	quit(0 if failures.is_empty() else 1)
