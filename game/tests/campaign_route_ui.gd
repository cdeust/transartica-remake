extends Node

# Test host for real campaign/reception/report controls. Presentation callbacks
# are observed here; every gameplay object belongs to the actual route driver.
class QuietView extends Control:
	var encounters
	var wagons
	func update_train() -> void:queue_redraw()

class BoudoirHost extends RefCounted:
	var view := Control.new()
	var reception
	func leave() -> void:view.hide()

var driver
var engine
var calendar
var wagons
var trade
var world
var journey
var network
var stoup
var _trade_rng
var _boudoir_session = BoudoirHost.new()
var _modal := Control.new()
var instruments := Control.new()
var _city_panel := Control.new()
var world_view = QuietView.new()
var session := {"paused":false}
var current_panel := "room"
var campaign_session = preload("res://scripts/campaign_session.gd").new()
var encounters = preload("res://scripts/world_encounters.gd").new()
var workshop = preload("res://scripts/station_workshop.gd").new()


func attach(source_driver) -> void:
	driver = source_driver
	for property in ["engine","calendar","wagons","trade","world","journey","network","stoup"]:
		set(property,driver.get(property))
	_trade_rng = driver.rng
	_boudoir_session.reception = preload("res://scripts/reception_screen.gd").new()
	add_child(_boudoir_session.reception)
	_boudoir_session.reception.size = Vector2(320,200)
	for view in [_boudoir_session.view,_modal,instruments,_city_panel,world_view]:add_child(view)
	campaign_session.attach(self)
	campaign_session.state = driver.campaign
	campaign_session.screen.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	campaign_session.screen.size = Vector2(320,200)
	campaign_session.screen.set_process(false)
	encounters.attach(self)
	driver.enemies = encounters.enemies
	driver.encounter_rng = encounters.rng
	driver.encounter_rng.seed = 1
	workshop.management = world.management
	workshop.trade = trade
	add_child(workshop)
	workshop.size = Vector2(320,200)


func city(index: int) -> bool:
	if campaign_session.before_city(index):
		answer_quiz()
		if not driver.campaign.pending.is_empty():return false
		driver.trace.append("SOURCE CITY MANUAL QUIZ ACCEPTED city%d" % index)
	return true


func station(index: int) -> bool:
	if not journey.at_station() or journey.station_result() != index:return false
	if not campaign_session.station(index):return false
	while not driver.campaign.pending.is_empty():
		if driver.campaign.pending.scene == "manual_quiz":answer_quiz()
		elif campaign_session.screen.entering_code:input_text(driver.campaign.DELIVERY_CODE)
		elif driver.campaign.pending.scene == "sun_end":return true
		else:press(KEY_ENTER)
	return true


func answer_quiz() -> void:
	var pending: Dictionary = driver.campaign.pending
	input_text(driver.campaign.data.quizzes[pending.quiz][pending.index].answer)
	driver.trace.append("INPUT SOURCE %s MANUAL answer accepted" % pending.quiz.to_upper())


func input_text(value: String) -> void:
	for character in value:
		var event := InputEventKey.new()
		event.unicode = character.unicode_at(0)
		campaign_session.screen.handle_key(event)
	press(KEY_ENTER)


func press(key: int) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = key
	campaign_session.screen.handle_key(event)


func sabotage(cell: Vector2i) -> bool:
	campaign_session.open_spy_menu()
	press(KEY_2)
	if not campaign_session.select_map_cell(cell):return false
	if driver.campaign.pending.get("scene") != "sabotage_confirm":return false
	press(KEY_Y)
	return driver.campaign.central_destroyed


func send_spy(cell: Vector2i) -> int:
	campaign_session.open_spy_menu()
	press(KEY_1)
	if not campaign_session.select_map_cell(cell):return -1
	for index in driver.campaign.spies.size():
		var record: Array = driver.campaign.spies[index]
		if record[0] == 2 and Vector2i(record[3]+40,record[4]) == cell:return index
	return -1


func before_entry(cell: Vector2i) -> Dictionary:
	if not campaign_session.before_entry(cell):return {}
	var event: Dictionary = driver.campaign.pending.duplicate(true)
	if event.scene == "whale_harpoon":
		press(KEY_ENTER)
		engine.brake = false # Player releases the scene-prelude brake.
	return event


func select_automatic() -> bool:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	event.position = Vector2(255,34) # Original reception combat plaque center.
	_boudoir_session.reception._gui_input(event)
	return encounters.automatic


func remove_wagon(index: int) -> bool:
	if not journey.at_reversal_event() or network.tile(journey.next_cell()) != 65:return false
	workshop.open(journey.position)
	while index >= workshop.scroll + 10:
		click_workshop(Vector2(310,52))
	click_workshop(workshop.MENU.position + Vector2(3.5*56,7))
	click_workshop(workshop.STRIP.position + Vector2((index-workshop.scroll+0.5)*workshop.CELL_WIDTH,12))
	if not workshop.confirmation:return false
	var count: int = wagons.count()
	click_workshop(Vector2(186,132))
	workshop.hide()
	return wagons.count() == count-1


func click_workshop(point: Vector2) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	event.position = point
	workshop._gui_input(event)


func resolve_battle(slot: int) -> Dictionary:
	encounters.pending = slot
	encounters.resolve_pending()
	var result: Dictionary = encounters.report.result.duplicate(true)
	var event := InputEventKey.new()
	event.physical_keycode = KEY_ENTER
	encounters.report.handle_key(event)
	return result


func finish_movie() -> bool:
	var screen = campaign_session.screen
	if driver.campaign.pending.get("scene") != "sun_end":return false
	for tick in screen.finale.LAST:
		screen._process(1.0 / screen.finale.HZ)
	return current_panel == "options" and screen.finale.tick == screen.finale.LAST and not screen.visible


func depart_from_city() -> void:
	journey.depart_from_station()
	engine.brake = false


func _open_panel(name: String) -> void:current_panel = name
func _open_city(_index: int) -> void:_city_panel.show()
func _on_cargo_changed() -> void:world_view.update_train()
