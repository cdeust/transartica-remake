extends RefCounted
# MIT. Validate authored save extensions against staged base objects, then commit.
const Campaign = preload("res://scripts/campaign_session.gd")
const World = preload("res://scripts/world_actions.gd")
const Works = preload("res://scripts/works_dialog.gd")
const UI = preload("res://scripts/world_ui_save.gd")
const Roamers = preload("res://scripts/world_roamers.gd")
const Launcher = preload("res://scripts/launcher_session.gd")
const VERSION := 9 # source: authored schema8 plus audio and independent commerce RNG.
const FULL_SESSION_VERSION := 8 # source: campaign/world/works/UI schema introduced together.

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
		value.version = FULL_SESSION_VERSION
	if has_component(app,"game_audio"):
		value.audio = app.game_audio.snapshot()
		value.version = VERSION
	if has_component(app,"_trade_rng"):
		value.trade_rng = {"seed":str(app._trade_rng.seed),"state":str(app._trade_rng.state)}
	if has_component(app,"roamers"):
		value.roamers = app.roamers.snapshot()
	if has_component(app,"_boudoir_session"):
		value.launcher = app._boudoir_session.launcher.snapshot()

static func stage(app, parsed: Dictionary, base: Dictionary) -> Dictionary:
	var version: Variant = parsed.get("version",7)
	if not UI.integer(version, 1, VERSION):
		return failure("Save version is unavailable")
	if version >= FULL_SESSION_VERSION:
		for key in ["campaign","world","works","world_ui","session","network","wagons","journey","calendar"]:
			if not parsed.has(key):
				return failure("Full session save is incomplete")
		if not _calendar_valid(parsed.calendar):
			return failure("Calendar save is invalid")
	elif parsed.get("version",7) is float or parsed.get("version",7) is int:
		if parsed.get("version",7) > VERSION:
			return failure("Save version is unavailable")
	var value := {"campaign":parsed.get("campaign",Campaign.new().snapshot()),"world":parsed.get("world",World.new().snapshot()),"works":parsed.get("works",empty_works()),"world_ui":parsed.get("world_ui",UI.empty_snapshot())}
	if version == VERSION and has_component(app,"roamers") and not parsed.has("roamers"):
		return failure("Roaming encounters are incomplete")
	# Legacy schemas did not record populations. Recreate a deterministic fresh
	# source baseline, never a live encounter transaction or historical recovery.
	value.roamers = parsed.roamers if parsed.has("roamers") else _legacy_roamers(parsed,base)
	var staged_roamers = Roamers.new()
	if not staged_roamers.restore(value.roamers):
		return failure("Roaming encounters are invalid")
	if version == VERSION and has_component(app,"_boudoir_session") and not parsed.has("launcher"):
		return failure("Launcher continuation is incomplete")
	# Prior schemas did not contain the launcher continuation.
	value.launcher = parsed.get("launcher",{"version":1,"active":false,"visible":false,"paused":false,"state":{}})
	if not Launcher.validate_snapshot(value.launcher,base.wagons,base.encounters.enemies,base.journey.position):
		return failure("Launcher continuation is invalid")
	if not Campaign.validate_snapshot(value.campaign):
		return failure("Campaign save is invalid")
	var staged_world = World.new()
	staged_world.attach(base.journey,base.wagons,base.session.engine,base.trade,base.encounters.rng)
	if not staged_world.restore(value.world):
		return failure("World save is invalid")
	if version >= FULL_SESSION_VERSION and staged_world.last_mine_day > parsed.calendar.day:
		return failure("Mine calendar differs from saved day")
	if not Works.validate_snapshot(value.works,base.network):
		return failure("Works save is invalid")
	if not UI.validate(value.world_ui,staged_world,value.works,base.session.seconds_per_cycle,staged_roamers):
		return failure("World screen save is invalid")
	if base.encounters.manual != null and base.encounters.manual.original != base.wagons.snapshot():
		return failure("Battle cargo differs from saved train")
	if version == VERSION and not parsed.has("audio"):
		return failure("Audio save is incomplete")
	value.audio = parsed.get("audio")
	if version == VERSION and not value.audio is Dictionary:
		return failure("Audio save is invalid")
	if value.audio != null and has_component(app,"game_audio") and not app.game_audio.validate_snapshot(value.audio):
		return failure("Audio save is invalid")
	value.trade_rng = parsed.get("trade_rng")
	if version == VERSION and has_component(app,"_trade_rng") and value.trade_rng == null:
		return failure("Commerce random state is incomplete")
	if value.trade_rng != null:
		if not value.trade_rng is Dictionary:
			return failure("Commerce random state is invalid")
		for key in ["seed","state"]:
			var number: Variant = value.trade_rng.get(key)
			if not number is String or not number.is_valid_int() or str(int(number)) != number:
				return failure("Commerce random state is invalid")
	return {"ok":true,"value":value}

static func _legacy_roamers(parsed: Dictionary, base: Dictionary) -> Dictionary:
	# Authored migration: copy the saved source RNG without advancing live streams.
	# Pre-encounter saves have no RNG; their persisted engine/journey identity seeds
	# a fresh baseline, not a reconstruction of unavailable population history.
	var rng := RandomNumberGenerator.new()
	if parsed.has("encounters"):
		rng.seed = base.encounters.rng.seed
		rng.state = base.encounters.rng.state
	else:
		rng.seed = parsed.hash()
	var fresh := Roamers.new()
	fresh.initialize(rng,preload("res://scripts/campaign_fauna.gd").new())
	return fresh.snapshot()

static func _calendar_valid(value: Variant) -> bool:
	# Source: GameCalendar domains, TABLE start and YODA minute/hour/day fields.
	if not value is Dictionary:
		return false
	if not UI.integer(value.get("minute"),0,59) or not UI.integer(value.get("hour"),0,23):
		return false
	var day: Variant = value.get("day")
	return UI.number(day) and day >= 1 and day == floor(day) and UI.integer(value.get("factor"),1,3) and int(value.factor) in [1,3]

static func commit(app, value: Dictionary) -> void:
	# CityTrade.visit uses this stream for nomad stock; persist it separately.
	if value.trade_rng != null and has_component(app,"_trade_rng"):
		app._trade_rng.seed = int(value.trade_rng.seed)
		app._trade_rng.state = int(value.trade_rng.state)
	if has_component(app,"roamers"):
		app.roamers.restore(value.roamers)
	if has_component(app,"campaign"):
		app.campaign.restore(value.campaign)
	if has_component(app,"world"):
		app.world.restore(value.world)
	if has_component(app,"works_dialog"):
		app.works_dialog.restore(value.works)
	if has_component(app,"_world_session"):
		UI.restore(app._world_session,value.world_ui)
		if has_component(app,"roamers"):
			app._world_session.restore_roamers()
	if has_component(app,"_boudoir_session"):
		app._boudoir_session.launcher.restore(value.launcher)

static func commit_audio(app, value: Dictionary) -> void:
	# Restore after all UI presentation; opening a restored city may select music.
	if has_component(app,"game_audio"):
		if value.audio == null:
			app.game_audio.reset()
		else:
			app.game_audio.restore(value.audio)

static func blocks(app) -> bool:
	return (has_component(app,"campaign") and app.campaign.blocks_simulation()) or (has_component(app,"_world_session") and app._world_session.blocks_simulation()) or (has_component(app,"works_dialog") and app.works_dialog.visible) or (has_component(app,"_boudoir_session") and app._boudoir_session.launcher.blocks_simulation())

static func empty_works() -> Dictionary:
	# Constructor state: no pending question/acceptance/text transaction.
	return {"visible":false,"kind":"","accepted":false,"question":false,"cell":[-1,-1],"code":0,"countdown":0,"lines":"","result_lines":[]}

static func failure(notice: String) -> Dictionary:
	return {"ok":false,"notice":notice+"; current session kept"}
