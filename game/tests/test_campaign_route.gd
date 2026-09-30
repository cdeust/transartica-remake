extends SceneTree

const Data = preload("res://scripts/world_data.gd")
const Rails = preload("res://scripts/rail_network.gd")
const Journey = preload("res://scripts/train_journey.gd")
const Campaign = preload("res://scripts/campaign_state.gd")
const Planner = preload("res://tests/campaign_route_planner.gd")
var data = Data.new()
var network = Rails.new()
var journey = Journey.new()
var campaign = Campaign.new()
var wagons = preload("res://scripts/train_wagons.gd").new()
var planner = Planner.new()
var failures: Array[String] = []
var stations: Dictionary = {}

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://../.cache/campaign-route"))
	if not data.load_from_project(ProjectSettings.globalize_path("res://").trim_suffix("/")) or not campaign.load_data():
		push_error("Campaign route test needs original map/cities and private campaign data")
		quit(1)
		return
	network.load_bytes(data.map_bytes)
	network.set_city_anchors(data.city_anchors())
	network.campaign_entry_enabled = true
	journey.network = network
	planner.network = network
	planner.campaign = campaign
	planner.wagons = wagons
	for x in Rails.WIDTH:
		for y in Rails.HEIGHT:
			var cell := Vector2i(x,y)
			if network.tile(cell) >= 34 and network.tile(cell) <= 37:
				stations[network.station_lookup(cell)] = cell
	for cell in Rails.STATION_SPECIALS:
		stations[Rails.STATION_SPECIALS[cell]] = cell
	
	var driver = preload("res://tests/campaign_route_driver.gd").new()
	if not driver.attach({"network":network,"journey":journey,"campaign":campaign,"wagons":wagons},self):
		push_error("Commerce data failed")
		quit(1)
		return
	driver.story_ui = preload("res://tests/campaign_route_ui.gd").new()
	root.add_child(driver.story_ui)
	driver.story_ui.attach(driver)
	var okay := _shopping_route(driver)
	var replay := FileAccess.open(ProjectSettings.globalize_path("res://../.cache/campaign-route/replay.log"),FileAccess.WRITE)
	replay.store_string("\n".join(driver.trace) + "\n")
	replay.close()
	print("ACTUAL ADVANCE calls=",driver.advance_calls," entered=",driver.entered_cells)
	if okay:
		print("PASS: TABLE-start earned campaign, source story/quiz/spy/workshop/reception inputs, default enemies, actual Minotaur result, Sun finale to OPTIONS; day%d fuel%d" % [driver.calendar.day,driver.engine.lignite])
	else:
		push_error(driver.error)
	driver.dialog.queue_free()
	driver.story_ui.queue_free()
	quit(0 if okay else 1)

func _shopping_route(driver) -> bool:
	if not driver.travel(stations[38],38):return false
	if not driver.trade_goods(10,20,driver.trade.BUY):return false
	if not driver.travel(stations[31],31):return false
	if not driver.trade_goods(10,20,driver.trade.SELL):return false
	if not driver.travel(stations[11],11):return false
	if not driver.buy_wagon(18):return false
	if not driver.travel(stations[38],38):return false
	if not driver.trade_goods(10,38,driver.trade.BUY):return false
	if not driver.travel(stations[31],31):return false
	if not driver.trade_goods(10,38,driver.trade.SELL):return false
	if not driver.travel(stations[11],11):return false
	if not driver.buy_wagon(18):return false
	
	if not driver.travel(stations[10],10):return false
	if not driver.buy_wagon(5):return false
	if not driver.travel(stations[4],4):return false
	if not driver.transaction(driver.trade.offer(4,driver.trade.SLAVE_MARKET,driver.trade.BUY),15):return false
	if not driver.travel(stations[35],35):return false
	if not driver.trade_goods(1,29,driver.trade.BUY):return false
	if not driver.travel(stations[15],15):return false
	if not driver.buy_wagon(8):return false
	if not driver.travel(stations[41],41):return false
	if not driver.travel(stations[4],4):return false
	if not driver.travel(stations[-2],-2):return false
	if not driver.story_ui.station(-2):return driver._fail("Actual Urga UI flow failed")
	if not campaign.urga_key:return false
	if not driver.travel(stations[13],13):return false
	if not driver.buy_wagon(22):return false
	if not driver.travel(stations[8],8):return false
	if not driver.transaction(driver.trade.offer(8,driver.trade.GARRISON,driver.trade.SELL),1):return false
	var spy: int = driver.story_ui.send_spy(Vector2i(65,20))
	if spy < 0:return driver._fail("Actual spy dispatch refused")
	driver.trace.append("SEND SPY from%s to(65,20) slot%d" % [journey.position,spy])
	if not driver.travel(stations[-4],-4):return false
	if not driver.story_ui.station(-4):return driver._fail("Actual Mausoleum UI flow failed")
	if not " ".join(campaign.message(51)).contains(Campaign.DELIVERY_CODE):return driver._fail("Actual Mausoleum document does not contain delivery code")
	if not driver.travel(stations[27],27):return false
	if not driver.trade_goods(1,50,driver.trade.BUY):return false
	if not driver.trade_goods(11,30,driver.trade.BUY):return false
	if not driver.travel(stations[32],32):return false
	if not driver.trade_goods(11,30,driver.trade.SELL):return false
	if not driver.travel(stations[16],16):return false
	if not driver.buy_wagon(9):return false
	if not driver.buy_wagon(15):return false
	if not driver.travel(stations[32],32):return false
	if not driver.trade_goods(8,20,driver.trade.BUY):return false
	if not driver.travel(stations[35],35):return false
	if not driver.trade_goods(8,20,driver.trade.SELL):return false
	if not driver.travel(stations[13],13):return false
	if not driver.buy_wagon(11):return false
	if not driver.travel(stations[-3],-3):return false
	if not driver.story_ui.station(-3):return driver._fail("Actual Oslo quiz/code UI flow failed")
	if not campaign.delivery_open:return driver._fail("Source delivery flag was not opened")
	if campaign.spies[spy][0] != 3:return driver._fail("Real calendar did not deliver source central spy")
	if not driver.story_ui.sabotage(Vector2i(65,20)):return driver._fail("Confirmed central sabotage UI flow rejected")
	driver.trace.append("CONFIRM CENTRAL SABOTAGE slot%d day%d" % [spy,driver.calendar.day])
	if not driver.travel(Vector2i(12,17),-1):return false
	for index in range(wagons.count()-1,-1,-1):
		if wagons.wagons[index][0] in [5,8,9,15,17,18,22,23]:
			var kind: int = wagons.wagons[index][0]
			if not driver.story_ui.remove_wagon(index):return driver._fail("Source workshop removal UI refused")
			driver.trace.append("WORKSHOP REMOVE type%d" % kind)
	if wagons.count() != 5:return driver._fail("Slope preparation did not retain original protected wagons and earned cannon")
	if not driver.story_ui.select_automatic():return driver._fail("Source reception combat plaque failed")
	driver.automatic = driver.story_ui.encounters.automatic
	driver.trace.append("SELECT SOURCE AUTOMATIC COMBAT")
	if not driver.travel(stations[-5],-5):return false
	if not driver.story_ui.station(-5):return driver._fail("Source Sun UI flow failed")
	if not driver.story_ui.finish_movie():return driver._fail("Source finale did not finish through its movie signal")
	if campaign.ending != "sun" or not campaign.pending.is_empty():return driver._fail("Final campaign state differs from source Sun completion")
	if not driver.gates.has(Vector2i(157,68)) or driver.gates[Vector2i(157,68)].tile != 3:return driver._fail("Actual Gycode map gate not crossed")
	if not driver.gates.has(Vector2i(152,48)) or driver.gates[Vector2i(152,48)].wagons != 5:return driver._fail("Actual source slope constraint not exercised")
	if driver.enemies.slots[29][0] != driver.enemies.REMOVED_STATE:return driver._fail("Actual Minotaur was not defeated")
	driver.trace.append("SUN ENDING + SOURCE FINALE completed to OPTIONS")
	return true
