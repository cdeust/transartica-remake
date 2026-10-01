extends RefCounted
# MIT. Authored JSON protocol for the existing mine/workshop controls.
# Constraints follow WorldActions, StationWorkshop and WorldSession state domains.
const MineTable = preload("res://scripts/mines.gd")
const TEXT_TICKS_PER_CYCLE := 48 # ALIS wait1,YODA16 tours/minute, engine3min/cycle.

static func empty_snapshot() -> Dictionary:
	return {"version":1,"mine":{"visible":false,"question":true,"report":{},"lines":[]},
		"workshop":{"visible":false,"title":"","selected":-1,"action":51,"scroll":0,"moving":-1,"confirmation":false,"notice":""},"text_accumulator":0.0}

static func snapshot(coordinator) -> Dictionary:
	var value := empty_snapshot()
	for key in value.mine:
		value.mine[key] = coordinator.mine_screen.get(key)
	for key in value.workshop:
		value.workshop[key] = coordinator.workshop.get(key)
	# Closed controls do not retain a live confirmation or moving transaction.
	if not value.workshop.visible:
		value.workshop.confirmation = false
		value.workshop.moving = -1
	value.text_accumulator = coordinator.text_accumulator if (coordinator.app.works_dialog.visible or (coordinator.app.get("roamers") != null and coordinator.app.roamers.pending == "hunt_result")) else 0.0
	return value.duplicate(true)

static func validate(value: Variant, world, works: Dictionary, seconds_per_cycle: float, roamers = null) -> bool:
	if not value is Dictionary or value.get("version") != 1:
		return false
	var accumulator: Variant = value.get("text_accumulator")
	if not number(accumulator) or accumulator < 0 or accumulator >= seconds_per_cycle/TEXT_TICKS_PER_CYCLE:
		return false
	if not works.visible and (roamers == null or roamers.pending != "hunt_result") and accumulator != 0:
		return false
	return _mine(value.get("mine"),world) and _workshop(value.get("workshop"),world.management)

static func _mine(value: Variant, world) -> bool:
	if not value is Dictionary or not value.get("visible") is bool or not value.get("question") is bool or not value.get("report") is Dictionary or not strings(value.get("lines")):
		return false
	if value.visible != (world.pending_mine >= 0):
		return false
	if not value.visible:
		return value.report.is_empty() or _mine_report(value.report)
	if value.question == world.mine_accepted or not _mine_report(value.report):
		return false
	var record: Array = world.mines.records[world.pending_mine]
	var ore := "ANTHRACITE" if MineTable.is_anthracite(record) else "LIGNITE"
	return value.report.ore == ore and value.report.wealth == record[MineTable.FIELD_WEALTH]

static func _mine_report(report: Dictionary) -> bool:
	# Source WorldActions.ask_mine/YODA22 and TEXTEK72/71 plaque year2714.
	return report.get("question") == 22 and report.get("text") == 72 and report.get("year") == 2714 and report.get("ore") in ["ANTHRACITE","LIGNITE"] and integer(report.get("wealth"),-4,MineTable.WEALTH_MIN+MineTable.WEALTH_SPREAD-1)

static func _workshop(value: Variant, management) -> bool:
	if not value is Dictionary or not value.get("visible") is bool or not value.get("confirmation") is bool or not value.get("title") is String or not value.get("notice") is String:
		return false
	var count: int = management.wagons.count()
	if not integer(value.get("selected"),-1,count-1) or not integer(value.get("moving"),-1,count-1):
		return false
	if not integer(value.get("action"),50,53) or not integer(value.get("scroll"),0,maxi(0,count-10)):
		return false
	if value.moving >= 0 and (not value.visible or value.action != 50 or value.selected != value.moving):
		return false
	if not value.confirmation:
		return true
	if not value.visible or value.selected < 0 or not int(value.action) in [52,53]:
		return false
	var index := int(value.selected)
	return management.repair_refusal(index) == 0 if value.action == 52 else management.remove_refusal(index) == 0

static func restore(coordinator, value: Dictionary) -> void:
	for key in empty_snapshot().mine:
		coordinator.mine_screen.set(key,value.mine[key].duplicate(true) if value.mine[key] is Dictionary or value.mine[key] is Array else value.mine[key])
	coordinator.mine_screen._load_scene()
	coordinator.mine_screen.queue_redraw()
	for key in empty_snapshot().workshop:
		coordinator.workshop.set(key,int(value.workshop[key]) if key in ["selected","action","scroll","moving"] else value.workshop[key])
	coordinator.workshop.management = coordinator.app.world.management
	coordinator.workshop.trade = coordinator.app.trade
	coordinator.workshop.queue_redraw()
	coordinator.text_accumulator = float(value.text_accumulator)

static func number(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(value)

static func integer(value: Variant, low: int, high: int) -> bool:
	return number(value) and value == floor(value) and value >= low and value <= high

static func strings(value: Variant) -> bool:
	if not value is Array:
		return false
	for line in value:
		if not line is String:
			return false
	return true
