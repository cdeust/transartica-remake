extends RefCounted

# Reachability planner over actual source rail glyphs/turn rules; the replay owns
# all gameplay writes. Predicting a documented reveal is not changing the live map.
const Rails = preload("res://scripts/rail_network.gd")
const Works = preload("res://scripts/track_works.gd")
const Glyphs = preload("res://scripts/rail_glyphs.gd")
const Journey = preload("res://scripts/train_journey.gd")
var network
var campaign
var wagons
var frontiers: Dictionary = {}
# Operator restriction for a native leg; no gameplay turn/port rule changes.
var allow_midtrack_reverse := true
var _parents: Dictionary
var _queue: Array[Vector3i]


func _code(cell: Vector2i) -> int:
	var code: int = network.tile(cell)
	if code == -115:
		var region := "hima" if cell.x > 38 and cell.x < 59 and cell.y > 19 and cell.y < 34 else "trans" if cell.x > 138 and cell.x < 158 and cell.y > 46 and cell.y < 69 else "oasis"
		var adjustment := 256 if region == "trans" else 0
		for record in campaign.data.regions[region]:
			if Vector2i(int(record[0]) + adjustment, int(record[1])) == cell:
				return int(record[2])
	if cell.y == 67 and cell.x in [28,29,30] and code in [88,89,90]:
		return {28:54,29:-114,30:-113}[cell.x]
	if cell == Vector2i(39,32) and code == 34:
		return 2
	if cell == Vector2i(157,68) and code == 36 and campaign.central_destroyed:
		return 3
	if cell == Vector2i(32,67) and code == 35 and (wagons.wagons.front()[0] == 8 or wagons.wagons.back()[0] == 8):
		return 2
	return code


func plan(position: Vector2i, heading: int, target: Vector2i, phase: int = 0) -> Array:
	var start := _state(position, heading, phase)
	var queue: Array[Vector3i] = [start]
	var parents := {start: {}}
	_parents = parents
	_queue = queue
	var cursor := 0
	frontiers.clear()
	while cursor < queue.size():
		var state: Vector3i = queue[cursor]
		cursor += 1
		var cell := Vector2i(state.x,state.y)
		var incoming := state.z % 16
		var current_phase := int(state.z / 16) - 1
		var skip_turn := current_phase >= Journey.TURN_PHASE
		var source_code: int = network.tile(cell)
		var effective := _code(cell)
		var alternatives := [effective]
		if Rails.is_switch_code(effective) and not skip_turn:
			alternatives.append(effective + 1 if effective % 2 == 0 else effective - 1)
		for choice in alternatives:
			# Planning uses a detached single-tile lookup; original network is restored
			# before any parent or result is returned.
			network._tiles[cell.x * Rails.HEIGHT + cell.y] = choice
			var outgoing: int = incoming if skip_turn else network.turn(cell,incoming)
			network._tiles[cell.x * Rails.HEIGHT + cell.y] = source_code
			var candidate: Vector2i = cell + Rails.DELTAS[outgoing]
			if not network.in_bounds(candidate):
				continue
			var next_code := _code(candidate)
			if candidate == Vector2i(11,10) and campaign.whale_present:
				var harpoon := false
				for wagon in wagons.wagons:
					harpoon = harpoon or wagon[0] == 9 and wagon[1] < 3
				if not harpoon:
					frontiers[candidate] = "whale requires harpoon or another route"
					continue
			var action := {"cell":cell,"heading":incoming,"phase":current_phase,"switch":choice if Rails.is_switch_code(choice) else 0,"next":candidate,"outgoing":outgoing}
			if candidate == target:
				return _route(parents,state,action)
			# Source: YODA mine(-22)->9ee->18e3 and workshop exit reverse;
			# world_actions.close_mine/world_session._close_workshop implement these.
			# This is an event-exit projection; the native pilot verifies rear contacts.
			if next_code >= 34 and next_code <= 37 or next_code in [65,78]:
				var reversed := _state(cell,10-outgoing,0)
				action.station = candidate
				_enqueue(reversed,state,action)
				continue
			var kind := Works.kind_for(next_code)
			if not kind.is_empty():
				if not Works.shortage(kind,wagons).is_empty():
					frontiers[candidate] = next_code
					continue
				next_code = Works.repaired_code(next_code)
			var ports: Array[Vector2] = Glyphs.ports_for_code(next_code)
			if ports.is_empty() or not -Vector2(Rails.DELTAS[outgoing])*0.5 in ports:
				if next_code != 0:
					frontiers[candidate] = next_code
				continue
			if next_code == -120:
				frontiers[candidate] = next_code
				continue
			_enqueue(_state(candidate,outgoing,0),state,action)
		# YODA reversal preserves the source phase transform. TIME turns only
		# when the remaining phases include phase1; phase1->0 must turn again.
		var reversed_phase := absi(current_phase - 2) - 1
		if allow_midtrack_reverse:
			_enqueue(_state(cell,10-incoming,reversed_phase),state,{"reverse":true,"cell":cell,"phase_before":current_phase,"phase_after":reversed_phase})
	return []


func _state(position: Vector2i, heading: int, phase: int) -> Vector3i:
	# Four heading bits leave distinct search states for source phases -1..2.
	return Vector3i(position.x,position.y,heading + 16 * (phase + 1))


func _enqueue(next: Vector3i, previous: Vector3i, action: Dictionary) -> void:
	if _parents.has(next):
		return
	_parents[next] = {"previous":previous,"action":action}
	_queue.append(next)


func _route(parents: Dictionary, state: Vector3i, last: Dictionary) -> Array:
	var route: Array = [last]
	while not parents[state].is_empty():
		route.push_front(parents[state].action)
		state = parents[state].previous
	return route
