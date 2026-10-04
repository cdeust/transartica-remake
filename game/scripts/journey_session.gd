extends RefCounted

# MIT. Behavior-preserving extraction of main.gd PR7 journey dispatch.
# Sources: TIME0x2483..24c3, YODA0x2318 and evidence/station-arrival.md.

static func advance(app) -> void:
	if app.engine.event_pending:
		return
	# A pre-entry modal suspends the physical special-site handler before its
	# classification/release. Dismissal resumes that same contact even though
	# it was already blocked, before TIME may advance or handle another cell.
	if app.journey.blocked and app.journey.physical_obstacle != Vector2i(-1,-1) and (app.journey.stop_reason == "special site" or app.journey.physical_spy_handled):
		if app.campaign.state.pending.is_empty():
			_handle_boundary(app,false)
		return
	# TIME re-checks the cell once the brake is released (obstacles-unknowns.md §1).
	if app.journey.at_obstacle() and not app.engine.brake and not app.works_dialog.visible:
		app.journey.resume_after_works()
	var was_blocked: bool = app.journey.blocked
	app._advance_calendar()
	# Source TIME herd/nomad movement is independent of enemy-train records.
	for observation in app.roamers.advance(app.network,app._trade_rng,app.campaign.state.hazards.traps):
		app.campaign.state.observe_enemy(observation.code-1,observation.cell,app.calendar,app.stoup)
	if app._world_session.encounter_roamers(app.journey.position):
		return
	# Source TIME0x85f..8ed: roaming wolves can reach a stationary player.
	if app.campaign.advance_fauna():
		return
	var old_cell: Vector2i = app.journey.position
	if _entry_due(app):
		if app._world_session.encounter_roamers(app.journey.next_cell()):
			return
		app.world.before_entry(app.journey.next_cell())
		if app.campaign.before_entry(app.journey.next_cell()):
			return
	preload("res://scripts/reverse_contact_stop.gd").advance(app.world_view, app.journey, app.engine.speed)
	if app.encounters.advance(old_cell):
		return
	app.world_view.visit_cell(app.journey.position)
	app.world_view.update_train()
	app._filter_cities(app.search_box.text)
	app._update_status()
	if app._map_panel.visible:
		app._modal_title.text = "   TRANSARCTICA · %s · (%d, %d) %s · %d km/h" % [app.calendar.display_text(), app.journey.position.x, app.journey.position.y, app.journey.heading_name(), app.engine.speed]
	if app.journey.blocked:
		_handle_boundary(app, was_blocked)


static func _handle_boundary(app, was_blocked: bool) -> void:
	if was_blocked:
		return
	# The reverse-leading rear contact can reach a source gate before TIME's
	# locomotive cell. Run the same pre-entry rules at that actual contact:
	# TIME0x1c31..1c75 (drill), CampaignState.prepare_entry (secret gates).
	if app.journey.physical_obstacle != Vector2i(-1,-1):
		var cell: Vector2i = app.journey.boundary_cell()
		app.world.before_entry(cell)
		if app.campaign.before_entry(cell, app.journey.physical_heading, app.journey.physical_spy_handled):
			if app.campaign.state.pending.get("scene") == "spy_pickup":
				app.journey.physical_spy_handled = true
			return
		app.journey.physical_spy_handled = false
		# A hidden record may decode to a station or works, not only clear rail.
		# Dispatch the revealed kind at this same physical contact.
		app.journey.stop_reason = app.network.entry_boundary(cell)
		if app.journey.stop_reason.is_empty():
			app.journey.physical_obstacle = Vector2i(-1,-1)
			app.journey.physical_heading = 0
			app.journey.blocked = false
			app.journey.stop_reason = ""
			app.world_view.update_train()
			return
	# Arrival pauses the visual clock in this same callback. Finish its final
	# rail segment before any station/dialog takes ownership (owner3Oct).
	app.world_view._snap_visual_position(app.journey.fractional_position())
	app.world_view.update_train()
	if app._world_session.handle_boundary():
		return
	var station: int = app.journey.station_result()
	if station >= 0:
		app._open_city(station)
		return
	if app.journey.at_station() and app.campaign.station(station):
		return
	if app.journey.at_reversal_event():
		if not was_blocked:
			app._reverse_at_event()
		return
	if app.journey.at_obstacle():
		# YODA 0x2318: the question brakes the train; asked once per refused entry.
		if not was_blocked:
			app.engine.brake = true
			app.engine.speed = 0
			app.works_dialog.ask(app.network)
		return
	app.engine.brake = true
	app.engine.speed = 0
	app.session.paused = true
	var ahead: Vector2i = app.journey.next_cell()
	var reason: String = app.journey.stop_reason
	if app.journey.at_station():
		# TIME 0x2483..0x24c3: -1 sends message 34, -2..-5 send messages 22..25.
		reason = "station without city (message 34)" if station == -1 else "story station (message %d)" % (absi(station) + 20)
	app.room_controls.announce("Stopped before %s at (%d, %d) · not yet ported" % [reason, ahead.x, ahead.y])
	app.status_label.text = "Stopped before %s at (%d, %d).\nR starts a new run." % [reason, ahead.x, ahead.y]


# Same strict remainder/phase guard as TrainJourney.advance (TIME0x0567..063f).
# Standing beside a story location must never trigger a pre-entry handler.
static func _entry_due(app) -> bool:
	if app.journey.blocked or app.engine.speed <= 0:
		return false
	var progress: int = mini(app.network.progress_speed(app.journey.position, app.journey.heading, app.engine.speed), app.journey.MAX_PROGRESS_SPEED)
	return app.journey.phase + 1 >= app.journey.PHASES_PER_TILE and app.journey.distance_ticks + int(progress / 20) > app.journey.MAX_DISTANCE_REMAINDER
