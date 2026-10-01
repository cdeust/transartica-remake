extends "res://scripts/campaign_crew.gd"

# MIT. TIME grid bits8/128 and YODA wolf/mole scenes; no shared map flags changed.
const Ambush = preload("res://scripts/campaign_ambush.gd")


func _mover_report_context() -> Dictionary:
	var context := {"wolf_heading": state.fauna.heading}
	var roamers = app.get("roamers")
	if roamers != null:
		context.herds = roamers.herds
		context.nomad_heading = roamers.nomad[3]
	return context


func advance_fauna() -> bool:
	if not state.pending.is_empty() or not state.ending.is_empty() or screen.visible:
		return false
	state.fauna.initialize(app._trade_rng)
	state.fauna.record_player(app.journey.position, app.network)
	if state.fauna.advance(app.network, app._trade_rng, state.hazards.traps):
		state.observe_enemy(59, state.fauna.cell, app.calendar, app.stoup) # TIME2191 wolf code60.
		if state.fauna.has_presence(app.journey.position):
			_present_ambush("wolf")
			return true
	return false


func before_fauna(cell: Vector2i) -> bool:
	state.fauna.initialize(app._trade_rng)
	var kind := "wolf" if state.fauna.has_presence(cell) else "mole" if state.hazards.player_mole(cell, app.calendar, app._trade_rng) else ""
	if kind.is_empty():
		return false
	_present_ambush(kind)
	return true


func _present_ambush(kind: String) -> void:
	var defenders: Dictionary = Ambush.defenders(app.wagons, state.data.get("ambush_phrases", {}))
	var lines: Array = state.message(77 if kind == "wolf" else 78)
	lines.append_array(defenders.lines)
	call("present", state._event(kind, [77 if kind == "wolf" else 78, 81, 79 if kind == "wolf" else 80],
		{"divisor": defenders.divisor, "applied": 0, "ambush_lines": lines}))


func _ambush_page() -> Array:
	var event: Dictionary = state.pending
	var page: int = get("page")
	if page > int(event.applied):
		var phrases: Dictionary = state.data.get("ambush_phrases", {})
		event.ambush_lines = Ambush.human(app.wagons, int(event.divisor), phrases) if page == 1 else Ambush.materials(event.scene == "wolf", app.wagons, app.engine, int(event.divisor), phrases, app._trade_rng, state.data)
		event.applied = page
		app._on_cargo_changed()
	return event.ambush_lines


func _finish_fauna(event: Dictionary) -> void:
	if event.get("scene") == "wolf":
		state.fauna.relocate(app._trade_rng) # YODA11c1→29dc after all reports.
