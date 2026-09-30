extends RefCounted
# MIT. Validate authored save extensions against staged base objects, then commit.
const Campaign = preload("res://scripts/campaign_session.gd")
const World = preload("res://scripts/world_actions.gd")
const Works = preload("res://scripts/works_dialog.gd")
const UI = preload("res://scripts/world_ui_save.gd")
const VERSION := 8 # Authored JSON schema7 plus campaign/world/works/UI state.

static func has_component(app, name: String) -> bool:
	for property in app.get_property_list():
		if property.name == name:
			return app.get(name) != null
	return false

static func append_snapshot(app, value: Dictionary) -> void:
	for name in ["campaign","world"]:
		if has_component(app,name):
			value[name] = app.get(name).snapshot()
	if has_component(app,"works_dialog"):
		value.works = app.works_dialog.snapshot()
	if has_component(app,"_world_session"):
		value.world_ui = UI.snapshot(app._world_session)
	if value.has("campaign") and value.has("world") and value.has("works") and value.has("world_ui"):
		value.version = VERSION

static func stage(app, parsed: Dictionary, base: Dictionary) -> Dictionary:
	var version: Variant = parsed.get("version",7)
	if not UI.integer(version, 1, VERSION):
		return failure("Save version is unavailable")
	if version == VERSION:
		for key in ["campaign","world","works","world_ui","session","network","wagons","journey"]:
			if not parsed.has(key):
				return failure("Full session save is incomplete")
	elif parsed.get("version",7) is float or parsed.get("version",7) is int:
		if parsed.get("version",7) > VERSION:
			return failure("Save version is unavailable")
	var value := {"campaign":parsed.get("campaign",Campaign.new().snapshot()),"world":parsed.get("world",World.new().snapshot()),"works":parsed.get("works",empty_works()),"world_ui":parsed.get("world_ui",UI.empty_snapshot())}
	if not Campaign.validate_snapshot(value.campaign):
		return failure("Campaign save is invalid")
	var staged_world = World.new()
	staged_world.attach(base.journey,base.wagons,base.session.engine,base.trade,base.encounters.rng)
	if not staged_world.restore(value.world):
		return failure("World save is invalid")
	if not Works.validate_snapshot(value.works,base.network):
		return failure("Works save is invalid")
	if not UI.validate(value.world_ui,staged_world,value.works,base.session.seconds_per_cycle):
		return failure("World screen save is invalid")
	if base.encounters.manual != null and base.encounters.manual.original != base.wagons.snapshot():
		return failure("Battle cargo differs from saved train")
	return {"ok":true,"value":value}

static func commit(app, value: Dictionary) -> void:
	if has_component(app,"campaign"):
		app.campaign.restore(value.campaign)
	if has_component(app,"world"):
		app.world.restore(value.world)
	if has_component(app,"works_dialog"):
		app.works_dialog.restore(value.works)
	if has_component(app,"_world_session"):
		UI.restore(app._world_session,value.world_ui)

static func blocks(app) -> bool:
	return (has_component(app,"campaign") and app.campaign.blocks_simulation()) or (has_component(app,"_world_session") and app._world_session.blocks_simulation()) or (has_component(app,"works_dialog") and app.works_dialog.visible)

static func empty_works() -> Dictionary:
	# Constructor state: no pending question/acceptance/text transaction.
	return {"visible":false,"kind":"","accepted":false,"question":false,"cell":[-1,-1],"code":0,"countdown":0,"lines":"","result_lines":[]}

static func failure(notice: String) -> Dictionary:
	return {"ok":false,"notice":notice+"; current session kept"}
