extends SceneTree
# MIT. Verify campaign seams independently of the root presentation fixture.
const Encounters = preload("res://scripts/world_encounters.gd")
class Observer extends RefCounted:
	var calls: Array = []
	func observe_enemy(slot,cell,calendar,stoup) -> void:
		calls.append([slot,cell,calendar,stoup])
class Campaign extends RefCounted:
	var state=Observer.new()
	var deaths: Array = []
	func die(reason: int) -> void:
		deaths.append(reason)
class App extends RefCounted:
	var campaign=Campaign.new()
	var calendar=preload("res://scripts/game_calendar.gd").new()
	var stoup=preload("res://scripts/stoup_messages.gd").new()
class Report extends Control:
	var reports: Array = []
	func open_report(value: Dictionary) -> void:
		reports.append(value)
func _initialize() -> void:
	var encounters=Encounters.new()
	encounters.app=App.new()
	encounters.manual_scene=Control.new()
	encounters.report=Report.new()
	encounters.enemies.slots[0][0]=1
	encounters.enemies.slots[0][1]=0
	encounters.enemies.slots[0][2]=10
	var before: Array=[]
	for slot in encounters.enemies.SLOT_COUNT: before.append(encounters.enemies.cell(slot))
	encounters._observe_enemy_moves(before)
	assert(encounters.app.campaign.state.calls.is_empty())
	encounters.enemies.slots[0][1]=1
	encounters._observe_enemy_moves(before)
	assert(encounters.app.campaign.state.calls.size()==1)
	assert(encounters.app.campaign.state.calls[0][0]==0 and encounters.app.campaign.state.calls[0][1]==Vector2i(41,10))
	encounters._present_result({"won":false})
	assert(encounters.app.campaign.deaths==[105] and encounters.report.reports.is_empty())
	encounters._present_result({"won":true})
	assert(encounters.report.reports.size()==1)
	encounters.manual_scene.free()
	encounters.report.free()
	print("PASS: moved live enemies notify campaign spies; defeat105 and victory reports")
	quit()
