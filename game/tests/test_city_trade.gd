extends SceneTree

const CityTrade = preload("res://scripts/city_trade.gd")
const TrainWagons = preload("res://scripts/train_wagons.gd")
const EngineState = preload("res://scripts/engine_state.gd")
const WorldData = preload("res://scripts/world_data.gd")

const KUWAIT := 24
const RAILS := 1
const WOOD := 7


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var failures: Array[String] = []
	var trade = CityTrade.new()
	if not trade.load_from_project(ProjectSettings.globalize_path("res://").trim_suffix("/")):
		push_error("private commerce table unavailable (python3 tools/build_commerce_data.py)")
		quit(1)
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	trade.reset(rng)
	_test_city_alignment(trade, failures)
	_test_mass(failures)
	_test_stock_init(trade, failures)
	_test_goods_purchase(trade, failures)
	_test_goods_sale(trade, failures)
	_test_other_markets(trade, failures)
	_test_persistence(trade, failures)
	_test_workshop(trade, failures)
	if failures.is_empty():
		print("PASS: glieu trade rules, wagon loading order, sale coal cap, money clamp, TIME wagon mass, persistence, workshop")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)


func _check(condition: bool, label: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(label)


func _test_mass(failures: Array[String]) -> void:
	var wagons = TrainWagons.new()
	_check(wagons.mass() == 1266, "TABLE train weighs 1266 (locomotive-rules.md)", failures)
	wagons.wagons[4][TrainWagons.QUANTITY] = 20
	_check(wagons.mass() == 1286, "a goods wagon adds its load (TIME 0x2bac)", failures)
	wagons.wagons[1][TrainWagons.QUANTITY] = 2
	_check(wagons.mass() == 1306, "a tender adds ten per unit (TIME 0x2bbd)", failures)


func _test_stock_init(trade, failures: Array[String]) -> void:
	var sold := 0
	var in_range := true
	for row in trade.data.stock_init.size():
		for goods in CityTrade.GOODS_KINDS:
			var cell: Array = trade.data.stock_init[row][goods]
			var value: int = trade.stock[row][goods]
			if int(cell[0]) >= 0:
				sold += 1
				in_range = in_range and value >= int(cell[0]) and value < int(cell[0]) + maxi(1, int(cell[1]))
			else:
				in_range = in_range and value == -1
	_check(sold == 94, "TABLE stocks 94 city goods (city-scripts.md §3)", failures)
	_check(in_range, "every stock lies in base + rnd(n)", failures)


func _test_goods_purchase(trade, failures: Array[String]) -> void:
	var wagons = TrainWagons.new()
	var engine = EngineState.new()
	trade.stock[0][RAILS - 1] = 30
	var rails: Dictionary = trade.offer(KUWAIT, CityTrade.COMMERCIAL, CityTrade.BUY, RAILS)
	_check(trade.price(rails) == 4, "KUWAIT sells rails at 4 (glieu 0xfcb)", failures)
	_check(trade.capacity(rails, wagons) == Vector2i(20, 0), "the TABLE goods wagon (type 17) holds 20 rails", failures)
	_check(trade.increment_refusal(rails, 20, wagons, engine) == CityTrade.NO_ROOM, "the 21st rail is refused (msg 51)", failures)
	engine.lignite = 10
	_check(trade.increment_refusal(rails, 1, wagons, engine) == 0, "a second rail is affordable with 10", failures)
	_check(trade.increment_refusal(rails, 2, wagons, engine) == CityTrade.NO_MONEY, "a third rail costs 12 > 10 (msg 50)", failures)
	trade.stock[0][RAILS - 1] = 2
	engine.lignite = 2000
	_check(trade.increment_refusal(rails, 2, wagons, engine) == CityTrade.STOCK_LIMIT, "no more than the city stock", failures)
	trade.stock[0][RAILS - 1] = 30
	trade.commit(rails, 5, wagons, engine)
	_check(engine.lignite == 1980, "purchase burns 5 x 4 lignite (glieu 0x555)", failures)
	_check(wagons.wagons[4] == [17, 0, RAILS, 5], "rails fill the type 17 wagon (glieu 0xa54)", failures)
	_check(trade.stock[0][RAILS - 1] == 25, "city stock falls by the quantity bought", failures)
	var wood: Dictionary = trade.offer(KUWAIT, CityTrade.COMMERCIAL, CityTrade.BUY, WOOD)
	_check(trade.capacity(wood, wagons).x == 0, "a wagon carrying rails does not accept wood (glieu 0x919)", failures)
	_check(trade.goods_list(KUWAIT, CityTrade.SELL, wagons) == [[RAILS, 5]], "sale list sums carried goods (glieu 0x1661)", failures)


func _test_goods_sale(trade, failures: Array[String]) -> void:
	var wagons = TrainWagons.new()
	var engine = EngineState.new()
	wagons.wagons[4] = [17, 0, RAILS, 5]
	var rails: Dictionary = trade.offer(KUWAIT, CityTrade.COMMERCIAL, CityTrade.SELL, RAILS)
	engine.lignite = 4500
	engine.anthracite = 500
	_check(trade.increment_refusal(rails, 0, wagons, engine) == CityTrade.NO_COAL_ROOM, "one tender holds 5000 coal in all (msg 54)", failures)
	engine.lignite = 1000
	_check(trade.increment_refusal(rails, 5, wagons, engine) == CityTrade.NOT_ENOUGH_LOAD, "cannot sell a sixth rail (msg 52)", failures)
	var stock_before: int = trade.stock[0][RAILS - 1]
	trade.commit(rails, 5, wagons, engine)
	_check(engine.lignite == 1010, "sale credits 5 x 2 lignite", failures)
	_check(wagons.wagons[4] == [17, 0, 0, 0], "an emptied wagon forgets its goods (glieu 0xc92)", failures)
	_check(trade.stock[0][RAILS - 1] == stock_before + 5, "sold goods return to a trading city", failures)
	wagons.wagons[4] = [17, 0, RAILS, 5]
	engine.lignite = 30999
	trade.commit(rails, 5, wagons, engine)
	_check(engine.lignite == 31000, "money is capped at 31000 (glieu 0x565)", failures)
	var buy_rails: Dictionary = trade.offer(KUWAIT, CityTrade.COMMERCIAL, CityTrade.BUY, RAILS)
	engine.lignite = 31500
	trade.commit(buy_rails, 1, wagons, engine)
	_check(engine.lignite == 31496, "a purchase is not clamped (glieu 0x555 jumps to 0x583)", failures)


func _test_other_markets(trade, failures: Array[String]) -> void:
	var wagons = TrainWagons.new()
	var engine = EngineState.new()
	var soldiers: Dictionary = trade.offer(5, CityTrade.GARRISON, CityTrade.BUY)
	_check(trade.price(soldiers) == 6 and trade.capacity(soldiers, wagons) == Vector2i(40, 10), "ABU DHABI enrols at 6 into the 10-soldier wagon", failures)
	trade.commit(soldiers, 3, wagons, engine)
	_check(wagons.wagons[5] == [23, 0, 0, 13] and engine.lignite == 1982, "three soldiers join the type 23 wagon", failures)
	_check(trade.offers_spies(8) and not trade.offers_spies(5), "spies only in cities 8 and 9", failures)
	var spies: Dictionary = trade.offer(8, CityTrade.GARRISON, CityTrade.SELL)
	_check(spies.mode == CityTrade.BUY and spies.spy, "the spy choice runs the purchase path (glieu 0x28d)", failures)
	_check(trade.entry_refusal(spies, wagons) == CityTrade.NO_ROOM, "no spy wagon (type 22) in the TABLE train", failures)
	var mammoths: Dictionary = trade.offer(1, CityTrade.MAMMOTH_FAIR, CityTrade.SELL)
	_check(trade.entry_refusal(mammoths, wagons) == CityTrade.NOTHING_TO_SELL, "no mammoth to sell (msg 18)", failures)
	_check(trade.offer(1, CityTrade.SLAVE_MARKET, CityTrade.BUY).is_empty(), "BHOPAL has no slave prices", failures)


func _test_persistence(trade, failures: Array[String]) -> void:
	var saved: Dictionary = JSON.parse_string(JSON.stringify(trade.snapshot()))
	var restored = CityTrade.new()
	_check(restored.restore(saved) and restored.snapshot() == trade.snapshot(), "stocks and spy files round-trip through JSON", failures)
	saved.stock[0][0] = 128
	_check(not restored.restore(saved), "a stock beyond a signed byte is refused", failures)
	var wagons = TrainWagons.new()
	var copy = TrainWagons.new()
	var encoded: Variant = JSON.parse_string(JSON.stringify(wagons.snapshot()))
	_check(copy.restore(encoded) and copy.snapshot() == wagons.snapshot(), "wagon table round-trips through JSON", failures)
	_check(not copy.restore([[26, 0, 0, 0]]), "unknown wagon type is refused", failures)


# VILLE.FIC record i must be glieu's L0x0c = i, and its kind must select a populated price table.
func _test_city_alignment(trade, failures: Array[String]) -> void:
	var world = WorldData.new()
	if not world.load_from_project(ProjectSettings.globalize_path("res://").trim_suffix("/")):
		failures.append("private city table unavailable")
		return
	var tables := {CityTrade.COMMERCIAL: "goods", CityTrade.MAMMOTH_FAIR: "mammoths", CityTrade.SLAVE_MARKET: "slaves", CityTrade.GARRISON: "soldiers"}
	var aligned := true
	for index in world.cities.size():
		var city: Dictionary = world.cities[index]
		aligned = aligned and String(city.name) == String(trade.data.city_names[index])
		if tables.has(int(city.kind)):
			aligned = aligned and trade.data[tables[int(city.kind)]].has(str(index))
	_check(world.cities.size() == 46 and aligned, "46 cities share glieu indices and each trading kind has its prices", failures)


# glieu 0x1905..0x21e7 (city-scripts evidence §2.4).
func _test_workshop(trade, failures: Array[String]) -> void:
	var sizes := []
	for city in range(10, 17):
		sizes.append(trade.workshop_list(city).size())
	_check(sizes == [8, 8, 5, 7, 6, 1, 8] and trade.workshop_list(9).is_empty(), "workshops only in cities 10..16, with 8/8/5/7/6/1/8 wagons", failures)
	_check(String(trade.data.city_names[10]) == "IN SALAH" and trade.workshop_list(10)[0] == [21, 100], "IN SALAH lists a tender at 100 first", failures)
	_check(String(trade.data.city_names[15]) == "RUM" and trade.workshop_list(15) == [[8, 800]], "RUM sells only THE DRILL at 800", failures)
	_check(trade.wagon_name(1) == "LOCOMOTIVE" and trade.wagon_name(21) == "TENDER" and trade.wagon_name(25) == "BOILER", "textek names types 1..25", failures)
	var wagons = TrainWagons.new()
	var engine = EngineState.new()
	engine.lignite = 10000
	var tender: Array = [21, 100]
	_check(trade.intact_tenders(wagons) == 1, "the TABLE train has one intact tender", failures)
	_check(trade.workshop_refusal(tender, 4, wagons, engine) == 0 and trade.workshop_refusal(tender, 5, wagons, engine) == CityTrade.TENDER_LIMIT, "at most six intact tenders, refused silently", failures)
	wagons.wagons[1][TrainWagons.STATE] = 3
	_check(trade.workshop_refusal(tender, 5, wagons, engine) == 0, "a scrap tender does not count", failures)
	wagons.wagons[1][TrainWagons.STATE] = 0
	engine.lignite = 299
	var drill: Array = [8, 800]
	_check(trade.workshop_refusal([7, 300], 0, wagons, engine) == CityTrade.NO_MONEY, "total + price must be affordable (msg 50)", failures)
	engine.lignite = 1600
	_check(trade.workshop_refusal(drill, 1, wagons, engine) == 0 and trade.workshop_refusal(drill, 2, wagons, engine) == CityTrade.NO_MONEY, "two drills cost 1600", failures)
	trade.buy_wagons(drill, 2, wagons, engine)
	_check(engine.lignite == 0 and wagons.count() == 8 and wagons.wagons[6] == [8, 0, 0, 0] and wagons.wagons[7] == [8, 0, 0, 0], "validation debits once and appends two drills", failures)
	_check(wagons.mass() == 1266 + 2 * 105, "bought wagons add their TIME base weight", failures)
	engine.lignite = 100000
	var cheap: Array = [7, 1]
	_check(trade.workshop_refusal(cheap, 91, wagons, engine) == 0 and trade.workshop_refusal(cheap, 92, wagons, engine) == CityTrade.WAGONS_FULL, "no more than 99 wagons (msg 17)", failures)
	var encoded: Variant = JSON.parse_string(JSON.stringify(wagons.snapshot()))
	var copy = TrainWagons.new()
	_check(copy.restore(encoded) and copy.snapshot() == wagons.snapshot(), "a bought train round-trips through JSON", failures)
